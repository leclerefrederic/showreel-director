---
type: ux
status: current
phase: 
date: 2026-11-10
summary: "Owner remarks on scene content, starting with a bug where adding an item made the existing items lose their text."
tags:
  - ux
---

Part of [[ux-notes]].

# Scene content

- Bug seen in use: adding another content item (a second text) makes the existing items lose what was typed, and every text field shows the placeholder "Your words" again.
- "Your words" must be a real placeholder (grey ghost text that disappears as soon as the field has focus), never a stored value. An empty text item stays empty. This may be the cause of the bug above if the default text is saved as content.

- Content is a map of what the scene contains and the instructions for the AI. Items: a text, its colour (linked to the palette, or "AI decides"), its animation (fly in, and so on, or "AI decides"), an optional instruction. The user chooses how much control they want. The order of the items is their processing priority.

**Built in W4 (2026-11-10).** Each item of a scene has a timing, fixed or auto like its other attributes: the Composition row has a "Timing in the scene" control (Auto, or Fixed with In and Out in seconds from the scene's start). A value outside the scene is refused with its reason, nothing is written, and a locked scene refuses with the lock's reason. Items follow a changed duration (an Out past the new end is pulled back, an Out that was the end follows a longer scene). The scene's picture, in the strip and in the viewer, is drawn from the content: the items on screen at a time, the colours of the palette, the images of the resources; an auto colour is drawn neutral and an auto animation is not drawn, and the picture says "AI decides". A scene has one thumbnail, and several only when its stills really differ. With nothing selected the viewer follows the playhead into the scene. `storyboard.md` and the build message carry the timing. Open questions: [[questions/What form should the timing control of an item take]], [[questions/Should an item's timing snap to the music grid]], [[questions/Should timing be in seconds or in beats]], [[questions/Should the viewer play an item's timing live]]. Remains: the viewer does not play the timing, no snapping to the beat grid, no scene-wide effects (the Effects tab was removed in DS3).

