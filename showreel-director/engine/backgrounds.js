/* Procedural backgrounds: window.SRB. Style-neutral library: every background is drawn from the palette passed in, nothing is hard-coded.
   SRB.draw(id, g, W, H, t, pal, o): pal = {bg, fg, accent, accent2}; t = seconds (only the animated ones use it); o.reduced = true freezes
   them at t = 0 (no motion). Backgrounds never flash. Music reaction (optional, a guard rail, never a rule): o.sig = SR.signals(ctx) = {pulse, energy, ...} and o.mood
   ('punch' | 'playful' | 'tech' | 'clean' | 'cinematic' | 'deadpan', SRB.moodFor(effects pack name)) make animated backgrounds breathe or bounce with the track; with no
   signals (no music, muted, reduced motion) nothing reacts. Reactions change size, position and softness only, never brightness flashes, and stay pure functions of t. SRB.list holds {id, family, name, desc, animated} (families: Solid, Gradient,
   Pattern, Texture, Animated). Add one with add(id, family, name, desc, animated, fn). Used by the background picker, the look board and reels (main.js calls SRB.draw). */
(function () {
  const SRB = { list: [], fns: {} };
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const hex = c => { c = c.replace('#', ''); if (c.length === 3) c = c.split('').map(x => x + x).join(''); return [0, 2, 4].map(i => parseInt(c.slice(i, i + 2), 16)); };
  const rgba = (c, a) => { const [r, g, b] = hex(c); return `rgba(${r},${g},${b},${a})`; };
  const mix = (a, b, t) => { const A = hex(a), B = hex(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join(''); };
  const hs = (a, b = 0) => { const x = Math.sin(a * 127.1 + b * 311.7) * 43758.5453; return x - Math.floor(x); };
  const fill = (g, W, H, c) => { g.fillStyle = c; g.fillRect(0, 0, W, H); };
  const a2 = p => p.accent2 || p.accent;
  const MOODS = { punch: 1, playful: .7, tech: .8, clean: .4, cinematic: .35, deadpan: .15 };
  SRB.moods = MOODS;
  SRB.moodFor = name => ({ 'Kinetic punch': 'punch', 'Playful toy': 'playful', 'Tech decode': 'tech', 'Clean product': 'clean', 'Cinematic': 'cinematic', 'Deadpan': 'deadpan' })[name] || 'clean';
  // Reaction strengths {p: kick pulse, e: energy} scaled by the mood, or null (no signals, reduced motion, or react:false).
  const RX = o => { if (!o || !o.sig || o.reduced || o.react === false) return null; const a = MOODS[o.mood] != null ? MOODS[o.mood] : .4, f = v => isFinite(v) ? clamp(v) : 0; return { p: f(o.sig.pulse) * a, e: f(o.sig.energy) * a }; };
  function add(id, family, name, desc, animated, fn) { SRB.list.push({ id, family, name, desc, animated: !!animated }); SRB.fns[id] = fn; }

  /* ---- Solid ---- */
  add('solid', 'Solid', 'Solid', 'One flat colour: the calmest base.', false, (g, W, H, t, p) => fill(g, W, H, p.bg));
  add('duotone', 'Solid', 'Duotone band', 'Flat colour with a lower band in a second tone.', false, (g, W, H, t, p) => { fill(g, W, H, p.bg); g.fillStyle = rgba(a2(p), .28); g.fillRect(0, H * .66, W, H * .34); });
  add('vignette', 'Solid', 'Vignette', 'Flat colour darkened at the edges to focus the centre.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const r = Math.hypot(W, H) / 2, v = g.createRadialGradient(W / 2, H / 2, r * .35, W / 2, H / 2, r);
    v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,.5)'); g.fillStyle = v; g.fillRect(0, 0, W, H);
  });

  /* ---- Gradient ---- */
  add('linear', 'Gradient', 'Linear gradient', 'Smooth diagonal blend from the base to the second tone.', false, (g, W, H, t, p) => {
    const v = g.createLinearGradient(0, 0, W, H); v.addColorStop(0, p.bg); v.addColorStop(1, mix(p.bg, a2(p), .6)); g.fillStyle = v; g.fillRect(0, 0, W, H);
  });
  add('radial', 'Gradient', 'Radial glow', 'Soft glow in the centre fading to the base.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const v = g.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, Math.max(W, H) * .7); v.addColorStop(0, mix(p.bg, a2(p), .55)); v.addColorStop(1, rgba(p.bg, 0)); g.fillStyle = v; g.fillRect(0, 0, W, H);
  });
  add('conic', 'Gradient', 'Conic sweep', 'Colour wheel sweeping around the centre, like a light fan.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const n = 120, R = Math.hypot(W, H);
    for (let i = 0; i < n; i++) { const a0 = i / n * Math.PI * 2, a1 = (i + 1.5) / n * Math.PI * 2, k = .5 - .5 * Math.cos(i / n * Math.PI * 2);
      g.fillStyle = mix(p.bg, a2(p), k * .5); g.beginPath(); g.moveTo(W / 2, H / 2); g.lineTo(W / 2 + Math.cos(a0) * R, H / 2 + Math.sin(a0) * R); g.lineTo(W / 2 + Math.cos(a1) * R, H / 2 + Math.sin(a1) * R); g.closePath(); g.fill(); }
    const c = g.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, Math.min(W, H) * .25); c.addColorStop(0, p.bg); c.addColorStop(1, rgba(p.bg, 0)); g.fillStyle = c; g.fillRect(0, 0, W, H);
  });
  add('mesh', 'Gradient', 'Mesh blobs', 'Three soft colour blobs melting into each other.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const R = Math.max(W, H) * .6;
    [[.2, .25, p.accent, .4], [.8, .3, a2(p), .45], [.5, .95, mix(p.accent, a2(p), .5), .35]].forEach(([x, y, c, al]) => { const v = g.createRadialGradient(W * x, H * y, 0, W * x, H * y, R); v.addColorStop(0, rgba(c, al)); v.addColorStop(1, rgba(c, 0)); g.fillStyle = v; g.fillRect(0, 0, W, H); });
  });

  /* ---- Pattern ---- */
  add('grid', 'Pattern', 'Grid', 'Fine blueprint grid.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const s = W / 32; g.strokeStyle = rgba(p.fg, .09); g.lineWidth = 1; g.beginPath();
    for (let x = 0; x <= W; x += s) { g.moveTo(x, 0); g.lineTo(x, H); } for (let y = 0; y <= H; y += s) { g.moveTo(0, y); g.lineTo(W, y); } g.stroke();
  });
  add('dots', 'Pattern', 'Dot matrix', 'Regular field of small dots.', false, (g, W, H, t, p, o) => {
    fill(g, W, H, p.bg); const s = W / 36, rx = RX(o) || { p: 0, e: 0 }; g.fillStyle = rgba(p.fg, .17);
    for (let y = s / 2; y < H; y += s) for (let x = s / 2; x < W; x += s) { g.beginPath(); g.arc(x, y, s * .08 * (1 + rx.p * .7), 0, 7); g.fill(); }
  });
  add('diagonal', 'Pattern', 'Diagonal lines', 'Thin diagonal hatching.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const s = W / 30; g.strokeStyle = rgba(p.fg, .07); g.lineWidth = 2; g.beginPath();
    for (let x = -H; x < W; x += s) { g.moveTo(x, H); g.lineTo(x + H, 0); } g.stroke();
  });
  add('checker', 'Pattern', 'Checkerboard', 'Large soft checkerboard.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const s = W / 16; g.fillStyle = rgba(p.fg, .045);
    for (let y = 0, j = 0; y < H; y += s, j++) for (let x = 0, i = 0; x < W; x += s, i++) if ((i + j) % 2) g.fillRect(x, y, s, s);
  });
  add('waves', 'Pattern', 'Wave lines', 'Stacked sine lines, like contour or sound.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); g.strokeStyle = rgba(p.fg, .13); g.lineWidth = 2;
    for (let k = 0; k < 10; k++) { g.beginPath(); for (let x = 0; x <= W; x += W / 80) { const y = H * (.12 + k * .085) + Math.sin(x / W * 6.28 * 1.5 + k * .5) * H * .05; x ? g.lineTo(x, y) : g.moveTo(x, y); } g.stroke(); }
  });
  add('hex', 'Pattern', 'Hexagons', 'Honeycomb outline.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const r = W / 26, dx = r * 1.732, dy = r * 1.5; g.strokeStyle = rgba(p.fg, .1); g.lineWidth = 1.5;
    for (let row = -1, y = 0; y < H + r; row++, y = row * dy) for (let x = (row % 2 ? dx / 2 : 0); x < W + dx; x += dx) {
      g.beginPath(); for (let k = 0; k < 6; k++) { const a = Math.PI / 3 * k + Math.PI / 6; k ? g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r) : g.moveTo(x + Math.cos(a) * r, y + Math.sin(a) * r); } g.closePath(); g.stroke(); }
  });
  add('bars', 'Pattern', 'Vertical bars', 'Wide alternating stripes.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const s = W / 24; g.fillStyle = rgba(p.fg, .05); for (let x = 0, i = 0; x < W; x += s, i++) if (i % 2) g.fillRect(x, 0, s, H);
  });

  /* ---- Texture ---- */
  add('grain', 'Texture', 'Film grain', 'Fine speckle over a flat base, like film or paper.', false, (g, W, H, t, p) => {
    fill(g, W, H, p.bg); const n = 7000, s = Math.max(1.4, W / 600);
    for (let i = 0; i < n; i++) { g.fillStyle = hs(i, 2) > .5 ? 'rgba(255,255,255,.1)' : 'rgba(0,0,0,.14)'; g.fillRect(hs(i, 1) * W, hs(i, 3) * H, s, s); }
  });
  add('halftone', 'Texture', 'Halftone', 'Print-style dots growing toward one corner.', false, (g, W, H, t, p, o) => {
    fill(g, W, H, p.bg); const s = W / 40, rx = RX(o) || { p: 0, e: 0 }; g.fillStyle = rgba(a2(p), .32);
    for (let y = s / 2; y < H; y += s) for (let x = s / 2; x < W; x += s) { const k = clamp((x / W + y / H) / 2 + rx.p * .08); g.beginPath(); g.arc(x, y, s * .46 * k * k, 0, 7); g.fill(); }
  });

  /* ---- Animated (frozen at t = 0 with reduced motion) ---- */
  const T = (o, t) => (o && o.reduced) ? 0 : t;
  add('aurora', 'Animated', 'Aurora', 'Slow drifting colour clouds.', true, (g, W, H, t, p, o) => {
    t = T(o, t); fill(g, W, H, p.bg); const rx = RX(o) || { p: 0, e: 0 }, R = Math.max(W, H) * .5 * (1 + rx.e * .25 + rx.p * .15);
    [[p.accent, .3, 0], [a2(p), .34, 2], [mix(p.accent, a2(p), .5), .28, 4], [a2(p), .22, 6]].forEach(([c, al, ph], i) => {
      const x = W * (.5 + .38 * Math.sin(t * .22 + ph)), y = H * (.5 + .32 * Math.cos(t * .17 + ph * 1.3)); const v = g.createRadialGradient(x, y, 0, x, y, R); v.addColorStop(0, rgba(c, al)); v.addColorStop(1, rgba(c, 0)); g.fillStyle = v; g.fillRect(0, 0, W, H); });
  });
  add('particles', 'Animated', 'Rising particles', 'Soft dots floating upward.', true, (g, W, H, t, p, o) => {
    t = T(o, t); fill(g, W, H, p.bg); const rx = RX(o) || { p: 0, e: 0 };
    for (let i = 0; i < 70; i++) { const sp = .02 + hs(i, 5) * .05, y = ((hs(i, 2) - t * sp) % 1 + 1) % 1 * H - rx.p * H * .03 * (.4 + hs(i, 8)), x = (hs(i, 1) + Math.sin(t * .4 + i) * .015) * W, r = (1 + hs(i, 3) * 3) * W / 900 * (1 + rx.p * 1.3);
      g.fillStyle = rgba(i % 5 ? p.fg : p.accent, .15 + hs(i, 4) * .3); g.beginPath(); g.arc(x, y, r, 0, 7); g.fill(); }
  });
  add('stars', 'Animated', 'Starfield', 'Fixed stars that twinkle gently.', true, (g, W, H, t, p, o) => {
    t = T(o, t); fill(g, W, H, p.bg); const rx = RX(o) || { p: 0, e: 0 };
    for (let i = 0; i < 140; i++) { const tw = .5 + .5 * Math.sin(t * (.6 + hs(i, 6) * 1.2) + hs(i, 7) * 6.28), r = (.6 + hs(i, 3) * 1.6) * W / 900 * (1 + rx.p * .7); g.fillStyle = rgba(p.fg, clamp(.15 + .65 * tw * hs(i, 4) + rx.e * .15)); g.beginPath(); g.arc(hs(i, 1) * W, hs(i, 2) * H, r, 0, 7); g.fill(); }
  });
  add('scanlines', 'Animated', 'Scanlines', 'Fine horizontal lines with a slow light band passing down.', true, (g, W, H, t, p, o) => {
    t = T(o, t); fill(g, W, H, p.bg); g.fillStyle = rgba(p.fg, .045); const s = Math.max(3, H / 120); for (let y = 0; y < H; y += s * 2) g.fillRect(0, y, W, s);
    const rx = RX(o) || { p: 0, e: 0 }, bh = H * .1 * (1 + rx.p * .8), y0 = ((t / 7) % 1) * (H * 1.3) - H * .15, v = g.createLinearGradient(0, y0 - bh, 0, y0 + bh); v.addColorStop(0, rgba(a2(p), 0)); v.addColorStop(.5, rgba(a2(p), .14 + rx.p * .08)); v.addColorStop(1, rgba(a2(p), 0)); g.fillStyle = v; g.fillRect(0, y0 - bh, W, bh * 2);
  });
  add('drift', 'Animated', 'Gradient drift', 'A gradient whose direction slowly turns.', true, (g, W, H, t, p, o) => {
    t = T(o, t); const rx = RX(o) || { p: 0, e: 0 }, a = .6 + t * .12 + rx.p * .08, R = Math.hypot(W, H) / 2, cx = W / 2, cy = H / 2, v = g.createLinearGradient(cx - Math.cos(a) * R, cy - Math.sin(a) * R, cx + Math.cos(a) * R, cy + Math.sin(a) * R);
    v.addColorStop(0, p.bg); v.addColorStop(1, mix(p.bg, a2(p), .65)); g.fillStyle = v; g.fillRect(0, 0, W, H);
  });
  add('spotlight', 'Animated', 'Moving spotlight', 'A soft pool of light sweeping slowly side to side.', true, (g, W, H, t, p, o) => {
    t = T(o, t); fill(g, W, H, p.bg); const x = W * (.5 + .3 * Math.sin(t * .45)), y = H * .42, rx = RX(o) || { p: 0, e: 0 }, v = g.createRadialGradient(x, y, 0, x, y, Math.max(W, H) * .5 * (1 + rx.p * .35)); v.addColorStop(0, rgba(p.accent, .34 + rx.p * .1)); v.addColorStop(1, rgba(p.accent, 0)); g.fillStyle = v; g.fillRect(0, 0, W, H);
  });
  add('waves-flow', 'Animated', 'Flowing waves', 'The wave lines, drifting like water.', true, (g, W, H, t, p, o) => {
    t = T(o, t); fill(g, W, H, p.bg); g.strokeStyle = rgba(p.fg, .14); g.lineWidth = 2; const rx = RX(o) || { p: 0, e: 0 };
    for (let k = 0; k < 10; k++) { g.beginPath(); for (let x = 0; x <= W; x += W / 80) { const y = H * (.12 + k * .085) + Math.sin(x / W * 6.28 * 1.5 + k * .5 + t * .7) * H * .05 * (1 + rx.p * .9); x ? g.lineTo(x, y) : g.moveTo(x, y); } g.stroke(); }
  });

  SRB.draw = function (id, g, W, H, t, pal, o) { const f = SRB.fns[id]; if (!f) throw new Error('unknown background ' + id); g.save(); try { f(g, W, H, t || 0, pal, o || {}); } finally { g.restore(); } };
  // Crossfade from background a to b (k 0..1) so a change of look never cuts hard.
  SRB.blend = function (g, W, H, a, b, k, t, pal, o) {
    k = clamp(k); SRB.draw(a, g, W, H, t, pal, o); if (k <= 0) return; if (k >= 1) { SRB.draw(b, g, W, H, t, pal, o); return; }
    g.save(); g.globalAlpha = (g.globalAlpha == null ? 1 : g.globalAlpha) * k; SRB.draw(b, g, W, H, t, pal, o); g.restore();
  };
  // One continuous background across scenes: segs = [{id, from}] sorted by start time (seconds); each change is a crossfade of `fade` seconds centred on the boundary.
  // Call it once per frame with the reel time (not the scene-local time) so the motion never restarts at a cut.
  SRB.sequence = function (g, W, H, t, pal, o, segs, fade) {
    fade = fade == null ? .6 : fade; let i = 0; for (let j = 0; j < segs.length; j++) if (t >= segs[j].from - fade / 2) i = j;
    if (i === 0) return SRB.draw(segs[0].id, g, W, H, t, pal, o);
    SRB.blend(g, W, H, segs[i - 1].id, segs[i].id, (t - (segs[i].from - fade / 2)) / fade, t, pal, o);
  };
  window.SRB = SRB;
})();
