---
type: phase-report
status: current
phase: RF0
date: 2026-11-10
summary: "Read-only health audit of the code: measured size, ProjectModel clusters, fragile glue, warnings, tests, dead code, and eight ranked refactorings."
app_version: 0.21.0
skill_version: 0.18.2
prompt:
  - "[[phases/RF0/prompt]]"
tags:
  - report
---

# RF0: health audit of the code

Nothing but this report and the generated index changed. No code, comment, test, skill file or version. The graph (`graphify-out/GRAPH_REPORT.md`: 9,077 nodes, 369 communities, hubs such as Film build and playback, Agent UI and blocks, Form system DS3) was used for orientation; the numbers below were measured with scripts over `app-swift/` and are exact unless marked "approximate".

## 1. The facts

| Area | Files | Lines |
|---|---|---|
| ShowreelKit (library) | 88 | 15,536 |
| ShowreelStudio (SwiftUI) | 51 | 12,799 |
| Tests | 61 | 12,975 (793 test functions) |

Sources total 28,335 lines (the prompt's 28,000 still holds; W4b and CR1 added about 600). 1,697 functions, 16 above 60 lines. No `TODO`. Forced `try!` or `!` outside constants: 5 (three `try!` on constant regular expressions in `Assets.swift:57`, `Checks.swift:201`, `Memory.swift:41`, two `!` on non-empty arrays in `SceneStates.swift:103` and `LockedLook.swift:36`): acceptable.

**The 10 largest files**

| File | Lines | What it holds |
|---|---|---|
| ShowreelStudio/ProjectModel.swift | 1,698 | the window's whole state and about 150 functions, 18 types |
| ShowreelStudio/TimelineViews.swift | 709 | the strip: frames, ruler, music row, keys, toolbar |
| ShowreelStudio/LookViews.swift | 648 | the Look editors (fonts, palette, effects, backgrounds), 17 types |
| ShowreelStudio/InspectorViews.swift | 627 | the right side: scene, project and Clap inspectors, viewer |
| ShowreelStudio/ResourceViews.swift | 541 | resources list, thumbnails, audio preview |
| ShowreelKit/Tools.swift | 526 | the agent's tools, one 121-line dispatch (`runText`) |
| ShowreelStudio/WorkspaceViews.swift | 514 | the workspace shell, scene tree, scene pictures |
| ShowreelStudio/Theme.swift | 504 | tokens, 24 small types |
| ShowreelKit/FontFiles.swift | 504 | fonts at build, 14 types |
| ShowreelStudio/ChatModel.swift | 503 | Clap's state, the `AgentUI` hop to the main queue |

(`BuildJob.swift` also has 503.) Only `ProjectModel.swift` is out of scale: 2.4 times the next. 103 of 139 source files hold more than one type, by design (small cohesive types next to their user); that is not a defect.

**Longest functions:** `SelfCheck.run` 266 (a self-test script: fine), `BuildJob.runSteps` 199 (the build state machine: the one worth cutting), `Tools.runText` 121, `Content.planContent` 117, `Drops.run` 113, `MessagesTransport.attempt` 87.

**Clusters of `ProjectModel.swift`** (by its own `MARK`s; lines approximate)

| Cluster | Lines | Depends on | Pure logic that could live in Kit | State |
|---|---|---|---|---|
| Declarations: 89 `@Published`, init, deinit | 116 to 304 | everything | none | yes |
| Right side and Film placement | 304 to 449 | `RailState`, `RightSide` (Kit, RB1 tests) | already Kit | little |
| Build, preview, assemble, fonts at build | 449 to 645, 1481 to 1620 | `FilmBuild`, `BuildJob`, `FontsAtBuild` | the alert and card texts | build tasks |
| Scenes, reel, music, content | 645 to 848 | `ContentOp`, `planContent`, `Reel` | already Kit (operations) | thin relays |
| Timeline and transport (S) | 848 to 1007 | `TimelineScale`, `TimelineNav` | the 30 Hz draft playback step | timer |
| Setup, update, checks | 1007 to 1055 | `ProjectSetup`, `Revision`, `Checks` | none | thin |
| Direct manipulation (W5) | 1055 to 1161 | `Drops`, `ReelRules` | already Kit | thin |
| Operations, action and reaction, documents | 1161 to 1278 | `ProjectOperation`, `StatusLine` | none | toast and flash timers |
| Selection, tabs, import | 1278 to 1388 | `Selection` enums | selection rules | yes |
| Save, reload, restore, copilot context | 1388 to 1455 | `ProjectStore` | none | yes |
| Side types (alerts, pending cards, wizard, sound) | 1455 to 1698 | none | none | value types |

Reading: the model is already mostly a relay (the rules are Kit's and tested); its size comes from state plus 150 small relays. A split by `MARK` into extensions is natural and cheap. **What protects each cut today:** nothing directly. `ShowreelStudio` is an executable target and the tests depend on `ShowreelKit` only, so no test can call `ProjectModel`. 12 test files read `ProjectModel.swift` as text and assert that certain lines exist ("by source"), so a split changes what they must look at. The rules each relay calls are protected by the Kit tests (about 790).

## 2. Findings by area

### 3. Views and logic (confidence: high for the quoted lines, not a full sweep)

- `ReactionViews.swift:272-300`: the build progress card composes its lines (active scenes, testing step, usage, added-up writing time) inside a `TimelineView` body. Rules belong in `BuildProgress` (Kit has `BuildProgress.elapsed`, `sceneLine`, `tokensLine` already). Quote: the 15 `let` lines of the closure.
- `DragDropViews.swift:70`: `resolve(at:item:)` chooses the target under the pointer from frames (smallest area first, slots split by midpoint): geometry that is pure and testable; `Drops.applies` is already Kit.
- `EditorViews.swift:57`: JSON validity through `JSONSerialization` in a view.
- `NewProjectViews.swift:76-86`: creates the folder, the project and the package start, and removes a half-made project: a sequence of file operations in a view (`ProjectStore.create` exists; the folder rollback does not).
- `EngineService.swift:58-72, 109`: cache key, cache folder and `sceneToken` live in the app target; `WorkspaceViews.swift:406` and `StageViews.swift:16` build their own tokens (three parallel recipes for "what makes a picture change").
- Everything else sampled (the 119 `sorted`/`filter`/`map` in `*Views.swift`) is display shaping (pickers, lists), acceptable.

### 4. Boundaries

- Kit knowing about the window: only `Engine.swift` (WebKit, the renderer) and `WindowGuard.swift` (AppKit, added by CR1, deliberately, for its tests). SwiftUI never appears in Kit. Correct direction everywhere else; no cycle found between Kit types (not proven: no tool run).
- `AgentUI` (`AgentUI.swift:17`) has three implementers (`ChatModel`, `SilentUI` in Kit, `NullUI` in `SelfCheck`): it is well used, and it is what lets the agent loop run in tests.
- Singletons: 8 in Studio (`OpenProjects`, `PackageInbox`, `AppSettings`, `LibraryModel`, `EngineService`, `AssetThumbs`, `FontRegistry`, `SceneCapture`) and 2 in Kit (`DragLog`, `ThumbnailCache`). Cost: none can be replaced in a test, and since Studio is not testable, nothing tests them. The one with a visible risk is `EngineService`: see section 5.

### 5. Fragile glue and lifetimes, ranked by the same risk as the crash

Inventory: delegates (`WindowGuard` only swaps one; four classes are `WKNavigationDelegate` or `WKUIDelegate` of web views they own), 4 local key monitors (`StepperKeys`, `StripKeys`, `ListKeys`, plus one in `FormViews`), 9 timers, 8 representables, about 40 `DispatchQueue.main.async(After)` hops, no Combine subscription, `unowned` none, `weak` about 60 (all `[weak self]` in closures).

1. **`SceneCapture.swift:36-43` (my W4b code): the 20 s load timeout is not tied to its load.** The `Task` that sleeps 20 s always calls `finishLoading(false)`; if a later load is in progress then, it resumes that later load's continuation with `false` and the capture fails with "The film page did not load" although it would have worked, and the failure is stored against the scene file until the file changes. Same class as the crash: a deferred call acts on a thing that is no longer the one it was made for. Confidence: high (read), not reproduced. Fix: tag the wait with the load's identity, or cancel the sleep when the load ends.
2. **`FormViews.swift:111-115` stepper repeat timer.** A `Timer` created in a view's closure, invalidated only by the drag's `onEnded`. If the field's view disappears while the button is held (the scene changes, the tab closes) no `onEnded` may come and the 0.12 s timer keeps stepping a stale value. No `onDisappear` cleans it. Confidence: medium, not reproduced.
3. **`EngineService.swift:15, 43-52`: fonts registered by name in a shared renderer.** `registeredFonts` is a set of names for the app's life, while the font file is read from the project asked about. Two projects with a font of the same name and different files share the first one registered. Confidence: medium; the effect is a wrong picture, not a crash.
4. **`SceneThumbModel` tasks (W4b): `thumbTask` and `thumbDelay` are not cancelled in `ProjectModel.deinit` (`ProjectModel.swift:380`).** The loop holds `weak self` and ends when the model dies, so the risk is low; the capture in flight still finishes and writes into a project folder whose window closed.
5. `StripKeys`/`ListKeys` monitors (`TimelineViews.swift:61-75`, `StoryboardListViews.swift:307-321`): installed in `makeNSView`, removed in `dismantleNSView`, handler holds `weak c`. If SwiftUI skips `dismantle` (it did not in the crash trace) the handler stays and only the weak project protects it. Correct; low. `StepperKeys` also stops in `deinit`.
6. `ReelPlayer` (`PlayerViews.swift:8-57`) and `EngineRenderer`: delegate set on a web view the object owns, timer invalidated in `deinit`: correct. `PreviewPane.Coordinator` as `uiDelegate`: WebKit holds it weakly, SwiftUI owns it: correct.
7. `CloseGuardHook`: fixed in CR1 (0.20.1); `dismantleNSView` restores the delegate. The only delegate swap in the app.

### 6. Concurrency and warnings (clean debug build: 20 s, 66 warning lines, about 17 distinct)

| Warning | What it means | Smallest fix |
|---|---|---|
| `EngineService.swift:81,89,98,131` `frameSize` ×13 | a default argument reads a main-actor static from a nonisolated context | `nonisolated static let frameSize` (a `CGSize` is Sendable) |
| `ChatModel.swift:460,464` `isLoading`, `evaluateJavaScript` (the CLAUDE.md warning) | the screenshot helper touches the web view from a nonisolated function | run those two lines inside the existing `onMain` hop, or mark the function `@MainActor` |
| `EnvModel.swift:71,80,83` (the other CLAUDE.md warning) | `self` captured in a `@Sendable` closure while `EnvModel` is main-bound | mark `EnvModel` `@MainActor` and hop with `await MainActor.run` |
| `ChatModel.swift:137,158` | `project` (non-Sendable) captured in a closure | `@MainActor` closure or hop first |
| `SceneAutosave.swift:10` | `SceneFields.invalid` passed where `@Sendable` is wanted | mark the function `@Sendable` or `nonisolated` |
| `ProjectModel.swift:1233` | result of `store.transaction` unused | `_ =` or `@discardableResult` |
| `ProjectModel.swift:1537`, `ChatModel.swift:350` | `weak self` next to an implicit strong capture | capture once, `[weak self]` at the outer level |
| `ReactionViews.swift:280` | `current` is never used (dead line) | delete it |
| `SceneStatus.swift:37` | `Sendable` struct holds a non-Sendable `Scene` | make `ShowreelFile.Scene` `Sendable` (a value type) |
| `FilmState.swift:123` | redundant `public` | delete it |
| `FontFiles.swift:131` | `?? 0` on a non-optional `Int` (dead branch) | delete it |
| `ResourceDetails.swift:153` | `UnsafeMutableRawPointer` to a generic `T` in `AudioFileGetProperty` | restrict `prop` to trivial types or use `withUnsafeMutableBytes` |

`ChatModel` is `@unchecked Sendable` and mixes agent-thread and main-thread state behind `DispatchQueue.main.async` hops (about 12): that is the real concurrency debt, and where Swift 6 strict mode would stop (`ChatModel`, `EnvModel`, the Studio singletons). Not a bug today. Confidence: medium; I read the warnings and the sites, I did not compile in Swift 6 mode.

### 7. Tests

- 793 tests, 61 files; 20 files read Studio sources as text (the only guard on views and the model). Every Kit file has a type that some test names (a weak measure: it does not say what is covered). Studio files whose types no test names: `BlockViews`, `EngineService`, `EnvModel`, `Keychain`, `PlayerViews`, `PreviewPane`, `SceneCapture` (the web view and process glue).
- The slow classes: `BuildTests` (in `SceneTests.swift:311`), `FilmTests` (6 tests, 146 lines: assembly and fonts embedded), `InteractionTests` (26, 452 lines: drops, strip and storyboard interactions), `ChecksTests` (8, 189 lines: the reel's checks). `verify.sh --fast` skips them when their content did not change.
- A refactoring of `ProjectModel` leans on: the Kit rules, the 12 by-source tests, and `ShowreelStudio --selftest` (`SelfCheck.run`). **Characterization tests to write first:** none can reach the model today, so before any split, either (a) move the pure rules out (item 4 of the ranking), or (b) accept that the compiler plus the by-source tests are the net for a pure move.

### 8. Dead code and duplication

Names defined once and never used or tested (17 candidates; protocol methods excluded): `refreshStaleThumbnails` (`SceneThumbModel.swift:24`, W4b: no control calls it), `ProjectModel.setParameter`, `Look.effectList`, `Util.jsonString`, `BuildJob.earlierFile`, `Motion.effectValue`, `Motion.departs`, and Theme members `fontTitle`, `fontLarge`, `textDecorative`, `textAccent`, `textWarning`, `textDanger` (tokens: check against the design intent before deleting). Stale comment: `EngineService.swift:129` still says "A scene has no layers yet (phase W4)". Parallel rules: the picture token recipe (3 copies, section 3); "first text of a scene" (`EngineService.sceneFrames`, `SceneFrameViews.placeholder`, `StageThumb`); `SceneThumbs.states` re-reads `build.json` per scene through `SceneModules.status` (one read per scene, fine at 30 scenes).

### 9. Consistency

- Comments quoting `docs/...` paths: 0 unresolved (checked every path in `Sources`).
- Naming and layout are consistent; one file per feature with several small types is the house style.
- Error handling: `try?` is the norm in views and cache code (silent on purpose for caches; `SceneCapture` and thumbnails now record reasons). Typed operations return cards or refusals with reasons.
- UI principle: the new controls (`Refresh thumbnail`, timing) use `disabledWithReason`; I did not sweep the other 190 views.

### 10. Build health

Clean debug build 20 s (4 cores, 426% CPU), 66 warning lines. `tools/verify.sh --fast`: 38 s wall, ends "VERIFY FAST OK". Nothing slow found. `python3 tools/check.py` passes (run before and after).

**What I did not check:** cycles between types (no tool), the 190 views one by one for disabled controls, Swift 6 strict mode compile, the Python and JavaScript sides of the repo, binary size, runtime performance.

## 3. Ranked refactorings (at most eight)

Order: value over risk, small first. None changes behaviour. Each is a patch of the app (code changes).

1. **Clean the warnings** (section 6 table, the two CLAUDE.md warnings included). Small, low risk. Files: `EngineService`, `ChatModel`, `EnvModel`, `SceneAutosave`, `ProjectModel`, `ReactionViews`, `SceneStatus`/`ShowreelFile`, `FilmState`, `FontFiles`, `ResourceDetails`. Protected by: the full test suite and `--selftest`. Add first: none needed. One session. Why first: it makes every later build output readable, so a new warning shows.
2. **Harden the glue of section 5** (items 1 to 4): tie the load timeout to its load (`SceneCapture`), stop the repeat timer on disappear (`StepperField`), key registered fonts by file as well as name (`EngineService`), cancel the thumbnail tasks in `deinit`. Small, low to medium risk. Protected by: nothing for the web view and timer parts. Add first: a pure `LoadGate` (identity-tagged completion) in Kit with a test, and a test for the font key. One session. Why second: the same class as the crash, and item 1 of it is my own W4b code.
3. **Split `ProjectModel.swift` by its `MARK`s** into `ProjectModel+Build.swift`, `+Timeline.swift`, `+Content.swift` and the like, and move the 17 side types to their own files. A pure move: stored properties and the class stay in the main file (about 300 lines). Medium size, low risk (the compiler checks it). Protected by: the compiler, the by-source tests (12 files read `ProjectModel.swift` by name and must be pointed at the new files in the same change), `--selftest`. Add first: none; update those 12 assertions with the move. One session, **alone, never with a feature**. Place: before PK2 (which touches packages in the model), so PK2 and N land in small files. Must not be combined with any feature phase.
4. **Move the pure rules out of views and the model into Kit, with tests** (section 3): the build progress lines (`BuildProgress`), the drop-target resolution geometry (`Drops`), the JSON validity of the editor, the new-project creation with its rollback (`ProjectStore`), the picture token recipe. Medium, low to medium risk. Protected by: nothing today (it is view code). Add first: a test per rule, written against the current output (characterization), then the move. One session per two rules; best done when a feature phase touches the same view (N touches the build progress card; the drop resolution with the next drag-and-drop change).
5. **Cut `BuildJob.runSteps` (199 lines) and `Tools.runText` (121)** into step functions and a tool table. Medium, medium risk (the build is the heart of the app). Protected by: `BuildTests`, `FilmTests` and the scripted `ScriptedUI` tests. Add first: one characterization test of the full step order with the fake transport. Wait for a phase that touches the build; do not do it in a cleanup session.
6. **Delete dead code and unify the duplicates** (section 8): the 17 candidates after checking each (Theme tokens against the design), the three picture-token recipes, the stale W4 comment. Small, low risk. Protected by: the compiler. One session, with item 1 if wanted.
7. **Make the app target testable**: split `ShowreelStudio` into a library (models and views, `ShowreelStudioUI`) and a thin executable, so a test can create a `ProjectModel` and call `togglePlay`, `focusScene`, `refreshThumbStates`. Large, medium risk (the package layout, `make-app.sh`, `verify-bundle.sh` and `SelfCheck` all assume the current targets). Gain: the 20 by-source tests can become behaviour tests and the model gets a real net. Wait: do it after item 3, and only if the owner wants the model tested directly; it is a change of structure, not of code.
8. **Replace the by-source tests by behaviour tests** as logic moves to Kit (items 4 and 7). Medium, low risk, spread over the phases that touch each area. Not a session of its own.

Items 1, 2 and 6 can be done in one session each now. Item 3 in one session before PK2. Items 4, 5, 8 ride on feature phases that touch the same files (N, the next drag-and-drop change, the next build change). Item 7 waits for the owner's decision.

## 4. What not to do

- **A full rewrite.** The audit found a 28,000-line code base with no TODO, rules in a tested library, 793 tests and a 20 s clean build. The one oversized file is a relay of tested rules. A rewrite would throw away the 790 Kit tests' fit with the code for no measured gain.
- **One type per file.** 103 of 139 files group small cohesive types by design; separating them would add files and no clarity (only the 18 types in `ProjectModel.swift` are worth moving, inside item 3).
- **Swift 6 strict mode now.** The warnings are 17 distinct sites; fix them (item 1) and revisit strict mode after item 7.
- **Splitting `TimelineViews`, `LookViews`, `InspectorViews`** (600 to 700 lines each): each is one cohesive screen; the size is not a problem until a phase has to touch it and finds it hard to read.
- **Refactoring and building in the same change**, for any item above.

## 5. Questions for the owner

None. Item 7 is the only one that needs a decision; I did not create a note because it can wait until item 3 is done.

## Verification

Ran `python3 tools/check.py` (all checks passed) and `tools/verify.sh --fast` (VERIFY FAST OK), the same result as before the phase. No rebuild, no version bump. Files touched: this report, `docs/Claude/Index.md`, `docs/Home.md` and `docs/Claude/phases-done.md` (generated by `docs_index.py --write`). Scratch output (a clean build) went to the session's scratchpad outside the repository.
