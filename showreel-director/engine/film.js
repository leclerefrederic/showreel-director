/* Showreel film layer (optional, W3a spike): assembles one render module per scene into a reel, and mixes scenes with transitions.
   Style-neutral: it draws nothing of its own. Palette, fonts, shapes, effects and words come from the scene modules the caller writes.
   The default way to make a reel stays one main.js with one render(); this is an option for films where scenes are separate modules
   (generated or edited one at a time) and where a transition has to show two scenes at once.

   const film = SRF.film({
     scenes: [                                    // in montage order; the first key found gives the start (t seconds, bar, or k beat), as SR.setScenes
       { name: 'a', t: 0, render(g, lt, c) {...} },                                        // a scene module: draws in the stage 0..c.SW x 0..c.SH
       { name: 'b', t: 3, render(g, lt, c) {...}, transition: { type: 'Push', duration: .8, params: {} } },   // the passage from THIS scene to the NEXT one
       ...],
     palette: { bg, fg, accent, accent2 },        // handed to the transitions (they colour flashes, floods and edges with it); neutral greys by default
     background(g, t, c) {...},                   // optional, drawn first at film time t: what crosses scenes (a background sequence, music reaction)
     overlay(g, t, c) {...},                      // optional, drawn last at film time t: persistent elements (a logo, a counter)
   });
   window.SHOWREEL = { ..., render: film.render };     // the player, the harness, the MP4 export and the contact sheets call it like any render

   A scene module is render(g, lt, c): lt is the time in the scene (seconds), c is the frame context of the engine plus scene (the scene entry), index,
   lt, u (0..1 progress), sig (SR.signals: null without music or in reduced motion) and t (film time). Draw with lt, never with the clock. Anything that must
   continue across scenes (a background, a persistent character, the music reaction) is a function of the film time t: put it in background() or overlay().
   Transitions: a transition is a relation between two consecutive scenes, stored on the outgoing one (type: 'cut' or a name of SRT.list, duration in
   seconds, params carried to the effect as c.params, unused by the catalogue today). It OVERLAPS the end of the outgoing scene and the start of the
   incoming one, centred on the cut: from T - d/2 to T + d/2, so scene starts and the film's length do not change. During it the outgoing module keeps
   drawing past its end (lt grows beyond its duration, u stays 1) and the incoming module draws from lt = 0 (c.pre is true while the film time is before
   its start: it shows its first frame). d is capped at the shorter of the two scenes. Outside the transitions each scene is drawn straight onto g, so the
   harness checks (text outside the stage, collisions) see it as usual; inside one, both scenes are drawn into off-screen canvases (the host provides
   SR_CANVAS_FACTORY(w, h) when it has no DOM) and mixed by the transition of the catalogue (engine/transitions.js, generated from the effects lab).
   film.windows lists the transitions with their start and end times; film.scenes is the scene list as the engine holds it. */
(function (G) {
  'use strict';
  const SR = G.SR, clamp = SR.clamp;
  const NEUTRAL = { bg: '#000000', fg: '#ffffff', accent: '#ffffff', accent2: '#888888', mute: '#888888' };

  function mk(w, h) {
    if (typeof G.SR_CANVAS_FACTORY === 'function') return G.SR_CANVAS_FACTORY(w, h);
    if (G.document) { const c = G.document.createElement('canvas'); c.width = w; c.height = h; return c; }
    throw new Error('the film layer needs a canvas factory (SR_CANVAS_FACTORY) in a host without a DOM');
  }

  function film(opt) {
    const given = opt.scenes || [];
    const scenes = SR.setScenes(given.map(s => Object.assign({}, s)));   // sorted by start; each entry keeps render and transition
    const P = Object.assign({}, NEUTRAL, opt.palette || {});
    const windows = scenes.slice(0, -1).map((s, i) => {
      const tr = s.transition || { type: 'cut' }, nx = scenes[i + 1];
      if (!tr.type || tr.type === 'cut' || !G.SRT || !G.SRT.has(tr.type)) return null;
      const d = Math.min(tr.duration > 0 ? tr.duration : 1, s.e - s.s, nx.e - nx.s);
      return { from: i, to: i + 1, type: tr.type, params: tr.params || {}, T: nx.s, d, start: nx.s - d / 2, end: nx.s + d / 2 };
    }).filter(Boolean);
    let bufs = null, bufKey = '';
    const buffers = (w, h) => { const k = w + 'x' + h; if (k !== bufKey) { bufs = [mk(w, h), mk(w, h)]; bufKey = k; } return bufs; };

    function sub(c, s, t, lt, extra) {
      return Object.assign({}, c, { scene: s, index: s.i, t, lt, u: clamp(lt / Math.max(.001, s.e - s.s)), sig: SR.signals(c) }, extra);
    }
    function clear(x, w, h) { x.setTransform(1, 0, 0, 1, 0, 0); x.globalAlpha = 1; x.globalCompositeOperation = 'source-over'; x.clearRect(0, 0, w, h); }

    function render(g, t, c) {
      if (opt.background) opt.background(g, t, c);
      const w = windows.find(x => t >= x.start && t < x.end);
      if (w) {
        const A = scenes[w.from], B = scenes[w.to], [ca, cb] = buffers(c.SW, c.SH);
        const xa = ca.getContext('2d'), xb = cb.getContext('2d');
        clear(xa, c.SW, c.SH); clear(xb, c.SW, c.SH);
        A.render(xa, t - A.s, sub(c, A, t, t - A.s, { params: w.params }));
        B.render(xb, Math.max(0, t - B.s), sub(c, B, t, Math.max(0, t - B.s), { pre: t < B.s, params: w.params }));
        G.SRT.draw(g, w.type, (t - w.start) / w.d, Object.assign({}, c, { P, params: w.params }), ca, cb, c.SW, c.SH);
      } else {
        const s = c.scene || (SR.sceneAt(t) || {}).scene;
        if (s && s.render) s.render(g, t - s.s, sub(c, s, t, t - s.s));
      }
      if (opt.overlay) opt.overlay(g, t, c);
    }
    const api = { render, windows, scenes, palette: P };
    G.SRF.current = api;
    return api;
  }
  G.SRF = { film, current: null };
})(typeof window !== 'undefined' ? window : globalThis);
