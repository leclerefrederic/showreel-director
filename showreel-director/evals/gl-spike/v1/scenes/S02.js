/* Test scene S02: the same field thrown outward, a ring glow, and a word in 2D (placeholder, not a design). */
const { clamp } = SR;
const st = SR3D.stage({ w: 1600, h: 900, bg: '#000000', grade: { tone: 1.1, vignette: .4 } });
const dust = SR3D.particles(st, { count: 2000, seed: 11, colors: ['#ffe0a0', '#ffffff'] });
const ring = SR3D.glow(st, { mode: 'ring', color: '#ffffff' });
return function render(g, lt, c) {
  g.fillStyle = '#000'; g.fillRect(0, 0, c.SW, c.SH);
  st.fit(c); st.look(0, 0, 1);
  dust.set(lt, { amt: 1 + 1.4 * Math.exp(-lt * 1.5), orbit: -.03, alpha: 1 }, c);
  ring.set(lt, { x: 0, y: 0, z: 0, size: 300 + 500 * clamp(lt / 3), k: 1 - clamp(lt / 3.5) });
  st.draw(g, lt, { flash: c.reduced ? 0 : .4 * Math.exp(-lt * 8) });
  g.font = '700 ' + Math.round(c.SH / 12) + 'px system-ui,sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.globalAlpha = clamp((lt - .6) / .6); g.fillStyle = '#ffffff'; g.fillText('Thrown out', c.SW / 2, c.SH * .82); g.globalAlpha = 1;
};
