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

## Second run (after the process hardening of 2026-11-07)

Changes under test: interaction rule (questions or tools, never a text block to approve), gates table, decision sheets, look test, delegation clause, untrusted-content rule, existing-project route, cut-downs, early beat map, baked-in redaction, release-gate waivers, review build with notes pad.

Method: skill-only runs of all 7 original cases plus 3 new ones (`waive-gates`, `untrusted-brief`, `existing-project`), first turn only, judged by independent graders (not blind: no base comparison this time). First pass: 4 regressions and 1 criterion that no longer matched the design. Each was traced to a missing instruction, fixed in `SKILL.md`, and the affected cases were re-run. After the fix: express-mode 8/8, ploma-full-interview 10/10 (8 N/A), vocabulary-lay-terms 6/6, existing-project 4/4, scene-by-scene-review 4/5 then 5/5 once the criterion accepted the card sheet as the place where fields are shown. Cases untouched by the fixes (capability-question 5/5, effects-list 4/4, infeasible-brief 5/5, waive-gates 4/4, untrusted-brief 3/3) were not re-run.

The same caveats apply (one run, first turn only, model graders), and the last wording change to express mode (round 0 asked first and alone) was verified by `tools/check.py` only, not re-run.

## End-to-end simulation (2026-11-07)

An independent agent carried out a whole project with the skill (Ploma, 30 s, 16:9 and 9:16, French conversation, scripted user): round 0, folder and environment, interview, assets organiser with held files and a redacted screenshot, beat map, brief and style sheet on decision sheets, storyboard, scene cards with a MODIFY and a DITCH, look test, full build, harness, notes pad, release gate, delivery build, MP4 segment. It reported 31 issues, one blocker. Verdict: the process side (interview, gates, organiser, sheets, scene review, release gate) held up; the production side did not support image-based reels.

Fixed after the run (and covered by `tools/check.py` self-tests where possible):
- Blocker: `build.py` embedded only the track and fonts. Images are now declared under `images` in `project.json`, embedded, drawn with `SR.img(key)`, guarded against `assets/source` and excluded or held manifest entries, drawn by the MP4 exporter and stubbed by the harness; contact sheets wait for images.
- Notes pad: the stamp is refreshed on reopen, seek and pause, a note near a cut names both scenes, labels are translatable.
- Organiser: held files get ids in the plan; low-resolution, heavy and small-logo assets are held; excluding an asset removes its copy from `prepared/`; `--check` fails while anything is on hold.
- `duration` is documented and the embedded track is trimmed; scene cards read translated headers and comma decimals; decision sheets, scene cards and the lab accept `--ui` and `--lang`; the sheet's Copy button now refuses and outlines open cards instead of staying disabled; swatch labels keep their contrast.
- Effect names in the catalogue and packs now match the effects index (checked automatically); `export_mp4.js --stills` renders a PNG of chosen frames; the default export name uses a short `slug`; `check_env.py --node-path`; `analyze_audio.py` reports 1-based drop bars and marks an intro; `feasibility.py` reports per-scene time correctly.
- Documentation contradictions (the go message, summary in chat, look test folder, first reply language, approval of assets, reading speed) resolved.

Left as is: the manifest table from `--md` has fewer columns than the brief template; decision sheets embed one font file; the harness still cannot see text that overflows a panel inside the stage (use stills).
