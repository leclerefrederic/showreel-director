---
type: phase-report
status: current
phase: OBS3
date: 2026-11-10
summary: "Report of OBS3: ideas as notes, a summary on every note, a generated agent index and generated blocks, with the step 0 lists and the proof."
prompt:
  - "[[phases/OBS3/prompt]]"
spec:
  - "[[spec/5.6 Design packages]]"
tags:
  - report
---

# OBS3: one note, two readers (documentation and docs tooling only, no version)

Documentation and the docs tooling only. The skill (0.18.2) and the app (0.19.2) are untouched, their code and comments too; no version bump, no app rebuild.

## Step 0

### The 45 ideas of `ideas.md`

Dates are the bullet's own; 10 bullets carry none (marked `?`): they got 2026-11-09, the oldest date in the file, and `source: assistant`; this is an assumption. `source: owner` only where the bullet says "(owner". Built or promoted means there is explicit evidence in a report, the spec or the code.

| # | Idea (note title) | Date | Source | Area | Status |
|---|---|---|---|---|---|
| 1 | An icon per transition family | 2026-11-10 | owner | app | parked |
| 2 | Two pictogram icons as the layout toggle | 2026-11-10 | assistant | app | parked (shelved as FIX3) |
| 3 | Show and hide controls for the side panels in the view group | 2026-11-10 | assistant | app | parked, looks the same as 43 |
| 4 | Interface skins as JSON design tokens | 2026-11-10 | assistant | app | parked |
| 5 | Voice mode for the copilot | 2026-11-10 | assistant | app | parked |
| 6 | A debug build mode for rebuild-app.sh | 2026-11-10 | assistant | tooling | parked (`--debug` is not in the script) |
| 7 to 11 | scroll while dragging; font drag; shape items; six transitions; off-screen resolution | 2026-11-10 | assistant | app (7 to 9), skill (10, 11) | parked |
| 12 | Write the montage as film.json for the build | 2026-11-10 | assistant | app | **built** (`Film.write`, BA1 report) |
| 13 | Build without the AI when a scene's content is fixed | 2026-11-09 | assistant | app | parked |
| 14, 15 | Interface language; several montages | 2026-11-09 | assistant | app | parked |
| 16 | One module file per scene with a deterministic assembler | 2026-11-09 | assistant | skill | **built** (BG1, BG1c) |
| 17 to 23 | locked-scene look pin; action/reaction later; film state later; toolbar toggle reason; language, voice and starting pack; Resources work; GPS check | ? | assistant | app | parked |
| 24 | Design System Manager, reusable packages | 2026-11-10 | owner | app | **promoted** (spec 5.6, PK1 to PK4) |
| 25 | Decisions on the Design System Manager | 2026-11-10 | owner | app | recorded as four decision notes |
| 26 | Design System Manager promoted to spec section 5.6 | 2026-11-10 | assistant | docs | done |
| 27 | Package tone instructions, default transition and drop on a project window | 2026-11-09 | assistant | app | parked |
| 28 | Music cover thumbnails, free font file names and a GitHub token for fonts | 2026-11-09 | assistant | app | parked, **half looks built** (F2 downloads without the GitHub API) |
| 29 | Rework creating a project for the Wizard and for Manual | 2026-11-10 | owner | app | parked (P5 built part of it) |
| 30, 31 | Typed drops; a drop target on the inspector | 2026-11-09 | assistant | app | parked, **may be built** (D1, D2, W5) |
| 32 | A 2D or 3D icon on each scene | 2026-11-10 | owner | skill | parked |
| 33 | A budget per Build before distributing the app | ? | assistant | app | parked (text in French) |
| 34 | Write independent scenes in parallel | ? | assistant | app | **built** (BG2 Part B) |
| 35 | Test scenes in parallel | ? | assistant | app | parked |
| 36 | Ask again after a 429 or 529 | 2026-11-09 | assistant | app | **built** (BG2 Part A) |
| 37 | Kill the children of a command, not only the shell | 2026-11-09 | assistant | app | parked (not found in the BA2 report) |
| 38 to 41 | one-scene preview; thin status row; free gap; drop ditched and archived | 2026-11-09 | assistant | app | parked |
| 42 to 45 | light theme and skins; show and hide controls (again); Clap drawer; sliding highlight | 2026-11-10 | assistant | app | parked |

