# BA1: audit of the Build pipeline (read only)

Nothing was changed in the code, the skill or the versions. Paths are under `app-swift/Sources/`; "KIT" = `ShowreelKit/`, "APP" = `ShowreelStudio/`. Evidence from a real run comes from the owner's project journal (`.studio/journal.jsonl`, times in UTC) and its files, read only.

**A correction to the brief.** The journal shows the Build did run end to end with the real model: v5 (BG1 code, 15 scenes, 16 requests, 17:32 to 17:46Z, about 54 s a scene) and v6 (BG1c/BG1d code, 18:20 to 18:47Z). What has never run is a Build with reuse from a *green* version, and nothing has run under a monitor that records requests.

## 1. The Build as it is now

Button: `BuildViews.swift:28` -> `ProjectModel.startBuild` (APP 393) -> `askAboutFonts` -> `offerBuild` (401): `BuildJob.plan` + `BuildJob.card` **on the main thread** -> sheet -> `confirmBuild` (436) / `rewriteEverything` (421) / `resumeBuild` (439, from the "Build stopped" alert, **no card**) -> `runBuild` (444).

```
runBuild (main)                       activity.build = {generating}   generating = true            APP 446-453
  Film.write(vN/film.json)            (creates the folder: a "husk" if nothing follows)            APP 446
  Task{@MainActor} -> BuildJob.run    (runs off the main thread)                                    APP 454
    plan()                            keep / reuse / write / frame                                  KIT BuildJob 247
    mark(buildjob.json)               marker "started"                                              BuildJob 249
    activity.build = new Build        runs[reel]=waiting|done, runs[id]=done(kept)|waiting          BuildJob 250-262
    carryOver reused files + records  journal "Sxx reused from vK"                                  BuildJob 266-273
    [frame needed]  begin(reel)  ->  1..10 requests (SceneWriter) -> write project.json, reel.js    BuildJob 294-305
    for id in plan.write:                                                                           BuildJob 321
        isCancelled? -> .cancelled
        begin(id)            state: waiting -> writing   (clapPhase: preparing/reading/writing)
        scene() 1..10 requests  -> save(file + record)                                              BuildJob 325-326
        test(id)             state: testing   (python3 build.py + node harness --scene, no AI)     BuildJob 327
        code error?  -> repairing -> 1 request -> save -> test again                                BuildJob 329-338
        still failing -> discard file, state failed(failedTest), journal, go on                     BuildJob 339-347
        else markTested, journal "written", state done                                              BuildJob 348-350
    any failedTests -> .stopped(cause "test")                                                       BuildJob 353-358
    else -> .completed                                                                              BuildJob 360
  finishJob (main)                                                                                  APP 488
    .cancelled: activity.build = nil, toast                  (no journal line)                      APP 492
    .stopped:   activity.build = nil, THEN gatherWarnings, alert "The Build stopped"                APP 496-501
    .completed: gatherWarnings, runChecks(v)                                                        APP 502-505
  runChecks: activity.build = {testing}; BuildRunner.run in place on vN (build.py, harness,
             smoke_player; 180+240+120 s caps); record(report); BuildJob.finish removes the marker;
             activity.build = nil; toast                                                            APP 509-533, KIT Build 141
```

Per-scene states (`SceneRun.State`, KIT Availability 78): `waiting -> writing -> testing -> (repairing -> testing) -> done | failed`. Reused scenes start as `done` with `kept = true` (BuildJob 256). A cancelled step goes back to `waiting` (BuildJob 285).

