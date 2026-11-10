---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "The decisions to validate: canonical store, copilot edits, windows, the skill in chat and the order of the phases."
tags:
  - spec
---

Part of [[studio-spec]].

# 11 Decisions to validate

1. **Canonical store:** `showreel.json` for structured decisions plus markdown for prose (recommended), or markdown only with the app parsing it.
2. **Copilot edits:** proposals with accept or refuse by default (recommended), or direct writes.
3. **Windows:** one window per project (recommended), or one window with a project switcher.
4. **Skill in chat:** keep it fully usable alone in Cowork (recommended), which is why `process.json` and the capability contract exist.
5. **Order:** phases A to D as above, or start with the pickers (phase B and C items) before the library.

Recorded as decisions: [[decisions/The canonical store is showreel.json plus markdown prose]], [[decisions/Copilot edits are proposals the owner accepts or refuses]], [[decisions/One window per project]], [[decisions/The skill stays fully usable alone in Cowork]].
