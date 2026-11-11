---
type: idea
status: superseded
phase: UR1
date: 2026-11-11
summary: "Undo and Redo buttons in the rail, and a menu on long press or right click that lists the last actions so the owner can go back several steps."
id: IDEA-052
aliases:
  - "IDEA-052"
since: 2026-11-11
outcome: built
outcome_link:
  - "[[phases/UR1/report]]"
area: app
source: assistant
origin: "docs_new.py"
tags:
  - idea
---

# Undo and Redo buttons in the rail with a history menu

The owner asked on 2026-11-11 for Undo and Redo buttons in the rail, and a way to see the stack.

**What exists.** `UndoLog` (`ShowreelKit/Undo.swift`) keeps an undo and a redo stack of titled entries; `ProjectModel` exposes `canUndo`, `canRedo`, `undoTitle`, `undo()` and `redo()`; the Edit menu (`App.swift`) has Undo and Redo with Command-Z and Shift-Command-Z, the title of the next action, and a reason when unavailable (for example while a film is building). The rail has no such buttons and nothing lists the stack.

**Proposal (owner's choice).**
- Two buttons in the rail, Undo and Redo, using the same availability and reason as the menu (`disabledWithReason`, never a silent disabled control).
- A press and hold, or a right click, opens a menu with the last actions (title of each entry), the redo ones apart; choosing one goes back or forward to that step.

**To settle when built.** Where the buttons sit in the rail groups; how many entries the menu lists; `UndoLog` has no "go back to step N" operation yet, only one step at a time; whether the typed text fields' own undo (`fieldUndo`) shows in the same list.

Not in the current phases: needs a phase of its own.
