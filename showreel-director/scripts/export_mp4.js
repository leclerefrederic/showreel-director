#!/usr/bin/env node
/* Export a built reel (dist/index.html) to MP4 without a browser.
   Every frame is a pure function of time, so frames are drawn one by one with a Node canvas and piped to ffmpeg;
   the embedded track is muxed as AAC with the same 0.6 s fade-out the player applies.

   Usage: NODE_PATH=<dir with node_modules/@napi-rs/canvas> node export_mp4.js BUILT_HTML --out reel.mp4
            [--mode d] [--lang en] [--fps 30] [--start 0] [--end SECONDS] [--crf 18] [--scale 1] [--no-audio] [--reduced]
   Setup (once, in a scratch folder): npm install @napi-rs/canvas      Needs ffmpeg (libx264, aac) on the PATH.
   --start/--end export a segment (handy to test a scene: --start 78 --end 82).
   Output size = the stage size of the chosen mode times --scale (even numbers are enforced for H.264).
   Limits: the canvas is Skia, not a browser, so rare canvas features can differ (CSS filters, some text shaping);
   compare one frame with the browser before delivering. Fonts embedded in the HTML are registered automatically. */
const fs = require('fs'), os = require('os'), path = require('path'), vm = require('vm'), { spawn, spawnSync } = require('child_process');
const args = process.argv.slice(2), file = args[0];
const opt = (n, d) => { const i = args.indexOf(n); return i > -1 ? args[i + 1] : d; };
if (!file || file.startsWith('--')) { console.error('usage: export_mp4.js BUILT_HTML --out reel.mp4 [--mode d] [--lang en] [--fps 30] [--start 0] [--end S] [--crf 18] [--scale 1] [--no-audio] [--reduced]'); process.exit(2); }
let canvasLib;
try { canvasLib = require('@napi-rs/canvas'); } catch (e) { console.error('Missing @napi-rs/canvas. In a scratch folder run: npm install @napi-rs/canvas, then set NODE_PATH to its node_modules.'); process.exit(2); }
const { createCanvas, GlobalFonts } = canvasLib;
if (spawnSync('ffmpeg', ['-version']).status !== 0) { console.error('ffmpeg not found on the PATH.'); process.exit(2); }

const html = fs.readFileSync(file, 'utf8');
const sandbox = { console, atob: s => Buffer.from(s, 'base64').toString('binary'), Math, Uint8Array, Array, JSON };
sandbox.window = sandbox; sandbox.globalThis = sandbox; vm.createContext(sandbox);
for (const id of ['sr-data', 'sr-core', 'sr-main']) {
  const m = new RegExp(`<script id="${id}">([\\s\\S]*?)</script>`).exec(html);
  if (!m) { console.error('missing script ' + id + ' (is this a built player page, not a contact sheet?)'); process.exit(2); }
  vm.runInContext(m[1], sandbox);
}
const S = sandbox.SHOWREEL, SR = sandbox.SR, DUR = SR.data.dur;
const mode = opt('--mode', Object.keys(S.formats)[0]), lang = opt('--lang', S.languages[0].id);
if (!S.formats[mode]) { console.error('unknown mode ' + mode + '; available: ' + Object.keys(S.formats)); process.exit(2); }
const fps = parseFloat(opt('--fps', '30')), start = parseFloat(opt('--start', '0')), end = Math.min(DUR, parseFloat(opt('--end', String(DUR))));
const crf = opt('--crf', '18'), scale = parseFloat(opt('--scale', '1')), out = opt('--out', 'reel.mp4');
const [SW, SH] = S.formats[mode], W = Math.round(SW * scale / 2) * 2, H = Math.round(SH * scale / 2) * 2;
const frames = Math.round((end - start) * fps);

// fonts embedded as data: URLs in @font-face rules
let fonts = 0;
for (const m of html.matchAll(/@font-face\{font-family:"([^"]+)";font-weight:(\d+);[^}]*?base64,([A-Za-z0-9+/=]+)\)/g)) {
  try { if (GlobalFonts.register(Buffer.from(m[3], 'base64'), m[1])) fonts++; } catch (e) { console.warn('font not registered: ' + m[1] + ' (' + e.message + ')'); }
}
// audio
let audioFile = null;
const tm = /<script type="text\/plain" id="trackdata">data:audio\/[\w-]+;base64,([A-Za-z0-9+/=]+)<\/script>/.exec(html);
if (tm && !args.includes('--no-audio')) { audioFile = path.join(os.tmpdir(), 'sr-track-' + process.pid + '.mp3'); fs.writeFileSync(audioFile, Buffer.from(tm[1], 'base64')); }

const ff = ['-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-r', String(fps), '-i', '-'];
const segDur = end - start;
if (audioFile) {
  ff.push('-ss', String(start), '-t', String(segDur), '-i', audioFile);
  if (end >= DUR - 1e-6) ff.push('-af', `afade=t=out:st=${Math.max(0, segDur - 0.6).toFixed(3)}:d=0.6`);  // same fade-out as the player, only at the real end
  ff.push('-c:a', 'aac', '-b:a', '192k');
}
ff.push('-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', crf, '-preset', 'medium', '-movflags', '+faststart', '-shortest', out);
const proc = spawn('ffmpeg', ff, { stdio: ['pipe', 'inherit', 'inherit'] });
let procErr = null; proc.on('error', e => { procErr = e; }); proc.stdin.on('error', e => { procErr = e; });
const done = new Promise(r => proc.on('close', r));

(async () => {
  if (S.setup) S.setup({ mode, lang });
  const cv = createCanvas(W, H), g = cv.getContext('2d'), t0 = Date.now();
  console.log(`exporting ${frames} frames, ${W}x${H} @ ${fps} fps, mode ${mode}, lang ${lang}, ${start}s to ${end}s, ${fonts} font(s) registered, audio ${audioFile ? 'yes' : 'no'}`);
  for (let i = 0; i < frames; i++) {
    const t = start + i / fps;
    SR.drawFrame(g, W, H, t, { mode, lang, reduced: args.includes('--reduced') });
    const buf = Buffer.from(cv.data());
    if (procErr) break;
    if (!proc.stdin.write(buf)) await new Promise(r => proc.stdin.once('drain', r));
    if (i % 300 === 0 || i === frames - 1) process.stdout.write(`\r  frame ${i + 1}/${frames}  ${(((i + 1) / ((Date.now() - t0) / 1000))).toFixed(1)} fps`);
  }
  proc.stdin.end(); const code = await done; process.stdout.write('\n');
  if (audioFile) fs.unlinkSync(audioFile);
  if (procErr || code !== 0) { console.error('ffmpeg failed', procErr ? procErr.message : 'code ' + code); process.exit(1); }
  console.log(`wrote ${out} (${(fs.statSync(out).size / 1e6).toFixed(2)} MB, ${((Date.now() - t0) / 1000).toFixed(1)} s)`);
})();
