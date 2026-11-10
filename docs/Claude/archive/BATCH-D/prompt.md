---
type: phase-prompt
status: current
phase: BATCH-D
date: 2026-11-10
summary: "Runs SM1, PT1 and PL1 (fewer controls, project settings in tabs, palette checks), overriding the stop-after-each-phase rule."
report:
  - "[[archive/BATCH-D/report]]"
tags:
  - prompt
---
# Batch D: SM1, PT1 and PL1 in a row

The owner authorizes these three phases in one run and will test everything afterwards. This batch overrides, for this run only, the rule "stop after each phase for the owner to test" and the rule "tools/rebuild-app.sh at the end of each phase". Every other rule of CLAUDE.md stands (never run git, English interface, the skill is untouched unless a phase says otherwise, no certificate workaround, no `osascript`, no paid model call, scope discipline: an idea outside a phase goes in a note created with `python3 tools/docs_new.py idea`). The owner waived the open questions for this redesign: the defaults that exist today stand.

## The phases, in this order

1. **SM1**: docs/Claude/phases/SM1/prompt.md (remove the Film up to date dot and the Go given button, the Look rail entry, the Catalogue control of the top bar and the empty inspector's Project settings button).
2. **PT1**: docs/Claude/phases/PT1/prompt.md (the project settings in three tabs, Brief, Format and Look; no conversation language choice for Clap).
3. **PL1**: docs/Claude/phases/PL1/prompt.md (the Palette card's contrast checks sit under their swatches).

SM1 comes before PT1 (SM1 sends every former path to the Look panel to the Project panel's Look tab, which PT1 keeps). PL1 is independent. Read each phase file in full when you reach it and follow it exactly, with these changes for the batch: "Stop after the phase" means "go on to the next phase", and the final `tools/rebuild-app.sh` is done once, at the end of the batch (the complete `tools/verify.sh` is still run at the end of each phase). Each phase keeps its own step 0, tests, release notes before its own `bump_app.py`, and report (`docs/Claude/phases/SM1/report.md`, `docs/Claude/phases/PT1/report.md`, `docs/Claude/phases/PL1/report.md`).

## Safety

- Before anything else, make a backup outside the repository in `~/Library/Application Support/ShowreelStudio/backups/batchD-<date and time>/` of `app-swift` (without build folders), `showreel-director`, `docs`, `tools` and the top-level Markdown and JSON files, then a second copy in `before-<phase>/` before each phase. Say the path at the top of the batch report.
- A phase is done when its complete `tools/verify.sh` is green and its report is written. If a phase cannot be brought to green after a reasonable effort (say what you tried), restore the files from that phase's `before-<phase>/` copy, write its report as "NOT DONE" with the cause, and continue with the next phase. Never leave a phase half done and never restore more than the failed phase.
- Between phases run `tools/verify.sh --fast` and confirm the tree is green.
- If the phase files seem to conflict, keep the more conservative reading, do not ask, and note the decision in the batch report.
- No version is edited by hand; each phase bumps its own version in order, release notes first.

## At the end of the batch

1. Run the complete `tools/verify.sh` once more, then `tools/rebuild-app.sh` once. Confirm with `pgrep` and give the pid.
2. Update docs/Claude/phases-done.md (through `python3 tools/docs_index.py --write`) and CLAUDE.md "Open work" for the phases that were done (and only those).
3. Write `docs/Claude/archive/BATCH-D/report.md` (a note of type `phase-report`, see an earlier batch report for its properties) and add its link to the `report` property of this prompt: the backup path; for each phase DONE or NOT DONE, its version, two lines on what changed, deviations, what is verified and what is not (no screen), and its "To check by hand" list copied from its own report; the questions left for the owner (the Project buttons of the inspectors, the Look tab of a scene); the final checks run, the rebuild result and a total duration.
4. Stop. Do not start any other phase.

## Reminder of what each phase must not do

SM1: no change to the Build itself, the skill, the strip drawing or Clap. PT1: no change to fields, autosave or the Film languages. PL1: no change to the colours, the ratios or the thresholds.
