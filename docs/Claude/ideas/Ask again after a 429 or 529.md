---
type: idea
status: superseded
date: 2026-11-09
summary: "Ask again after a short wait a request refused with 429 or 529, instead of stopping the Build."
area: app
source: assistant
origin: "BA2"
id: IDEA-036
aliases:
  - "IDEA-036"
since: 2026-11-09
outcome: built
outcome_link:
  - "[[phases/BG2/report]]"
phase: BG2
tags:
  - idea
  - app
---

# Ask again after a 429 or 529

2026-11-09 (BA2): ask again, after a short wait, a request that the API refused with 429 or 529 (overloaded); today the Build stops there and Continue resumes it.

Related: [[phases/BA2/report]], [[phases/BG2/report]].

Built: retry on 429 and 529, see [[phases/BG2/report]] (Part A).
