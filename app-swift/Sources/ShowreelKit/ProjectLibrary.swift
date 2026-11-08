import Foundation

public struct LibraryEntry: Codable, Identifiable, Equatable {
    public var id: String
    public var path: String
    public var name: String
    public var lastOpened: Date
    public var step: String
    public var pinned: Bool
    public var archived: Bool
}

/// The list of projects the app knows, in `~/Library/Application Support/ShowreelStudio/projects.json`.
public final class ProjectLibrary {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ShowreelStudio/projects.json")
    }

    public let url: URL
    public private(set) var entries: [LibraryEntry] = []

    public init(url: URL = ProjectLibrary.defaultURL) {
        self.url = url
        load()
    }

    private struct Wrapper: Codable { var projects: [LibraryEntry] }

    public func load() {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        guard let d = try? Data(contentsOf: url), let w = try? dec.decode(Wrapper.self, from: d) else { entries = []; return }
        entries = w.projects
    }

    public func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? enc.encode(Wrapper(projects: entries)).write(to: url, options: .atomic)
    }

    /// Pinned first, then the most recently opened. Archived projects are left out.
    public var visible: [LibraryEntry] {
        entries.filter { !$0.archived }.sorted { ($0.pinned ? 1 : 0, $0.lastOpened) > ($1.pinned ? 1 : 0, $1.lastOpened) }
    }
    public var archived: [LibraryEntry] { entries.filter { $0.archived }.sorted { $0.lastOpened > $1.lastOpened } }

    private static func key(_ path: String) -> String { URL(fileURLWithPath: path).standardizedFileURL.path }

    public func entry(forPath path: String) -> LibraryEntry? { entries.first { Self.key($0.path) == Self.key(path) } }

    /// Adds a project folder, or reopens its entry when it is already known.
    @discardableResult
    public func add(path: String, name: String? = nil, now: Date = Date()) -> LibraryEntry {
        let p = Self.key(path)
        if let i = entries.firstIndex(where: { Self.key($0.path) == p }) {
            entries[i].archived = false
            entries[i].lastOpened = now
            if let n = name { entries[i].name = n }
            save()
            return entries[i]
        }
        let e = LibraryEntry(id: UUID().uuidString, path: p, name: name ?? URL(fileURLWithPath: p).lastPathComponent,
                             lastOpened: now, step: "start", pinned: false, archived: false)
        entries.append(e)
        save()
        return e
    }

    public func touch(path: String, name: String? = nil, step: String? = nil, now: Date = Date()) {
        guard let i = entries.firstIndex(where: { Self.key($0.path) == Self.key(path) }) else { return }
        entries[i].lastOpened = now
        if let n = name, !n.isEmpty { entries[i].name = n }
        if let s = step { entries[i].step = s }
        save()
    }

    /// Reads each project's showreel.json for its name and step. Does not change the opened date.
    public func refreshMetadata() {
        var changed = false
        for i in entries.indices {
            guard let f = ProjectStore(root: URL(fileURLWithPath: entries[i].path)).loadShowreel() else { continue }
            let name = f.name.isEmpty ? entries[i].name : f.name
            if entries[i].name != name || entries[i].step != f.step { entries[i].name = name; entries[i].step = f.step; changed = true }
        }
        if changed { save() }
    }

    public func setPinned(_ id: String, _ on: Bool) { update(id) { $0.pinned = on } }
    public func setArchived(_ id: String, _ on: Bool) { update(id) { $0.archived = on; if on { $0.pinned = false } } }
    /// Removes the entry only; the folder and its files stay where they are.
    public func remove(_ id: String) { entries.removeAll { $0.id == id }; save() }

    private func update(_ id: String, _ f: (inout LibraryEntry) -> Void) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        f(&entries[i]); save()
    }
}

// MARK: what the Library window shows, and what it may do

