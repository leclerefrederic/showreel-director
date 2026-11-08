/* Host API of the embedded engine (Showreel Studio). It runs after the skill's own engine code (core, kit, backgrounds, effects) in one
   page, and only adds the calls the app needs. Everything it draws comes from that code; it holds no palette, font or effect of its own. */
(function () {
  const OUT = [];
  const errors = [];
  const sizeCanvas = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
  const stage = sizeCanvas(W, H);   // W, H (640 x 360) come from the effects' helper block
  const sg = stage.getContext('2d');
  const note = (what, e) => { errors.push(what + ': ' + (e && e.message || e)); };
  const fam = f => '"' + String(f || 'sans-serif').replace(/"/g, '') + '",sans-serif';
  const find = name => E.find(x => x.name === name);
  const palette = p => Object.assign({ bg: '#101820', fg: '#FFFFFF', accent: '#F2AA4C', accent2: '#F2AA4C', mute: '#8A8A8A' }, p || {});

  function toURL(w, h, type) {
    const o = sizeCanvas(w, h), g = o.getContext('2d');
    g.imageSmoothingQuality = 'high'; g.drawImage(stage, 0, 0, W, H, 0, 0, w, h);
    return o.toDataURL(type || 'image/png', 0.85);
  }
  function drawEffect(ef, pal, font, t, text) {
    FONT = fam(font);
    const words = String(text || 'Simple. Fast. Yours.').trim().split(/\s+/);
    const ctx = { P: palette(pal), txt: String(text || 'Simple. Fast. Yours.'), w1: words[0], w2: words[1] || words[0] };
    sg.setTransform(1, 0, 0, 1, 0, 0); sg.globalAlpha = 1; sg.globalCompositeOperation = 'source-over'; sg.clearRect(0, 0, W, H);
    sg.save();
    try { ef.draw(sg, clamp(t / ef.dur), ctx); } catch (e) { note(ef.name, e); } finally { sg.restore(); }
  }
  function drawBackground(id, params, pal, t) {
    sg.setTransform(1, 0, 0, 1, 0, 0); sg.globalAlpha = 1; sg.globalCompositeOperation = 'source-over'; sg.clearRect(0, 0, W, H);
    try { window.SRB.draw(id, sg, W, H, t, palette(pal), params || {}); } catch (e) { note('background ' + id, e); }
  }

  // An effect draws its own flat background first (bg(g, c)). For a look frame the chosen background goes underneath instead, so
  // while a look is drawn that first fill is skipped. The effects themselves are untouched.
  let underlay = false;
  const flatBG = bg;
  bg = function (g, c) { if (!underlay) flatBG(g, c); };
  function drawLook(bgId, params, ef, pal, font, t, text) {
    drawBackground(bgId, params, pal, t);
    underlay = true;
    FONT = fam(font);
    const words = String(text || 'Simple. Fast. Yours.').trim().split(/\s+/);
    const ctx = { P: palette(pal), txt: String(text || 'Simple. Fast. Yours.'), w1: words[0], w2: words[1] || words[0] };
    sg.save();
    try { ef.draw(sg, clamp(t / ef.dur), ctx); } catch (e) { note(ef.name, e); } finally { sg.restore(); underlay = false; }
  }

  window.studioEngine = {
    catalogue() {
      return JSON.stringify({
        effects: E.map(x => ({ cat: x.cat, name: x.name, desc: x.desc, energy: x.energy, dur: x.dur })),
        backgrounds: window.SRB.list,
        moods: Object.keys(window.SRB.moods)
      });
    },
    async registerFont(family, url) {
      const f = new FontFace(family, 'url(' + url + ')');
      await f.load(); document.fonts.add(f); return true;
    },
    renderEffect(name, pal, font, t, text, w, h) {
      const ef = find(name); if (!ef) return null;
      drawEffect(ef, pal, font, t, text); return toURL(w, h);
    },
    renderBackground(id, params, pal, t, w, h) {
      if (!window.SRB.fns[id]) return null;
      drawBackground(id, params, pal, t); return toURL(w, h);
    },
    effectStrip(name, pal, font, n, text, w, h) {
      const ef = find(name); if (!ef) return null;
      const frames = [], span = ef.dur + 0.6;       // the effect, then a short hold on its last frame
      for (let i = 0; i < n; i++) { drawEffect(ef, pal, font, span * i / Math.max(1, n - 1), text); frames.push(toURL(w, h, 'image/jpeg')); }
      return JSON.stringify(frames);
    },
    backgroundStrip(id, params, pal, n, secs, w, h) {
      if (!window.SRB.fns[id]) return null;
      const frames = [];
      for (let i = 0; i < n; i++) { drawBackground(id, params, pal, secs * i / n); frames.push(toURL(w, h, 'image/jpeg')); }
      return JSON.stringify(frames);
    },
    lookStrip(bgId, params, name, pal, font, n, text, w, h) {
      const ef = find(name); if (!ef || !window.SRB.fns[bgId]) return null;
      const frames = [], span = ef.dur + 0.8;
      for (let i = 0; i < n; i++) { drawLook(bgId, params, ef, pal, font, span * i / Math.max(1, n - 1), text); frames.push(toURL(w, h, 'image/jpeg')); }
      return JSON.stringify(frames);
    },
    errors() { return errors.slice(); }
  };
})();
