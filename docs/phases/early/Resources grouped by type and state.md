---
type: phase-report
status: current
phase: R1
date: 2026-11-10
summary: "Phase R1: the Resources tab groups resources by type then by state, with folding remembered per project."
aliases:
  - "R1"
phases: [R1]
decisions:
  - "[[decisions/A package can be handed to the skill]]"
  - "[[decisions/A package is one archive file with its own extension]]"
  - "[[decisions/Package rights and approvals travel with the package]]"
  - "[[decisions/The AI may read design decisions and corrections, never the content]]"
tags:
  - summary
---

Part of [[phases-done]].

# R1

phase R1 is built (the Resources tab: resources grouped by type, Images, Sounds, Music, Fonts and Other, then by state, with folding remembered per project; the selected resource shown in the centre, an image, a sound or a music file with its tags, its cover and a small player, or a font specimen, by one priority rule; tags kept in `showreel.json`, with the "placeholder" tag standing for the manifest status; four states derived from the manifest, Available, Used in scenes (derived from the scenes, never typed), Proposal and Needs attention; a file added by the user is approved at once when it passes the automatic checks (resolution, weight, a name that suggests real data, a copyright notice in the metadata, a font's licence and embedding flag), otherwise it needs attention, stays in `assets/source/`, is hidden from Clap and refused by the build until the rights question is answered, a risk is accepted with a reason, or the file is replaced)

Rules in ShowreelKit: `ResourceStates.swift`, `ResourceChecks.swift`, `FontInfo.swift`, `Assets.swift`
