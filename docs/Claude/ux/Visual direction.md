---
type: ux
status: current
phase: 
date: 2026-11-10
summary: "The owner's visual direction: a dark editor look with its own identity, shown by a mockup, and the layout it fixes."
aliases:
  - "Visual direction (owner liked the mockup, 2026-11-10)"
tags:
  - ux
---

Part of [[ux-notes]].

# Visual direction

A dark editor look, our own identity (not a copy of any product). Mockup shown in the conversation, not stored as a file; what it fixes:
- **Layout.** A narrow view rail at the left (Film, Look, Build, Project: it switches what the centre shows; this is the DS1 mockup, and since RL1 the rail has two groups, see "Built in RL1"), the flat Storyboard on top of the left panel with Resources in its lower third, the preview in a rounded frame at the centre with its transport under it, the inspector at the right (Visible, Ready and Locked switches, a "Made of" overview, Delete scene at the bottom, Ask Clap as its other tab), the strip at the bottom with the status icon on each frame, diamonds on the cuts and the music wave under the scenes.
- **Colour.** Graphite surfaces in three steps, hairline borders, one accent (a teal) for selection and the one primary action (Build), warning yellow only for warnings, the scene lane in slate blue and the music lane in amber. The six Status icons keep the colours decided in UI2.
- **Principles to keep.** One accent per view, rounded panels with one radius scale, 11 px minimum text, every disabled control still says why and how to get it back, and the icons must keep their meaning on the new palette (check contrast, grey text on dark first).
- **Plan, not scheduled.** (1) a theme file for the app (colours, radii, spacing, type, states) used by every view, with a contrast check; (2) the shell: rail, panels, centre and right regions; (3) the strip and the lists; (4) the inspector and the forms. One block per phase, tested on screen each time. Native controls stay where replacing them would cost accessibility.
- **Waiting on the owner:** the questions at the top of `docs/Claude/ideas.md` that touch these screens (Checks badge or status row, the 2/3 and 1/3 split, the lock and instruction rules).

**Built in RB1 (2026-11-10).** The rail's buttons follow one rule (ShowreelKit `RailState`, `RightSide`, `RailEntry.tooltip`): the centre views never toggle off, a right panel opens, replaces another and closes on a second click, a request for Clap (Build, draft, card, interview) always makes Clap visible, the Inspector's mark never shows on the open Inspector; the six buttons share hover, pressed, selected, focus ring and badges, with names and shortcuts in the tooltips, arrows that move inside a group and wrap. What remains (questions in docs/Claude/phases/RB1/report.md): whether Build may toggle off, whether Look lights a centre entry, shortcuts for the other panels; everything drawn is to be judged on screen.

Phases named in this note: [[phases/RB1/report|RB1]], [[phases/UI2/report|UI2]]

**Built in SM1 (2026-11-10).** The Go is implicit (every visible scene Ready; starting the Build records it); no Film status dot, Go or Validate button in the Film toolbar; Look left the rail and is the Look tab of Project (five rail entries); the empty inspector lost its Project settings button. Remains: the Catalogue stays (it holds drag actions); the Project button of the other inspectors stays (question for the owner).

**Built in PT1 (2026-11-10).** The project settings panel has three tabs (Brief, Format, Look) under the project name and a compact base configuration whose items go to their tab; no conversation language control anywhere. The second tab is called "Format" (kept: it names what the tab sets best in one word). Remains: the Wizard's wording is unchanged.

**Built in PL1 (2026-11-10).** The design board's contrast checks sit under their swatches (`DesignBoard.columns`, `spanning`). Remains: the palette editor's list of checks and the palette preview of the Catalogue keep their own layouts (they are not swatch columns).

**Built in SC1 (2026-11-11).** Shift-Command-I (Inspector), -J (Project) and -Y (Project on its Look tab), next to -A for Clap; in the View menu and the rail tooltips; a second press of an open panel's key does nothing. Remains: the keys are not pressed here (no keyboard); J and Y are chosen because -L (Project Library) and -P (Page Setup) are taken.

**Built in UR1 (2026-11-11).** Undo and Redo sit at the foot of the rail, icon only, with the Edit menu's availability and reasons; pressed and held, or right-clicked, each lists the last 20 steps (`UndoHistory`) and goes back or forward through several as one operation (`ProjectStore.undo(steps:)`, `redo(steps:)`). Remains: the long press is SwiftUI's `Menu` with a primary action (not seen on screen); typed text keeps its own undo.
