import AppKit
import Foundation
import ShowreelKit

/// One open file in the center pane.
final class EditorTab: ObservableObject, Identifiable {
    let path: String
    let kind: FileKind
    var id: String { path }
    @Published var text: String
    @Published private(set) var saved: String
    /// The file changed on disk while this tab has unsaved edits.
    @Published var diskChanged = false

    var dirty: Bool { text != saved }
    var name: String { (path as NSString).lastPathComponent }

    init(path: String, kind: FileKind, text: String) {
        self.path = path; self.kind = kind; self.text = text; self.saved = text
    }

    func markSaved(_ t: String) { saved = t; diskChanged = false }
    func replace(with t: String) { text = t; saved = t; diskChanged = false }
}

/// The kinds of look element the library lists.
enum LookKind: String, CaseIterable, Identifiable {
    case looks, palettes, fonts, backgrounds, effects, transitions
    var id: String { rawValue }
    var title: String {
        switch self {
        case .looks: return "Looks"
        case .palettes: return "Palettes"
        case .fonts: return "Fonts"
        case .backgrounds: return "Backgrounds"
        case .effects: return "Effects"
        case .transitions: return "Scene transitions"
        }
    }
}

/// What the user selected in the workspace. It drives the viewer and the inspector.
enum Selection: Hashable {
    case none
    case scene(String)
    /// A node of a scene's tree: the group it belongs to and, for a resource or a text, which one.
    case sceneNode(String, SceneGroup, String?)
    /// The passage from this scene to the next one that is on (a marker of the reel).
    case transition(String)
    case asset(String)
    case look(LookKind, String)
    case file(String)      // a project file opened from the Advanced panel
    case preview           // a page the copilot showed

    /// The scene the selection is about, itself or one of its nodes.
    var sceneID: String? {
        switch self {
        case .scene(let id), .sceneNode(let id, _, _): return id
        default: return nil
        }
    }
}

/// The tabs of a scene's inspector, one per group of its tree (plus Settings, which the scene's row sums up).
enum SceneTab: String, CaseIterable, Identifiable {
    case settings, composition, effects, look
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    init(_ g: SceneGroup) {
        switch g {
        case .composition: self = .composition
        case .effects: self = .effects
        case .look: self = .look
        }
    }
}

/// A drop that waits for the user's yes: it would replace the look of a scene.
struct PendingDrop: Identifiable {
    let id = UUID()
    let item: DragItem
    let target: DropTarget
    let message: String
}

/// A change of the global look that would redraw locked scenes: it waits for the user's choice on a card (apply anyway, or refuse).
struct PendingLookChange: Identifiable {
    let id = UUID()
    let operation: ProjectOperation
    let card: OperationCard
}

/// The library holds assets only: the resources and the scenes. The look is a project setting, and its catalogues are picked where they are used.
enum LibraryTab: String, CaseIterable, Identifiable {
    case resources, scenes, checks
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// The two parts of the project settings panel (the history belongs to Clap: see `ClapSection`).
enum SettingsTab: String, CaseIterable, Identifiable {
    case project, look
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case inspector, copilot, files
    var id: String { rawValue }
    var title: String { self == .copilot ? ClapMark.title : rawValue.capitalized }
}

/// The four parts of the Ask Clap tab: the conversation, then what Clap keeps of the project (memory, sessions, journal).
enum ClapSection: String, CaseIterable, Identifiable {
    case conversation = "Conversation", memory = "Memory", sessions = "Sessions", journal = "Journal"
    var id: String { rawValue }
}

/// What the centre of the workspace shows: the selection, or the build and its player.
enum CenterMode { case viewer, build }

/// State of one project window: files, open tabs, the showreel, the watcher. Main thread only.
final class ProjectModel: ObservableObject {
    let root: URL
    let store: ProjectStore
    @Published var tree: [FileNode] = []
    @Published var tabs: [EditorTab] = []
    @Published var selection: Selection = .none
    @Published var sceneTab: SceneTab = .settings
    /// The content item open in the Content tab (set by selecting its node in the tree).
    @Published var contentItem: String?
    /// With a built version the viewer plays it; true shows the draft thumbnails instead.
    @Published var viewerShowsDraft = false
    /// Plays the built version in the viewer (one page for the project, so it survives a change of selection).
    lazy var player = ReelPlayer()
    /// The sizes of the workspace's panels, remembered in .studio/ui.json.
    @Published private(set) var layout: PanelLayout
    /// The playhead of the reel, in seconds.
    @Published var playhead = 0.0
    /// The time scale of the strip and how far it is scrolled. `fitAll`: it shows the whole film and refits when its panel is resized.
    @Published private(set) var timeline = TimelineScale.Viewport(pps: 60, scroll: 0)
    @Published private(set) var fitAll = true
    /// Bumps when the strip must scroll to `timeline.scroll` (the user's own scrolling does not).
    @Published private(set) var scrollRequest = 0
    @Published private(set) var viewportWidth = 0.0
    var pointerX: Double?                    // the pointer over the strip, in the strip's own coordinates (not published: it moves all the time)
    var stripHovered = false
    @Published private(set) var draftPlaying = false
    private var draftTimer: Timer?
    private var saveTimeline: DispatchWorkItem?
    /// The analysis of the project's track (analysis/beats.json), its waveform, and what the app has to say about it.
    @Published private(set) var music: MusicAnalysis?
    @Published private(set) var waveform: [Float] = []
    @Published private(set) var trackDuration = 0.0
    @Published var musicNotice: String?
    @Published private(set) var analysing = false
    private var waveformKey: String?
    /// The scenes whose tree is open in the library.
    @Published var expanded: Set<String> = []
    /// The tree of each scene of the library, with the statuses computed natively.
    @Published private(set) var trees: [String: [SceneGroupNodes]] = [:]
    /// The status of each resource (approved, to approve, missing, over budget), from the asset rules.
    @Published private(set) var assetStatus: [String: NodeStatus] = [:]
    @Published var libraryTab: LibraryTab = .scenes
    /// The project settings panel (project parameters and global look) and the floating Catalogue palette, both opened from the top bar.
    @Published var showProjectSettings = false
    @Published var settingsTab: SettingsTab = .project
    /// The look editor open in the project settings (nil: the list of the six).
    @Published var lookSection: LookSection?
    @Published var showCatalogue = false
    @Published var inspectorTab: InspectorTab = .inspector
    @Published var clapSection: ClapSection = .conversation
    @Published var centerMode: CenterMode = .viewer
    @Published var lookKind: LookKind = .looks
    /// The workspace opens when the base configuration is complete (a project made earlier is never held back).
    @Published var workspaceOpen: Bool
    @Published var showreel: ShowreelFile?
    @Published var assets: [AssetRow] = []
    @Published var docIssues: [DocReport] = []
    @Published var reimport: (proposed: ShowreelFile, changes: [Change], files: [String])?
    private var dismissedDocs: Set<String> = []
    let spec = ProcessSpec.load()
    @Published var importOffer: ImportResult?
    @Published var historyFor: EditorTab?
    @Published var error: String?
    @Published var applyDirectly: Bool {
        didSet { var s = store.settings; s.applyDirectly = applyDirectly; store.settings = s }
    }
    /// "wizard" or "manual", chosen when the project was created and kept in .studio/ui.json. Nothing switches it, except the way out of a wizard that cannot go on.
    @Published private(set) var mode: String
    /// What the user answered to Clap's interview, by the header of the question: kept so that a wizard that cannot go on loses nothing.
    @Published var wizardAnswers: [String: String] = [:]
    /// The interview was started in this window.
    var wizardStarted = false
    @Published var showCopilot: Bool
    @Published private(set) var decided: [String] = []
    /// The deterministic checks of the blocks that have some (no AI), recomputed with the data.
    @Published private(set) var checks: [String: [CheckResult]] = [:]

