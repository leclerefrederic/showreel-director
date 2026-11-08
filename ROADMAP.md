# Roadmap

## Done
- Packaging and repo checks: `tools/package.py`, `tools/check.py`, GitHub Action `.github/workflows/check.yml`.
- MP4 export without a browser: `showreel-director/scripts/export_mp4.js`.
- Portability fallbacks and degraded-mode notice (`references/portability.md`, `scripts/check_env.py --notice`).
- Reduced-motion mode (`ctx.reduced`, player toggle, harness and export flags).
- Visual scene cards (`scripts/build_scene_cards.py`).
- GIF download per effect in the effects lab (`engine/gif.js`).
- Process hardening: gates table, decision sheets, look test, notes pad, waiver and existing-project routes, untrusted-content rule.
- Asset layout and naming convention, manifest, organiser and build guard (`references/assets.md`).
- Cut-downs with their own build, audio analysis overrides.
- Guided effects lab (moods first, then their effects) and font picker over curated free fonts (`scripts/build_font_picker.py`, `scripts/fetch_font.py`).
- `SKILL.md` split into a 14 KB router plus per-step references.
- Refactoring: shared helpers `scripts/_common.py` (Python page builders) and `scripts/_reel.js` (harness and exporter).
- Demo reel moved out of the packaged skill (`demo/` at the repository root).

## Next
- Bring Your Own Licensed Material: supplied fonts, images, music and footage under a commercial licence. Read the font embedding flag (`fsType`) in the audit and the organiser; ask which use the licence covers (web or app embedding, video only, unsure) and record it in the manifest licence note; for video-only or unclear licences deliver the MP4 only and keep the HTML private, listed in the release gate; optional glyph subsetting. The same licence question for supplied images, music and footage.
- Design system ingestion (a Claude Design export): needs a real export to build against.
- Automatic check for text overflowing a card or panel (today only a visual check of stills catches it).
- Licence note option in the organiser (`--licence`), instead of editing the manifest by hand.

## Known limits
- The decision sheet embeds one font only.
- Text measurement is an estimate without the `@napi-rs/canvas` package.
- Lab category tabs, counter and GIF tooltip are not translatable.
- The organiser keeps the sub-folders of the uploads (a `source/source/` is possible).
