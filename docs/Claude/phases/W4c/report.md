---
type: phase-report
status: current
phase: W4c
date: 2026-11-10
summary: "Report of W4c: the blank strip frames of W4b came from a capture window that never painted; fixed, with old pictures retaken; app 0.21.1, skill unchanged."
app_version: 0.21.1
skill_version: 0.18.2
prompt:
  - "[[phases/W4c/prompt]]"
tags:
  - report
---

# W4c: existing projects showed blank frames in the strip (a W4b bug)

## Audit

1. **Size and hit-testing.** `FrameLayout.elements` never gives a thumbnail under 1 pt (`max(1, …)`), and `FrameView` gives a frame at least 1 pt wide (`TimelineViews.swift`, `max(1, …)`), so no old project (no timing, no duration) yields a zero size. The picture layer is `.allowsHitTesting(false)`, so the `.help` set inside `SceneFrameImage` could never show: that is the missing tooltip. The frame's own `.help` only said the scene's label.
2. **States.** `SceneThumbs.states` covers every scene of `showreel.film`, and `FrameView` always reaches `SceneFrameImage` (it draws a placeholder when there is no state).
3. **Suspects.** `playableVersion` nil, `moduleHash` nil, a stuck `activity.build` or `assembling`, a cached `failed` entry: **none is real** on the project I could read (`Showreel Studio Trailer`: v6 has its scene files, `index.json` has 14 entries and no failure). The hidden capture window not drawing: **real**.
4. **Root cause (certain, reproduced).** The 14 PNGs in `.studio/scene-thumbs/` of that project are byte for byte the same size (17,862 bytes) and are a flat `#111111` image: the film's background with nothing drawn. `SceneCapture` kept its window at `(-4000, -4000)` and ordered it back. The film page draws on `requestAnimationFrame`, which a window that is off screen or ordered back does not run: after the seek the page's clock read `0:00` and its canvas was still 300 × 150. With the same page loaded in a window on the screen (nearly transparent, ordered front) the clock reads `0:04 / 1:30` and the scene draws. The capture neither noticed the blank picture nor refused it: it recorded it as fresh, so no placeholder, and the state never asked for another capture. A new project showed placeholders only because it had no build yet; the first build would have given blank pictures too.

I reproduced it with a small program of my own outside the repository (a web view in a window, the film page, a seek, a snapshot; no screen capture, no other app): off screen or ordered back, blank; on screen at alpha 0.01 and ordered front, the confetti scene of 4.5 s.

## Fix

- **`SceneCapture`:** the window is on the screen (lower-left corner of the main screen), alpha 0.01, deaf to the mouse, `orderFrontRegardless`; and the capture polls the page's clock (`#tm`) until it reads the instant (`SceneThumbs.timecode`, 3 s at most): if it never does, the capture fails with "The film page did not draw the scene" and the frame shows that reason instead of a dark picture.
- **`SceneThumbs`:** an entry carries the capture format (`captureFormat` = 2). Entries without it (everything 0.21.0 recorded) are not trusted: the state is "not captured yet" and the scene is capturable, so the pictures are retaken by themselves after the project opens, one at a time, after the quiet delay and never during a build.
- **`FrameView`:** the frame's tooltip now says what the picture is (captured, out of date and why, no picture and why).
- Not changed: one capture at a time, quiet delay, never during a build, the states and the refresh rules.

## Tests

`W4bTests`, new: `testACaptureOfAnOlderFormatIsNotTrustedAndIsTakenAgain` (written first; it did not compile, then failed until the format existed), `testTheTimecodeIsTheOneTheFilmPageWrites`, `testAFrameIsNeverEmpty` (the layout never gives a thumbnail under 1 pt). The other `W4bTests` and `W4Tests` still pass.

## Version

App **0.21.1** (a patch: a fix). Skill **0.18.2**, unchanged.

## Verified and not

Verified: the tests above; the cause and the on-screen window working, by the experiment described; the verification commands are in the closing message. **Not verified (no screen in the app itself):** that the app's own capture now produces the real scenes, that 3 s is enough for the film page to start its clock on a slow machine, that the nearly transparent window is not noticeable in the corner, and WebGL or 3D scenes.

## To check by hand

Open an existing project that has a built film, wait a few seconds, and look at the strip: the frames should show the real scenes (the old blank pictures are retaken by themselves). Hover a frame: its tooltip says what its picture is. Press Refresh thumbnail in a frame's menu. If a frame shows a reason instead of a picture, send it to me.