    private var watcher: FileWatcher?

    /// Direct manipulation (phase W5): what is being dragged and over what, the notice at the bottom of the window, the scene being renamed in place.
    let dnd = DragState()
    @Published var toast: Toast?
    @Published var renaming: String?
    @Published var pendingDrop: PendingDrop?
    /// What is going on in the project (a build, Clap, proposals waiting): the model's snapshot, read by the views; the rules are ShowreelKit's.
    @Published private(set) var activity = ProjectActivity.Snapshot()
    /// Elements that just changed: lit for a second.
    @Published var flashed: Set<ElementRef> = []
    var buildCancelled = false
    /// The state of the film and of each scene, from fingerprints (ShowreelKit's `FilmBuild`): recomputed whenever the project is read again.
    @Published private(set) var film = FilmBuild.Status.empty
    @Published var assembling = false
    /// The engine's error when the last assembly failed, in the engine's own words; cleared by the next success.
    @Published var assemblyError: String?
    @Published var generationOffer: PendingGeneration?
    @Published var fontOffer: PendingFontOffer?
    var fontSource: FontSource = GoogleFontsSource()
    private var genTask: Task<Void, Never>?
    weak var chat: ChatModel?
    @Published var pendingLook: PendingLookChange?
    /// The base configuration of a new project is not done: the workspace stays closed. And: the file is of an older revision (nothing was written on opening).
    @Published private(set) var needsSetup = false
    @Published private(set) var outdated = false
    @Published var updateBannerDismissed = false
    @Published var showUpdateSheet = false
    /// What the project remembers, what was done and the sessions: loaded for the history parts of the Ask Clap tab.
    @Published private(set) var memory: [MemoryEntry] = []
    @Published private(set) var journalEntries: [JournalEntry] = []
    @Published private(set) var sessionRows: [SessionRow] = []
    /// Every check, with its group and what it points at (the Checks tab of the left panel).
    @Published private(set) var checkEntries: [CheckEntry] = []
    var attentionCount: Int { CheckPanel.attention(checkEntries) }
    /// The look node of a scene's tree that was clicked (background, palette, fonts): the Look tab marks that group.
    @Published var lookFocus: String?

    init(path: String) {
        root = URL(fileURLWithPath: path)
        store = ProjectStore(root: root)
        let s = store.settings
        applyDirectly = s.applyDirectly
        mode = s.mode
        workspaceOpen = !s.setupRequired
        showCopilot = !s.setupRequired || s.mode == StudioSettings.wizard
        decided = s.decided
        layout = s.layout ?? PanelLayout()
        if let m = s.timeline, m.fitAll == false { timeline = TimelineScale.Viewport(pps: TimelineScale.clamp(m.pps ?? 60), scroll: max(0, m.scroll ?? 0)); fitAll = false }
        dnd.onRefused = { [weak self] why in self?.showToast(why, error: true) }
        store.activity.reset()
        store.activity.observer = { [weak self] s in DispatchQueue.main.async { self?.activity = s } }
        OpenProjects.shared.register(self)
    }

    /// The user dragged a divider: the new sizes are kept for this project (floors applied, no ceiling).
    func setLayout(_ l: PanelLayout) {
        layout = l
        var s = store.settings; s.layout = l.isStandard ? nil : l; store.settings = s
    }

    func resetLayout() { setLayout(PanelLayout()) }

    deinit { draftTimer?.invalidate(); let p = root.path; DispatchQueue.main.async { LibraryModel.shared.markClosed(p) } }

    var title: String { showreel.flatMap { $0.name.isEmpty ? nil : $0.name } ?? root.lastPathComponent }

    /// Loads the project, offers to create or import `showreel.json`, and starts watching the folder.
    func start() {
        reloadTree()
        if let problem = store.showreelProblem {
            error = problem + ". The file was left as it is."      // an unreadable showreel.json is never replaced
        } else if store.hasShowreel {
            refresh()                                                // showreel.json exists: it is the source, the regex importer stays out
        } else {
            importOffer = ProjectImporter.importMarkdown(from: root)
        }
        if showreel?.decisions.track?.file != nil, music == nil { analyseTrack() }
        LibraryModel.shared.markOpen(root.path)
        LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step)
        watcher = FileWatcher(root: root) { [weak self] paths in self?.filesChanged(paths) }
    }

