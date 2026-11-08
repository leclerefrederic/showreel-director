/* Showreel engine core — style-neutral, no DOM. Loaded before main.js.
   Provides time, beat and scene helpers and the stage transform. It draws nothing by itself. */
(function (G) {
  'use strict';
  const D = G.SR_DATA || { beats: [], dur: 60, env: null, bars: [] };
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const lerp = (a, b, t) => a + (b - a) * t;
  // Basic easings only. Motion character (overshoot, bounce, snap) belongs to the project, not the engine.
  const ease = {
    lin: t => t,
    in2: t => t * t, out2: t => 1 - (1 - t) * (1 - t),
    io2: t => t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2,
    in3: t => t * t * t, out3: t => 1 - Math.pow(1 - t, 3),
    io3: t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2,
    outExpo: t => t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)
  };
  const BEATS = D.beats;
  // Time of beat index k (integer beat count from the beat map). Extrapolates beyond the ends with the local period.
  function K_(k) {
    if (!BEATS.length) return k * .5;
    if (k < 0) return BEATS[0] + k * (BEATS[1] - BEATS[0]);
    if (k >= BEATS.length) return BEATS[BEATS.length - 1] + (k - BEATS.length + 1) * (BEATS[BEATS.length - 1] - BEATS[BEATS.length - 2]);
    return BEATS[k];
  }
  // Bar b (1-based) start time, given downbeat offset from the analysis (beats.json).
  const DOWN = D.downbeat_offset || 0;
  const barT = b => K_(DOWN + (b - 1) * 4);
  function beatInfo(t) { // {i: beat index, bf: fraction 0..1 inside the beat}
    const n = BEATS.length;
    if (!n || t < BEATS[0]) return { i: -1, bf: n ? clamp(t / BEATS[0]) : 0 };
    let lo = 0, hi = n - 1;
    while (lo < hi) { const m = (lo + hi + 1) >> 1; if (BEATS[m] <= t) lo = m; else hi = m - 1; }
    const e = lo + 1 < n ? BEATS[lo + 1] : BEATS[lo] + .5;
    return { i: lo, bf: clamp((t - BEATS[lo]) / (e - BEATS[lo])) };
  }
  // Envelopes (kick/hat/energy, 0..1) sampled at time t. Returns zeros when there is no track.
  let ENV = null;
  function decodeEnv() {
    const e = D.env; if (!e) return null;
    if (e.kick) return e; // already arrays
    const b = Uint8Array.from(G.atob(e.b64), c => c.charCodeAt(0)), n = b.length / 3;
    const ch = k => Array.from({ length: n }, (_, i) => b[i * 3 + k]);
    return { fps: e.fps, kick: ch(0), hat: ch(1), energy: ch(2) };
  }
  function envAt(t) {
    if (ENV === null) ENV = decodeEnv() || false;
    if (!ENV) return { kick: 0, hat: 0, energy: 0 };
    const i = clamp(Math.round(t * ENV.fps), 0, ENV.kick.length - 1);
    return { kick: ENV.kick[i] / 255, hat: ENV.hat[i] / 255, energy: ENV.energy[i] / 255 };
  }
  // Scenes: list of {name, k: start beat index OR t: start seconds OR bar: start bar number, ...anything}. Sorted by start.
  let SCENES = [];
  function setScenes(list) {
    SCENES = list.map(s => Object.assign({}, s, { s: s.t != null ? s.t : s.bar != null ? barT(s.bar) : K_(s.k || 0) }))
      .sort((a, b) => a.s - b.s);
    SCENES.forEach((s, i) => { s.e = i + 1 < SCENES.length ? SCENES[i + 1].s : D.dur; s.i = i; });
    return SCENES;
  }
  function sceneAt(t) {
    let sc = SCENES[0];
    for (const s of SCENES) if (t >= s.s) sc = s;
    return sc ? { scene: sc, lt: t - sc.s, u: clamp((t - sc.s) / Math.max(.001, sc.e - sc.s)) } : null;
  }
  // Images listed under "images" in project.json (embedded as data URIs by build.py). SR.img(key) returns a drawable image
  // once it is ready, or null while it is still decoding (the loop draws again next frame), so always guard: const im = SR.img('shot-01'); if (im) g.drawImage(im, ...).
  // Hosts without a DOM (MP4 export, harness) provide G.SR_IMG_LOADER(dataUri) instead of the browser Image.
  const IMG = {};
  function img(key) {
    if (!(key in IMG)) {
      const src = (D.images || {})[key]; let im = null;
      if (src) { if (typeof G.SR_IMG_LOADER === 'function') im = G.SR_IMG_LOADER(src); else if (typeof G.Image === 'function') { im = new G.Image(); im.src = src; } }
      IMG[key] = im;
    }
    const im = IMG[key];
    return im && im.complete !== false && im.naturalWidth !== 0 ? im : null;
  }
  function imagesReady() {
    return Promise.all(Object.keys(D.images || {}).map(k => { img(k); const im = IMG[k]; return im && im.decode ? im.decode().catch(() => {}) : Promise.resolve(); }));
  }
  // Letterbox a virtual stage SW x SH into the canvas W x H and clip to it. Returns the scale.
  function stage(g, W, H, SW, SH) {
    const k = Math.min(W / SW, H / SH), ox = (W - SW * k) / 2, oy = (H - SH * k) / 2;
    g.save(); g.translate(ox, oy); g.scale(k, k); g.beginPath(); g.rect(0, 0, SW, SH); g.clip();
    return k;
  }
  // Frame entry point used by the player and the test harness: pure function of (t, lang, mode).
  function drawFrame(g, W, H, t, state) {
    const S = G.SHOWREEL, f = S.formats[state.mode], SW = f[0], SH = f[1];
    g.fillStyle = S.pageColor || '#000'; g.fillRect(0, 0, W, H);
    stage(g, W, H, SW, SH);
    const s = sceneAt(t);
    S.render(g, t, { SW, SH, mode: state.mode, lang: state.lang, env: envAt(t), beat: beatInfo(t), scene: s && s.scene, lt: s ? s.lt : t, u: s ? s.u : 0, reduced: !!state.reduced, music: !!state.music });
    g.restore();
  }
  // Music signals for reactive visuals (backgrounds, props): null (so nothing reacts) when there is no music playing, the track is muted or the viewer asked for reduced motion.
  function signals(ctx) {
    if (!ctx || !ctx.music || ctx.reduced || !ctx.env) return null;
    return { pulse: clamp(ctx.env.kick), hat: clamp(ctx.env.hat), energy: clamp(ctx.env.energy), beat: ctx.beat && ctx.beat.bf != null ? ctx.beat.bf : 0 };
  }
  G.SR = { signals, clamp, lerp, ease, K_, barT, beatInfo, envAt, setScenes, sceneAt, drawFrame, stage, img, imagesReady, data: D };
})(typeof window !== 'undefined' ? window : globalThis);
