---
type: phase-prompt
status: current
phase: FT1
date: 2026-11-10
summary: "Film toolbar: zoom at the far right, no Add scene button, no Ripple toggle."
tags:
  - prompt
---

# Phase FT1: the Film toolbar, simplified

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic: rules live in ShowreelKit with tests. The owner waived the open questions for the redesign. The owner loves the look of the app today: **change only what is listed here** and keep every behaviour; where a colour has no token, add a token with that value, no new colour literal.

Read docs/Claude/ux-notes.md (the entries on the Film strip and its toolbar, "Sizes and reset", the UI principle), the RL1 and RB1 reports, and the code of the strip's toolbar (TimelineViews.swift and its controls: the title and counts, the transport, the zoom slider, the zoom menu, the Beat menu, the grid and fit buttons, Add scene, any ripple setting), the edit rules in ShowreelKit that mention ripple.

## Step 0 (read-only, 10 lines at the top of the report)

a) Every control of the toolbar in order, with what it does (the Beat menu and the two icon buttons included).
b) Every way to add a scene in the app today (the Storyboard list's "New" button, menus, Clap, drag and drop) and which one the toolbar's "Add scene" menu calls. The owner says the Storyboard's "New" is where scenes are created: confirm it covers everything the toolbar menu offers (for example insert after, from a resource, a draft), and list any entry that exists only in the toolbar's menu.
c) Where "ripple" lives: the control, its stored preference, the edit rules and the tests that use it, and what the default does when a scene's duration changes (the following scenes move?). The owner says scenes never overlap, so a ripple choice makes no sense.
d) How the zoom controls are laid out and stored.

## What to build

1. **Zoom controls at the far right of the toolbar** (the slider, the zoom in and out buttons and the zoom menu together, in that order, right-aligned). Nothing else moves.
2. **Remove the "Add scene" menu from the toolbar**, only if step 0 b shows that the Storyboard's "New" covers every entry (or that the missing entries exist elsewhere). If an entry exists only in the toolbar menu, move it into the Storyboard list's "New" menu (same operation, same rules, same reaction) and say so. Keep keyboard shortcuts and application menu items that exist. Never leave the app unable to add a scene.
3. **Remove the Ripple on/off control.** The behaviour stays what the default does today (step 0 c): scenes follow each other with no overlap and no gap, a change of duration moves the scenes after it, and the lock rule of UI2 holds (a change that would move a locked scene's start is refused with its reason). Remove the control, its stored preference (an old stored value is ignored, never an error) and the dead branches; keep the edit rules and their tests for the behaviour that stays; list what you removed.
4. **Leave the Beat menu, the grid button and the fit button where they are** (MT1 moves the music controls next). Nothing else changes in the toolbar.

## Tests (no screen)

The toolbar's control order; the zoom group is last; no ripple setting is read or written (an old stored ripple value is ignored); the edit rules still move the following scenes and still refuse to move a locked scene; every entry that the removed Add scene menu offered is reachable from the Storyboard's "New". Update the tests that referenced ripple or the removed menu and say which.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py` (a patch version unless you can say why it is minor); never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in FT1 (date)" and what remains), ROADMAP.md if a limit is lifted, CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh`.

## Final report (docs/Claude/phases/FT1/report.md)

Step 0 results, what was built point by point, deviations, the version, what is verified and what is not (no screen: nothing drawn, animated or felt is verified, say so plainly), and "To check by hand": the zoom group at the far right and its three controls working; no Add scene in the toolbar and a new scene created from the Storyboard's New (every entry); changing a scene's duration moving the following scenes; a locked scene refusing a move with its reason; an old project opening without any ripple trace. Stop after the phase.
