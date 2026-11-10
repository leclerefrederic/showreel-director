---
type: reference
status: current
phase: OBS1
date: 2026-11-10
tags:
  - vault
  - conventions
---

# Conventions of the vault

The vault is `docs/`. It is the only source of truth for specs, UX notes, decisions, phase prompts and phase reports. Start from [[Home]]; the way of working is in [[Workflow]]. Notes are written in English.

> [!note] Two states
> New notes follow these rules now. The existing notes keep their paths and headings until OBS2 migrates them: other files and agents name them (see "Paths that stay valid" below).

## Properties

Every new note starts with these properties.

| Property | Values |
|---|---|
| `type` | `spec`, `ux`, `phase-prompt`, `phase-report`, `decision`, `idea`, `question`, `reference` |
| `status` | `draft`, `current`, `superseded` |
| `phase` | the phase ID exactly as in `CLAUDE.md` (for example `RB1`, `W3b`), or empty |
| `date` | the day the note was written or last decided, as `YYYY-MM-DD` |
| `tags` | a short list, lowercase |

## Naming

- The folder of a phase uses the phase ID exactly as in `CLAUDE.md`.
- A note is named by what it says, in sentence case: "Clap opens when asked", not "Clap note 3".
- The numbered sections of the spec keep their number in the title, so that "section 5.6" still finds its note.
- A file name carries no date and no version.

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
- `docs/prompts/` and `docs/<phase>-report.md`, which the prompts name.
