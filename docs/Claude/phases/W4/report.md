---
type: phase-report
status: current
phase: W4
date: 2026-11-10
summary: "Report of W4: timing of each item inside its scene, pictures and viewer drawn from the content, one thumbnail per scene; app 0.20.0, skill unchanged."
app_version: 0.20.0
skill_version: 0.18.2
prompt:
  - "[[phases/W4/prompt]]"
spec:
  - "[[spec/10 Phases]]"
  - "[[spec/3.1 The showreel.json schema]]"
  - "[[spec/5.5 Editing workspace]]"
tags:
  - report
---

# W4: timing inside the scene, and a viewer and thumbnails drawn from the content (app 0.20.0, skill unchanged 0.18.2)

## Step 0

### Where things were

- **The item model** (`Content.swift`): text, resource, colour and animation (each `auto` or fixed), instruction. No `in` or `out`: the prompt says they were reserved "to come with W4", but nothing reserved them; the only trace was `Checks.visible`, which read them from the item's *unknown* keys (a placeholder for "the layers of a later phase") and so did not yet read a real field.
- **What the pictures drew:** the strip's thumbnails and the viewer called the engine (`EngineService.sceneFrames`): the scene's first line of text, with the project's effects pack, background and palette. "A scene has no layers yet (phase W4), so this is a stand-in." No item colour, no image, no timing was drawn.
- **The strip and the viewer, the two defects of the UX note:** both were already fixed before this phase. A scene has one thumbnail (`FrameLayout.thumbTiles` was fixed at 1, waiting for real stills), and with nothing selected and no build the viewer already follows the playhead (`sceneUnderPlayhead`). What was missing was the time inside the scene.
- **`storyboard.md` and the skill's export:** `visualColumn` summarised the items' fixed attributes; the skill's `export_studio.py` writes the content with every attribute auto and has nothing to say about time. The skill needs no change.
- **The music grid (T2):** drawn over the strip, used for snapping the cuts; nothing snaps an item.
- **Composition rows:** each edit is a typed operation (`project.updateItem`, `ContentEdit`), journaled, committed by `autoCommit` with an undo key (AS1), refused on a locked scene through `Availability.edit(.item(...))` with its reason.
- **Scene-wide effects:** none exist. The Effects tab was removed in DS3 (`SceneTab(.effects)` opens Composition); each item's animation control lives in its Composition row. Out of this phase, as the prompt says.

### The proposal, as built

