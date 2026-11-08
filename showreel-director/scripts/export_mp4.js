#!/usr/bin/env node
/* Export a built reel (dist/index.html) to MP4 without a browser.
   Every frame is a pure function of time, so frames are drawn one by one with a Node canvas and piped to ffmpeg;
   the embedded track is muxed as AAC with the same 0.6 s fade-out the player applies.

   Usage: NODE_PATH=<dir with node_modules/@napi-rs/canvas> node export_mp4.js BUILT_HTML [--out FILE]   (default FILE: <slug>_<vN>_<mode>_<lang>.mp4 next to BUILT_HTML)
            [--mode d] [--lang en] [--fps 30] [--start 0] [--end SECONDS] [--crf 18] [--scale 1] [--no-audio] [--reduced]
   --stills t1,t2,... [--cols 3 --tile 480 --out grid.png --stills-report] writes one PNG with frames at those times and exits (no ffmpeg needed).
   Setup (once, in a scratch folder): npm install @napi-rs/canvas      Needs ffmpeg (libx264, aac) on the PATH.
   --start/--end export a segment (handy to test a scene: --start 78 --end 82).
   Output size = the stage size of the chosen mode times --scale (even numbers are enforced for H.264).
   Limits: the canvas is Skia, not a browser, so rare canvas features can differ (CSS filters, some text shaping);
   compare one frame with the browser before delivering. Fonts embedded in the HTML are registered automatically. */
const fs = require('fs'), os = require('os'), path = require('path'), { spawn, spawnSync } = require('child_process');
const { makeOpt, loadReel, registerFonts } = require('./_reel');
const args = process.argv.slice(2), file = args[0], opt = makeOpt(args);
if (!file || file.startsWith('--')) { console.error('usage: export_mp4.js BUILT_HTML [--out FILE] [--mode d] [--lang en] [--fps 30] [--start 0] [--end S] [--crf 18] [--scale 1] [--no-audio] [--reduced] | --stills t1,t2,...'); process.exit(2); }
let canvasLib;
try { canvasLib = require('@napi-rs/canvas'); } catch (e) { console.error('Missing @napi-rs/canvas. In a scratch folder run: npm install @napi-rs/canvas, then set NODE_PATH to its node_modules.'); process.exit(2); }
const { createCanvas, GlobalFonts } = canvasLib;
if (!args.includes('--stills') && spawnSync('ffmpeg', ['-version']).status !== 0) { console.error('ffmpeg not found on the PATH.'); process.exit(2); }

