---
type: decision
status: current
phase: UI2
date: 2026-11-09
summary: "IDs of deleted scenes are kept in the optional retiredIDs key of showreel.json, which older apps ignore and keep."
tags:
  - decision
---

# Deleted scene IDs are kept in retiredIDs

**Decision.** "IDs of deleted scenes are kept in a new optional `retiredIDs` key of showreel.json (older apps ignore it and keep it)."

**Where it is recorded.** [[phases/UI2/report#Decisions taken]].

**What it affects.** [[phases/UI2/report]], [[spec/3.1 The showreel.json schema]].
