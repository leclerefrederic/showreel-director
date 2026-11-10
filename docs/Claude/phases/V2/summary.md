---
type: phase-report
status: current
phase: V2
date: 2026-11-10
summary: "Phase V2: the state of the film and of each scene computed from fingerprints, with an Assemble that needs no AI."
tags:
  - summary
---

Part of [[phases-done]].

# V2

phase V2 is built (the state of the film and of each scene from fingerprints, never stored by hand: `FilmBuild.status`; Assemble, with no AI, writes film.json, assembles and tests on a copy and only a green result replaces the version, `FilmAssembly`; the version that is read is the last one built and tested green, never a folder a stopped build left behind; Play plays only the assembled film and assembles a stale one first; banners, a counter in the reel's header and a build mark on each scene; the old single-file format plays as it is; the free instruction of a transition is marked pending until a generation read it, `TransitionNotes`; `assemble_film` for Clap; the details are in `docs/Claude/phases/V2/report.md`)

Rules in ShowreelKit: `FilmState.swift`, `SceneModules.swift`