    /// Reads showreel.json, the manifest and the state of the generated documents again.
    func refresh() {
        store.dropUndoIfStale()           // a data file changed outside the typed operations: what can be undone is no longer known
        dnd.verdicts = [:]
        showreel = store.loadShowreel()
        assets = Assets.load(store)
        docIssues = DocSync.pending(store).filter { !dismissedDocs.contains($0.file) }
        decided = store.settings.decided
        versions = Versions.list(store)
        film = FilmBuild.status(store)
        if playVersion == nil || !(playVersion.map { Versions.hasDist(store, $0) } ?? false) { playVersion = film.playable }
        for a in Blocks.areas { checks[a] = Checks.run(area: a, store: store) }
        music = showreel?.decisions.track?.file == nil ? nil : MusicAnalysis.load(root: root)
        loadWaveform()
        assetStatus = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, Assets.nodeStatus($0, store: store)) })
        trees = Dictionary(uniqueKeysWithValues: (showreel?.library ?? []).map { ($0.id, SceneTree.build($0, in: showreel!, assets: assets, store: store)) })
        checkEntries = CheckPanel.entries(checks, file: showreel, assets: assets, status: assetStatus)
        outdated = showreel?.isOutdated ?? false
        // in the guided path the workspace follows the wizard: once the base configuration is complete there is nothing left to wait for
        // a wizard project opens its workspace by itself once the accepted cards complete the base configuration; a manual one waits for its button
        if store.needsSetup, mode == StudioSettings.wizard, let f = showreel, ProjectSetup.isComplete(f) { try? store.finishSetup(); workspaceOpen = true }
        needsSetup = store.needsSetup
        if fitAll, viewportWidth > 1 { fitFilm(remember: false) }          // the film got longer or shorter: the strip still shows all of it
        if inspectorTab == .copilot && clapSection != .conversation { reloadHistory() }
    }

    /// Reads the journal, the memory and the sessions again (when a history part of the Ask Clap tab is in front, and when Clap writes to the memory).
    func reloadHistory() {
        memory = store.memoryEntries(); journalEntries = store.journal.entries(); sessionRows = Sessions.rows(store)
    }

    @discardableResult
    func addMemory(kind: String, text: String, reason: String) -> String? {
        do { try store.remember(kind: kind, text: text, reason: reason, source: "user"); reloadHistory(); return nil } catch { return error.localizedDescription }
    }

    @discardableResult
    func editMemory(_ id: String, text: String? = nil, reason: String? = nil, kind: String? = nil, status: String? = nil, confirm: Bool = false) -> String? {
        do { try store.updateMemory(id: id, text: text, reason: reason, kind: kind, status: status, confirm: confirm, source: "user"); reloadHistory(); return nil } catch { return error.localizedDescription }
    }

    func deleteMemory(_ id: String) { do { try store.forget(id: id); reloadHistory() } catch { self.error = error.localizedDescription } }

    func transcript(of session: String) -> [ChatRecord] { ChatStore.records(root: root, session: session) }

    /// A journal line leads to the element it is about.
    func openJournal(_ e: JournalEntry) { if let t = JournalLinks.target(of: e) { open(t) } }

    // MARK: build and preview

    @Published var buildReport: BuildReport?
    @Published var generating = false        // the copilot is writing the version folder
    @Published var testing = false           // the app is building and testing it
    @Published var buildVersion: String?     // the version in progress, or the last one
    @Published var playVersion: String?      // the version shown in the player
    @Published var playNonce = 0
    @Published private(set) var versions: [String] = []

    var buildBusy: Bool { generating || testing }
    private var testTask: Task<Void, Never>?

    /// Cancel build: the writing stops at once (the request in flight is cancelled), what was written stays in its version folder and is not built, and the film stays at its
    /// last working version. While the testing runs it is dropped: nothing is lost, it can be run again.
    func cancelBuild() {
        guard let b = store.activity.snapshot.build else { return }
        if genTask != nil {                                  // a generation of some scenes: its request is cancelled, nothing is written
            genTask?.cancel()
            store.activity.update { $0.build?.phase = .cancelling }
            return
        }
        if b.phase == .testing {
            testTask?.cancel(); testing = false; assembling = false
            store.activity.update { $0.build = nil }
            showToast("The test of \(b.version) was cancelled. Nothing was lost: use Test it again to run it.")
            return
        }
        buildCancelled = true
        store.activity.update { $0.build?.phase = .cancelling }
        chat?.stop()
    }

    /// The Go is given and nothing is running: the copilot may write the next version. Needs a key (this is the one step that does).
    func startBuild(with chat: ChatModel) {
        guard BuildRunner.canBuild(store) else { error = "The build never starts without the Go. Give it from the toolbar once every scene is OK."; return }
        guard !buildBusy else { return }
        let v = Versions.next(store)
        do { try Film.write(version: v, store: store) } catch { self.error = "Could not write \(v)/film.json: \(error.localizedDescription)"; return }   // the exact montage, for the build to read
        buildVersion = v
        generating = true
        buildReport = nil
        buildCancelled = false; self.chat = chat
        store.activity.update { $0.build = .init(version: v, phase: .generating) }          // from here every change is refused, with its reason, until the end
        let sent = chat.ask(prompt: BuildRunner.prompt(version: v, store: store)) { [weak self] in self?.finishGeneration(v) }
        if !sent { generating = false; store.activity.update { $0.build = nil } } else { inspectorTab = .copilot; centerMode = .build }       // the user sees what the copilot does
    }

    private func finishGeneration(_ v: String) {
        generating = false
        let kept = BuildProgress.lastWorking(store).map { "the film stays at \($0)" } ?? "the film has no working version yet"
        if buildCancelled || chat?.stoppedByUser == true {
            buildCancelled = false
            store.activity.update { $0.build = nil }
            showToast("Build cancelled. What Clap wrote stays in \(v), not built; \(kept).", undoable: false)
            refresh(); reloadTree(); return
        }
        guard Versions.list(store).contains(v) else {
            store.activity.update { $0.build = nil }
            error = "Clap did not write \(v) (project.json and the scene files). See what it said in the chat, then try again. Nothing is frozen any more."
            refresh(); return
        }
        // what each scene file was generated from, so that a later change can tell which scenes are stale (nothing shows it yet)
        try? SceneModules.recordGeneration(version: v, store: store)
        runChecks(v)
    }

    /// Builds the version with the skill's scripts and tests it. No AI: usable on a version that already exists.
    func runChecks(_ v: String) {
        guard !buildBusy || (generating == false && store.activity.snapshot.build?.phase == .generating), let skill = Skill.root() else { return }
        testing = true; buildVersion = v
        store.activity.update { $0.build = .init(version: v, phase: .testing, started: $0.build?.started ?? Date()) }
        testTask = Task { @MainActor in
            let report = await BuildRunner.run(version: v, store: store, skill: skill)
            guard !Task.isCancelled, store.activity.snapshot.build?.phase == .testing else { return }          // cancelled: the user was told, nothing more happens
            try? store.record(report)
            buildReport = report
            testing = false
            store.activity.update { $0.build = nil }                                                      // success or problems, the project is editable again
            if report.built, report.harnessClean, report.smokeClean { playVersion = v; playNonce += 1 }
            refresh(); reloadTree()
            let p = BuildProgress.scenes(version: v, store: store)
            if report.ok { showToast("Build done: \(p.done) scene\(p.done == 1 ? "" : "s") generated, film assembled (\(v)). The previous version is kept.") }
            else {
                let bad = report.steps.first { $0.level != .ok }
                showToast("Build \(v) finished with a problem: \(bad.map { "\($0.title): \($0.detail)" } ?? "see the checks"). The editing is open again.", error: true)
            }
        }
    }

    /// Writes a parameter through the typed operation, unless it already holds that value.
    @discardableResult
    func setParameter(_ key: ParameterKey, _ value: String) -> Bool {
        guard let f = showreel else { error = "This project has no data yet."; return false }
        var probe = f
        do { try key.set(value, in: &probe) } catch { self.error = error.localizedDescription; return false }
        if key.current(probe) == key.current(f) { return true }
        return perform(.parameter(key, value))
    }

    func loadShowreel() { refresh() }

    // MARK: the scenes and the montage (the workspace calls these; the rules live in ShowreelKit)

    /// A new scene at the end of the master montage, selected. Returns false when it could not be added.
    @discardableResult
    func addScene() -> Bool {
        var e = SceneEdit(duration: "3")
        if let last = showreel?.storyboards.first?.items.last { e.after = last.scene }
        let before = Set(showreel?.scenes.map { $0.id } ?? [])
        guard perform(.addScene(id: "", e)) else { return false }
        if let n = showreel?.scenes.first(where: { !before.contains($0.id) }) { select(.scene(n.id)) }
        return true
    }

    /// A copy right after the scene, with its name and the rest of its content: one undo step (the rules are in ShowreelKit).
    @discardableResult
    func duplicateScene(_ id: String) -> Bool {
        do { let n = try store.duplicateScene(id); refresh(); select(.scene(n)); showToast("Duplicated \(id) as \(n)", undoable: true); return true }
        catch { self.error = error.localizedDescription; refresh(); return false }
    }

    // MARK: the reel: durations, cuts, transitions, grid

    /// Where a time lands on the grid at the level the user chose; the modifier key (`bypass`) leaves it alone.
    func snapped(_ t: Double, bypass: Bool) -> Double {
        guard !bypass, let m = music, let f = showreel else { return t }
        return m.snap(t, level: f.snapLevel())
    }

    /// The right edge of a frame was dragged to `t`: the scene's own duration changes (and the following scenes follow, with ripple).
    func stretch(scene id: String, toEnd t: Double, bypass: Bool) {
        guard let f = showreel, let item = f.timeline().first(where: { $0.scene.id == id }), let start = item.start else { return }
        let d = ((snapped(t, bypass: bypass) - start) * 1000).rounded() / 1000
        if abs(d - (item.length ?? -1)) < 0.001 { return }
        perform(.resize(scene: id, duration: max(d, 0.1), ripple: f.ripple()))
    }

    /// The left edge of a frame was dragged to `t`: the cut between it and the scene before moves.
    func moveCut(before: String, after: String, to t: Double, bypass: Bool) {
        guard let f = showreel, let prev = f.timeline().first(where: { $0.scene.id == before }), let end = prev.end else { return }
        let at = snapped(t, bypass: bypass)
        if abs(at - end) < 0.001 { return }
        perform(.moveCut(before: before, after: after, at: at))
    }

    /// A scene dropped on the reel (from the library or from another frame): switched on if needed, then put before `target` (nil: at the end).
    /// The version the viewer can play: the one picked in Build, or the last one, when its page exists.
    var playableVersion: String? {
        if let v = playVersion, Versions.hasDist(store, v) { return v }
        return film.playable          // the last version that works, never a folder a stopped build left behind
    }

    /// Selects the marker after a scene and puts the playhead just before the transition starts (centred on the cut).
    func selectTransition(from id: String) {
        select(.transition(id))
        if let f = showreel, let tl = Optional(f.timeline()), let i = tl.firstIndex(where: { $0.scene.id == id }), i + 1 < tl.count, let cut = tl[i + 1].start {
            let d = f.transition(after: id).map { $0.item.duration ?? f.defaultTransitionDuration($0.item.type, between: tl[i].scene, and: tl[i + 1].scene) } ?? 0
            playhead = max(0, cut - d / 2 - 0.2)
        }
    }

    func place(_ id: String, before target: String?) {
        let on = showreel?.storyboards.first?.items.first { $0.scene == id }?.enabled ?? false
        if !on { guard perform(.sceneEnabled(id: id, enabled: true, montage: nil)) else { return } }
        moveScene(id, before: target)
    }

    @discardableResult
    func setTransition(from id: String, _ e: TransitionEdit?) -> Bool { perform(.transition(from: id, e)) }
    func setGridSettings(snap: SnapLevel? = nil, ripple: Bool? = nil) { perform(.gridSettings(snap: snap?.rawValue, ripple: ripple)) }

    // MARK: the music

    /// Attaches an approved audio resource as the music (nil removes it) and analyses it.
    func attachTrack(_ asset: String?) {
        guard perform(.track(asset: asset)) else { return }
        for p in [MusicAnalysis.beatsPath, MusicAnalysis.envPath] { try? FileManager.default.removeItem(at: root.appendingPathComponent(p)) }
        musicNotice = nil
        if asset?.isEmpty == false { analyseTrack() } else { refresh() }
    }

    /// The user corrected the tempo or the first beat: the grid is computed again with those values.
    func correctGrid(bpm: Double?, firstBeat: Double?) {
        guard perform(.grid(bpm: bpm, firstBeat: firstBeat)) else { return }
        let t = showreel?.decisions.track
        analyseTrack(bpm: t?.bpm, firstBeat: t?.firstBeat)
    }

    /// Runs the skill's analysis from the app's environment. Without numpy or ffmpeg the notice says what is missing and the grid stays a time ruler.
    func analyseTrack(bpm: Double? = nil, firstBeat: Double? = nil) {
        guard !analysing, let skill = Skill.root() else { return }
        analysing = true; musicNotice = nil
        Task { @MainActor in
            let out = await Audio.analyse(store: store, skill: skill, bpm: bpm, firstBeat: firstBeat)
            analysing = false
            switch out {
            case .analysed(let a): try? store.recordAnalysis(a)
            case .unavailable(let m): musicNotice = m
            case .failed(let m): musicNotice = "The analysis failed: " + m
            }
            refresh()
        }
    }

    private func loadWaveform() {
        guard let file = showreel?.decisions.track?.file, !file.isEmpty else { waveform = []; trackDuration = 0; waveformKey = nil; return }
        let url = root.appendingPathComponent(file)
        let stamp = ((try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0)
        let key = "\(file)|\(stamp)"
        guard key != waveformKey else { return }
        waveformKey = key
        let env = music?.envelope ?? []
        Task { @MainActor in
            let (p, len) = await Task.detached { (Audio.peaks(url, buckets: 1500), Audio.duration(url)) }.value
            guard waveformKey == key else { return }
            trackDuration = len ?? music?.duration ?? 0
            if let p = p { waveform = p }
            else if !env.isEmpty { let n = 1500, per = max(1, env.count / n); waveform = (0..<min(n, env.count / per)).map { i in Float(env[(i * per)..<min(env.count, (i + 1) * per)].max() ?? 0) / 255 } }
            else { waveform = [] }
        }
    }

    // MARK: scene content

    /// A new item at the end of a scene's list. An image or a sound takes the first resource of its kind (approved ones first).
    func addItem(_ scene: String, type: String) {
        var e = ContentEdit(type: type)
        if type == "text" { e.text = "Your words" }
        else {
            let fit = assets.filter { ContentRules.accepts(type, asset: $0.type) && $0.status != "excluded" }
            guard let a = fit.first(where: { $0.status == "approved" }) ?? fit.first else { error = "Add \(type == "image" ? "an image or a logo" : "a sound or a voice") in the Resources tab first."; return }
            e.resource = a.id
        }
        if perform(.content(scene: scene, .add(e, after: nil))), let last = showreel?.scenes.first(where: { $0.id == scene })?.content.last { contentItem = last.id }
    }

    /// A resource of the project becomes an element of the scene's composition, at the end (it is linked to the scene by the same operation).
    func addResource(_ scene: String, _ asset: String) {
        guard let a = assets.first(where: { $0.id == asset }), let t = ContentRules.elementType(for: a.type) else { return }
        if perform(.content(scene: scene, .add(ContentEdit(type: t, resource: asset), after: nil))), let last = showreel?.scenes.first(where: { $0.id == scene })?.content.last { contentItem = last.id }
    }

    func updateItem(_ scene: String, _ item: String, _ e: ContentEdit) { perform(.content(scene: scene, .update(item: item, e))) }
    func removeItem(_ scene: String, _ item: String) { perform(.content(scene: scene, .remove(item: item))) }

    /// Moves an item up (-1) or down (+1) in the priority order.
    func moveItem(_ scene: String, _ item: String, by delta: Int) {
        guard let after = showreel?.contentPosition(scene: scene, item: item, by: delta) else { return }
        perform(.content(scene: scene, .move(item: item, after: after)))
    }

    /// A scene's control level (empty: the project's).
    func setControlLevel(_ scene: String, _ level: String) { perform(.scene(id: scene, SceneEdit(controlLevel: level))) }

    func setEnabled(_ id: String, _ on: Bool) { perform(.sceneEnabled(id: id, enabled: on, montage: nil)) }

    /// Puts a scene before another one in the master montage (nil: at the end).
    func moveScene(_ id: String, before target: String?) {
        guard let f = showreel, let after = f.position(of: id, before: target) else { return }
        perform(.moveScene(id: id, after: after, montage: nil))
    }

    func archiveScene(_ id: String) {
        perform(.scene(id: id, SceneEdit(archived: true)))
        if selection.sceneID == id { selection = .none }
    }

    func restoreScene(_ id: String) { perform(.scene(id: id, SceneEdit(status: "wip", archived: false))) }

    // MARK: the timeline (phase S): the rules are ShowreelKit's `TimelineScale` and `TimelineNav`

    /// How long the timeline extends, for its width.
    var timelineLength: Double { showreel.map { TimelineNav.contentLength($0, music: max(trackDuration, music?.duration ?? 0)) } ?? 1 }
    private var fitLength: Double { showreel.map { TimelineNav.filmLength($0) } ?? 1 }

    /// The width the strip has now. While it follows the width, the whole film stays in view as the panel is resized.
    func setViewportWidth(_ w: Double) {
        guard w > 1, abs(w - viewportWidth) > 0.5 else { return }
        viewportWidth = w
        if fitAll { fitFilm(remember: false) } else { setViewport(TimelineScale.Viewport(pps: timeline.pps, scroll: timeline.scroll), scroll: false) }
    }

    private func setViewport(_ v: TimelineScale.Viewport, scroll request: Bool) {
        var n = v
        n.scroll = TimelineScale.clampScroll(v.scroll, duration: timelineLength, pps: v.pps, viewport: viewportWidth)
        guard n != timeline else { return }
        timeline = n
        if request { scrollRequest += 1 }
    }

    /// The whole film in the width (Cmd+0). The strip then follows its panel.
    func fitFilm(remember: Bool = true) {
        fitAll = true
        setViewport(TimelineScale.fitAll(duration: fitLength, viewport: viewportWidth), scroll: true)
        if remember { rememberTimeline() }
    }

    /// The selected scene (or the two scenes of the selected transition) fills the width.
    func fitSelection() {
        guard let f = showreel else { return }
        var span: (start: Double, end: Double)?
        switch selection {
        case .transition(let id): span = TimelineNav.span(of: id, transition: true, in: f)
        default: if let id = selection.sceneID { span = TimelineNav.span(of: id, transition: false, in: f) }
        }
        guard let s = span else { fitFilm(); return }
        fitAll = false
        setViewport(TimelineScale.fitSelection(start: s.start, end: s.end, duration: timelineLength, viewport: viewportWidth), scroll: true)
        rememberTimeline()
    }

    /// A zoom by a factor (a button, a key, a pinch), anchored on the pointer when it is over the strip, else on the playhead.
    func zoom(by factor: Double) {
        guard viewportWidth > 1 else { return }
        let playheadX = TimelineScale.x(playhead, pps: timeline.pps) - timeline.scroll
        let anchor = TimelineScale.anchorX(pointerX: stripHovered ? pointerX : nil, playheadX: playheadX, viewport: viewportWidth)
        fitAll = false
        setViewport(TimelineScale.zoom(timeline, factor: factor, anchorX: anchor, duration: timelineLength, viewport: viewportWidth), scroll: true)
        rememberTimeline()
    }

    func zoomIn() { zoom(by: TimelineScale.stepFactor) }
    func zoomOut() { zoom(by: 1 / TimelineScale.stepFactor) }

    /// The slider: an absolute scale, anchored the same way.
    func setScale(_ pps: Double) { zoom(by: TimelineScale.clamp(pps) / timeline.pps) }

    /// The view was scrolled by the user.
    func scrolled(to x: Double) {
        guard abs(x - timeline.scroll) > 0.5 else { return }
        timeline.scroll = max(0, x)
        rememberTimeline()
    }

    private func rememberTimeline() {
        saveTimeline?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            var s = self.store.settings
            s.timeline = self.fitAll ? nil : TimelineMemory(pps: self.timeline.pps, scroll: self.timeline.scroll, fitAll: false)
            self.store.settings = s
        }
        saveTimeline = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: w)
    }

    /// The scene under the playhead.
    var sceneUnderPlayhead: ShowreelFile.Scene? { showreel.flatMap { TimelineNav.scene(at: playhead, in: $0) } }

    /// Arrow keys: the previous or next scene of the film becomes the selection and the playhead goes to its start.
    func stepScene(by delta: Int) {
        guard let f = showreel, let n = TimelineNav.step(from: selection.sceneID, by: delta, playhead: playhead, in: f) else { return }
        select(.scene(n.id)); playhead = n.start
        setViewport(TimelineScale.follow(timeline, playhead: n.start, duration: timelineLength, viewport: viewportWidth), scroll: true)
    }

    // MARK: the transport of the strip

    /// The built film plays in the viewer when the viewer shows it; otherwise the playhead runs by itself over the thumbnails.
    var playsBuiltFilm: Bool {
        viewerFilmVersion != nil && !viewerShowsDraft && centerMode == .viewer && !(showProjectSettings && settingsTab == .look) && player.loaded != nil
    }

    var isPlaying: Bool { playsBuiltFilm ? player.playing : draftPlaying }

    func togglePlay() {
        // Play only ever plays the assembled film, never the draft thumbnails
        if let u = Availability.play(film).why { react(StatusLine.refused(u.message)); return }
        if film.state == .stale, film.target == film.playable, !player.playing { assembleFilm(thenPlay: true); return }
        if !playsBuiltFilm, !isPlaying {
            selection = .none; viewerShowsDraft = false; centerMode = .viewer
            showToast("The assembled film is in the viewer now: press Play again.")
            return
        }
        if playsBuiltFilm { player.toggle(); return }
        if draftPlaying { stopDraft(); return }
        guard let f = showreel else { return }
        let end = TimelineNav.filmLength(f)
        if playhead >= end - 0.05 { playhead = 0 }
        draftPlaying = true
        var last = Date()
        draftTimer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date(), dt = now.timeIntervalSince(last); last = now
            let r = TimelineNav.advance(self.playhead, by: dt, end: end)
            self.playhead = r.time
            self.setViewport(TimelineScale.follow(self.timeline, playhead: r.time, duration: self.timelineLength, viewport: self.viewportWidth), scroll: true)
            if r.ended { self.stopDraft() }
        }
        RunLoop.main.add(t, forMode: .common)
        draftTimer = t
    }

    func stopDraft() { draftTimer?.invalidate(); draftTimer = nil; draftPlaying = false }

    /// What the viewer plays for the selection: the built version, for a selection that belongs to the film (nothing, a scene, a node that is not a resource, a transition).
    var viewerFilmVersion: String? {
        switch selection {
        case .none, .scene, .transition: return playableVersion
        case .sceneNode(let sid, _, let n): return nodeAsset(sid, n) != nil ? nil : playableVersion
        default: return nil
        }
    }

    /// The resource a node of a scene's tree stands for (a resource element, or a linked resource), if any.
    func nodeAsset(_ scene: String, _ node: String?) -> AssetRow? {
        guard let n = node else { return nil }
        if n.hasPrefix("raw.") { return assets.first { $0.id == String(n.dropFirst(4)) } }
        if n.hasPrefix("item.") { return itemAsset(scene, String(n.dropFirst(5))) }
        return nil
    }

    func itemAsset(_ scene: String, _ item: String) -> AssetRow? {
        let r = showreel?.scenes.first { $0.id == scene }?.content.first { $0.id == item }?.resource
        return assets.first { $0.id == r }
    }

    // MARK: setup, update, checks (phases P2 and P3): the rules are ShowreelKit's

    /// The user opens the workspace: only when the base configuration is complete (the form enables its button on that).
    func finishSetup() {
        guard store.needsSetup else { workspaceOpen = true; return }       // a project that never asked for its setup is never held back
        do { try store.finishSetup(); needsSetup = false; workspaceOpen = true }
        catch { self.error = error.localizedDescription }
    }

    /// What "Update project" would do now, to show before doing it.
    var updatePlan: UpdatePlan? { ProjectFormat.plan(store) }

    /// Backs the data up, migrates and writes the current revision (the user decided: nothing is written before this).
    func updateProject() {
        guard confirmLeaving(.updateProject) else { return }
        do {
            let r = try ProjectFormat.update(store)
            showUpdateSheet = false; updateBannerDismissed = false
            refresh(); reloadTree()
            showToast("Updated to revision \(ProjectFormat.current). The backup is in .studio/backups/\(r.backup.id)")
        } catch { self.error = error.localizedDescription; refresh() }
    }

    func restoreBackup(_ b: ProjectBackup) {
        guard confirmLeaving(.restoreBackup) else { return }
        do { try ProjectFormat.restore(store, b); refresh(); reloadTree(); showToast("Restored the backup \(b.id)") } catch { self.error = error.localizedDescription }
    }

    /// A click on a check opens the element it is about, on the right section.
    func openCheck(_ e: CheckEntry) { open(e.target) }

    func open(_ target: CheckTarget) {
        switch target {
        case .project: openSettings(.project)
        case .look(let s): openSettings(.look, look: s)
        case .resource(let id): libraryTab = .resources; select(.asset(id))
        case .resources: libraryTab = .resources
        case .scene(let id, let tab):
            libraryTab = .scenes; select(.scene(id)); expanded.insert(id)
            sceneTab = SceneTab(rawValue: tab) ?? .settings
        case .transition(let from): selectTransition(from: from)
        case .music: showProjectSettings = false; selection = .none; inspectorTab = .inspector; centerMode = .viewer
        case .storyboard: centerMode = .viewer
        case .build: centerMode = .build
        }
    }

    // MARK: direct manipulation (phase W5): the views relay, ShowreelKit decides

    func showToast(_ text: String, error: Bool = false, undoable: Bool = false) {
        let t = Toast(text: text, isError: error, undoable: undoable)
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + (error ? 6 : 4.5)) { [weak self] in if self?.toast?.id == t.id { self?.toast = nil } }
    }

    /// Whether the drop is allowed, with what it does or why not. Cached while the drag lasts (the data does not change under the pointer).
    func verdict(_ item: DragItem, _ target: DropTarget) -> DropVerdict {
        let k = DragState.Key(item: item, target: target)
        if let v = dnd.verdicts[k] { return v }
        let v = Drops.verdict(item, on: target, store: store)
        dnd.verdicts[k] = v
        return v
    }

    /// The user dropped something. Typed operations do the work; a refusal is said in a short notice.
    @discardableResult
    func performDrop(_ item: DragItem, on target: DropTarget) -> Bool {
        // a drop that would replace a scene's look asks first (the rule is ShowreelKit's); a no changes nothing
        if let q = Drops.confirmation(item, on: target) { pendingDrop = PendingDrop(item: item, target: target, message: q); return true }
        return carryOutDrop(item, on: target)
    }

    func confirmPendingDrop() {
        guard let p = pendingDrop else { return }
        pendingDrop = nil
        carryOutDrop(p.item, on: p.target)
    }

    func cancelPendingDrop() { pendingDrop = nil }

    @discardableResult
    private func carryOutDrop(_ item: DragItem, on target: DropTarget) -> Bool {
        do {
            let r = try Drops.drop(item, on: target, store: store)
            refresh(); reloadTree()
            if let s = r.scene, case .files = item { select(.scene(s)); if let i = r.item { contentItem = i } }
            if case .musicLane = target {                    // a new track: its analysis was for the other file
                for p in [MusicAnalysis.beatsPath, MusicAnalysis.envPath] { try? FileManager.default.removeItem(at: root.appendingPathComponent(p)) }
                music = nil; musicNotice = nil
                analyseTrack()
            }
            showToast([r.title, r.notice].compactMap { $0 }.joined(separator: "\n"), undoable: true)
            return true
        } catch {
            showToast(error.localizedDescription, error: true); refresh(); return false
        }
    }

    var canUndo: Bool { store.undoLog.canUndo }
    var canRedo: Bool { store.undoLog.canRedo }
    var undoTitle: String? { store.undoLog.undoTitle }
    var redoTitle: String? { store.undoLog.redoTitle }

    func undo() { stepHistory { try store.undo() } label: { "Undid: \($0)" } }
    func redo() { stepHistory { try store.redo() } label: { "Redid: \($0)" } }

    private func stepHistory(_ step: () throws -> String, label: (String) -> String) {
        let track = showreel?.decisions.track?.file
        do {
            let t = try step()
            refresh(); reloadTree()
            if showreel?.decisions.track?.file != track {            // the music changed: its analysis was for the other file
                for p in [MusicAnalysis.beatsPath, MusicAnalysis.envPath] { try? FileManager.default.removeItem(at: root.appendingPathComponent(p)) }
                music = nil
                if showreel?.decisions.track?.file != nil { analyseTrack() } else { refresh() }
            }
            showToast(label(t))
        } catch { showToast(error.localizedDescription, error: true); refresh() }
    }

    /// Renaming in place: the name is a label next to the ID, the ID never changes.
    func beginRename(_ id: String) { libraryTab = .scenes; renaming = id }
    func renameScene(_ id: String, _ name: String) { renaming = nil; perform(.scene(id: id, SceneEdit(name: name))) }

    func duplicateItem(_ scene: String, _ item: String) {
        guard let it = showreel?.scenes.first(where: { $0.id == scene })?.content.first(where: { $0.id == item }) else { return }
        perform(.content(scene: scene, .add(it.edit, after: item)))
    }

    /// Takes a resource out of a scene (the resource stays in the project).
    func unlink(_ asset: String, from scene: String) {
        let rest = assets.filter { $0.sceneIDs.contains(scene) && $0.id != asset }.map { $0.id }.joined(separator: ", ")
        perform(.scene(id: scene, SceneEdit(assets: rest)))
    }

    /// A choice made in a picker (an effect for an item, a transition for a marker, a background for a scene): the same typed operation the drag builds.
    @discardableResult
    func choose(_ kind: CatalogueKind, _ choice: String, for target: CatalogueTarget) -> Bool {
        do { return perform(try Catalogue.operation(kind, choice: choice, target: target)) } catch { self.error = error.localizedDescription; return false }
    }

    /// Opens the project settings on a part of the global look.
    func openSettings(_ tab: SettingsTab = .project, look: LookSection? = nil) {
        settingsTab = tab
        if let l = look { lookSection = l }
        showProjectSettings = true
    }

    func setAssetStatus(_ id: String, _ status: AssetStatus) { perform(.asset(id: id, status: status, note: nil, licence: nil, scenes: nil)) }

    // MARK: operations (the blocks and the copilot use the same ones)

    /// Applies a change the user made in a block. Errors are shown, never swallowed.
    @discardableResult
    func perform(_ op: ProjectOperation) -> Bool {
        // a change of the global look that locked scenes inherit is shown on its card first (the rule is ShowreelKit's)
        if case .decisions = op, let card = try? store.plan(op), card.lockWarning != nil {
            pendingLook = PendingLookChange(operation: op, card: card)
            return false
        }
        return carryOut(op)
    }

    func confirmPendingLook() {
        guard let p = pendingLook else { return }
        pendingLook = nil
        carryOut(p.operation, expecting: p.card)
    }

    func cancelPendingLook() { pendingLook = nil }

    @discardableResult
    private func carryOut(_ op: ProjectOperation, expecting card: OperationCard? = nil) -> Bool {
        let planned = try? store.plan(op)
        do {
            try store.apply(op, expecting: card); refresh(); LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step)
            if let c = planned { react(StatusLine.applied(op, card: c)) }
            return true
        } catch {
            refresh(); react(StatusLine.refused(error.localizedDescription, op: op)); return false
        }
    }

    // MARK: action and reaction

    /// The reaction to a typed change: the elements it touched light up and the line at the bottom says what happened, with Undo; a refusal says why and what to do.
    func react(_ line: StatusLine) {
        showToast(line.text, error: line.kind == .refused, undoable: line.undoable)
        if line.kind == .applied { flash(line.targets) }
    }

    func flash(_ refs: [ElementRef]) {
        guard !refs.isEmpty else { return }
        flashed.formUnion(refs)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.flashed.subtract(refs) }
    }

    /// Clap's change was accepted on its card: the same reaction, a moment later (the change is applied by the agent's own thread).
    func reactToAccepted(_ card: OperationCard) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            self.refresh(); self.reloadTree()
            self.react(StatusLine.applied(card: card, targets: card.targets))
        }
    }

    /// Why an element cannot be edited now, or nil: what the views read to mark it, disable its controls and say why.
    func blocked(_ ref: ElementRef) -> Unavailable? { Availability.edit(ref, in: activity, file: showreel).why.flatMap { $0.cause == .locked ? nil : $0 } }

    /// The way out that a reason offers: the card of a proposal, or the build's Cancel.
    func followLink(_ u: Unavailable, chat: ChatModel?) {
        switch u.link {
        case .proposal(let id)?: chat?.focus(card: id)
        case .scene(let id)?: select(.scene(id))
        case .build?: centerMode = .build
        case .key?: AppSettingsWindow.open()
        default: break
        }
    }

    func addAssets(_ urls: [URL]) {
        // adding files is one undo step too (the copies in assets/ and the manifest rows go back together)
        do { try store.transaction(urls.count == 1 ? "Add \(urls[0].lastPathComponent)" : "Add \(urls.count) files") { try Assets.add(urls, to: store) }; refresh(); reloadTree() } catch { self.error = error.localizedDescription }
    }

    func status(_ zone: String) -> BlockStatus {
        guard let spec = spec else { return .soon }
        return Blocks.status(zone, spec: spec, showreel: showreel, assets: assets)
    }

    // MARK: generated documents

    static func friendly(_ file: String) -> String {
        switch file {
        case "brief.md": return "the brief"
        case "style-sheet.md": return "the style sheet"
        case "storyboard.md": return "the storyboard"
        default: return file
        }
    }

    /// Reads the changed documents back into a proposal the user reviews. Nothing is saved yet.
    func reviewReimport() {
        let files = docIssues.map { $0.file }
        guard let r = DocSync.reimport(store, files: files) else { return }
        reimport = (r.proposed, r.changes, files)
    }

    func acceptReimport() {
        guard let r = reimport else { return }
        do { try DocSync.acceptReimport(store, files: r.files, proposed: r.proposed); reimport = nil; refresh() }
        catch { self.error = error.localizedDescription }
    }

    /// The user chose the app's version: the documents are rewritten, the old content stays in the history.
    func replaceDocs() {
        for d in docIssues { try? DocSync.overwrite(store, d.file) }
        reimport = nil; refresh(); reloadTree()
    }

    func leaveDocs() {
        dismissedDocs.formUnion(docIssues.map { $0.file })
        reimport = nil; refresh()
    }

    func reloadTree() { tree = ProjectTree.scan(root) }

    // MARK: selection and zones

    func select(_ x: Selection) {
        selection = x
        centerMode = .viewer
        switch x {
        case .scene: inspectorTab = .inspector; sceneTab = .settings
        case .asset, .look, .sceneNode: inspectorTab = .inspector
        default: break
        }
    }

    /// Selecting a node of a scene's tree opens the matching tab of the scene's inspector and shows the node in the viewer.
    func selectNode(_ scene: String, _ group: SceneGroup, _ item: String?) {
        select(.sceneNode(scene, group, item))
        sceneTab = SceneTab(group)
        lookFocus = group == .look ? item : nil
        if let i = item, i.hasPrefix("item.") { sceneTab = .composition; contentItem = String(i.dropFirst(5)) }
        expanded.insert(scene)
    }

    /// A scene's own palette, fonts or background (an empty value takes the override away).
    @discardableResult
    func setSceneLook(_ id: String, _ changes: [DecisionChange]) -> Bool { perform(.sceneLook(id: id, changes)) }

    /// The copilot (or a link) asks for a zone of the workspace. While the base configuration is not complete the workspace stays closed.
    func openZone(_ id: String) {
        guard workspaceOpen else { return }
        switch id {
        case "library": break
        case "viewer": centerMode = .viewer
        case "inspector": inspectorTab = .inspector; selection = .none; showProjectSettings = true
        case "storyboard": centerMode = .viewer
        case "build": centerMode = .build
        default: break
        }
    }

    func showPreview() { selection = .preview; centerMode = .viewer }

    // MARK: import

    func confirmImport() {
        guard let r = importOffer else { return }
        do {
            try ProjectImporter.confirm(r, in: root)
            importOffer = nil
            loadShowreel(); reloadTree()
            LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step)
        } catch { self.error = error.localizedDescription }
    }

    func dismissImport() { importOffer = nil }

    // MARK: tabs

    func node(_ id: String) -> FileNode? {
        func find(_ nodes: [FileNode]) -> FileNode? {
            for n in nodes {
                if n.id == id { return n }
                if let c = n.children, let f = find(c) { return f }
            }
            return nil
        }
        return find(tree)
    }

    func open(_ rel: String) {
        let url = root.appendingPathComponent(rel)
        let kind = ProjectTree.kind(of: rel)
        if kind == .binary { NSWorkspace.shared.open(url); return }
        if tabs.contains(where: { $0.path == rel }) { select(.file(rel)); return }
        guard let text = store.read(rel) else {
            error = "\(rel) is not a readable text file."
            NSWorkspace.shared.open(url)
            return
        }
        tabs.append(EditorTab(path: rel, kind: kind, text: text))
        select(.file(rel))
    }

    func close(_ tab: EditorTab) {
        tabs.removeAll { $0.id == tab.id }
        if selection == .file(tab.path) { selection = tabs.last.map { .file($0.path) } ?? .none }
    }

    func tab(_ id: String) -> EditorTab? { tabs.first { $0.id == id } }

    /// The file in front of the user, for the copilot's context.
    var foreground: String? {
        if case .file(let p) = selection { return p }
        return nil
    }

    /// The scene as the user reads it (ID and name), for the copilot's context. The ID is still what operations use.
    func sceneLabel(_ id: String) -> String { showreel?.scenes.first { $0.id == id }?.label ?? id }

    /// The zone or selection in front of the user, for the copilot's context.
    var foregroundBlock: String? {
        switch selection {
        case .scene(let id): return "inspector: scene \(sceneLabel(id))"
        case .transition(let id): return "inspector: transition after scene \(id)"
        case .sceneNode(let id, let g, _): return "inspector: scene \(sceneLabel(id)), \(g.title) tab"
        case .asset(let id): return "inspector: resource \(id)"
        case .look(let k, let id): return "inspector: \(k.title.lowercased()) element \(id)"
        case .file, .preview: return nil
        case .none: return showProjectSettings ? "project settings (parameters and global look)" : centerMode == .build ? "build" : "inspector: nothing selected"
        }
    }

    // MARK: save, reload, restore

    func save(_ tab: EditorTab) {
        do {
            if let e = store.buildRefusal() { throw e }           // a file edited during a build would change the film under construction
            try store.write(tab.path, tab.text, source: .user)
            tab.markSaved(tab.text)
            refresh(); if tab.path == ShowreelFile.fileName { refreshTab("brief.md") }
            reloadTree()
        } catch { self.error = error.localizedDescription }
    }

    func reloadFromDisk(_ tab: EditorTab) {
        if let t = store.read(tab.path) { tab.replace(with: t) }
    }

    func restore(_ tab: EditorTab, _ s: Snapshot) {
        do {
            try store.restore(tab.path, s)
            reloadFromDisk(tab)
            refresh()
        } catch { self.error = error.localizedDescription }
    }

    private func refreshTab(_ rel: String) {
        guard let t = tab(rel), let disk = store.read(rel) else { return }
        if t.dirty { t.diskChanged = disk != t.saved } else { t.replace(with: disk) }
    }

    /// The watcher saw these files change (the user, the copilot, a script).
    private func filesChanged(_ paths: [String]) {
        reloadTree()
        let before = dismissedDocs
        dismissedDocs.subtract(paths)                      // a file edited again asks again
        if paths.contains(where: { $0.contains("/scenes/") || $0.hasSuffix("/assembly.json") }) { refresh() }
        if paths.contains(where: { $0 == ShowreelFile.fileName || $0 == Assets.manifestPath || ProjectDocs.files.contains($0) }) || before != dismissedDocs { refresh() }
        for p in paths {
            guard let t = tab(p) else { continue }
            guard let disk = store.read(p) else { continue }
            if disk == t.saved { continue }          // our own save
            if t.dirty { t.diskChanged = true } else { t.replace(with: disk) }
        }
    }

    // MARK: copilot context

    /// One line sent with every message: step, open gates, file in front of the user.
    var contextLine: String {
        var parts: [String] = []
        if !workspaceOpen {
            parts.append(mode == StudioSettings.wizard ? "a new project in Wizard mode: you lead the interview and propose the starting pack with propose_starter_pack" : "a new project in Manual mode: the user fills the setup form")
        } else if let b = foregroundBlock { parts.append("in front of the user: \(b)") }
        if let s = showreel {
            parts.append("step: \(s.step)")
            let open = s.gates.filter { $0.value != "passed" }.keys.sorted()
            if !open.isEmpty { parts.append("open gates: " + open.joined(separator: ", ")) }
        } else {
            parts.append("no showreel.json yet")
        }
        if let f = foreground { parts.append("file in front of the user: \(f)") }
        let unsaved = tabs.filter { $0.dirty }.map { $0.path }
        if !unsaved.isEmpty { parts.append("unsaved edits by the user in: " + unsaved.joined(separator: ", ")) }
        return parts.joined(separator: "; ")
    }
}

