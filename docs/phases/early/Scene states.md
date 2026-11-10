---
type: phase-report
status: current
phase: Q2
date: 2026-11-10
summary: "Phase Q2: the scene states WIP, Validated, Locked and Ditched."
aliases:
  - "Q2"
phases: [Q2]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# Q2

phase Q2 is built (scene states WIP, Validated, Locked, Ditched, `SceneState`: the older words ok, open and modify are read as Validated, WIP and WIP with a note, and the file moves to format revision 2 through "Update project"; one check in `ProjectStore.plan` refuses any change to a locked scene, from the user, from a drop and from Clap, with the reason; only a Validated scene can be locked, by the typed operation `sceneLock`, one card, undoable; a state badge with a menu, "Lock all validated", `lock_scene` for Clap)

Rules in ShowreelKit: `SceneStates.swift`
