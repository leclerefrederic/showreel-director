---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "The project folder layout, with showreel.json as the structured state and markdown for the prose."
tags:
  - spec
---

Part of [[studio-spec]].

# 3 Project model

```
<project>/
  showreel.json            structured state (section 3.1)
  brief.md  style-sheet.md  storyboard.md        prose, readable by humans and by the skill
  assets/  analysis/  v1/ v2/ ...  qa/  archive/  unchanged (see SKILL.md, Project layout)
  .studio/                 app-private: chat/<session>.jsonl, history/<file>/<timestamp>, ui.json
```
