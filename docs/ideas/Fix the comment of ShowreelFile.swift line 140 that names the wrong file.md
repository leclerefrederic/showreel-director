---
type: idea
status: current
phase: 
date: 2026-11-10
summary: "Fix the comment at ShowreelFile.swift line 140, which names the spec for Scene content, a block of the UX notes."
area: app
source: assistant
origin: "question 5 of the OBS1 report"
tags:
  - idea
  - app
---

# Fix the comment of ShowreelFile.swift line 140 that names the wrong file

The comment at `app-swift/Sources/ShowreelKit/ShowreelFile.swift` line 140 reads `docs/studio-spec.md, "Scene content"`, but "Scene content" is a block of the UX notes, [[ux/Scene content]], not a section of the spec. To be done with the next phase that touches the app. The comment itself is not edited by OBS4, which changes documentation only.

Related: [[phases/OBS1/report]], [[phases/OBS2/report]].
