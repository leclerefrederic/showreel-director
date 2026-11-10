---
type: reference
status: current
phase: OBS1
date: 2026-11-10
summary: "How the owner and the agents work: the Cowork and Claude Code sides, the phase cycle, the owner's hand test and where things go."
tags:
  - vault
  - workflow
---

# How we work

Two readers work on this repository: the owner, and agents. This note is the two-minute version. The rules in full are in `CLAUDE.md`; the rules of the vault are in [[Conventions]]; the way in is [[Home]].

## Two sides

- **The Cowork side.** The assistant in the owner's Cowork workspace designs the work, writes the phase prompt files, and keeps its own memory of what the owner decided. It reads the open questions in [[ideas]] and reminds the owner of them before any new prompt.
- **The Claude Code side.** Claude Code runs in the repository and executes one prompt file. It does not design the next phase.

## Two readers, two places

The owner works only through `docs/Home.md` and `docs/Dashboards/`: the questions to answer, the ideas, the decisions, where we are. He answers in the chat by quoting an ID. Everything else is Claude's workspace under `docs/Claude/`, read through `docs/Claude/Index.md`.

**Cite by ID and title, always**, in chat, prompts and reports: "QUESTION-004: Should a lock freeze the transitions beside it?", "IDEA-013: Build without the AI when a scene's content is fixed". An ID is unique, never reused and never renumbered. Create ideas, questions and decisions only with `python3 tools/docs_new.py <idea|question|decision> "<title>"`.

## A phase

1. **A prompt file.** A phase is the file `docs/Claude/phases/<ID>/prompt.md`, written for Claude Code; the folder is named by the phase ID exactly as in `CLAUDE.md` (for example RB1).
2. **Audit first.** Claude Code reads `CLAUDE.md`, the notes the prompt names and the code. When the prompt says so, it starts with a read-only step 0 that records what is there before changing anything.
3. **Build only that phase.** A good idea outside the phase goes in a note in `docs/Claude/ideas/`, not in the code. A taste choice that the owner has not made becomes a question in the report, not a decision.
4. **Check while working, fully at the end.** During the work: `tools/verify.sh --fast`. At the end of the phase: the complete `tools/verify.sh`, then `tools/rebuild-app.sh`. A fast pass does not verify a phase.
5. **Release notes before the version.** The notes for the new version are written first, then `tools/bump_app.py` or `tools/bump.py` publishes it. A version is never edited by hand.
6. **A report.** Claude Code writes the phase report: what it found, what it built, the questions left for the owner, what is verified and what is not, and the list "To check by hand".
7. **Never git, then stop.** Claude Code never runs git; the owner commits with GitHub Desktop. It stops after the phase.

## The owner's part

The owner tests by hand the list "To check by hand" of the report, on a real screen, and answers the open questions. Only then does the next prompt start.

> [!important] What "verified" means
> Automated tests verify rules, files and wiring. Nothing drawn, animated or typed is verified without a screen: a report says so plainly, under "Not verified". The owner's hand test is what closes that gap.

## Where things go

| What | Where |
|---|---|
| A good idea outside the phase | a note made with `python3 tools/docs_new.py idea "<title>"` (ID `IDEA-NNN`), listed in [[ideas]] and in the Ideas dashboard |
| A question the owner must settle | a note made with `python3 tools/docs_new.py question "<title>"` (ID `QUESTION-NNN`, `status: current` is open); the section "Questions to settle with the owner" of [[ideas]] is generated from the notes. To settle it: `status: superseded`, a link to the decision, then the script |
| A UX remark or a decision about the interface | [[ux-notes]] |
| The design and its numbered sections | [[studio-spec]] |
| A phase prompt | `docs/Claude/phases/<ID>/prompt.md` |
| A phase report | `docs/Claude/phases/<ID>/report.md` (a batch: `docs/Claude/archive/<BATCH-ID>/`) |
| A decision the owner took | a note made with `python3 tools/docs_new.py decision "<title>"` (ID `DECISION-NNN`) |
| What the vault holds, for an agent | `docs/Claude/Index.md`, generated from the properties: read it first and open only the note it points to |
| A test run of the skill | `showreel-director/evals/RESULTS.md`, never `ROADMAP.md` |
