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
- Background library (`engine/backgrounds.js`) and background picker (`scripts/build_background_picker.py`); music-reactive backgrounds with continuous crossfades (`SRB.sequence`, `SR.signals`), off without music, when muted or in reduced motion.
- Look board of design packages (`scripts/build_look_board.py`).
- Guided effects lab (moods first, then their effects) and font picker over curated free fonts (`scripts/build_font_picker.py`, `scripts/fetch_font.py`).
- `SKILL.md` split into a 14 KB router plus per-step references.
- Refactoring: shared helpers `scripts/_common.py` (Python page builders) and `scripts/_reel.js` (harness and exporter).
- Demo reel moved out of the packaged skill (`demo/` at the repository root).

## Next
- Showreel Studio (`app/`, macOS, experimental): first slice written, with a browser mode (`npm run web`) for machines where Electron cannot be downloaded (agent loop, tools, chat, preview pane, question cards); next: test in a real Electron window, picks sent straight to the chat, screenshot tool for the model, bundled ffmpeg and node, progress and cost display.
- Bring Your Own Licensed Material, remaining: ask in the interview which use a supplied licence covers (web or app embedding, video only, unsure); deliver the MP4 only for video-only or unclear licences and keep the HTML private; the same question for supplied images, music and footage; optional glyph subsetting. Done: embedding flag (`fsType`) read in the audit and organiser, `--licence` note option.
- Design system ingestion (a Claude Design export): needs a real export to build against.
- Automatic check for text overflowing a card or panel (today only a visual check of stills catches it).

## To explore
- Playwright (https://playwright.dev/mcp/introduction) for real-browser checks: playback, seek, muted sound and `ctx.music`, console errors, computed fonts on the picker pages, clipboard copy. Likely shape: Playwright tests run by GitHub Actions rather than the MCP server (deterministic, no token cost); an optional "real browser" tier in the skill when `check_env.py` finds a headless browser; the MCP or CLI only for hands-on exploration on an unlocked machine. A canvas has no accessibility tree, so reel frames still need screenshots; headless browsers play no sound.

## Known limits
- The decision sheet embeds one font only.
- Look board and font picker previews show titles at regular weight only.
- An MP4 bakes the beat reaction in; a muted version needs its own export (`--silent`).
- Text measurement is an estimate without the `@napi-rs/canvas` package.
- Lab category tabs, counter and GIF tooltip are not translatable.
- The organiser keeps the sub-folders of the uploads (a `source/source/` is possible).
