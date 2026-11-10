---
type: phase-report
status: current
phase: D1
date: 2026-11-10
summary: "Batch D1: a resource dragged to a scene is taken by the scene targets through a typed payload."
aliases:
  - "D1"
phases: [D1]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# D1

batch D1 is built (a resource dragged to a scene: the scene targets take the resource by a typed payload (`com.showreelstudio.resource-token`, declared in Info.plist by make-app.sh, checked by `--selftest` and `tools/verify-bundle.sh`) with `dropDestination`, beside the geometry-resolved drop that stays for slots, lists and Finder files; the pure `DropPlan` gives the operation or the refusal for a token and a target, a lost token has its own message; every release ends with a line at the bottom; `drag.log` in `~/Library/Logs/ShowreelStudio/`, bounded and with no content or user path)

Rules in ShowreelKit: `DragLog.swift` (`DragLog`, `DropPlan`), `Drops.swift`
