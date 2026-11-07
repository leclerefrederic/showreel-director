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
- Environment check: `python3 scripts/check_env.py` lists required and optional tools (numpy, ffmpeg, Node, fontTools, brotli, jsdom, headless browser), what degrades without each, and the install hint. It never installs anything.
- Audio analysis: `python3 scripts/analyze_audio.py <project>/assets/audio/track.mp3 --out <project>/analysis` prints tempo, bar start times and probable drops, writes `beats.json` and `env.json`. It assumes a steady tempo: verify the bar table by ear and fix tempo changes or a late first beat by hand.
- Asset audit: `python3 scripts/audit_assets.py <project>/assets` flags weight, resolution, personal-data keywords, missing licences, fonts that forbid embedding, rights not confirmed.
- Build: `python3 scripts/build.py <vN>` writes one self-contained HTML and a weight report; fails over the budget. Fonts embed as woff2 when the `brotli` package is installed (`pip install brotli --break-system-packages`), otherwise as woff.
- Contact sheet: `python3 scripts/build.py <vN> --qa-step 4` (or `--qa 0,17.4,40.6`, with `--qa-langs fr,en --qa-modes d,m --qa-tile 420`) writes `<project>/qa/sheet.html`, a page tiling frames per language and format. View it with a screenshot tool, or give it to the user.
- Logic test: `node scripts/harness.js <vN>/dist/index.html --step 0.25` renders every frame in each language and format with a canvas stub. Reports exceptions, non-finite values, text drawn outside the stage and the strings drawn per scene. Exit code 1 if there are issues.
- Player test: `NODE_PATH=<dir containing node_modules/jsdom> node scripts/smoke_player.js <vN>/dist/index.html` checks overlay, start, pause, seek and switches (install jsdom in a scratch folder with `npm install jsdom`).

## What the engine provides
`window.SR`: `clamp`, `lerp`, basic `ease`, `K_(beat)`, `barT(bar)`, `beatInfo(t)`, `envAt(t)` (kick/hat/energy), `setScenes([...])` and `sceneAt(t)`, `stage()` letterbox, `drawFrame()` (pure function of time, language and format). The player supplies the start overlay (language, format, with or without sound), the controls declared by the brief, audio as master clock with latency compensation, a 0.6 s fade-out, a silent fallback, replay or loop, and keyboard shortcuts. Controls the brief did not ask for are hidden.

## What it deliberately does not provide
Text animation styles, shapes, transitions, particles, camera moves, props, layouts, wording, translations, portrait remapping. Build those from `effects-catalogue.md` and the storyboard. If you copy a pattern you saw in an earlier project, check that the brief actually asks for it.

## Known limits
No browser is guaranteed in the session: contact sheets may need the user's eyes or a screenshot tool. The harness measures text with an approximate width, so treat its overflow warnings as leads and confirm visually. The audio analysis handles constant tempo only.
