---
type: phase-report
status: current
phase: W4b
date: 2026-11-10
summary: "Report of W4b: scene thumbnails are a PNG captured from the real built scene, with placeholder, stale mark and refresh; app 0.21.0, skill unchanged."
app_version: 0.21.0
skill_version: 0.18.2
prompt:
  - "[[phases/W4b/prompt]]"
decision:
  - "[[decisions/Scene thumbnails are a PNG capture of the real scene]]"
tags:
  - report
---

# W4b: scene thumbnails are a PNG of the real scene

## Step 0

1. **How a scene renders.** The film is one page, `vN/dist/index.html` (the assembled scene modules), which `ReelPlayer` shows in a `WKWebView` and seeks with its own `#seek` range input (steps of 0.1 s; `window.SR.data.dur` is the length). A scene can therefore be drawn at a chosen instant without playing: seek to the scene's start in the film plus the instant. It needs the whole film page, once per version, not a render per scene. WebGL scenes are drawn by the web view (the Node harness cannot see them). The resolution is the page's own canvas, scaled to the web view; a render is a seek and a wait.
2. **How to capture.** `WKWebView.takeSnapshot` on a web view held by a nearly transparent borderless window (a web view only draws inside a window) at 640 × 360. One page load per version, then a seek, 0.35 s for the scene to draw, a snapshot: about half a second per scene, so 10 scenes take a few seconds and 30 about fifteen, one at a time on the main actor without blocking the interface (the work is waiting, not computing). Failures: a missing page, a page that does not load (20 s limit), a missing seek control, no image from the web view; each records its reason.
3. **Where PNGs live.** `.studio/scene-thumbs/<ID>-<hash>.png` plus `index.json` (the entry per scene: file, hash of the scene file, what it was generated from, instant, version). The name carries a hash of the scene, the file, its inputs and the instant, so a new image never overwrites the one it replaces, which is deleted. Orphans (a deleted scene, a stray PNG) are cleaned at each refresh. A path with a folder or another extension is refused. About 100 to 300 KB per scene at 640 × 360.
4. **The representative instant.** Options: the W4 still time (three quarters through, or the middle of the busiest state when items have times), the middle, the busiest moment, the last moment before the exit. Applied: the W4 still time, kept inside the scene (QUESTION-017).
5. **Does the viewer share the drawing code of W4?** Yes: the viewer (scene selected, or nothing selected with the playhead on a scene) and the transition preview use `SceneThumb`, which uses `StageThumb`. Applied, behind QUESTION-018: the viewer keeps it before a build (it is the only picture there is); the strip and the inspector stop using it.

### The owner's choices, with the default applied

- QUESTION-017: Which instant of a scene should its thumbnail show (default: the W4 still time).
- QUESTION-018: Should the viewer keep its content drawing before a build (default: yes).
- QUESTION-019: Should the strip mark every frame as fresh or only the stale ones (default: only the stale ones).

Decision recorded: DECISION-022, Scene thumbnails are a PNG capture of the real scene.

## What was built

- **ShowreelKit** `SceneThumbs.swift`: the key and file name, the instant, the job (scene, version, absolute film time), the state of a frame derived from the files (placeholder with a reason, fresh, stale with what changed and whether only a build can fix it, failed with its reason), the scenes a capture can bring up to date (never a loop on a scene changed after the build), the storage, the failure record, the orphan cleanup, the size, the journal line, `refreshAvailability` (why and how to get it back), and `SceneThumbQueue` (one at a time, in order, each scene once, cancellable).
- **ShowreelStudio**: `SceneCapture.swift` (the web view and the snapshot), `SceneThumbModel.swift` (the states in `ProjectModel.sceneThumbs`, recomputed at each refresh; captures after a 1.5 s quiet delay, only while no build runs; Refresh thumbnail and refresh all, journaled as an app event), `SceneFrameViews.swift` (`SceneFrameImage`: the PNG, the PNG with a clock mark, or the placeholder; `SceneFramePanel`: the larger picture in the scene inspector with its Refresh button), the strip uses it, the frame's menu has "Refresh thumbnail".
- **Removed**: the schematic drawing and its several tiles from the strip; the "AI decides" icon variant (the viewer keeps the word label); the `still` mode of `EngineSceneThumb`. `ContentTiming.stills` stays (pure timing rule, tested).
- **Not changed**: the skill, timing rules, rail, Build, transitions, look.

## Versions

App **0.21.0** (a minor: a new capability and a visible change of the strip). Skill **0.18.2**, unchanged.

## Tests

`W4bTests` (11): placeholder reasons; the job and the instant inside the film; fresh, stale after a scene edit (needs a build, not capturable, no loop), stale after a rebuild (capturable); the key changes with duration and not with a note; the look changes staleness; a failure and its reason until the file changes; orphans, old projects with no folder, nothing created by cleaning; refused paths; the queue; the refresh availability; the views draw the state and never decide it (by source). Updated: `W4Tests.testTheViewsDrawFromTheRulesAndNeverFromTheirOwn` (the strip now uses the captured PNG, not the W4 drawing).

## Verified, not verified

Verified (run): `W4bTests` and `W4Tests`; the other checks are listed in the closing message (fast verify, `check.py`, complete verify, rebuild). **Not verified (no screen): the capture itself** (that the hidden window lets the web view draw, that the seek lands on the right moment, that 0.35 s is enough, WebGL and 3D scenes), the image quality, the clock mark, the placeholder and the layout in the strip and inspector, VoiceOver. If the capture fails on screen, frames show the failure reason, not a wrong picture.

## To check by hand

1. Build a film: every frame shows the real scene, not a drawing (a few seconds after the build).
2. Change a scene's text or duration: its frame gets the clock mark and a tooltip; after the next build it refreshes.
3. Open a project with no build: the placeholder says why and that Build gives the picture.
4. Use "Refresh thumbnail" in a frame's menu and in the scene inspector; also while a build runs (it must say why not).
5. Check a 3D scene.
6. Look in `.studio/scene-thumbs/` of a project: the PNGs are there and small.
7. Delete a scene: its PNG goes.