Other paths that write scenes or the film:
- **Generate** (card, `confirmGeneration` APP ~1428; also Clap's tool `generate_scenes`, KIT Tools 296): `SceneGeneration.generate` (KIT 137). One request per scene, files written **all at once at the end**, no test, no repair, no `tested` mark.
- **Assemble** (`FilmAssembly.run`, KIT FilmState 218): staged copy, build.py + harness + smoke, then moved into the version. No AI.
- **Old single-request Build**: `BuildRunner.prompt` (KIT Build 57) is no longer called by the app flow; only `SelfCheck.swift:242-251` still calls it.

## 2. Every wait that can wait forever

| # | Wait | Timeout? Who cancels? What the user sees | Verdict |
|---|---|---|---|
| 1 | `session.bytes(for:)`, waiting for the headers (KIT MessagesTransport 116) | Watchdog cuts after `idleTimeout` (90 s, setting >= 5 s) of **silence** (82-87); `IdleTimeout` -> journal "stopped at Sxx: idle-timeout" -> alert. `req.timeoutInterval = 300` (109) is an idle timeout too. | bounded |
| 2 | SSE loop `for try await line in bytes.lines` (130) | Same watchdog, but **every line resets it, including `event: ping`** (`pulse.beat()` at 131, before the `data:` filter at 132). No total deadline, no "no content for N s" rule, no cap on elapsed time per request. A stream that sends pings and no text, or one token a minute, never ends. User sees: counter frozen, elapsed time rising, Cancel works. | **can hang** |
| 3 | HTTP error body (120) | Same watchdog | bounded |
| 4 | `SceneWriter.answer`: up to 10 requests per step (`readingTurns + 2`, SceneWriter 41) | Bounded in count; each request only by #2. The card says "1 call per scene" (BuildJob 133) but a scene can cost up to 10 (plus the repair's 10). | bounded in count, **can hang** per request |
| 5 | `Shell.run` (KIT Tools 458-491): python3, node, harness, smoke | `asyncAfter(seconds)` -> `terminate()` (SIGTERM only, never SIGKILL). I checked that `zsh -l -c "...; cmd"` execs the last command, so SIGTERM reaches python3/node. Caps: scene test 180 + 240 s (SceneTest 45, 52); `BuildRunner.run` 180 + 240 + 120 s (Build 155, 172, 197). A process that ignores SIGTERM keeps the continuation unresumed forever. **Not cancellation aware**: `Task.cancel()` does not stop it. | bounded by SIGTERM; **can hang** if SIGTERM is ignored; cancel is late |
| 6 | Same, from `runChecks` / `FilmAssembly` | After Cancel in the `testing` phase the UI is released (APP 381-385) but the shell chain keeps running up to 540 s and writes `dist/` later. | bounded, but a **zombie** |
| 7 | `proposeOperation(card)` in Clap's `generate_scenes` (KIT Tools 304) | Waits for the user's yes; no timeout, by design. While the card is open the chat request is "busy". | waits on the user (by design) |
| 8 | Locks: `ProjectActivity.guardLock` (Availability 143, 151), `Pulse`, `AnthropicTransport.lock`, `Journal.lock` (Journal 133) | All short. `update{}` runs the closure under a non-recursive `NSLock`: a closure that calls `snapshot` or `update` would deadlock. No such call exists today (checked in BuildJob, SceneWriter, SceneGeneration). | bounded (fragile) |
| 9 | `offerBuild` on the main thread (APP 401-407): `plan` calls `SceneModules.status` which decodes `.studio/build.json` on **each** call (`loadBook`, SceneModules 77), `card` calls `SceneGeneration.prompt` per scene (BuildJob 130). | Not measured. Likely under a second at 15 scenes and 6 versions; grows with scenes x versions. | bounded, not measured |
| 10 | `BuildProgressPanel` (ReactionViews 274) re-reads showreel.json and hashes every scene file once a second, in two views. | Small. | bounded |
| 11 | Fonts card (`askAboutFonts`, APP 1386-1391): while the card is open, or `checkingFonts` is set, `startBuild` returns **silently**. `checkingFonts` is declared (APP 240) and read, but never set to true anywhere. | The Build button looks active and does nothing (breaks the UI principle). | UI wait with no reason shown |
| 12 | Font download (KIT FontFiles 229-231) | Has a `timeout` parameter. Not part of the Build proper. | bounded |

What the user sees while waiting: `BuildProgressPanel` (ReactionViews 270-324) shows one line "step · Scene i of N · phase · tokens · total elapsed", and a row per scene. `testing` shows only the word "testing" (ReactionViews 356), no time and no timeout.

## 3. Disagreements between paths, and impossible states

**Build vs Generate vs Fix.**
1. Build tests every scene and marks it (`markTested`, BuildJob 348). Generate and "Fix this scene" never do: `retest` (APP 480-486) runs the test for warnings but does not mark. Real data: v6 `S06` was rewritten by Generate at 19:26Z and has `tested: null`, while `results.v6.ok = true`. `SceneModules.trusted` (SceneModules 144) falls back to the **version's** result, so the next Build will reuse this untested file as if tested.
2. Generate writes nothing until all its scenes are done (SceneGeneration 160-168): a failure on the 3rd of 3 scenes loses two paid answers. Build keeps each one.
3. `BuildJob.markTested(ok: false)` is never called, so `record.tested == false` never exists and the reason "failed its test" (BuildJob 104) is dead. A scene that failed its test has no file and no record.
4. The reason shown on the card is wrong when an earlier version exists but is not trusted: all 14 v6 lines say "its content, look or music changed" although nothing changed; the real cause was v5 untrusted (`tested` nil, result not green).

**Continue vs Build vs Rewrite everything.**
5. "Try again" and "Continue the build" in the alert (ProjectView 94-96, APP 439) start spending right away with **no card, no cost**. The "Continue vN" button (BuildViews 28) shows the card. Same job, two confirmation rules.
6. The marker keeps `force` (BuildJob 246): a crashed Rewrite everything stays one at "Continue". Scenes written in the run but not marked tested are written again.
7. The plan is computed twice (card at APP 405, run at BuildJob 247). Between the two the files can change.

**Cancel.**
8. Three cancel mechanisms (APP 374-389): `genTask`, `testTask`, `buildTask`. A generation started by **Clap's tool** has none of them: `cancelBuild` sets `phase = .cancelling` and cancels nothing; the button is then disabled (ReactionViews 298) until the request ends by itself.
9. Cancel during a scene's test or repair is only seen at the next scene (BuildJob 322). If it is the **last** scene, `run` returns `.completed` (360) and `finishJob` calls `runChecks` (APP 504): the full assembly runs after the user pressed Cancel, and the phase goes from `cancelling` back to `testing`.
10. Cancel leaves no journal line; a stop does (BuildJob 290); a start leaves none; "frame written" leaves none (only "frame reused", BuildJob 272). The run of v6 cannot be reconstructed (section 5).
11. `assembleFilm` and `runChecks` share one `testTask` variable (APP 513, 1364): the second overwrites the handle of the first.

**Impossible or misleading combinations.**
12. `.stopped` sets `activity.build = nil` (APP 497) and **then** calls `gatherWarnings`, which reads `activity.build` (APP 462-463): it returns at once. The layout warnings of a stopped Build are never gathered, while a completed one does gather them (503).
13. `clapPhase` is set to `.preparing` by a `defer` when an answer ends (SceneWriter 38) and never cleared. During `testing` and `repairing`, and between scenes, the header says "Preparing" with a frozen token count (ReactionViews 283, 302) while no request is in flight. That looks exactly like a hang.
14. `runChecks` returns silently when `Skill.root()` is nil (APP 510), after `runBuild` set `activity.build`: the interface stays on "Building" with nothing running; Cancel only sets `.cancelling` (`buildTask` is nil by then). Unlikely (the skill was found a moment before) but unrecoverable without a restart.
15. After Cancel in `testing`, `testing = false` and `activity.build = nil` while `build.py` runs on: "Test it again" or another Build can then run on the same folder at the same time (zombie, #6 above).
16. `runChecks` builds **in place** in `vN`; Assemble builds on a staged copy and swaps. Two ways to do the same step, only one of them atomic.
17. The frame (`reel.js`) is never tested alone. If it is broken, every scene fails its own test with the same error, is rewritten once, and fails again: up to 2N requests spent on a defect that is not in a scene.
18. Dead code that keeps a second design alive: `BuildRunner.prompt` and its self-check assertions (SelfCheck 242-251), `checkingFonts`, the "failed its test" record state.

## 4. After a crash, a force quit or Cancel

On launch `store.activity.reset()` (APP 278): nothing in memory survives, so nothing can block. The only state on disk is below.

| Moment | On disk | Next launch |
|---|---|---|
| Card open | nothing | nothing |
| `Film.write` done, marker not yet written (APP 446 -> BuildJob 249) | `vN/film.json` only (a **husk**) | No marker: the next Build is `vN+1` (`Versions.next` counts any `vN` folder, Build 16). The husk stays. The owner's project has four: v1 to v4. |
| Frame request | marker, `film.json`, no `project.json` | "Continue vN": plan writes the frame |
| Scene request | marker; earlier files and records. Atomic write, then the record (BuildJob 310-311): a crash between them leaves a file with no record -> `stale` -> written again (waste, not harm) | "Continue vN": written scenes with `tested: true` are kept (confirmed in the v6 journal: S01-S03 were not written again) |
| Test (scratch dir) | `.scenetest-vN-Sxx/` stays (the `defer` does not run); removed only when the same scene is tested again (SceneTest 36) | Harmless, hidden, accumulates |
| After the last scene, `runChecks` | marker stays (removed only at APP 517), `main.js` and `dist/` rewritten in place; a kill can leave them half written (not verified: build.py's own write pattern) | "Continue vN": plan finds nothing to write: "Nothing changed", Assemble only (staged, safe) |
| Cancel | marker kept, files kept, the step in flight lost, no journal line | "Continue vN" |
| Stop on an error | marker kept, journal line, alert | "Continue vN" |

No blocking state was found. What is missing is information: no start line, no cancel line, no per-request log.

## 5. The most likely hang, and what is only a guess

**Evidence (real run, owner's project).**
- v6 first run: frame at 18:20:26Z, S01 18:20:57, S02 18:22:15, S03 18:23:10 (31 to 78 s per scene, journal lines `Test of Sxx` and `Sxx written`). Then **no journal line for 14 min 22 s**; the next line is "S13 reused from v5" at 18:37:32Z, which is the start of a second run (a Continue). In that run S04 was done in 46 s, then 44, 40, 87, 75 s.
- A silent stream would have produced `Build v6 stopped at S04: idle-timeout` at about 18:24:40Z (BuildJob 290). **It did not.** So this was not a silent stream, and not an exception.
- A scene test is short: on a scratch copy of v6, `build.py` took 0.2 s and `harness.js --scene` 0.1 s. A hang inside the tests is unlikely (a scene with an infinite loop would be cut at 240 s and logged by the next line).

**Most likely (code + evidence): the S04 request stayed alive without producing content, and nothing bounds that.** Rule #2 in section 2: any SSE line, `ping` included, resets the watchdog, and there is no total or "no new content" deadline. Counter frozen, time rising, no end, no journal line: this matches, and the owner then used Cancel or quit (both silent, #10) and pressed Continue 14 minutes later. Supporting fact: during the gap the panel would also show the same "Preparing" (#13) after the last scene's test.

**Only a guess.**
- That the API actually sent pings during the stall (documented for the stream, not observed: there is no log of bytes, events or stop reasons).
- That the owner pressed Cancel rather than quitting the app: the journal cannot say.
- A buffering proxy (corporate TLS inspection) that holds the SSE until the end would make a long scene look silent; it would have been cut at 90 s and logged, so it does not explain this gap.
- A second family of hangs the code allows but the journal does not show: Cancel during a test then `.completed` (#9), and the stuck "Building" screen (#14).

## 6. Proposal (not implemented), smallest first

Ranked by risk (low first) and size.

1. **Record what happens** (small, no risk, do first). One line in the journal at: Build start (version, plan counts), each request start and end (step, turn, seconds, output tokens, `stop_reason`, HTTP status), frame written, Cancel. Without it the next hang is again unreadable.
2. **Bound each request in time** (small, low risk): replace "any line resets the watchdog" by "a text or tool delta, or `message_start`/`message_delta`, resets it; pings do not", and add a per-request ceiling (for example 10 min, a setting next to the idle one). Both end as `IdleTimeout`-style stops with the existing "Try again".
3. **Say what is happening while testing** (small): clear `clapPhase` at the end of an answer (SceneWriter 38); show elapsed time on `testing`/`repairing` rows; show "no data for N s" next to the counter once N > 20.
4. **Fix the three state bugs** (small): check `Task.isCancelled` after the loop and return `.cancelled` (BuildJob 353); gather warnings before clearing the activity (APP 497-499); `runChecks`: clear the activity and say why when the skill is missing (APP 510).
5. **Make Shell cancellable and killable** (medium, medium risk): wrap `Shell.run` in `withTaskCancellationHandler` -> `terminate()`, then SIGKILL after 3 s. This also removes the zombie in #15.
6. **One rule for "tested"** (small): `markTested` after Generate/Fix retest; `trusted` must stop falling back on the version's result for a file whose record says nothing; give the card the true reason ("v5 was not tested").
7. **One confirmation rule for Continue** (small): the alert's "Try again" opens the same card.
8. **Stop spending on a broken frame** (small): test the frame once (build the scratch copy with no scene) before the first scene, and stop the Build with the frame's own error.
9. **Husks** (small): create `vN/` only after the frame or the first scene is written, or remove an empty `vN` on stop/cancel/launch.

**Remove rather than fix.** `BuildRunner.prompt` and its self-check lines (keep `contentBrief`, `filmBrief`, `reelBrief`, used by the frame); `checkingFonts`; the `tested == false` branch and its reason; the three separate cancel mechanisms (use one `activeJob` handle with `cancel()` for Build, Generate, Assemble and Clap's generation).

**Is the design too complicated?** Yes, in one place: the *reuse layer* (BG1d). Reuse decisions depend on six inputs (fingerprint, context, contract, record, tested, version result) read from three files, with a silent fallback (#1, #4). Per-scene requests, tests and repair are sound. The simplification I would propose: a scene is reusable only if `tested == true` in its own record (no fallback); drop `context`'s music part from the fingerprint until it is shown to matter; keep the contract note as text only. I do not recommend removing reuse itself: it is the point of BG1d, and the v6 journal shows it working (S01-S03 kept on Continue).

## Tests that would have caught each problem

| Problem | Test that would catch it | Exists today? |
|---|---|---|
| Silent stream cut | `testASilentStreamIsCutWithTheTimeoutMessage` (BG1Tests 219) | **yes** |
| Stream that sends only pings (#2) | stub that emits `ping` every second and no content; the request must end by the ceiling | no |
| Per-request ceiling / slow trickle (#2) | stub that sends one token per 5 s | no |
| Cancel really stops a request | real `Task.cancel()` on a running stream stub, check the end within 2 s | no (`testCancellingStopsAtOnceAndKeepsWhatIsWritten`, BG1Tests 189, only scripts a thrown `CancellationError`) |
| Cancel during a scene test (#9) | cancel while a slow `SceneTest.override` runs; expect `.cancelled`, never `.completed` | no |
| Cancel on the last scene | same, last scene | no |
| Shell timeout and SIGTERM-ignoring process (#5) | `Shell.run("trap '' TERM; sleep 30", timeout: 1)` must return within 5 s | no (only `Shell.run` as a probe, ResourceFlowTests 266, SceneModuleTests 43) |
| Shell cancelled with its task (#6, #15) | cancel a task running `Shell.run("sleep 30")`; the process must be gone | no |
| Stopped Build gathers warnings (#12) | `.stopped` with a scene that has warnings; `layoutWarnings` must hold them | no |
| `clapPhase` while testing (#13) | read the activity while a slow test runs; phase must be nil | no |
| `runChecks` with no skill (#14) | `activity.build` must be nil after it | no |
| Generate marks tested / reuse trust (#1) | Generate, then plan for the next version: the file must not be reused untested | no |
| Reason on the card when the earlier version is untrusted (#4) | plan with an earlier version whose `tested` is nil | no |
| Clap's generation can be cancelled (#8) | cancel during `generateScenes`; request must stop | no |
| Husk folders (#9 of the proposal) | kill after `Film.write`; `Versions.next` must not skip | no |
| Marker after crash | run, abort the task mid-scene, new process: `pending` is the version, plan writes only the missing scene | partly (`testStartOver...`, `testCancelling...` check `pending`) |
| Frame defect costs 2N requests (#17) | broken `reel.js`: the model stub must be asked once, not 2N times | no |
| Journal has start / cancel / request lines | read the journal after a cancelled run | no |
| Reuse itself | BG1dTests (11 tests) | **yes** (with the model and the harness scripted) |

## Not verified in this audit

No real model call was made, and the app was not driven (no screen). The timing of `offerBuild` on the main thread was not measured. The behaviour of `build.py` when killed mid-write was not tested. The claim that the API sends pings during a stall comes from its documented stream format, not from a capture.
