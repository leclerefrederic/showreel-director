#!/usr/bin/env node
/* Smoke test of the player UI in jsdom (needs: npm i jsdom in a scratch dir, run with NODE_PATH).
   Usage: NODE_PATH=/path/to/node_modules node smoke_player.js BUILT_HTML
   Add --release to fail when the review notes pad is still in the build.
   Checks: overlay buttons, start silent, clock advances, pause/seek/replay/lang/format controls, no console errors. */
const { JSDOM, VirtualConsole } = require('jsdom'); const fs = require('fs');
const errors = []; const vc = new VirtualConsole(); vc.on('jsdomError', e => errors.push(e.message)); vc.on('error', e => errors.push(String(e)));
const dom = new JSDOM(fs.readFileSync(process.argv[2], 'utf8'), { runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  beforeParse(w) {
    const ctx = new Proxy({}, { get: (t, k) => k in t ? t[k] : (k === 'measureText' ? s => ({ width: String(s).length * 8 }) : () => undefined), set: (t, k, v) => (t[k] = v, true) });
    w.HTMLCanvasElement.prototype.getContext = () => ctx;
    w.HTMLCanvasElement.prototype.getBoundingClientRect = () => ({ width: 800, height: 450 });
    w.matchMedia = () => ({ matches: false });
  } });
const w = dom.window, $ = id => w.document.getElementById(id); const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const out = []; const ok = (n, c) => out.push((c ? 'PASS ' : 'FAIL ') + n);
  await sleep(200);
  ok('overlay shown with start buttons', $('ov').style.display !== 'none' && $('ov2').textContent.length > 0);
  ok('language buttons built', w.SHOWREEL.languages.length < 2 || $('ovl').children.length === w.SHOWREEL.languages.length);
  $('ov2').click(); await sleep(700);
  ok('overlay hidden after start', $('ov').style.display === 'none');
  ok('time label advances', /^0:0[0-9] \//.test($('tm').textContent) && $('tm').textContent !== '0:00 / 0:00');
  $('pp').click(); const t1 = $('tm').textContent; await sleep(500);
  ok('pause freezes the clock', $('tm').textContent === t1);
  $('seek').value = 100; $('seek').dispatchEvent(new w.Event('input')); await sleep(100);
  ok('seek moves the clock', /0:10/.test($('tm').textContent));
  if ($('rm') && $('rm').style.display !== 'none') {
    let seen = null; const r0 = w.SHOWREEL.render; w.SHOWREEL.render = (g, t, c) => { seen = c.reduced; return r0(g, t, c); };
    const before = $('rm').textContent; $('rm').click(); await sleep(120);
    ok('reduced-motion toggle changes the label', $('rm').textContent !== before);
    ok('ctx.reduced reaches render()', seen === true);
    $('rm').click(); await sleep(120); w.SHOWREEL.render = r0;
  }
  if (process.argv.includes('--release')) ok('release build has no notes pad', !$('nt'));
  if ($('nt')) {
    $('nt').click(); await sleep(80);
    ok('notes pad opens and pauses', !!$('pad') && $('pad').style.display !== 'none');
    $('padtx').value = 'test note'; $('padadd').click();
    ok('note is recorded with time, scene and format', /\[\d+:\d\d\.\d · .+ · \w+\/\w+\] test note/.test($('padls').textContent));
    $('padx').click();
  }
  if ($('lg').style.display !== 'none') { $('lg').click(); ok('language switch does not throw', true); }
  if ($('fm').style.display !== 'none') { $('fm').click(); ok('format switch does not throw', true); }
  ok('no script errors', errors.length === 0); if (errors.length) console.log(errors.slice(0, 5));
  console.log(out.join('\n')); process.exit(out.some(l => l.startsWith('FAIL')) ? 1 : 0);
})();
