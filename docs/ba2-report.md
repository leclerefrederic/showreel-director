# BA2: the Build bounded, honest and consistent (app 0.10.3, skill unchanged 0.18.2)

## Two gaps in the request

- Item 9 of the brief stops at "prends la liste de la". I took the list to be the table "Tests that would have caught each problem" of `docs/ba1-report.md` and wrote the tests for every line of it that this phase fixes.
- The brief refers to "section 7 of the report" (item 3) and to its sections "2, 3, 5, 6 et 7". `ba1-report.md` has six sections and the test table, no section 7. Nothing in it differs from the brief for the retries, so I applied the brief.

## What was done, by item

1. **Log.** `BuildLog` (KIT BuildLog.swift) writes each line to the project journal (op "build") and to `~/Library/Logs/ShowreelStudio/build.log` (bounded, no path of the user). Lines: `Build vN started` (kind, counts, the three time rules), `Request <step> started` / `ended` / `failed` (turn, seconds, bytes, content tokens, pings, stop_reason, cause), each retry, `Test of Sxx`, `Cancel asked by button | closing the window | quitting the app | leaving the project`, `Build vN ended: completed | stopped at X | cancelled`. A force quit cannot write a line: it is the one gap.
2. **Bounds.** In `AnthropicTransport` the watchdog now has three rules: silence (idle, 90 s, any byte), no content (`AgentLimits.contentTimeout` = 120 s, only text, tool arguments or thinking deltas reset it, pings never), and the longest request (`AgentLimits.requestTimeout` = 8 min, Settings > Advanced "Longest request (minutes)"). Messages: "No content from the API for 120 s on S04, only keep-alive pings", "Request exceeded 8 min on S04". A stream that ends without `stop_reason` is now a `ConnectionLost`, not a complete answer (this was a second way for a truncated stream to pass as finished).
3. **Retries.** `SceneWriter.answer` asks a step again after a cut (`AgentLimits.stepRetries` = 2, `retryDelay` = 3 s), with the panel line "Connection lost on S07, retrying (1 of 2)" and a journal line per try. Checked that a retry has no side effect: `SceneWriter` only streams and runs `read_file`/`list_dir`; the file and its record are written by `BuildJob` after the answer (BuildJob `save`), and `Generate` writes after all its answers. After the tries the error is "... (tried 3 times)", cause `no-content`, `too-long` or `connection-lost`, the Build stops and the marker offers "Continue vN". An API answer (4xx, 5xx) and the user's Cancel are never retried (idea added for 429/529).
4. **States.**
   - a) Panel: "Testing S04 · 12 s", no token counter, no "Preparing" (`clapPhase` is cleared at the end of every answer and when a test starts); a quiet request says "no data for N s".
   - b) `BuildJob` checks `Task.isCancelled` after each test and after the last scene: a Cancel in the last test returns `.cancelled`.
   - c) `SceneGeneration.generateTested` runs its work in a task registered in `ProjectActivity.cancelRunning()`; `cancelBuild` calls it, so Clap's `generate_scenes` is cancellable.
   - d) `finishJob(.stopped)` gathers the warnings before it clears the activity (`Build.layoutWarnings` is a property, testable).
   - e) `Shell.run` is cancellable (`withTaskCancellationHandler`) and stops with SIGTERM then SIGKILL after 3 s, on timeout as well. The pipes are drained without waiting for a writer that outlived the shell. Also: `runChecks` without the skill now clears the activity and says so (it used to leave "Building" on screen).
