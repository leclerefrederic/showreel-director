---
type: decision
status: current
phase: 
date: 2026-11-10
summary: "A scene parked outside the film and an item thrown away are two different places: the group Not in the storyboard, and a trash."
id: DECISION-021
aliases:
  - "DECISION-021"
since: 2026-11-10
affects:
  - "[[ideas/A trash for scenes and resources the owner no longer wants]]"
  - "[[ideas/Drag a scene between the storyboard and the Not in the storyboard group]]"
  - "[[decisions/A scene enters and leaves the storyboard by the eye and by drag and drop]]"
tags:
  - decision
---

# Parked scenes and thrown-away items are two different places

2026-11-10 (owner): asked whether "not in the storyboard" means parked for later or no longer wanted, he chose **two places**: the group "Not in the storyboard" keeps the scenes set aside for later (an alternative take), with the eye and the drag and drop of [[decisions/A scene enters and leaves the storyboard by the eye and by drag and drop]] unchanged; and a **trash** receives what the owner throws away, scenes and resources, restorable and emptied on demand. The alternatives offered and not chosen: one place where hidden means thrown away, and no trash.

To respect when it is built ([[ideas/A trash for scenes and resources the owner no longer wants]]): throwing away is a typed operation (journaled, one undo step, refused on a locked scene with a reason, never silent); a trashed scene keeps its ID reserved until the trash is emptied (see [[decisions/Deleted scene IDs are kept in retiredIDs]]); what a trash does to a resource that a scene still uses is to be settled in the audit and asked as a question, not decided.
