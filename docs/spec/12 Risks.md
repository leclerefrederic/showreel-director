---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "The risks of the project, such as skill and app drift, and how each is reduced."
tags:
  - spec
---

Part of [[studio-spec]].

# 12 Risks

- Skill and app drift: reduced by `capabilities.json`, `process.json` and `check.py`, but the method text itself is still written for a chat.
- The engine bridge (`EnginePreview`) is the least known part; it gets a spike at the start of phase C.
- The Swift code is written without a compiler on the Cowork side; Claude Code builds and runs it, as for the current app.
- Distribution constraints are unchanged (see `ROADMAP.md`).
