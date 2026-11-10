---
type: phase-report
status: current
phase: MT1
date: 2026-11-10
summary: "Report of MT1: a music lane toolbar (Beat, Bars, Sections, Drop, Analyse, track name and BPM); the Beat menu leaves the Film toolbar; app 0.21.6."
app_version: 0.21.6
skill_version: 0.18.2
prompt:
  - "[[phases/MT1/prompt]]"
tags:
  - report
---

# MT1: the music lane gets its own toolbar

## Step 0

- a) The "Beat menu" was the snap menu of the Film toolbar: Beat, Bar, Section, Drop, Off. It set where a scene's edge snaps (`.gridSettings`, stored in the storyboard's `snap` in `showreel.json`) and the level of the grid drawn over the frames (that level and every stronger kind). The Grid toggle (`gridVisible`, in `.studio` settings) shows or hides it. The music lane drew every kind of mark whatever the level.
- b) The analysis (`analysis/beats.json`) returns beats, bars, BPM, first beat, bar energy, drop bars and breakdowns (breaks, returns, intro). Sections are derived from the breaks, returns and drops; drops from `dropBars`. All five buttons have data, except when a track is flat (no break, no drop): then Sections or Drop are disabled with their reason. No gap in the analysis, so no idea note.
- c) The lane is the last row of the scrolling strip (`MusicLane`), 56 to 170 pt high, following the zoom. It sits inside the horizontal scroll view, so a toolbar inside it would scroll away.
- d) `analyseTrack` runs the skill's script (up to 240 s), shows a small spinner in the lane, and writes `analysis/*.json` only on success; on failure it sets `musicNotice` and the loaded result stays. Nothing stops it during a Build today.

## Built

1. `MusicToolbarView` (Studio) pinned under the lane, `TimelineLayout.toolbar` high, tokens only: Beat, Bars, Sections, Drop (toggle buttons), Analyse (spinner and "Analysing…", then a "Analysis failed" label with the reason in its tooltip), track name (truncated, full name in the tooltip) and BPM at the end.
2. Availability in Kit (`MusicToolbar.availability`), shown with `disabledWithReason`: no track (all five), not analysed, no beats, bars, sections, drops, Build running and analysing (Analyse).
3. The snap menu left the Film toolbar. **Rule: scenes snap to the finest kind that is shown and exists** (`MusicToolbar.snapLevel`); a project with no stored toolbar starts from its stored snap level (`MusicToolbarState(migrating:)`), so nothing changes at first. The grid over the frames shows the kinds that are on (`MusicGrid.lines(..., only:)`). The Grid and fit buttons stay.
4. State: `StudioSettings.musicToolbar` in the project's `.studio` settings next to `gridVisible`, restored at launch, independent of the film's content. The rules are Kit's `MusicToolbarState` and `MusicToolbar`.
5. Sections colour the lane by section with a four-colour token palette (`sectionColors`, `sectionTint`), replacing the always-on tint of breaks; the top 14 pt of each section answers hover with its name.

## Deviations and questions for the owner

- The toolbar is **under** the lane, pinned, not inside its header (the lane scrolls). It takes 44 pt of the strip's height.
- The stored `snap` of `showreel.json` is no longer read after a project has a toolbar state; it only seeds it. Clap's `get_state` still reports it. Question: should Clap's `get_state` report the effective snap?
- `.gridSettings(snap:)` stays as an operation but nothing in the interface calls it now.
- An analysis that fails after the script began writing could leave a half-written result: the script, not the app, writes the files (not changed, skill untouched).

## Tests

`MT1Tests` (15): toggles and their stored value, availability for no track, not analysed, full, flat, Build running, analysing; the earlier result kept on failure; status; grid equals the old menu for the same settings at every level; snapping rule; hidden kinds leave the lane; sections; track summary; source guard (no colour literal, Beat menu gone). Updated: `TimelineTests` (no "magnet" in the Film toolbar), `FT1Tests` (order list without the snap menu).

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen): the bar's look and height, the spinner, the section colours and hover names, a real analysis run, Analyse refused during a Build.

## To check by hand

Each of the five buttons on a full track and on one without sections or drops (disabled with the reason); the track name and BPM; Analyse running, finishing, failing, and during a Build; snapping after the Beat menu is gone (drag an edge with Beat off and Bars on); toggles restored after quitting and reopening; a project with no music.
