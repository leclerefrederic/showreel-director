---
type: phase-prompt
status: current
phase: FIX1
date: 2026-11-09
summary: "Asks for a fix of the Design package footer that floats over the project settings form."
report:
  - "[[phases/FIX1/report]]"
tags:
  - prompt
---
# Fix FIX1: the "Design package" footer floats over the project settings form

Read CLAUDE.md. Follow every rule of CLAUDE.md (never run git, English interface, no out-of-scope work: an idea goes in docs/ideas.md in one line). Fix the first compiler error first.

## The bug (owner's screenshot of the Project panel)

"Design package" and the button "Save design as package..." float over the form, over the helper text under "Film languages" ("English by default. Add languages the viewer can switch to..."), shifted to the left and with its divider running the full width.

## Cause found by reading the code (check it, do not trust it)

In `app-swift/Sources/ShowreelStudio/ProjectSettingsPanel.swift` (about lines 52 to 61) the `ScrollView` content has two sibling views with no stack around them: the form's `VStack` and then `PackageSettingsFooter().padding(.horizontal, 14).padding(.bottom, 14)`. A `ScrollView` whose content builder holds several views without a stack overlays them instead of stacking them, so the footer lands on top of the form.

## To do

1. Confirm the cause (say in the report if it is something else). Wrap the form and the footer in one `VStack(alignment: .leading, spacing: ...)` inside the `ScrollView`, keeping the paddings, so the footer sits under the form with the same inner margin as the form, and the divider spans the card width like the other sections.
2. Search the other views of ShowreelStudio for the same pattern: a `ScrollView` (or any single-child container) whose content has several sibling views and no stack. List each place in the report, and fix those that really overlap.
3. Keep it small: no restyle, no change to behaviour, no change to the package logic. If a pure rule can express "the footer is below the form" do not invent one; this is a layout fix checked by reading and by hand.
4. Release notes in RELEASE-NOTES-APP.md BEFORE tools/bump_app.py (a patch); never edit a version by hand.

## Verification

During the work: tools/verify.sh --fast. At the end: the complete tools/verify.sh, then tools/rebuild-app.sh.

## Final report (docs/phases/FIX1/report.md)

The cause as found, what changed, other places with the same pattern (fixed or listed), the version, what is verified and what is not (no screen: nothing drawn is verified), and "To check by hand": open Project settings, scroll to the bottom of the Project tab and of the Look tab: "Design package" must sit under the last section with the same margins, the button must open the save sheet, and nothing overlaps at a narrow pane width. Stop after the fix.