/// The two models of a project window.
final class WindowModel: ObservableObject {
    let project: ProjectModel
    let chat: ChatModel

    init(path: String) {
        project = ProjectModel(path: path)
        chat = ChatModel(project: project)
        project.chat = chat
    }
}

/// A generation of scenes waiting for the user's yes: the one card that lists them, the scenes that cannot be generated, and the version.
struct PendingGeneration: Identifiable {
    let id = UUID()
    let version: String
    var card: OperationCard
    /// The scenes to generate without any extra question; the hand-edited ones join them only when the user ticks them.
    let ids: [String]
    let excluded: [(id: String, reason: String)]
    let handEdited: [String]
    var overwrite: Set<String> = []
    var all: [String] { ids + handEdited.filter { overwrite.contains($0) } }
}

extension ProjectModel {
    /// Assembles the film of the newest version with no AI (free). The project is read-only while it runs; a failure leaves the film that works as it was.
    /// With `thenPlay`, the film plays when it is ready (Play on a stale film).
    func assembleFilm(thenPlay: Bool = false) {
        if let u = Availability.assemble(film, in: activity).why { react(StatusLine.refused(u.message)); return }
        guard !assembling, let skill = Skill.root(), let v = film.target else { return }
        assembling = true; assemblyError = nil
        showToast("Assembling\u{2026}")
        testTask = Task { @MainActor in
            let r = await FilmAssembly.run(version: v, store: store, skill: skill)
            assembling = false
            guard !Task.isCancelled else { refresh(); return }
            refresh(); reloadTree()
            if r.ok {
                playVersion = v; playNonce += 1
                react(StatusLine.assembled(r))
                if thenPlay {
                    for _ in 0..<60 where !player.ready { try? await Task.sleep(nanoseconds: 100_000_000) }
                    player.play()
                }
            } else {
                assemblyError = r.message
                showToast("Not assembled: " + (r.message.split(separator: "\n").first.map(String.init) ?? r.message), error: true)
            }
        }
    }

