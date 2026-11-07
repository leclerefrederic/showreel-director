# Roadmap

## Done
- Packaging and repo checks: `tools/package.py`, `tools/check.py`, GitHub Action `.github/workflows/check.yml`.
- MP4 export without a browser: `showreel-director/scripts/export_mp4.js`.
- Portability fallbacks (`references/portability.md`).
- Reduced-motion mode (`ctx.reduced`, player toggle, harness and export flags).
- Visual scene cards (`scripts/build_scene_cards.py`).

## On hold
- **GIF download per effect in the effects lab.** A button that records an effect's canvas animation and saves it as a GIF, so effects can be shared or pasted in a brief. Needs a small GIF encoder inlined in the lab (a few KB) and makes the lab heavier; nothing in the skill depends on it.
- **Demo reel outside the package.** Publish the demo as a GitHub release asset instead of inside the `.skill`. The skill would no longer carry the demo or its Suno track, so it drops from about 2.4 MB to under 0.2 MB, but the "launch the demo" offer would then need a download link or must be removed.
- **Evals with and without the skill.** Run the 7 cases in `showreel-director/evals/` twice (skill on, skill off) and keep the scores in the repo. It shows whether the skill changes behaviour and whether a change makes it worse; it costs sub-agent time and tokens.
