---
type: reference
status: current
phase: OBS1
date: 2026-11-10
summary: "The rules of the vault: properties, naming, links, one fact in one place, what never goes in a note and the paths that stay valid."
tags:
  - vault
  - conventions
---

# Conventions of the vault

The vault is `docs/`. It is the only source of truth for specs, UX notes, decisions, phase prompts and phase reports. Start from [[Home]]; the way of working is in [[Workflow]]. Notes are written in English.

> [!note] Hubs
> `studio-spec.md`, `ux-notes.md`, `phases-done.md` and `ideas.md` stay at their old paths as hubs: a short overview with the same headings, linking to the atomic notes (`spec/`, `ux/`, `phases/`). Other files and agents name them (see "Paths that stay valid" below).

## Properties

Every new note starts with these properties.

| Property | Values |
|---|---|
| `type` | `spec`, `ux`, `phase-prompt`, `phase-report`, `decision`, `idea`, `question`, `reference` |
| `status` | `draft`, `current`, `superseded`. For a `question`, `current` means open and `superseded` means settled, with a link to the decision. For an `idea`, `draft` is parked, `current` is wanted soon, and `superseded` is built, promoted or dropped, with a link to where it went. |
| `phase` | the phase ID exactly as in `CLAUDE.md` (for example `RB1`, `W3b`), or empty |
| `date` | the day the note was written or last decided, as `YYYY-MM-DD` |
| `summary` | one plain sentence, at most 160 characters, saying what the note holds (not its title again); written from the note's content |
| `app_version`, `skill_version` | on a phase report, when the report names them |
| `aliases`, `revision` | `aliases` lists the old titles of a renamed note; `revision` is the revision of a spec note, when it has one |
| `phases` | on an early phase note: the IDs it covers, as a list |
| `prompt`, `report`, `spec`, `ux`, `decisions` | on a phase note: the notes it relates to, as wikilinks in the property (the graph counts them), never a change of the body |
| `id`, `since` | on an idea, a question and a decision: `id` is `IDEA-NNN`, `QUESTION-NNN` or `DECISION-NNN` (three digits, unique, never reused, never renumbered; also in `aliases`, so that Cmd+O finds it); `since` is the date it appeared. Allocated by `tools/docs_new.py` in `docs/Claude/ids.json` |
| `blocks`, `recommendation`, `decision`, `answer` | on a question: the phase IDs that wait for the answer (or empty), the assistant's one-line recommendation (or "none yet", never a decision), and for a settled one the link to the decision and a one-line answer |
| `outcome`, `outcome_link`, `merged_into` | on a settled idea: built, promoted, merged or dropped, with the link to where it went (`merged_into` for a merged stub) |
| `affects` | on a decision: links to the notes or phases it governs |
| `area`, `source`, `origin` | on an idea note: `area` is `app`, `skill`, `docs` or `tooling`; `source` is `owner` or `assistant`; `origin` says where it came from |
| `tags` | a short list, lowercase |

## Naming

- The folder of a phase, `docs/Claude/phases/<ID>/`, uses the phase ID exactly as in `CLAUDE.md`; the files in it are `prompt.md`, `report.md` and, when it exists, `summary.md`. A phase that has only a summary is a flat note in `docs/Claude/phases/early/<Title>.md`, named by what it holds, with its IDs in `aliases` and in `phases`; never a folder with one file. A phase always gets `docs/Claude/phases/<ID>/prompt.md` and `report.md`.
- Folders under `docs/Claude/`: `spec/`, `ux/`, `decisions/`, `questions/`, `ideas/`, `archive/` (batches in `archive/<BATCH-ID>/` with `prompt.md` and `report.md`, and reports that span several phases).
- A note is named by what it says, in sentence case: "Clap opens when asked", not "Clap note 3".
- The numbered sections of the spec keep their number in the title, so that "section 5.6" still finds its note.
- A file name carries no parenthesis, no date, no revision and no version: the revision, the status and the date go in properties (`revision`, `status`, `date`). A note that is renamed keeps its old title in `aliases`, so old wikilinks, searches and the reports that name it still resolve. `tools/check_docs.py` checks it.
- The four hubs (`studio-spec.md`, `ux-notes.md`, `phases-done.md`, `ideas.md`) keep their historic lowercase names on purpose: code comments and agents quote them. The other root notes are `Home.md`, `Index.md`, `Workflow.md` and `Conventions.md`.

