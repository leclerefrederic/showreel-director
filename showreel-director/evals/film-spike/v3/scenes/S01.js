/* Test scene S01: a flat colour field with a marker and a word (placeholder, not a design). */
const { clamp, ease } = SR;
const field = (col, word, shape) => (g, lt, c) => {
  g.fillStyle = col; g.fillRect(0, 0, c.SW, c.SH);
  const k = ease.out3(clamp(lt / .6));                       // each module animates with its own local time
  g.fillStyle = '#ffffff'; g.globalAlpha = .9;
  shape(g, c, k); g.globalAlpha = 1;
  g.font = '700 ' + Math.round(c.SH / 9) + 'px system-ui,sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillStyle = '#ffffff'; g.fillText(word, c.SW / 2, c.SH * .78);
};
const disc = (g, c, k) => { g.beginPath(); g.arc(c.SW / 2, c.SH * .4, c.SH * .15 * k, 0, Math.PI * 2); g.fill(); };
return field('#cc2222', 'One', disc);
