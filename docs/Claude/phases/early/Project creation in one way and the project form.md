---
type: phase-report
status: current
phase: P5
date: 2026-11-10
summary: "Phase P5: project creation in one way chosen once (Wizard or Manual), and the project form in sections."
aliases:
  - "P5"
phases: [P5]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# P5

phase P5 is built (project creation and the project form: a new project is set up in one way, chosen once at creation and never switched, Wizard (Clap leads a short interview with the existing question cards, then proposes a starting pack as cards, `propose_starter_pack`, one for the base configuration, one for the look, one for the scenes and their order, one for the music, that the user accepts one by one or all at once, through the existing proposals banner) or Manual (a form in sections: formats as tiles, duration with presets and a live feasibility line, film languages as chips, a compact brief with examples as placeholders, three control-level cards); the words Beginner and Expert are gone and the stored setting is "wizard" or "manual" (the old values are still read); the Wizard card is disabled without an API key, with its reason and way; the base configuration has five parts with an "n of 5 set" progress and the workspace opens only when it is complete; the interview gate is derived from it, with no button)

Rules in ShowreelKit: `Setup.swift` (`ProjectSetup.progress`, `ProjectSetup.durationHint`, `ProjectLanguages`, `Availability.wizard`, `ShowreelFile.gateState`), `Wizard.swift` (`WizardInterview`, `StarterPack`), `ProjectStore.swift` (`StudioSettings`)
