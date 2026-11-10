---
type: phase-report
status: current
phase: BF2
date: 2026-11-09
summary: "Report of BF2: removes the limits on the agent during the prototype."
tags:
  - report
---
# BF2: no limits on the agent during the prototype

## The value

- `AgentLimits.modelMaxOutput = 128_000` (BuildStop.swift, the only place). Source: the code holds no per-model configuration (the model is free text in Settings, default `claude-sonnet-5-5`), so the value is the documented maximum output of that default model, 128K tokens, from the Claude API reference available in this session (the claude-api skill: "128K output tokens ... Claude Sonnet 5.5"; the Models API also reports it as `max_tokens`). It is the model's limit, not a product choice, and the comment says so. The transport streams, as the API requires for such values.
- `AgentLimits.loopGuardSteps = 1000`: a guard against a loop, not a product limit.
- A model that allows less: the 400 names its maximum ("max_tokens: 128000 > N ..."); `OutputCap.limit` reads N (only when below the value asked, never a guess), the transport asks again once with it and keeps it for the next requests. If it still fails, or the error names no value, the cause reads "API 400 (max_tokens asked: 128000): ...".

## What changed (app 0.9.3, the skill is untouched)

- Removed `AgentBudget` (standard 8000/60 and the adaptive Build budget), `BuildRunner.budget`, and the `budget` parameters of `Agent.send` and `ChatModel.ask`. The chat, the Build and "Generate" (same transport) use the one cap.
- Progress: `AgentUI.progress(turns:outputTokens:)`, fed by the transport (an estimate of 4 characters a token while an answer is written, the API's exact `output_tokens` at the end of each answer). `ProjectActivity.Build` carries `turns` and `outputTokens`; the Build panel (full and compact) shows "Step 7, about 12 400 output tokens" next to the scene and the time. Cancel build is unchanged.
- The BF1 messages stay; the cut-answer message now says "the maximum output of the model (N tokens)" and the guard says "loop guard (1000 steps)".
- `docs/ideas.md` and `ROADMAP.md` have their lines.

## Verified, not verified

- Verified: `tools/verify.sh --fast` and the complete one, then the rebuild. The BF1 tests were rewritten (12): the constants, no adaptive budget (the source holds no `AgentBudget`), the agent never changes the cap, the counter rises and never goes back, the loop guard after 1000 scripted steps, the message at the model's maximum, `OutputCap` on the documented error text, a stubbed API that refuses 128000 and accepts 64000 (asked twice, then kept), and an error with no value (not retried, value cited).
- Not verified: any real model call (no paid call), that the live API accepts 128 000 for the configured model, the exact wording of the API's error for another model (the parser also accepts a "maximum ... N" phrasing, but only the first form is documented), and the look of the counter (no screen).

## To check by hand

1. Start a Build and watch the line in the panel: "Step N, about X output tokens" must move while Clap writes.
2. If the API refuses the value, the chat says "API 400 (max_tokens asked: ...)"; tell me the text.

Recorded as a decision: [[decisions/No limits on the agent during the prototype]].
