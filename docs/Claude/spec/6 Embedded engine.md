---
type: spec
status: current
phase: 
date: 2026-11-09
summary: "The embedded engine: the effects, backgrounds and player are JavaScript in showreel-director/engine/."
tags:
  - spec
---

Part of [[studio-spec]].

# 6 Embedded engine

The effects (248), backgrounds and the player are JavaScript in `showreel-director/engine/`. They are not rewritten in Swift. A reusable `EnginePreview` view (a `WKWebView` loading a small bundled host page that includes `core.js`, `kit.js`, `backgrounds.js` and the effect code) offers:

- `renderEffect(name, palette, font, t)` and `renderBackground(id, params, palette, t)` for animated thumbnails in the pickers;
- `renderScene(sceneId, t)` for scene cards and the look test;
- the reel player for Build and Verify.

Thumbnails are cached under `.studio/`. Native screens own lists, filters, selection and state; the engine only draws. The HTML picker generators (`build_*_picker.py`) stay in the skill for chat-only use.
