---
type: phase-report
status: current
phase: OBS2
date: 2026-11-10
summary: "Report of OBS2: docs/ migrated into phase folders and atomic notes, with decisions, dashboards, a check script and a snapshot proof."
prompt:
  - "[[phases/OBS2/prompt]]"
spec:
  - "[[spec/1 Idea]]"
  - "[[spec/11 Decisions to validate]]"
ux:
  - "[[ux/Motion, the interface answers]]"
  - "[[ux/Scene content]]"
tags:
  - report
---

# OBS2: docs/ migrated into the vault (documentation only, no version)

Documentation and tooling only. The skill (0.18.2) and the app (0.19.2) are untouched; no version bump, no app rebuild. The owner's answers to the questions of [[phases/OBS1/report]] were: move everything, fix the drift, translate the titles of the overnight report, use `docs/archive/` for the batch and overnight reports.

## Target tree (applied)

```
docs/
  Home.md  Workflow.md  Conventions.md                 entry notes
  studio-spec.md  ux-notes.md  phases-done.md  ideas.md   hubs, same paths, same headings
  spec/            21 notes, one per section or subsection, the number kept in the title
  ux/              15 notes, one per block (and the one sub-block "Motion: the interface answers")
  phases/<ID>/     58 folders: prompt.md (18), report.md (24 moved, plus this one), summary.md (35, early phases)
  archive/         batch-report, batch2-report, batchA-report, overnight-report
  decisions/       14 notes        questions/   11 notes
  Phases.base  Decisions.base  Open questions.base  Architecture map.canvas
```

Changes from the OBS1 proposal: `BATCH-A` and `BATCH-B` are phases of their own (their prompt is in `phases/BATCH-A/`, `phases/BATCH-B/`); their reports are in `archive/` as the owner chose. No `Ideas.base` (see the questions). The batch reports stay whole.

## What moved (plain file operations, no git)

46 files: every `docs/prompts/<ID>.md` to `docs/phases/<ID>/prompt.md`, every `docs/<id>-report.md` to `docs/phases/<ID>/report.md` (`3d1` to `3D1`, `bg1c` to `BG1c`, `bg1d` to `BG1d`, `ds3b` to `DS3b`, and so on), and `batch-report`, `batch2-report`, `batchA-report`, `overnight-report` to `docs/archive/`. `docs/prompts/` no longer exists. The list is `moved.json` in `~/Library/Application Support/ShowreelStudio/docs-migration/`. Each moved note got properties (`type`, `status`, `phase`, `date`, and `app_version` and `skill_version` when the title names them). The dates are the files' last-modified days (there is no git history to read): a few may be a day late.

## Links rewritten

92 references to the old locations, in 24 files: the prompts and reports themselves (most in `phases/OBS1/report.md` 17, `BATCH-A` 7, `BATCH-B` 6, `BG2` 6), `phases-done.md` 5, and `CLAUDE.md` (the RB1 report path). `README.md`, `ROADMAP.md`, `.claude/**` named no moved path. Past prompts keep their text as history: only paths and links changed (and one quoted heading, see the drift fixes). `Home.md`, `Workflow.md` and `Conventions.md` were rewritten for the new tree.

## Notes created by splitting

