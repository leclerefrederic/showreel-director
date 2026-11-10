---
type: phase-report
status: current
phase: FL1
date: 2026-11-10
summary: "Report of FL1: Film strip frames drawn as film (grid under frames, centred thumbnail on translucent black, reel perforations and caps); app 0.21.4."
app_version: 0.21.4
skill_version: 0.18.2
prompt:
  - "[[phases/FL1/prompt]]"
tags:
  - report
---

# FL1: the scenes of the Film look like film

## Step 0

- a) Order before: background, ruler, frames (with thumbnails), then `GridOverlay` over them (lines cut around labels), markers, playhead. Beat lines were drawn in `GridOverlay` (`TimelineViews.swift`).
- b) Thumbnail: `SceneFrameImage` filled (`scaledToFill`) and clipped, left-aligned in `FrameElements.thumb`; frame background `theme.strip.frame` (opaque).
- c) States: selected (3 pt accent stroke and glow), hover (2 pt white stroke), default (1 pt); locked and hidden are drawn by the existing badges, the veil and the Storyboard, not by the frame; To review is the `SceneStatusIcon` and `BlockMarker`; drag is the `dragSource`. None of these changed.
- d) Zoom: `project.zoom` and `TimelineScale` pps; frame width is `length * pps`, at least 1 pt.

## Built

1. **Layer order:** `StripLayerOrder` / `StripLayer` (Kit); the strip applies `zIndex(StripLayerOrder.z(...))` to the grid, frames, transition markers and playhead. `GridOverlay` now only avoids transition markers (frames cover it).
2. **Thumbnail:** `ThumbnailFit.rect` (centred, aspect fit, 16:9 when no picture). `SceneFrameImage` is `scaledToFit`. Frame background is the new token `thumbBackdrop` (0.55 black), replacing `strip.frame` for frames.
3. **Reel frame:** `ReelFrame.layout` (Kit): perforation bands of `reelBand` 7 pt, perforations 6 x 3 pt every 11 pt, caps 3 pt; threshold **60 pt width** (no perforations below, caps remain) and **40 pt height**. `FrameLayout.elements` is given the content height between the bands, so labels, status icon and duration never touch the perforations. `ReelFrameMarks` draws them from tokens (`perforation` 0.2 white, `cap` 0.42 white, accent when selected). Static, no animation.
4. New tokens in `DesignTokens.Strip` with defaults; nothing else changed (toolbar, music lane, list, inspector).

## Deviations

- The "heavier edge at the cut" is the cap itself (3 pt solid); there is no separate perforation-zone cap.
- Image aspect is the constant 16:9 of `SceneCapture.size`, not read from each PNG.
- The frame's own opaque colour is gone: the whole frame is translucent, so the grid reads faintly through the bands too.

## Tests

`FL1Tests` (11): layer order, thumbnail rectangle (wide, narrow, tall, none), perforation count and minimum, perforations inside bands, caps at every width, short frame, token and layer source guards. No existing test had to change.

## Verified, not verified

Verified: build, tests, `verify.sh --fast`. **Not verified (no screen):** everything drawn: how the perforations, caps, translucency and layers look.

## To check by hand

Beat lines hidden behind a scene, visible between scenes and in the music lane; the playhead crossing a scene; a thumbnail centred on translucent black (wide and narrow scene); perforations and caps at several zooms down to 60 pt wide; selected, locked, hidden and To review frames; hover and drag.
