import Foundation

/// What a form field commits and when (AS1: no Save button, what you type or add is saved). Pure, with the clock passed in, so every rule is tested without a screen.
///
/// A field is `text` (commits when it loses focus, on Return, or after a pause in typing), `numeric` (on focus loss, on Return, or shortly after a step with the stepper or the arrow keys,
/// so holding a chevron makes one commit) or `instant` (a switch, a chip, a picker choice: at once). An invalid value never commits: the field keeps the draft, shows the reason, and
/// nothing is stored until the draft is valid or the owner restores the stored value.
public struct EditSession {
    public static let textPause = 0.7
    public static let stepDebounce = 0.3
    /// Commits to one field closer together than this are one undo step.
    public static let undoWindow = 2.0

    public enum Kind: Equatable, Sendable { case text, numeric, instant }

    public struct Field: Equatable, Sendable {
        public var kind: Kind
        public var stored: String
        public var draft: String
        /// When the draft last changed; nil when it is clean or already waiting for a blur or a Return.
        public var changedAt: Date?
        public var stepped = false
        public var invalid: String?
        public var isDirty: Bool { draft != stored }
    }

    public struct Commit: Equatable, Sendable {
        public let key: String
        public let value: String
    }

    /// What happened to a field when the stored value changed somewhere else.
    public enum External: Equatable, Sendable { case unchanged, updated, keptDraft }

    public private(set) var fields: [String: Field] = [:]
    /// Scenes whose "back to To review" was already said in this session.
    private var announced: Set<String> = []
    private let validate: @Sendable (String, String) -> String?

    public init(validate: @escaping @Sendable (String, String) -> String? = { _, _ in nil }) { self.validate = validate }

    public func field(_ key: String) -> Field? { fields[key] }
    public var pending: [String] { fields.filter { $0.value.isDirty && $0.value.invalid == nil }.map { $0.key }.sorted() }

    /// Declares a field with the value stored now. A clean field takes the new stored value; a dirty one keeps the owner's draft, which will win when it commits.
    @discardableResult
    public mutating func load(_ key: String, stored: String, kind: Kind) -> External {
        guard var f = fields[key] else { fields[key] = Field(kind: kind, stored: stored, draft: stored); return .unchanged }
        f.kind = kind
        if f.stored == stored { fields[key] = f; return .unchanged }
        let dirty = f.isDirty            // judged against the value it had, before the other change
        f.stored = stored
        if dirty { fields[key] = f; return .keptDraft }
        f.draft = stored; f.changedAt = nil; f.invalid = nil
        fields[key] = f
        return .updated
    }

    /// The owner changed the draft. An instant field commits at once; the others wait for their moment (`due`, `blur`, `returnKey`). `stepped` marks a change made with a stepper or arrow keys.
    public mutating func edit(_ key: String, draft: String, at now: Date, stepped: Bool = false) -> Commit? {
        guard var f = fields[key] else { return nil }
        f.draft = draft; f.stepped = stepped
        f.invalid = f.isDirty ? validate(key, draft) : nil
        f.changedAt = f.isDirty ? now : nil
        fields[key] = f
        guard f.isDirty, f.invalid == nil, f.kind == .instant else { return nil }
        return take(key)
    }

    /// The last change was made with a stepper or the arrow keys: a numeric field then commits after the debounce, so holding a chevron makes one commit.
    public mutating func markStepped(_ key: String, at now: Date) {
        guard var f = fields[key], f.isDirty else { return }
        f.stepped = true; f.changedAt = now
        fields[key] = f
    }

    /// The commits whose moment has come: a text field after the pause, a stepped numeric field after the debounce.
    public mutating func due(at now: Date) -> [Commit] {
        var out: [Commit] = []
        for (k, f) in fields.sorted(by: { $0.key < $1.key }) {
            guard f.isDirty, f.invalid == nil, let t = f.changedAt else { continue }
            let wait: Double?
            switch f.kind { case .text: wait = Self.textPause; case .numeric: wait = f.stepped ? Self.stepDebounce : nil; case .instant: wait = 0 }
            if let w = wait, now.timeIntervalSince(t) >= w, let c = take(k) { out.append(c) }
        }
        return out
    }

    public mutating func blur(_ key: String) -> Commit? { take(key) }
    public mutating func returnKey(_ key: String) -> Commit? { take(key) }

    /// Everything pending, valid ones only: before the owner selects another scene, switches a tab, closes the pane or the window, or starts a Build. Invalid drafts stay.
    public mutating func flush() -> [Commit] { fields.keys.sorted().compactMap { take($0) } }

    /// The owner gives up the draft: the stored value comes back.
    public mutating func restore(_ key: String) {
        guard var f = fields[key] else { return }
        f.draft = f.stored; f.changedAt = nil; f.invalid = nil; f.stepped = false
        fields[key] = f
    }

    /// The store accepted the commit (or the value now stored is another one): the field is clean.
    public mutating func stored(_ key: String, _ value: String) {
        guard var f = fields[key] else { return }
        f.stored = value
        if f.draft == value { f.changedAt = nil; f.invalid = nil }
        fields[key] = f
    }

    /// The store refused: the draft stays, the reason shows next to the field.
    public mutating func refused(_ key: String, reason: String) {
        guard var f = fields[key] else { return }
        f.invalid = reason; f.changedAt = nil
        fields[key] = f
    }

    /// Selecting another scene closes the session: the fields go and the announcements start over.
    public mutating func close() { fields = [:]; announced = [] }

    /// True the first time a scene going back to To review is announced in this session, so the status line says it once.
    public mutating func announceReview(_ scene: String) -> Bool { announced.insert(scene).inserted }

    private mutating func take(_ key: String) -> Commit? {
        guard var f = fields[key], f.isDirty else { return nil }
        if f.invalid == nil { f.invalid = validate(key, f.draft) }
        guard f.invalid == nil else { f.changedAt = nil; fields[key] = f; return nil }
        f.changedAt = nil
        fields[key] = f
        return Commit(key: key, value: f.draft)
    }
}

/// The fields of a scene's form: how each is read, checked and turned into the one typed operation. The rules the store holds (a locked scene, a Build) stay with `plan()`.
public enum SceneFields: Sendable {
    public static let duration = "duration", text = "text", visual = "visual", feeling = "feeling", handoff = "handoff", assets = "assets"

    public static func kind(_ key: String) -> EditSession.Kind {
        switch key { case duration: return .numeric; case assets: return .instant; default: return .text }
    }

    /// Why a draft cannot be stored, or nil. A duration is a positive number of seconds.
    public static func invalid(_ key: String, _ value: String) -> String? {
        guard key == duration else { return nil }
        let v = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if v.isEmpty { return nil }
        guard let d = Double(v), d.isFinite else { return "A duration is a number of seconds, such as 3 or 2.5." }
        return d > 0 ? nil : "A duration is more than 0 seconds."
    }

    public static func edit(_ key: String, _ value: String) -> SceneEdit {
        var e = SceneEdit()
        switch key {
        case duration: e.duration = value
        case text: e.text = value
        case visual: e.visual = value
        case feeling: e.feeling = value
        case handoff: e.handoff = value
        default: e.assets = value
        }
        return e
    }

    /// The journal and undo key of one field of one scene.
    public static func undoKey(_ scene: String, _ field: String) -> String { "scene:\(scene):\(field)" }
}
