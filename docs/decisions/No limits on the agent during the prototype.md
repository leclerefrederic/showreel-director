---
type: decision
status: current
phase: BF2
date: 2026-11-09
summary: "No budget or limit on the agent during the prototype: one cap, the model's maximum output, and a loop guard."
tags:
  - decision
---

# No limits on the agent during the prototype

**Decision.** The report title states it: "no limits on the agent during the prototype". "Removed `AgentBudget` (standard 8000/60 and the adaptive Build budget), `BuildRunner.budget`, and the `budget` parameters of `Agent.send` and `ChatModel.ask`. The chat, the Build and "Generate" (same transport) use the one cap."

**Where it is recorded.** [[phases/BF2/report]].

**What it affects.** [[ideas/A budget per Build before distributing the app]], which says the budget returns before the app is distributed.
