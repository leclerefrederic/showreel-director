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
| `area`, `source`, `origin` | on an idea note: `area` is `app`, `skill`, `docs` or `tooling`; `source` is `owner` or `assistant`; `origin` says where it came from |
| `tags` | a short list, lowercase |

## Naming

- The folder of a phase, `docs/phases/<ID>/`, uses the phase ID exactly as in `CLAUDE.md`; the files in it are `prompt.md`, `report.md` and, when it exists, `summary.md`. A phase that has only a summary is a flat note in `docs/phases/early/<Title>.md`, named by what it holds, with its IDs in `aliases` and in `phases`; never a folder with one file. A phase always gets `docs/phases/<ID>/prompt.md` and `report.md`.
- Folders: `spec/`, `ux/`, `decisions/`, `questions/`, `ideas/`, `dashboards/` (the `.base` files and the `.canvas`), `archive/` (batches in `archive/<BATCH-ID>/` with `prompt.md` and `report.md`, and reports that span several phases).
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

- `docs/studio-spec.md` and its numbered sections (the code comments quote "section 5.6", "sections 3.1 and 5.1b", "section 6", "Scene content").
- `docs/ux-notes.md` and the names of its blocks.
- `docs/phases-done.md`.
- `docs/ideas.md` and its section "Questions to settle with the owner", which the owner's assistant reads before every prompt.
- `docs/phases/<ID>/prompt.md` and `report.md` for the phases that have them: the prompts name them, and so do `CLAUDE.md` and the other reports.
- `docs/Home.md`, `docs/Workflow.md` and `docs/Conventions.md`, named by `CLAUDE.md`.

## One source, two readers

The notes and their properties are the only source. Two views are derived from them and never written by hand: the agent view `docs/Index.md`, and the blocks between `<!-- generated:NAME -->` and `<!-- /generated:NAME -->` markers (the "Where we are" block of [[Home]], the open questions and the list of ideas in [[ideas]]). They are regenerated by `python3 tools/docs_index.py --write`; `python3 tools/check_docs.py` fails when one is out of date. Versions and "where we are" live only in the generated block of Home and the status block of the index; a phase report keeps the version of its own day, as history. The dashboards (`.base`) and the map (`.canvas`) are for Obsidian only: an agent never reads them.

