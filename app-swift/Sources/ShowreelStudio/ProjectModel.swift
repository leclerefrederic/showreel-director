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
    case asset(String)
    case look(LookKind, String)
    case file(String)      // a project file opened from the Advanced panel
    case preview           // a page the copilot showed
}

enum LibraryTab: String, CaseIterable, Identifiable {
    case resources, scenes, look
    var id: String { rawValue }
    var title: String { self == .look ? "Look" : rawValue.capitalized }
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
    @Published var libraryTab: LibraryTab = .scenes
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
            if mode == StudioSettings.beginner { resumeWizard(); workspaceOpen = wizardFinished } else { workspaceOpen = true }
        }
    }
    @Published var showCopilot: Bool
    @Published var wizardIndex = 0
    @Published private(set) var wizardSteps: [WizardStep] = []
    @Published private(set) var decided: [String] = []
    /// The deterministic checks of the blocks that have some (no AI), recomputed with the data.
    @Published private(set) var checks: [String: [CheckResult]] = [:]

    private var watcher: FileWatcher?

    init(path: String) {
        root = URL(fileURLWithPath: path)
        store = ProjectStore(root: root)
        let s = store.settings
        applyDirectly = s.applyDirectly
        mode = s.mode
        workspaceOpen = s.mode == StudioSettings.expert
        showCopilot = s.mode == StudioSettings.expert
        decided = s.decided
    }

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
        if mode == StudioSettings.beginner { resumeWizard(); workspaceOpen = wizardFinished }
        LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step)
        watcher = FileWatcher(root: root) { [weak self] paths in self?.filesChanged(paths) }
    }

    /// Reads showreel.json, the manifest and the state of the generated documents again.
    func refresh() {
        showreel = store.loadShowreel()
        assets = Assets.load(store)
        docIssues = DocSync.pending(store).filter { !dismissedDocs.contains($0.file) }
        decided = store.settings.decided
        versions = Versions.list(store)
        if playVersion == nil, let last = versions.last, Versions.hasDist(store, last) { playVersion = last }
        wizardSteps = Wizard.steps(assets: assets, spec: spec, systemLanguage: Locale.current.language.languageCode?.identifier, file: showreel)
        for a in Blocks.areas { checks[a] = Checks.run(area: a, store: store) }
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
    func addScene(copying id: String? = nil) -> Bool {
        var e = SceneEdit(duration: "3")
        if let id = id, let s = showreel?.scenes.first(where: { $0.id == id }) {
            e = SceneEdit(duration: s.duration.map { ProjectDocs.seconds($0) }, text: s.text, visual: s.visual, feeling: s.feeling, handoff: s.handoff, inCuts: s.inCuts)
            e.after = id
        } else if let last = showreel?.storyboards.first?.items.last { e.after = last.scene }
        let before = Set(showreel?.scenes.map { $0.id } ?? [])
        guard perform(.addScene(id: "", e)) else { return false }
        if let n = showreel?.scenes.first(where: { !before.contains($0.id) }) { select(.scene(n.id)) }
        return true
    }

    func setEnabled(_ id: String, _ on: Bool) { perform(.sceneEnabled(id: id, enabled: on, montage: nil)) }

    /// Puts a scene before another one in the master montage (nil: at the end).
    func moveScene(_ id: String, before target: String?) {
        guard let f = showreel, let after = f.position(of: id, before: target) else { return }
        perform(.moveScene(id: id, after: after, montage: nil))
    }

    func archiveScene(_ id: String) {
        perform(.scene(id: id, SceneEdit(archived: true)))
        if selection == .scene(id) { selection = .none }
    }

    func restoreScene(_ id: String) { perform(.scene(id: id, SceneEdit(status: "open", archived: false))) }

    // MARK: operations (the blocks and the copilot use the same ones)

    /// Applies a change the user made in a block. Errors are shown, never swallowed.
    @discardableResult
    func perform(_ op: ProjectOperation) -> Bool {
        do { try store.apply(op); refresh(); LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step); return true }
        catch { self.error = error.localizedDescription; refresh(); return false }
    }

    func addAssets(_ urls: [URL]) {
        do { try Assets.add(urls, to: store); refresh(); reloadTree() } catch { self.error = error.localizedDescription }
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
        case .scene, .asset, .look: inspectorTab = .inspector
        default: break
        }
    }

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
        case "inspector": inspectorTab = .inspector; selection = .none
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

    /// The zone or selection in front of the user, for the copilot's context.
    var foregroundBlock: String? {
        switch selection {
        case .scene(let id): return "inspector: scene \(id)"
        case .asset(let id): return "inspector: resource \(id)"
        case .look(let k, let id): return "inspector: \(k.title.lowercased()) element \(id)"
        case .file, .preview: return nil
        case .none: return centerMode == .build ? "build" : "inspector: project and global look"
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
