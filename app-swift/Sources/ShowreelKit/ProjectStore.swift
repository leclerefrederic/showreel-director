import Foundation

/// App-private settings of one project, kept in `.studio/ui.json`.
public struct StudioSettings: Codable, Equatable {
    /// When true the copilot's edits are written at once instead of shown as proposals.
    public var applyDirectly = false
    public init(applyDirectly: Bool = false) { self.applyDirectly = applyDirectly }
}

/// One saved earlier version of a file.
public struct Snapshot: Identifiable, Equatable {
    public let id: String          // the timestamp, which is also the file name
    public let url: URL
    public var date: Date?
}

public enum WriteSource: String { case user, copilot, restore }

/// A project folder: reads and writes files safely, keeps the history, owns `showreel.json` and `.studio/`.
public final class ProjectStore {
    public static let studioDir = ".studio"
    public static let historyLimit = 50

    public let root: URL
    private let fm = FileManager.default

    public init(root: URL) { self.root = root.standardizedFileURL }

    // MARK: paths

    /// The path of `url` relative to the project, or nil when it is outside.
    public func relativePath(of url: URL) -> String? {
        guard url.isInside(root) else { return nil }
        let a = url.resolvingSymlinksInPath().standardizedFileURL.path
        let b = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard a.count > b.count else { return "" }
        return String(a.dropFirst(b.count + 1))
    }

    /// The file for a relative path; throws when it would leave the project.
    public func resolve(_ path: String) throws -> URL {
        let u = (path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)).standardizedFileURL
        guard u.isInside(root) else { throw AgentError.msg("refused: writes stay inside the project folder") }
        return u
    }

    public func isPrivate(_ rel: String) -> Bool { rel == Self.studioDir || rel.hasPrefix(Self.studioDir + "/") }

    // MARK: read and write

    public func read(_ path: String) -> String? {
        guard let u = try? resolve(path) else { return nil }
        return try? String(contentsOf: u, encoding: .utf8)
    }

    /// Writes a text file. The previous content is saved in the history first; a write that changes nothing is skipped.
    @discardableResult
    public func write(_ path: String, _ content: String, source: WriteSource = .user) throws -> String {
        let u = try resolve(path)
        guard let rel = relativePath(of: u) else { throw AgentError.msg("refused: writes stay inside the project folder") }
        guard !isPrivate(rel) else { throw AgentError.msg("refused: .studio is private to the app") }
        let previous = try? String(contentsOf: u, encoding: .utf8)
        if previous == content { return rel }
        if let p = previous { try snapshot(rel, content: p) }
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: u, atomically: true, encoding: .utf8)
        if rel == ShowreelFile.fileName { try? syncDecisions() }
        return rel
    }

    // MARK: history

    private func historyDir(_ rel: String) -> URL {
        root.appendingPathComponent(Self.studioDir).appendingPathComponent("history").appendingPathComponent(rel)
    }

    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return f.string(from: d)
    }

    static func date(fromStamp s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return f.date(from: String(s.prefix(19)))
    }

    private func snapshot(_ rel: String, content: String) throws {
        let dir = historyDir(rel)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var name = Self.stamp(Date())
        var n = 1
        while fm.fileExists(atPath: dir.appendingPathComponent(name).path) { n += 1; name = Self.stamp(Date()) + String(format: "-%03d", n) }
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        let all = snapshots(rel)
        for old in all.dropFirst(Self.historyLimit) { try? fm.removeItem(at: old.url) }
    }

    /// Saved versions of a file, newest first.
    public func snapshots(_ rel: String) -> [Snapshot] {
        let dir = historyDir(rel)
        let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.sorted(by: >).map { Snapshot(id: $0, url: dir.appendingPathComponent($0), date: Self.date(fromStamp: $0)) }
    }

    public func content(of s: Snapshot) -> String? { try? String(contentsOf: s.url, encoding: .utf8) }

    /// Puts a saved version back. The current content is saved first, so a restore can be undone.
    public func restore(_ rel: String, _ s: Snapshot) throws {
        guard let old = content(of: s) else { throw AgentError.msg("snapshot not readable") }
        try write(rel, old, source: .restore)
    }

    // MARK: settings

    private var settingsURL: URL { root.appendingPathComponent(Self.studioDir).appendingPathComponent("ui.json") }

    public var settings: StudioSettings {
        get {
            guard let d = try? Data(contentsOf: settingsURL), let s = try? JSONDecoder().decode(StudioSettings.self, from: d) else { return StudioSettings() }
            return s
        }
        set {
            try? fm.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? JSONEncoder().encode(newValue).write(to: settingsURL, options: .atomic)
        }
    }

    // MARK: showreel.json

    public func loadShowreel() -> ShowreelFile? {
        guard let t = read(ShowreelFile.fileName) else { return nil }
        return try? ShowreelFile.decode(t)
    }

    public var hasShowreel: Bool { fm.fileExists(atPath: root.appendingPathComponent(ShowreelFile.fileName).path) }

    /// Creates `showreel.json` for a new project, and the folder when needed.
    @discardableResult
    public func create(name: String, conversationLanguage: String?, reelLanguages: [String]) throws -> ShowreelFile {
        try fm.createDirectory(at: root.appendingPathComponent(Self.studioDir), withIntermediateDirectories: true)
        let f = ShowreelFile(name: name, conversationLanguage: conversationLanguage, reelLanguages: reelLanguages)
        try save(f)
        return f
    }

    public func save(_ f: ShowreelFile) throws {
        try write(ShowreelFile.fileName, try f.encoded(), source: .user)
    }

    /// Rewrites the generated Decisions section of brief.md so that it matches showreel.json. Creates brief.md when absent.
    public func syncDecisions() throws {
        guard let f = loadShowreel() else { return }
        let brief = read("brief.md") ?? ""
        let next = f.applyDecisionsSection(to: brief)
        if next != brief { try write("brief.md", next, source: .user) }
    }
}
