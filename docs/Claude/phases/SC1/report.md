---
type: phase-report
status: current
phase: SC1
date: 2026-11-11
summary: "Report of SC1: Shift-Command-I, J and Y open the Inspector, Project and its Look tab, listed in the View menu and the rail tooltips; app 0.23.3."
app_version: 0.23.3
skill_version: 0.18.2
prompt:
  - "[[phases/SC1/prompt]]"
tags:
  - report
---

# SC1: shortcuts for the Inspector, Project and Look

## Step 0

- a) Already defined: Shift-Command-L (Project Library, `App.swift`), Shift-Command-K (Catalogue), Shift-Command-A (Clap, `WorkspaceViews`), Command-Z and Shift-Command-Z, Command-S (the file editor), Command-minus, equals, plus and 0 (strip zoom and fit), Space (play over the strip), Command-comma, Q, W, H, M, C, V, X, A; all listed in `AppShortcuts.used` and checked for duplicates by a test. System ones a plain key would clash with: Shift-Command-P (Page Setup), Shift-Command-L here is ours.
- b) `RailState.choose` (a click toggles a right panel), `RailState.open` (never toggles; used by Clap's shortcut through `ProjectModel.showClap`/`openClap`), `setRight` writes it back; Look is the Project panel's tab `settingsTab = .look` since SM1.
- c) The tooltip of a rail entry (`RailEntry.shortcut`) and the View menu (`StudioCommands`).

## Keys chosen

- **Inspector: Shift-Command-I.** **Project: Shift-Command-J.** **Look: Shift-Command-Y** (Project on its Look tab).
- Why: same family as Clap's (Shift-Command and a letter). Shift-Command-L is the Project Library, Shift-Command-P is Page Setup, so Project takes J and Look takes Y (free in the app and not a standard command of a SwiftUI app).

## Built

1. `AppShortcuts.inspector`, `project`, `look` and their display strings, added to `used`; `RailEntry.shortcut` for the Inspector and Project (the Project tooltip also names the Look key).
2. `ProjectModel.showInspector`, `showProject`, `showLook` (all through `RailState.open`: from a closed side they open it, from another panel they replace it, a repeat does nothing; Look sets the tab to Look only if it is not already).
3. A View-menu group in `StudioCommands` with the three entries; when the workspace is not open, the entry is disabled and its title says why (the reason of `RailEntry.unavailable`, as Undo does). No scene is needed for the Inspector (it shows its empty state), so there is no other unavailable case.

## Deviations

- Clap's own shortcut is not in the View menu (it stays declared by the workspace, unchanged, as asked); the three new ones are.

## Tests

`SC1Tests` (7). Changed: `RB1Tests.testEveryTooltipHasTheNameAndTheShortcutWhenThereIsOne` (it asserted Clap had the only shortcut; now three entries have one).

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen, no keyboard): that a key press does anything, that the menu shows the entries, that the focus in a text field does not swallow them.

## To check by hand

Each shortcut from a closed right side, from another open panel (including Clap) and with the focus in a text field; a second press of an open panel's key (nothing happens); Shift-Command-Y while Project is on Brief (it goes to Look); the View menu entries and the tooltips of Inspector and Project; the menu entries greyed with the reason before the base configuration is complete.
