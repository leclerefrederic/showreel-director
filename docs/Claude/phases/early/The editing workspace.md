---
type: phase-report
status: current
phase: W1
date: 2026-11-10
summary: "Phase W1: the editing workspace, with a library of tabs, the viewer and the inspector with the Copilot tab."
aliases:
  - "W1"
phases: [W1]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# W1

Phase W1 is built: the editing workspace (Library with tabs Resources, Scenes and Look elements; Viewer; Inspector with the Copilot tab; Storyboard strip) replaces the sidebar of blocks, and the data is a scene library plus `storyboards` (migration of the phase T shape on first save, archive with tombstone). Next, in this order:

Rules in ShowreelKit: `Storyboard.swift`, `ShowreelFile.swift`, `Operations.swift`
