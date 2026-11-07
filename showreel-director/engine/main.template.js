/* main.js — the creative part. EVERYTHING here is a placeholder: replace the look, motion, layouts and text
   with what the brief and storyboard say. The engine (core.js, player.js) imposes none of it.

   Contract:
   - window.SHOWREEL declares title/languages/formats/controls/ui/footnote and a pure render(g, t, ctx).
   - ctx = {SW, SH, mode, lang, env:{kick,hat,energy}, beat:{i,bf}, scene, lt (time in scene), u (0..1 progress)}.
   - render draws in the virtual stage 0..SW x 0..SH (already letterboxed and clipped). Never read the clock inside.
   - Scenes start on beats/bars: setScenes([{name, bar:10}, {name, k:48}, {name, t:12.5}]).
   - Keep the script text in one block (TXT per language, TXTM for portrait) so a rewrite is a one-file swap. */
(function () {
  const { setScenes, ease, clamp } = window.SR;
  const SCENES = setScenes([{ name: 'intro', t: 0 }, { name: 'outro', t: window.SR.data.dur * .6 }]);
  const TXT = { en: { intro: 'Placeholder title', outro: 'Placeholder closing' } };
  window.SHOWREEL = {
    title: { en: 'Showreel' },
    footnote: { en: '' },
    languages: [{ id: 'en', label: 'EN' }],
    formats: { d: [1600, 900] },              // add m: [900, 1600] when 9:16 is in the brief
    formatLabels: { d: 'Desktop 16:9', m: 'Mobile 9:16' },
    controls: { pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true },
    ui: { en: { play: 'Play', pause: 'Pause', muted: 'Sound off', sound: 'Sound on', rp: 'Replay', lp: 'Loop', fm: 'Format', lg: 'Language', startSound: 'Start with sound', startSilent: 'Start without sound' } },
    pageColor: '#000',
    setup(state) { /* rebuild layouts/text when language or format changes */ },
    render(g, t, c) {
      g.fillStyle = '#111'; g.fillRect(0, 0, c.SW, c.SH);
      const s = c.scene; if (!s) return;
      const a = ease.out3(clamp(c.lt / .5));
      g.globalAlpha = a; g.fillStyle = '#fff'; g.font = '700 64px system-ui,sans-serif'; g.textAlign = 'center';
      g.fillText((TXT[c.lang] || TXT.en)[s.name] || '', c.SW / 2, c.SH / 2); g.globalAlpha = 1;
    }
  };
})();
