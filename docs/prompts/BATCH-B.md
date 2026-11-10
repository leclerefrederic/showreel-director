# SHELVED, DO NOT RUN: FIX3 was dropped (the owner prefers the current animated single button). Run docs/prompts/FIX2.md alone.

# Batch B: FIX2 and FIX3 in a row

The owner authorizes these two fixes in one run and will test them afterwards. This batch overrides, for this run only, the rule "stop after each phase for the owner to test" and the rule "tools/rebuild-app.sh at the end of each phase". Every other rule of CLAUDE.md stands (never run git, English interface, the skill is English only and style-neutral, no certificate workaround, no `osascript`, no paid model call, scope discipline: an idea outside a phase goes in docs/ideas.md in one line). The owner waived the open questions of docs/ideas.md for this redesign: the defaults that exist today stand.

## The phases, in this order

1. **FIX2**: docs/prompts/FIX2.md (selecting a scene in the Storyboard list must also move the preview).
2. **FIX3**: docs/prompts/FIX3.md (the layout toggle becomes two icons with a highlight that moves).

The two phases do not depend on each other. Read each phase file in full when you reach it and follow it exactly, with these changes for the batch: "Stop after the fix" means "go on to the next phase of this batch", and the final "tools/rebuild-app.sh" is done once, at the end of the batch (the complete `tools/verify.sh` is still run at the end of each phase). Each phase keeps its own tests, its own release notes before its own `bump_app.py`, and its own report (`docs/fix2-report.md`, `docs/fix3-report.md`).

## Safety

- Before anything else, make a backup outside the repository in `~/Library/Application Support/ShowreelStudio/backups/batchB-<date and time>/` of `app-swift` (without build folders), `showreel-director`, `docs`, `tools` and the top-level Markdown and JSON files, and a second copy of the same files in `before-<phase>/` before each phase. Say the path at the top of the batch report.
- A phase is done when its complete `tools/verify.sh` is green and its report is written. If a phase cannot be brought to green after a reasonable effort, restore the files from that phase's `before-<phase>/` copy, write its report as "NOT DONE" with the cause and what you restored, and continue with the next phase. Never leave a phase half done and never restore more than the failed phase.
- Between the phases run `tools/verify.sh --fast` and confirm the tree is green.
- If the two phase files conflict, keep the more conservative reading, do not ask, and note the decision in the batch report.
- No version is edited by hand; each phase bumps its own version in order, with its release notes written first.

## At the end of the batch

1. Run the complete `tools/verify.sh` once more, then `tools/rebuild-app.sh` once. Confirm with `pgrep` and give the pid.
2. Update docs/phases-done.md and CLAUDE.md "Open work" for the phases that were done (and only those).
3. Write `docs/batchB-report.md`: the backup path; for each phase DONE or NOT DONE, its version, two lines on what changed, deviations from its prompt, what is verified and what is not (no screen), and its "To check by hand" list copied from its report; then the final checks run (which `verify.sh`, how many tests, any flaky test), the rebuild result and a total duration.
4. Stop. Do not start DS3 or any other phase.

## Reminder of what each phase must not do

FIX2: no restyle, no change to the Build, no change to what a selection means beyond moving the playhead and the scroll. FIX3: no change to the reset icon's behaviour, to the stored sizes or to the placement logic; no new top bar controls.
