---
type: phase-report
status: current
phase: M
date: 2026-11-10
summary: "Phase M: project memory and history, with an append-only journal of every typed operation."
aliases:
  - "M"
phases: [M]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# M

phase M is built (project memory and history: `.studio/journal.jsonl` appends one line per typed operation, refusals, undos and redos included; `.studio/memory.json` is what Clap keeps through `remember`, `update_memory` and `forget`, checked by `MemoryRules` against personal data, identifiers and instructions; `.studio/sessions.json` holds a summary of each session; a project picked up again gives the model a data block built from these, `ProjectResume`; the History tab of the project settings shows them; the brief's Decisions log and Assumptions come from them; all three files are in the update backups)

Rules in ShowreelKit: `Journal.swift`, `Memory.swift`, `Sessions.swift`
