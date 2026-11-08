/* main.js — the creative part. EVERYTHING here is a placeholder: replace the look, motion, layouts and text
   with what the brief and storyboard say. The engine (core.js, player.js) imposes none of it.

   Contract:
   - Images listed under "images" in project.json are used with SR.img(key), which returns null until ready: const im = SR.img('shot-01'); if (im) g.drawImage(im, x, y, w, h).
   - window.SHOWREEL declares title/languages/formats/controls/ui/footnote and a pure render(g, t, ctx).
   - ctx = {SW, SH, mode, lang, reduced, music, env:{kick,hat,energy}, beat:{i,bf}, scene, lt (time in scene), u (0..1 progress)}.
     ctx.music is true only while a track is audible (there is a track, sound is on, not muted). Anything that reacts to the beat must use SR.signals(ctx), which is null
     without music or in reduced motion, so a silent or muted reel stays calm. Backgrounds (engine/backgrounds.js, window.SRB, inlined when this file mentions SRB):
     SRB.draw(id, g, W, H, t, pal, {reduced: c.reduced, sig: SR.signals(c), mood: SRB.moodFor(pack)}), or SRB.sequence(...) for one continuous background with crossfades; draw it with the reel time t, not c.lt.
     ctx.reduced is true when the viewer asked for reduced motion: drop screen shake and flashes, soften big scale jumps and strobing.
   - render draws in the virtual stage 0..SW x 0..SH (already letterboxed and clipped). Never read the clock inside.
   - Scenes start on beats/bars: setScenes([{name, bar:10}, {name, k:48}, {name, t:12.5}]).
   - window.SRK (engine/kit.js) offers neutral helpers: SRK.init({title, mono}); SRK.text, slam, letters, ring, shake, flash, confetti... (see its header).
   - Keep the script text in one block (TXT per language, TXTM for portrait) so a rewrite is a one-file swap. */
(function () {
  const { setScenes, ease, clamp } = window.SR;
  const SCENES = setScenes([{ name: 'intro', t: 0 }, { name: 'outro', t: window.SR.data.dur * .6 }]);
  const TXT = { en: { intro: 'Placeholder title', outro: 'Placeholder closing' } };
  window.SHOWREEL = {
    title: { en: 'Showreel' },
    // reviewLang: 'en', // language of the review pad labels (key into ui), when it differs from the reel language
    slug: 'showreel', // short name used in export file names: <slug>_<vN>_<mode>_<lang>.mp4
    footnote: { en: '' },
    languages: [{ id: 'en', label: 'EN' }],
    formats: { d: [1600, 900] },              // add m: [900, 1600] when 9:16 is in the brief
    formatLabels: { d: 'Desktop 16:9', m: 'Mobile 9:16' },
    controls: { pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true, notes: false /* true in review builds only: timestamped notes, key N */ },
    ui: { en: { reduced: 'Reduced motion', reducedOn: 'Reduced motion: on', play: 'Play', pause: 'Pause', muted: 'Sound off', sound: 'Sound on', rp: 'Replay', lp: 'Loop', fm: 'Format', lg: 'Language', startSound: 'Start with sound', startSilent: 'Start without sound', note: 'Note', noteAt: 'Note at', noteHint: 'What should change here?', noteAdd: 'Add note', noteCopy: 'Copy notes', noteCopied: 'Copied', noteClose: 'Close', noteHeader: 'Review notes (draft, please confirm in chat):', noScene: 'no scene', cutIn: 'cut in' } }, // translate every key for each reel language (fr: {...}); the last eight keys only matter in a review build
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
