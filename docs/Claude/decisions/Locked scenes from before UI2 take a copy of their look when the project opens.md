---
type: decision
status: current
phase: 
date: 2026-11-11
summary: "Locked scenes from before UI2 take a copy of their look when the project opens."
id: DECISION-028
aliases:
  - "DECISION-028"
since: 2026-11-11
affects:
  - "[[phases/UI2/report]]"
tags:
  - decision
---

# Locked scenes from before UI2 take a copy of their look when the project opens

**Decision.** When a project opens, each locked scene made before UI2 that has no copy of its look takes one automatically. At that moment the copy equals the current look, so nothing changes on screen, and the lock then holds if the global look changes later.

**Why.** The owner accepted the recommendation of QUESTION-010, 2026-11-11.

**Not built yet.** Needs a small phase.
