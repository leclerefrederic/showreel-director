/* Test scene S02: a flat colour field with a marker and a word (placeholder, not a design). */
const { clamp, ease } = SR;
const field = (col, word, shape) => (g, lt, c) => {
  g.fillStyle = col; g.fillRect(0, 0, c.SW, c.SH);
  const k = ease.out3(clamp(lt / .6));                       // each module animates with its own local time
  g.fillStyle = '#ffffff'; g.globalAlpha = .9;
  shape(g, c, k); g.globalAlpha = 1;
  g.font = '700 ' + Math.round(c.SH / 9) + 'px system-ui,sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillStyle = '#ffffff'; g.fillText(word, c.SW / 2, c.SH * .78);
};
const bar = (g, c, k) => g.fillRect(c.SW * .25, c.SH * .3, c.SW * .5 * k, c.SH * .16);
return field('#2222cc', 'Two', bar);
