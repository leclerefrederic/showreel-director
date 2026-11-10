---
type: idea
status: current
phase: ""
date: 2026-11-10
summary: "A scene cannot be dragged from the storyboard into the Not in the storyboard group, nor back out of it; the owner noted it during the W4 hand test."
id: IDEA-047
aliases:
  - "IDEA-047"
since: 2026-11-10
area: app
source: owner
origin: "owner, W4 hand test"
tags:
  - idea
---

# Drag a scene between the storyboard and the Not in the storyboard group

2026-11-10 (owner, noted while testing W4): "We cannot drag and drop a scene into the 'Not in the storyboard' group and the other way round."

Context found by the assistant (not yet verified in the app): the group is the disclosure "Not in the storyboard" of the Storyboard list (`StoryboardListViews.swift`), and the hidden scenes also appear as dimmed chips under the film strip (`TimelineViews.swift`). The UX decision in [[ux/Storyboard and music]] says a hidden scene "stays reachable as a dimmed chip under the strip (drag it back, or click it)", and W5 built one drag and drop system for every list and target ([[phases/early/Direct manipulation with one drag and drop system]]). So dropping onto or out of this group is a gap or a regression against that decision, to be audited (does the group accept a drop? do the chips drag?). Hiding is done today by the eye, the Delete key or the context menu "Remove from film".

2026-11-10 (owner, right after): "So visible / not visible may not be the right choice." He is questioning the model: a scene is either in the storyboard or not, which a place and a drag say more naturally than an eye that switches a flag.

Settled by the owner the same day: [[decisions/A scene enters and leaves the storyboard by the eye and by drag and drop]] (keep the eye, add the drag and drop). What remains to build: dropping a scene on the group hides it, and dragging a hidden scene into the list or the strip shows it at the drop position, one undo step either way, refused on a locked scene with a reason. Status `current`: the owner wants it soon. Placement (owner, 2026-11-10): it is built in the same phase as [[ideas/A trash for scenes and resources the owner no longer wants]], not in W4b, since both touch the same zone.
