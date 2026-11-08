# Changelog

Version of the skill (`metadata.version` in `showreel-director/SKILL.md`). Semantic versioning while below 1.0: a minor number for new capabilities or changed behaviour, a patch number for fixes. The Studio file format has its own number (`schema` in `showreel.json`). Ship with `python3 tools/bump.py`.

## 0.9.2 - 2026-11-08

Portability table: two rows for the desktop app, one to write the storyboard, review each scene and give the go on screens (an explicit Go button), one to build the reel, test it and play it. Same fallbacks as the steps describe. No change to the method.

## 0.9.1 - 2026-11-08

Portability table: a row for picking the look (palette, fonts, background, effects mood) on screens in the desktop app, with the usual fallback to the look board, font picker, background picker and effects lab pages. No change to the method.

## 0.9.0 - 2026-11-09

First numbered version. Interview-led brief, feasibility gates, scene-by-scene review, self-contained HTML build, MP4 export, audio analysis, look board, font and background pickers, effects lab, asset organiser, reduced-motion support, portability fallbacks, and export of a project to Showreel Studio (`scripts/export_studio.py`).
