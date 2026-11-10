---
type: phase-report
status: current
phase: FIX1
date: 2026-11-09
summary: "Report of FIX1: the cause and the fix of the Design package footer floating over the project settings form."
app_version: 0.14.1
prompt:
  - "[[phases/FIX1/prompt]]"
tags:
  - report
---
# FIX1: the "Design package" footer floats over the project settings form (app 0.14.1, skill untouched)

## The cause

Confirmed by reading `ProjectSettingsPanel.swift`: inside the `ScrollView` the form's `VStack` and `PackageSettingsFooter().padding(.horizontal, 14).padding(.bottom, 14)` were two siblings with no stack around them. A `ScrollView` whose content builder holds several views overlays them, so the footer landed on top of the form (the helper text under "Film languages").

## What changed

- One `VStack(alignment: .leading, spacing: 0)` now holds the form (with its own padding) and the footer (same horizontal padding), inside the `ScrollView`: the footer is under the last section with the same inner margin and its divider spans the card width like the other sections. No restyle, no behaviour change, no change to the package logic.
- Release notes 0.14.1 first, then `tools/bump_app.py patch`.

## Other places with the same pattern

A scan of every `ScrollView { ... }` of ShowreelStudio (content with more than one top-level view and no stack) found **only this one**. The scan is now a test (`FIX1Tests.testNoScrollViewHoldsSeveralViewsWithoutAStack`), so a new one fails the build; `scrollViewsWithSiblingViews` is in `UI2Support.swift`. Single-child containers other than `ScrollView` (`.overlay`, `Group`) were not scanned: they were not part of the bug.

## Tests

`FIX1Tests` (3): the scan over all views, the scan seeing the bug, the footer sharing the stack with the form.

## Verified, not verified

- Verified: the complete `tools/verify.sh` (VERIFY OK). The cause and the fix are checked by reading and by the source scan.
- **Not verified: anything drawn** (no screen): that the footer really sits under the form, at a narrow pane width too.

## To check by hand

Open Project settings; scroll to the bottom of the Project tab and of the Look tab: "Design package" must sit under the last section with the same margins; the button must open the save sheet; nothing overlaps at a narrow pane width.
