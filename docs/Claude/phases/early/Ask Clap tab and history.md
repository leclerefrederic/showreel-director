---
type: phase-report
status: current
phase: Q3
date: 2026-11-10
summary: "Phase Q3: the Clap tab titled Ask Clap, with one icon and a selector for Conversation, Memory, Sessions and Journal."
aliases:
  - "Q3"
phases: [Q3]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# Q3

phase Q3 is built (the Clap tab of the inspector is titled Ask Clap, with one icon, `ClapMark`; a selector at its top holds Conversation, Memory, Sessions and Journal, `ClapSection` and `ClapHistoryPane`, which are the history views of phase M moved out of the project settings; the project settings keep Project and Look; the words "copilot" are gone from the interface; the labels of the selector were later set in English by Q4)

Rules in ShowreelKit: none (views and `ProjectModel` only; the history rules stay in `Journal.swift`, `Memory.swift`, `Sessions.swift`)
