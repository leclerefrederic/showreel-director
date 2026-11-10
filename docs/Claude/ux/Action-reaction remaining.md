---
type: ux
status: current
phase: 
date: 2026-11-10
summary: "What Q5 and Q6 built for action and reaction, and what remains of it."
tags:
  - ux
---

Part of [[ux-notes]].

# Action/reaction: remaining

Built in Q5 and Q6: the state and reason model (`Availability`, `ProjectActivity`, `Marks`), the freeze during a build, the proposals banner, the temporary marks on every surface (the list, the tree, the reel, the inspector and the resources: a veil around the row and a small button at its end, the same tooltip and the same way to the proposal's card), the persistent badges in one order (review state, then build state), the activity chip, the build panel, the closing alert, the status line with Undo, and the standard disabled control (`disabledWithReason`) on the storyboard review, Save scene, the reel's Apply and Revert, the content item's Apply, Build and Test it again, Reset layout, Validate storyboard, the palette editors, the moods picker, the memory form, the editor's Save, the set-up form and screen, the new project and Update and Restore sheets, the preview pane, the wizard's Back and Next. Undo and Redo of the Edit menu, and the move items of a content item's menu, say why in their own title (a menu item has no tooltip).

Left, and why:
- The state choices of a scene's badge menu (`SceneStateViews.swift`) keep the reason in the item's title; the lock switch and the Go button explain themselves with the text beside them. They do not use the standard control: a menu item and a text-led control do not take one.
- The Library's own buttons other than Create (Open, Remove, Locate, Trash) are never disabled today: nothing to do.
- The music toggle of the player (`PlayerViews.swift`) has a tooltip only ("This build has no music"): a toolbar toggle in a custom bar; it needs a small component of its own.
- Clap's own composer (the send button turning into Stop) has no reason line: its rule (busy, no key) is shown by the connect box and the chip.
- An outdated project stays editable: the banner offers Update project, nothing blocks it. Blocking it would be a new rule (decided by the owner).
- The mark of "Clap is applying changes to S02" is shown on scenes and items only, not on the transition markers, the music lane or the settings rows: a transition and the music are not elements with a row of their own yet.

Phases named in this note: [[phases/Q5/report|Q5]]
