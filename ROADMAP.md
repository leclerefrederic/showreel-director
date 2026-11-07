# Roadmap

## Done
- Packaging and repo checks: `tools/package.py`, `tools/check.py`, GitHub Action `.github/workflows/check.yml`.
- MP4 export without a browser: `showreel-director/scripts/export_mp4.js`.
- Portability fallbacks (`references/portability.md`).
- Reduced-motion mode (`ctx.reduced`, player toggle, harness and export flags).
- Visual scene cards (`scripts/build_scene_cards.py`).
- GIF download per effect in the effects lab (`engine/gif.js`).
- Evals run with and without the skill (first round, `evals/RESULTS.md`).
- Demo reel moved out of the packaged skill (`demo/` at the repository root).

## On hold
- Next eval round: several runs per case, multi-turn cases (brief writing, scene review loop, build and release gate), and a test of triggering from the skill description in a fresh conversation. First results: `showreel-director/evals/RESULTS.md`.
