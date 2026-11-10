---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "The process contract: process.json lists the steps and gates the app implements, in the order of the skill's Gates table."
tags:
  - spec
---

Part of [[studio-spec]].

# 4 Process contract

`app-swift/shared/process.json` lists the steps and gates the app implements, in the order of the `Gates` table of `SKILL.md`:

```json
{ "steps": [
  { "id": "start",     "name": "Start",        "gate": "Round 0",       "produces": ["showreel.json"],        "screen": "NewProject" },
  { "id": "interview", "name": "Brief",        "gate": "Interview",     "produces": ["brief.md"],              "screen": "Brief" },
  { "id": "assets",    "name": "Assets",       "gate": "Assets",        "produces": ["assets/MANIFEST.csv"],   "screen": "Assets" },
  { "id": "style",     "name": "Look",         "gate": "Style sheet",   "produces": ["style-sheet.md"],        "screen": "Look" },
  { "id": "storyboard","name": "Storyboard",   "gate": "Storyboard",    "produces": ["storyboard.md"],         "screen": "Storyboard" },
  { "id": "review",    "name": "Scene review", "gate": "Scene review",  "produces": [],                        "screen": "SceneReview" },
  { "id": "build",     "name": "Build",        "gate": "Build",         "produces": ["vN/dist"],               "screen": "Build" },
  { "id": "verify",    "name": "Verify",       "gate": "Verify",        "produces": ["qa/"],                   "screen": "Verify" },
  { "id": "publish",   "name": "Deliver",      "gate": "Publish or share", "produces": ["exports"],            "screen": "Deliver" }
] }
```

`tools/check.py` fails when a gate named in the `Gates` table of `SKILL.md` has no step here, or the reverse, the same way it checks `capabilities.json`. A new capability, "The app drives the process with native screens", is added to `portability.md` and `capabilities.json`, so the skill knows that "pages the user operates" are screens in this mode.
