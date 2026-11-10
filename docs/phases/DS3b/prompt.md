---
type: phase-prompt
status: current
phase: DS3b
date: 2026-11-10
summary: "Asks for what DS3 left undone: one field style, growing fields, stepper keys and button roles."
report:
  - "[[phases/DS3b/report]]"
ux:
  - "[[ux/Motion, the interface answers]]"
tags:
  - prompt
---
# Phase DS3b: finish what DS3 left undone

Read CLAUDE.md, docs/phases/DS3/report.md (the "Not done" items and "To check by hand"), docs/ux-notes.md (entries "Forms (owner, after DS1)", "Alignment in the inspector", "Duration stepper"), and the code of the form system (`FormLayout`, `NumericField`, the Duration field, every TextField and TextEditor in the inspector, the project form, the Clap panel and Settings). Follow every rule of CLAUDE.md (never run git, English interface, skill untouched, no out-of-scope work: an idea goes in docs/ideas.md in one line). Views stay free of business logic. The owner waived the open questions of docs/ideas.md for the redesign. Change only what is listed here; keep every behaviour.

## What to build

1. **One text field style for every text field** of the inspector, the project form, the Look editors, the Clap panel and Settings: flexible width filling the pane, height and radius from `FormLayout` and the tokens, label above or in the fixed column, a placeholder that is a real example, a focus ring in the accent, an error state with its inline message next to the field, a disabled state that keeps its reason (`disabledWithReason`). Report how many fields were converted and list any left on the native style with the reason.
2. **Multi-line fields grow with their text** up to a limit (the `FormLayout` rule exists and is tested; wire the views to it) and show overlay scrollbars only when something scrolls: no empty scroll track on two lines of text.
3. **Stepper arrow keys.** DS3 reports that Up and Down in the Duration field go through `onMoveCommand`, which the text field may intercept, and that `onKeyPress` needs macOS 14 while the target is macOS 13. Find a way that works on macOS 13 (for example a small `NSViewRepresentable` or an `NSTextField` delegate catching `moveUp:` and `moveDown:`, with Option for the fine step and Shift for the coarse step), keep the rule in `NumericField`, and say plainly in the report whether it is verified by a test of the rule only or also by behaviour.
4. **Buttons by role across the app:** list every button still on the default grey style where a role applies (primary at most one per view, secondary, destructive, quiet) and give each its role. Report the list with before and after. No new button, no removal.
5. **Nothing else:** no change to the Build, the skill, the strip, the Storyboard list, the rail, the top bar, no new feature.

## Tests (no screen)

Every text field kind has the same height and radius (from `FormLayout`); the multi-line growth rule is used by the views' configuration (a test on the rule and on the constants the views read); the stepper's key mapping (Up, Down, Option, Shift) as a pure function; a source guard that no text field in these areas sets its own height, radius or colour literal. Update the tests that referenced old layouts and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a patch version); never edit a version by hand. Update docs/ux-notes.md ("Built in DS3b (date)" and what remains) and CLAUDE.md "Open work".

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/phases/DS3b/report.md)

What was built point by point, what is verified and what is not (no screen: nothing drawn or typed is verified, say so plainly), the version, and "To check by hand": every kind of text field at several pane widths (fill, focus ring, error, disabled with its reason); a two-line field with no empty scroll track and a long text growing then scrolling; the Duration field with the Up and Down keys, Option and Shift; the buttons by role in the inspector, the project form and Settings. Stop after the phase.
