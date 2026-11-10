---
type: phase-report
status: current
phase: BATCH-D
date: 2026-11-10
summary: "Report of Batch D, which ran SM1, PT1 and PL1 in a row: all three done, app 0.22.0 to 0.23.1, skill unchanged."
aliases:
  - "batchD-report"
prompt:
  - "[[archive/BATCH-D/prompt]]"
tags:
  - report
  - archive
---

# Batch D: SM1, PT1 and PL1 in a row

**Backup (outside the repository):** `/Users/fleclere/Library/Application Support/ShowreelStudio/backups/batchD-20261110-1849` with `start/`, `before-SM1/`, `before-PT1/` and `before-PL1/` (app-swift without build folders, showreel-director, docs, tools, the top-level Markdown files). No phase had to be restored.

**Result: three phases DONE.** SM1 0.22.0, PT1 0.23.0, PL1 0.23.1. The skill was not changed (0.18.2).

## SM1: DONE (0.22.0), [[phases/SM1/report|report]]

The Go is implicit: the Build is allowed when every visible scene is Ready and starting it records the Go in the file as the old button did; the Film status dot, the Go button and the Validate storyboard button are gone. Look left the rail (five entries) and is a tab of the Project panel, its tab stored and restored. The empty inspector lost its Project settings button. Deviations: Validate storyboard removed too (nothing left for it to unlock); the **Catalogue was kept**: it is a palette to drag looks, effects and transitions onto scenes, items and markers, so it offers an action.
To check by hand: the Film toolbar without the dot, the Go button and Validate; a project with a scene not Ready (Build disabled with its reason, naming the scene) then all Ready (a Build starts, and `showreel.json` has `gates.review: passed`); an older project that had the Go given or not; the rail with five entries; every way to the Look tab (a font link, "Change..." on a look, an old project that had the Look panel open) opening Project on Look; the top bar with the Catalogue and nothing else moved; the empty inspector without the button and a scene inspector's Project button still opening Project.

## PT1: DONE (0.23.0), [[phases/PT1/report|report]]

The project settings have three tabs, Brief (with the Control level), Format (formats, target duration, film languages) and Look, under the project name and a compact base configuration whose items go to their tab. The second tab is called "Format". The conversation language control (the "More" area) is removed; the value stays in the file and the Mac's language still reaches Clap. Minor version: the stored tab changes shape (an old Project tab is read as Brief). Deviation: the "Look: set, Open the Look" row of the old form is removed (the tab and the checklist replace it).
To check by hand: the panel with its three tabs (every field of the old form present once); the name and compact base configuration on every tab; a checklist item going to its tab; arrow keys between the tabs; the tab restored after relaunch; an older project opening on the right tab; the panel dragged wider and narrower; the Message field's text off its border; no conversation language anywhere; Clap answering in the Mac's language and in the language you write in.

## PL1: DONE (0.23.1), [[phases/PL1/report|report]]

Each contrast check of the design board's Palette card sits under the swatch it judges, from a pure column model in Kit (`DesignBoard.columns`, `spanning`); the Background column is empty. The palette editor and the Catalogue preview keep their own layouts (not swatch columns).
To check by hand: the Palette card at the default width and dragged wider and narrower (each check under its swatch, wrapping without overlap); a palette with a failing contrast (the warning stays in its own column); the palette editor and the Catalogue preview unchanged.

## Questions for the owner

- The Project button of the scene, transition, resource and look item inspectors is now the only link from an inspector to the Project panel besides the rail: do you still want it? (SM1)
- The Look tab of a scene's inspector: nothing was changed there; its "Change..." links open Project on Look. Keep as is? (SM1)
- The Catalogue does offer drag actions, so it stays: remove it anyway? (SM1)
- Decision taken between the phase files: the Validate storyboard button went with the Go (the prompt named the dot and the Go button only). Say if you want a validation step back.

## Final checks

The complete `tools/verify.sh` ran green at the end of each phase and once more after PL1 (`VERIFY OK`); `python3 tools/check.py` all passed; 863 tests in the Kit's test target; no flaky test seen. `tools/rebuild-app.sh` once at the end: `BUNDLE OK (standalone)`, **REBUILT AND RUNNING, pid 6802** (confirmed with `pgrep`). Nothing drawn, animated or felt was seen: there is no screen.
Total duration: about 23 minutes by the machine clock, from the first backup to the rebuild.
