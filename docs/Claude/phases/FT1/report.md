---
type: phase-report
status: current
phase: FT1
date: 2026-11-10
summary: "Report of FT1: Film toolbar without Ripple or Add scene, zoom group at the far right; resize always moves the following scenes; app 0.21.5."
app_version: 0.21.5
skill_version: 0.18.2
prompt:
  - "[[phases/FT1/prompt]]"
tags:
  - report
---

# FT1: the Film toolbar, simplified

## Step 0

- a) Order before: title and counts, transport (previous, play, next, timecode), then on the right: zoom (minus, slider, plus, fit menu), Beat menu (snap level), Grid toggle, Ripple toggle, Add scene menu, Film status chip, the primary action (Validate storyboard, then Go).
- b) Ways to add a scene: Storyboard list "New" (`addScene`), the storyboard page's "Add scene", Draft (Clap), the toolbar menu ("New scene" and the library scenes that are not in the film, placed at the end), drag from the Resources. Only one entry lived only in the toolbar menu: placing a hidden library scene at the end. The Storyboard list has a "Not in the storyboard" section with a Visible eye that brings such a scene back, so nothing was moved. The one difference: the eye puts the scene back at its own place, not at the end.
- c) Ripple: toolbar toggle, `Storyboard.ripple` (stored per storyboard, absent means on), `ShowreelFile.ripple()`, `.resize(ripple:)` and `.gridSettings(ripple:)`, `planResize`, Clap's `set_scene_duration` option, 25 test call sites. Default: the following scenes move. With ripple off the next scene was pinned at its start and a gap opened, which the owner says never exists.
- d) Zoom: `project.timeline` (pps) in `TimelineScale`, stored per project; the group is one `zoom` view.

## Built

1. The `zoom` group is the last control of `right` (and so at the far right of the one-row toolbar).
2. The toolbar's Add scene menu is removed (see b: every scene can still be added).
3. Ripple removed: toggle, `ripple()`, `Storyboard.ripple`, `ripple:` of `.resize` and `.gridSettings`, the `!ripple` branch of `planResize`, the `ripple` property of the `set_scene_duration` tool (`shared/tools.json`) and the word in `shared/capabilities.json`. An old stored `"ripple"` is now an unknown field: ignored and carried through saves. The lock rule is unchanged.
4. Beat menu, grid button and fit menu untouched.

## Deviations

- Clap's `set_scene_duration` lost its `ripple` option (the app's tool, not the skill: `references/portability.md` does not mention it).
- ROADMAP not touched (no limit lifted).

## Tests

`FT1Tests` (4): zoom group last, no ripple or Add scene in the toolbar source, the other ways to add a scene remain, an old `ripple` value is ignored and kept. Updated: `ReelTests` (the ripple test is now "resize moves the following scenes and never leaves a gap"; three `ripple()` asserts removed), `TimelineTests` (no "Add scene" expected), and about 25 `ripple:` arguments in the tests of `.resize` and `.gridSettings`. The lock test (`SceneStateTests`) is unchanged and passes.

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen): the toolbar's look and the zoom group's position.

## To check by hand

Zoom group at the far right and its three controls; no Add scene in the toolbar and a new scene from the Storyboard's New; changing a scene's length moves the following ones; a locked scene refuses a move with its reason; an old project opens with no ripple trace.
