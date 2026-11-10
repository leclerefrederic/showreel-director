---
type: phase-prompt
status: current
phase: BATCH-C
date: 2026-11-10
summary: "Runs FL1, FT1, MT1 and PF1 in one batch (film look, film and music toolbars, list-selection lag), overriding the stop-after-each-phase rule."
report:
  - "[[archive/BATCH-C/report]]"
tags:
  - prompt
---

# Batch C: FL1, FT1, MT1 and PF1 in a row

The owner authorizes these four phases in one run and will test everything afterwards. This batch overrides, for this run only, the rule "stop after each phase for the owner to test" and the rule "tools/rebuild-app.sh at the end of each phase". Every other rule of CLAUDE.md stands (never run git, English interface, the skill is untouched, no certificate workaround, no `osascript`, no paid model call, scope discipline: an idea outside a phase goes in a note created with `python3 tools/docs_new.py idea`). The owner waived the open questions for this redesign: the defaults that exist today stand.

## The phases, in this order

1. **FL1**: docs/Claude/phases/FL1/prompt.md (the scenes of the Film look like film: beat lines behind, centred thumbnails, a reel frame).
2. **FT1**: docs/Claude/phases/FT1/prompt.md (the Film toolbar: zoom at the far right, no Add scene, no Ripple).
3. **MT1**: docs/Claude/phases/MT1/prompt.md (the music lane toolbar: Beat, Bars, Sections, Drop, Analyse, track name and BPM; the Beat menu leaves the Film toolbar).
4. **PF1**: docs/Claude/phases/PF1/prompt.md (selecting a scene from the Storyboard list lags: measure, find the cause, fix it, no change of behaviour).

FT1 must come before MT1 (MT1 edits the Film toolbar that FT1 simplified). FL1 and PF1 are independent. Read each phase file in full when you reach it and follow it exactly, with these changes for the batch: "Stop after the phase" means "go on to the next phase of this batch", and the final `tools/rebuild-app.sh` is done once, at the end of the batch (the complete `tools/verify.sh` is still run at the end of each phase). Each phase keeps its own step 0, tests, release notes before its own `bump_app.py`, and report (`docs/Claude/phases/FL1/report.md`, `FT1/report.md`, `MT1/report.md`, `PF1/report.md`).

## Safety

- Before anything else, make a backup outside the repository in `~/Library/Application Support/ShowreelStudio/backups/batchC-<date and time>/` of `app-swift` (without build folders), `showreel-director`, `docs`, `tools` and the top-level Markdown and JSON files, then a second copy in `before-<phase>/` before each phase. Say the path at the top of the batch report.
- A phase is done when its complete `tools/verify.sh` is green and its report is written. If a phase cannot be brought to green after a reasonable effort (say what you tried), restore the files from that phase's `before-<phase>/` copy, write its report as "NOT DONE" with the cause, and continue with the next phase, except that MT1 is skipped if FT1 is NOT DONE (say so). Never leave a phase half done and never restore more than the failed phase.
- Between phases run `tools/verify.sh --fast` and confirm the tree is green.
- If two phase files seem to conflict, keep the more conservative reading, do not ask, and note the decision in the batch report.
- No version is edited by hand; each phase bumps its own version in order, release notes first.

## At the end of the batch

1. Run the complete `tools/verify.sh` once more, then `tools/rebuild-app.sh` once. Confirm with `pgrep` and give the pid.
2. Update docs/Claude/phases-done.md (through `python3 tools/docs_index.py --write`) and CLAUDE.md "Open work" for the phases that were done (and only those).
3. Write `docs/Claude/archive/BATCH-C/report.md` (a note of type `phase-report`, see an earlier batch report for its properties) and add its link to the `report` property of this prompt: the backup path; for each phase DONE or NOT DONE, its version, two lines on what changed, deviations, what is verified and what is not (no screen), and its "To check by hand" list copied from its own report; the questions left for the owner; the final checks run (which `verify.sh`, how many tests, any flaky test), the rebuild result and a total duration.
4. Stop. Do not start any other phase.

## Reminder of what each phase must not do

FL1: no new animation, no change to the toolbar or the Storyboard list. FT1: no change to the Beat menu, the grid and fit buttons, no loss of any way to add a scene. MT1: no new analysis, no change to the skill. PF1: no change to what a selection does, only its speed.
