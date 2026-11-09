import Foundation

/// One line of the project's journal: what was done (or proposed and refused), by whom, to what, from what to what. The journal is the memory of every typed
/// operation, so that what was decided, refused or taken back is never lost, whichever model is in use or however often the project is reopened.
public struct JournalEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var time: Date
    /// user, clap (the copilot), skill (a re-import of what a chat wrote) or app (the app's own doing: an update, a restore).
    public var author: String
    /// The kind of operation (`ProjectOperation.kind`), its target, and the card's title.
    public var op: String
    public var target: String
    public var title: String
    /// What it changed, before and after, as the card said it.
    public var before: String
    public var after: String
    /// applied, refused, undone or redone.
    public var state: String
    /// The reason or the note, when there is one.
    public var note: String?
    /// The session (the chat session's name) the entry belongs to.
    public var session: String
    /// For an undo or a redo: the entry it is about.
    public var ref: String?

    public static let authors = ["user", "clap", "skill", "app"]
    public static let states = ["applied", "refused", "undone", "redone"]
    static let valueLimit = 600

    static func clip(_ s: String, _ n: Int = valueLimit) -> String {
        let one = s.replacingOccurrences(of: "\n", with: " ")
        return one.count > n ? String(one.prefix(n - 1)) + "\u{2026}" : one
    }

    public init(id: String = "j-" + UUID().uuidString.prefix(8).lowercased(), time: Date = Date(), author: String, op: String, target: String, title: String,
                before: String = "", after: String = "", state: String, note: String? = nil, session: String, ref: String? = nil) {
        self.id = id; self.time = time; self.author = author; self.op = op; self.target = target; self.title = Self.clip(title, 200)
        self.before = Self.clip(before); self.after = Self.clip(after); self.state = state
        self.note = note.flatMap { n in let t = Self.clip(n.trimmingCharacters(in: .whitespacesAndNewlines), 400); return t.isEmpty ? nil : t }
        self.session = session; self.ref = ref
    }

    /// The line that records an undo (the values swapped) or a redo (as first done) of this entry.
    public func derived(_ state: String, author: String, session: String, swap: Bool, at time: Date = Date()) -> JournalEntry {
        JournalEntry(time: time, author: author, op: op, target: target, title: title, before: swap ? after : before, after: swap ? before : after, state: state, note: nil, session: session, ref: id)
    }
}

extension ProjectOperation {
    /// The name of the kind of operation, for the journal.
    public var kind: String {
        switch self {
        case .parameter: return "parameter"
        case .decisions: return "decisions"
        case .asset: return "asset"
        case .gate: return "gate"
        case .scene: return "scene"
        case .addScene: return "addScene"
        case .sceneEnabled: return "sceneEnabled"
        case .moveScene: return "moveScene"
        case .sceneLook: return "sceneLook"
        case .content: return "content"
        case .resize: return "resize"
        case .moveCut: return "moveCut"
        case .transition: return "transition"
        case .track: return "track"
        case .grid: return "grid"
        case .gridSettings: return "gridSettings"
        case .moveAsset: return "moveAsset"
        case .sceneLock: return "sceneLock"
        }
    }

    /// What it is about: a scene, a resource, a setting, an item of a scene.
    public var target: String {
        switch self {
        case .parameter(let k, _): return k.rawValue
        case .decisions(let l, _): return l.map { $0.key.rawValue }.joined(separator: ",")
        case .asset(let id, _, _, _, _): return id
        case .gate(let k, _): return k
        case .scene(let id, _): return id
        case .addScene(let id, _): return id.isEmpty ? "new scene" : id
        case .sceneEnabled(let id, _, _): return id
        case .moveScene(let id, _, _): return id
        case .sceneLook(let id, let l): return ([id] + l.map { $0.key.rawValue }).joined(separator: " ")
        case .content(let s, let op):
            switch op {
            case .add: return s
            case .update(let i, _), .remove(let i), .move(let i, _): return s + " " + i
            }
        case .resize(let s, _, _): return s
        case .moveCut(let a, let b, _): return a + " " + b
        case .transition(let from, _): return from
        case .track(let a): return a ?? "none"
        case .sceneLock(let ids, _): return ids.joined(separator: " ")
        case .grid, .gridSettings: return "grid"
        case .moveAsset(let id, _): return id
        }
    }
}

/// The journal of a project: `.studio/journal.jsonl`, append only. One line per write, one write per line, never a rewrite: a crash can cut a line short,
/// never damage the ones before it, and a line that cannot be read is skipped when reading.
public final class Journal: @unchecked Sendable {
    public static let path = ".studio/journal.jsonl"
    public let url: URL
    private let lock = NSLock()