// embedded images (project.json "images") are decoded with the canvas library, so MP4 frames match the browser
// (decoding is asynchronous in the canvas library, so every image is preloaded before the first frame)
const PRE = new Map();
const { html, S, SR, DUR } = loadReel(file, uri => PRE.get(uri) || null);
const mode = opt('--mode', Object.keys(S.formats)[0]), lang = opt('--lang', S.languages[0].id);
if (!S.formats[mode]) { console.error('unknown mode ' + mode + '; available: ' + Object.keys(S.formats)); process.exit(2); }
const fps = parseFloat(opt('--fps', '30')), start = parseFloat(opt('--start', '0')), end = Math.min(DUR, parseFloat(opt('--end', String(DUR))));
const crf = opt('--crf', '18'), scale = parseFloat(opt('--scale', '1'));
// default name: <slug>_<vN>_<mode>_<lang>.mp4 next to the built page (slug from the reel title, vN from the version folder)
const slug = String(S.slug || ((S.title && (S.title[lang] || S.title.en)) || 'reel')).normalize('NFKD').replace(/[^\x00-\x7f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40).replace(/-$/, '') || 'reel';
const ver = (path.resolve(file).split(path.sep).slice(-3, -2)[0] || 'v1') + (SR.data.cut ? '-' + SR.data.cut : '');
const out = opt('--out', path.join(path.dirname(path.resolve(file)), `${slug}_${ver}_${mode}_${lang}${(args.includes('--start') || args.includes('--end')) ? '_' + start + '-' + end + 's' : ''}${args.includes('--reduced') ? '_reduced' : ''}.mp4`));
const [SW, SH] = S.formats[mode], W = Math.round(SW * scale / 2) * 2, H = Math.round(SH * scale / 2) * 2;
const frames = Math.round((end - start) * fps);

// fonts embedded as data: URLs in @font-face rules
const fonts = registerFonts(html, GlobalFonts);
const preload = async () => { for (const uri of Object.values((SR.data && SR.data.images) || {})) PRE.set(uri, await canvasLib.loadImage(Buffer.from(uri.split(',')[1] || '', 'base64'))); };
// stills: a PNG grid of frames at chosen times, to look at a reel without a browser (also finds overflow the harness cannot see)
if (opt('--stills', null)) { (async () => {
  await preload();
  const times = opt('--stills').split(',').map(Number), cols = parseInt(opt('--cols', String(Math.min(3, times.length)))), tw = parseInt(opt('--tile', '480'));
  const th = Math.round(tw * SH / SW), rows = Math.ceil(times.length / cols), lab = 22;
  const sheet = createCanvas(cols * tw, rows * (th + lab)), sg = sheet.getContext('2d'); sg.fillStyle = '#1d1d1d'; sg.fillRect(0, 0, sheet.width, sheet.height);
  if (S.setup) S.setup({ mode, lang });
  times.forEach((t, i) => {
    const c = createCanvas(tw, th), g2 = c.getContext('2d'); SR.drawFrame(g2, tw, th, t, { mode, lang, reduced: args.includes('--reduced') });
    const x = (i % cols) * tw, y = Math.floor(i / cols) * (th + lab); sg.drawImage(c, x, y);
    const a = SR.sceneAt(t); sg.fillStyle = '#ccc'; sg.font = '13px sans-serif'; sg.fillText(`${mode}/${lang} t=${t.toFixed(1)} ${a && a.scene ? (a.scene.id || a.scene.name || '') : ''}`, x + 4, y + th + 15);
  });
  if (args.includes('--stills-report')) {  // objective numbers for each tile, for sessions that cannot look at the PNG
    times.forEach(t => { const c = createCanvas(tw, th), g2 = c.getContext('2d'); SR.drawFrame(g2, tw, th, t, { mode, lang, reduced: args.includes('--reduced') });
      const d = g2.getImageData(0, 0, tw, th).data; const cs = [[4, 4], [tw - 5, 4], [4, th - 5], [tw - 5, th - 5]].map(([x, y]) => { const i = (y * tw + x) * 4; return [d[i], d[i + 1], d[i + 2]]; }); const bg = cs.sort((p, q) => cs.filter(r => r.join() === q.join()).length - cs.filter(r => r.join() === p.join()).length)[0];  // background = most common colour of the four inner corners (the 1 px letterbox strip is ignored)
       let ink = 0, x0 = tw, y0 = th, x1 = -1, y1 = -1, edge = 0;
      for (let y = 0; y < th; y++) for (let x = 0; x < tw; x++) { const i = (y * tw + x) * 4; if (Math.abs(d[i] - bg[0]) + Math.abs(d[i + 1] - bg[1]) + Math.abs(d[i + 2] - bg[2]) > 40) { ink++; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; if (x < 2 || y < 2 || x >= tw - 2 || y >= th - 2) edge++; } }
      const a = SR.sceneAt(t); console.log(`t=${t.toFixed(1)} ${a && a.scene ? (a.scene.id || a.scene.name || '') : ''}: content ${(100 * ink / (tw * th)).toFixed(1)}% of the frame, box x ${(x1 < 0 ? '-' : (x0 / tw).toFixed(2) + '..' + (x1 / tw).toFixed(2))} y ${(y1 < 0 ? '-' : (y0 / th).toFixed(2) + '..' + (y1 / th).toFixed(2))}${x1 < 0 ? ' EMPTY FRAME' : ''}${edge > 0 ? ' content touches the frame edge (' + edge + ' px)' : ''}`); });
  }
  const outp = opt('--out', path.join(path.dirname(path.resolve(file)), 'stills.png')); fs.writeFileSync(outp, sheet.toBuffer('image/png')); console.log('wrote ' + outp + ' (' + times.length + ' stills)'); process.exit(0);
  })(); return;
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
  await preload(); if (S.setup) S.setup({ mode, lang });
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
