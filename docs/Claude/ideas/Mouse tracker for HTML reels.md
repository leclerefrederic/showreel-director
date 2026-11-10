---
type: idea
status: draft
phase: ""
date: 2026-11-10
summary: "Optional project setting: the pointer gently moves backgrounds, 3D camera and layers in the HTML player; off by default, ignored by MP4 export."
id: IDEA-051
aliases:
  - "IDEA-051"
since: 2026-11-10
area: skill
source: owner
origin: "docs_new.py"
tags:
  - idea
---

# Mouse tracker for HTML reels (optional, low, medium or high influence)

Optional project setting: the pointer gently moves backgrounds, 3D camera and layers in the HTML player; off by default, ignored by MP4 export.

## The idea (owner, 2026-11-10)

An optional element of the project settings: in the HTML versions, moving the mouse over the screen influences the reel weakly, moderately or strongly.

## Design notes (assistant)

- **One engine signal, many readers.** The player exposes a smoothed, normalised pointer position (x and y from -1 to 1, eased, back to 0 when the pointer leaves) next to the existing signals. Backgrounds, the 3D layer's camera, particles and layers of a scene read it and multiply it by a strength. Low, medium and high are three strengths (for example 0.15, 0.35, 0.7 of each reader's own maximum), never separate behaviours.
- **Off by default.** The skill stays style-neutral: it is an option to offer, never a default. Stored in the project settings and in `showreel.json`, so a package could carry it.
- **The film stays deterministic.** With no pointer the signal is exactly 0, so the Node harness, the pixel tests, the thumbnails and the MP4 export are unchanged. The export cannot carry the effect: say so in the setting's help text.
- **Respect the guards the engine already has:** nothing under Reduce Motion, nothing when muted-or-reduced rules apply, text legibility kept (parallax on backgrounds and 3D first, copy last and tiny), a cap on displacement.
- **Touch and phones:** no pointer, so the setting does nothing there (touch drag or the gyroscope could be a later step). Studio's preview works, since it is a web view.
- **Natural first readers:** the 3D camera (gentle orbit) and the backgrounds (depth parallax), which already have a motion model. Per-scene opt-out is a possible later refinement.
- **Slices:** (1) skill: the signal, the setting, two readers, a guard test; (2) app: the project settings control with its help text; (3) more readers.
