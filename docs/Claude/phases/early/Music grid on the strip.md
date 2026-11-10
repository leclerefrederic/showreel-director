---
type: phase-report
status: current
phase: T2
date: 2026-11-10
summary: "Phase T2: the music's grid on the strip, thinned so that its lines stay at least 12 points apart."
aliases:
  - "T2"
phases: [T2]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# T2

phase T2 is built (the music's grid on the strip: lines over the frames at the snap level, thinned to at least 12 points apart, cut around labels, durations, states and markers; the lane's marks (beats, bar numbers, section limits with their names, drops with a tooltip); the snap guide and label ("Bar 5, beat 1, 0:12.4") while an edge or a cut is dragged; the Grid button remembered in `.studio/ui.json`; Analyse the track when attached but not analysed; one thumbnail per frame; the Transitions tab (rows per pair with marks, the click selecting the marker, the catalogue as a drag source with the six preview-only ones refused with their reason); `DragRow` for every list that drags, and the chips of the scenes that are off, which were buttons that could not be dragged)

Rules in ShowreelKit: `MusicMarks.swift` (`MusicGrid`), `TransitionList.swift`, `Timeline.swift` (`FrameLayout`), `ProjectStore.swift` (`StudioSettings.gridVisible`)
