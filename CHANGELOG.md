# Changelog

Version of the skill (`metadata.version` in `showreel-director/SKILL.md`). Semantic versioning while below 1.0: a minor number for new capabilities or changed behaviour, a patch number for fixes. The Studio file format has its own number (`schema` in `showreel.json`). Ship with `python3 tools/bump.py`.

## 0.14.0 - 2026-11-08

film format for the app's Build: film.json (the montage) inlined by build.py as SR.data.film, SRF.fromData, main.film.template.js, harness --scene, list of transitions that are previews only

## 0.13.0 - 2026-11-08

optional film layer: one render module per scene assembled by engine/film.js, scene transitions of the effects lab as a compositor (engine/transitions.js, generated), test film and pixel test; documented in references/engine.md

## 0.12.0 - 2026-11-08

portability: the storyboard is a film reel with transitions between scenes and the project's music grid (the skill itself is unchanged)

## 0.11.0 - 2026-11-08

Studio export writes each scene's words as its first content item (all attributes auto); portability: a content list per scene with fixed or auto attributes

## 0.10.1 - 2026-11-08

portability: the scene library is a tree per scene with node statuses, and a scene can override the project's background and look

## 0.10.0 - 2026-11-08

Studio export writes the scene library and one montage (scene durations, DITCH rows archived and off, handoff as the passage note); portability rows follow the app's editing workspace

## 0.9.2 - 2026-11-08

Portability table: two rows for the desktop app, one to write the storyboard, review each scene and give the go on screens (an explicit Go button), one to build the reel, test it and play it. Same fallbacks as the steps describe. No change to the method.

## 0.9.1 - 2026-11-08

Portability table: a row for picking the look (palette, fonts, background, effects mood) on screens in the desktop app, with the usual fallback to the look board, font picker, background picker and effects lab pages. No change to the method.

## 0.9.0 - 2026-11-09

First numbered version. Interview-led brief, feasibility gates, scene-by-scene review, self-contained HTML build, MP4 export, audio analysis, look board, font and background pickers, effects lab, asset organiser, reduced-motion support, portability fallbacks, and export of a project to Showreel Studio (`scripts/export_studio.py`).
