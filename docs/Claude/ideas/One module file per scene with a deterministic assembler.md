---
type: idea
status: superseded
date: 2026-11-09
summary: "Let the AI write each scene as its own module file with a deterministic assembler, so main.js is reassembled without AI and one scene regenerated."
area: skill
source: assistant
origin: "ideas.md"
id: IDEA-016
aliases:
  - "IDEA-016"
since: 2026-11-09
outcome: built
outcome_link:
  - "[[phases/BG1/report]]"
  - "[[phases/BG1c/report]]"
phase: BG1
tags:
  - idea
  - skill
---

# One module file per scene with a deterministic assembler

2026-11-09: let the AI write each scene as its own module file (scenes/S01.js) with a deterministic assembler in the skill's scripts, so that the app can reassemble main.js without AI and regenerate one scene only (the premise of phase V, see docs/Claude/archive/overnight-report.md).

Related: [[phases/BG1/report]], [[phases/BG1c/report]], [[archive/overnight-report]].

Built: the Build writes the scenes one by one as separate files, see [[phases/BG1/report]] and [[phases/BG1c/report]].
