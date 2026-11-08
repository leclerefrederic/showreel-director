/* main.js in film format — the creative part, everything here is a placeholder. Use it instead of main.template.js when the version folder holds film.json
   (written by the app: the montage with the exact start, duration and transition of every scene; build.py inlines it as SR.data.film).
   One module per scene, named by the scene ID, each draws with its own local time lt in the stage 0..c.SW x 0..c.SH. ONE call, SRF.fromData, assembles them: it reads the
   starts, durations and transitions from film.json, so none of them is copied here. Do not edit film.json.
   Scene modules: render(g, lt, c). lt is the time in the scene (seconds); c is the engine context plus scene, index, u (0..1), sig (SR.signals(c)), t (film time).
   While a transition overlaps a cut the outgoing module keeps drawing past its end (lt beyond its duration, u stays 1) and the incoming one draws from lt = 0 (c.pre is true),
   so animate with clamp(lt / d) and let the last state hold. What crosses scenes (a background sequence, music reaction, a persistent element) is a function of the film
   time: background(g, t, c) and overlay(g, t, c) below. Transitions colour themselves with the palette handed to SRF.fromData (roles bg, fg, accent, accent2).
   Everything else in engine.md applies (ctx.reduced, SR.img, SRK helpers, SRB backgrounds, the declarations of window.SHOWREEL). */
(function () {
  const { clamp, ease } = window.SR;
  const MODULES = {
    // S01(g, lt, c) { ... },
    // S02(g, lt, c) { ... },
  };
  const film = window.SRF.fromData(MODULES, {
    palette: { bg: '#111111', fg: '#ffffff', accent: '#ffffff', accent2: '#888888' },   // replace with the style sheet's palette
    // background(g, t, c) { },
    // overlay(g, t, c) { },
  });
  window.SHOWREEL = {
    title: { en: 'Showreel' }, slug: 'showreel', footnote: { en: '' },
    languages: [{ id: 'en', label: 'EN' }],
    formats: { d: [1600, 900] },              // add m: [900, 1600] when 9:16 is in the brief
    formatLabels: { d: 'Desktop 16:9', m: 'Mobile 9:16' },
    controls: { pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true, notes: false },
    ui: { en: { reduced: 'Reduced motion', reducedOn: 'Reduced motion: on', play: 'Play', pause: 'Pause', muted: 'Sound off', sound: 'Sound on', rp: 'Replay', lp: 'Loop', fm: 'Format', lg: 'Language', startSound: 'Start with sound', startSilent: 'Start without sound', note: 'Note', noteAt: 'Note at', noteHint: 'What should change here?', noteAdd: 'Add note', noteCopy: 'Copy notes', noteCopied: 'Copied', noteClose: 'Close', noteHeader: 'Review notes (draft, please confirm in chat):', noScene: 'no scene', cutIn: 'cut in' } },
    pageColor: '#000',
    setup(state) { },
    render: film.render
  };
})();
