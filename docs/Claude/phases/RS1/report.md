---
type: phase-report
status: current
phase: RS1
date: 2026-11-11
summary: "Report of RS1: a left panel whose divider was never dragged gives the Resources the height of the Film strip, from a pure function in Kit; app 0.23.2."
app_version: 0.23.2
skill_version: 0.18.2
prompt:
  - "[[phases/RS1/prompt]]"
tags:
  - report
---

# RS1: Resources take the height of the Film strip by default

## Step 0

- a) `LibrarySplit.standard` (2/3) in `LibraryPanel.swift`; the divider is `PanelLayout.split` (the Storyboard's share), stored per project in `.studio/ui.json` and clamped to 25 to 85 percent when set or drawn (`LibrarySplit.clamp`, applied again in `heights`). `split == nil` means never dragged.
- b) The strip's drawn height is `ShellLayout.frames(...).filmHeight` (the stored `strip` or 300, floored at 200 and capped by the window). DECISION-019 holds: stored sizes are only clamped for drawing.
- c) Under the preview, the left panel spans the full height and ends on the strip's bottom edge. At full width the strip is below the left panel, so no line is shared.

## Built

1. `LibrarySplit.defaultFraction(total:stripHeight:placement:)`: pure, in Kit. Under the preview it returns `(total - strip) / total`, clamped to the range; at full width, or for a bad input, the old `standard`.
2. `LibraryPane` takes `stripHeight` (from `WorkspaceView`) and uses `project.layout.split ?? defaultFraction(...)`. "Never dragged" needed no new flag: `split` is nil until a drag stores it.
3. Range: kept at 25 to 85 percent. The default is clamped inside it, so a tall strip in a small window is drawn at the range's end; nothing is stored.

## Deviations

- The divider follows the strip while the owner drags the strip (the default is computed live), as long as the divider itself was never dragged.

## Tests

`RS1Tests` (6): height equals the strip for three window heights, a taller strip, the range at the smallest window and absurd inputs, the full-width fallback, a stored split kept, the view's use of the stored value. No existing split test changed (they use `standard` or an explicit fraction).

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen): that the divider's line meets the strip's top, the look of the panel.

## To check by hand

A new project (the divider on the line of the strip's top); drag the divider, close and reopen (the dragged value stays); a small window; the Film placement toggle (full width: two thirds and one third).
