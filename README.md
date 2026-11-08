# showreel-director

Claude skill that directs motion-design showreels: interview-led brief, feasibility checks, scene-by-scene review, then a self-contained HTML build synced to your music.

## What it does
- Interview in rounds: languages, message, emotion, look and motion, sound, assets.
- Feasibility gate based on recognised standards (Netflix timed text, WCAG, EBU R128, Cinemetrics).
- Scene-by-scene review (OK / MODIFY / DITCH) before anything is generated.
- Audio analysis (tempo, beats, bars, drops) and asset audit.
- 248 previewable effects in an effects lab, with search, "copy my picks" and a GIF download per effect.
- Built-in glossary so people outside video and editing are understood and the right terms land in the brief.
- Style-neutral engine: no look is imposed, the brief decides.
- Visual scene cards (`scripts/build_scene_cards.py`) for the OK / MODIFY / DITCH review.
- Decision sheets (`scripts/build_decision_sheet.py`): the brief, the style sheet, structure options and the release gate are validated by clicking, never by approving a block of text.
- One home for every file: `assets/source` (originals), `assets/prepared` and `assets/generated` (typed names such as `logo-01-ploma-clair.svg`), a `MANIFEST.csv`, and an organiser that holds sensitive or unlicensed files until decided (`scripts/organize_assets.py`, `references/assets.md`).
- Gates between steps, a look test before the full build, and a review build with a timestamped notes pad for feedback.
- Reduced-motion mode in the player (`ctx.reduced`, from the viewer's setting or a toggle).
- Works with fewer tools: `references/portability.md` maps each step to a fallback.
- MP4 export without a browser (`scripts/export_mp4.js`, Node canvas + ffmpeg), about 100 frames per second.
- Checks before release: harness (NaN, clipped or colliding text), player test, release gate.
- Audio analysis finds tempo, bars, drops, and breakdowns with the bar to hit on when the bass returns.
- Shared drawing helpers (`engine/kit.js`, style-neutral) so projects do not rewrite text, ring, shake, flash and confetti code.

## Layout
- `showreel-director/` the skill: `SKILL.md`, `references/`, `engine/`, `scripts/`, `evals/` (7 cases, English; first results in `evals/RESULTS.md`)
- `tools/` repo tooling (`package.py`, `check.py`), `.github/workflows/check.yml`
- `demo/` demo reel (HTML) and its notes, kept outside the packaged skill
- `ROADMAP.md` ideas on hold
- `CHANGELOG.md` and `tools/bump.py`: skill versions (ship with `python3 tools/bump.py patch|minor|major "note"`)
- `showreel-director.skill` packaged skill (zip of the folder, `evals/` excluded)
- `showreel-director/engine/effects-lab-sample.html` neutral effects lab, open it in a browser

## Install
Open `showreel-director.skill` in Claude and click "Save skill".

## Try it
Demo reel (plays in the browser, click "Start with sound"): https://leclerefrederic.github.io/showreel-director/

Ask the skill what it can do, then pick the effects lab, or the demo reel (`demo/`, not part of the packaged skill).

## Maintenance
- Effects live in `showreel-director/engine/effects/*.js`. After editing them run `python3 tools/check.py --fix` (refreshes `references/effects-index.md` and the sample lab, then re-checks).
- Build the package with `python3 tools/package.py`, then verify with `python3 tools/check.py` (syntax, index and lab up to date, English-only text, `.skill` identical to the folder, demo harness). The same check runs on every push (GitHub Action).
- Ideas on hold are in `ROADMAP.md`.

## Requirements
Python 3 with numpy and ffmpeg (audio analysis), Node 16+ (tests). Optional: fontTools, brotli, jsdom, `@napi-rs/canvas` (MP4 export), a headless browser. `showreel-director/scripts/check_env.py` lists what is missing.

## Licence notes
- `demo/` embeds the track "Deep-Space Funk", generated with Suno. This project is non-commercial and the track is provided for non-commercial use only, under Suno's terms. Do not reuse the track commercially.
- Demo fonts: Liberation Sans Narrow Bold and Liberation Mono Bold.
- `evals/` contains synthetic test fixtures (fictional brand "Ploma", placeholder fonts, photo, audio, video; about 8 MB).
- Code: MIT, see `LICENSE`. The MIT licence covers the code and documentation only, not the Suno-generated demo track (non-commercial, Suno's terms) nor the fonts, which keep their own licences.
