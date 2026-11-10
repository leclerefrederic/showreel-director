---
type: phase-prompt
status: current
phase: RF2
date: 2026-11-10
summary: "Hardens four fragile spots of the app glue (capture load timeout, stepper repeat timer, shared font registry, thumbnail tasks) with tests first."
tags:
  - prompt
---

# Phase RF2: harden the fragile glue (refactoring 2 of RF0)

Read CLAUDE.md first and follow every rule (never run git; English interface; answer the owner in French and short; no screen, so say what was not seen). Use `graphify query` before reading files. Run only after RF1 is built. **Hardening only: no feature, no behaviour the owner can see changes except that the failures below stop happening.** Same class as the CR1 crash: a deferred call acts on a thing that is no longer the one it was made for.

## Source

`docs/Claude/phases/RF0/report.md`, section "5. Fragile glue and lifetimes" items 1 to 4 and section 3, item 2. Re-read the code first: lines may have moved (W4c, RF1). For each item write down in the report: the failing scenario, a test or the reason none is possible, and the fix.

## The four fixes

1. **`SceneCapture` load timeout** (`SceneCapture.swift`, `load`): the 20 s sleeping task always calls `finishLoading(false)` and can resume a later load's continuation, so a capture that would work fails and the failure is stored against the scene file. Tie the wait to its load: a pure `LoadGate` in ShowreelKit (identity-tagged completion: only the load that owns the token can finish it; a stale timeout is a no-op), with unit tests (stale timeout after a newer load, double finish, timeout of the current load). `SceneCapture` uses it. Also: a failure caused by a timeout or by a cancelled load must not be stored as the scene's failure (it should retry), only real failures are.
2. **Stepper repeat timer** (`FormViews.swift`, the `Timer` of the field's button): stop and release it when the view disappears or the value source changes (`onDisappear`, and in `deinit` of the owning object if there is one). Extract the repeat logic into a small pure type in Kit if that makes it testable (start, stop, tick count, stop is idempotent) and test it.
3. **Fonts registered by name in a shared renderer** (`EngineService.swift`, `registeredFonts`): key the registry by file identity (path plus size and modification date, or a hash) as well as name, so two projects with the same font name and different files each get theirs. A pure key function in Kit with a test (same name, different file gives two keys; same file gives one).
4. **Thumbnail tasks at close** (`ProjectModel.deinit`, `SceneThumbModel.swift`): cancel `thumbTask` and `thumbDelay`, empty the queue, and make a capture that finishes after its project closed drop its result instead of writing into the closed project's folder.

## Rules

- Each fix first as a failing test when it can be tested (Kit), otherwise say in the report why not and how the code was checked.
- Keep W4b's rules (one capture at a time, never during a build, quiet delay) and the UI principle.
- Do not touch other glue (key monitors, `WindowGuard`, `ReelPlayer`) beyond what the four items need; list anything new you find as a line of the report, not a change.

## Verification

`tools/verify.sh --fast` during; at the end the full `tools/verify.sh`, release notes in RELEASE-NOTES-APP.md, `python3 tools/bump_app.py patch "Glue hardened: capture timeout, stepper timer, font registry, thumbnail tasks"`, then `tools/rebuild-app.sh`. Report in `docs/Claude/phases/RF2/report.md` (each item: scenario, test, fix, confidence, what was not seen on screen). Then `python3 tools/docs_index.py --write` and `python3 tools/check_docs.py`. Stop after the phase.
