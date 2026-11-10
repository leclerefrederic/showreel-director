---
type: phase-prompt
status: current
phase: CR1
date: 2026-11-10
summary: "Asks for the fix of a crash of app 0.20.0 (unrecognized selector windowDidResize: during a window resize), audit and a failing test first."
tags:
  - prompt
---

# Phase CR1: crash "unrecognized selector windowDidResize:" during a window resize (audit, failing test, fix)

Read CLAUDE.md, then `docs/Claude/Index.md` and open only what it points to for the reports that touched the window, the close guard and the rail (CL1, RL1, RB1, UI1), and the code: `app-swift/Sources/ShowreelStudio/ReactionViews.swift` (`CloseGuardHook` and its `Coordinator`), `ProjectView.swift` (where the hook is attached), `OpenProjects`, `App.swift`. Follow every rule of CLAUDE.md (never run git; English interface; answer the owner in French and short; skill untouched; no scope beyond this crash: a good idea goes as a note created with `python3 tools/docs_new.py idea`). Views stay free of business logic.

## The crash (owner, app 0.20.0, macOS 27.0.1, 2026-11-10, 17 minutes after launch)

`EXC_CRASH (SIGABRT)` on the main thread, `NSInvalidArgumentException`: `-[… windowDidResize:]: unrecognized selector sent to instance 0x…`. The last exception backtrace, from the bottom: a display link fires `-[NSAnimation _advanceTimeWithDisplayLink:]`, which calls `-[NSAnimation setCurrentProgress:]` and then `-[NSWindow _setFrameCommon:display:fromServer:]` (a **window frame animation**: zoom, fill, tile, restore, or a programmatic animated frame change), which posts `NSWindowDidResizeNotification` through `-[NSNotificationCenter postNotificationName:object:userInfo:]`; the notification centre calls an observer, the call goes to `___forwarding___` and ends in `doesNotRecognizeSelector`. No ShowreelKit or ShowreelStudio frame is on the stack apart from `main`. The receiver's class name could not be read (`%s`).

## The assistant's hypothesis (to confirm or refute in step 0, never to assume)

`CloseGuardHook.Coordinator` replaces the window's delegate with itself and keeps the previous delegate in a `weak var original`. It answers `responds(to:)` with `super.responds(to:) || original.responds(to:)` and forwards unknown selectors through `forwardingTarget(for:)` only while `original` is alive. AppKit registers a window's delegate as an observer of the window notifications for every `windowDid…` method the delegate **responds to at the moment the delegate is set** (so the coordinator is registered for `windowDidResize:` because the SwiftUI delegate behind it implements it). If `original` later becomes nil, `forwardingTarget(for:)` returns nil and the same selector is unrecognized at the next resize: exactly this crash. Ways `original` can die: `attach` runs again from `updateNSView` and from `makeNSView`; if the hook is re-created (a new `Coordinator`), the second one takes the first one as its `original` (a chain), and when the first coordinator is deallocated with its view the second one's weak `original` becomes nil; or SwiftUI replaces its own delegate object. Also look for: a coordinator left as `window.delegate` after its view is gone; the hook attached once per `ProjectView` while a project window can show another project (`win.project` changes).

## Step 0 (read-only, the top of docs/Claude/phases/CR1/report.md)

1. Where the hook is created and how often (`ProjectView.swift`, the identity of the view, what makes SwiftUI re-create it: switching projects in a window, the rail, the layout, Reset, W4 changes), and the life of each `Coordinator` and of the delegates in the chain: for each case, say whether `original` can become nil while the coordinator is still the window's delegate.
2. Which window notification selectors the coordinator can be registered for (what the SwiftUI window delegate implements) and which of them would crash the same way (`windowDidResize:`, `windowDidMove:`, `windowDidChangeScreen:`, `windowDidEndLiveResize:`, `windowDidEnterFullScreen:`, etc.).
3. Whether another place changes a window's delegate, posts or observes window notifications, or animates a window frame (the grep of the assistant found none besides the hook: confirm).
4. **A failing test first.** Without a screen, using an `NSWindow` created in the test (`defer: true`, never shown): attach a delegate that implements `windowDidResize:`, attach one coordinator, then a second (the chain), release the first (or its `original`), then post `NSWindow.didResizeNotification` for the window (or call `setFrame(_, display: false, animate: false)`). Show that the test **crashes or raises on the current code** (if a crash cannot be caught in XCTest, show the unrecognized selector with an Objective-C exception catch helper, or test the forwarding logic directly: a coordinator whose `original` is nil must still answer every selector it claims to respond to). Say if the hypothesis is confirmed, partly or refuted, and what the real cause is if different.

## What to build (only if step 0 confirms a cause; if it refutes the hypothesis, stop after step 0, report, and propose)

1. **No dangling forwarding.** The coordinator must never claim a selector it cannot answer: keep the previous delegate **strongly** while the coordinator is the window's delegate (a window's delegate is not retained by the window, so there is no cycle), never build a chain (when `window.delegate` is already a `CloseGuardHook.Coordinator`, update that one instead of wrapping it, or unwrap to the real original), answer `responds(to:)` from the **current** state, and give every selector it may be registered for a safe path (implement the common `windowDid…` and `windowWill…` methods explicitly and forward them if `original` exists, or ignore them if not).
2. **Restore on teardown.** When the coordinator is torn down (the view goes away, `dismantleNSView`), put the original delegate back if the coordinator is still the window's delegate, so that AppKit re-registers the right observer and nothing points to a dead object.
3. **One close guard per window**, whatever the number of hooks SwiftUI creates; the close guard behaviour itself (the alert, `windowShouldClose`) is unchanged and its existing tests still pass.
4. **Nothing else**: no change to the close rules, the rail, the strip, the Build or the skill.

## Tests (no screen)

The failing test of step 0 now passes; several attaches and detaches in any order; the original deallocated; a resize, a move, a screen change and a close posted to the window; `windowShouldClose` still asks and still honours the original; the delegate is restored after teardown. Say which existing tests were updated.

## Release

A **patch** app version (a fix; say so): release notes in `RELEASE-NOTES-APP.md` BEFORE `python3 tools/bump_app.py`; never edit a version by hand. The skill is untouched; the report names both versions.

## Vault

Report in `docs/Claude/phases/CR1/report.md` with its properties; add a line to the UX note or to a note of the vault only if a rule changed; update `CLAUDE.md` "Open work" only to say the crash is fixed; run `python3 tools/docs_index.py --write` and `python3 tools/check_docs.py`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: `python3 tools/check.py`, the complete `tools/verify.sh`, then `tools/rebuild-app.sh`. Say which you ran.

## Final report (docs/Claude/phases/CR1/report.md)

Step 0 (how often the hook is created, the chain, the selectors, the failing test and its result, the real cause); what was changed; the version; the tests; what is verified and what is not (the real crash needs a window animation on screen: a unit test can show the missing selector and its fix, not the animation itself; say so plainly); and "To check by hand": open a project, switch between Film and Build, open and close the right panels, open another project in the same window if the app allows it, then use the green zoom button, double-click the title bar and tile the window several times; try the close button and Command-W with and without a build running (the guard must still ask); leave the app open for a long session and repeat. Stop after the phase.
