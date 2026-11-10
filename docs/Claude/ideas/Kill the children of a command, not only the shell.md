---
type: idea
status: draft
date: 2026-11-09
summary: "Kill the children of a command the app runs (process group), not only the shell, so a grandchild cannot outlive a cancelled test."
area: app
source: assistant
origin: "BA2"
id: IDEA-037
aliases:
  - "IDEA-037"
since: 2026-11-09
phase: ""
tags:
  - idea
  - app
---

# Kill the children of a command, not only the shell

2026-11-09 (BA2): kill the children of a command the app runs (process group), not only the shell; a grandchild that ignores SIGTERM can outlive a cancelled test.

Related: [[phases/BA2/report]].
