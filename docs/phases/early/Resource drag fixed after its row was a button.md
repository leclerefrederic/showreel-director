---
type: phase-report
status: current
phase: D2
date: 2026-11-10
summary: "Batch D2: fixes the drag of a resource that did not start because its row was a Button."
aliases:
  - "D2"
phases: [D2]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# D2

batch D2 is built (the drag of a resource did not start because its row was a Button, which takes the press: the row is now a plain view that selects on a click and drags from its whole surface, with a handle and an open-hand cursor on hover, a preview with the thumbnail and the name, and the start of the drag in `drag.log`; a way without dragging: the right-click menu of a resource with "Add to scene" (locked scenes greyed with their reason, archived ones left out, everything greyed during a build) and "Use as the project's music", and "Use in a scene..." in the inspector of a resource, all through the typed drop operations, with the line at the bottom and Undo)

Rules in ShowreelKit: `ResourceMenu.swift`, `DragLog.swift` (`DropPlan`), `Drops.swift`
