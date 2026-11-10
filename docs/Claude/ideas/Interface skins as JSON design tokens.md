---
type: idea
status: draft
date: 2026-11-10
summary: "Interface skins: a JSON file of design tokens loaded at run time, with bundled skins, a picker, import and export, a contrast gate and an icon map."
area: app
source: assistant
origin: "ideas.md"
id: IDEA-004
aliases:
  - "IDEA-004"
since: 2026-11-10
phase: 
tags:
  - idea
  - app
---

# Interface skins as JSON design tokens

2026-11-10: interface skins (phase SK1, after DS1 to DS3): a skin is a JSON file of design tokens (colours, radii, spacing, type scale) loaded at run time, never code; bundled skins (a dark default, a light one, a high-contrast one), a picker in Settings that applies at once, import and export of one skin file from `~/Library/Application Support/ShowreelStudio/Skins/`, a contrast gate that refuses or warns on a skin below the minimum ratios and falls back to the default. It needs the theme read through the environment (not static) and every view migrated to tokens first. A skin is the app's own look, not the film's palette and not a design package (.studiopack). Icons: SK1 carries an icon map only (a stable semantic role such as status.review or lock.closed mapped to an SF Symbol name, plus weight and size scale), validated at load (every symbol must exist, the six Status roles must stay distinct, the legend and the tooltips read the same map); custom icon artwork (a .studioskin zip with plain SVG or PDF template images, no scripts or external references, size limits, a hash like the packages) is a later phase (SK2).

Related: [[phases/DS1/report]], [[phases/DS3/report]], [[ideas/A light theme and skin loading]].
