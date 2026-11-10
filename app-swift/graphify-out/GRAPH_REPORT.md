# Graph Report - app-swift  (2026-11-10)

## Corpus Check
- 233 files · ~319,571 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 2 file(s) not represented in the graph (top: .icns 1, .csv 1)

## Summary
- 6161 nodes · 20129 edges · 247 communities (180 shown, 67 thin omitted)
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 3140 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6f73d2ba`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- AgentError
- ProjectImporter
- .apply
- ContentItemRow
- .run
- LibraryEntry
- .all
- View
- ProjectModel
- CaseIterable
- Sendable
- ProjectStore
- .body
- Theme
- .load
- Codable
- .runSteps
- .timeline
- WorkspaceViews.swift
- View
- .loadShowreel
- AssetRow
- CheckResult
- Motion
- ShowreelKit
- ProjectStore
- CheckTarget
- StoryboardSection
- TimelineTests
- PrimaryButtonStyle
- FrameView
- ProjectOperation
- LibrarySplit
- ProjectModel.swift
- MotionTokens
- AnthropicTransport
- ProjectForm
- Resources
- URL
- PackageTests
- ScriptedUI
- .operation
- .build
- ShowreelFile
- ChatRecord
- MusicAnalysis
- AppSettings
- LookSection
- AgentStop
- String
- SwiftUI
- SceneStatusKind
- .run
- SceneRun
- ElementRef
- RailEntry
- .read
- DragItem
- SceneGroupNodes
- RightPanel
- SceneForm
- DragDropViews.swift
- ChatModel
- Availability
- DragState
- .add
- .plan
- DropTarget
- IconRole
- .root
- FL1Tests
- RF2Tests
- PackageError
- ReelPlayer
- BF1Tests
- RailState
- C1Tests
- SceneStateTests
- ChatItem
- TransitionEdit
- Context
- SceneCapture
- .remember
- Double
- DecisionKey
- StageFrame
- UndoLog
- Unavailable
- .run
- JournalEntry
- ResourceFlowTests
- LibraryPackage
- SceneModuleTests
- StoryboardList
- FontRepositoryError
- SavePackageSheet
- EngineRenderer
- FontPayload
- FontFilesTests
- DS3Tests
- MarkdownTable
- CR1Tests
- DesignPackage
- .finish
- Foundation
- ContentTimes
- SceneLookGroup
- SceneThumbs
- Kind
- EngineService
- .refresh
- Look
- MusicToolbarButton
- .save
- WhatClapKnows
- StepperField
- .run
- ProjectTab
- AS1Tests
- LibraryModel
- DiffLine
- MusicToolbarState
- SoundOwnership
- ShowreelStudioApp
- ContentItem
- DesignBoard
- FileKind
- W4bTests
- fakeSfnt
- Cause
- .state
- NumericField
- .lines
- MT1Tests
- ProjectTests
- AgentUI
- .estimate
- BG1cTests
- EditSession
- StudioSettings
- FilmBuild
- WindowGuard
- .seconds
- EnvModel
- TimelineTests
- ThumbnailCache
- CheckLevel
- WebPreview
- .stream
- DragRun
- Surface
- WizardInterview
- WizardStep
- BA2Tests
- EngineTests
- .run
- engine-host.js
- Motion
- Int
- FontInfo
- Brief
- XCTestCase
- BG2ATests
- RL1Tests
- LibraryRules
- .frame
- .pending
- MessagesTransport
- DS1Tests
- LookSettingsTests
- SimplePlayer
- EnginePalette
- PF1Tests
- ParameterKey
- Text
- ChatView.swift
- Brief: Demo
- ProcessSpec
- .entries
- Value
- AutoCommit
- MemoryTests
- RightsAnswer
- ProjectModel
- LibraryState
- PackageDesign
- HoldRepeat
- State
- CL1Tests
- Kind
- StoryboardSceneRow
- T2Tests
- AssetTests
- .encode
- AppInfo
- PaletteRole
- MemoryKind
- Util.swift
- DragLog
- Kind
- OperationToolTests
- DS3bTests
- .note
- State
- FilmPlacement
- DocState
- FT1Tests
- DS3Tests
- .status
- .ratio
- .missing
- OpenProjects
- InlineEdit
- ListKeys
- StripKeys
- Link
- .systemPrompt
- Status
- FIX2Tests
- Brief
- SnapLevel
- make-app.sh
- Package.swift
- addendum.md
- generated/storyboard.md
- generated/style-sheet.md
- export-sample/storyboard.md
- export-sample/style-sheet.md
- PackCard

## God Nodes (most connected - your core abstractions)
1. `ProjectStore` - 500 edges
2. `ShowreelFile` - 289 edges
3. `ProjectModel` - 261 edges
4. `Text` - 201 edges
5. `SceneEdit` - 152 edges
6. `Theme` - 130 edges
7. `ShowreelKit` - 119 edges
8. `AssetRow` - 102 edges
9. `makeTempDir()` - 100 edges
10. `AgentError` - 93 edges

## Surprising Connections (you probably didn't know these)
- `Showreel Studio (native macOS app)` --references--> `ProjectStore`  [INFERRED]
  README.md → Sources/ShowreelKit/ProjectStore.swift
- `Showreel Studio (native macOS app)` --references--> `Shell`  [INFERRED]
  README.md → Sources/ShowreelKit/Tools.swift
- `Showreel Studio (native macOS app)` --references--> `ShowreelFile`  [INFERRED]
  README.md → Sources/ShowreelKit/ShowreelFile.swift
- `Showreel Studio (native macOS app)` --references--> `ProjectImporter`  [INFERRED]
  README.md → Sources/ShowreelKit/ProjectImporter.swift
- `Showreel Studio (native macOS app)` --references--> `AgentUI`  [INFERRED]
  README.md → Sources/ShowreelKit/AgentUI.swift

## Import Cycles
- None detected.

## Communities (247 total, 67 thin omitted)

### Community 0 - "AgentError"
Cohesion: 0.09
Nodes (8): Change, OperationCard, Operations, ScenePlace, SceneRules, AgentError, .errorDescription, msg

### Community 2 - ".apply"
Cohesion: 0.04
Nodes (10): DecisionChange, SceneEdit, ChecksTests, LockedLookTests, .otherBackground, makeTempDir(), SceneTests, .scenes (+2 more)

### Community 3 - "ContentItemRow"
Cohesion: 0.06
Nodes (30): CatalogueChoice, ContentItemRow, .animation, .body, .colorChoice, .colour, .dirty, .icon (+22 more)

### Community 4 - ".run"
Cohesion: 0.14
Nodes (5): BG1Tests, .skill, JobModel, BG2BTests, .skill

### Community 5 - "LibraryEntry"
Cohesion: 0.21
Nodes (6): LibraryEntry, ProjectLibrary, .archived, .defaultURL, .visible, Wrapper

### Community 6 - ".all"
Cohesion: 0.08
Nodes (44): Partition, IconLabel, .body, IconRow, .body, AnimatedThumb, BackgroundMenu, .body (+36 more)

### Community 7 - "View"
Cohesion: 0.05
Nodes (37): .name, CanvasBackground, DestructiveButtonStyle, EnvironmentValues, .fieldError, .fieldVerticalPadding, FieldErrorKey, FieldErrorModifier (+29 more)

### Community 8 - "ProjectModel"
Cohesion: 0.04
Nodes (26): DocReport, .needsDecision, ProjectModel, .applyDirectly, .buildBusy, .canRedo, .canUndo, .filmPlayAvailability (+18 more)

### Community 9 - "CaseIterable"
Cohesion: 0.05
Nodes (38): ControlLevel, auto, guided, .help, precise, .title, SceneGroup, composition (+30 more)

### Community 10 - "Sendable"
Cohesion: 0.04
Nodes (75): Proposal, Alert, BuildPolicy, allowed, refused, ClapWork, applying, thinking (+67 more)

### Community 11 - "ProjectStore"
Cohesion: 0.11
Nodes (10): Book, FilmRecord, Record, SceneModules, State, notGenerated, stale, upToDate (+2 more)

### Community 12 - ".body"
Cohesion: 0.05
Nodes (15): .snapshot, Film, GenerationOffer, .bannerLine, .overwriteLine, .staleLine, .instructionText, Revision (+7 more)

### Community 13 - "Theme"
Cohesion: 0.04
Nodes (64): DiffView, .body, ChipStyle, ReelFrameMarks, .body, StageThumb, .backdropToken, .body (+56 more)

### Community 14 - ".load"
Cohesion: 0.04
Nodes (16): BuildLog, Composition, LookChoices, LookOverrides, .showreelProblem, ProjectBackup, ProjectFormat, .backupsDir (+8 more)

### Community 15 - "Codable"
Cohesion: 0.09
Nodes (18): JSONValue, .any, array, bool, null, number, object, string (+10 more)

### Community 16 - ".runSteps"
Cohesion: 0.07
Nodes (20): Act, handEdited, keep, retest, reuse, skipped, write, BuildJob (+12 more)

### Community 17 - ".timeline"
Cohesion: 0.16
Nodes (8): .film, .filmEnd, TimelineNav, .fitLength, .sceneAtPlayhead, .sceneUnderPlayhead, .timelineLength, .transport

### Community 18 - "WorkspaceViews.swift"
Cohesion: 0.06
Nodes (32): AssetFiles, AssetRow, .statusColor, .symbolName, CheckRow, .body, ChecksLibrary, .body (+24 more)

### Community 19 - "View"
Cohesion: 0.08
Nodes (35): AskClapPane, CenterPane, .selectedResource, ClapPanel, .body, FilesInspector, .body, InspectorContent (+27 more)

### Community 20 - ".loadShowreel"
Cohesion: 0.06
Nodes (12): .deletePrompt, .file, .file, .file, .file, LookTests, .file, .order (+4 more)

### Community 21 - "AssetRow"
Cohesion: 0.07
Nodes (32): AssetRow, .name, .sceneIDs, .hiddenFromClap, ResourceState, available, declined, .key (+24 more)

### Community 22 - "CheckResult"
Cohesion: 0.21
Nodes (5): CheckResult, Checks, ChecksPanel, .body, .results

### Community 23 - "Motion"
Cohesion: 0.09
Nodes (13): ClapPulse, Nudge, NudgeEffect, .animatableData, Pop, RunMark, .body, SelectionSlide (+5 more)

### Community 25 - "ProjectStore"
Cohesion: 0.04
Nodes (25): ContentEdit, DropPlan, Outcome, .isValid, operation, refused, .text, DropVerdict (+17 more)

### Community 26 - "CheckTarget"
Cohesion: 0.09
Nodes (22): CheckEntry, .id, CheckGroup, build, .id, music, project, resources (+14 more)

### Community 27 - "StoryboardSection"
Cohesion: 0.15
Nodes (11): LockAllValidatedButton, LockedLookSheet, ResourcesSection, .body, SectionHeader, .body, StoryboardSection, .body (+3 more)

### Community 28 - "TimelineTests"
Cohesion: 0.08
Nodes (14): CoreGraphics, FrameElements, FrameLayout, LabelMode, id, idAndName, none, shortID (+6 more)

### Community 29 - "PrimaryButtonStyle"
Cohesion: 0.04
Nodes (64): ValidateButton, .body, .passed, BuildBlockView, .body, BuildPanel, .body, .versionsRow (+56 more)

### Community 30 - "FrameView"
Cohesion: 0.09
Nodes (26): TimedScene, .length, FilmStrip, .body, FrameView, .body, .scene, .selected (+18 more)

### Community 31 - "ProjectOperation"
Cohesion: 0.05
Nodes (29): ContentOp, add, move, remove, update, .kind, .target, ProjectOperation (+21 more)

### Community 32 - "LibrarySplit"
Cohesion: 0.14
Nodes (7): LibrarySplit, ResourcesState, collapsed, expanded, open, LibraryPane, .body

### Community 33 - "ProjectModel.swift"
Cohesion: 0.06
Nodes (25): Kind, applied, refused, ProjectOperation, .buildPolicy, .targets, StatusLine, Choice (+17 more)

### Community 34 - "MotionTokens"
Cohesion: 0.07
Nodes (28): Curve, accelerate, decelerate, overshoot, panelSpring, Look, Motion, alternate (+20 more)

### Community 35 - "AnthropicTransport"
Cohesion: 0.10
Nodes (21): OutputBudgeted, RequestStats, .line, RequestWatched, AnthropicTransport, .contentTimeout, .idleTimeout, .lastRequest (+13 more)

### Community 36 - "ProjectForm"
Cohesion: 0.16
Nodes (6): Part, brief, format, header, ProjectForm, .body

### Community 37 - "Resources"
Cohesion: 0.21
Nodes (6): Resources, ViewerSubject, designBoard, film, resource, .isPreviewingResource

### Community 38 - "URL"
Cohesion: 0.08
Nodes (11): Assets, .activity, Flag, Kind, quality, rights, sensitive, ResourceChecks (+3 more)

### Community 40 - "ScriptedUI"
Cohesion: 0.13
Nodes (8): Agent, .isAborted, .systemText, .transcript, AgentLoopTests, ScriptedTransport, textBlock(), toolUse()

### Community 41 - ".operation"
Cohesion: 0.18
Nodes (10): Catalogue, CatalogueKind, background, effect, .title, transition, CatalogueTarget, item (+2 more)

### Community 42 - ".build"
Cohesion: 0.15
Nodes (9): Availability, OfferedResource, .id, PackageOffer, .isEmpty, PackageSave, PackageSelection, PackageStart (+1 more)

### Community 43 - "ShowreelFile"
Cohesion: 0.04
Nodes (19): ShowreelFile.Scene, LockedLook, LockedLookWarning, .advice, .headline, ShowreelFile, .isOutdated, .isStudioOwned (+11 more)

### Community 44 - "ChatRecord"
Cohesion: 0.12
Nodes (9): ChatDisplay, ChatRecord, .fromApp, ChatStore, .sessionID, .sessions, Line, bubble (+1 more)

### Community 45 - "MusicAnalysis"
Cohesion: 0.12
Nodes (13): Audio, Breakdown, MusicAnalysis, .breaks, .dropTimes, .returns, .sections, .strongestDrop (+5 more)

### Community 46 - "AppSettings"
Cohesion: 0.10
Nodes (13): Security, AppSettings, .advanced, .baseURL, .bearer, .idleTimeout, .keyIfLoaded, .modelName (+5 more)

### Community 47 - "LookSection"
Cohesion: 0.12
Nodes (15): LookSection, background, effects, fonts, .id, looks, moods, palette (+7 more)

### Community 48 - "AgentStop"
Cohesion: 0.10
Nodes (24): AgentLimits, AgentStop, cancelled, emptyReply, finished, .line, other, refused (+16 more)

### Community 49 - "String"
Cohesion: 0.06
Nodes (15): AssetStatus, approved, excluded, hold, placeholder, proposed, ContentRules, SceneThumbQueue (+7 more)

### Community 50 - "SwiftUI"
Cohesion: 0.07
Nodes (12): AppKit, ClapMark, .symbol, PackageAuthorMemory, .name, Box, ShowreelFile.Scene, .durationLabel (+4 more)

### Community 51 - "SceneStatusKind"
Cohesion: 0.07
Nodes (24): .statusRoles, RailGroup, centre, right, SceneStatuses, SceneStatusInput, SceneStatusKind, layoutWarning (+16 more)

### Community 52 - ".run"
Cohesion: 0.17
Nodes (6): BuildReport, .built, .harnessClean, .ok, .smokeClean, BuildRunner

### Community 53 - "SceneRun"
Cohesion: 0.09
Nodes (23): Build, .generationSeconds, .notice, BuildProgress, ClapActivity, ClapPhase, preparing, reading (+15 more)

### Community 54 - "ElementRef"
Cohesion: 0.11
Nodes (21): ElementRef, asset, file, item, scene, setting, BlockedNotice, .body (+13 more)

### Community 55 - "RailEntry"
Cohesion: 0.08
Nodes (23): ClapIndicator, .badge, .label, Motion, dot, none, pulse, RailEntry (+15 more)

### Community 56 - ".read"
Cohesion: 0.12
Nodes (8): DetailFormat, DetailGroup, DetailRow, ResourceDetails, ResourceDetailsCache, ResourceDetailsReader, .body, .body

### Community 57 - "DragItem"
Cohesion: 0.13
Nodes (13): DragItem, background, content, effect, files, look, pack, palette (+5 more)

### Community 58 - "SceneGroupNodes"
Cohesion: 0.27
Nodes (8): NodeOrigin, inherited, overridden, SceneGroupNodes, .id, SceneNode, SceneTree, .on

### Community 59 - "RightPanel"
Cohesion: 0.09
Nodes (18): PaneWidth, PanelLayout, .inspectorWidth, .isStandard, .libraryWidth, .resourcesState, .settingsWidth, .splitFraction (+10 more)

### Community 60 - "SceneForm"
Cohesion: 0.08
Nodes (17): Mark, saved, updated, SceneAutosave, SavedMark, .body, SceneForm, .blockedReason (+9 more)

### Community 61 - "DragDropViews.swift"
Cohesion: 0.11
Nodes (18): DragChip, .body, DragRow, .body, DragSource, DropGlow, .body, DropRegistration (+10 more)

### Community 62 - "ChatModel"
Cohesion: 0.10
Nodes (7): ChatModel, .activity, .hasKey, End, .body, .body, .button

### Community 63 - "Availability"
Cohesion: 0.22
Nodes (5): Availability, available, .isAvailable, unavailable, .why

### Community 64 - "DragState"
Cohesion: 0.19
Nodes (5): DragState, .lastValid, .refusal, WorkspaceDropDelegate, .dnd

### Community 66 - ".plan"
Cohesion: 0.07
Nodes (11): ProjectActivity, SceneSwitches, Switch, .body, AvailabilityTests, .act, .everyOperation, .file (+3 more)

### Community 67 - "DropTarget"
Cohesion: 0.12
Nodes (15): DropResult, Drops, DropTarget, assetSlot, contentItem, contentSlot, .isSlot, librarySlot (+7 more)

### Community 68 - "IconRole"
Cohesion: 0.06
Nodes (29): IconRole, checks, checksAttention, .isPictogram, layoutFullWidth, layoutUnderPreview, lockClosed, lockOpen (+21 more)

### Community 69 - ".root"
Cohesion: 0.09
Nodes (6): Tools, ScriptedUI, .skill, .skill, SetupFlowTests, .file

### Community 70 - "FL1Tests"
Cohesion: 0.10
Nodes (12): ReelFrame, ReelLayout, StripLayer, background, frames, grid, musicMarkers, playhead (+4 more)

### Community 71 - "RF2Tests"
Cohesion: 0.22
Nodes (3): FontIdentity, LoadGate, RF2Tests

### Community 72 - "PackageError"
Cohesion: 0.14
Nodes (14): Compression, Entry, Header, PackageError, .errorDescription, invalid, newerFormat, notAnArchive (+6 more)

### Community 73 - "ReelPlayer"
Cohesion: 0.13
Nodes (5): FilmViewer, .body, .current, ReelPlayer, ReelWebView

### Community 75 - "BF1Tests"
Cohesion: 0.10
Nodes (5): OutputCap, .onOutput, BF1Tests, BudgetedTransport, CapStub

### Community 76 - "RailState"
Cohesion: 0.12
Nodes (6): RailState, .inspectorMarked, RightSide, .panel, RB1Tests, .views

### Community 77 - "C1Tests"
Cohesion: 0.16
Nodes (4): AudioMetadata, Box, ID3Artwork, C1Tests

### Community 78 - "SceneStateTests"
Cohesion: 0.17
Nodes (4): SceneLock, SceneStates, .body, SceneStateTests

### Community 79 - "ChatItem"
Cohesion: 0.19
Nodes (9): ChatItem, ChoiceOption, ChoiceQuestion, OperationState, ProposalState, QuestionCard, .body, .complete (+1 more)

### Community 80 - "TransitionEdit"
Cohesion: 0.06
Nodes (9): TransitionEdit, TransitionList, FilmTests, .file, ReelTests, .file, UI1Tests, .file (+1 more)

### Community 81 - "Context"
Cohesion: 0.12
Nodes (9): CloseGuard, Context, closeWindow, openOtherProject, quit, restoreBackup, updateProject, CloseGuardHook (+1 more)

### Community 82 - "SceneCapture"
Cohesion: 0.10
Nodes (8): LoadOutcome, failed, .isTransient, loaded, superseded, timedOut, CaptureError, SceneCapture

### Community 83 - ".remember"
Cohesion: 0.20
Nodes (3): MemoryEntry, MemoryFile, MemoryRules

### Community 84 - "Double"
Cohesion: 0.29
Nodes (4): TimelineScale, Viewport, .zoom, .body

### Community 85 - "DecisionKey"
Cohesion: 0.06
Nodes (28): DecisionKey, background, backgroundMood, effectsPack, moods, palette, textFont, .title (+20 more)

### Community 86 - "StageFrame"
Cohesion: 0.31
Nodes (7): Stage, StageFrame, .aiDecides, .images, .sounds, .texts, StageItem

### Community 87 - "UndoLog"
Cohesion: 0.10
Nodes (10): Capture, UndoEntry, UndoLog, .canRedo, .canUndo, .redos, .redoTitle, .undoCount (+2 more)

### Community 88 - "Unavailable"
Cohesion: 0.24
Nodes (4): ProjectActivity.Snapshot, Reasons, Unavailable, .message

### Community 89 - ".run"
Cohesion: 0.11
Nodes (6): Killer, OutputBuffer, .timedOut, Result, Shell, ToolResult

### Community 90 - "JournalEntry"
Cohesion: 0.11
Nodes (8): Journal, JournalEntry, JournalLinks, JournalFilter, .body, JournalRow, .body, .symbol

### Community 91 - "ResourceFlowTests"
Cohesion: 0.18
Nodes (5): .group, ResourceAttention, .isEmpty, ResourceFlowTests, .file

### Community 92 - "LibraryPackage"
Cohesion: 0.12
Nodes (10): .currentAppVersion, PackageVersion, LibraryPackage, .id, .isConfirmed, PackageConfirmation, PackageLibrary, .standard (+2 more)

### Community 93 - "SceneModuleTests"
Cohesion: 0.15
Nodes (4): SceneModuleTests, .file, .skill, SceneWriterModel

### Community 94 - "StoryboardList"
Cohesion: 0.10
Nodes (15): Entry, .id, scene, transition, NotIn, .wayBack, .why, SceneRow (+7 more)

### Community 95 - "FontRepositoryError"
Cohesion: 0.17
Nodes (4): FontRepositoryError, .errorDescription, GoogleFontsSource, RepoFile

### Community 96 - "SavePackageSheet"
Cohesion: 0.13
Nodes (9): PackageAuthor, PackageImportSheet, .body, PackageSettingsFooter, .body, SavePackageSheet, .continuation, .continuing (+1 more)

### Community 98 - "FontPayload"
Cohesion: 0.17
Nodes (11): FontEmbedding, FontEntry, FontFile, FontPayload, .fontFiles, LookFontRole, .key, text (+3 more)

### Community 99 - "FontFilesTests"
Cohesion: 0.24
Nodes (3): FontSource, FakeFontSource, FontFilesTests

### Community 100 - "DS3Tests"
Cohesion: 0.15
Nodes (4): FormLayout, .lengths, TabBarModel, .index

### Community 101 - "MarkdownTable"
Cohesion: 0.09
Nodes (12): CSV, Block, table, text, MarkdownTable, .nextSceneID, .sceneColumn, .sceneIDs (+4 more)

### Community 102 - "CR1Tests"
Cohesion: 0.20
Nodes (3): CR1Tests, Inner, Legacy

### Community 103 - "DesignPackage"
Cohesion: 0.16
Nodes (4): DesignPackage, PackageHash, PackageReader, PackageFormat

### Community 105 - "Foundation"
Cohesion: 0.10
Nodes (7): AudioToolbox, AVFoundation, CoreText, CryptoKit, Foundation, ImageIO, AppSettingsWindow

### Community 106 - "ContentTimes"
Cohesion: 0.18
Nodes (5): ContentTimes, .isFixed, .text, ContentTiming, .timing

### Community 107 - "SceneLookGroup"
Cohesion: 0.20
Nodes (9): SceneLookGroup, background, fonts, .keys, palette, .title, SceneLookTab, .body (+1 more)

### Community 108 - "SceneThumbs"
Cohesion: 0.13
Nodes (10): Book, Entry, Failure, Job, SceneThumbs, SceneFrameImage, .body, .staleMark (+2 more)

### Community 109 - "Kind"
Cohesion: 0.11
Nodes (19): Kind, asset, background, build, effectsPack, files, font, go (+11 more)

### Community 111 - ".refresh"
Cohesion: 0.07
Nodes (5): .layoutWarnings, EditorTab, .dirty, .id, .contextLine

### Community 112 - "Look"
Cohesion: 0.06
Nodes (26): CodingKeys, cat, dir, files, license, licenseFile, list, moods (+18 more)

### Community 113 - "MusicToolbarButton"
Cohesion: 0.14
Nodes (12): MusicToolbarButton, analyse, beat, drop, .isToggle, sections, .title, MusicToolbarContext (+4 more)

### Community 114 - ".save"
Cohesion: 0.11
Nodes (5): BriefExtras, DocSync, MarkdownRead, ProjectDocs, DocsTests

### Community 115 - "WhatClapKnows"
Cohesion: 0.17
Nodes (13): ClapHistoryPane, .body, JournalList, MemoryRow, .body, SessionsList, .body, WhatClapKnows (+5 more)

### Community 117 - ".run"
Cohesion: 0.10
Nodes (4): awaitMain(), NullUI, pixelStats(), SelfCheck

### Community 118 - "ProjectTab"
Cohesion: 0.09
Nodes (12): Place, aboveTabs, tab, ProjectFormMap, ProjectTab, brief, format, .id (+4 more)

### Community 120 - "LibraryModel"
Cohesion: 0.19
Nodes (6): LibraryModel, LibraryView, .actions, .body, ImportTicket, .id

### Community 121 - "DiffLine"
Cohesion: 0.21
Nodes (9): DiffLine, Kind, added, removed, same, LineDiff, Row, gap (+1 more)

### Community 122 - "MusicToolbarState"
Cohesion: 0.16
Nodes (6): AnalyseStatus, failed, idle, running, MusicSection, MusicToolbar

### Community 123 - "SoundOwnership"
Cohesion: 0.16
Nodes (8): Effect, stopFilm, stopPreview, Owner, film, none, resource, SoundOwnership

### Community 124 - "ShowreelStudioApp"
Cohesion: 0.18
Nodes (5): ShowreelStudioApp, .body, StudioCommands, .body, .fieldUndo

### Community 125 - "ContentItem"
Cohesion: 0.14
Nodes (12): ContentAnimation, .isFixed, .paramsText, .text, ContentColor, .isFixed, .text, ContentItem (+4 more)

### Community 126 - "DesignBoard"
Cohesion: 0.20
Nodes (8): Column, ContrastLine, DesignBoard, .columns, .hasPalette, .spanning, Swatch, PL1Tests

### Community 127 - "FileKind"
Cohesion: 0.14
Nodes (8): FileKind, binary, csv, json, markdown, text, FileNode, ProjectTree

### Community 130 - "Cause"
Cohesion: 0.20
Nodes (10): Cause, building, busy, clapWorking, legacy, locked, noKey, notAssembled (+2 more)

### Community 131 - ".state"
Cohesion: 0.19
Nodes (6): FontUse, State, embedded, needsFiles, previewOnly, .body

### Community 132 - "NumericField"
Cohesion: 0.24
Nodes (5): NumericField, Result, StepperField, .body, .value

### Community 133 - ".lines"
Cohesion: 0.30
Nodes (5): GridLine, LaneMarks, .isEmpty, MusicGrid, .lane

### Community 135 - "ProjectTests"
Cohesion: 0.21
Nodes (3): CoreServices, Showreel Studio (native macOS app), FileWatcher

### Community 137 - ".estimate"
Cohesion: 0.24
Nodes (4): BuildStats, Measure, WidthGate, .current

### Community 138 - "BG1cTests"
Cohesion: 0.15
Nodes (5): SceneTest, SceneTestResult, .ok, BG1cTests, .skill

### Community 139 - "EditSession"
Cohesion: 0.10
Nodes (14): Commit, EditSession, .pending, Field, .isDirty, Kind, instant, numeric (+6 more)

### Community 140 - "StudioSettings"
Cohesion: 0.15
Nodes (7): StudioSettings, TimelineMemory, WriteSource, copilot, restore, user, SM1Tests

### Community 141 - "FilmBuild"
Cohesion: 0.13
Nodes (9): Availability, FilmBuild, Status, .counter, .empty, .isOK, .staleLine, .toGenerate (+1 more)

### Community 144 - ".seconds"
Cohesion: 0.13
Nodes (10): SceneStatusIcon, .body, MusicInspector, .audio, .body, .track, TransitionInspector, .body (+2 more)

### Community 145 - "EnvModel"
Cohesion: 0.24
Nodes (5): EnvItem, EnvModel, .passed, .ready, ShellRunner

### Community 148 - "CheckLevel"
Cohesion: 0.13
Nodes (13): CheckLevel, fail, ok, pending, .rank, tight, Kind, bar (+5 more)

### Community 151 - "DragRun"
Cohesion: 0.20
Nodes (7): DragRun, .isActive, Outcome, cancelled, dropped, outsideTarget, refused

### Community 152 - "Surface"
Cohesion: 0.20
Nodes (8): Availability, Marks, Surface, inspector, list, reel, resources, tree

### Community 154 - "WizardStep"
Cohesion: 0.29
Nodes (4): Wizard, .draftScenesPrompt, WizardStep, .isBuilt

### Community 155 - "BA2Tests"
Cohesion: 0.08
Nodes (9): BA2Tests, .clean, .skill, LiveStub, .isDone, Mode, pings, trickle (+1 more)

### Community 156 - "EngineTests"
Cohesion: 0.15
Nodes (4): EngineHost, EngineTests, Pixels, .colours

### Community 158 - "engine-host.js"
Cohesion: 0.27
Nodes (10): backgroundStrip(), drawBackground(), drawEffect(), drawLook(), effectStrip(), lookStrip(), renderBackground(), renderEffect() (+2 more)

### Community 159 - "Motion"
Cohesion: 0.18
Nodes (11): Motion, .appear, .arrive, .confirm, .depart, .quick, .reduced, .select (+3 more)

### Community 161 - "FontInfo"
Cohesion: 0.21
Nodes (5): FontInfo, .forbidsEmbedding, .isOpenLicence, .isVariable, .names

### Community 163 - "XCTestCase"
Cohesion: 0.10
Nodes (5): .settings, Snapshot, ToolsTests, BlocksTests, ProjectTests

### Community 164 - "BG2ATests"
Cohesion: 0.12
Nodes (4): BG2ATests, .skill, SceneWriterProbe, StatusStub

### Community 168 - ".pending"
Cohesion: 0.18
Nodes (5): BuildFailureAlert, .canSkip, .skip, PendingBuild, .snapLevel

### Community 169 - "MessagesTransport"
Cohesion: 0.27
Nodes (6): MessagesTransport, Box, Exhausted, .errorDescription, SceneWriter, StatsBox

### Community 171 - "LookSettingsTests"
Cohesion: 0.13
Nodes (7): FIX1Tests, .views, LookSettingsTests, .file, .views, .lines, scrollViewsWithSiblingViews()

### Community 173 - "EnginePalette"
Cohesion: 0.36
Nodes (3): EnginePalette, .json, .signature

### Community 174 - "PF1Tests"
Cohesion: 0.24
Nodes (3): os, DebugProbe, PF1Tests

### Community 175 - "ParameterKey"
Cohesion: 0.15
Nodes (13): ParameterKey, audience, constraints, controlLevel, conversationLanguage, duration, formats, .help (+5 more)

### Community 176 - "Text"
Cohesion: 0.05
Nodes (36): Text, FontLicense, DesignBoardView, .body, EditorView, .body, .changedBanner, .content (+28 more)

### Community 177 - "ChatView.swift"
Cohesion: 0.09
Nodes (23): ChatView, .body, Composer, ConnectAIView, ConnectKeyLink, .body, CopilotHeader, .body (+15 more)

### Community 178 - "Brief: Demo"
Cohesion: 0.17
Nodes (11): Assets manifest, Audience, Brief: Demo, Constraints, Gates, Look and motion, Message, Mission and message (+3 more)

### Community 179 - "ProcessSpec"
Cohesion: 0.14
Nodes (15): EngineBackground, EngineCatalogue, EngineEffect, .id, Blocks, BlockSpec, BlockStatus, inProgress (+7 more)

### Community 180 - ".entries"
Cohesion: 0.27
Nodes (7): CheckPanel, NodeStatus, approved, excluded, missing, overBudget, toApprove

### Community 181 - "Value"
Cohesion: 0.23
Nodes (7): CheckBadge, Tone, attention, clear, problem, Value, .attentionCount

### Community 183 - "MemoryTests"
Cohesion: 0.12
Nodes (3): ProjectResume, MemoryTests, .file

### Community 184 - "RightsAnswer"
Cohesion: 0.11
Nodes (15): ResourceGroup, fonts, images, music, other, sounds, .title, RightsAnswer (+7 more)

### Community 186 - "LibraryState"
Cohesion: 0.18
Nodes (10): LibraryState, built, missing, outdated, setup, storyboard, LibraryActions, ProjectRow (+2 more)

### Community 187 - "PackageDesign"
Cohesion: 0.09
Nodes (21): Defaults, .isEmpty, Look, Motion, PackageDesign, .isEmpty, PackageIntegrity, damaged (+13 more)

### Community 189 - "State"
Cohesion: 0.18
Nodes (7): State, failed, fresh, placeholder, stale, .url, .body

### Community 190 - "CL1Tests"
Cohesion: 0.18
Nodes (4): ProjectLanguages, CL1Tests, .shared, .views

### Community 191 - "Kind"
Cohesion: 0.22
Nodes (9): Kind, accent, danger, faint, primary, review, secondary, success (+1 more)

### Community 192 - "StoryboardSceneRow"
Cohesion: 0.24
Nodes (10): Handle, .body, Column, eye, lock, StoryboardSceneRow, .body, .body (+2 more)

### Community 195 - ".encode"
Cohesion: 0.22
Nodes (4): AnyEncodable, DynamicKey, .intValue, Keep

### Community 196 - "AppInfo"
Cohesion: 0.29
Nodes (5): AppInfo, .line, .skillVersion, .version, ReleaseTests

### Community 197 - "PaletteRole"
Cohesion: 0.25
Nodes (7): PaletteRole, accent, accent2, background, .index, text, .title

### Community 198 - "MemoryKind"
Cohesion: 0.22
Nodes (8): MemoryKind, constraint, decision, fact, open_question, preference, rejected, .title

### Community 199 - "Util.swift"
Cohesion: 0.32
Nodes (4): clip(), jsonData(), jsonString(), resource()

### Community 200 - "DragLog"
Cohesion: 0.24
Nodes (3): DragLog, .standardURL, D3Tests

### Community 201 - "Kind"
Cohesion: 0.25
Nodes (8): Kind, assistant, notice, operation, proposal, question, steps, user

### Community 203 - "DS3bTests"
Cohesion: 0.20
Nodes (6): Modifier, coarse, fine, normal, DS3bTests, .views

### Community 204 - ".note"
Cohesion: 0.22
Nodes (7): FilmAssembly, TransitionNote, .lines, TransitionNotes, Unavailable.Cause, .body, .body

### Community 205 - "State"
Cohesion: 0.29
Nodes (7): State, done, failed, repairing, testing, waiting, writing

### Community 206 - "FilmPlacement"
Cohesion: 0.20
Nodes (9): AppShortcuts, .clapDisplay, FilmPlacement, fullWidth, .name, .other, .role, .tooltip (+1 more)

### Community 207 - "DocState"
Cohesion: 0.29
Nodes (7): DocState, created, edited, foreign, inSync, notNeeded, regenerated

### Community 210 - ".status"
Cohesion: 0.39
Nodes (3): Versions, .url, .playableVersion

### Community 213 - "OpenProjects"
Cohesion: 0.60
Nodes (3): Box, OpenProjects, .all

### Community 214 - "InlineEdit"
Cohesion: 0.28
Nodes (6): InlineEdit, .body, Kind, slots, target, Toast

### Community 217 - "Link"
Cohesion: 0.25
Nodes (7): Link, assemble, build, key, proposal, scene, setting

### Community 219 - "Status"
Cohesion: 0.50
Nodes (4): Status, accepted, pending, refused

### Community 221 - "Brief"
Cohesion: 0.50
Nodes (3): Brief, Look and motion, Mission

### Community 222 - "SnapLevel"
Cohesion: 0.29
Nodes (7): SnapLevel, bar, beat, drop, off, section, .title

## Knowledge Gaps
- **900 isolated node(s):** `scene`, `item`, `setting`, `asset`, `file` (+895 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1411 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **67 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `AgentError`, `ProjectImporter`, `.apply`, `ContentItemRow`, `.run`, `LibraryEntry`, `.all`, `View`, `ProjectModel`, `CaseIterable`, `Sendable`, `ProjectStore`, `.body`, `Theme`, `.load`, `Codable`, `.runSteps`, `.timeline`, `WorkspaceViews.swift`, `View`, `.loadShowreel`, `AssetRow`, `CheckResult`, `Motion`, `ProjectStore`, `CheckTarget`, `StoryboardSection`, `PrimaryButtonStyle`, `FrameView`, `ProjectOperation`, `LibrarySplit`, `ProjectModel.swift`, `MotionTokens`, `AnthropicTransport`, `ProjectForm`, `Resources`, `URL`, `PackageTests`, `ScriptedUI`, `.operation`, `.build`, `ShowreelFile`, `ChatRecord`, `MusicAnalysis`, `AppSettings`, `LookSection`, `AgentStop`, `SwiftUI`, `SceneStatusKind`, `.run`, `SceneRun`, `ElementRef`, `RailEntry`, `.read`, `DragItem`, `SceneGroupNodes`, `RightPanel`, `SceneForm`, `DragDropViews.swift`, `ChatModel`, `Availability`, `DragState`, `.add`, `.plan`, `DropTarget`, `IconRole`, `.root`, `FL1Tests`, `RF2Tests`, `PackageError`, `ReelPlayer`, `Tools`, `BF1Tests`, `RailState`, `C1Tests`, `SceneStateTests`, `ChatItem`, `TransitionEdit`, `Context`, `SceneCapture`, `.remember`, `DecisionKey`, `StageFrame`, `UndoLog`, `Unavailable`, `.run`, `JournalEntry`, `ResourceFlowTests`, `LibraryPackage`, `SceneModuleTests`, `StoryboardList`, `FontRepositoryError`, `SavePackageSheet`, `EngineRenderer`, `FontPayload`, `FontFilesTests`, `DS3Tests`, `MarkdownTable`, `DesignPackage`, `.finish`, `ContentTimes`, `SceneLookGroup`, `SceneThumbs`, `Kind`, `EngineService`, `.refresh`, `Look`, `MusicToolbarButton`, `.save`, `WhatClapKnows`, `.run`, `ProjectTab`, `AS1Tests`, `LibraryModel`, `DiffLine`, `MusicToolbarState`, `SoundOwnership`, `ShowreelStudioApp`, `ContentItem`, `DesignBoard`, `FileKind`, `W4bTests`, `fakeSfnt`, `Cause`, `.state`, `NumericField`, `.lines`, `MT1Tests`, `ProjectTests`, `AgentUI`, `.estimate`, `BG1cTests`, `EditSession`, `StudioSettings`, `FilmBuild`, `.prepare`, `.seconds`, `EnvModel`, `TimelineTests`, `ThumbnailCache`, `CheckLevel`, `.stream`, `DragRun`, `Surface`, `WizardInterview`, `WizardStep`, `BA2Tests`, `EngineTests`, `.run`, `Int`, `FontInfo`, `Brief`, `XCTestCase`, `BG2ATests`, `RL1Tests`, `LibraryRules`, `.frame`, `.pending`, `MessagesTransport`, `DS1Tests`, `LookSettingsTests`, `EnginePalette`, `PF1Tests`, `ParameterKey`, `Text`, `ChatView.swift`, `ProcessSpec`, `.entries`, `Value`, `AutoCommit`, `MemoryTests`, `RightsAnswer`, `ProjectModel`, `LibraryState`, `PackageDesign`, `State`, `CL1Tests`, `StoryboardSceneRow`, `AssetTests`, `.encode`, `AppInfo`, `PaletteRole`, `MemoryKind`, `Util.swift`, `DragLog`, `OperationToolTests`, `DS3bTests`, `.note`, `State`, `FilmPlacement`, `FT1Tests`, `DS3Tests`, `.status`, `.ratio`, `.missing`, `OpenProjects`, `InlineEdit`, `Link`, `.systemPrompt`, `FIX2Tests`, `SnapLevel`, `PackCard`?**
  _High betweenness centrality (0.646) - this node is a cross-community bridge._
- **Are the 134 inferred relationships involving `ProjectStore` (e.g. with `Showreel Studio (native macOS app)` and `.init()`) actually correct?**
  _`ProjectStore` has 134 INFERRED edges - model-reasoned connections that need verification._
- **What connects `scene`, `item`, `setting` to the rest of the system?**
  _900 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AgentError` be split into smaller, more focused modules?**
  _Cohesion score 0.08647936786654961 - nodes in this community are weakly interconnected._
