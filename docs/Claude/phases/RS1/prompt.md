---
type: phase-prompt
status: current
phase: RS1
date: 2026-11-11
summary: "The Resources section of the left panel takes the height of the Film strip by default, so the divider lines up with the top of the strip (DECISION-023)."
tags:
  - prompt
---

# Phase RS1: Resources take the height of the Film strip by default

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic.

The owner's answer to QUESTION-002 (2026-11-11): "same height as the Film strip by default, so we don't have to think about it." It is DECISION-023 ("The Resources section takes the height of the Film strip by default"), which replaces the 2/3 and 1/3 default of DECISION-011. **Change only the default of the split.**

## Step 0 (read-only, 5 lines at the top of the report)

a) Where `LibrarySplit.standard` (or its equivalent) is defined, how the divider is stored per project or per window, and the range of 25 to 85 percent.
b) How the Film strip's height is defined and whether it can change (the owner drags it, the Film placement toggle, a small window), and how DECISION-019 (the sizes the owner drags never change with the Film placement) applies.
c) What the left panel looks like when the strip is at the bottom and when the Film placement puts it elsewhere.

## What to build

1. **The default.** When the owner has not dragged the divider, the Resources section is as tall as the Film strip, so the divider sits on the same horizontal line as the top of the strip; the Storyboard takes the rest. The value is computed by a pure function in ShowreelKit (inputs: the available height and the strip's height; output: the split), with tests, not in the view.
2. **A dragged divider wins.** A stored, dragged position is never changed by this phase (DECISION-019). Only a panel that never had its divider dragged gets the new default. Say how "never dragged" is known today; if it is not recorded, add the smallest flag that records it, and say so.
3. **The range.** Re-check the 25 to 85 percent range against the new default: the default must lie inside it at any window size the app allows, or the range is clamped for drawing only, as DECISION-019 says for a small window (the stored value stays). Say what you chose.
4. **When the strip is not at the bottom** (Film placement, a window too small for it): fall back to the old 2/3 and 1/3 and say so in the report.
5. **Nothing else:** no change to the Resources tabs, the groups, the Storyboard list, the strip's own size or the Film placement.

## Tests (no screen)

The default equals the strip's height for several window heights; a stored dragged value is untouched; the default is clamped inside the range at the smallest allowed window; the fallback applies when the strip is not at the bottom. Existing split tests that assert 2/3 and 1/3 change: list them and say why.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py patch "..."`; never edit a version by hand. Set DECISION-011 to `status: superseded` with a line pointing to DECISION-023; update docs/Claude/ux-notes.md ("Built in RS1 (date)"), CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh` (in the batch: once at the end).

## Final report (docs/Claude/phases/RS1/report.md)

Step 0 results, what was built, the version, what is verified and what is not (no screen: nothing drawn is verified, say so plainly), and "To check by hand": a new project (the divider on the line of the strip's top), dragging the divider and reopening (the dragged value stays), a small window, and the Film placement toggle. Stop after the phase.
