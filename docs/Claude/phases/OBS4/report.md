---
type: phase-report
status: current
phase: OBS4
date: 2026-11-10
summary: "Report of OBS4: notes renamed with aliases, early phases flattened, one generated phase table, dashboards moved, graph linked, OBS3 leftovers settled."
prompt:
  - "[[phases/OBS4/prompt]]"
tags:
  - report
---

# OBS4: the vault cleaned (documentation and docs tooling only, no version)

Documentation and the docs tooling only. The skill (0.18.2) and the app (0.19.2) are untouched, their code and comments too (no complete verification is required); no version bump, no app rebuild.

## Step 0

### Names against the rules

12 notes broke the rule "no parenthesis, date, revision or version in a file name". The hub headings, the wikilinks, the code comments (which quote section numbers and "Scene content", never the parentheses) and the tests were checked: nothing quotes a parenthesis. The section number stays at the start of every spec note.

| Old name | New name | Keeps | Moved to properties |
|---|---|---|---|
| `spec/3.1 showreel.json (schema version 1)` | `spec/3.1 The showreel.json schema` | 3.1 | alias |
| `spec/5 Screens (revision 1 ...)` | `spec/5 Screens` | 5 | `revision: 1`, alias |
| `spec/5.1 Source of truth (revises decision 1)` | `spec/5.1 Source of truth` | 5.1 | alias |
| `spec/5.3 Modes, and the role of the AI (revision 2)` | `spec/5.3 Modes and the role of the AI` | 5.3 | `revision: 2`, alias |
| `spec/5.4 Hierarchy libraries and montage (revision 3)` | `spec/5.4 Hierarchy of libraries and montage` | 5.4 | `revision: 3`, alias |
| `spec/5.5 Editing workspace (revision 4, supersedes ...)` | `spec/5.5 Editing workspace` | 5.5 | `revision: 4`, alias |
| `spec/5.6 Design packages (revision 5, proposed)` | `spec/5.6 Design packages` | 5.6 | `revision: 5`, alias |
| `spec/6.1 Build architecture scene modules (proposal, ...)` | `spec/6.1 Build architecture with scene modules` | 6.1 | alias |
| `spec/10 Phases (revision 1)` | `spec/10 Phases` | 10 | `revision: 1`, alias |
| `ux/Application (launch, library, settings)` | `ux/Application launch, library and settings` | | alias |
| `ux/Motion the interface answers (owner, 2026-11-10, after DS1)` | `ux/Motion, the interface answers` | | alias (the date is already in `date`) |
| `ux/Visual direction (owner liked the mockup, 2026-11-10)` | `ux/Visual direction` | | alias |

Each new note has two aliases: the old file title and the heading of the hub (for example "5.4 Hierarchy: libraries and montage (revision 3)"). The hubs keep their headings unchanged.

### Phases

60 folders of `docs/Claude/phases/` (59 plus the OBS4 folder created for this phase):

| Group | Count | Folders |
|---|---|---|
| prompt and report | 13 | AS1, BG2, DS1, DS2, DS3, DS3b, FIX2, OBS1, OBS2, OBS3, RB1, UI1, UI2 |
| prompt, report and summary | 3 | CL1, FIX1, RL1 |
| report and summary | 2 | Q5, V2 |
| report only | 8 | 3D1, BA1, BA2, BF1, BF2, BG1, BG1c, BG1d |
| prompt only | 4 | BATCH-A, BATCH-B, FIX3, OBS4 |
| summary only | 30 | A, C1, D1, D2, D3, F, F2, L, M, P1, P2, P5, PK1, Q2, Q3, Q4, Q6, R, R1, S, T2, V1, W1, W1b, W1c, W2, W3a, W3b, W5, X |

Shared summaries: `phases/A/summary` served A, A2, A3, B and T; `phases/P2/summary` served P2 and P3. Superseded or abandoned prompts: `BATCH-B` and `FIX3` (both marked `superseded` in OBS3).

### The three tables

- `phases-done.md` (the table): 63 rows, every built phase, by hand.
- `Phases.base`: one row per note (a phase has two or three), not per phase.
- `spec/10` (17 KB): the plan as designed, 28 rows. It has 10 IDs that are not in the phases table (C, D, N, P, PK2, PK3, PK4, R2, W2b, W4: planned, not built or replaced) and lacks 45 phases that were built after the plan (every phase from the BA, BG, BF, UI, DS, RL, AS, FIX and OBS families, and the batches C1, D1 to D3). So they disagree on purpose: the plan against what was done; they were not tied together.

### Graph

