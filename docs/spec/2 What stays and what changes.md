---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "A table of what stays (the skill, engine, scripts, outputs) and what changes (who drives, native pickers)."
tags:
  - spec
---

Part of [[studio-spec]].

# 2 What stays and what changes

| Stays | Changes |
|---|---|
| `showreel-director/` (method, engine, scripts, references) | Who drives: the app shows the steps and gates; the assistant proposes, drafts and builds on request |
| Reel output (HTML player, MP4, cuts) built by the existing scripts | Pickers and boards become native screens (SwiftUI) instead of generated HTML files |
| JavaScript effects and backgrounds engine as the renderer | The assistant's role in the system prompt: copilot, not interviewer |
| Agent loop, tools, Keychain, setup screen, self-test | Project model: several projects, structured decisions, per-project chat history |