Seven ideas are `superseded` (12, 16, 24, 25, 26, 34, 36), with a link to where they went. The rest are `draft`; none is `current` (the owner has not said that any is wanted soon).

### Open questions against the notes

The section had 11 lines and `docs/questions/` has 11 notes: one to one. No line without a note, no note without a line. One is settled (the Instruction field, removed in DS3, `status: superseded`); 10 are open.

### The vault before OBS3

151 notes: 151 without `summary`, 1 without `type` and `status` (the OBS3 prompt itself, which got its properties).

## The properties chosen and why

Each is one a dashboard shows or filters on, or the index carries.

| Property | Why |
|---|---|
| `summary` (every note, at most 160 characters) | Bases shows it, the index carries it, `grep '^summary:'` triages without opening a note |
| `area` (idea notes: app, skill, docs, tooling) | the "By area" view of `Ideas.base` |
| `source` (owner or assistant) | filter of who asked |
| `origin` (idea notes) | where the idea came from (the bullet's own tag, or "ideas.md") |
| `status` on an idea | draft is parked, current is wanted soon, superseded is built or promoted, with a link |

## What was built

- **45 idea notes** in `docs/ideas/`, each with the bullet's text word for word under its title, the properties above, a "Related" line and, for the built or promoted ones, a line saying where it went. The summary is in the properties, not repeated in the body (one fact in one place).
- **4 decision notes** for the owner's decisions (1) to (4) on packages (OBS2 had not extracted them), linked from the idea note that holds them.
- **A `summary` on every note** (200 when the index was first written), written by hand from each note's content (phase prompts and reports: one line on what the phase asked or did); added to the properties table of `Conventions.md`. The two shelved prompts (`FIX3`, `BATCH-B`) are now `status: superseded`.
- **`tools/docs_index.py`** (stdlib only, `--write`, `--check`, `--selftest`): builds `docs/Index.md` (250 lines: status block, entry notes, spec, ux, decisions, questions, ideas, archive, and one line per phase folder) and three generated blocks: `where-we-are` in `Home.md` (versions read from `app-swift/shared/app-version.json` and `SKILL.md`, the last built phase and the next ones read from `CLAUDE.md` "Open work"), and `questions` and `ideas` in `ideas.md`. Deterministic: a second `--write` printed "nothing to change".
- **`docs/Ideas.base`** (all ideas newest first, by area, wanted soon); `Phases.base`, `Open questions.base` and `Decisions.base` show `summary` too. Linked from `Home.md`.
- **`Home.md`**: the "Where we are" block is generated; the Ideas dashboard and a "For agents" line about `Index.md` were added.
- **`ideas.md`**: the questions section first, with its heading unchanged, a short rule and a generated list (title, phase, date, one line, link); the "Ideas" section with its intro reworded for the new rule, the generated list and the dashboard; nothing hand-written in a generated block.
- **`tools/check_docs.py`** (and its selftest): every note has `type`, `status` and a `summary` within the limit; idea notes have `area`, `source` and `origin`; the questions section exists and comes first; `docs_index.py --check` passes (so a hand edit inside a generated block or `Index.md` is caught). `tools/check.py` runs it as before.

## Rule changes

- `CLAUDE.md:41` and `:42` (Layout: `docs/Index.md`, `docs/ideas/`, `docs_index.py`); `CLAUDE.md:51` to `:62` (the section "Documentation vault": reading order, regenerate after any change, an idea is a note, a question is a note, never read `.base` or `.canvas`); `CLAUDE.md:65` ("Scope discipline": an idea goes "as a note in `docs/ideas/`", nothing else in that paragraph changed).
- `docs/Workflow.md:25` (step 3), `:42` (an idea), `:43` (a question: how it is added and settled, nothing is deleted), `:49` (the index).
- `docs/Conventions.md`: the properties table (`summary`, `area`, `source`, `origin`, the meaning of `status` for questions and ideas), the folders (`ideas/`), and the section "One source, two readers" (line 71).

## What an agent reads at the start

Before: to know what the vault holds, walk 151 notes, about 570 KB, roughly 143,000 tokens if read whole. After: `docs/Index.md`, 250 lines, 36 KB, roughly 9,000 tokens, then one note (the median note is about 1 KB). The ratio is an estimate by bytes divided by four, not a measured token count.

## Proof that nothing was lost

Snapshot before OBS3 (`before3.json`, outside the repo) against after (`after3.json`), the paragraphs of every file with properties excluded:

- **The ideas: 45 bullets, each appears exactly once in the idea notes, 0 missing.**
- **The questions: 11 lines, the text of each is present in its note, 0 missing.**
- The other differences are in the files that changed on purpose: 4 paragraphs of `Home.md` (the generated block and the dashboards), 2 of `Workflow.md` and 2 of `Conventions.md` (the new rules), and one sentence in each of the 11 question notes (they said the section of `ideas.md` mirrored them; now it is generated from them). The waiver paragraph of the old section is quoted whole in [[decisions/The open questions are waived during the redesign]]; the two intro paragraphs of `ideas.md` were reworded only as far as the new rule needs. Zero unexplained differences.
- `docs_index.py --write` run twice: the first writes, the second prints "nothing to change".

## Questions for the owner

1. **Doubtful merges, left as separate notes:** ideas 3 and 43 (show and hide controls for the side panels, the same idea twice); 14 inside 21 (21 repeats 14 and adds voice for the Wizard and a re-run of the starting pack); 4 and 42 (skins, and a light theme with skin loading); 2 and 45 (a sliding selection); 24, 25 and 26 (the package idea, its decisions, and the line saying it was promoted); 29 and the question "Rework of the Wizard and Manual creation experience" (one subject, an idea and a question). Merge any?
2. **Ideas that look built, still `draft`:** 30 and 31 (typed drops, a drop target: D1, D2, W5), the second half of 28 (F2 downloads fonts without the GitHub API), 35 (tests in parallel: BG2 may cover it), 13 (build without the AI). Mark them `superseded`?
3. **Dead or doubtful ideas:** 37 (kill the children of a command) is not in the BA2 report; 33 (a budget per Build, written in French) is the opposite of BF2's "no limits during the prototype". Drop, keep or translate?
4. **Dates and sources of the 10 untagged bullets** (17 to 23, 33 to 35) are assumed: 2026-11-09 and the assistant. Correct them if you remember.
5. Do you want any idea marked `current` (wanted soon)? None is today, so the "Wanted soon" view is empty.

## Verified, not verified

Verified: `python3 tools/docs_index.py --selftest` and `--check`; `python3 tools/check_docs.py --selftest` and the real check; the YAML of the four `.base` files and of the properties of every note, parsed with Ruby (0 problems); the snapshot proof above; the last messages give `python3 tools/check.py` and `tools/verify.sh --fast`; no application code changed.
Not verified (no screen): that Obsidian renders the properties and `summary` columns, that the hidden `<!-- generated -->` markers are invisible in reading view and in the editor, that the three views of `Ideas.base` filter and group as intended, and the keys I could not check against the `obsidian-bases` skill: `sort:` (the skill documents `groupBy` and filters, not sorting). `file.folder` is in the skill's list and was used as documented.

## To check by hand

1. Open `Home`: the "Where we are" block reads right (versions, last phase, next phases).
2. Open `docs/Ideas.base`: three views (newest first, by area, wanted soon, which is empty). Open two idea notes and click their links.
3. Open `docs/ideas.md`: the questions come first, then the list of ideas, and no marker is visible.
4. Edit a question's `status` (for example to `superseded`), run `python3 tools/docs_index.py --write`, and see `ideas.md` and `Index.md` follow; put it back and run it again.
5. In GitHub Desktop: the new files show, and no `docs/.obsidian/` file.