    public init(root: URL) { url = root.appendingPathComponent(Self.path) }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return e
    }()
    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    /// A name for a session: the time, to the millisecond, like the chat's own session files (`yyyyMMdd-HHmmss-SSS`).
    public static func newSessionID(_ d: Date = Date()) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return f.string(from: d)
    }

    /// Adds one line. Returns false when it could not be written (the project goes on: the journal is a record, not a precondition).
    @discardableResult
    public func append(_ e: JournalEntry) -> Bool {
        guard var line = try? Self.encoder.encode(e) else { return false }
        line.removeAll { $0 == 0x0A }
        line.append(0x0A)
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) } == line.count
    }

    /// Every line that can be read, oldest first.
    public func entries() -> [JournalEntry] {
        lock.lock(); defer { lock.unlock() }
        guard let t = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return t.split(separator: "\n").compactMap { try? Self.decoder.decode(JournalEntry.self, from: Data($0.utf8)) }
    }
}

extension ProjectStore {
    /// Records an operation that was applied, with the card that described it. Inside a group of operations the line joins the group's undo step.
    func noteApplied(_ op: ProjectOperation, _ card: OperationCard, author: String, reason: String?) {
        let e = JournalEntry(author: author, op: op.kind, target: op.target, title: card.title,
                             before: card.changes.map { "\($0.label): \($0.before)" }.joined(separator: "; "), after: card.changes.map { "\($0.label): \($0.after)" }.joined(separator: "; "),
                             state: "applied", note: reason.map { MemoryRules.redact($0) }, session: sessionID)
        journal.append(e)
        undoLog.note(e)
        if e.note != nil { DocSync.sync(self) }        // a reason feeds the brief's decisions log
    }

    /// Records a proposal that was not applied: the user said no, or the rules did not allow it. `card` is nil when there was no card.
    public func noteRefused(_ op: ProjectOperation, card: OperationCard?, author: String, note: String) {
        journal.append(JournalEntry(author: author, op: op.kind, target: op.target, title: card?.title ?? "Proposed \(op.kind) on \(op.target)",
                                    before: card?.changes.map { "\($0.label): \($0.before)" }.joined(separator: "; ") ?? "", after: card?.changes.map { "\($0.label): \($0.after)" }.joined(separator: "; ") ?? "",
                                    state: "refused", note: MemoryRules.redact(note), session: sessionID))
    }

    /// A line for something the app itself did (an update, a restore) or a re-import of what a chat wrote.
    public func noteEvent(author: String, op: String, target: String, title: String, before: String = "", after: String = "", note: String? = nil) {
        journal.append(JournalEntry(author: author, op: op, target: target, title: title, before: before, after: after, state: "applied", note: note, session: sessionID))
    }
}

/// Where a journal line leads: the element it is about.
public enum JournalLinks {
    public static func target(of e: JournalEntry) -> CheckTarget? {
        let first = e.target.split(separator: " ").first.map(String.init) ?? e.target
        switch e.op {
        case "parameter": return .project
        case "decisions":
            let keys = e.target.split(separator: ",").map(String.init)
            if keys.contains("palette") { return .look(.palette) }
            if keys.contains("titleFont") || keys.contains("textFont") { return .look(.fonts) }
            if keys.contains("background") || keys.contains("backgroundMood") { return .look(.background) }
            if keys.contains("moods") { return .look(.moods) }
            if keys.contains("effectsPack") { return .look(.effects) }
            return .look(.looks)
        case "asset", "moveAsset": return .resource(first)
        case "gate": return ["interview"].contains(first) ? .project : first == "assets" ? .resources : first == "style" ? .look(.looks) : first == "build" || first == "verify" || first == "publish" ? .build : .storyboard
        case "scene", "addScene", "sceneEnabled", "moveScene", "resize", "moveCut", "sceneLock": return CheckPanel.firstScene(in: first).map { .scene($0, tab: "settings") } ?? .storyboard
        case "sceneLook": return CheckPanel.firstScene(in: first).map { .scene($0, tab: "look") } ?? .storyboard
        case "content": return CheckPanel.firstScene(in: first).map { .scene($0, tab: "composition") } ?? .storyboard
        case "transition": return .transition(from: first)
        case "track", "grid", "gridSettings": return .music
        case "update", "restore", "reimport": return .project
        default: return nil
        }
    }
}