- `studio-spec.md` to `spec/`: sections 1 to 12 and the subsections 3.1, 5.1 to 5.6 (5.1b among them), 6.1. The hub keeps the title, the status paragraph and every heading (`## 5. Screens ...`, `### 5.6 Design packages ...`), each followed by the link to its note, so "section 5.6" still finds its heading.
- `ux-notes.md` to `ux/`: the 14 blocks and the sub-block "Motion: the interface answers". The hub keeps the block names. The entries named by the prompts ("Rail", "Forms (owner, after DS1)", and so on) are bullets inside their block note: they are found by searching, not by a heading.
- `phases-done.md` to `phases/<ID>/summary.md`: 35 summaries (the heading with several IDs, such as "A, A2, A3, B and T" and "P2 and P3", became one note in the first ID's folder). The hub is now one table of every phase (63 rows: the early phases, then the later ones by date) with links to the summary, the prompt and the report.
- Each split note has properties, "Part of" and the link to its hub, and a line "Phases named in this note" with wikilinks to the phases it names (computed from the text, nothing added to the content).

## Decisions extracted (14, only what the text states)

Four from spec section 11 (the owner validated the recommended choice of each on 2026-11-08): the canonical store, copilot edits as proposals, one window per project, the skill usable alone in Cowork. Two from UI1 (Checks as a badge, the two-thirds split), three from UI2 (the instruction field, which is marked superseded by DS3; `retiredIDs`; a locked scene's own transition stays editable), one from CL1 (the conversation language comes from the Mac), one from the ux notes (keep the Project button in the inspector header), two from the RL1 notes (Clap is a rail entry; dragged sizes never change with the placement), and the waiver of the open questions during the redesign. Each links to its source, and the source links back.

## Questions as notes (11)

The 7 lines of the section "Questions to settle with the owner" of [[ideas]] and the 4 questions of [[phases/RB1/report]] are now notes with `type: question`. The RB1 questions were added to the section of `ideas.md` too, since the owner's assistant reads that section before every prompt. The Instruction question is marked settled (`status: superseded`).

## Dashboards and map

`Phases.base` (reports and summaries, prompts, newest first), `Decisions.base` (all, and superseded), `Open questions.base` (open, and settled), all linked from [[Home]]. `Architecture map.canvas`: the notes of the vault, the repository, the skill, ShowreelKit, ShowreelStudio and the tests, 15 nodes and 17 edges, small by design.

## The check

`tools/check_docs.py` (stdlib only), run by `tools/check.py` through a four-line hook, and `python3 tools/check_docs.py --selftest` (builds a broken tree and asserts every kind of problem is caught and nothing else). It checks: the paths named in `CLAUDE.md` and in `Workflow.md` exist; every wikilink, heading link and relative link resolves; every note has `type`, `status`, `phase`, `date`, `tags` with allowed values; the section numbers that `app-swift/**` comments quote exist as headings of `studio-spec.md`; the section "Questions to settle with the owner" exists; no key or token pattern. Result: `check_docs: ok` on the whole vault. Limit: names such as "Scene content" in code comments are not checked (the comment at `ShowreelFile.swift:140` names the wrong file; the owner's question 5 of OBS1 is still open). `ideas.md` got properties so that the rule holds for every note.

## Drift fixed (as the owner allowed)

1. One phase list: the table in `phases-done.md`; `CLAUDE.md` "Open work" points to it instead of repeating 47 IDs, and `spec/10 Phases (revision 1)` says it is the original plan and links to the table.
2. `ROADMAP.md` line 6: DS3 and DS3b are built, the rail is in two groups (one sentence each corrected).
3. The contradiction about Reset: the note now says the reset icon keeps the placement (it restores the sizes only).
4. Two marks of history: the DS1 four-entry rail is marked as the mockup; the Project button question is marked settled in DS3.
5. `phases/DS3b/prompt.md` quotes the heading "Not done" (it said "Pas fait").
6. The four French titles of `archive/overnight-report.md` are in English (the body is untouched).

Not fixed: the missing reports `batchB-report` and `fix3-report` (those phases may not have run; their prompts name `phases/BATCH-B/report.md` and `phases/FIX3/report.md` now).

## Proof that nothing was lost

`snapshot.py` and `compare.py` live in `~/Library/Application Support/ShowreelStudio/docs-migration/` (outside the repo); the snapshot of `docs/` before the migration is `before.json`, with a full copy in `docs-before/`. The snapshot records the normalised paragraphs of every file (properties excluded) with their count. After the migration, the old paths were mapped through the same rewrite, and: **1013 paragraphs before; 955 appear exactly once in the new tree; 58 differ, all intentional, none unexplained.**

| Differences | Reason |
|---|---|
| 35 | the section headings of `phases-done.md` (and the three FIX1, CL1 and RL1 sections, whose body is present as its own paragraph, checked) became a note title and a row of the table |
| 8 | `Home.md` rewritten for the new tree |
| 4 + 2 | `Conventions.md` and `Workflow.md` updated for the new tree |
| 4 | the overnight report's French titles translated |
| 3 | `ux` drift fixes (Reset, Project button, DS1 rail) |
| 1 | `ideas.md`: the paragraph of questions gained the four RB1 lines |
| 1 | the DS3b prompt: "Pas fait" to "Not done" |

Files that no longer exist at their old path: the 18 files of `docs/prompts/`, the 24 `docs/<id>-report.md`, and the four batch and overnight reports (46 in all, listed above with their new path). `studio-spec.md`, `ux-notes.md` and `phases-done.md` exist, as hubs; their text is in `spec/`, `ux/` and `phases/<ID>/summary.md`.

## Questions for the owner

1. **Ideas.** The ideas stay lines of `ideas.md` (46 dated one-line entries (questions included) with a date and a tag, none with its own properties); turning them into notes would add files without adding reading value. Do you want an `Ideas.base`, which needs one note per idea?
2. **Spec section 11, point 5** (the order of the phases) is not a decision note: its text names no recommended choice, so I did not invent one. Tell me which choice you validated and I will add it.
3. **The ux notes are split by block**, not by entry: an entry such as "Forms (owner, after DS1)" is a bullet of its block note. Splitting entries needs a judgement on each, so I did not do it. Do you want it?
4. **Dates** of the moved prompts and reports are last-modified days, not git dates.
5. The comment at `ShowreelFile.swift:140` still names the wrong file for "Scene content" (the question remains for the next app phase).

## Verified, not verified

Verified: `python3 tools/check_docs.py` and its `--selftest`; the paragraph snapshot (above); the YAML of the three `.base` files and of the properties of all 149 notes, and the JSON of the canvas, parsed with Ruby's YAML and JSON (the stdlib of Python has no YAML); `tools/check.py` and the verification run are in the last message.
Not verified (no screen): that Obsidian renders the properties, the callouts, the Bases and the canvas, that the `sort:` key of the Bases works as I wrote it (the Bases skill documents groups and filters, not sorting), that the filters of the dashboards select what I mean, and that the wikilinks open the right note (the check resolves them by name and heading, which is not the same as clicking them).

## To check by hand

1. Open `docs/` in Obsidian. Click through [[Home]], each dashboard (the three `.base` files) and the canvas.
2. Open `docs/studio-spec.md` and `docs/ux-notes.md` and follow three links each.
3. Search for a phrase you remember from the old files (the search finds it in the notes).
4. In GitHub Desktop confirm that the moves show as moves and that no `docs/.obsidian/` file is listed.
