---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "The copilot: the system prompt stays SKILL.md plus an addendum with a new section saying that the user drives."
tags:
  - spec
---

Part of [[studio-spec]].

# 7 The copilot

- The system prompt is still `SKILL.md` plus the addendum, with a new addendum section: "The user drives. The screens collect the interview answers, so do not ask what a screen already holds. On request: draft the storyboard or a style line, explain a choice, write `main.js`, fix issues from the harness, translate. Read `showreel.json` first."
- New tools: `get_state` (decisions, gates, step), `update_decision(key, value)`, `open_screen(step)`, `propose_edit(file, change)` and the existing file tools. A write to a file the user is editing, or to a prose file, becomes a proposal shown as a diff in the copilot panel (accept or refuse) unless the user switched on "apply directly" for the project.
- The copilot gets a short context message with every turn: current step, open gates, the file in the foreground.
- A selection can be sent to the copilot ("make this scene shorter", "write the file for this palette").
