---
type: phase-report
status: current
phase: D3
date: 2026-11-10
summary: "Batch D3: fixes a resource drag that blocked the panel, so that a drag ends in one place."
aliases:
  - "D3"
phases: [D3]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# D3

batch D3 is built (the drag of a resource blocked the panel; the report of the one crash found was older and unrelated; a drag ends in one place, `DragRun.finish`, whatever the outcome, and says it in `drag.log`, with a line when no drop target saw the drag; the resource drag carries only the plain-text token like a scene handle and the typed token of D1 and its drop destinations are removed; pictures of rows and of the drag preview come from `ThumbnailCache` (memory, read once in the background); the drag log writes on its own queue and ignores errors)

Rules in ShowreelKit: `DragSession.swift` (`DragRun`, `ThumbnailCache`), `DragLog.swift`
