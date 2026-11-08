#!/usr/bin/env node
/* Pixel test of the film layer (engine/film.js): does a transition really draw two scenes at once, and is the output the same on every run?
   Usage: NODE_PATH=<dir with node_modules/@napi-rs/canvas> node test_film.js BUILT_HTML [--mode d] [--all [--min-working N]] [--quiet]
   Default: for every transition of the built film, a frame in the middle of the transition is rendered with a real canvas (Skia); it must hold pixels that
   belong to the outgoing scene only and pixels that belong to the incoming scene only (colours found by drawing each scene alone), twice the same bytes in this process;
   a SHA-256 of each frame is printed on a `digest` line so two runs (two processes) can be compared.
   --all: takes the first two scenes of the built film (real scene modules) and puts every transition of the catalogue (SRT.list) between them. For each it
   checks no exception, that the start of the transition equals the outgoing scene and the end equals the incoming one (within a small tolerance), that the frames
   change in between, and whether both scenes are visible together at some point. Prints one line per transition and a summary.
   The built page must come from a project whose main.js uses SRF (the build then inlines engine/film.js and engine/transitions.js).
   Exit code 1 when a check fails. With --all it fails only when fewer than --min-working transitions run (default 0: report only); a transition that shows only
   one scene is reported, not failed. Needs @napi-rs/canvas. */
const crypto = require('crypto');
const { makeOpt, loadReel } = require('./_reel');
const args = process.argv.slice(2), file = args[0], opt = makeOpt(args);
if (!file || file.startsWith('--')) { console.error('usage: test_film.js BUILT_HTML [--mode d] [--all] [--quiet]'); process.exit(2); }
let lib;
try { lib = require('@napi-rs/canvas'); } catch (e) { console.error('Missing @napi-rs/canvas (set NODE_PATH to a node_modules that has it).'); process.exit(2); }
const { S, SR, sandbox } = loadReel(file, null, (w, h) => lib.createCanvas(w, h));
if (!sandbox.SRF || !sandbox.SRT) { console.error('this page has no film layer: main.js must use SRF'); process.exit(2); }
const mode = opt('--mode', Object.keys(S.formats)[0]), [SW, SH] = S.formats[mode];
const W = 320, H = Math.round(320 * SH / SW), lang = S.languages[0].id;
const fails = []; const say = (...a) => { if (!args.includes('--quiet')) console.log(...a); };
const ok = (cond, msg) => { if (!cond) { fails.push(msg); console.log('FAIL ' + msg); } else say('PASS ' + msg); };

function frame(render, t) {
  const c = lib.createCanvas(W, H), g = c.getContext('2d');
  S.render = render; if (S.setup) S.setup({ mode, lang });
  SR.drawFrame(g, W, H, t, { mode, lang, reduced: false, music: false });
  return g.getImageData(0, 0, W, H).data;
}
const q = (d, i) => ((d[i] >> 4) << 8) | ((d[i + 1] >> 4) << 4) | (d[i + 2] >> 4);
const hist = d => { const h = new Map(); for (let i = 0; i < d.length; i += 4) h.set(q(d, i), (h.get(q(d, i)) || 0) + 1); return h; };
const share = (h, set, n) => { let s = 0; for (const k of set) s += h.get(k) || 0; return s / n; };
// colours that one scene shows (at least 1% of the frame) and the other does not (under 0.2%)
function only(ha, hb, n) { const out = new Set(); for (const [k, v] of ha) if (v / n >= .01 && (hb.get(k) || 0) / n < .002) out.add(k); return out; }
const diff = (a, b) => { let n = 0; for (let i = 0; i < a.length; i += 4) if (Math.abs(a[i] - b[i]) + Math.abs(a[i + 1] - b[i + 1]) + Math.abs(a[i + 2] - b[i + 2]) > 48) n++; return n / (a.length / 4); };
const sha = d => crypto.createHash('sha256').update(Buffer.from(d.buffer, d.byteOffset, d.length)).digest('hex').slice(0, 16);
const N = W * H;

function cutFilm(scenes, palette) { return sandbox.SRF.film({ palette, scenes: scenes.map(s => ({ name: s.name, t: s.s, render: s.render })) }); }

