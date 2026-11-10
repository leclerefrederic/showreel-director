---
type: phase-report
status: current
phase: Q4
date: 2026-11-10
summary: "Phase Q4: English labels for the Ask Clap selector, and a warning listing the locked scenes that a global look change would redraw."
aliases:
  - "Q4"
phases: [Q4]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# Q4

phase Q4 is built (the labels of the Ask Clap selector are in English; a change of the global look that would redraw locked scenes inheriting it lists them on its card, "S02 and S05 are locked and inherit this look", and the user applies anyway or refuses, for the user's edits and for Clap's `update_decision` alike, apply-directly never skipping that card; a scene that has its own value for the changed part is not concerned; a locked scene whose inherited look changed is stale, says why through `Availability.regenerate`, and is never generated again without unlocking)

Rules in ShowreelKit: `LockedLook.swift`, `SceneStates.swift`, `FilmState.swift` (`Availability.regenerate`)
