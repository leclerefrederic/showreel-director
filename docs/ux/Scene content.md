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
