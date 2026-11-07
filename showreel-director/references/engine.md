# Engine and scripts (style-neutral plumbing)

The `engine/` and `scripts/` folders hold plumbing only: time, beats, audio clock, controls, build, tests. They have no palette, font, shape, effect or script of their own, so they cannot bias the look. The creative code (`main.js`: scenes, layouts, effects, text, props) is always written from the brief and storyboard. Reuse the plumbing so the effort goes to the design and the known timing, audio and controls bugs do not come back.

## Project layout
```
<project>/
  assets/  analysis/  brief.md  storyboard.md  qa/
  v1/
    project.json     title, main, track, fonts, CSS tokens, weight budget (copy engine/project.template.json)
    main.js          the creative part (start from engine/main.template.js)
    dist/index.html  built output
```
Paths in `project.json` are relative to the `vN/` folder (`../assets/audio/track.mp3`, `../analysis`). A new version is a copy of the previous `vN/` folder.

## Commands (run from the skill folder; `<vN>` is the version folder)
- Effects lab: `python3 scripts/build_effects_lab.py --out <project>/qa/effects-lab.html --bg #... --fg #... --accent #... --accent2 #... --font <font file> --family "<name>"` writes a page animating the effects of the catalogue in the user's palette and font, with a sample-text field, category filter, hearts and a copy-my-picks button. Present it in round 3.
- Environment check: `python3 scripts/check_env.py` lists required and optional tools (numpy, ffmpeg, Node, fontTools, brotli, jsdom, @napi-rs/canvas, headless browser), what degrades without each, and the install hint. It never installs anything.
- Audio analysis: `python3 scripts/analyze_audio.py <project>/assets/audio/track.mp3 --out <project>/analysis` prints tempo, bar start times, probable drops, and **breakdowns** (bass out for 4+ beats) with the **return** (bass back) and the bar to hit on, then writes `beats.json` (with `breakdowns` and `returns`) and `env.json`. On tracks with no loud/quiet jump the drop test finds nothing; use the returns instead, or choose emphasis moments from the bar energy table and by ear. It assumes a steady tempo: verify the bar table by ear and fix tempo changes or a late first beat by hand.
- Asset audit: `python3 scripts/audit_assets.py <project>/assets` flags weight, resolution, personal-data keywords (licence and consent notes are matched in English: read notes written in another language yourself), missing licences, fonts that forbid embedding, rights not confirmed.
- Build: `python3 scripts/build.py <vN>` writes one self-contained HTML and a weight report; fails over the budget. Fonts embed as woff2 when the `brotli` package is installed (`pip install brotli --break-system-packages`), otherwise as woff.
- Contact sheet: `python3 scripts/build.py <vN> --qa-step 4` (or `--qa 0,17.4,40.6`, with `--qa-langs fr,en --qa-modes d,m --qa-tile 420`) writes `<project>/qa/sheet.html`, a page tiling frames per language and format. View it with a screenshot tool, or give it to the user.
- Logic test: `node scripts/harness.js <vN>/dist/index.html --step 0.25` renders every frame in each language and format with a canvas stub. Reports exceptions, non-finite values, text collisions (two different texts overlapping for 3 or more consecutive samples), text drawn outside the stage and the strings drawn per scene. Exit code 1 if there are issues.
- Scene cards: `python3 scripts/build_scene_cards.py storyboard.md --out <project>/qa/scene-cards.html --title "..." [--bg --fg --accent --accent2 --font --family]` writes the visual sheet used before the scene-by-scene review.
- MP4 export: `NODE_PATH=<dir with node_modules/@napi-rs/canvas> node scripts/export_mp4.js <vN>/dist/index.html --out <vN>/dist/reel.mp4 [--mode m] [--start S --end S]` renders frames without a browser and muxes the track with ffmpeg (about 100 fps at 1600x900). Install the canvas package in a scratch folder (`npm install @napi-rs/canvas`) after asking the user.
- Player test: `NODE_PATH=<dir containing node_modules/jsdom> node scripts/smoke_player.js <vN>/dist/index.html` checks overlay, start, pause, seek and switches (install jsdom in a scratch folder with `npm install jsdom`).

## What the engine provides
`window.SR`: `clamp`, `lerp`, basic `ease`, `K_(beat)`, `barT(bar)`, `beatInfo(t)`, `envAt(t)` (kick/hat/energy), `setScenes([...])` and `sceneAt(t)`, `stage()` letterbox, `drawFrame()` (pure function of time, language and format). The player supplies the start overlay (language, format, reduced motion, with or without sound), the controls declared by the brief, audio as master clock with latency compensation, a 0.6 s fade-out, a silent fallback, replay or loop, and keyboard shortcuts. `ctx.reduced` comes from `prefers-reduced-motion` or the player's toggle. Controls the brief did not ask for are hidden.

`window.SRK` (`engine/kit.js`, inlined with core.js): style-neutral drawing helpers so each project does not rewrite them: text with scale/alpha/rotation, fit-to-width, per-letter control, slam-in, rings, rects, progressive check mark, screen shake and flash lists, scramble, and a confetti cannon (one celebration per film). Colours, fonts and wording are always passed in by the project (`SRK.init({title, mono})` sets the two font families). Read the header of `kit.js` for the signatures. Use what the brief needs; the kit adds no look of its own.

## What it deliberately does not provide
Effect choices, palettes, fonts, scene layouts, wording, translations, portrait remapping (the kit only provides the low-level helpers named above). Build those from `effects-catalogue.md` and the storyboard. If you copy a pattern you saw in an earlier project, check that the brief actually asks for it.

## Known limits
No browser is guaranteed in the session: contact sheets may need the user's eyes or a screenshot tool. The harness measures text with an approximate width, so treat its overflow and collision warnings as leads and confirm visually. Slam-in frames (text scaled up for a few frames) can show up as "outside the stage" on purpose. The audio analysis handles constant tempo only.
