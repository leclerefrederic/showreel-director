---
type: phase-report
status: current
phase: BATCH-C
date: 2026-11-10
summary: "Report of Batch C, which ran FL1, FT1, MT1 and PF1 in a row: all four done, app 0.21.4 to 0.21.7, skill unchanged."
aliases:
  - "batchC-report"
prompt:
  - "[[archive/BATCH-C/prompt]]"
tags:
  - report
  - archive
---

# Batch C: FL1, FT1, MT1 and PF1 in a row

**Backup (outside the repository):** `/Users/fleclere/Library/Application Support/ShowreelStudio/backups/batchC-20261110-1800` with `start/`, `before-FL1/`, `before-FT1/`, `before-MT1/` and `before-PF1/` (app-swift without build folders, showreel-director, docs, tools, the top-level Markdown files). No phase had to be restored.

**Result: four phases DONE.** FL1 0.21.4, FT1 0.21.5, MT1 0.21.6, PF1 0.21.7. The skill was not changed (0.18.2).

## FL1: DONE (0.21.4), [[phases/FL1/report|report]]

Film frames are drawn as film: the grid is under the frames, the thumbnail is centred and whole on a translucent black token, and each frame has perforation bands and start and end caps (gone under 60 pt wide, caps stay). 11 tests. Deviation: the "heavier edge at the cut" is the cap itself; the image aspect is the constant 16:9. Not seen: everything drawn.
To check by hand: beat lines hidden behind a scene and visible between scenes and in the music lane; the playhead crossing a scene; a thumbnail centred on translucent black (wide and narrow scene); perforations and caps at several zooms down to 60 pt wide; selected, locked, hidden and To review frames; hover and drag.

## FT1: DONE (0.21.5), [[phases/FT1/report|report]]

The Film toolbar lost Ripple and the Add scene menu; the zoom group is last, at the far right. Resize always moves the following scenes (the `ripple` argument, the stored `Storyboard.ripple`, the `!ripple` branch and Clap's `ripple` option are gone; an old stored value is carried as an unknown field). The Storyboard's New and the "Not in the storyboard" section cover every way to add a scene. 4 tests; about 25 test call sites updated. Deviation: Clap's `set_scene_duration` lost its `ripple` option (app tool, not the skill).
To check by hand: the zoom group at the far right and its three controls; no Add scene in the toolbar and a new scene from the Storyboard's New; changing a scene's length moves the following ones; a locked scene refuses a move with its reason; an old project opens with no ripple trace.

## MT1: DONE (0.21.6), [[phases/MT1/report|report]]

A music lane toolbar (Beat, Bars, Sections, Drop, Analyse, track name and BPM), pinned under the lane, with availability and reasons in Kit. The Beat (snap) menu left the Film toolbar: scenes snap to the finest kind shown; a project starts from its stored snap level. 15 tests. Deviations: the bar is under the lane, not in its header; `.gridSettings` is no longer called by the interface.
To check by hand: each of the five buttons on a full track and on one without sections or drops (disabled with the reason); the track name and BPM; Analyse running, finishing, failing, and during a Build; snapping after the Beat menu is gone; toggles restored after quitting and reopening; a project with no music.

## PF1: DONE (0.21.7), [[phases/PF1/report|report]]

The lag on a Storyboard list click was the row's double-tap (rename) gesture holding the single tap back for the double-click interval. The single tap is now immediate and rename is a simultaneous double-tap. `DebugProbe` (debug only) wraps `focusScene`. 4 tests (by source: no publish counter is reachable). Not measured: no screen, so the lag and its end are reasoned, not seen. Three other `count: 2` taps remain elsewhere.
To check by hand: click scenes in the Storyboard list quickly, with 15 scenes and with an edit pending; compare with a click in the Film; look for a delay before the highlight, the inspector or the playhead; Reduce Motion on; double-click still renames.

## Questions for the owner

- MT1: should Clap's `get_state` report the effective snap (the finest mark shown) instead of the project's stored one?
- MT1: is the music toolbar under the lane acceptable, or should it live in a header inside the lane (it would scroll with the strip)?
- PF1: the other three double-tap gestures (a content word, a history entry, the inspector name) may delay their single tap in the same way: fix them too?

## Final checks

The complete `tools/verify.sh` ran green at the end of each phase and once more after PF1 (`VERIFY OK`); `python3 tools/check.py` all passed; 840 tests in the Kit's test target; no flaky test seen. `tools/rebuild-app.sh` once at the end: `BUNDLE OK (standalone)`, **REBUILT AND RUNNING, pid 41956** (confirmed with `pgrep`). Nothing drawn, animated or felt was seen: there is no screen.
Total duration: about 1 h 15 min.
