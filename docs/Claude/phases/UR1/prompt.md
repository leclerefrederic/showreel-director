---
type: phase-prompt
status: current
phase: UR1
date: 2026-11-11
summary: "Undo and Redo buttons in the rail, and a menu on long press or right click that lists the last actions so the owner can go back several steps (IDEA-052)."
tags:
  - prompt
---

# Phase UR1: Undo and Redo in the rail, with a history menu

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic. UI principle: every action gets a visible reaction, and anything unavailable says so, why and how to get it back (`disabledWithReason`, `Availability`; never a silent disabled control).

The owner asked (2026-11-11) for Undo and Redo buttons in the rail and a way to see the stack, and chose "a menu on long press": IDEA-052. Build exactly that.

## Step 0 (read-only, 5 lines at the top of the report)

a) What exists: `UndoLog` and `UndoEntry` (`ShowreelKit/Undo.swift`), `ProjectStore.undo()` and `redo()`, `ProjectModel` (`canUndo`, `canRedo`, `undoTitle`, `undo()`, `redo()`, `stepHistory`) and the Edit menu (`App.swift`) with its reasons (`Availability.undo`), including `fieldUndo` for typed text fields.
b) How the rail is built (the groups and entries, `RailShell`, `IconRoles`) and where two more buttons fit without crowding it.
c) How an entry's title is made and whether every entry has a readable one; what happens to the stacks when a Build runs and when a project closes or reopens.

## What to build

1. **Two rail buttons**, Undo and Redo, with the same enabled state and the same reasons as the Edit menu (including "building the film"), a tooltip carrying the title of the next action ("Undo: <title>"), and an icon by role in `IconRoles`. They use the same code path as the menu's Cmd-Z and Shift-Cmd-Z (one operation, two doors); the menu keeps working.
2. **A history menu** on long press or right click of either button: the last actions with their titles, newest first (up to a count you choose and say, for example 20), the undone ones apart and dimmed on the Redo side. Choosing an entry goes back (or forward) to the state just after that step, through repeated single steps run as one operation. Each entry shows a clear title; an entry without one gets a generic title and the report says how many.
3. **A new operation in ShowreelKit**: `undo(steps:)` and `redo(steps:)` (or one "go to step" operation) with tests. It must be all or nothing: if one step fails, the steps already taken are reported and the stack stays consistent (say how), and the message names what was undone ("Undid 3 actions: ...").
4. **Reactions.** A press that cannot act says why through the reason of `Availability.undo`; a successful undo shows the existing "Undid: <title>" message.
5. **Out of scope, say so in the report:** the typed text fields' own undo (`fieldUndo`) is not part of this list unless step 0 shows it already shares the stack; no persistent history panel; no change to what an entry records or to the journal.

## Tests (no screen)

Undo of n steps leaves the same files as n single undos; redo of n steps restores them; the menu list matches the stack (order, count limit, redo apart); a failing step leaves a consistent stack; the buttons' availability and reason equal the menu's in every state (empty, building, ok); a title exists for every kind of entry. Say which tests changed.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py minor "..."`; never edit a version by hand. Set IDEA-052 to `status: superseded` with `outcome: built` and its link; update docs/Claude/ux-notes.md ("Built in UR1 (date)"), CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh` (in the batch: once at the end).

## Final report (docs/Claude/phases/UR1/report.md)

Step 0 results, what was built, the version, what is verified and what is not (no screen, no mouse: nothing pressed or drawn is verified, say so plainly), and "To check by hand": the two buttons in the rail with their tooltips; Undo and Redo after a few edits; the long press or right click menu and going back three steps at once; the buttons while a film builds; the menu's Cmd-Z still working. Stop after the phase.
