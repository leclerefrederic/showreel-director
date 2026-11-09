# BG1: the Build writes the scenes one by one, with visible states

## Step 0 (read only)

**a) Before.** `startBuild` sent Clap one message (`BuildRunner.prompt`: read the state, the storyboard, the style sheet, the brief, then engine.md, build-guide.md, steps-3-to-6.md, write project.json, reel.js and every scene file), with the whole agent loop and its tools. `generate_scenes` was different: one model request per scene, no tools, answer text extracted, files written together at the end. Yes, the Build can be a chain of single-scene requests followed by the assembly with no AI: `build.py` already runs `assemble.py`, and `generate` already had the per-scene request. What was missing was the frame (project.json, reel.js) as its own request and the per-file writing.

**b) What one scene needs.** The contract of the file (engine.md, Scene files, 3 962 characters), what the engine provides (1 337), the kit's signatures (header of kit.js, 2 373), the backgrounds' API (header of backgrounds.js, 1 035) and the template (964): about 9 700 characters, read from the skill's files at run time. Today Clap re-reads engine.md (28 397), core.js (5 816), kit.js (7 939), backgrounds.js (13 869), film.js (7 090) and the templates (about 10 000), roughly 70 000 characters, in seven to ten reads.

**c) Without the other scenes?** Yes: a scene is a self-contained function of its local time and its context `c`; the montage is read only through `c`. What must stay coherent (rhythm, vocabulary of effects, palette, fonts, music landing) is given by what every request shares: the same style sheet, brief, look and music grid, a short summary of the scenes already written computed from their files (the engine names they use, their words and feeling), the neighbours and the transitions. The frame (palette, background across scenes) is written first. The assembler and the tests check the result as a whole.

**d) State.** `.studio/build.json` keeps, per version and scene, the fingerprint of the inputs and of the file; `SceneModules.status` says not generated, up to date or stale. BG1 adds the marker `.studio/buildjob.json` (the version a Build began and did not finish, removed when the app has assembled and tested it) and the per-scene states in the activity (waiting, writing, done, failed). A restart reads the files and the records, so it continues at the first scene whose file is missing or stale.

**e) Idle timeout, counter.** None before: only the 300 s `timeoutInterval` of the request, which the stream reset with each byte, so a stream that kept sending pings never ended. The estimated counter counted visible text and, since BF2, tool arguments (`input_json_delta`) too; the API's exact `output_tokens` replaced it at the end of each answer. It only moved every 400 characters, so a stalled connection and a model preparing a long tool call looked the same.

## What changed (app 0.10.0; the skill is untouched)

- `SceneContract` (new): the contract, built from the skill's files; a test fails if a function exported by the kit is not in it, and another that the contract follows the skill.
- `SceneGeneration.prompt`: adds the music under the scene, the summary of the written scenes, the image convention and the note that reading the engine is not normally necessary (the read tools stay).
- `SceneWriter` (new): one step = a request that may read (read_file, list_dir) and ends with its answer; reports Reading / Preparing / Writing and the tokens.
- `BuildJob` (new): the plan (write, keep, carry over a locked scene's earlier file, leave aside), the card (calls, estimate), the frame request, the run (each file saved and recorded at once), stop at the first failure, cancel, continue, start over.
- `AnthropicTransport`: idle timeout by a watchdog on the bytes (default 90 s, one constant `AgentLimits.idleTimeout`, advanced setting in Settings), error "No answer from the API for 90 s"; the first bytes report at once so "Preparing" ends when the first token arrives.
- UI: the card (`BuildConfirmSheet`), the panel with one line per step and the phase, the alert with Try again / Continue the build, the button that says Continue, Start over with a confirmation.
- `addendum.md` describes the new flow. `BuildStop`'s old failure message code (BF1) was removed since the Build no longer goes through the chat; the cut-answer and loop-guard messages of the chat stay. `BuildRunner.prompt` is kept as the whole-film brief that the selftest and the tests read.

## Verified, not verified

- Verified: `tools/verify.sh --fast` during the work, the complete one and the rebuild at the end. 19 new tests (BG1Tests): contract from the skill and complete, plan, card, a full run with scripted model, per-scene states while it runs, phases, a failed scene keeps the others and continuing asks only for what is missing, leaving a failed scene aside, a failing frame, cancel, start over, frame extraction, idle timeout with a stalled stream stub, tool arguments counted.
- Not verified: any real model call (no paid call), that 15 scenes written this way are good and coherent, the real cost and time of a Build, the look of the panel (no screen).
- Point 8 of the request was cut off after "8."; I did not guess it.

## To check by hand

1. Press "Build a new version" on the trailer: the card shows 16 calls and an estimate. Confirm, and watch the panel: one line per step, the phase word, tokens and times moving.
2. Cancel in the middle, then press the button (it says Continue): it should start at the first missing scene.
3. Look at the film for coherence between scenes, and tell me what drifts.
