import Foundation

/// The sizes of the workspace's panels (library width, inspector width, storyboard height), remembered per project. A panel has a floor, so its
/// content stays usable, and no ceiling: the window is the only limit. Absent sizes mean the standard layout.
public struct PanelLayout: Codable, Equatable, Sendable {
    public static let minLibrary = 200.0, minInspector = 280.0, minStrip = 200.0, minSettings = 380.0
    public static let standardLibrary = 290.0, standardInspector = 390.0, standardStrip = 300.0, standardSettings = 560.0

    public var library: Double?
    public var inspector: Double?
    public var strip: Double?
    /// The project settings panel (opened from the top bar), which slides in over the right side.
    public var settings: Double?

    public init(library: Double? = nil, inspector: Double? = nil, strip: Double? = nil, settings: Double? = nil) {
        self.library = Self.floored(library, Self.minLibrary); self.inspector = Self.floored(inspector, Self.minInspector); self.strip = Self.floored(strip, Self.minStrip)
        self.settings = Self.floored(settings, Self.minSettings)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(library: try c.decodeIfPresent(Double.self, forKey: .library), inspector: try c.decodeIfPresent(Double.self, forKey: .inspector), strip: try c.decodeIfPresent(Double.self, forKey: .strip),
                  settings: try c.decodeIfPresent(Double.self, forKey: .settings))
    }

    /// A size with the floor applied; nil for something that is not a size (not finite).
    public static func floored(_ v: Double?, _ min: Double) -> Double? {
        guard let v = v, v.isFinite else { return nil }
        return Swift.max(v, min)
    }

    public var libraryWidth: Double { library ?? Self.standardLibrary }
    public var inspectorWidth: Double { inspector ?? Self.standardInspector }
    public var stripHeight: Double { strip ?? Self.standardStrip }
    public var settingsWidth: Double { settings ?? Self.standardSettings }
    public var isStandard: Bool { library == nil && inspector == nil && strip == nil && settings == nil }
}

/// How the storyboard strip was left: the time scale, how far it is scrolled, and whether it follows the width (the whole film in view).
public struct TimelineMemory: Codable, Equatable, Sendable {
    public var pps: Double?
    public var scroll: Double?
    /// True (or absent): the strip shows the whole film and refits when its panel is resized. False: the user chose a scale.
    public var fitAll: Bool?
    public init(pps: Double? = nil, scroll: Double? = nil, fitAll: Bool? = nil) { self.pps = pps; self.scroll = scroll; self.fitAll = fitAll }
}

/// App-private settings of one project, kept in `.studio/ui.json`.
public struct StudioSettings: Codable, Equatable {
    /// How a project was set up, chosen once when it was created: "wizard" (Clap leads a short interview and proposes a starting pack) or "manual" (the user fills the form).
    /// The older words are still read: "beginner" is wizard, "expert" is manual. The setting lives in `.studio/ui.json`, never in showreel.json.
    public static let wizard = "wizard", manual = "manual"

    /// When true the copilot's edits are written at once instead of shown as cards and proposals.
    public var applyDirectly = false
    /// "wizard" or "manual", set when the project is created. A folder that has no setting yet (made earlier, or opened from elsewhere) is manual, as it was used so far.
    public var mode: String
    /// Wizard steps the user settled without giving a value ("none needed"). Everything else is decided by the data itself.
    public var decided: [String]
    /// The panel sizes of the workspace; nil is the standard layout.
    public var layout: PanelLayout?
    /// A project made by the app starts with its base configuration to fill in; the workspace opens when that is done. A folder that has no such flag
    /// (made earlier, or opened from elsewhere) is never blocked.
    public var setupRequired: Bool
    /// The strip's time scale and scroll; nil: it opens showing the whole film.
    public var timeline: TimelineMemory?
    /// The groups of the Resources list that the user folded, by key ("images", "images.available"...): remembered for this project.
    public var collapsed: [String]?
    /// Whether the music's grid is drawn over the frames of the strip; nil: shown.
    public var gridVisible: Bool?

