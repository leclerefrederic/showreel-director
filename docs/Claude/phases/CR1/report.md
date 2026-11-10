---
type: phase-report
status: current
phase: CR1
date: 2026-11-10
summary: "Report of CR1: the close guard kept the window's delegate weakly and could leave windowDidResize: unanswered; now strong, single, restored; app 0.20.1."
app_version: 0.20.1
skill_version: 0.18.2
prompt:
  - "[[phases/CR1/prompt]]"
tags:
  - report
---

# CR1: crash "unrecognized selector windowDidResize:"

## Step 0

1. **Creation.** `CloseGuardHook` is attached once, in `ProjectWindow.body` (`ProjectView.swift`), as a `.background` of the window's root view. `makeCoordinator` runs once per view identity: one `Coordinator` per window in normal use. `attach` runs again from `updateNSView` (guarded by `w.delegate !== self`), so the same coordinator is not re-wrapped. A second coordinator (view identity lost, for example `env.ready` switching `SetupView` and `ProjectView`, which are inside the `Group`, not the background) would take the first as `original` (a chain), and its weak `original` would die with the first view. In every case `original` was weak and the coordinator stayed the window's delegate after its view left (no teardown): yes, `original` can become nil while the coordinator is still the delegate.
2. **Selectors.** AppKit registers the delegate for each `windowDid…` it responds to when it is set. Through `responds(to:)` the coordinator claimed all of SwiftUI's delegate: `windowDidResize:`, `windowDidMove:`, `windowDidChangeScreen:`, `windowDidEndLiveResize:`, the full-screen ones, key, miniaturize and backing properties. Any of them crashes the same way once `original` is nil.
3. **Other places.** `grep` for `.delegate` in `Sources`: only the hook sets a window delegate. No other window notification observer or frame animation in the app's code (the animation in the trace is AppKit's own zoom/tile).
4. **Failing test.** `CR1Tests.testTheOldGuardClaimedASelectorItCouldNotAnswer` models the old code: it responds to `windowDidResize:`, then, with `original` released, `forwardingTarget(for:)` is nil and `responds(to:)` is false: exactly the state that ends in `doesNotRecognizeSelector`. An XCTest cannot catch the Objective-C exception, so the test shows the unanswerable selector, not the abort itself.

**Verdict:** hypothesis confirmed as the cause that can be shown; the exact path that killed `original` in the owner's session is not known (no screen, no repro).

## Changed

- `ShowreelKit/WindowGuard.swift` (new): one guard per window, `original` held strongly, `install` updates an existing guard instead of wrapping it, `detach` restores the original only if the guard is still the delegate, explicit forwarding for the common `windowDid…` and `windowWillClose`, `windowShouldClose` unchanged in behaviour (asks first, then the original).
- `ReactionViews.swift`: the `Coordinator` only calls `WindowGuard.install`; `dismantleNSView` calls `detach`.

## Version

App **0.20.1** (patch: a fix). Skill **0.18.2**, untouched.

## Tests

`CR1Tests` (7, all pass): the old defect, the original survives its release, no chain, every window notification with and without an original plus `setFrame`, close still asks and honours the original, detach restores only when still the delegate, no original allows closing. No existing test updated.

## Verified and not

Verified: the 7 tests; `verify.sh --fast`, `check.py`, complete `verify.sh` and rebuild are reported at the end of W4b (same session). Not verified: the real window animation on screen; a unit test shows the missing selector and its fix, not the animation.

## To check by hand

Open a project, switch Film and Build, open and close the right panels; use the green zoom button, double-click the title bar and tile the window several times; close with the red button and Command-W with and without a build running (the guard must still ask); leave the app open a long session and repeat.
