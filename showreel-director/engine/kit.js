/* Showreel kit: style-neutral drawing helpers, loaded after core.js (same script block). Exposes window.SRK.
   It carries NO palette, font, effect choice or wording: colours, fonts and text always come from the caller.
   Everything is a pure function of its arguments (time in, pixels out), so seek, pause and loop stay exact.

   SRK.init({title: 'Family A', mono: 'Family B'})        fonts for o.f === 'title' (default) or 'mono'; any other o.f is one font family name
   SRK.text(g, str, x, y, size, color, o)                  o: {a alpha, s scale, sx, sy, rot, al align, f font key, w weight}
   SRK.width(g, str, size, f)  SRK.fit(g, str, size, maxW, f)   measure / shrink to fit a width
   SRK.letters(g, str, x, y, size, color, fn, f)           per-letter control: fn(i, n) -> {dx, dy, a, s, rot, col}
   SRK.slam(g, str, x, y, size, color, bt, startBeat, o)   arrive large and settle; o: {from, len, o: text options}
   SRK.prog(bt, startBeat, lenBeats)                       0..1 progress of something that starts at a beat
   SRK.ring(g, x, y, p, maxR, color, lineWidth)            expanding ring, p 0..1
   SRK.rect(g, x, y, w, h, color, alpha)  SRK.stroke(g, x, y, w, h, color, lineWidth, alpha)
   SRK.tick(g, x, y, size, p, color, lineWidth)            check mark drawn progressively
   SRK.shake(list, bt, reduced) -> [dx, dy]                list of [beat, amplitude] hits; apply with g.translate; [0, 0] when reduced
   SRK.flash(list, bt, reduced) -> alpha 0..1              list of [beat, strength]; draw a full-frame rect with it; 0 when reduced
   Reduced motion: pass ctx.reduced (set by the player from prefers-reduced-motion or its toggle) to shake and flash, give slam o.reduced so it
   fades in without the oversize scale, and skip or soften other strong motion (strobing, big scale jumps, particles) in your own scenes.
   SRK.scramble(str, p, seed, glyphs)                      text resolving from random glyphs, p 0..1
   SRK.confetti(g, W, H, seconds, palette, o)              two corner cannons, then a rain; palette = array of colours;
                                                           o: {count, life, wave2At, cannons: false to skip, mobile}
   SRK.hash(n, seed)  SRK.back(t)  SRK.ex(t)               deterministic noise, overshoot ease, exponential ease-out
   Keep any celebration effect (confetti) to one moment per film. */
