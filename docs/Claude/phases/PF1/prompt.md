---
type: phase-prompt
status: current
phase: PF1
date: 2026-11-10
summary: "Finds and removes the lag when a scene is selected from the Storyboard list (a click in the Film is instant), without changing what a selection does."
tags:
  - prompt
---

# Phase PF1: selecting a scene from the Storyboard list lags

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. **No change to what a selection does** (since FIX2 a click in the list selects the scene, moves the playhead and scrolls the Film, as a click in the Film does): only the time it takes.

The owner's report: a click on a scene in the Film updates the Storyboard list and the inspector very fast; a click on a scene in the Storyboard list lags a little.

## Step 0 (read-only, 10 lines at the top of the report)

a) The two call paths side by side: the Film's tap (TimelineViews.swift, around the scene frame's tap) and the Storyboard row's tap (StoryboardListViews.swift, around the row's tap), down to the shared `focusScene` operation. List every step each one does (selection, playhead, preview seek, scroll, thumbnails, inspector, journal, autosave commit of a pending edit) and the differences.
b) What in the list path runs on the main thread before the next frame: row view updates, `@Published` changes that each invalidate the whole list (count how many publishes one click causes), animations (DS2 row highlight, the Film scroll), the commit of a pending edit (AS1), any synchronous disk or JSON work.
c) A measured timeline of one click on each path, taken without the screen: wrap the shared operation and the steps of a) in `os_signpost` or timestamps written to the app's own log in a debug-only switch (off in release), run it through a test or the self-test where possible, and say what could only be reasoned about.
d) Your hypothesis of the cause, with the evidence, before changing anything.

## What to build

1. **Fix the cause found in step 0** with the smallest change: for example coalesce several publishes of one click into one, make the list's rows depend only on what they display (identity and equatable rows) so a selection does not rebuild every row, move non-visual work (the thumbnails refresh, the journal, the autosave commit) off the click's critical path or after the first frame, avoid starting two animations that fight (row highlight and Film scroll). Do not remove any reaction the owner sees, and keep the order of effects stated in FIX2.
2. **Keep a regression guard:** a test that one selection operation causes at most N publishes (state N from step 0) and that both entry points call the same operation; a measurement helper that stays in debug builds only.
3. **Nothing else:** no restyle, no change to the Build, the skill, the strip drawing or the inspector's content.

## Tests (no screen)

Both taps reach the same operation; one selection causes the expected number of publishes; the commit of a pending edit still happens before the selection changes (AS1); the playhead and the scroll still follow (FIX2). Update the tests that depended on the old publish pattern and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py patch "..."`; never edit a version by hand. Update CLAUDE.md "Open work" if needed, then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh` (in the batch: once at the end of the batch).

## Final report (docs/Claude/phases/PF1/report.md)

Step 0 results with the numbers, the cause, the fix, the version, what is verified and what is not (no screen: the lag itself is felt, not measured on the real UI; say so plainly), and "To check by hand": click scenes in the Storyboard list quickly one after the other, with 15 scenes and with a scene selected that has an edit pending; compare with a click in the Film; look for a delay before the highlight, the inspector or the playhead; check Reduce Motion on. Stop after the phase.
