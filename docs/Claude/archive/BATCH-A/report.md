---
type: phase-report
status: current
phase: BATCH-A
date: 2026-11-09
summary: "Report of Batch A, which ran FIX1, CL1 and RL1 in a row, with the backup and each phase's result."
aliases:
  - "batchA-report"
prompt:
  - "[[archive/BATCH-A/prompt]]"
tags:
  - report
  - archive
---

# Batch A: FIX1, CL1 and RL1 in a row

**Backup (outside the repository):** `/Users/fleclere/Library/Application Support/ShowreelStudio/backups/batchA-20261109-2303` with `initial/` (before anything), `before-FIX1/`, `before-CL1/` and `before-RL1/` (app-swift without build folders, showreel-director, docs, tools, the top-level Markdown and JSON files). No phase had to be restored.

**Result: three phases DONE, versions 0.14.1 (FIX1), 0.15.0 (CL1), 0.16.0 (RL1). The skill was not changed (still 0.18.2).**

## FIX1: DONE (app 0.14.1)

- **What changed:** the form and the "Design package" footer of the project settings now share one stack inside the ScrollView (the footer used to overlay the form). A scan of every ScrollView of the app found no other case, and is now a test.
- **Deviations from the prompt:** none. The cause was confirmed as written.
- **Verified:** the complete `tools/verify.sh`; the cause and the fix by reading and by a source scan (`FIX1Tests`, 3 tests). **Not verified:** anything drawn (no screen).
- **To check by hand (from docs/Claude/phases/FIX1/report.md):** Open Project settings; scroll to the bottom of the Project tab and of the Look tab: "Design package" must sit under the last section with the same margins; the button must open the save sheet; nothing overlaps at a narrow pane width.

## CL1: DONE (app 0.15.0)

- **What changed:** a new project takes the Mac's language (first supported preferred language, English otherwise) and stores it once with its origin; the base configuration is four items ("n of 4 set"), the Wizard and Clap's interview lose one question, and the language stays editable under a collapsed "More" in the Project tab (journalled, with Undo); `addendum.md` and `capabilities.json` say so.
- **Deviations from the prompt:** none that change its intent. The skill was not changed (its portability table needed no change, so no skill release). A new optional key `conversationLanguageSource` in showreel.json holds the origin; a project made before keeps its value and shows "Kept from before".
- **Verified:** the complete `tools/verify.sh` (check.py green with capabilities and portability in agreement); `CL1Tests` (7) and the tests updated for four items. **Not verified:** anything drawn (no screen), and Clap's real behaviour (no paid call).
- **To check by hand (from docs/Claude/phases/CL1/report.md):** 1. Create a project on a Mac set to French, then to another language (even an unsupported one: English): the stored value (Project settings, More) and its origin "From your Mac".
2. The progress says "n of 4 set"; the Wizard has one step fewer; Clap's first message is in the right language.
3. Change the language under More: it is journalled and Undo (Edit menu) brings back the previous value and "From your Mac".
4. Write to Clap in a language that differs from the stored one: it should answer in yours.

## RL1: DONE (app 0.16.0)

- **What changed:** the rail has two groups (Film, Build | Inspector, Look, Project, Clap) and Clap shows its state (a pulse, a badge); one right panel at a time, independent of the centre, remembered per project; Shift-Command-A opens Clap with the cursor in its input; the shell is full height with the Film strip under the preview or at full width (`ShellLayout`), the dragged sizes stored apart from the placement, one reset icon at the right end of the top bar.
- **Deviations from the prompt and decisions:** the Inspector panel keeps a Files tab when Advanced is on (it had no home in the rail); the centre viewer still shows the design board while the Look panel is open (what Look contains); the reset is not undoable (the app has no interface undo, none was invented); the strip's toolbar has two rows when it is the width of the centre column. **Conflict between phase files:** CL1's collapsed "More" control sits in the Project tab, which RL1 now opens as a right panel; I kept the more conservative reading (CL1's control is in the Project form, wherever the Project panel shows). Nothing else conflicted.
- **Verified:** the complete `tools/verify.sh`; `RL1Tests` (19) and the updated DS1 and Memory tests. **Not verified:** anything drawn (no screen): the look and fit of every region, the strip at the centre column's width, the springs and the pulse, the keyboard and VoiceOver.
- **To check by hand (from docs/Claude/phases/RL1/report.md):** 1. The shell: the rail, the left panels and the right panel full height under the unchanged top bar; the preview with the Film strip under it in the centre column; the strip at its narrower width (two toolbar rows): Fit, zoom, ruler labels, grid and the transition diamonds still readable; the smallest window and the reset.
2. The strip is titled Film, the left list Storyboard.
3. The view group at the top right: one button whose pictogram shows the current layout (it changes on click, the tooltip names the state and the action); under the preview and full width (the panels move with the spring; Fit and the ruler read well in both; nothing is cut at each mode's smallest window); the choice survives a restart.
4. Drag the sizes you like (left and right widths, the Film height, the Storyboard and Resources divider), switch the placement and back: none moved. The reset icon puts the standard proportions back without changing the placement, and is disabled with its reason when they are standard.
5. The two groups and their separator; each right-panel entry sliding in with the bounce and a second click closing it; Film and Build switching without touching the right side.
6. Clap's pane: the conversation and the Memory, Sessions, Journal tabs; the pulse while Clap works; the badge with a waiting proposal and a click on it; Reduce motion on (System Settings, Accessibility, Display): a dot instead of the pulse.
7. Shift-Command-A from the strip and from the inspector.
8. Quit and reopen the project: the open panel is restored.
9. Select a scene while Clap or Look is open: the panel stays and the Inspector entry shows a dot.
10. Tab and the arrows on the rail; VoiceOver reading the entries with their state.

## The final checks of the batch

- Between phases, `tools/verify.sh --fast` was green before the next one started. At the end of each phase the complete `tools/verify.sh` was green, and once more at the end of the batch (VERIFY OK, the app self-test included).
- The whole suite (`swift test`): **704 tests, 1 skipped, 0 failures**. No flaky test was seen in this run (a few tests that wait on timers, for instance `BA2Tests` and `BG2ATests`, ran green each time).
- `tools/rebuild-app.sh` once, at the end: SELFTEST OK, BUNDLE OK (standalone), **REBUILT AND RUNNING, pid 19336** (confirmed with `pgrep`). The earlier app was closed by the rebuild, as expected.
- docs/Claude/phases-done.md and CLAUDE.md "Open work" updated for FIX1, CL1 and RL1 only; ROADMAP.md has a line for CL1 and RL1 (no limit was lifted by FIX1). DS2, DS3 and every other phase were not started.
- Total duration: about 23 minutes of work in this run, measured from the backup to the last test run.
