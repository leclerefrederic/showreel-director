/* Showreel player — style-neutral shell logic (DOM). Reads window.SHOWREEL declared in main.js:
   {title, subtitle, footnote, languages:[{id,label}], formats:{d:[w,h], m:[w,h]}, controls:{...}, ui:{lang:{...}},
    setup(state), render(g,t,ctx)}. Colours and fonts come from CSS variables, nothing is hard-coded here. */
(function () {
  'use strict';
  const S = window.SHOWREEL, SR = window.SR, DUR = SR.data.dur;
  const C = Object.assign({ pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true, fullscreen: false, reduced: true }, S.controls || {});
  const $ = id => document.getElementById(id);
  const state = { lang: S.languages[0].id, mode: Object.keys(S.formats)[0], reduced: !!(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches) };
  const nav = (navigator.language || 'en').slice(0, 2);
  if (S.languages.some(l => l.id === nav)) state.lang = nav;
  if (S.formats.m && matchMedia('(orientation:portrait)').matches) state.mode = 'm';
  const UI_DEFAULT = { reduced: 'Reduced motion', reducedOn: 'Reduced motion: on' };
  const UI = k => ((S.ui || {})[state.lang] || (S.ui || {}).en || {})[k] || UI_DEFAULT[k] || k;
  const cv = $('cv'), g = cv.getContext('2d');
  let playing = false, pos = 0, ac = null, buf = null, src = null, gain = null, silent = true, muted = false, vol = .9, loop = !!C.loop, t0 = 0, startedAt = 0, ended = false;
  const hasTrack = !!$('trackdata') && $('trackdata').textContent.trim().length > 100;

  function applyState() {
    if (S.setup) S.setup(state);
    document.documentElement.lang = state.lang;
    document.title = (S.title && S.title[state.lang]) || (S.title && S.title.en) || document.title;
    ['pp', 'mu', 'lp', 'fm', 'lg', 'rp'].forEach(id => { const e = $(id); if (e) e.textContent = UI(id); });
    $('pp').textContent = playing ? UI('pause') : UI('play');
    $('mu').textContent = muted ? UI('muted') : UI('sound');
    if ($('rm')) { $('rm').textContent = state.reduced ? UI('reducedOn') : UI('reduced'); $('rm').classList.toggle('off', !state.reduced); }
  }
  function fit() {
    const dpr = Math.min(2, devicePixelRatio || 1), r = cv.getBoundingClientRect();
    const W = Math.max(2, Math.round(r.width * dpr)), H = Math.max(2, Math.round(r.height * dpr));
    if (cv.width !== W || cv.height !== H) { cv.width = W; cv.height = H; }
  }
  function clock() {
    if (!playing) return pos;
    if (!silent && ac && buf && ac.state === 'running') {
      const lat = Math.min(.3, (ac.outputLatency || 0) + (ac.baseLatency || 0));
      return Math.min(DUR, Math.max(0, ac.currentTime - startedAt - lat + t0));
    }
    return Math.min(DUR, t0 + (performance.now() - startedAt) / 1000);
  }
  function stopSrc() { if (src) { try { src.onended = null; src.stop(); } catch (e) {} src = null; } }
  function play(from) {
    from = SR.clamp(from, 0, DUR - .05); stopSrc(); pos = from; t0 = from; ended = false;
    if (!silent && buf) {
      src = ac.createBufferSource(); src.buffer = buf; src.connect(gain);
      startedAt = ac.currentTime; src.start(0, from);
    } else startedAt = performance.now();
    playing = true; $('rp').style.display = 'none'; applyState();
  }
  function pause() { if (!playing) return; pos = clock(); stopSrc(); playing = false; applyState(); }
  function applyVol() { if (gain) gain.gain.value = muted ? 0 : vol; applyState(); }
  async function boot(withSound) {
    $('ov').style.display = 'none'; silent = !withSound || !hasTrack;
    if (!silent) {
      ac = new (window.AudioContext || window.webkitAudioContext)();
      gain = ac.createGain(); gain.connect(ac.destination); applyVol();
      const b64 = $('trackdata').textContent.trim().replace(/^data:[^,]*,/, '');
      const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
      buf = await ac.decodeAudioData(bytes.buffer);
      await ac.resume();
    }
    play(0);
  }
  function frame() {
    fit(); let t = clock();
    if (playing && t >= DUR - .01) { if (loop) { play(0); t = 0; } else { pause(); pos = DUR - .01; ended = true; t = pos; $('rp').style.display = C.replay ? '' : 'none'; } }
    if (!silent && gain && playing) { // fade out the last 0.6 s
      const f = SR.clamp((DUR - t) / .6); gain.gain.value = (muted ? 0 : vol) * f;
    }
    SR.drawFrame(g, cv.width, cv.height, t, state);
    if (C.seek && document.activeElement !== $('seek')) $('seek').value = Math.round(t * 10);
    $('tm').textContent = fmt(t) + ' / ' + fmt(DUR);
    requestAnimationFrame(frame);
  }
  const fmt = s => Math.floor(s / 60) + ':' + String(Math.floor(s % 60)).padStart(2, '0');

  // Build the overlay from the declared languages/formats, hide controls the brief did not ask for.
  $('ovt').textContent = (S.title && (S.title[state.lang] || S.title.en)) || '';
  const addBtns = (box, items, cur, cb) => { box.innerHTML = ''; items.forEach(it => { const b = document.createElement('button'); b.textContent = it.label; b.className = 'f' + (it.id === cur ? ' on' : ''); b.onclick = () => { cb(it.id); }; box.appendChild(b); }); };
  const refreshOv = () => {
    addBtns($('ovl'), S.languages.length > 1 ? S.languages : [], state.lang, id => { state.lang = id; applyState(); $('ovt').textContent = (S.title[id] || S.title.en); refreshOv(); });
    addBtns($('ovf'), Object.keys(S.formats).length > 1 ? Object.keys(S.formats).map(k => ({ id: k, label: S.formatLabels ? S.formatLabels[k] : k })) : [], state.mode, id => { state.mode = id; applyState(); refreshOv(); });
    addBtns($('ovr'), C.reduced ? [{ id: 'r', label: state.reduced ? UI('reducedOn') : UI('reduced') }] : [], state.reduced ? 'r' : '', () => { state.reduced = !state.reduced; applyState(); refreshOv(); });
    $('ov1').textContent = UI('startSound'); $('ov2').textContent = UI('startSilent');
    $('ovsm').textContent = (S.footnote && (S.footnote[state.lang] || S.footnote.en)) || '';
  };
  $('ov1').onclick = () => boot(true); $('ov2').onclick = () => boot(false);
  if (!hasTrack) $('ov1').style.display = 'none';
  const hide = (id, on) => { const e = $(id); if (e && !on) e.style.display = 'none'; };
  hide('pp', C.pause); hide('seek', C.seek); hide('mu', C.mute && hasTrack); hide('vl', C.volume && hasTrack); hide('lp', C.loop); hide('fm', C.format && Object.keys(S.formats).length > 1); hide('lg', C.lang && S.languages.length > 1); hide('fs', C.fullscreen); hide('rm', C.reduced);
  $('rp').style.display = 'none'; $('rp').onclick = () => play(0);
  $('pp').onclick = () => { if (ended) play(0); else playing ? pause() : play(pos); };
  $('seek').max = Math.round(DUR * 10);
  $('seek').oninput = e => { const v = e.target.value / 10; if (playing) play(v); else pos = v; };
  $('mu').onclick = () => { muted = !muted; applyVol(); };
  $('vl').oninput = e => { vol = e.target.value / 100; applyVol(); };
  $('lp').onclick = () => { loop = !loop; $('lp').classList.toggle('off', !loop); };
  $('fm').onclick = () => { const ks = Object.keys(S.formats); state.mode = ks[(ks.indexOf(state.mode) + 1) % ks.length]; applyState(); };
  $('lg').onclick = () => { const ids = S.languages.map(l => l.id); state.lang = ids[(ids.indexOf(state.lang) + 1) % ids.length]; applyState(); };
  $('rm').onclick = () => { state.reduced = !state.reduced; applyState(); refreshOv(); };
  if ($('fs')) $('fs').onclick = () => document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen();
  addEventListener('keydown', e => {
    if ($('ov').style.display !== 'none') return; // overlay first: the viewer must choose sound or silence
    if (e.key === ' ') { e.preventDefault(); if (C.pause) $('pp').click(); }
    else if (e.key === 'ArrowRight' && C.seek) play(clock() + 5);
    else if (e.key === 'ArrowLeft' && C.seek) play(clock() - 5);
    else if ((e.key === 'm' || e.key === 'M') && C.mute) $('mu').click();
    else if ((e.key === 'l' || e.key === 'L') && C.loop) $('lp').click();
  });
  applyState(); refreshOv(); requestAnimationFrame(frame);
})();
