---
type: phase-report
status: current
phase: UR1
date: 2026-11-11
summary: "Report of UR1: Undo and Redo buttons in the rail with a press-and-hold or right-click history menu of 20 steps, going back several steps at once; app 0.24.0."
app_version: 0.24.0
skill_version: 0.18.2
prompt:
  - "[[phases/UR1/prompt]]"
tags:
  - report
---

# UR1: Undo and Redo in the rail, with a history menu

## Step 0

- a) `UndoLog` (stacks, limit 100, in memory only) with `UndoEntry` (title, before/after of showreel.json and the manifest, files created or removed); `ProjectStore.undo()` and `redo()` move one whole step and journal it; `ProjectModel.undo()`, `redo()`, `stepHistory` (refresh, music re-analysis, the toast "Undid: title"); the Edit menu (`StudioCommands`) with `Availability.undo` and `fieldUndo`, the text view's own `UndoManager`, which does not share the stack.
- b) The rail is `ViewRailView` (Theme.swift): two groups of `RailEntry` buttons 52 wide, then a Spacer; the five entries, the hairline and the padding take about 300 points of the 406 the smallest window leaves, so two icon-only buttons fit at the foot.
- c) Every step has a `title` from `recording(title)`; an empty one is possible only by a caller passing "". A Build refuses Undo and Redo (`buildRefusal`); the stacks are cleared when the project closes and when a data file changes outside the app (`dropUndoIfStale`).

## Built

1. **ShowreelKit:** `ProjectStore.undo(steps:)` and `redo(steps:)` (one operation, the lock held throughout, Build refused once at the start, a request larger than the stack refused), `UndoHistory` (the 20 newest steps of each side with how many steps choosing each goes through, the generic title "Untitled action" and its count, the message "Undid 3 actions: A; B; C"), `RailHistory.tooltip`, the icon roles `railUndo` and `railRedo`.
2. **Consistency:** a single step that fails after it left its stack now goes back on it (before, it was lost). `undo(steps:)` stops at a failing step: the steps taken stay taken and are named, the failing one stays on the stack.
3. **App:** `RailHistoryButtons` at the foot of the rail (a SwiftUI `Menu` with a primary action: a click undoes, press-and-hold shows the list; the same list on right-click), `disabledWithReason` from `Availability.undo`, tooltip "Undo: title (Command-Z)". `ProjectModel.undo(steps:)` and `redo(steps:)` are the one path; the Edit menu calls them with one step.

## Choices

- **Count: 20** steps per side in the menu (the log keeps 100).
- **Not a rollback.** The prompt says "all or nothing" and also "the steps already taken are reported and the stack stays consistent". I took the second: a rollback by redo could itself fail, and the taken steps are legitimate undo steps the owner can redo.
- **The other side** is listed apart and dimmed (disabled) in each menu: "Undone" under Undo, "Done" under Redo.
- **Titles:** every kind of step recorded by the app has one (checked on scenes, lock, decisions); `untitledCount` reports how many listed steps fell back to the generic title: 0 in the cases tried.

## Deviations

- `fieldUndo` is out of scope: the rail's buttons act on the project's stack only, so while a text field has the keyboard, Command-Z still goes to the text and the buttons go to the project.

## Tests

`UR1Tests` (9): n steps equal n single steps and redo restores, the list (order, count, side, limit), a failing step keeps whole steps and names what was taken, too many or zero steps refused, a Build refuses the whole, availability and reasons equal the menu's (empty, building, ok), titles and the generic one, the message, the rail wiring. No existing test changed.

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen, no mouse): that the press and hold opens the list on macOS 13 and later, that right-click does, how the buttons look in the rail, the dimmed section.

## To check by hand

The two buttons in the rail with their tooltips; Undo and Redo after a few edits; press and hold and right-click on each (the list, newest first, the other side dimmed); going back three steps at once (one message naming them); the buttons while a film builds (greyed, with the reason); Command-Z and Shift-Command-Z in the Edit menu still working.
