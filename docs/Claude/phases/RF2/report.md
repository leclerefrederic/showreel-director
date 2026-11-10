---
type: phase-report
status: current
phase: RF2
date: 2026-11-10
summary: "Report of RF2: four fragile glue spots hardened (capture load timeout, stepper repeat timer, font registry key, thumbnail tasks at close); tests; app 0.21.3."
app_version: 0.21.3
skill_version: 0.18.2
prompt:
  - "[[phases/RF2/prompt]]"
tags:
  - report
---

# RF2: harden the fragile glue

Pure rules are in `ShowreelKit/GlueGuards.swift`, tests in `RF2Tests.swift` (11). Everything is the same class as the CR1 crash: a deferred call acts on a thing that is no longer the one it was made for.

## 1. `SceneCapture` load timeout

- **Scenario:** the 20 s sleeping task of load A fires while load B is pending and resumes B's continuation with `false`; the capture fails and the failure is stored against the scene file.
- **Test:** `LoadGate` (`testStaleTimeoutAfterANewerLoadIsANoOp`, double finish, current timeout, superseded load, `LoadOutcome.isTransient`).
- **Fix:** `LoadGate` tags each load with a token; the timeout finishes only its own token. A new load first resumes a still pending one as `superseded`. `CaptureError.transient` is true for a timeout or superseded load, and `ProjectModel.finishThumb` does not record such a failure, so the scene is retried.
- **Confidence:** high on the logic (tested); the timeout path itself not run against a real hanging page. Not seen on screen.

## 2. Stepper repeat timer

- **Scenario:** button held, field disappears, no `onEnded`: the 0.12 s timer keeps stepping a stale value.
- **Test:** `HoldRepeat` (ticks, stop idempotent, no tick after stop, released object stops, restart replaces).
- **Fix:** `StepperField` uses `@StateObject HoldRepeat` (stopped in its `deinit`) and `.onDisappear { hold.stop() }`.
- **Confidence:** high on the type; the SwiftUI disappear path not seen on screen.

## 3. Fonts registered by name

- **Scenario:** two projects with the font name "X" over different files: the second gets the first's.
- **Test:** `FontIdentity` (same name, different path or size gives two keys; same file one key; the file key changes when the file does).
- **Fix:** `EngineService.registeredFonts` holds `FontIdentity.key(name:file:)`. The font file is resolved before the check. The renderer registers by family name, so a second file of the same name is declared again under that family (the latest declaration wins in the page); whether the engine page then redraws with it was not checked.
- **Confidence:** medium (the key is tested; the renderer's override behaviour is read, not run).

## 4. Thumbnail tasks at close

- **Scenario:** the capture loop held `self` strongly across the capture, so a closed project stayed alive until the capture ended and then wrote its picture into the closed folder.
- **Test:** none possible in Kit (the model and `SceneCapture` are Studio types); checked by the compiler, `verify.sh` and reading.
- **Fix:** the loop holds the model weakly across the `await` (`nextThumbJob`, `finishThumb`); `ProjectModel.deinit` calls `stopThumbs()` (cancels `thumbDelay` and `thumbTask`, empties the queue); a result that arrives after cancellation or release is dropped. W4b rules unchanged (one at a time, never during a build, quiet delay).
- **Confidence:** medium.

## Found, not changed

- `refreshStaleThumbnails` is still dead (RF0 item 8).
- A timed-out capture is retried at the next `refreshThumbStates`, with no cap: a page that always times out is retried on every refresh.

## Not seen on screen

Hold a stepper arrow and change scene; open two projects with the same font name; close a project during a capture.
