---
type: decision
status: current
phase: 
date: 2026-11-10
summary: "A scene enters and leaves the storyboard by the eye and by drag and drop."
id: DECISION-020
aliases:
  - "DECISION-020"
since: 2026-11-10
affects:
  - "[[ideas/Drag a scene between the storyboard and the Not in the storyboard group]]"
  - "[[ux/Storyboard and music]]"
tags:
  - decision
---

# A scene enters and leaves the storyboard by the eye and by drag and drop

2026-11-10 (owner): asked whether "visible / not visible" (the eye) is the right model, since a scene is either in the storyboard or not, he chose to **keep the eye and add drag and drop**: a scene can be hidden or shown by the eye (and by the Delete key and the context menu "Remove from film", as today) and also by dragging it into the group "Not in the storyboard" and back into the storyboard or the film strip. The alternative offered and not chosen: a place only, with no eye.

Why: both gestures stay available; nothing is removed. Consequences to respect when it is built: the same typed operation behind every gesture (one undo step, journaled, refused on a locked scene with a reason, never silent), the stored model does not change (a scene hidden is still "not enabled" in the storyboard), and the tooltips of the eye say what the drag does too. Built by the phase that takes [[ideas/Drag a scene between the storyboard and the Not in the storyboard group]].
