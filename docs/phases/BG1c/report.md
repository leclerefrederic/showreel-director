---
type: phase-report
status: current
phase: BG1c
date: 2026-11-09
summary: "Report of BG1c: each scene is tested right after it is written and repaired once."
tags:
  - report
---
# BG1c: test each scene right after it is written, repair once

## Step 0 (read only)

**a) The contract and `ease`.** It said only "basic `ease`" among the names of `window.SR` (engine.md, "What the engine provides"), with no form: nothing told a model that `ease` is an object. The template even destructures it (`const { clamp, ease } = SR;`), which reads like a function. The test "every kit function is in the contract" covered the names of `SRK` only, not the forms of `SR` and not the functions inside an object like `ease`.

**b) One scene in the harness.** `harness.js BUILT_HTML --scene ID` (skill 0.14.0) limits the analysis to the frames of that scene (the loop skips the others). It needs a built page. It can run on one scene file: the app copies the version's frame (project.json, reel.js, film.json, fonts.json) and that one scene file into a scratch folder next to the versions (so `../assets` resolves), and the assembler puts an empty frame in place of every other scene. Cost: one build.py plus one node run, a few seconds (the real tests in this phase took about one second per scene without fonts or a track).

**c) What a scene alone can show.** Without AI: a file that is not valid JavaScript (the assembler says so), a file that throws when the film loads (logged by the page, now counted), exceptions while drawing, values that are not numbers, text outside the stage, text over text. What only shows in the whole film: transitions between two scenes (one hiding the other's text), rhythm and coherence between scenes, the background that crosses scenes, the music landing, and anything that depends on a neighbour.

**d) Where the state is decided.** `SceneRun.State` (waiting, writing, done, failed) in `Availability.swift`, set by `BuildJob.run` (`begin`/`end`) and by `SceneGeneration.generate`. BG1c adds `testing` and `repairing`, plus per run: the layout warnings and their count, and `failedTest`.

## What was done

- The skill (0.18.2): the harness sorts `code errors` and `layout warnings`, lists each repeated error once with its count, and counts a scene that throws at load. `issues: N`, the exit code and the 30-line cap are unchanged. engine.md says `ease` is an object (and the signatures of `clamp` and `lerp`); build-guide.md describes `--scene`.
- The contract (`SceneContract.engineShapes`): the form of every name exported by `window.SR` and `window.SRK`, read from `core.js` and `kit.js` when the request is made: function (with its parameters), object (with its functions and an example call), alias, or data. For `ease`: "an object, never a function. Its functions: lin, in2, out2, io2, in3, out3, io3, outExpo. Call them as SR.ease.lin(t), SR.ease.outExpo(t), never SR.ease(...)".
- `SceneTest`: the test of one scene on a scratch copy, then parsing of the harness lines. `repairsPerScene = 1` is the only constant for the repair.
- `BuildJob.run`: save the file, test (state testing), on a code error one rewrite with the exact errors and the file (state repairing), test again. A second failure marks the scene failed (test), removes its file (empty frame, said as such) and goes on; the Build ends with "Continue" and a message that names the scenes. Layout warnings never trigger a rewrite; they are kept per scene with their count. A failure of the rewrite request itself discards the file and stops like any other failed request.
- The whole-film test: "0 code errors, 6 layout warnings". The Logic test step fails only on code errors; the warnings are an orange step "Layout warnings", so a film with only warnings reads "Build done, with a note".
- UI: the panel lines (testing, repairing, "failed (test): error", "done, 2 layout warnings"), the end card "3 scenes have layout warnings" with Show them, and a sheet with Fix this scene per scene (disabled with its reason when the scene is locked). Fix this scene is one generation behind the usual confirmation card, followed by the scene's own test.
- Journal: one line per test, per repair, per failure.
- `addendum.md` tells Clap about the test and the repair.

## Verified, not verified

- Verified: `tools/verify.sh --fast` during the work, the complete one and the rebuild. 10 new tests (BG1cTests) and the BG1 ones adapted: the contract against the engine as node loads it (this test found two real gaps in my reader: an exported alias `data: D` and `const ex = SR.ease.outExpo`), real harness runs on one scene (ease error, collision as a warning, a clean scene), the whole-film report ("code errors" apart from layout warnings), repair once with the exact error and the file in the request, states testing and repairing visible, failing twice and the Build going on, no repair for a warning, Fix this scene as one request with the warning and the file, a locked scene refused.
- Not verified: any real model call (no paid call), that the model's rewrite actually fixes real errors, the look of the panel and of the warnings sheet (no screen), "Show them" and "Fix this scene" in the window (their logic is tested in the kit).
- Not done: tests run one after the other (BG1b does not exist yet; nothing depends between them, so it can run them in parallel later: one line in ideas.md).

## To check by hand

1. Run the trailer's Build again. If a scene crashes, the panel shows testing then repairing, and the scene ends done; if it fails twice it shows "failed (test)" and the Build ends with Continue.
2. At the end, the Logic test reads "0 code errors, N layout warnings" and an orange "Layout warnings" step; the Build tab says "N scenes have layout warnings" with Show them.
3. In that list, press "Fix this scene" on S15: a card first, then one request, then the scene's warnings are tested again.
