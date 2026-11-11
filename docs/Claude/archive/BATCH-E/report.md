---
type: phase-report
status: current
phase: BATCH-E
date: 2026-11-11
summary: "Report of Batch E, which ran RS1, SC1, LK1 and UR1 in a row: all four done, app 0.23.2 to 0.24.0, skill unchanged."
aliases:
  - "batchE-report"
prompt:
  - "[[archive/BATCH-E/prompt]]"
tags:
  - report
---

# Batch E: RS1, SC1, LK1 and UR1

Backup before the batch and before each phase: `~/Library/Application Support/ShowreelStudio/backups/batchE-20261111-1637/` (`start/`, `before-RS1/`, `before-SC1/`, `before-LK1/`, `before-UR1/`). No restoration was needed. Skill unchanged (0.18.2). App reached **0.24.0**.

## Phases

### RS1: DONE, app 0.23.2
- The Resources section is as tall as the Film strip by default (`LibrarySplit.defaultFraction`, pure, in Kit), so the divider sits on the line of the strip's top. A dragged divider (`split` stored) always wins; "never dragged" is `split == nil`, no new flag. At full width the strip is below the left panel, so 2/3 and 1/3 stay. DECISION-011 is superseded by DECISION-023.
- Deviation: the divider follows the strip while the strip is dragged, as long as the divider was never dragged. Not verified (no screen): that the line meets the strip's top.
- To check by hand: a new project (the divider on the line of the strip's top); drag the divider and reopen (the dragged value stays); a small window; the Film placement toggle.

### SC1: DONE, app 0.23.3
- Shift-Command-I opens the Inspector, Shift-Command-J opens Project, Shift-Command-Y opens Project on its Look tab. They are in the View menu (greyed with the reason before the workspace is open) and in the tooltips of the rail's Inspector and Project buttons. A second press of an open panel's key does nothing. One test changed (RB1: three entries now have a shortcut).
- Not verified (no keyboard, no screen): any key press, the menu, the focus in a text field.
- To check by hand: each shortcut from a closed side, from another open panel and with the focus in a text field; the tooltips and the menu entries.

### LK1: DONE, app 0.23.4
- Opening a project gives each locked scene with no copy of its look (made before UI2) that copy (`LockedLookMigration`, in the field the lock already writes), once, before the first draw; one journal line and one quiet toast. A second open writes nothing. An older-revision project waits for Update project. It is not an undo step, so the owner cannot undo it into the unprotected state.
- Not verified (no screen, no project of the owner touched): the toast. No existing test changed.
- To check by hand (on a copy): open a project with a scene locked before UI2 (nothing changes on screen); change the global palette (the locked scene keeps its look); reopen (no second note, no new write).

### UR1: DONE, app 0.24.0
- Undo and Redo buttons at the foot of the rail (the Edit menu's availability and reasons, tooltip "Undo: title"); press and hold or right-click lists the last 20 steps and goes through several as one operation (`undo(steps:)`, `redo(steps:)`); the message names them. A failing step leaves whole steps and is named; a single step that failed no longer drops its entry.
- Choice: not a rollback (the taken steps stay, as the prompt's second clause says). Out of scope: the text fields' own undo. Not verified (no screen, no mouse): press and hold, right-click, the look. No existing test changed.
- To check by hand: the two buttons and their tooltips; Undo and Redo after a few edits; press and hold and right-click, going back three steps at once; the buttons while a film builds; Command-Z in the Edit menu.

## Keys chosen by SC1

Inspector Shift-Command-I, Project Shift-Command-J, Look Shift-Command-Y. Shift-Command-L (Project Library) and Shift-Command-P (Page Setup) are taken, so J and Y; all share Clap's family (Shift-Command and a letter).

## Decisions taken without asking

- RS1: no flag for "never dragged" (`split == nil` already says it); full-width keeps 2/3.
- LK1: archived locked scenes are migrated too; the note is a toast; a journal event, not an undo step.
- UR1: not a rollback; 20 steps per menu.
- SC1 and UR1 do not conflict: the rail buttons take no shortcut (they use Command-Z of the Edit menu).

## Final checks

The complete `tools/verify.sh` passed at the end of each phase and once more at the end of the batch (`check.py` all passed, no flaky test seen, 30 tests added: RS1 6, SC1 7, LK1 8, UR1 9). `tools/rebuild-app.sh`: SELFTEST OK, BUNDLE OK (standalone), REBUILT AND RUNNING, pid 40028 (confirmed with `pgrep`). Total duration: about 20 minutes by the machine clock.