if (!args.includes('--all')) {
  const cur = sandbox.SRF.current, wins = cur.windows;
  ok(wins.length > 0, 'the film has ' + wins.length + ' transition(s) to test');
  const real = cur.render, scenes = cur.scenes, pal = cur.palette;
  const cut = cutFilm(scenes, pal).render;
  let digests = [];
  for (const w of wins) {
    const mid = (w.start + w.end) / 2;
    const A = scenes[w.from], B = scenes[w.to];
    const ta = Math.max(A.s, w.start - .05), tb = Math.min(B.e - .01, w.end + .05);
    const fa = frame(cut, ta), fb = frame(cut, tb);           // each scene alone, just outside the transition
    const ha = hist(fa), hb = hist(fb), onlyA = only(ha, hb, N), onlyB = only(hb, ha, N);
    ok(onlyA.size > 0 && onlyB.size > 0, `${A.name} and ${B.name} each have colours of their own`);
    const m1 = frame(real, mid), m2 = frame(real, mid), hm = hist(m1);
    const sa = share(hm, onlyA, N), sb = share(hm, onlyB, N);
    ok(sa >= .03 && sb >= .03, `${w.type} ${A.name} -> ${B.name} at ${mid.toFixed(2)} s draws both scenes: ${(sa * 100).toFixed(0)}% outgoing pixels, ${(sb * 100).toFixed(0)}% incoming pixels`);
    ok(Buffer.compare(Buffer.from(m1), Buffer.from(m2)) === 0, `${w.type} frame is identical when drawn twice`);
    const before = frame(real, w.start - .02), after = frame(real, w.end + .02);
    ok(diff(before, frame(cut, w.start - .02)) < .001 && diff(after, frame(cut, w.end + .02)) < .001, `${w.type}: outside the transition the scenes are drawn as they are`);
    digests.push(sha(m1));
  }
  // a frame outside every transition equals the same film drawn with cuts only (the layer adds nothing)
  console.log('digest ' + digests.join(' '));
} else {
  const base = sandbox.SRF.current, scenes = base.scenes.slice(0, 2).map(s => ({ name: s.name, s: 0, render: s.render }));
  if (scenes.length < 2) { console.error('--all needs a film with two scenes'); process.exit(2); }
  scenes[0].s = 0; scenes[1].s = 3;
  const pal = base.palette, cut = cutFilm(scenes, pal).render;
  const names = sandbox.SRT.list.map(x => x.name), PS = [.02, .15, .3, .5, .7, .85, .98], D = 1.2;
  let works = 0, both = 0; const lines = [];
  for (const name of names) {
    let why = '', bestBoth = 0, moved = false, prev = null;
    try {
      const f = sandbox.SRF.film({ palette: pal, scenes: [{ name: scenes[0].name, t: 0, render: scenes[0].render, transition: { type: name, duration: D } }, { name: scenes[1].name, t: 3, render: scenes[1].render }] });
      const start = 3 - D / 2;
      for (const p of PS) {
        const t = start + p * D, fr = frame(f.render, t), pure = frame(cut, t);
        const hp = hist(fr);
        const fa = frame(cut, start - .05), fb = frame(cut, 3 + D / 2 + .05), ha = hist(fa), hb = hist(fb);
        bestBoth = Math.max(bestBoth, Math.min(share(hp, only(ha, hb, N), N), share(hp, only(hb, ha, N), N)));
        if (prev && diff(prev, fr) > .002) moved = true; prev = fr;
        if (p === PS[0] && diff(fr, pure) > .06) why = 'start differs from the outgoing scene (' + (100 * diff(fr, pure)).toFixed(0) + '%)';
        if (p === PS[PS.length - 1]) { const pureB = frame(cut, t); if (diff(fr, pureB) > .06) why = why || 'end differs from the incoming scene (' + (100 * diff(fr, pureB)).toFixed(0) + '%)'; }
      }
      if (!moved) why = why || 'the frames do not change over the transition';
    } catch (e) { why = 'EXCEPTION ' + e.message; }
    const good = !why; if (good) works++; if (good && bestBoth >= .03) both++;
    lines.push(`${good ? 'ok  ' : 'FAIL'} ${name.padEnd(24)} both scenes visible: ${(bestBoth * 100).toFixed(0).padStart(3)}%${why ? '  ' + why : ''}`);
  }
  lines.forEach(l => console.log(l));
  console.log(`transitions that run between two real scenes: ${works} of ${names.length} (start = outgoing scene, end = incoming scene, no exception, the frames move)`);
  console.log(`transitions that show both scenes together at some point (3% or more of each): ${both} of ${names.length}`);
  const need = parseInt(opt('--min-working', '0'));
  if (works < need) fails.push(works + ' transitions run, ' + need + ' expected');
}
console.log(fails.length ? fails.length + ' check(s) failed' : 'film test passed');
process.exit(fails.length ? 1 : 0);
