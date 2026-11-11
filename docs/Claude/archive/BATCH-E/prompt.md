---
type: phase-prompt
status: current
phase: BATCH-E
date: 2026-11-11
summary: "Runs RS1, SC1, LK1 and UR1 (Resources height, panel shortcuts, locked-scene look copy, Undo and Redo in the rail), overriding the stop-after-each-phase rule."
report:
  - "[[archive/BATCH-E/report]]"
tags:
  - prompt
---
# Batch E: RS1, SC1, LK1 and UR1 in a row

The owner authorizes these four phases in one run and will test everything afterwards. This batch overrides, for this run only, the rule "stop after each phase for the owner to test" and the rule "tools/rebuild-app.sh at the end of each phase". Every other rule of CLAUDE.md stands (never run git, English interface, the skill is untouched, no certificate workaround, no `osascript`, no paid model call, scope discipline: an idea outside a phase goes in a note created with `python3 tools/docs_new.py idea`). All questions are settled (DECISION-023 to DECISION-035): follow the decisions, do not reopen them.

## The phases, in this order

1. **RS1**: docs/Claude/phases/RS1/prompt.md (DECISION-023: the Resources section takes the height of the Film strip by default).
2. **SC1**: docs/Claude/phases/SC1/prompt.md (DECISION-027: shortcuts for the Inspector, Look and Project).
3. **LK1**: docs/Claude/phases/LK1/prompt.md (DECISION-028: locked scenes from before UI2 take a copy of their look when the project opens).
4. **UR1**: docs/Claude/phases/UR1/prompt.md (IDEA-052: Undo and Redo in the rail, with a history menu).

RS1, SC1 and LK1 are independent. UR1 comes last because it adds two rail buttons and a menu entry, after SC1's shortcuts are in place (the new buttons must not take a shortcut SC1 chose). Read each phase file in full when you reach it and follow it exactly, with these changes for the batch: "Stop after the phase" means "go on to the next phase", and the final `tools/rebuild-app.sh` is done once, at the end of the batch (the complete `tools/verify.sh` is still run at the end of each phase). Each phase keeps its own step 0, tests, release notes before its own `bump_app.py`, and report (`docs/Claude/phases/<ID>/report.md`).

## Safety

- Before anything else, make a backup outside the repository in `~/Library/Application Support/ShowreelStudio/backups/batchE-<date and time>/` of `app-swift` (without build folders), `showreel-director`, `docs`, `tools` and the top-level Markdown and JSON files, then a second copy in `before-<phase>/` before each phase. Say the path at the top of the batch report.
- A phase is done when its complete `tools/verify.sh` is green and its report is written. If a phase cannot be brought to green after a reasonable effort (say what you tried), restore the files from that phase's `before-<phase>/` copy, write its report as "NOT DONE" with the cause, and continue with the next phase. Never leave a phase half done and never restore more than the failed phase.
- Between phases run `tools/verify.sh --fast` and confirm the tree is green.
- If the phase files seem to conflict, keep the more conservative reading, do not ask, and note the decision in the batch report.
- No version is edited by hand; each phase bumps its own version in order, release notes first.
- Work only on copies of projects for the LK1 tests; never open or change the owner's own projects.

## At the end of the batch

1. Run the complete `tools/verify.sh` once more, then `tools/rebuild-app.sh` once. Confirm with `pgrep` and give the pid.
2. Update docs/Claude/phases-done.md (through `python3 tools/docs_index.py --write`) and CLAUDE.md "Open work" for the phases that were done (and only those); the "Open work" line for the next phases (PK2, N) stays.
3. Write `docs/Claude/archive/BATCH-E/report.md` (a note of type `phase-report`, see an earlier batch report for its properties) and add its link to the `report` property of this prompt: the backup path; for each phase DONE or NOT DONE, its version, two lines on what changed, deviations, what is verified and what is not (no screen), and its "To check by hand" list copied from its own report; the keys chosen by SC1; the final checks run, the rebuild result and a total duration. The end-of-phase report names the app version reached.
4. Stop. Do not start any other phase.

## Reminder of what each phase must not do

RS1: no change to the Resources tabs, the strip's size or a dragged divider. SC1: no new panel, no change to Clap's shortcut. LK1: no change to how a lock is taken or to DECISION-005. UR1: no persistent history panel, no change to what an entry records.
