---
type: phase-prompt
status: current
phase: W4c
date: 2026-11-10
summary: "Fixes W4b: on an existing project the strip frames are empty, with no placeholder and no tooltip, even after a rebuild of app 0.21.0."
tags:
  - prompt
---

# Phase W4c: existing projects show empty frames in the strip (W4b bug)

Read CLAUDE.md first and follow every rule (never run git; English interface; answer the owner in French and short; no screen, so say what was not seen). Use `graphify query` before reading files. Build only this fix; nothing from the ideas below.

## Symptom (owner, app 0.21.0 confirmed in About, after a rebuild)

On an existing project the frames of the strip show no picture. Hovering a frame shows nothing: no tooltip at all. `SceneFrameImage` (`SceneFrameViews.swift`) always draws a placeholder and always sets `.help(...)`, even with no PNG, so an empty frame without tooltip means the view is not drawn as expected, is covered, or has no size, or it is not the view in use for these projects. A new project was not reported as broken; check it too.

## Audit first (report before any fix)

1. Reproduce on a copy of an existing project (the demo in `demo/` and a project without `.studio/scene-thumbs/`). Find where the strip draws a frame (`TimelineViews.swift`, `thumbs(_:)`, `FrameElements.thumbWidth` and `thumb.height`): can the width or height be 0 for older projects (no timing, no duration, old content model), and does anything above the frame take hit-testing or hide it?
2. Check that every scene of `showreel.film` of an old project gets a state from `SceneThumbs.states` and that `SceneFrameImage` is reached for it.
3. Check the other suspects and say which are real: `playableVersion` nil; `SceneModules.moduleHash` nil for projects built before per-scene module files; `activity.build` or `assembling` stuck so no capture is ever scheduled; a cached `book.failed` entry; the hidden window of `SceneCapture` not drawing.
4. State the root cause with file and line and how sure you are.

## Fix

- A failing test first on an existing-project fixture (ShowreelKit if the cause is logic; a characterization test of the state or the frame size otherwise).
- Fix the cause, not the symptom. If old projects have no module files, say how the build writes them or how the state should read ("Build the film to get its picture"), keeping the UI principle (action/reaction; say why and how to get it back).
- A frame must never be empty: if there is no size to draw, give it the minimum one.
- Keep W4b's rules (one capture at a time, never during a build, quiet delay).

## Vault, release, verification

Report in `docs/Claude/phases/W4c/report.md`; if the fix changes a documented rule, update that note. `python3 tools/docs_index.py --write`, `python3 tools/check_docs.py`. Release notes in RELEASE-NOTES-APP.md, then `python3 tools/bump_app.py patch "..."`. `tools/verify.sh --fast` during, `tools/verify.sh` then `tools/rebuild-app.sh` at the end. Say which verify you ran and what the owner must look at by hand: open an existing project, wait a few seconds after a build, hover a frame, press Refresh thumbnail.

Stop after the phase.
