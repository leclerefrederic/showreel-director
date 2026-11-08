/* Test film for the film layer, montage from film.json (SRF.fromData). Three scene modules, each a flat colour field with a marker and a word, so that a frame in the
   middle of a transition can be read pixel by pixel: scene one is RED, scene two BLUE, scene three GREEN. Not a design: placeholders only. */
(function () {
  const { clamp, ease } = window.SR;
  const field = (col, word, shape) => (g, lt, c) => {
    g.fillStyle = col; g.fillRect(0, 0, c.SW, c.SH);
    const k = ease.out3(clamp(lt / .6));                       // each module animates with its own local time
    g.fillStyle = '#ffffff'; g.globalAlpha = .9;
    shape(g, c, k); g.globalAlpha = 1;
    g.font = '700 ' + Math.round(c.SH / 9) + 'px system-ui,sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillStyle = '#ffffff'; g.fillText(word, c.SW / 2, c.SH * .78);
  };
  const disc = (g, c, k) => { g.beginPath(); g.arc(c.SW / 2, c.SH * .4, c.SH * .15 * k, 0, Math.PI * 2); g.fill(); };
  const bar = (g, c, k) => g.fillRect(c.SW * .25, c.SH * .3, c.SW * .5 * k, c.SH * .16);
  const tri = (g, c, k) => { g.beginPath(); g.moveTo(c.SW / 2, c.SH * .22); g.lineTo(c.SW / 2 + c.SH * .18 * k, c.SH * .55); g.lineTo(c.SW / 2 - c.SH * .18 * k, c.SH * .55); g.closePath(); g.fill(); };
  // the montage (starts, durations, transitions) is in film.json next to project.json: the modules are keyed by scene name and SRF.fromData reads the rest
  const film = window.SRF.fromData({ S01: field('#cc2222', 'One', disc), S02: field('#2222cc', 'Two', bar), S03: field('#22aa22', 'Three', tri) },
    { palette: { bg: '#202020', fg: '#f0f0f0', accent: '#e0c040', accent2: '#40c0e0' } });
  window.SHOWREEL = {
    title: { en: 'Film layer spike' }, slug: 'film-spike', footnote: { en: '' },
    languages: [{ id: 'en', label: 'EN' }],
    formats: { d: [1600, 900], m: [900, 1600] }, formatLabels: { d: 'Desktop 16:9', m: 'Mobile 9:16' },
    controls: { pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true, notes: false },
    ui: { en: { reduced: 'Reduced motion', reducedOn: 'Reduced motion: on', play: 'Play', pause: 'Pause', muted: 'Sound off', sound: 'Sound on', rp: 'Replay', lp: 'Loop', fm: 'Format', lg: 'Language', startSound: 'Start with sound', startSilent: 'Start without sound' } },
    pageColor: '#000',
    setup() {},
    render: film.render
  };
})();
