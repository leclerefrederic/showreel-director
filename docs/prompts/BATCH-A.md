# Batch A: FIX1, CL1 and RL1 in a row

The owner authorizes these three phases in one run and will test everything afterwards. This batch overrides, for this run only, the rule "stop after each phase for the owner to test" and the rule "tools/rebuild-app.sh at the end of each phase". Every other rule of CLAUDE.md stands (never run git, English interface, the skill is English only and style-neutral, no certificate workaround, no `osascript`, no paid model call, scope discipline: an idea outside a phase goes in docs/ideas.md in one line). The owner waived the open questions of docs/ideas.md for this redesign: the defaults that exist today stand.

## The phases, in this order

1. **FIX1**: docs/prompts/FIX1.md (the "Design package" footer floats over the project settings form).
2. **CL1**: docs/prompts/CL1.md (the conversation language comes from the Mac, not from a question).
3. **RL1**: docs/prompts/RL1.md (the rail gets two groups, Clap becomes one of its entries).

The phases do not depend on each other. Read each phase file in full when you reach it, and follow it exactly, with these changes for the batch: "Stop after the phase" means "go on to the next phase of this batch", and the final step "tools/rebuild-app.sh" is done once, at the end of the batch (the phase's complete `tools/verify.sh` is still run at the end of each phase). Each phase keeps its own step 0, its own tests, its own release notes before its own `bump_app.py` (and `bump.py` if the skill changed), and its own report (`docs/fix1-report.md`, `docs/cl1-report.md`, `docs/rl1-report.md`).

## Safety

- Before anything else, make a backup outside the repository, in `~/Library/Application Support/ShowreelStudio/backups/batchA-<date and time>/`, of `app-swift` (without build folders), `showreel-director`, `docs`, `tools`, and the top-level Markdown and JSON files. Then, before each phase, a second copy of the same files in `before-<phase>/` inside that folder. Say the path at the top of the batch report.
- A phase is done when its complete `tools/verify.sh` is green and its report is written. If a phase cannot be brought to green after a reasonable effort (say what you tried), restore the files from that phase's `before-<phase>/` copy, write its report as "NOT DONE" with the cause and what you restored, and continue with the next phase (they are independent). Never leave a phase half done, and never restore more than the failed phase.
- Between phases run `tools/verify.sh --fast` and confirm the tree is green before starting the next one.
- If two phase files seem to conflict (for example CL1's collapsed control and RL1's Project panel), keep the more conservative reading, do not ask, and note the decision in the batch report.
- No version is edited by hand. Each phase bumps its own version in order (so the versions advance FIX1, then CL1, then RL1), each with its release notes written first.

## At the end of the batch

1. Run the complete `tools/verify.sh` once more, then `tools/rebuild-app.sh` once. Confirm with `pgrep` that the new app runs and give its pid. The earlier app is closed by the rebuild, which is expected.
2. Update docs/phases-done.md and CLAUDE.md "Open work" for the phases that were done (and only those), and ROADMAP.md if a limit was lifted.
3. Write `docs/batchA-report.md`: the backup path; for each phase DONE or NOT DONE, its version(s), two lines on what changed, deviations from its prompt, what is verified and what is not (no screen: nothing drawn is verified, say so plainly), and its "To check by hand" list copied from its own report; then the final checks run (which `verify.sh`, how many tests, any flaky test), the rebuild result, and a total duration.
4. Stop. Do not start DS2, DS3 or any other phase.

## Reminder of what each phase must not do

FIX1: no restyle, no behaviour change. CL1: no change to the skill's method, no change to the film's languages, formats, duration or look, no new setting beyond the collapsed control. RL1: no change to what the Inspector, Look, Project or Clap contain, no new motion tokens, no drawer for Clap beside the Inspector.
