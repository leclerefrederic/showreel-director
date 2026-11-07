# Roadmap

Ideas on hold. Nothing here is started.

## Next candidates
- **Packaging and repo checks.** `scripts/package.py` to build `showreel-director.skill` (zip of the skill folder without `evals/` and `__pycache__/`) and `scripts/check_repo.py` to verify: script syntax, effects index and effects lab up to date, `.skill` identical to the folder, no stray language or cache files. Then a small GitHub Action running both.
- **MP4 export.** Frames are a pure function of time, so they can be rendered one by one with a Node canvas (no browser) and muxed with the audio through ffmpeg. Needs a spike to confirm font registration, canvas filters and speed.

## Other ideas
- Portability: a fallback section for environments without the Cowork tools (Claude Code, other agent platforms): folder request, presenting files, artifacts.
- Reduced motion: a player option and a `ctx.reduced` flag that switches off shake and flashes.
- Visual scene cards: an HTML sheet of storyboard cards for the OK / MODIFY / DITCH review.
- GIF download per effect in the effects lab.
- Demo reel outside the package: publish it as a release asset to keep the `.skill` light.
- Run the evals with and without the skill and track the results in the repo.
