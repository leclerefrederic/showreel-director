---
type: reference
status: current
phase: OBS1
date: 2026-11-10
tags:
  - vault
  - entry
---

# Showreel Studio documentation

This folder is an Obsidian vault and the single source of truth for the specs, the UX notes, the decisions, the phase prompts and the phase reports of the repository. Start here. The rules of the vault are in [[Conventions]]; how the owner and the agents work is in [[Workflow]].

## Where we are

Read on 2026-11-10 from `app-swift/shared/app-version.json`, `showreel-director/SKILL.md` and the "Open work" list of `CLAUDE.md`. These are snapshots: the files named are the truth, not this note.

- App version: **0.19.2**. Skill version: **0.18.2**.
- Last phase: **RB1** (the behaviour of the rail's buttons), report in [[rb1-report]].
- Next, in the order of `CLAUDE.md`: PK2 (apply a package to an existing project), W4 (timing inside the scene), N (activity and notifications), then Deliver (D).

> [!note] Stop after each phase
> Claude Code builds one phase, writes its report and stops. The owner tests by hand before the next prompt. See [[Workflow]].

## The reference documents

- [[studio-spec]]: the design of Showreel Studio v2, with numbered sections (section 10 lists the phases, section 11 the owner's decisions).
- [[ux-notes]]: the owner's UX remarks per block, and what each phase built from them.
- [[phases-done]]: the archive of the early phases, with their details.
- [[ideas]]: the parking lot, and the open questions the owner has not settled yet (read the section "Questions to settle with the owner" before writing any prompt).

## Phase prompts

The files Claude Code reads to run a phase. Each one has its report below.

- Studio shell and rail: [[prompts/UI1]], [[prompts/UI2]], [[prompts/DS1]], [[prompts/DS2]], [[prompts/DS3]], [[prompts/DS3b]], [[prompts/RL1]], [[prompts/RB1]]
- Forms and behaviour: [[prompts/AS1]], [[prompts/CL1]]
- Build: [[prompts/BG2]]
- Fixes and batches: [[prompts/FIX1]], [[prompts/FIX2]], [[prompts/FIX3]], [[prompts/BATCH-A]], [[prompts/BATCH-B]]
- The vault itself: [[prompts/OBS1]], [[prompts/OBS2]]

## Phase reports

- Studio shell and rail: [[ui1-report]], [[ui2-report]], [[ds1-report]], [[ds2-report]], [[ds3-report]], [[ds3b-report]], [[rl1-report]], [[rb1-report]]
- Forms and behaviour: [[as1-report]], [[cl1-report]], [[q5-report]], [[v2-report]]
- Build: [[ba1-report]], [[ba2-report]], [[bf1-report]], [[bf2-report]], [[bg1-report]], [[bg1c-report]], [[bg1d-report]], [[bg2-report]]
- Engine and 3D: [[3d1-report]]
- Fixes: [[fix1-report]], [[fix2-report]]
- Batches and the overnight run: [[batch-report]], [[batch2-report]], [[batchA-report]], [[overnight-report]]

## Outside the vault

- `CLAUDE.md` at the root: the rules every agent follows.
- `ROADMAP.md`: features and known limits.
- `CHANGELOG-APP.md` and `RELEASE-NOTES-APP.md`: what each app version changed.
- `showreel-director/evals/RESULTS.md`: test runs of the skill.