    public init(applyDirectly: Bool = false, mode: String = StudioSettings.manual, decided: [String] = [], layout: PanelLayout? = nil, setupRequired: Bool = false, timeline: TimelineMemory? = nil) {
        self.applyDirectly = applyDirectly; self.mode = mode; self.decided = decided; self.layout = layout; self.setupRequired = setupRequired; self.timeline = timeline
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        applyDirectly = try c.decodeIfPresent(Bool.self, forKey: .applyDirectly) ?? false
        let m = try c.decodeIfPresent(String.self, forKey: .mode)
        mode = (m == Self.wizard || m == "beginner") ? Self.wizard : Self.manual
        decided = try c.decodeIfPresent([String].self, forKey: .decided) ?? []
        layout = try c.decodeIfPresent(PanelLayout.self, forKey: .layout)
        setupRequired = try c.decodeIfPresent(Bool.self, forKey: .setupRequired) ?? false
        timeline = try c.decodeIfPresent(TimelineMemory.self, forKey: .timeline)
        collapsed = try c.decodeIfPresent([String].self, forKey: .collapsed)
        gridVisible = try c.decodeIfPresent(Bool.self, forKey: .gridVisible)
    }
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
    /// What the typed operations did, to undo and redo them (in memory, per project; see Undo.swift).
    public let undoLog = UndoLog()
    /// The journal of every typed operation (`.studio/journal.jsonl`, append only), and the session its lines belong to (the chat session's name).
    public let journal: Journal
    public var sessionID: String
    let memoryLock = NSRecursiveLock()

    public init(root: URL) {
        self.root = root.standardizedFileURL
        journal = Journal(root: self.root)
        sessionID = Journal.newSessionID()
    }

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

    /// Marks a wizard step as settled without a value ("none needed").
    public func markDecided(_ step: String) {
        var s = settings
        if !s.decided.contains(step) { s.decided.append(step); settings = s }
    }

    public func isPrivate(_ rel: String) -> Bool { rel == Self.studioDir || rel.hasPrefix(Self.studioDir + "/") }

    // MARK: read and write

    public func read(_ path: String) -> String? {
        guard let u = try? resolve(path) else { return nil }
        return try? String(contentsOf: u, encoding: .utf8)
    }

    /// Writes a text file. The previous content is saved in the history first; a write that changes nothing is skipped.
    @discardableResult
    public func write(_ path: String, _ content: String, source: WriteSource = .user, syncDocs: Bool = true) throws -> String {
        let u = try resolve(path)
        guard let rel = relativePath(of: u) else { throw AgentError.msg("refused: writes stay inside the project folder") }
        guard !isPrivate(rel) else { throw AgentError.msg("refused: .studio is private to the app") }
        let previous = try? String(contentsOf: u, encoding: .utf8)
        if previous == content { return rel }
        if let p = previous { try snapshot(rel, content: p) }
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: u, atomically: true, encoding: .utf8)
        // the documents the app generates follow showreel.json and the manifest; a file changed outside the app is never overwritten
        if syncDocs, rel == ShowreelFile.fileName || rel == Assets.manifestPath { DocSync.sync(self) }
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

    /// nil when there is no showreel.json or it cannot be read; see `showreelProblem` to tell the two apart.
    public func loadShowreel() -> ShowreelFile? {
        guard let t = read(ShowreelFile.fileName) else { return nil }
        return try? ShowreelFile.decode(t)
    }

    /// Why an existing showreel.json cannot be read, or nil when it is fine or absent. An unreadable file is never replaced.
    public var showreelProblem: String? {
        guard let t = read(ShowreelFile.fileName) else { return hasShowreel ? "showreel.json is not a text file" : nil }
        do { _ = try ShowreelFile.decode(t); return nil } catch { return "showreel.json cannot be read: \(error.localizedDescription)" }
    }

    public var hasShowreel: Bool { fm.fileExists(atPath: root.appendingPathComponent(ShowreelFile.fileName).path) }

    /// Creates `showreel.json` for a new project, and the folder when needed.
    @discardableResult
    public func create(name: String, conversationLanguage: String?, reelLanguages: [String], mode: String = StudioSettings.wizard) throws -> ShowreelFile {
        try fm.createDirectory(at: root.appendingPathComponent(Self.studioDir), withIntermediateDirectories: true)
        let f = ShowreelFile(name: name, conversationLanguage: conversationLanguage, reelLanguages: reelLanguages)
        try save(f)
        var s = settings
        s.mode = mode == StudioSettings.manual ? StudioSettings.manual : StudioSettings.wizard       // chosen once, here
        s.setupRequired = true                 // and does not reach the workspace before its base configuration is set
        settings = s
        return f
    }

    /// Saves showreel.json. From the first save the app owns the file: `origin.tool` becomes "studio" (the skill's export then refuses
    /// to overwrite it). The generated documents follow.
    public func save(_ f: ShowreelFile) throws {
        var g = f
        var o = g.origin ?? ShowreelFile.Origin()
        o.tool = "studio"
        g.origin = o
        if g.gateState("interview") == "passed" { g.gates["interview"] = "passed" }       // derived from the base configuration; written so that what reads the file sees it
        try write(ShowreelFile.fileName, try g.encoded(), source: .user)
    }
}
