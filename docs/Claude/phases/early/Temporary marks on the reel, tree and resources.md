---
type: phase-report
status: current
phase: Q6
date: 2026-11-10
summary: "Phase Q6: temporary marks for a waiting proposal or a running build on the reel's frames, the tree and the resources."
aliases:
  - "Q6"
phases: [Q6]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# Q6

phase Q6 is built (the temporary marks, a proposal waiting or the build running, on the reel's frames, the tree and the resources as on the list, with one layout rule for the badges, the review state then the build state, `MarkLayout`; the remaining disabled controls say why, Undo and Redo in the Edit menu included; the offer to generate lists the scenes with no file and the stale ones, leaves out the locked ones with their reason, and asks a separate confirmation before it overwrites a file edited by hand)

Rules in ShowreelKit: `Marks.swift`, `FilmState.swift` (`GenerationOffer`), `SceneGeneration.swift`
