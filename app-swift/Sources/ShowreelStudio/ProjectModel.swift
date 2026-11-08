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

enum CenterTab: Hashable {
    case block(String)
    case preview
    case file(String)
}

/// State of one project window: files, open tabs, the showreel, the watcher. Main thread only.
final class ProjectModel: ObservableObject {
    let root: URL
    let store: ProjectStore
    @Published var tree: [FileNode] = []
    @Published var tabs: [EditorTab] = []
    @Published var selected: CenterTab = .block("project")
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
        didSet { store.settings = StudioSettings(applyDirectly: applyDirectly) }
    }

    private var watcher: FileWatcher?

    init(path: String) {
        root = URL(fileURLWithPath: path)
        store = ProjectStore(root: root)
        applyDirectly = store.settings.applyDirectly
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
        LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step)
        watcher = FileWatcher(root: root) { [weak self] paths in self?.filesChanged(paths) }
    }

    /// Reads showreel.json, the manifest and the state of the generated documents again.
    func refresh() {
        showreel = store.loadShowreel()
        assets = Assets.load(store)
        docIssues = DocSync.pending(store).filter { !dismissedDocs.contains($0.file) }
    }

    func loadShowreel() { refresh() }

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

    func status(_ block: String) -> BlockStatus {
        guard let spec = spec else { return .soon }
        return Blocks.status(block, spec: spec, showreel: showreel, assets: assets)
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

    /// The last block the user was in, for the way back from a file in the Advanced panel.
    private(set) var lastBlock = "project"

    func selectBlock(_ id: String) { lastBlock = id; selected = .block(id) }

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
        if tabs.contains(where: { $0.path == rel }) { selected = .file(rel); return }
        guard let text = store.read(rel) else {
            error = "\(rel) is not a readable text file."
            NSWorkspace.shared.open(url)
            return
        }
        tabs.append(EditorTab(path: rel, kind: kind, text: text))
        selected = .file(rel)
    }

    func close(_ tab: EditorTab) {
        tabs.removeAll { $0.id == tab.id }
        if selected == .file(tab.path) { selected = tabs.last.map { .file($0.path) } ?? .block("project") }
    }

    func tab(_ id: String) -> EditorTab? { tabs.first { $0.id == id } }

    /// The file in front of the user, for the copilot's context.
    var foreground: String? {
        if case .file(let p) = selected { return p }
        return nil
    }

    var foregroundBlock: String? {
        if case .block(let b) = selected { return b }
        return nil
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
        if case .block(let b) = selected { parts.append("block in front of the user: \(b)") }
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
