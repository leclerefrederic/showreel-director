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
