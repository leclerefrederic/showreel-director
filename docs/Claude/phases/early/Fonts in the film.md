---
type: phase-report
status: current
phase: F
date: 2026-11-10
summary: "Phase F: fonts in the film, each Look font showing Needs files, Preview only or Embedded, with an Add font files operation."
aliases:
  - "F"
phases: [F]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# F

phase F is built (fonts in the film: each font of the Look shows Needs files, Preview only or Embedded; the typed operation Add font files, with one card (the font, the open Google Fonts repository from the skill's fixed list, the licence, the files and size, the network), downloads only the weights the Look uses into `assets/fonts/<family>/` and approves them in the manifest, undoable, also proposed by Clap with `add_font_files`; the build and the assembly embed the approved files through `fonts.json`, merged by the skill's `build.py`, and show an orange Fonts step when a font has no file; adding files makes the film stale and no scene; a dropped font file shows its family and weight and needs its licence note before approval)

Rules in ShowreelKit: `FontFiles.swift`, `FontInfo.swift`
