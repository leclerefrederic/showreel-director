# Eval results (first run, 2026-11-07)

Method: each of the 7 cases ran twice as a first turn only (the run could not receive user answers): once following `SKILL.md` ("skill") and once as a plain assistant with no skill instructions ("base"), on the same prompt and the same fixture files. Replies were shuffled into blind A/B pairs and judged criterion by criterion (PASS / FAIL / N/A for criteria that can only be judged in a later turn) by independent sub-agents using the `graders/*.md` files.

| Case | Skill | Base |
|---|---|---|
| capability-question | 5/5 | 1/4 |
| effects-list | 4/4 | 1/4 |
| express-mode | 6/6 | 1/6 |
| infeasible-brief | 5/5 | 4/5 |
| ploma-full-interview | 10/11 | 8/15 |
| scene-by-scene-review | 4/4 | 1/4 |
| vocabulary-lay-terms | 6/6 | 3/6 |
| **Total** | **40/41** | **19/44** |

Skill failure: `ploma-full-interview` / `08-excludes-photo-without-rights`: the skill flagged the photo without confirmed image rights but deferred the decision to the asset round instead of proposing to exclude it. Fixed in `SKILL.md` (a default is stated for every flagged asset).

Base held up best on `infeasible-brief` (a general assistant also pushes back on 30 shots in 10 seconds) and on filtering risky assets in the Ploma case.

Read these numbers with care:
- The criteria describe the skill's own intended behaviour, so a plain assistant is expected to score lower; the table shows that the skill produces that behaviour, not that it is better in every respect.
- One run per case and per variant, first turn only: later steps (brief writing, build, scene review loop, release gate) are not covered.
- The runner followed `SKILL.md` by reading it explicitly; real triggering by the skill description in a fresh conversation is not tested here.
- Graders are language models of the same family as the runner.
