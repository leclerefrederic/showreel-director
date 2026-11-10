---
type: reference
status: current
phase: OBS1
date: 2026-11-10
tags:
  - vault
  - workflow
---

# How we work

Two readers work on this repository: the owner, and agents. This note is the two-minute version. The rules in full are in `CLAUDE.md`; the rules of the vault are in [[Conventions]]; the way in is [[Home]].

## Two sides

- **The Cowork side.** The assistant in the owner's Cowork workspace designs the work, writes the phase prompt files, and keeps its own memory of what the owner decided. It reads the open questions in [[ideas]] and reminds the owner of them before any new prompt.
- **The Claude Code side.** Claude Code runs in the repository and executes one prompt file. It does not design the next phase.

## A phase

1. **A prompt file.** A phase is a file in `docs/prompts/`, written for Claude Code, named by the phase ID exactly as in `CLAUDE.md` (for example RB1).
2. **Audit first.** Claude Code reads `CLAUDE.md`, the notes the prompt names and the code. When the prompt says so, it starts with a read-only step 0 that records what is there before changing anything.
3. **Build only that phase.** A good idea outside the phase goes in one line in [[ideas]], not in the code. A taste choice that the owner has not made becomes a question in the report, not a decision.
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
| A good idea outside the phase | one line in [[ideas]] |
| A question the owner must settle | the section "Questions to settle with the owner" of [[ideas]] |
| A UX remark or a decision about the interface | [[ux-notes]] |
| The design and its numbered sections | [[studio-spec]] |
| A phase prompt | `docs/prompts/` |
| A phase report | `docs/<phase>-report.md` (until the move described in [[Conventions]]) |
| A test run of the skill | `showreel-director/evals/RESULTS.md`, never `ROADMAP.md` |
