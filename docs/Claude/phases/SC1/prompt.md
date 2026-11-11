---
type: phase-prompt
status: current
phase: SC1
date: 2026-11-11
summary: "Keyboard shortcuts for the Inspector, the Look tab and the Project panel, in the family of Shift-Command-A for Clap (DECISION-027)."
tags:
  - prompt
---

# Phase SC1: shortcuts for the Inspector, Look and Project

Read CLAUDE.md first and follow every rule (never run git, English interface, skill untouched, answer the owner in French and short, no screen so say what was not seen, no out-of-scope work: an idea goes in a note created with `python3 tools/docs_new.py idea`). Use `graphify query` before reading files. Views stay free of business logic. UI principle: every action gets a visible reaction, and anything unavailable says so, why and how to get it back (`disabledWithReason`, `Availability`).

The owner's answer to QUESTION-007 (2026-11-11), DECISION-027: the Inspector, Look and Project panels each get a keyboard shortcut, next to Shift-Command-A for Clap.

## Step 0 (read-only, 5 lines at the top of the report)

a) Every keyboard shortcut the app already defines (the menus in `App.swift`, Shift-Command-A, Shift-Command-K and others), and the macOS ones a plain key would clash with.
b) How a rail entry or a panel is opened today (`openRail`, `RightPanel`, `openSettings(.look, ...)`, the Project panel's Look tab since SM1) and how Clap's shortcut is wired.
c) Where the shortcuts of the rail can be listed for the owner (a tooltip, the View menu).

## What to build

1. **Three shortcuts**: Inspector, Project and Look. Look is not a rail entry since SM1: its shortcut opens the Project panel on its Look tab. Propose the keys in the same family as Clap's (for example Shift-Command-I, Shift-Command-L, and a free key for Project), **avoid every clash found in step 0 a** (Shift-Command-P is the system Page Setup: do not take it for Project unless the app has no such menu, say what you chose and why).
2. **Every action shows its reaction.** Pressing a shortcut for an already open panel does nothing, as DECISION-026 says for the centre views (a second click does nothing); say what the shortcut does when the right side is closed (it opens the side on that panel). A shortcut that cannot act (no scene selected for the Inspector) says why, through the same `Availability` reason as the button.
3. **They are visible.** The shortcuts appear in the View menu (or the menu that holds Clap's) and in the tooltip of the matching rail entry.
4. **Nothing else:** no new panel, no change to what the panels show, no change to Clap's shortcut.

## Tests (no screen)

Each shortcut maps to its panel; no two shortcuts of the app are equal (a test over the whole list); the Look shortcut opens the Project panel on the Look tab; a repeat does not toggle; the unavailable case carries a reason. Say which tests changed.

## Release

Release notes in RELEASE-NOTES-APP.md BEFORE `python3 tools/bump_app.py patch "..."`; never edit a version by hand. Update docs/Claude/ux-notes.md ("Built in SC1 (date)"), CLAUDE.md "Open work", then `python3 tools/docs_index.py --write`.

## Verification

During the work: `tools/verify.sh --fast`. At the end: the complete `tools/verify.sh`, then `tools/rebuild-app.sh` (in the batch: once at the end).

## Final report (docs/Claude/phases/SC1/report.md)

Step 0 results, the keys chosen and why, the version, what is verified and what is not (no screen, no keyboard: nothing pressed is verified, say so plainly), and "To check by hand": each shortcut from a closed side, from another open panel and with the focus in a text field; the tooltips and the menu entries. Stop after the phase.
