---
type: decision
status: current
phase: UI2
date: 2026-11-09
summary: "A locked scene's own transition stays editable; a change touching the locked scene's own edges is refused."
tags:
  - decision
---

# A locked scene's own transition stays editable

**Decision.** "A locked scene's own transition stays editable (not in the list of refusals)." A change that trades time between two neighbours without moving a locked scene's start is allowed; the one that touches the locked scene's own edges is refused. Whether a lock should also freeze the transitions on both sides is an open question in [[ideas]].

**Where it is recorded.** [[phases/UI2/report#Decisions taken]].

**What it affects.** [[phases/UI2/report]].
