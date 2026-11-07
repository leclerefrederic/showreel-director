# Roadmap

## Done
- Packaging and repo checks: `tools/package.py`, `tools/check.py`, GitHub Action `.github/workflows/check.yml`.
- MP4 export without a browser: `showreel-director/scripts/export_mp4.js`.
- Portability fallbacks (`references/portability.md`).
- Reduced-motion mode (`ctx.reduced`, player toggle, harness and export flags).
- Visual scene cards (`scripts/build_scene_cards.py`).
- GIF download per effect in the effects lab (`engine/gif.js`).
- Demo reel moved out of the packaged skill (`demo/` at the repository root).

## On hold
- Evals with and without the skill: run the 7 cases in `showreel-director/evals/` twice (skill on, skill off) and keep the scores in the repo.