Before: 203 notes, 2 isolated (`Index.md`, and the OBS4 prompt just created). The phase prompts and reports were not isolated only because the hand table linked them; 67 of them had no link to their counterpart or to what they built. After: 206 notes, 0 isolated, counting links in properties (Obsidian counts them for the graph).

## What was built

- **12 notes renamed** (above), `aliases` and `revision` set, their H1 renamed; 82 wikilinks and 6 written paths rewritten to the new names.
- **Phase folders:** the 30 summary-only folders became 30 flat notes in `docs/Claude/phases/early/`, named by what they hold, with the IDs in `aliases` and in `phases` (2 of them cover several IDs). The explorer's `phases/` went from 60 entries to 29 (28 folders and `early/`).
- **One phase table:** the table of `phases-done.md` is now the generated block `<!-- generated:phases -->`, read by `tools/docs_index.py` from the properties of the phase notes: 65 rows, all 63 old rows (compared, none missing) plus OBS3 and OBS4. `Phases.base` reads the same properties and gained `prompt`, `report`, `phases` columns and a view of the early phases. `spec/10` got a banner at its top (text unchanged) pointing to `phases-done`.
- **Batches:** `archive/BATCH-A/prompt.md` and `report.md` (the report was `archive/batchA-report`), `archive/BATCH-B/prompt.md` (superseded, no report). `batch-report`, `batch2-report` and `overnight-report` stay in `archive/`: they have no prompt to pair with.
- **Root and dashboards:** the four `.base` files and `Architecture map.canvas` are in `docs/Dashboards/` (the canvas paths were updated). The root of `docs/` is `Home.md`, `Index.md`, `Workflow.md`, `Conventions.md`, the four hubs and the folders.
- **Graph:** `prompt`, `report`, `spec`, `ux`, `decisions` properties on 67 phase notes, holding wikilinks, derived from what each note names; no body text changed.
- **Index:** `Index.md` has the early phases as their own table; 261 lines, 37,862 bytes (before: 250 lines, 36,058 bytes).

### Old to new

The 12 renames are in the table above. Other moves: `phases/<ID>/summary` to `phases/early/<Title>` for the 30 early phases:

| ID | Early note |
|---|---|
| A (A2, A3, B, T) | Library, project model, wizard and first storyboard |
| C1 | Corrections from the first test session |
| D1, D2, D3 | Typed payload for dropping a resource on a scene; Resource drag fixed after its row was a button; Resource drag no longer blocks the panel |
| F, F2 | Fonts in the film; Fonts downloaded from Google Fonts without the GitHub API |
| L, M, P1 | The library keeps assets only; Project memory and history; Scene and look ergonomics |
| P2 (P3), P5 | Look editors list and the base configuration; Project creation in one way and the project form |
| PK1 | Design packages without AI |
| Q2, Q3, Q4, Q6 | Scene states; Ask Clap tab and history; Ask Clap selector labels and locked look warning; Temporary marks on the reel, tree and resources |
| R, R1 | Release notes for the skill and the app; Resources grouped by type and state |
| S, T2, V1 | Storyboard strip as an editing timeline; Music grid on the strip; The film as one file per scene |
| W1, W1b, W1c | The editing workspace; The scene tree and tabbed scene inspector; Scene content as ordered items |
| W2, W3a, W3b, W5, X | The film reel with transitions and music grid; Scene modules and transition compositor spike; Viewer and film integration of the compositor; Direct manipulation with one drag and drop system; Verification tools with one command and two modes |

Also: `phases/BATCH-A/prompt`, `phases/BATCH-B/prompt` and `archive/batchA-report` to `archive/BATCH-A/` and `archive/BATCH-B/`; `Phases.base`, `Decisions.base`, `Questions.base`, `Ideas.base`, `Architecture map.canvas` to `dashboards/` (wikilinks resolve by name, so none changed).

## The rules

- `tools/check_docs.py` (and its selftest, extended): file names with no parenthesis, date, revision or version; a note whose name differs from its heading in a hub has that heading as an alias; no phase folder holds only a summary; no isolated note outside `archive/` and `early/`; the heading "Scene content" and the section numbers the code quotes still exist; wikilinks resolve through aliases (so an old title still opens the note) and the `\|` of links in tables is read. Every earlier check is kept.
- `tools/docs_index.py` (and its selftest): the `phases` block of `phases-done.md`, the table of early phases in the index.
- `docs/Claude/Conventions.md`: names (no parenthesis, date, revision, version), `aliases` and `revision`, the early-phases rule, the lowercase of the hubs on purpose, the properties `phases`, `prompt`, `report`, `spec`, `ux`, `decisions`, the folders `dashboards/` and `archive/<BATCH-ID>/`. `docs/Claude/Workflow.md` (batch path). `CLAUDE.md` Layout and "Documentation vault" (phases, batches, dashboards, aliases); nothing else.

