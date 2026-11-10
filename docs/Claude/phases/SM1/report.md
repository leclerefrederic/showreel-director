---
type: phase-report
status: current
phase: SM1
date: 2026-11-10
summary: "Report of SM1: implicit Go, Look leaves the rail for the Project panel's tab, empty inspector without its Project button; Catalogue kept; app 0.22.0."
app_version: 0.22.0
skill_version: 0.18.2
prompt:
  - "[[phases/SM1/prompt]]"
tags:
  - report
---

# SM1: fewer controls, same behaviour

## Step 0

- a) "Film up to date" (`FilmStatusChip`) read `project.film` (the film state: stale, never assembled, legacy), with an Assemble button. "Go given" (`GoButton`) wrote the gate `review` in `showreel.json` (`.gate("review")`, refused unless `goBlocker` said ok: a scene on, the storyboard gate `storyboard` passed, every visible scene Ready). Readers of `gates["review"]`: `BuildRunner.canBuild`, the readiness check, `Process`, the Wizard, Clap's `get_state`, and the reopen rule of Storyboard and Composition (a change after the Go sets it back to open). The Build button needed `canBuild`.
- b) The skill does not need the gate recorded by the app for itself beyond the file value; the file format, Clap's tools and `process.json` are unchanged. The app now writes `review: passed` itself at the start of a Build (`runBuild`), through the same `.gate` operation, so every reader sees what it saw before.
- c) Look panel: only the rail entry reached it as a panel (`RightPanel.look`); every other path (`openSettings(.look, look:)`, links in forms, drops of fonts, packages) set the Project panel's tab. The tab was stored as the panel name ("look").
- d) The empty inspector (`ProjectInspector`) showed the title and a "Project settings" button. The Project button also appears in the header of the scene, transition, resource and look item inspectors (`FormViews.swift`, `openRail(.project)`).
- e) The Catalogue (the four-squares icon) opens `CataloguePalette`: a floating card of looks, palettes, backgrounds, effects and transitions to **drag onto a scene, an item or a marker**. That is an action (it applies through the typed drop operations), shared with the look library views, the pickers and the shortcut Shift-Command-K.

## Removed, kept

- **Removed:** `FilmStatusChip`, `StripPrimaryAction` (Validate storyboard, Go given, Reopen), `GoButton`, `GoPanel` (unused), the Look rail entry, `RightPanel.look`, `IconRole.railLook`, the Project settings button of the empty inspector and the title above it.
- **Kept:** the film state model (`FilmBuild`, banners with Assemble in the viewer, the thumbnails and the Build's reuse read it); the `storyboard` and `review` gates and their operations (the Wizard, Clap, the file); the reopen rule; the Catalogue (see e).
- **Where Assemble now lives:** the viewer's banners; the chip's Assemble button is gone with the chip.

## Built

1. **Implicit Go:** the rule is `ProjectStore.goBlocker`: a scene is on and every visible scene is Ready (a locked scene counts as Ready as before, a hidden one is not counted). The storyboard-validation condition is dropped with its button. `BuildRunner.canBuild` follows it. `Availability.startBuild` gets the reason ("2 scenes are not Ready (S01, S02)", way: switch Ready on in the inspector). `runBuild` records the Go first and aborts if it is refused. Readiness and Clap's `get_state` say "implicit".
2. **Rail:** five entries. `RightPanel` has no Look; `RightSide.settings` is a flag; the Project tab (Project or Look) is `settingsTab`, stored as `settingsTab` in `.studio` settings and restored; an older stored "look" panel opens Project on Look. There was no shortcut for Look.
3. **Empty inspector:** title block and button removed; the "Select a scene..." line stays.
4. **Catalogue:** kept, see e. Question for the owner below.

## Deviations

- The Validate storyboard button is also gone (the prompt names the dot and the Go button; the implicit rule leaves nothing for it to unlock). The `storyboard` gate still exists and nothing waits for it.
- The Go is recorded in `runBuild`, after the Build card is confirmed, so cancelling the card changes nothing in the file.

## Tests

`SM1Tests` (7). Updated: `DS1Tests` and `RL1Tests`, `RB1Tests`, `DS3Tests` (five rail entries, no Look, `RightSide(settings: Bool)`), `AvailabilityTests` (the reason), `SceneTests` (the Go is implicit: `canBuild` without the stored Go, readiness ok, the reopen test), `UI2Tests` (message), `FT1Tests` and `TimelineTests` (no chip or primary action), `RL1Tests` (no Validate storyboard in the toolbar). `SelfCheck` now says a Ready scene is the implicit Go.

## Verified, not verified

Verified: build, tests, `verify.sh`. Not verified (no screen): the toolbar, the rail with five entries, the tab restored, a real Build starting and writing the Go.

## Question for the owner

The Project button of the scene, transition, resource and look item inspectors is now the only link from an inspector to the Project panel besides the rail: do you still want it? And the Catalogue: it does offer drag actions, so I kept it; remove it anyway?

## To check by hand

The Film toolbar without the dot, the Go button and Validate; a project with a scene not Ready (Build disabled with its reason, naming the scene) then all Ready (Build enabled, a Build starts, and `showreel.json` has `gates.review: passed`); an older project that had the Go given or not; the rail with five entries; every way to the Look tab (a font link, "Change..." on a look, an old project that had the Look panel open) opening Project on Look; the top bar with the Catalogue and nothing else moved; the empty inspector without the button and a scene inspector's Project button still opening Project.
