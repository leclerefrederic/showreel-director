---
type: decision
status: current
phase: 
date: 2026-11-11
summary: "Scenes are written three at once by default."
id: DECISION-025
aliases:
  - "DECISION-025"
since: 2026-11-11
affects:
  - "[[phases/BG2/report]]"
tags:
  - decision
---

# Scenes are written three at once by default

**Decision.** A Build writes three scenes at the same time by default (BG2). The setting stays in Settings and can be lowered to one scene at a time.

**Why.** Faster Build; the owner chose to keep the default (answer to QUESTION-004, 2026-11-11). The trade-off is that each scene is written without seeing its neighbours, which can cost coherence.

**To check.** The comparison of one scene at a time against three on a real film (total time, cost, coherence of the two films) is still to be done; if three at once hurts coherence, reverse this decision.
