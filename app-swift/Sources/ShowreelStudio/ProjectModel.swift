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

/// The library holds assets only: the resources and the scenes. The look is a project setting, and its catalogues are picked where they are used.
enum LibraryTab: String, CaseIterable, Identifiable {
    case resources, scenes, checks
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// The two parts of the project settings panel.
enum SettingsTab: String, CaseIterable, Identifiable {
    case project, look
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case inspector, copilot, files
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
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
    /// The playhead of the reel, in seconds, and the zoom of the reel (pixels per second).
    @Published var playhead = 0.0
    @Published var pps = 60.0
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
    @Published var centerMode: CenterMode = .viewer
    @Published var lookKind: LookKind = .looks
    /// Beginner mode walks the wizard first and ends in the workspace; Expert opens the workspace at once.
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
    /// "beginner" (the wizard, then the workspace) or "expert" (the workspace), kept in .studio/ui.json. Switching never touches the project data.
    @Published var mode: String {
        didSet {
            var s = store.settings; s.mode = mode; store.settings = s
            if mode == StudioSettings.beginner { resumeWizard(); workspaceOpen = wizardFinished && !needsSetup } else { workspaceOpen = true }
        }
    }
    @Published var showCopilot: Bool
    @Published var wizardIndex = 0
    @Published private(set) var wizardSteps: [WizardStep] = []
    @Published private(set) var decided: [String] = []
    /// The deterministic checks of the blocks that have some (no AI), recomputed with the data.
    @Published private(set) var checks: [String: [CheckResult]] = [:]

    private var watcher: FileWatcher?

    /// Direct manipulation (phase W5): what is being dragged and over what, the notice at the bottom of the window, the scene being renamed in place.
    let dnd = DragState()
    @Published var toast: Toast?
    @Published var renaming: String?
    @Published var pendingDrop: PendingDrop?
    /// The base configuration of a new project is not done: the workspace stays closed. And: the file is of an older revision (nothing was written on opening).
    @Published private(set) var needsSetup = false
    @Published private(set) var outdated = false
    @Published var updateBannerDismissed = false
    @Published var showUpdateSheet = false
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
        workspaceOpen = s.mode == StudioSettings.expert
        showCopilot = s.mode == StudioSettings.expert
        decided = s.decided
        layout = s.layout ?? PanelLayout()
        dnd.onRefused = { [weak self] why in self?.showToast(why, error: true) }
    }

    /// The user dragged a divider: the new sizes are kept for this project (floors applied, no ceiling).
    func setLayout(_ l: PanelLayout) {
        layout = l
        var s = store.settings; s.layout = l.isStandard ? nil : l; store.settings = s
    }

    func resetLayout() { setLayout(PanelLayout()) }

