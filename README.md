# showreel-direrctor

Claude skill that directs motion-design showreels: interview-led brief, feasibility checks, scene-by-scene review, then a self-contained HTML build synced to your music.

## What it does
- Interview in rounds: languages, message, emotion, look and motion, sound, assets.
- Feasibility gate based on recognised standards (Netflix timed text, WCAG, EBU R128, Cinemetrics).
- Scene-by-scene review (OK / MODIFY / DITCH) before anything is generated.
- Audio analysis (tempo, beats, bars, drops) and asset audit.
- 248 previewable effects in an effects lab, with search and "copy my picks".
- Style-neutral engine: no look is imposed, the brief decides.
- Checks before release: harness (NaN, clipped text), player test, release gate.

## Layout
- `showreel-director/` the skill: `SKILL.md`, `references/`, `engine/`, `scripts/`, `demo/`, `evals/`
- `showreel-director.skill` packaged skill (zip of the folder, `evals/` excluded)
- `showreel-director/engine/effects-lab-sample.html` neutral effects lab, open it in a browser

## Install
Open `showreel-director.skill` in Claude and click "Save skill".

## Try it
Ask the skill what it can do, then pick the demo reel or the effects lab.

## Maintenance
- Effects live in `engine/effects/*.js`. After editing: `python3 showreel-director/scripts/export_effects_index.py` (refreshes `references/effects-index.md`) and `python3 showreel-director/scripts/build_effects_lab.py --out showreel-director/engine/effects-lab-sample.html`.
- Rebuild the `.skill` by zipping `showreel-director/` without `evals/` and `__pycache__/`.

## Requirements
Python 3 with numpy and ffmpeg (audio analysis), Node 16+ (tests). Optional: fontTools, brotli, jsdom, a headless browser. `showreel-director/scripts/check_env.py` lists what is missing.

## Licence notes
- `showreel-director/demo/` embeds the track "Deep-Space Funk", whose licence is not confirmed: internal use only. Remove it, or replace the track, before making the repository public.
- Demo fonts: Liberation Sans Narrow Bold and Liberation Mono Bold.
- `evals/` contains synthetic test fixtures (fictional brand "Ploma", placeholder fonts, photo, audio, video; about 8 MB).
- No code licence chosen yet: add a `LICENSE` file.