## Links

- Inside the vault, use wikilinks: `[[Note]]`, `[[Note#Heading]]`, `[[Note|text]]`.
- Use a path in backticks only where an agent or a program needs a path: `CLAUDE.md`, a script, a comment in the code.
- Outside the vault, use a normal Markdown link.

## One fact in one place

A summary links to the source; it does not copy it. When a fact is needed in two places, one of them says it and the other links to it. Version numbers and phase lists are read from their source (`app-swift/shared/app-version.json`, `SKILL.md`, `CLAUDE.md`), and a note that quotes one says when it was read.

## What never goes in a note

API keys, tokens, passwords, customer data, real personal data, and anything copied from a private conversation. Use placeholders.

## Superseded notes

A note that is replaced stays where it is. It gets `status: superseded` and a line at the top that links to its successor. It is never deleted, because other notes and reports link to it.

## Paths that stay valid

These paths and headings are read by programs, by agents or by comments in the code. Do not move or rename them without updating every reader.

- `docs/Claude/studio-spec.md` and its numbered sections (the code comments quote "section 5.6", "sections 3.1 and 5.1b", "section 6", "Scene content").
- `docs/Claude/ux-notes.md` and the names of its blocks.
- `docs/Claude/phases-done.md`.
- `docs/Claude/ideas.md` and its section "Questions to settle with the owner", which the owner's assistant reads before every prompt.
- `docs/Claude/phases/<ID>/prompt.md` and `report.md` for the phases that have them: the prompts name them, and so do `CLAUDE.md` and the other reports.
- `docs/Home.md`, `docs/Claude/Workflow.md` and `docs/Claude/Conventions.md`, named by `CLAUDE.md`.

## Where things live

`docs/` holds only `Home.md` (the owner's cockpit), `Dashboards/` (the `.base` files and the `.canvas`, for the owner in Obsidian) and `Claude/` (everything else: the agent workspace, with `Index.md`, the hubs, `Workflow.md`, `Conventions.md`, `ids.json`, and the folders `spec/`, `ux/`, `ideas/`, `questions/`, `decisions/`, `phases/`, `archive/`). Paths in this note are relative to `docs/Claude/` unless they start with `docs/`.

## One source, two readers

The notes and their properties are the only source. Two views are derived from them and never written by hand: the agent view `docs/Claude/Index.md`, and the blocks between `<!-- generated:NAME -->` and `<!-- /generated:NAME -->` markers (the "Where we are" block of [[Home]], the open questions and the list of ideas in [[ideas]]). They are regenerated by `python3 tools/docs_index.py --write`; `python3 tools/check_docs.py` fails when one is out of date. Versions and "where we are" live only in the generated block of Home and the status block of the index; a phase report keeps the version of its own day, as history. The dashboards (`.base`) and the map (`.canvas`) are for Obsidian only: an agent never reads them.

## Dashboards

A dashboard (`.base`) of this vault uses only constructs the `obsidian-bases` skill documents and `tools/check_docs.py` can check: top-level and view `filters` made of `and` lists of `property == "text"` and `property != "text"` (a note property is written bare), `file.folder == "<an existing folder>"`, views of `type: table` with a name, `order`, `groupBy` (property and direction) and `sort`, and `properties` with `displayName`; no formula unless it is defined and needed. A dashboard filters on a note's `type`, so a type belongs to its folder only (`idea` in `ideas/`, `question` in `questions/`, `decision` in `decisions/`, `phase-prompt` and `phase-report` in `phases/` or `archive/`): a hub or any other note carries `reference`, `spec` or `ux`, never a type a dashboard filters on. The `phase` of an idea is an empty text (`phase: ""`), never null. A new dashboard must pass `python3 tools/check_docs.py`; `python3 tools/check_docs.py --dashboards` prints the number of rows each view should show, to compare with Obsidian. Obsidian rewrites a `.base` file when it is opened (quotes disappear, the keys stay).

