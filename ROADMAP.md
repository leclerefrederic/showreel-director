# Roadmap

Ideas on hold. Nothing here is started.

## Done
- Packaging and repo checks: `tools/package.py`, `tools/check.py`, GitHub Action `.github/workflows/check.yml`.
- MP4 export without a browser: `showreel-director/scripts/export_mp4.js`.

## Next candidates
- MP4: hardware-accelerated encoding options, a `--lang` loop to export every language and format in one run, a frame-compare tool against the browser.
- Portability: a fallback section for environments without the Cowork tools (Claude Code, other agent platforms): folder request, presenting files, artifacts.
- Reduced motion: a player option and a `ctx.reduced` flag that switches off shake and flashes.
- Visual scene cards: an HTML sheet of storyboard cards for the OK / MODIFY / DITCH review.
- GIF download per effect in the effects lab.
- Demo reel outside the package: publish it as a release asset to keep the `.skill` light.
- Run the evals with and without the skill and track the results in the repo.