## The OBS3 leftovers

- (a) Merged: ideas 3 and 43 into one note (both lines under headings with their dates), 14 into 21, 2 into 45 (the carrier of the shelved layout toggle line is "A selected highlight that slides"); the other three are `superseded` stubs linking to the carrier. Done.
- (b) Left separate, each linking its neighbours: 4 and 42; 24, 25 and 26; 29 (already linked to its question). Done.
- (c) 31 (a drop target on the inspector) is `superseded`: the UI1 report, point 6, shows the Overview of the inspector accepting a dropped resource. 28's second half is built (F2: font file names listed, no GitHub API call): the note says so and stays `draft`, since the thumbnails and the token are not built. **Not confirmed, still `draft`:** 30 (D1 shows typed payloads for the scene targets, not for the content list and the resource slots), 35 (the BG2 report writes scenes in parallel; BG1c says tests run one after the other), 13 (nothing in any report).
- (d) 37 untouched. 33 is in English, with the original French kept word for word, stays `draft`, and links the new decision [[decisions/No limits on the agent during the prototype]] (BF2).
- (e) The idea "Fix the comment of ShowreelFile.swift line 140 that names the wrong file" exists (`area: app`, `status: current`); the comment itself is not edited.
- (f) The question "Is the phase order of the spec still the one we follow?" exists (`status: current`), with the facts and no decision.

## Proof that nothing was lost

Snapshots before and after (outside the repo, generated blocks left out), with the old paragraphs rewritten by the same link map: 1292 distinct paragraphs before, **1254 found as they are, 38 differ, all explained, 0 unexplained**:

| Differences | Reason |
|---|---|
| 12 | the H1 of a renamed note: the title became the new name (the old title is an alias) |
| 8 | `Index.md`, regenerated (a generated file) |
| 10 | idea notes: the merges, neighbours linked, 33 translated (the original is kept as a paragraph), 31 marked built |
| 3, 1, 2 | `Conventions.md`, `Workflow.md`, `Home.md`: the new tree and rules |
| 2 | `phases-done.md`: the hand table, now the generated block (rows compared, none missing), and its reworded intro |

The 45 idea bullets each appear exactly once in the idea notes. All 12 old titles resolve through an alias (checked in each note's properties and by the link check). `docs_index.py --write` run twice: the second run changes nothing. Links rewritten: 82 wikilinks and 6 written paths. Files that no longer exist at their old path: the 12 renames, the 30 summaries, the 3 batch files and the 5 dashboards (the old-to-new map above).

## Questions for the owner

1. Ideas 30, 35 and 13 are not confirmed built and stay `draft`; say if you know one is done.
2. `batch-report` (Q4, R, F, Q6) and `batch2-report` (F2, T2) have no prompt file: they stay in `archive/`. Do you want a folder each, with an invented ID?
3. The table of `phases-done` is sorted by date then ID; the early phases share a day, so they read alphabetically. Do you want an explicit order (a number per phase)?
4. The question "Is the phase order of the spec still the one we follow?" is yours to answer.

## Verified, not verified

Verified: `python3 tools/docs_index.py --selftest` and `--check`, `python3 tools/check_docs.py --selftest` and the real check, the YAML of the `.base` files and of every note's properties parsed with Ruby, the snapshot proof, `python3 tools/check.py` and `tools/verify.sh --fast` (the last message); no application code or comment changed.
Not verified (no screen): the look of the explorer, the graph and the Bases views in Obsidian; that the quick switcher finds a note by an old title; that Obsidian draws the links held in properties in the graph (it is a setting of the graph view); the keys I could not check against the `obsidian-bases` skill (`sort:`, and `file.folder == "phases/early"`, which the skill's file properties table supports but does not show with a path).

## To check by hand

1. Open the vault and read the file explorer: the root (4 notes, 4 hubs, folders), `phases/` (28 folders and `early/`), `spec/`, `ux/`, `dashboards/`.
2. Open the graph view and look for isolated dots (none expected outside `archive/` and `early/`).
3. Type an old title in the quick switcher, for example "Design packages (revision 5, proposed)": the alias must find `spec/5.6 Design packages`.
4. Open `phases-done.md` and `Phases.base`: they must agree (65 rows against the notes).
5. Open `ideas.md` and the three merged ideas ("Show and hide controls for the side panels in the view group", "Interface language, voice for the Wizard and re-running the starting pack", "A selected highlight that slides").
6. In GitHub Desktop: renames, no `docs/.obsidian/`.
