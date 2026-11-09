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

## X

phase X is built (the verification tools: `tools/verify.sh` is one command with two modes. `--fast` runs, inside a phase, the app and shared checks, the debug build and the tests without the four slow classes (BuildTests, FilmTests, InteractionTests, ChecksTests), skips the app self-test, and runs the skill's own checks and the slow classes only when their content changed since the last complete pass, a fingerprint kept outside the repository by `tools/verify_state.py`; it ends with "VERIFY FAST OK (pas un contrôle de fin de phase)". The complete mode, for the end of a phase, runs every repo check in parallel with the build, every test with `--parallel` and the app self-test, and saves the fingerprints after a pass. The stale-binary guard is decided by content, not by date: `tools/build_fresh.sh` compares the fingerprint of the Swift sources with the stamp of the last good build, so touching a file without changing it does not fail and a real change that was not built does; `make-app.sh` and `tools/rebuild-app.sh` use it, the app is closed only after the build was found valid, and `tools/test_build_guard.sh` tests these guards)

Rules in ShowreelKit: none (repository tooling: `tools/verify.sh`, `tools/verify_state.py`, `tools/build_fresh.sh`, `tools/test_build_guard.sh`)

## Q3

phase Q3 is built (the Clap tab of the inspector is titled Ask Clap, with one icon, `ClapMark`; a selector at its top holds Conversation, Memory, Sessions and Journal, `ClapSection` and `ClapHistoryPane`, which are the history views of phase M moved out of the project settings; the project settings keep Project and Look; the words "copilot" are gone from the interface; the labels of the selector were later set in English by Q4)

Rules in ShowreelKit: none (views and `ProjectModel` only; the history rules stay in `Journal.swift`, `Memory.swift`, `Sessions.swift`)

## Q2

phase Q2 is built (scene states WIP, Validated, Locked, Ditched, `SceneState`: the older words ok, open and modify are read as Validated, WIP and WIP with a note, and the file moves to format revision 2 through "Update project"; one check in `ProjectStore.plan` refuses any change to a locked scene, from the user, from a drop and from Clap, with the reason; only a Validated scene can be locked, by the typed operation `sceneLock`, one card, undoable; a state badge with a menu, "Lock all validated", `lock_scene` for Clap)

Rules in ShowreelKit: `SceneStates.swift`

## Q4

phase Q4 is built (the labels of the Ask Clap selector are in English; a change of the global look that would redraw locked scenes inheriting it lists them on its card, "S02 and S05 are locked and inherit this look", and the user applies anyway or refuses, for the user's edits and for Clap's `update_decision` alike, apply-directly never skipping that card; a scene that has its own value for the changed part is not concerned; a locked scene whose inherited look changed is stale, says why through `Availability.regenerate`, and is never generated again without unlocking)

Rules in ShowreelKit: `LockedLook.swift`, `SceneStates.swift`, `FilmState.swift` (`Availability.regenerate`)

## V1

phase V1 is built (the film as one file per scene: the skill's `scripts/assemble.py`, run by `build.py`, puts `scenes/<ID>.js` and `reel.js` into `main.js` with no AI and the same bytes for the same files, shows a placeholder frame for a scene with no file and lists it in `assembly.json`; a version with only a hand-written `main.js` builds as before; `SceneGeneration` asks the model for one or several scenes only, writes only those files, refuses a locked scene, is one card for Clap's `generate_scenes`; `.studio/build.json` records for each scene the fingerprint of its inputs and of its file, so that a scene is not generated, up to date or stale, plus a flag when the file was edited by hand)

Rules in ShowreelKit: `SceneModules.swift`, `SceneGeneration.swift`

## Q5

phase Q5 is built (action/reaction: one model says for each element or action whether it is available, why not and how to get it back, `Availability` with `ProjectActivity`; every typed operation, undo, redo, files added, updates and file saves are refused while a build runs; elements a proposal of Clap waits on are read-only and marked, with a banner to accept or refuse all; a chip says what Clap is doing; a build has a progress panel and Cancel build; a status line says what each change did, with Undo, and a refusal says why; closing, quitting, updating or restoring with work in progress asks first, `CloseGuard`; `disabledWithReason` is the standard disabled control; the details are in `docs/q5-report.md`)

Rules in ShowreelKit: `Availability.swift`

## V2

phase V2 is built (the state of the film and of each scene from fingerprints, never stored by hand: `FilmBuild.status`; Assemble, with no AI, writes film.json, assembles and tests on a copy and only a green result replaces the version, `FilmAssembly`; the version that is read is the last one built and tested green, never a folder a stopped build left behind; Play plays only the assembled film and assembles a stale one first; banners, a counter in the reel's header and a build mark on each scene; the old single-file format plays as it is; the free instruction of a transition is marked pending until a generation read it, `TransitionNotes`; `assemble_film` for Clap; the details are in `docs/v2-report.md`)

Rules in ShowreelKit: `FilmState.swift`, `SceneModules.swift`

## R

phase R is built (release notes: `RELEASE-NOTES-SKILL.md` and `RELEASE-NOTES-APP.md`, one section per version, and the app's own short register `CHANGELOG-APP.md`; the app's version has one source, `app-swift/shared/app-version.json`, written into the bundle by `make-app.sh` and shown with the skill's version in About Showreel Studio, `AppInfo`; `tools/bump_app.py` ships an app version and, like `tools/bump.py`, refuses without the section of the new version; `tools/check.py` fails when versions, registers, records and notes disagree)

Rules in ShowreelKit: `AppInfo.swift` (the rest is repository tooling: `tools/bump_app.py`, `tools/app_hash.py`, `tools/check.py`)

## F

phase F is built (fonts in the film: each font of the Look shows Needs files, Preview only or Embedded; the typed operation Add font files, with one card (the font, the open Google Fonts repository from the skill's fixed list, the licence, the files and size, the network), downloads only the weights the Look uses into `assets/fonts/<family>/` and approves them in the manifest, undoable, also proposed by Clap with `add_font_files`; the build and the assembly embed the approved files through `fonts.json`, merged by the skill's `build.py`, and show an orange Fonts step when a font has no file; adding files makes the film stale and no scene; a dropped font file shows its family and weight and needs its licence note before approval)

Rules in ShowreelKit: `FontFiles.swift`, `FontInfo.swift`

## Q6

phase Q6 is built (the temporary marks, a proposal waiting or the build running, on the reel's frames, the tree and the resources as on the list, with one layout rule for the badges, the review state then the build state, `MarkLayout`; the remaining disabled controls say why, Undo and Redo in the Edit menu included; the offer to generate lists the scenes with no file and the stale ones, leaves out the locked ones with their reason, and asks a separate confirmation before it overwrites a file edited by hand)

Rules in ShowreelKit: `Marks.swift`, `FilmState.swift` (`GenerationOffer`), `SceneGeneration.swift`

## P5

phase P5 is built (project creation and the project form: a new project is set up in one way, chosen once at creation and never switched, Wizard (Clap leads a short interview with the existing question cards, then proposes a starting pack as cards, `propose_starter_pack`, one for the base configuration, one for the look, one for the scenes and their order, one for the music, that the user accepts one by one or all at once, through the existing proposals banner) or Manual (a form in sections: formats as tiles, duration with presets and a live feasibility line, film languages as chips, a compact brief with examples as placeholders, three control-level cards); the words Beginner and Expert are gone and the stored setting is "wizard" or "manual" (the old values are still read); the Wizard card is disabled without an API key, with its reason and way; the base configuration has five parts with an "n of 5 set" progress and the workspace opens only when it is complete; the interview gate is derived from it, with no button)

Rules in ShowreelKit: `Setup.swift` (`ProjectSetup.progress`, `ProjectSetup.durationHint`, `ProjectLanguages`, `Availability.wizard`, `ShowreelFile.gateState`), `Wizard.swift` (`WizardInterview`, `StarterPack`), `ProjectStore.swift` (`StudioSettings`)

## R1

phase R1 is built (the Resources tab: resources grouped by type, Images, Sounds, Music, Fonts and Other, then by state, with folding remembered per project; the selected resource shown in the centre, an image, a sound or a music file with its tags, its cover and a small player, or a font specimen, by one priority rule; tags kept in `showreel.json`, with the "placeholder" tag standing for the manifest status; four states derived from the manifest, Available, Used in scenes (derived from the scenes, never typed), Proposal and Needs attention; a file added by the user is approved at once when it passes the automatic checks (resolution, weight, a name that suggests real data, a copyright notice in the metadata, a font's licence and embedding flag), otherwise it needs attention, stays in `assets/source/`, is hidden from Clap and refused by the build until the rights question is answered, a risk is accepted with a reason, or the file is replaced)

Rules in ShowreelKit: `ResourceStates.swift`, `ResourceChecks.swift`, `FontInfo.swift`, `Assets.swift`

## PK1

phase PK1 is built (design packages, with no AI: the `.studiopack` format, a zip with `package.json` first, then `design.json`, `resources.json` and `assets/`, read and written by the app itself with no other tool and checked entirely before any entry is read (names, symbolic links, sizes, number of entries, expected file types, nested archives refused); the manifest, the canonical SHA-256 hash that leaves the dates out and ignores the order of keys, and the integrity result (matches, modified, damaged); the author as a display name, never an e-mail, never taken from the system account; the library in Application Support, one folder per id and version with the rights confirmation of that version; "Save design as package" in the project settings (what goes in, name, author, note, a new version of the same id with a mandatory note, export and Show in Finder, not an undoable change of the project); "Start from a package" at project creation in the Wizard and in Manual, the Wizard asking only what the package leaves open; the import card with the rights box, "Not signed" and the integrity decision, opened by double-click, drop or Open a .studiopack; the origin recorded in showreel.json under `package`, and the journal line with the version, the hash and the confirmation; the document type registered in Info.plist by make-app.sh and checked by `--selftest` and `tools/verify-bundle.sh`)

Rules in ShowreelKit: `PackageZip.swift`, `DesignPackage.swift`, `PackageLibrary.swift`, `PackageProject.swift` (`PackageSave`, `PackageStart`, `Availability.savePackage`), `Wizard.swift` (`WizardInterview.questions(for:)`), `Assets.swift` (`holdReason`), `ShowreelFile.swift` (`PackageOrigin`)

## C1

batch C1 is built (corrections from the owner's test session: a resource dragged from the grouped list of Resources always ends with an effect or a reason in the bottom line, and the drop remembers the last valid target of the pointer; the cover of an MP3 is read through AVFoundation, then from the ID3v2 picture frame itself (2.2, 2.3, 2.4), then the old audio file property; the font repository errors keep the HTTP code and the address, a call limit is told apart and offers Try again; the optional network test checks every folder of `fonts-free.json`; the question before a Build or an Assemble when a Look font has no file, with its three choices recorded in the journal; the app's own instructions to Clap are kept in the transcript with the origin "app" but shown as a short status line, and the Sessions view can show them; the durations 30, 45, 60, 75 and 90 from one constant; the eye of the reel frames, the Mark as validated button of the Look editors (the style gate is derived from the look) and the repeated thumbnail removed)

Rules in ShowreelKit: `Drops.swift`, `ResourceChecks.swift` (`AudioMetadata.artwork`, `ID3Artwork`), `FontFiles.swift` (`FontRepositoryError`, `FontLookupError`, `FontsAtBuild`), `ChatStore.swift` (`ChatRecord.origin`, `ChatDisplay`), `Setup.swift` (`ProjectSetup.durationChoices`, the style gate), `Timeline.swift`

