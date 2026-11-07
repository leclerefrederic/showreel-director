#!/usr/bin/env node
/* Headless test: renders the whole timeline in every format and language with a Proxy canvas stub.
   Usage: node harness.js BUILT_HTML [--step 0.25] [--modes d,m] [--langs en,fr] [--reduced]
   --reduced renders with ctx.reduced = true (reduced-motion mode) to check that path too.
   Reports: exceptions, non-finite values in drawing calls, text drawn outside the stage (tracks translate/scale/save/restore,
   skips rotated text), text collisions (two texts overlapping for 3+ consecutive samples; widths are estimated, so treat as leads),
   strings drawn per scene (spot untranslated text), near-empty frames.
   It cannot judge looks: still look at contact sheets. */
const fs = require('fs'), vm = require('vm');
const args = process.argv.slice(2), file = args[0];
const opt = (n, d) => { const i = args.indexOf(n); return i > -1 ? args[i + 1] : d; };
const step = parseFloat(opt('--step', '0.25'));
const html = fs.readFileSync(file, 'utf8');
const sandbox = { console, atob: s => Buffer.from(s, 'base64').toString('binary'), Math, Uint8Array, Array, JSON };
sandbox.window = sandbox; sandbox.globalThis = sandbox; vm.createContext(sandbox);
for (const id of ['sr-data', 'sr-core', 'sr-main']) {
  const m = new RegExp(`<script id="${id}">([\\s\\S]*?)</script>`).exec(html);
  if (!m) { console.error('missing script ' + id); process.exit(2); }
  vm.runInContext(m[1], sandbox);
}
const S = sandbox.SHOWREEL, SR = sandbox.SR, DUR = SR.data.dur;
const modes = opt('--modes', Object.keys(S.formats).join(',')).split(','), langs = opt('--langs', S.languages.map(l => l.id).join(',')).split(',');
const overlapRun = {}; let issues = [], strings = {}, empty = 0, frames = 0, cur = '', seen = new Set(), stageRect = null;
const mul = (m, n) => [m[0] * n[0] + m[2] * n[1], m[1] * n[0] + m[3] * n[1], m[0] * n[2] + m[2] * n[3], m[1] * n[2] + m[3] * n[3], m[0] * n[4] + m[2] * n[5] + m[4], m[1] * n[4] + m[3] * n[5] + m[5]];
function mkCtx() {
  let ops = 0, M = [1, 0, 0, 1, 0, 0], stack = []; const texts = [];
  const target = { globalAlpha: 1, font: '10px sans-serif', textAlign: 'left' };
  const p = new Proxy(target, {
    get(_, k) {
      if (k === 'measureText') return s => { const m = /(\d+(?:\.\d+)?)px/.exec(target.font || ''); return { width: String(s).length * (m ? +m[1] : 16) * .55 }; };
      if (k === 'canvas') return { width: 1600, height: 900 };
      if (k === '__ops') return ops;
      if (k === '__texts') return texts;
      if (k === 'save') return () => { ops++; stack.push({ M: M.slice(), a: target.globalAlpha }); };
      if (k === 'restore') return () => { ops++; const s = stack.pop(); if (s) { M = s.M; target.globalAlpha = s.a; } };
      if (k === 'translate') return (x, y) => { ops++; M = mul(M, [1, 0, 0, 1, x, y]); };
      if (k === 'scale') return (x, y) => { ops++; M = mul(M, [x, 0, 0, y, 0, 0]); };
      if (k === 'rotate') return a => { ops++; const c = Math.cos(a), s = Math.sin(a); M = mul(M, [c, s, -s, c, 0, 0]); };
      if (k === 'setTransform') return (a, b, c, d, e, f) => { ops++; M = [a, b, c, d, e, f]; };
      if (k === 'resetTransform') return () => { ops++; M = [1, 0, 0, 1, 0, 0]; };
      if (k in target) return target[k];
      return (...a) => {
        ops++;
        for (const v of a) if (typeof v === 'number' && !isFinite(v)) issues.push(`${cur}: ${String(k)}(${a.join(',')}) has non-finite value`);
        if ((k === 'fillText' || k === 'strokeText') && typeof a[0] === 'string') {
          const [sc, rest] = cur.split('|'), key = rest.split(' ')[0];
          (strings[sc] = strings[sc] || new Set()).add(`${key}: ${a[0]}`);
          const al = target.globalAlpha, fs0 = /(\d+(?:\.\d+)?)px/.exec(target.font || ''), sx = Math.hypot(M[0], M[1]);
          if (al > .08 && Math.abs(M[1]) < 1e-6 && Math.abs(M[2]) < 1e-6 && stageRect && sx > 0) {
            const w = String(a[0]).length * (fs0 ? +fs0[1] : 16) * .55 * sx;
            const x = M[0] * a[1] + M[4]; const left = target.textAlign === 'center' ? x - w / 2 : target.textAlign === 'right' ? x - w : x;
            const fsz = (fs0 ? +fs0[1] : 16) * Math.abs(M[3]), yy = M[3] * a[2] + M[5], bl = target.textBaseline || 'alphabetic';
            const top = bl === 'middle' ? yy - fsz * .375 : bl === 'top' ? yy : bl === 'bottom' ? yy - fsz * .75 : yy - fsz * .75;
            if (al > .5 && String(a[0]).trim()) texts.push({ s: String(a[0]), l: left, r: left + w, t: top, b: top + fsz * .75 });
            if (left < stageRect.l - 2 || left + w > stageRect.r + 2) {
              const id = `${sc}|${key}|${a[0]}`; if (!seen.has(id)) { seen.add(id); issues.push(`${cur}: text outside stage "${a[0]}" (${Math.round(left - stageRect.l)}..${Math.round(left + w - stageRect.r)} px)`); }
            }
          }
        }
        if (k === 'createLinearGradient' || k === 'createRadialGradient') return { addColorStop() {} };
        return undefined;
      };
    },
    set(_, k, v) { target[k] = v; return true; }
  });
  return p;
}
for (const mode of modes) for (const lang of langs) {
  if (S.setup) S.setup({ mode, lang });
  const f = S.formats[mode], W = f[0], H = f[1], g = mkCtx();
  stageRect = { l: 0, r: W };  // canvas == stage size in the harness (letterbox is identity)
  for (let t = 0; t <= DUR; t += step) {
    const sc = SR.sceneAt(t); cur = `${sc ? sc.scene.name : '-'}|${lang}/${mode} t=${t.toFixed(2)}`;
    const before = g.__ops;
    try { SR.drawFrame(g, W, H, t, { mode, lang, reduced: args.includes('--reduced') }); } catch (e) { issues.push(`${cur}: EXCEPTION ${e.message}`); }
    frames++; if (g.__ops - before < 4) empty++;
    const T = g.__texts, hit = new Set();
    for (let i = 0; i < T.length; i++) for (let j = i + 1; j < T.length; j++) {
      const A = T[i], B = T[j]; if (A.s === B.s) continue;
      const ox = Math.min(A.r, B.r) - Math.max(A.l, B.l), oy = Math.min(A.b, B.b) - Math.max(A.t, B.t);
      if (ox > 0 && oy > 0 && ox * oy > .35 * Math.min((A.r - A.l) * (A.b - A.t), (B.r - B.l) * (B.b - B.t))) {
        const key = `${lang}/${mode}|${sc ? sc.scene.name : '-'}|${A.s}|${B.s}`; hit.add(key); overlapRun[key] = (overlapRun[key] || 0) + 1;
        if (overlapRun[key] === 3) issues.push(`${cur}: text collision "${A.s}" over "${B.s}"`);
      }
    }
    for (const k of Object.keys(overlapRun)) if (!hit.has(k)) overlapRun[k] = 0;
    T.length = 0;
  }
}
console.log(`frames rendered: ${frames}  (modes ${modes}, langs ${langs}, step ${step}s, duration ${DUR}s)`);
console.log(`issues: ${issues.length}`); issues.slice(0, 30).forEach(i => console.log('  ' + i));
console.log(`near-empty frames: ${empty}`);
console.log('strings per scene:'); for (const [sc, set] of Object.entries(strings)) console.log(`  ${sc}: ${[...set].slice(0, 6).join(' / ')}${set.size > 6 ? ' …' : ''}`);
process.exit(issues.length ? 1 : 0);