- **The control:** a "Timing in the scene" row in each item's Composition section: a segmented Auto or Fixed, and, when Fixed, two `StepperField`s (In and Out, seconds from the start of the scene, to the tenth) with the form system's keys. A value outside the scene is refused with the reason under the field and nothing is written. Fixing starts from "there all along" (0 to the scene's end); Auto clears both bounds. With no scene duration the switch is disabled with its reason ("The scene has no duration yet"), never silently.
- **The rules** (`ContentTiming`, pure): In is 0 or more, Out is at most the scene's duration, Out at least 0.1 s after In, In at least 0.1 s before the end; a bound left empty means from the start or to the end; both empty is auto. Overlap is allowed. An item is on screen from In up to, not including, Out; one that runs to the end is still there on the last instant. When the scene gets shorter, an Out past the new end is pulled back to it and an In past it keeps 0.1 s before it; when it gets longer, an Out that was exactly the old end follows; any other time stays.
- **Active items at time t:** `ContentTiming.active(in:at:)`, in priority order. **The stage:** `Stage.frame(of:in:at:)` resolves the colours (palette role, custom hex), names the images' resources, and marks what is still `auto`; an auto colour is neutral, an auto animation is not drawn, and the picture is flagged "AI decides" (an icon in a tile, the words in the viewer) and described for VoiceOver.
- **Thumbnails:** one still per scene, at three quarters through when every item is there all along (as before) or at the middle of the busiest state; several (at most 4) only when the scene's states differ and the frame is wide enough for each at the 16:9 shape (`FrameLayout.elements(... stills:)`). The viewer draws a scene at its still time, and at the playhead's time inside the scene when it follows the playhead (`TimelineNav.sceneAndTime`).
- **The project file:** two optional fields on a content item, `in` and `out` (numbers, seconds), written only when a timing is fixed. `schema` stays 1. An older project has none and opens and saves unchanged (tested); an older app keeps them as unknown keys.

### The owner's choices, with the default applied behind each

- QUESTION-013: What form should the timing control of an item take (default: two steppers behind an Auto or Fixed switch).
- QUESTION-014: Should an item's timing snap to the music grid (default: no, free to a tenth of a second).
- QUESTION-015: Should timing be in seconds or in beats (default: seconds).
- QUESTION-016: Should the viewer play an item's timing live (default: no, a still at a time).

## What was built

- **ShowreelKit:** `ContentTiming.swift` (the rules, `ContentTimes`), `Stage.swift` (the stage model); `Content.swift` (`timeIn`, `timeOut`, `timing`, `ContentEdit.times`, the validation, the card lines, `allAuto` counts a fixed timing); `Reel.swift` (the resize and the cut move the items; `Checks.visible` reads the real fields); `Timeline.swift` (`sceneAndTime`, `FrameLayout.elements(stills:)`); `ProjectDocs.swift` (the storyboard's visual column); `Build.swift` (the build message says "timing in the scene: FIXED in 1 s, out 3 s" or AUTO).
- **ShowreelStudio:** `ContentViews.swift` (the timing control, a clock mark on a fixed row), `StageViews.swift` (new: the stage drawn from the content), `WorkspaceViews.swift` (`SceneThumb` draws the stage for a scene with content, the engine's stand-in for one without), `TimelineViews.swift` (the tiles), `InspectorViews.swift` and `ProjectModel.swift` (the playhead's time inside the scene).
- **Not changed:** the skill, the rail, the top bar, the Build, the transitions, scene-wide effects, the text of `docs/Claude/spec/` (only the W4 row got a line saying what was built and what became of the Effects tab).

## Tests

`W4Tests` (15): the validation rules and their reasons; active items at several times (overlap, Out excluded, the last instant); the shrink and grow rules, and through the resize operation with the card lines; an old project opens and saves with no `in` or `out`, an unknown key is kept; the operation sets, refuses outside the scene without writing, clears to auto and adds with a timing; a locked scene refuses and says why; one undo step per field in two seconds; the storyboard column and the build message; the stage's colours from roles, auto neutral and flagged, only the items active at the time, an image from its resource; the single-still rule and the strip's tiles; the viewer's time into the scene; the views call the rules (by source).
**Tests updated because they assumed the old behaviour:** `ContentTests.testRoundTripKeepsUnknownKeysEverywhere` (the `in` key used to be an unknown key; it is now read as `timeIn`), `ContentTests.testTheScenePromptListsItemsInPriorityWithFixedAndAuto` (the build message now has the timing), `ReelTests.testTransitionChecks` (it set the timing through unknown keys; it sets `timeIn` and `timeOut`). `DS1Tests` made me use the theme for colours in the new view (no colour picked by the view).

## Versions

App **0.20.0** (a minor: a new capability, and a scene with content no longer shows the engine's stand-in). Skill **0.18.2**, unchanged: the audit found nothing to change there (its export carries no timing, and the build message carries it).

## Verified, not verified

Verified (run): `tools/verify.sh --fast` during the work; at the end `python3 tools/check.py`, the **complete** `tools/verify.sh` and `tools/rebuild-app.sh` (results in the last message). The rules, the operations, the file round trip, the stage model, the strip's layout, the playhead's time and the wiring (by source) are tested.
**Not verified (no screen): anything drawn, dragged or animated.** That the Timing row looks right and the steppers behave in the inspector; that the stage's text, images and flag are legible and well placed at the strip's size and in the viewer; that the backdrop (the project's background frames, or the palette's background) shows; that "AI decides" reads well; that the tiles lay out in a wide frame; that Reduce Motion needs nothing (the new pictures do not animate); VoiceOver on the new control and pictures. A text that does not fit a tile shrinks (minimum scale 0.4) and may be unreadable in a small one.

## To check by hand

1. Add two or three items to a scene (words, an image from the Resources) and open one: set Timing to Fixed and give it an In and an Out in the inspector. Type an Out past the scene's length: it is refused, the reason shows under the field, and nothing changes.
2. Change the scene's duration (the Duration field, or by dragging the end in the strip) and watch the items follow: an Out past the new end is pulled back; an Out that was the end follows a longer scene.
3. Look at the scene's thumbnail and the viewer at several playhead positions: only the items on screen at that time, the words in the palette's colours, the image, and an "AI decides" mark on what is auto.
4. Give two items different times so that they never overlap: the strip may show two stills; a long scene with all items there all along shows one.
5. With nothing selected and no build, move the playhead across a scene: the viewer follows it and shows the scene at the right moment.
6. Lock a scene and try to change an item's timing: refused, with the reason. Undo after a timing edit: one press returns it.
7. Open an old project: nothing changes, no timing is written. If a track is analysed, nothing snaps (question QUESTION-014).
