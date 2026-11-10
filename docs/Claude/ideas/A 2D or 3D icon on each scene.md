---
type: idea
status: draft
date: 2026-11-10
summary: "Show a 2D or 3D icon on each scene, read from a renderer field that assemble.py would record, with MP4 export refusals explained."
area: skill
source: owner
origin: "owner, 3D layer 0.18.0"
id: IDEA-032
aliases:
  - "IDEA-032"
since: 2026-11-10
phase: 
tags:
  - idea
  - skill
---

# A 2D or 3D icon on each scene

2026-11-10 (owner, 3D layer 0.18.0): a 2D or 3D icon on each scene in Studio (storyboard frame, scene tree and inspector). Proposed design: the kind of a scene is read from what exists, never typed: `assemble.py` would record `"renderer": "3d"|"2d"` per scene in `assembly.json` (3D when the scene file names `SR3D`, comments aside; the app already reads that file in `SceneModules.swift` and `FilmState.swift`), so the app needs no regex of its own; the icon says why in its help text (WebGL scene: weighs about 0.8 MB more, the Node harness cannot see it, no MP4 export through the Node exporter). With `Availability`: an MP4 export asked on a film that has a 3D scene says so, says why and offers the HTML player (never a silent disabled control). Skill side first (the field and a test), then the app phase.

Related: [[phases/3D1/report]].
