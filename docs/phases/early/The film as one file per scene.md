---
type: phase-report
status: current
phase: V1
date: 2026-11-10
summary: "Phase V1: the film as one file per scene, assembled by the skill's assemble.py."
aliases:
  - "V1"
phases: [V1]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# V1

phase V1 is built (the film as one file per scene: the skill's `scripts/assemble.py`, run by `build.py`, puts `scenes/<ID>.js` and `reel.js` into `main.js` with no AI and the same bytes for the same files, shows a placeholder frame for a scene with no file and lists it in `assembly.json`; a version with only a hand-written `main.js` builds as before; `SceneGeneration` asks the model for one or several scenes only, writes only those files, refuses a locked scene, is one card for Clap's `generate_scenes`; `.studio/build.json` records for each scene the fingerprint of its inputs and of its file, so that a scene is not generated, up to date or stale, plus a flag when the file was edited by hand)

Rules in ShowreelKit: `SceneModules.swift`, `SceneGeneration.swift`
