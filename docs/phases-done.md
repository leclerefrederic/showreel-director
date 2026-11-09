# Phases done

The built phases of Studio v2, with what each one holds, archived from `CLAUDE.md` ("Open work", item 1). One paragraph per phase, as it was written there; the line under it names the file of ShowreelKit where its rules live. The design is in `docs/studio-spec.md`.

## A, A2, A3, B and T

Phases A, A2, A3, B and T are built (ShowreelKit library, project model, generated documents, typed copilot operations, `process.json`, Beginner wizard and Expert mode, no-key start, native checks, EnginePreview and the look editors, Library at launch, storyboard, the explicit Go, Build and preview).

Rules in ShowreelKit: `ProjectStore.swift`, `ShowreelFile.swift`, `Operations.swift`, `Wizard.swift`, `Checks.swift`, `Process.swift`, `Build.swift`, `Look.swift`, `Storyboard.swift`

## W1

Phase W1 is built: the editing workspace (Library with tabs Resources, Scenes and Look elements; Viewer; Inspector with the Copilot tab; Storyboard strip) replaces the sidebar of blocks, and the data is a scene library plus `storyboards` (migration of the phase T shape on first save, archive with tombstone). Next, in this order:

Rules in ShowreelKit: `Storyboard.swift`, `ShowreelFile.swift`, `Operations.swift`

## W1b

W1b (scene tree and tabbed scene inspector)

Rules in ShowreelKit: `SceneTree.swift`, `Storyboard.swift`

## W1c

W1c (scene content: ordered items with colour, animation and instruction, fixed or auto, control level, order = priority)

Rules in ShowreelKit: `Content.swift`

## W2

W2 (the film reel: transitions, durations by drag, playhead, music grid and snapping; built, the transition compositor of the engine is the spike of W3)

Rules in ShowreelKit: `Reel.swift`, `Music.swift`

## W3a

W3a spike (built; decision: compositor only)

Rules in ShowreelKit: `Film.swift` (the compositor itself is the skill's `engine/film.js`)

## W3b

W3b viewer and film integration (built)

Rules in ShowreelKit: `Film.swift`, `Look.swift`, `Build.swift`

## W5

W5 direct manipulation (built: one drag and drop system for every list and target, context menus, scene names, undo and redo of every typed operation; the rules are in `Drops.swift` and `Undo.swift`, the views only draw and relay)

Rules in ShowreelKit: `Drops.swift`, `Undo.swift`

## L

phase L is built (the library keeps assets only; the project settings panel holds the parameters and the global look; effects, transitions and backgrounds are pickers where they are used, `Catalogue.swift`; an optional floating Catalogue stays a drag source; application settings are in the app menu)

Rules in ShowreelKit: `Catalogue.swift`

## P1

phase P1 is built (scene and look ergonomics: the design board in the viewer, a pinned current-choice card in each look editor, one switch per group for a scene's look with a confirmation on look drops and a badge, scene tabs Settings, Composition, Effects, Look with a tree of the same structure, and a linked resource always an element: `LookRules.swift`, `Composition.swift`)

Rules in ShowreelKit: `LookRules.swift`, `Composition.swift`

## P2 and P3

phases P2 and P3 are built (the look is a list of six editors with a back button; a new project needs its base configuration before the workspace opens, `Setup.swift`; the Checks tab of the left panel, `CheckPanel.swift`; `showreel.json` carries `formatRevision`, nothing is written when a project opens, and "Update project..." backs up to `.studio/backups/`, migrates and can be restored, `Revision.swift`; the Library window shows plain-text states and can locate, remove and move to the Trash, `ProjectLibrary.swift`; the app's settings have one way in, the app menu)

Rules in ShowreelKit: `Setup.swift`, `CheckPanel.swift`, `LookSections.swift`, `Revision.swift`, `ProjectLibrary.swift`

## S

phase S is built (the storyboard strip is an editing timeline that replaces W2b: `Timeline.swift` holds the scale, zoom, ruler, lane sizes, frame and marker layout, `TimelineViews.swift` draws it; the music lane takes drops)

Rules in ShowreelKit: `Timeline.swift`

## M

phase M is built (project memory and history: `.studio/journal.jsonl` appends one line per typed operation, refusals, undos and redos included; `.studio/memory.json` is what Clap keeps through `remember`, `update_memory` and `forget`, checked by `MemoryRules` against personal data, identifiers and instructions; `.studio/sessions.json` holds a summary of each session; a project picked up again gives the model a data block built from these, `ProjectResume`; the History tab of the project settings shows them; the brief's Decisions log and Assumptions come from them; all three files are in the update backups)

Rules in ShowreelKit: `Journal.swift`, `Memory.swift`, `Sessions.swift`
