---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "Screens, revision 1: the user works with the film, never with files."
aliases:
  - "5 Screens (revision 1 functional blocks, no files)"
  - "5. Screens (revision 1: functional blocks, no files)"
revision: 1
tags:
  - spec
---

Part of [[studio-spec]].

# 5 Screens

Principle: the user works with the film, never with files. Markdown, JSON and CSV are the assistant's working material. They stay in the project folder but are not shown in the interface, except in an "Advanced" panel (off by default) for debugging, and "Show in Finder".

Window per project. Left sidebar = the functional blocks, in the order of the process, each with a status (to do, in progress, validated):

| Block | What the user does | Stored in |
|---|---|---|
| **Project** | Name, audience, message, languages, formats, duration, tone, sound choice, constraints. Form with the interview's questions as help text, feasibility result shown inline. | `showreel.json` (`parameters`) |
| **Look and technique** | Palette (colour wells, contrast check), fonts (real specimens), background, motion mood, effects pack, music and beat grid. Native pickers with live thumbnails from the engine. | `showreel.json` (`decisions`) |
| **Resources** | All attached assets as a grid or list: drag and drop files in, status (approved, excluded, hold + note), licence note, which scenes use it, replace, remove. | `assets/` + `MANIFEST.csv` |
| **Storyboard** | The film as a timeline of scenes: add, reorder, split, ditch; text, timing, feeling; gate "Storyboard validated". | `showreel.json` (`scenes`) |
| **Scene editor** | One scene at a time: on-screen text, image/asset, motion, effects, timing, live preview, OK / MODIFY / DITCH with note. | `showreel.json` (`scenes`) |
| **Build and preview** | Build, issues from the checks, play the reel, stills. | `vN/` |
| **Deliver** | HTML, MP4, cuts, languages; release gate with resolve or waive and a note. | `exports/` |

The copilot is a panel on the right in every block. It sees the block in the foreground and the selection.

Library window unchanged: list of projects, new, open folder, duplicate as new version, archive.
