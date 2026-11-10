---
type: decision
status: superseded
phase: UI2
date: 2026-11-09
summary: "The instruction field is the scene's note and writing it does not switch Ready; superseded when the field was removed in DS3."
id: DECISION-010
aliases:
  - "DECISION-010"
since: 2026-11-09
affects:
  - "[[phases/UI2/report]]"
tags:
  - decision
---

# The instruction field is the scene note and does not switch Ready

**Decision.** "The 'instruction field' is the scene's existing `note` (labelled Instruction); writing it does not switch Ready by itself."

**Where it is recorded.** [[phases/UI2/report#Decisions taken]].

**What it affects.** [[phases/UI2/report]].

Superseded: the owner removed the State section's Instruction field in DS3 (see the entry "State section: no Instruction field" in [[ux/Motion, the interface answers]] and the line marked SETTLED in [[ideas]]); the stored note stays, read-only (see [[phases/DS3/report]]).