    /// The card that offers to generate the scenes that have no file. Explicit, never automatic.
    func offerGeneration() {
        guard let f = showreel, let v = film.target else { return }
        let o = SceneGeneration.offer(version: v, store: store, file: f)
        let plain = o.ids.filter { !o.handEdited.contains($0) }
        if let u = Availability.generate(o.ids, film, in: activity, hasKey: AppSettings.shared.hasKey, file: f).why { react(StatusLine.refused(u.message)); return }
        do { generationOffer = PendingGeneration(version: v, card: try SceneGeneration.plan(plain.isEmpty ? o.ids : plain, version: v, store: store), ids: plain, excluded: o.excluded, handEdited: o.handEdited) }
        catch { react(StatusLine.refused(error.localizedDescription)) }
    }

    /// The line that asks before a hand edit is overwritten: ticking it adds the scene to the card.
    func toggleOverwrite(_ id: String) {
        guard var g = generationOffer else { return }
        if g.overwrite.contains(id) { g.overwrite.remove(id) } else { g.overwrite.insert(id) }
        if let c = try? SceneGeneration.plan(g.all.isEmpty ? g.handEdited : g.all, version: g.version, store: store) { g.card = c }
        generationOffer = g
    }

    /// The user said yes to the card: one call per scene, with the build's panel, Cancel and end.
    func confirmGeneration() {
        guard let g = generationOffer, let skill = Skill.root(), let key = AppSettings.shared.apiKey() else { return }
        generationOffer = nil
        let s = AppSettings.shared
        let transport = AnthropicTransport(apiKey: key, model: s.modelName, baseURL: s.baseURL, bearer: s.bearer)
        genTask = Task { @MainActor in
            do {
                let ids = try await SceneGeneration.generate(g.all, version: g.version, store: store, skill: skill, transport: transport, overwriting: g.overwrite)
                react(StatusLine.generated(ids))
            } catch is CancellationError {
                showToast("Generation cancelled. Nothing was written.")
            } catch {
                showToast("Not generated: \(error.localizedDescription)", error: true)
            }
            genTask = nil
            refresh(); reloadTree()
        }
    }
}

