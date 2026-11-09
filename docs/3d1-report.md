# Phase 3D1 report: the 3D layer, visible and honest in Studio

## Step 0 (read only, checked)
- **a) Thumbnails and drafts.** They never read the scene's own file: `EngineService.sceneFrames` draws a stand-in from the project's look (the scene's first line over the project's background, palette and title font, with an effect of the pack), for every scene. A scene that uses SR3D therefore gets the same kind of thumbnail as any other: not empty, no crash, and not its 2D layers either (the stand-in is the look, not the scene). The viewer already says "Preview: a quick draft, not the assembled film" over drafts. So a 3D scene is not shown *differently* misleadingly: **item 2 was not built** (no change to the thumbnails or the viewer).
- **b) The player.** `ReelPlayer` is a plain `WKWebViewConfiguration` (only the autoplay rule and a stylesheet hiding the bar and the start overlay) loading `dist/index.html` with `loadFileURL`; nothing in the app turns WebGL off, and WKWebView has it on by default. What I can affirm without a screen: the page loads with the same code path as any film and nothing in the app blocks WebGL. Whether the 3D actually draws is **not verified** (no screen).
- **c) Weight.** The gl-spike film weighs 0.85 MB in total (the Three.js bundle is 0.77 MB), against a budget of 5 MB: the check does not fail with +0.8 MB. `build.py` fails only above the project's `weight_budget_mb`.
- **A defect the audit had not seen.** The *player test* (`smoke_player.js`, jsdom) failed on the gl-spike film: "no script errors" red, with `THREE.WebGLRenderer: Cannot read properties of undefined (reading 'precision')`. The test answers every `getContext` with a stand-in, WebGL included, so the 3D layer believed WebGL was there and Three.js threw. In the app that meant a red "Player test", the verify gate left open and the version not counted as working: the opposite of the false green, and a false red. `tools/check.py` never ran the player test on the 3D film.

## Done
- **Skill 0.18.1** (patch): `smoke_player.js` now answers `null` for a WebGL context, like a host without WebGL, so the 3D layer takes its documented inert path; `tools/check.py` runs the player test on the gl-spike film; `references/portability.md` says that a film with 3D scenes is judged in the host's player and has no MP4 in the app. Notes written first.
- **App 0.9.1**: `BuildRunner.run` reads the harness line "3D layer: no WebGL ..." (`hasThreeD`) and adds a separate step **"3D scenes"**, orange (`.tight`), with "This film has 3D scenes. The logic test cannot draw them: play the film to look at them. No MP4 export for this film." The "Logic test" stays green for its 0 issues; the step is not counted by the build gate or the verify gate; a film without 3D has no such step. When every check passed and only an orange step remains (3D, or a font with no file), the toast says "Build done (vN), with a note: ..." instead of "finished with a problem".
- `capabilities.json` (the "Build the reel, test it and play it" row, same need as in portability.md) and `addendum.md` (two lines for Clap: not tested by the harness and no MP4, never promise the MP4; offer 3D only when depth is the point). `ROADMAP.md`: one line in the known limits. `check.py` green.
- The app embedded in the repository build was rebuilt: `Contents/Resources/skill/SKILL.md` says **0.18.1** (before: 0.17.0).

## Verified
- `tools/verify.sh` complete: OK; `tools/rebuild-app.sh`: SELFTEST OK, BUNDLE OK (standalone), app running (pid 48582); the app's `Info.plist` says 0.9.1, the embedded skill 0.18.1.
- By hand in this session, outside the app: gl-spike built (0.85 MB), harness `issues: 0` with the "3D layer: no WebGL" line, player test red before the fix and green after.
- 4 new tests (`ThreeDTests`): the harness line is recognised and nothing else; with and without the step the report is built, logic test clean, player test clean, the build gate and the verify gate "passed", and the report is all green only without the step; a real Build of gl-spike gives the orange step with the exact words and both gates passed; the shared files and the portability table carry the words; plus an assertion that a film without 3D has no 3D step.

## Not verified (no screen)
- Whether the 3D is drawn in the app's player.
- The look of the orange step and of the "with a note" message.
- Thumbnails and drafts of a 3D film (unchanged: look stand-in).

## To check by hand
1. Build `evals/gl-spike` in a project (copy `v1` into a project and run Build): the steps are green for the build, the logic test and the player test, and **orange "3D scenes"** with the sentence; the toast says "Build done (v1), with a note".
2. Play the film in the player: does the 3D (particles, sphere, glow) appear? Say yes or no.
3. Look at the thumbnails of the two scenes in the strip and the viewer's draft: they show the look stand-in with the draft tag; say if that is misleading for a 3D scene.
4. Try the MP4 export of that film outside the app (the skill's own exporter cannot render it): expected, no MP4 here.
5. A film without 3D: no "3D scenes" step.
