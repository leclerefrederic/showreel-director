---
type: decision
status: current
phase: 
date: 2026-11-11
summary: "The Resources section takes the height of the Film strip by default."
id: DECISION-023
aliases:
  - "DECISION-023"
since: 2026-11-11
affects:
  - "[[The left panel splits two thirds Storyboard and one third Resources]]"
tags:
  - decision
---

# The Resources section takes the height of the Film strip by default

**Decision.** By default the Resources section, at the bottom of the left panel, takes the same height as the Film strip, so the divider between Storyboard and Resources sits on the same line as the top of the Film strip. The Storyboard takes the rest. The divider stays draggable; the sizes the owner drags are never changed ([[The sizes the owner drags never change with the Film placement]]).

**Why.** The owner's answer to QUESTION-002 on 2026-11-11: "same height as the Film strip by default, so we don't have to think about it."

**Replaces.** The default of [[The left panel splits two thirds Storyboard and one third Resources]] (2/3 and 1/3). The 25 to 85 percent divider range is to be checked against the new default when it is built.

**Not built yet.** Needs a phase; it changes `LibrarySplit.standard`.
