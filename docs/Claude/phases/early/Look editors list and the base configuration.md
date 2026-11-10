---
type: phase-report
status: current
phase: P2
date: 2026-11-10
summary: "Phases P2 and P3: the look as a list of six editors, and a new project needing its base configuration before the workspace opens."
aliases:
  - "P2"
  - "P3"
  - "P2 and P3"
phases: [P2, P3]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# P2 and P3

phases P2 and P3 are built (the look is a list of six editors with a back button; a new project needs its base configuration before the workspace opens, `Setup.swift`; the Checks tab of the left panel, `CheckPanel.swift`; `showreel.json` carries `formatRevision`, nothing is written when a project opens, and "Update project..." backs up to `.studio/backups/`, migrates and can be restored, `Revision.swift`; the Library window shows plain-text states and can locate, remove and move to the Trash, `ProjectLibrary.swift`; the app's settings have one way in, the app menu)

Rules in ShowreelKit: `Setup.swift`, `CheckPanel.swift`, `LookSections.swift`, `Revision.swift`, `ProjectLibrary.swift`