/// Where a project stands, in one plain word: never a button.
public enum LibraryState: String, Sendable {
    case setup = "Setup", storyboard = "Storyboard", built = "Built", outdated = "Outdated", missing = "Missing"
}

public enum LibraryRules {
    /// Missing: the folder is gone. Outdated: its showreel.json is of an older revision (opening it writes nothing; Update does). Built: a version has been built.
    /// Setup: the base configuration is not complete (or there is no readable showreel.json yet). Storyboard: the rest of the work.
    public static func state(path: String) -> LibraryState {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return .missing }
        let store = ProjectStore(root: URL(fileURLWithPath: path))
        guard let f = store.loadShowreel() else { return .setup }
        if f.isOutdated { return .outdated }
        if Versions.list(store).contains(where: { Versions.hasDist(store, $0) }) { return .built }
        return ProjectSetup.isComplete(f) ? .storyboard : .setup
    }

    private static func standard(_ path: String) -> String { URL(fileURLWithPath: path).standardizedFileURL.path }

    /// Why a project cannot be updated or restored from the Library now, or nil. A project open in a window holds its own copy of the data: close it first.
    public static func refusal(forChangingDataOf path: String, openPaths: Set<String>) -> String? {
        openPaths.map(standard).contains(standard(path)) ? "This project is open in a window: close it first." : nil
    }

    /// Why a project cannot be moved to the Trash, or nil.
    public static func trashRefusal(path: String, openPaths: Set<String>) -> String? {
        let p = standard(path)
        if openPaths.map(standard).contains(p) { return "This project is open in a window: close it before moving it to the Trash." }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue else { return "The folder is missing: there is nothing to move. Use Remove." }
        if p == "/" || p == NSHomeDirectory() || URL(fileURLWithPath: p).pathComponents.count < 4 { return "This folder is too important to move: it does not look like a project folder." }
        return nil
    }

    public struct TrashPrompt: Equatable, Sendable {
        public let name: String
        public let path: String
        public let bytes: Int64
        public let message: String
    }

    /// The question asked before moving a project folder to the Trash: it names the folder and says how big it is.
    public static func trashPrompt(name: String, path: String) -> TrashPrompt {
        let bytes = folderSize(path)
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        let folder = URL(fileURLWithPath: path).lastPathComponent
        return TrashPrompt(name: name, path: path, bytes: bytes,
                           message: "Move the folder \u{201C}\(folder)\u{201D} (\(size), \(standard(path))) to the Trash? Project \u{201C}\(name)\u{201D} leaves the Library. The Trash keeps the files until you empty it.")
    }

    public static func folderSize(_ path: String) -> Int64 {
        guard let e = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let u as URL in e {
            let v = try? u.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if v?.isRegularFile == true { total += Int64(v?.fileSize ?? 0) }
        }
        return total
    }

    /// Moves the folder to the Trash with `trash` (the system's, which never deletes for good) and takes the entry out of the Library. Nothing else is ever deleted.
    public static func moveToTrash(_ e: LibraryEntry, in library: ProjectLibrary, openPaths: Set<String>, using trash: (URL) throws -> Void) throws {
        if let why = trashRefusal(path: e.path, openPaths: openPaths) { throw AgentError.msg(why) }
        try trash(URL(fileURLWithPath: e.path))
        library.remove(e.id)
    }

    /// The system's Trash.
    public static func systemTrash(_ url: URL) throws { try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
}

extension ProjectLibrary {
    /// A missing project's folder, found again: the entry follows it.
    public func locate(_ id: String, to path: String) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { throw AgentError.msg("that is not a folder") }
        guard let i = entries.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("unknown project") }
        let p = URL(fileURLWithPath: path).standardizedFileURL.path
        if let other = entries.first(where: { $0.id != id && URL(fileURLWithPath: $0.path).standardizedFileURL.path == p }) { throw AgentError.msg("that folder is already in the Library as \u{201C}\(other.name)\u{201D}") }
        entries[i].path = p
        save()
    }
}
