# Roadmap

## Done
- Dark theme from one set of design tokens (contrast-tested), a theme object read from the environment, a view rail (Film, Look, Build, Project) and rounded panels; text never below 11 pt; a source guard that stops views picking their own colours (DS1). DS2 (the strip and the lists) and DS3 (the inspector and the forms) take the 189 remaining colour picks to the theme; there is no light theme.
- Scene rows with one Status icon (six states), Visible and Locked columns; three switches (Visible, Ready, Locked) and Delete scene in the inspector; a real lock (frozen in time and space, a copy of its look, never rewritten by a Build); the Go reads every visible scene is Ready (UI2).
- Left panel: the Storyboard (flat list with transition lines, state icons, "Not in the storyboard") above the Resources browser, one divider remembered per project; the Checks are a badge in the top bar with their list in the centre (UI1).
- 3D layer (`engine/gl`, `SR3D`): Three.js scenes with seeded particles driven by time, a shader library and a GLSL lint, drawn onto the 2D stage; inert without WebGL, reported by the harness (`scripts/test_sr3d.js`, `evals/gl-spike`).
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
- Showreel Studio, native macOS app (`app-swift/`): SwiftUI chat with question cards, preview pane for the pickers and the reel, Keychain key storage, gateway endpoint (Bearer or x-api-key), launch-time environment check with guided install (`tools/setup-env.sh`), screenshot tool so the model can look at the preview, skill fingerprint and capability contract kept in step with the skill (`tools/check.py`).
- Scene files: one `scenes/<ID>.js` per scene, assembled into `main.js` without AI (`scripts/assemble.py`, run by `build.py`), a visible placeholder for a scene with no file, per-scene generation and per-scene fingerprints in the app (no interface yet); a version with only a `main.js` builds as before.
- Fonts in the built film: a font chosen in the Look shows its state (Needs files, Preview only, Embedded); the Add font files card (user and Clap) downloads the weights the Look uses from the open Google Fonts repository into `assets/fonts/` and approves them; the build and the assembly embed them (`fonts.json`), and say so in an orange Fonts step when a font has no file.

## Next
- 3D layer, remaining: export of 3D scenes to MP4 through a headless browser (the Node exporter has no WebGL); a Three.js bundle with named imports (expected 250 to 350 KB, the current file is the full namespace, 0.77 MB); scrolling text block and evaporating text in Canvas 2D (`SRK`) so the text of a 3D film is exportable; a fallback frame for a device without WebGL; tested on phones and on WebGL 1 (the first version was checked in Node only: pixels not verified).
- Showreel Studio v2 (the app as a workspace with a copilot: several projects, file editing, native pickers, process driven by the app): specification in `docs/studio-spec.md`, validated; phase A next.
- Showreel Studio (`app-swift/`): remaining: `--selftest` and a library split so the agent loop is tested without the UI; picks sent straight to the chat; progress and cost display; check which API format each gateway exposes; look and feel polish.
- Bring Your Own Licensed Material, remaining: ask in the interview which use a supplied licence covers (web or app embedding, video only, unsure); deliver the MP4 only for video-only or unclear licences and keep the HTML private; the same question for supplied images, music and footage; optional glyph subsetting. Done: embedding flag (`fsType`) read in the audit and organiser, `--licence` note option.
- Design system ingestion (a Claude Design export): needs a real export to build against.
- Automatic check for text overflowing a card or panel (today only a visual check of stills catches it).
- Distribution of the app to other people: (1) signing and notarization with a Developer ID (a self-signed or ad hoc app is blocked by Gatekeeper on other Macs, and the Keychain prompt returns); for internal use, ask IT about managed distribution; (2) dependencies: today the app relies on the system `python3`, `node`, `ffmpeg` and `tools/setup-env.sh` (numpy, fonttools, jsdom, @napi-rs/canvas); options are bundling arm64 runtimes inside the app (about 300 MB, licences to review, ffmpeg build choice), a first-run installer into Application Support (lighter, depends on network and certificates), or porting the Python scripts to Node to drop one runtime; (3) security review of the `bash` tool for a wider audience (the App Sandbox is incompatible with it); (4) a first-run check that explains what is missing.

## To explore
- Playwright (https://playwright.dev/mcp/introduction) for real-browser checks: playback, seek, muted sound and `ctx.music`, console errors, computed fonts on the picker pages, clipboard copy. Likely shape: Playwright tests run by GitHub Actions rather than the MCP server (deterministic, no token cost); an optional "real browser" tier in the skill when `check_env.py` finds a headless browser; the MCP or CLI only for hands-on exploration on an unlocked machine. A canvas has no accessibility tree, so reel frames still need screenshots; headless browsers play no sound.

## Known limits
- The decision sheet embeds one font only.
- Look board and font picker previews show titles at regular weight only.
- The 3D layer is not verified by the test host (no WebGL in Node): a film with 3D scenes is judged in the player, and the app has no MP4 export for it.
- No ceiling on the agent: a Build that loops costs until Cancel build (the output is the model's maximum, the steps are guarded at 1 000).
- Scenes are written up to 4 at a time (3 by default for this prototype): the frame first and alone, then a sliding window. Scenes written together cannot see each other's result: each request gets one line per scene of the storyboard instead (words, length, mood, passage), so rhythm and vocabulary between neighbours can drift more than when they are written one at a time. When the API limits requests (429, 529) the width goes down by one for the rest of that Build.
- A scene is about 7 000 output tokens and a minute of generation. More compact scenes that reuse the kit's helpers would cut both: not done, a known limit.
- A request that is cut (lost connection, no content for 120 s even with pings, more than 8 minutes) is asked again twice; a 429, a 529 and a retryable 5xx are asked again up to 5 times after the wait the API gives (or 5 s doubled, at most 2 min); the two kinds share one counter per scene; any other answer is not.
- A scene is tested on its own: what only shows in the whole film (a transition that hides a text, rhythm and coherence between scenes, a scene that is fine alone and wrong beside its neighbour) is still judged by the user and by the test of the whole film; the layout warnings of the last Build are kept for the session only.
- A Build reuses a scene when what it was written from is unchanged (its content, look, brief and the music under it, relative to its start). What a neighbour does to it (a transition's free instruction, the scene next to it) does not make it stale, and a change of the scene contract is said on the card without rewriting.
- An MP4 bakes the beat reaction in; a muted version needs its own export (`--silent`).
- Text measurement is an estimate without the `@napi-rs/canvas` package.
- Lab category tabs, counter and GIF tooltip are not translatable.
- The organiser keeps the sub-folders of the uploads (a `source/source/` is possible).
