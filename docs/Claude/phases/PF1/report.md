---
type: phase-report
status: current
phase: PF1
date: 2026-11-10
summary: "Report of PF1: the lag on a Storyboard list click was the double-tap (rename) gesture holding the single tap back; fixed, no change of behaviour; app 0.21.7."
app_version: 0.21.7
skill_version: 0.18.2
prompt:
  - "[[phases/PF1/prompt]]"
tags:
  - report
---

# PF1: selecting a scene from the Storyboard list lags

## Step 0

- a) Film: `FrameView` `.onTapGesture { project.focusScene(scene.id); focused = true }`. List: the row's text area `.onTapGesture(count: 2) { beginRename }` then `.onTapGesture { project.focusScene(scene.id) }`. Both call the same `focusScene`: `select(.scene)` (commit of a pending edit if the scene changes, selection, centre mode, tab, rail), then the playhead, then the Film's scroll (`setViewport`). The only difference is the double-tap gesture on the list row.
- b) One click publishes about six `@Published` values (selection, centre mode, scene tab, rail layout, playhead, viewport and scroll) in one run-loop turn: SwiftUI renders them as one update. No disk or JSON work on the path except the commit of a pending edit (`flush`, already before the selection changes). The list scrolls its row into view on a selection change (`Motion.with(.select)`), cheap when the row is visible.
- c) Measured: **nothing could be measured without the screen.** I added `DebugProbe.interval` (an `os_signpost` interval, debug builds only) around `focusScene` so the owner can see its duration in Instruments (Points of Interest, subsystem `ShowreelStudio`). It will show the operation itself is short; the lag is before it starts.
- d) Cause: in SwiftUI a view that has `onTapGesture(count: 2)` declared before `onTapGesture` holds the single tap until the double-click interval (about a quarter to half a second) has passed, to know whether a second click comes. The Film's frame has no double-tap, so its click is immediate. Confidence: high by reading and by that known SwiftUI behaviour; the delay itself was not seen or measured.

## Built

- The row's single tap is plain `onTapGesture { focusScene }`; rename is `simultaneousGesture(TapGesture(count: 2))`. A double-click now selects (twice, harmless: the second selection changes nothing) and renames; a single click acts at once.
- `DebugProbe` (Kit), wrapped around `focusScene`; in release it only calls the body.
- Behaviour of a selection unchanged: same operation, same order (selection, playhead, scroll), a pending edit still committed first.

## Deviations

- No publish counter test: `ProjectModel` is not reachable from the tests. The guard is by source: both entry points call `focusScene`, the row has no `count: 2` tap before its single tap, the order of effects and the commit before selection are asserted.
- Three other `onTapGesture(count: 2)` remain (content word label, history entry text, inspector name). They are outside this phase; they have the same delay on their own single tap if one exists.

## Tests

`PF1Tests` (4). No existing test changed.

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen): the lag itself and its disappearance.

## To check by hand

Click scenes in the Storyboard list quickly one after the other, with 15 scenes and with a scene selected that has an edit pending; compare with a click in the Film; look for a delay before the highlight, the inspector or the playhead; Reduce Motion on; double-click still renames.
