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
    case preview
    case file(String)
}

/// State of one project window: files, open tabs, the showreel, the watcher. Main thread only.
final class ProjectModel: ObservableObject {
    let root: URL
    let store: ProjectStore
    @Published var tree: [FileNode] = []
    @Published var tabs: [EditorTab] = []
    @Published var selected: CenterTab = .preview
    @Published var showreel: ShowreelFile?
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
        loadShowreel()
        if showreel == nil { importOffer = ProjectImporter.importMarkdown(from: root) }
        LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step)
        watcher = FileWatcher(root: root) { [weak self] paths in self?.filesChanged(paths) }
    }

    func loadShowreel() {
        showreel = store.loadShowreel()
    }

    func reloadTree() { tree = ProjectTree.scan(root) }

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
        if selected == .file(tab.path) { selected = tabs.last.map { .file($0.path) } ?? .preview }
    }

    func tab(_ id: String) -> EditorTab? { tabs.first { $0.id == id } }

    /// The file in front of the user, for the copilot's context.
    var foreground: String? {
        if case .file(let p) = selected { return p }
        return nil
    }

    // MARK: save, reload, restore

    func save(_ tab: EditorTab) {
        do {
            try store.write(tab.path, tab.text, source: .user)
            tab.markSaved(tab.text)
            if tab.path == ShowreelFile.fileName { loadShowreel(); refreshTab("brief.md") }
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
            if tab.path == ShowreelFile.fileName { loadShowreel() }
        } catch { self.error = error.localizedDescription }
    }

    private func refreshTab(_ rel: String) {
        guard let t = tab(rel), let disk = store.read(rel) else { return }
        if t.dirty { t.diskChanged = disk != t.saved } else { t.replace(with: disk) }
    }

    /// The watcher saw these files change (the user, the copilot, a script).
    private func filesChanged(_ paths: [String]) {
        reloadTree()
        for p in paths {
            if p == ShowreelFile.fileName { loadShowreel() }
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
