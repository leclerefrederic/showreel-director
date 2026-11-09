/* Test scene S01: a particle field pulled toward a point, an emissive sphere and a soft glow, with one word drawn in 2D over them (placeholder, not a design). */
const { clamp } = SR;
const st = SR3D.stage({ w: 1600, h: 900, bg: '#000000', bloom: { strength: .25, radius: .4, threshold: .9 }, grade: { tone: 1.2, vignette: .5, grain: .03 } });
const dust = SR3D.particles(st, { count: 3000, seed: 7, colors: ['#ffffff', '#c0d8ff'] });
const orb = SR3D.orb(st, { colors: ['#ffffff', '#808080'] });
const halo = SR3D.glow(st, { color: '#ffffff' });
return function render(g, lt, c) {
  g.fillStyle = '#000'; g.fillRect(0, 0, c.SW, c.SH);
  st.fit(c); st.look(0, 0, 1);
  const k = clamp(lt / 3);
  dust.set(lt, { amt: 1 - k * .8, orbit: .02, twinkle: .6, alpha: clamp(lt / .5), target: [0, 0] }, c);
  orb.set(lt, { x: 0, y: 0, z: 0, radius: 120, k: clamp(lt / .4), spin: lt * .3, seed: 3 }, c);
  halo.set(lt, { x: 0, y: 0, z: 0, size: 700, k: .5 * k });
  st.draw(g, lt, { veil: 1 - clamp(lt / .5), bars: c.mode === 'd' ? 80 / 900 : 0 });
  g.font = '700 ' + Math.round(c.SH / 12) + 'px system-ui,sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.globalAlpha = clamp((lt - .8) / .6); g.fillStyle = '#ffffff'; g.fillText('Pulled in', c.SW / 2, c.SH * .82); g.globalAlpha = 1;
};