/// The card of "Add font files", waiting for the user's yes. Nothing is downloaded before it.
struct PendingFontOffer: Identifiable {
    let id = UUID()
    let offer: FontOffer
}

extension ProjectModel {
    /// Looks up the files of a Look font (names and sizes only) and shows the card.
    func addFontFiles(_ family: String) {
        if let u = Availability.addFontFiles(family, in: activity, store: store).why { react(StatusLine.refused(u.message)); return }
        showToast("Looking up the files of \(family)\u{2026}")
        Task { @MainActor in
            do { fontOffer = PendingFontOffer(offer: try await FontFiles.offer(family, store: store, source: fontSource)) }
            catch { react(StatusLine.refused(error.localizedDescription)) }
        }
    }

    /// The card was accepted: download, then one typed operation (undoable, in the journal) puts the files in the project and approves them.
    func confirmFontOffer() {
        guard let o = fontOffer?.offer else { return }
        fontOffer = nil
        showToast("Downloading the files of \(o.family)\u{2026}")
        Task { @MainActor in
            do {
                let payload = try await FontFiles.fetch(o, source: fontSource)
                perform(.addFontFiles(payload)); reloadTree()
            } catch { react(StatusLine.refused(error.localizedDescription)) }
        }
    }
}


// MARK: the wizard of a new project (Clap leads it; the rules are ShowreelKit's `WizardInterview` and `StarterPack`)

extension ProjectModel {
    /// Starts Clap's interview, once per window, for a new project made in Wizard mode that still has its base configuration to set.
    func startWizardIfNeeded(chat: ChatModel) {
        guard mode == StudioSettings.wizard, needsSetup, !wizardStarted, showreel != nil, AppSettings.shared.hasKey else { return }
        wizardStarted = true
        showCopilot = true; inspectorTab = .copilot
        chat.ask(prompt: WizardInterview.prompt(projectName: title, conversationLanguage: showreel?.conversationLanguage))
    }

    /// The way out of a wizard that cannot go on (no key, a failed request, or the user's choice): the answers already given become typed changes, and the
    /// project goes on as a Manual one with the same form.
    func continueInManual() {
        if let f = showreel {
            for op in WizardInterview.operations(from: wizardAnswers, file: f) { _ = perform(op) }
        }
        mode = StudioSettings.manual
        var s = store.settings; s.mode = StudioSettings.manual; store.settings = s
        showCopilot = false
        refresh()
    }
}
