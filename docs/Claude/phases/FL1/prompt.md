---
type: phase-prompt
status: current
phase: FL1
date: 2026-11-10
summary: "Film strip scenes: beat lines behind the frames, centred thumbnails on translucent black, a film-reel frame that shows where each scene starts and ends."
tags:
  - prompt
---

# Phase FL1: the scenes of the Film look like film

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic: rules live in ShowreelKit with tests. The owner waived the open questions for the redesign. The owner loves the look of the app today: **change only what is listed here** and keep every behaviour; where a colour has no token, add a token with that value, no new colour literal.

Read docs/Claude/ux-notes.md (the entries on the Film strip, "Visual direction", "Motion: the interface answers"), the DS2 and W4b reports, and the code of the strip (TimelineViews.swift and the views it draws: the scene frame, the thumbnail, the beat and bar grid, the music lane, the playhead, the markers), `DesignTokens`, the Motion file.

## Step 0 (read-only, 10 lines at the top of the report)

a) The drawing order of the strip today (grid, frames, thumbnails, markers, playhead) and where the beat lines are drawn.
b) How a thumbnail is placed in its frame (fit or fill, alignment) and what the frame's background is.
c) The frame's states (selected, locked, hidden, hover, drag, To review marks) and what each draws, so the new frame keeps them.
d) How the strip is zoomed and what the smallest frame width is.

## What to build

1. **Beat lines never cross a frame.** Drawing order, bottom to top: background, beat and bar grid, scene frames, transition markers, music markers, the playhead (the playhead stays on top: it is the one line allowed over a scene). The grid stays visible between frames and in the music lane. Express the order as a pure `StripLayerOrder` in ShowreelKit with a test, so no view can reorder it.
2. **The thumbnail is always centred** in its frame (horizontally and vertically), shown whole (aspect fit, never cropped, never stretched), on a **translucent black background** (a token, about 55 percent black): the grid may read faintly through it on the empty sides, which is intended. A pure function gives the thumbnail's rectangle from the frame size and the image aspect, with tests (wide frame, narrow frame, tall image, no image yet).
3. **A film-reel frame around each scene** so the eye sees where it starts and where it ends: perforations along the top and bottom edges (a repeating pattern, size and spacing from the tokens, the count derived from the frame width by a pure function with tests), and distinct start and end caps (the first and last perforation zone are solid, a slightly heavier edge at the cut). It must not touch the labels, the status icons or the duration text: the perforations live in a band of their own above and below. Under a minimum width the perforations disappear and only the start and end caps remain; say the threshold. All four states of step 0 c keep their marks; a locked scene's frame shows its lock as today. The look is static: no new animation. Keep it quiet: perforations in a low-contrast neutral from the tokens, the accent only on the selected frame's caps.
4. **Nothing else:** no change to the toolbar, the music lane's content, the Storyboard list, the inspector, the Build.

## Tests (no screen)

Layer order (the grid is below the frames, the playhead above everything); the thumbnail rectangle in the four cases; the perforation count for several widths and below the minimum; the caps exist for every width; a source guard that the new drawing uses no colour literal. Update the tests that assumed the old drawing and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py` (a patch version unless you can say why it is minor); never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in FL1 (date)" and what remains), ROADMAP.md if a limit is lifted, CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh`.

## Final report (docs/Claude/phases/FL1/report.md)

Step 0 results, what was built point by point, deviations, the version, what is verified and what is not (no screen: nothing drawn, animated or felt is verified, say so plainly), and "To check by hand": beat lines hidden behind a scene and visible between scenes and in the music lane; the playhead crossing a scene; a thumbnail centred on translucent black for a wide and a narrow scene; the reel perforations and the start and end caps at several zoom levels, down to the width where they disappear; selected, locked, hidden and To review frames; hover and drag. Stop after the phase.
