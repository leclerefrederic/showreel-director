# Changelog of the app

Version of the Showreel Studio app (`app-swift/shared/app-version.json`). Semantic versioning while below 1.0: a minor number for new capabilities or changed behaviour, a patch number for fixes. The skill and the project file format have their own numbers. Ship with `python3 tools/bump_app.py`, after writing the section of the new version in `RELEASE-NOTES-APP.md`.

## 0.19.2 - 2026-11-10

RB1: one rule for the rail's buttons (centre views never toggle off, Clap always opens when asked, same states and tooltips, arrows inside a group)

## 0.19.1 - 2026-11-10

DS3b: one text field style, growing multi-line fields, stepper arrow keys, buttons by role

## 0.19.0 - 2026-11-10

DS3: form system, real tabs, stepper, State section simplified, no scene Duplicate, no Effects tab, wider panes, inspector and forms on the tokens

## 0.18.0 - 2026-11-10

AS1: no Save button, scene fields, palette, content items and transitions autosave, one undo step per field per 2 s

## 0.17.1 - 2026-11-10

FIX2: a click on a scene in the list, a chip or a check moves the preview like the strip

## 0.17.0 - 2026-11-09

DS2: the Film strip and the Storyboard list on the tokens, the strip decluttered (thumbnails clipped, header and footer bands), a motion language as tokens

## 0.16.0 - 2026-11-09

RL1: two rail groups, Clap in the rail, one right panel at a time, full-height shell, Film placement

## 0.15.0 - 2026-11-09

CL1: the conversation language comes from the Mac, no longer a question (base configuration: 4 items)

## 0.14.1 - 2026-11-09

FIX1: the Design package footer sits under the project settings form

## 0.14.0 - 2026-11-09

DS1: design tokens, dark theme, view rail and rounded panels, no text under 11 pt

## 0.13.0 - 2026-11-09

UI2: one Status icon, Visible/Ready/Locked switches, Delete scene, a real lock with a look copy

## 0.12.0 - 2026-11-09

UI1: left panel = flat Storyboard + Resources below, state icons, scene overview in the inspector, Checks badge

## 0.11.0 - 2026-11-09

BG2: 429/529 retries with waits, scenes written at the same time (1 to 4), width lowered on rate limits, time estimate from measured speed

## 0.10.3 - 2026-11-09

BA2: every request bounded (no-content rule, longest request), cut requests asked again, build log, one rule for tested, true reasons, empty version folders removed, cancel fixes

## 0.10.2 - 2026-11-09

BG1d: a Build writes only the scenes that changed, the others are taken over from the version before

## 0.10.1 - 2026-11-09

BG1c: each scene tested right after it is written, repaired once on a code error, layout warnings listed and fixable

## 0.10.0 - 2026-11-09

BG1: the Build writes the scenes one by one with visible states, idle timeout, continue after a stop

## 0.9.3 - 2026-11-09

BF2: no limit on the agent during the prototype (model maximum output, loop guard, live counter)

## 0.9.2 - 2026-11-09

BF1: a Build that stops says why, gets more room for long films, and offers a way on

## 0.9.1 - 2026-11-09

3D scenes step in the Build, 3D words for Clap and the capabilities

## 0.9.0 - 2026-11-09

timeline beat markers, Transitions tab

## 0.8.5 - 2026-11-09

fonts download from Google Fonts, no GitHub API

## 0.8.4 - 2026-11-09

resource drag crash fix

## 0.8.3 - 2026-11-09

resource drag starts, add to scene menu

## 0.8.2 - 2026-11-09

resource drag to scenes fix and drag log

## 0.8.1 - 2026-11-09

test session fixes

## 0.8.0 - 2026-11-09

design packages: save and start from a package

## 0.7.0 - 2026-11-09

resource details and preview player fix

## 0.6.0 - 2026-11-09

Resources tab: groups, preview, tags, four states, automatic checks and Needs attention

## 0.5.1 - 2026-11-09

New project screen moved to its own file

## 0.5.0 - 2026-11-09

project creation: Wizard or Manual chosen once, Clap leads the interview and proposes a starting pack, the project form in sections, the interview gate derived

## 0.4.1 - 2026-11-09

tools.json: hand-edit sentence for generate_scenes

## 0.4.0 - 2026-11-09

marks on every surface, one badge layout, Generate offers stale scenes, disabled controls say why

## 0.3.0 - 2026-11-09

fonts in the film: states, the Add font files card, embedding in the build and the assembly

## 0.2.0 - 2026-11-09

release notes, the app version in one place, the Q-phases and the film state

## 0.1.0 - 2026-11-09

First numbered version of the app: the base before release notes (phases A to M, see docs/phases-done.md).
