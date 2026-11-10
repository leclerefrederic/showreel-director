---
type: idea
status: superseded
date: 2026-11-10
summary: "The app writes the montage as film.json, inlined by build.py, so main.js reads scene starts, durations and transitions instead of copying them."
area: app
source: assistant
origin: "ideas.md"
id: IDEA-012
aliases:
  - "IDEA-012"
since: 2026-11-10
outcome: built
outcome_link:
  - "[[phases/BA1/report]]"
phase: 
tags:
  - idea
  - app
---

# Write the montage as film.json for the build

2026-11-10: the app writes the montage as a film.json that build.py inlines (scene starts, durations, transitions), so main.js reads them instead of copying them from the message.

Related: [[phases/BA1/report]].

Built: the app writes `vN/film.json` before each Build (`Film.write`), see [[phases/BA1/report]].