5. **One rule for "tested".** `SceneModules.isTested` = the scene's own record says `tested == true`. The fallback on the version's result is gone. `Generate` and `Fix this scene` test each scene after writing and record the pass (`generateTested`, also used for Clap's tool). New plan category `retest`: a scene that is up to date but not recorded as tested is tested again with no request, taken over if it passes, written if it fails (journal line either way). This is the S06 case of the owner's project. A Build whose only work is retests is a real Build (`unchanged` is false) and the card says "0 scenes will be written, N reused unchanged".
6. **True reasons.** `BuildJob.decide` computes them: "its content or look changed", "the brief or the music under it changed", "nothing records how its file was written", "never tested: tested now, no request", "the previous build was not reliable: tested again, no request", "its test failed" (from a small `failed` record kept when a scene fails after its repair), "edited by hand, out of date: kept as it is unless you tick it", "never written", "locked", "rewritten on request".
7. **Cleanup.** a) `Versions.pruneHusks` removes a `vN` that holds only film.json, an empty `scenes/`, assembly.json or fonts.json, never the version a Build could continue. It runs when a project is opened and when a Build starts. **v1 to v4 of the trailer project will disappear the next time it is opened.** b) `BuildRunner.prompt` is removed; its content checks now read `BuildJob.frame` and `SceneGeneration.prompt` (the ones that carry the same briefs). Three tests that only tested text of the old message ("The user pressed Go", "Locked scenes (...)") were deleted: the text no longer exists. `checkingFonts` removed (it was never set). The "failed its test" branch (`tested == false`) removed; `markTested(ok: false)` records nothing.
8. **One decision function.** `BuildJob.decide(...)` returns keep, reuse, retest, write, handEdited or skipped, with the version and the reason; `plan` only collects its answers. Reusable means tested, nothing else.

Also from section 6 of the audit: the "Build stopped" alert's Try again and Continue the build now open the same card as the Build tab (proposal 7), and the frame is tested alone before any scene (proposal 8; checked on the real v6 frame: `harness.js` with no scene prints `code errors: 0`).

## Verified

- `tools/verify.sh --fast` during the work, then the complete `tools/verify.sh` (VERIFY OK) and `tools/rebuild-app.sh` (SELFTEST OK, BUNDLE OK, running, pid 82945).
- `BA2Tests`, 20 tests, agent and API simulated, no paid call:
  - **Time rules:** pings alone cut by the no-content rule with the exact message and stats; trickle of text cut at the maximum; stream closed early = connection lost; a real `Task.cancel` stops a running request in under 2 s and is never retried.
  - **Retries:** a lost connection retried once (notice visible, journal line, nothing else asked again); three failures end the step with "tried 3 times", no file, marker kept; an API answer is not retried.
  - **Journal and log:** the start, request and end lines appear in the journal and the log file.
  - **States:** a Cancel in the last test never reaches the assembly; no phase "Preparing" during a test; the warnings survive a stop; a broken frame stops the Build after one request and removes the frame so Continue writes it again.
  - **Shell:** a process that ignores SIGTERM is killed; cancelling the task kills the process.
  - **Tested rule and reasons:** Generate records a pass and does not record a failure; Clap's generation is cancellable; an untested scene is tested again with no request and reused; one that fails its test is written; the reasons.
  - **Folders:** an empty `vN` is removed, one with work is kept.
- Existing tests adapted (7 assertions: the new reason texts, the journal's last line, the cleared phase, the reads of the removed brief).

## Not verified

- No real model call, so the retry and the two new rules were not seen against the real API; the time limits are tested against a stub.
- No screen: the new panel lines, the Settings field, the card after "Try again" and the alert flow were not looked at.
- Not tested in code: `cancelBuild(by:)` writing its line (app target), `runChecks` without the skill, pruning at launch (the function is tested, its calls are not).
- A command whose child process ignores SIGTERM can still outlive its shell (the call returns, the child keeps running): added to `docs/ideas.md`.
- The cause of the 14 minutes in v6 is still not proven. If it comes back, `build.log` and the journal will now say whether the request was alive with pings, trickling, or cut.

## To check by hand

1. Open the trailer project: v1 to v4 are gone (empty folders), v5 and v6 stay.
2. Press "Build a new version": the card should say "0 scenes will be written, 15 reused unchanged" with S06 and S13's reasons ("never tested ..."; S13 is edited by hand so it is kept as it is). After the yes, S06 is tested with no request.
3. During a Build, the header must say "Testing S05 · 3 s" while a scene is tested, then "Clap is writing the film" again.
4. Settings, Advanced: "Longest request (minutes)" (empty = 8).
5. Look at `~/Library/Logs/ShowreelStudio/build.log` after a Build: one line per request.
6. Unplug the network during a scene: the panel says "Connection lost on Sxx, retrying (1 of 2)".