    deinit { let p = root.path; DispatchQueue.main.async { LibraryModel.shared.markClosed(p) } }

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
        if mode == StudioSettings.beginner { resumeWizard(); workspaceOpen = wizardFinished && !needsSetup }
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
        if playVersion == nil, let last = versions.last, Versions.hasDist(store, last) { playVersion = last }
        wizardSteps = Wizard.steps(assets: assets, spec: spec, systemLanguage: Locale.current.language.languageCode?.identifier, file: showreel)
        for a in Blocks.areas { checks[a] = Checks.run(area: a, store: store) }
        music = showreel?.decisions.track?.file == nil ? nil : MusicAnalysis.load(root: root)
        loadWaveform()
        assetStatus = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, Assets.nodeStatus($0, store: store)) })
        trees = Dictionary(uniqueKeysWithValues: (showreel?.library ?? []).map { ($0.id, SceneTree.build($0, in: showreel!, assets: assets, store: store)) })
        checkEntries = CheckPanel.entries(checks, file: showreel, assets: assets, status: assetStatus)
        outdated = showreel?.isOutdated ?? false
        // in the guided path the workspace follows the wizard: once the base configuration is complete there is nothing left to wait for
        if store.needsSetup, mode == StudioSettings.beginner, let f = showreel, ProjectSetup.isComplete(f) { try? store.finishSetup() }
        needsSetup = store.needsSetup
    }

    // MARK: build and preview

    @Published var buildReport: BuildReport?
    @Published var generating = false        // the copilot is writing the version folder
    @Published var testing = false           // the app is building and testing it
    @Published var buildVersion: String?     // the version in progress, or the last one
    @Published var playVersion: String?      // the version shown in the player
    @Published var playNonce = 0
    @Published private(set) var versions: [String] = []

    var buildBusy: Bool { generating || testing }

    /// The Go is given and nothing is running: the copilot may write the next version. Needs a key (this is the one step that does).
    func startBuild(with chat: ChatModel) {
        guard BuildRunner.canBuild(store) else { error = "The build never starts without the Go. Give it from the toolbar once every scene is OK."; return }
        guard !buildBusy else { return }
        let v = Versions.next(store)
        do { try Film.write(version: v, store: store) } catch { self.error = "Could not write \(v)/film.json: \(error.localizedDescription)"; return }   // the exact montage, for the build to read
        buildVersion = v
        generating = true
        buildReport = nil
        let sent = chat.ask(prompt: BuildRunner.prompt(version: v, store: store)) { [weak self] in self?.finishGeneration(v) }
        if !sent { generating = false } else { inspectorTab = .copilot }       // the user sees what the copilot does
    }

    private func finishGeneration(_ v: String) {
        generating = false
        guard Versions.list(store).contains(v) else {
            error = "The copilot did not write \(v) (project.json and main.js). See what it said in the chat, then try again."
            refresh(); return
        }
        runChecks(v)
    }

    /// Builds the version with the skill's scripts and tests it. No AI: usable on a version that already exists.
    func runChecks(_ v: String) {
        guard !buildBusy, let skill = Skill.root() else { return }
        testing = true; buildVersion = v
        Task { @MainActor in
            let report = await BuildRunner.run(version: v, store: store, skill: skill)
            try? store.record(report)
            buildReport = report
            testing = false
            if report.built { playVersion = v; playNonce += 1 }
            refresh(); reloadTree()
        }
    }

    // MARK: wizard (Beginner mode): the same data and operations as the blocks

    var builtSteps: [WizardStep] { wizardSteps.filter { $0.isBuilt } }

    func isDecided(_ step: WizardStep) -> Bool {
        Wizard.isDecided(step, file: showreel, assets: assets, settings: store.settings, spec: spec)
    }

    var wizardProgress: (decided: Int, total: Int) {
        Wizard.progress(wizardSteps, file: showreel, assets: assets, settings: store.settings, spec: spec)
    }

    /// Goes to the first built step that is not decided yet; after the last one, the "done for now" screen.
    func resumeWizard() {
        refresh()
        wizardIndex = Wizard.firstUndecided(wizardSteps, file: showreel, assets: assets, settings: store.settings, spec: spec) ?? builtSteps.count
    }

    /// Every built step is decided: the wizard has nothing more to ask, and the workspace is where the work goes on.
    var wizardFinished: Bool { showreel != nil && !builtSteps.isEmpty && wizardProgress.decided == wizardProgress.total }

    func wizardNext() { wizardIndex = min(wizardIndex + 1, builtSteps.count) }
    func wizardBack() { wizardIndex = max(wizardIndex - 1, 0) }

    func jumpToFirstUndecided(in area: String) {
        if let i = builtSteps.firstIndex(where: { $0.area == area && !isDecided($0) }) ?? builtSteps.firstIndex(where: { $0.area == area }) { wizardIndex = i }
    }

    /// The user settled a question without giving a value ("nothing special", "no files yet").
    func markDecided(_ step: WizardStep) { store.markDecided(step.id); refresh() }

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
        if let v = versions.last, Versions.hasDist(store, v) { return v }
        return nil
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

    func restoreScene(_ id: String) { perform(.scene(id: id, SceneEdit(status: "open", archived: false))) }

    // MARK: setup, update, checks (phases P2 and P3): the rules are ShowreelKit's

    /// The user opens the workspace: only when the base configuration is complete (the form enables its button on that).
    func finishSetup() {
        guard store.needsSetup else { workspaceOpen = true; return }       // a project that never asked for its setup is never held back
        do { try store.finishSetup(); needsSetup = false; if mode == StudioSettings.beginner { workspaceOpen = true } }
        catch { self.error = error.localizedDescription }
    }

    /// What "Update project" would do now, to show before doing it.
    var updatePlan: UpdatePlan? { ProjectFormat.plan(store) }

    /// Backs the data up, migrates and writes the current revision (the user decided: nothing is written before this).
    func updateProject() {
        do {
            let r = try ProjectFormat.update(store)
            showUpdateSheet = false; updateBannerDismissed = false
            refresh(); reloadTree()
            showToast("Updated to revision \(ProjectFormat.current). The backup is in .studio/backups/\(r.backup.id)")
        } catch { self.error = error.localizedDescription; refresh() }
    }

    func restoreBackup(_ b: ProjectBackup) {
        do { try ProjectFormat.restore(store, b); refresh(); reloadTree(); showToast("Restored the backup \(b.id)") } catch { self.error = error.localizedDescription }
    }

    /// A click on a check opens the element it is about, on the right section.
    func openCheck(_ e: CheckEntry) {
        switch e.target {
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
        do { try store.apply(op); refresh(); LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step); return true }
        catch { self.error = error.localizedDescription; refresh(); return false }
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

    /// The copilot (or a link) asks for a zone of the workspace. In the wizard, it goes to the first undecided step of that part.
    func openZone(_ id: String) {
        if mode == StudioSettings.beginner, !workspaceOpen {
            let areas: [String] = ["library": ["resources"], "inspector": ["project", "look"], "storyboard": ["storyboard", "scene"], "build": ["build"]][id] ?? []
            for a in areas where builtSteps.contains(where: { $0.area == a && !isDecided($0) }) { jumpToFirstUndecided(in: a); return }
            if let a = areas.first { jumpToFirstUndecided(in: a) }
            return
        }
        workspaceOpen = true
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
            if mode == StudioSettings.beginner { resumeWizard() }
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
        if mode == StudioSettings.beginner && !workspaceOpen {
            parts.append("mode: beginner (wizard)" + (wizardIndex < builtSteps.count ? ", question on screen: \(builtSteps[wizardIndex].title)" : ""))
        } else if let b = foregroundBlock { parts.append("mode: \(mode == StudioSettings.beginner ? "beginner, workspace" : "expert"), in front of the user: \(b)") }
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
    }
}