- **Why does `ProjectStore` connect `ProjectStore` to `AgentError`, `ProjectImporter`, `.apply`, `.run`, `LibraryEntry`, `ProjectModel`, `ProjectStore`, `.body`, `.load`, `.runSteps`, `.timeline`, `.loadShowreel`, `CheckResult`, `TimelineTests`, `PrimaryButtonStyle`, `FrameView`, `ProjectOperation`, `URL`, `PackageTests`, `ScriptedUI`, `.operation`, `.build`, `ShowreelFile`, `MusicAnalysis`, `String`, `.run`, `SceneRun`, `.read`, `RightPanel`, `.add`, `.plan`, `DropTarget`, `.root`, `Tools`, `BF1Tests`, `C1Tests`, `SceneStateTests`, `TransitionEdit`, `SceneCapture`, `.remember`, `UndoLog`, `JournalEntry`, `ResourceFlowTests`, `LibraryPackage`, `SceneModuleTests`, `StoryboardList`, `FontPayload`, `FontFilesTests`, `.finish`, `Foundation`, `SceneThumbs`, `EngineService`, `.refresh`, `.save`, `.run`, `ProjectTab`, `AS1Tests`, `LibraryModel`, `W4bTests`, `.state`, `ProjectTests`, `.estimate`, `BG1cTests`, `StudioSettings`, `FilmBuild`, `.prepare`, `WizardInterview`, `BA2Tests`, `.run`, `XCTestCase`, `BG2ATests`, `RL1Tests`, `.frame`, `.pending`, `MessagesTransport`, `LookSettingsTests`, `Text`, `ChatView.swift`, `MemoryTests`, `RightsAnswer`, `ProjectModel`, `T2Tests`, `AssetTests`, `MemoryKind`, `OperationToolTests`, `.note`, `.status`, `.missing`, `PackCard`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **Are the 66 inferred relationships involving `ShowreelFile` (e.g. with `Showreel Studio (native macOS app)` and `.runSteps()`) actually correct?**
  _`ShowreelFile` has 66 INFERRED edges - model-reasoned connections that need verification._
- **Should `.apply` be split into smaller, more focused modules?**
  _Cohesion score 0.04421501514981484 - nodes in this community are weakly interconnected._