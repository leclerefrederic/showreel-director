/* Reel file: reel.js, one per version folder, optional (without it the assembler uses neutral defaults). Like a scene file it is the BODY of a function and ends with a return.
   It holds what belongs to the whole film and not to one scene: the palette handed to the transitions, what crosses scenes (a background sequence, music reaction, a persistent
   element: functions of the FILM time t) and the declarations of window.SHOWREEL other than render (the assembler adds render). Placeholders only. */
return {
  palette: { bg: '#111111', fg: '#ffffff', accent: '#ffffff', accent2: '#888888' },     // replace with the style sheet's palette
  // background(g, t, c) { },                                                           // drawn first, at film time t
  // overlay(g, t, c) { },                                                              // drawn last, at film time t
  show: {
    title: { en: 'Showreel' }, slug: 'showreel',                                         // any key of window.SHOWREEL except render: title, slug, footnote, languages, formats, formatLabels, controls, ui, pageColor, setup, reviewLang...
    formats: { d: [1600, 900] }                                                          // add m: [900, 1600] when 9:16 is in the brief
  }
};