(function (G) {
  'use strict';
  const SR = G.SR, clamp = SR.clamp, lerp = SR.lerp;
  const cfg = { title: 'sans-serif', mono: 'monospace' };
  const hash = (n, s = 0) => { const x = Math.sin(n * 127.1 + s * 311.7) * 43758.5453; return x - Math.floor(x); };
  const back = t => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
  const ex = SR.ease.outExpo;
  const fam = f => f === 'mono' ? cfg.mono : (!f || f === 'title') ? cfg.title : f;
  const font = (size, f, w) => (w || 700) + ' ' + size + 'px ' + '"' + String(fam(f)).replace(/"/g, '') + '",sans-serif';

  function init(o) { Object.assign(cfg, o || {}); }

  function width(g, s, size, f) { g.font = font(size, f); return g.measureText(s).width; }
  function fit(g, s, size, maxW, f) { const w = width(g, s, size, f); return w > maxW ? size * maxW / w : size; }

  function text(g, s, x, y, size, col, o = {}) {
    g.save(); g.translate(x, y); if (o.rot) g.rotate(o.rot);
    g.scale(o.sx != null ? o.sx : (o.s == null ? 1 : o.s), o.sy != null ? o.sy : (o.s == null ? 1 : o.s));
    g.globalAlpha = o.a == null ? 1 : o.a; g.font = font(size, o.f, o.w);
    g.textAlign = o.al || 'center'; g.textBaseline = 'middle'; g.fillStyle = col; g.fillText(s, 0, 0); g.restore();
  }

  function letters(g, s, x, y, size, col, fn, f) {
    const tot = width(g, s, size, f); let cx = x - tot / 2;
    for (let i = 0; i < s.length; i++) {
      const a = width(g, s.slice(0, i), size, f), b = width(g, s.slice(0, i + 1), size, f), r = fn(i, s.length) || {};
      text(g, s[i], cx + a + (b - a) / 2 + (r.dx || 0), y + (r.dy || 0), size, r.col || col, { a: r.a, s: r.s, rot: r.rot, f });
    }
  }

  const prog = (bt, b, len) => clamp((bt - b) / (len || .5));

  function slam(g, s, x, y, size, col, bt, b, o = {}) {
    if (bt < b) return; const p = prog(bt, b, o.len || .45);
    text(g, s, x, y, size, col, Object.assign({ s: o.reduced ? 1 : lerp(o.from || 2.6, 1, ex(p)), a: clamp(p * (o.reduced ? 3 : 6)) }, o.o || {}));
  }

  function ring(g, x, y, p, maxR, col, lw) {
    if (p <= 0 || p >= 1) return;
    g.save(); g.strokeStyle = col; g.globalAlpha = 1 - p; g.lineWidth = (lw || 10) * (1 - p) + 1; g.beginPath(); g.arc(x, y, ex(p) * maxR, 0, 7); g.stroke(); g.restore();
  }
  function rect(g, x, y, w, h, col, a) { g.save(); g.globalAlpha = a == null ? 1 : a; g.fillStyle = col; g.fillRect(x, y, w, h); g.restore(); }
  function stroke(g, x, y, w, h, col, lw, a) { g.save(); g.globalAlpha = a == null ? 1 : a; g.strokeStyle = col; g.lineWidth = lw || 2; g.strokeRect(x, y, w, h); g.restore(); }

  function tick(g, x, y, s, p, col, lw) {
    g.save(); g.strokeStyle = col; g.lineWidth = lw || 8; g.lineCap = 'round'; g.lineJoin = 'round'; g.beginPath();
    const a = [x - s * .5, y], b = [x - s * .15, y + s * .38], c = [x + s * .55, y - s * .42];
    if (p > 0) {
      g.moveTo(a[0], a[1]); const q = clamp(p / .4); g.lineTo(lerp(a[0], b[0], q), lerp(a[1], b[1], q));
      if (p > .4) { const r = clamp((p - .4) / .6); g.lineTo(lerp(b[0], c[0], r), lerp(b[1], c[1], r)); }
    }
    g.stroke(); g.restore();
  }

  function shake(list, bt, reduced) {
    if (reduced) return [0, 0];
    let dx = 0, dy = 0; (list || []).forEach(([b, a]) => {
      const d = bt - b; if (d < 0 || d > 2) return; const k = Math.exp(-d * 5) * a, q = Math.floor(d * 40);
      dx += (hash(q, b) - .5) * 2 * k; dy += (hash(q, b + 9) - .5) * 2 * k;
    }); return [dx, dy];
  }
  function flash(list, bt, reduced) {
    if (reduced) return 0;
    let m = 0; (list || []).forEach(([b, a]) => { const d = bt - b; if (d >= 0 && d < .5) m = Math.max(m, a * (1 - d / .5)); }); return m;
  }

  function scramble(s, p, seed, glyphs) {
    const G_ = glyphs || '#%&@$*+=?', done = clamp(p);
    return [...s].map((ch, i) => /[\s.,;:!?'-]/.test(ch) || done > i / s.length ? ch : G_[Math.floor(hash(i, Math.floor(p * 40) + (seed || 0)) * G_.length)]).join('');
  }

  // Confetti as a pure function of seconds since the cannons fire.
  function confetti(g, W, H, ts, palette, o = {}) {
    if (ts < 0 || !palette || !palette.length) return;
    const N = o.count || (o.mobile ? 170 : 260), k = 1.6, g0 = o.mobile ? 1500 : 1900, w2 = o.wave2At == null ? 1.45 : o.wave2At;
    for (let i = 0; i < N; i++) {
      const wave = (o.cannons === false || i >= N * .65) ? 1 : 0, t = ts - (wave ? w2 : hash(i, 11) * .12); if (t < 0) continue;
      const life = o.life || (wave ? 2.6 : 3.4), q = t / life; if (q > 1) continue;
      const dr = (1 - Math.exp(-k * t)) / k; let px, py;
      if (!wave) {
        const side = i % 2 ? 1 : -1, ang = .55 + hash(i) * .85, v = (o.mobile ? 1500 : 2300) + hash(i, 2) * (o.mobile ? 1500 : 2300);
        px = (side > 0 ? W + 30 : -30) - side * Math.cos(ang) * v * dr;
        py = H + 30 - Math.sin(ang) * v * dr + g0 * .5 * t * t * .55 + Math.sin(t * 5 + i) * 14 * t;
      } else {
        px = hash(i, 4) * W + Math.sin(t * 4 + i) * 40; py = -40 + (260 + hash(i, 5) * 260) * t + 120 * t * t;
      }
      const w = 14 + hash(i, 6) * 18, h = 7 + hash(i, 7) * 9, flip = Math.cos(t * (6 + hash(i, 8) * 8) + i);
      g.save(); g.translate(px, py); g.rotate(t * 5 * (hash(i, 3) - .5) * 4); g.scale(1, flip);
      g.globalAlpha = q > .8 ? (1 - q) / .2 : 1; g.fillStyle = palette[i % palette.length]; g.fillRect(-w / 2, -h / 2, w, h); g.restore();
    }
  }

  G.SRK = { init, hash, back, ex, width, fit, text, letters, prog, slam, ring, rect, stroke, tick, shake, flash, scramble, confetti };
})(typeof window !== 'undefined' ? window : globalThis);
