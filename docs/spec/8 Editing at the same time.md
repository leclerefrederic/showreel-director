---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "Editing at the same time: a file watcher refreshes the open editors."
tags:
  - spec
---

Part of [[studio-spec]].

# 8 Editing at the same time

- A file watcher refreshes open editors. Every save, by the user or by the copilot, snapshots the previous content in `.studio/history/<file>/` (last 50), with diff and restore.
- A proposal records the file version it was based on; if the file changed since, the copilot regenerates it.
- The skill's own rules stay: the storyboard is archived before being rewritten, scene IDs never change, the explicit Go before the build.
