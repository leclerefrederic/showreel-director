---
type: decision
status: current
phase: CL1
date: 2026-11-09
summary: "A new project's conversation language is read from the Mac and stored once with its origin, not asked as a question."
tags:
  - decision
---

# The conversation language comes from the Mac

**Decision.** The report title states it: "the conversation language comes from the Mac, not from a question". A new project's language is stored at creation, and `conversationLanguageSource` is a new optional key of showreel.json (older apps ignore it and keep it).

**Where it is recorded.** [[phases/CL1/report#Decisions and deviations]].

**What it affects.** [[phases/CL1/report]], [[ux/Project and wizard]].
