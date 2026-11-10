---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "Why Studio exists: today the chat is the centre, and the app turns the process into a workspace with a copilot."
tags:
  - spec
---

Part of [[studio-spec]].

# 1 Idea

Today the chat is the centre: the assistant follows `SKILL.md`, asks questions, opens HTML pages for the user to pick things, and writes the files. In v2 the app is the centre and the assistant is a copilot inside it.

- The project folder is the source of truth. The user sees and edits every file (brief, style sheet, storyboard, assets, build) from the app. The assistant edits the same files, when asked.
- Pickers, the look board, scene cards and decision sheets are screens of the app that write their choices into the project. No "copy your picks and paste them in the chat".
- The app holds several projects.
- The skill stays usable on its own in a chat (Cowork): nothing in the skill is removed. The app is a second way to drive the same method.
