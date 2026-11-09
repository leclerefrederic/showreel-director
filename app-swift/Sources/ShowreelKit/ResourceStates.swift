import Foundation

// MARK: how the Resources list is organised

/// The groups of the Resources list. Images, Sounds (sfx and voice), Music (audio tracks) and Fonts; what the film does not embed (video, notes, data) goes to Other.
public enum ResourceGroup: String, CaseIterable, Sendable {
    case images, sounds, music, fonts, other
    public var title: String { switch self { case .images: return "Images"; case .sounds: return "Sounds"; case .music: return "Music"; case .fonts: return "Fonts"; case .other: return "Other" } }
    public static func of(_ type: String) -> ResourceGroup {
        switch type {
        case "logo", "icon", "shot", "photo", "illus", "img", "frames": return .images
        case "sfx", "voice": return .sounds
        case "audio": return .music
        case "font": return .fonts
        default: return .other
        }
    }
}

/// What the user sees of a resource's state: four things only. Under the hood the manifest's statuses stay (Available and Used are approved, Proposal is proposed, Declined is
/// excluded, Needs attention is hold, a placeholder is approved with the tag).
public enum ResourceState: Equatable, Sendable {
    case available
    case used([String])
    case proposal
    case declined
    case needsAttention

    public var title: String {
        switch self {
        case .available: return "Available"
        case .used(let s): return "Used in " + s.joined(separator: ", ")
        case .proposal: return "Proposal"
        case .declined: return "Declined"
        case .needsAttention: return "Needs attention"
        }
    }
    /// The key of the sub-group of the list, in the order they are shown.
    public var key: String {
        switch self { case .needsAttention: return "attention"; case .proposal: return "proposal"; case .used: return "used"; case .available: return "available"; case .declined: return "declined" }
    }
    public static let order = ["attention", "proposal", "used", "available", "declined"]
    public static func heading(_ key: String) -> String {
        switch key { case "attention": return "Needs attention"; case "proposal": return "Proposals"; case "used": return "Used"; case "available": return "Available"; default: return "Declined" }
    }
}

public extension AssetRow {
    var group: ResourceGroup { ResourceGroup.of(type) }

    /// The scenes that use the resource, in the library's order: a scene whose content has an element that is this resource, or that the manifest links it to. Never typed in.
    func usedIn(_ f: ShowreelFile?) -> [String] {
        guard let f = f else { return [] }
        let linked = Set(sceneIDs)
        return f.scenes.filter { !$0.archived && (linked.contains($0.id) || $0.content.contains { $0.resource == id }) }.map { $0.id }
    }

    func state(in f: ShowreelFile?) -> ResourceState {
        switch status {
        case "hold": return .needsAttention
        case "proposed": return .proposal
        case "excluded": return .declined
        default:
            let u = usedIn(f)
            return u.isEmpty ? .available : .used(u)
        }
    }

    /// A file that needs attention is never shown to Clap: it is not in its state, its tools or its prompt.
    var hiddenFromClap: Bool { status == "hold" }
}

public enum Resources {
    public struct Sub: Identifiable, Equatable, Sendable {
        public var id: String { key }
        public let key: String          // "images.used"
        public let heading: String
        public let rows: [AssetRow]
        public let folded: Bool
    }
    public struct Section: Identifiable, Equatable, Sendable {
        public var id: String { group.rawValue }
        public let group: ResourceGroup
        public let subs: [Sub]
        public let folded: Bool
        public var count: Int { subs.reduce(0) { $0 + $1.rows.count } }
    }

    // MARK: tags

    /// The tags of a resource: the ones in showreel.json, and "placeholder" when the manifest says so (the skill's release gate lists those, as before).
    public static func tags(of row: AssetRow, in f: ShowreelFile?) -> [String] {
        var t = f?.resourceTags?[row.id] ?? []
        if row.status == "placeholder", !t.contains("placeholder") { t.append("placeholder") }
        return t
    }
    public static func allTags(_ rows: [AssetRow], in f: ShowreelFile?) -> [String] { Array(Set(rows.flatMap { tags(of: $0, in: f) })).sorted() }

    // MARK: folding, remembered per project

    static func defaultFolded(_ key: String) -> Bool { key.hasSuffix(".declined") }
    public static func isFolded(_ key: String, memory: [String]?) -> Bool {
        let m = memory ?? []
        return m.contains("fold:" + key) || (defaultFolded(key) && !m.contains("open:" + key))
    }
    /// The memory after the user clicked a header.
    public static func toggled(_ key: String, memory: [String]?) -> [String] {
        var m = (memory ?? []).filter { $0 != "fold:" + key && $0 != "open:" + key }
        m.append(isFolded(key, memory: memory) ? "open:" + key : "fold:" + key)
        return m
    }

    // MARK: the list

    /// By type, then by state; a tag filters it. A group with nothing in it is not listed.
    public static func sections(_ rows: [AssetRow], file: ShowreelFile?, tag: String? = nil, memory: [String]? = nil) -> [Section] {
        let kept = rows.filter { r in tag.map { tags(of: r, in: file).contains($0) } ?? true }
        return ResourceGroup.allCases.compactMap { g in
            let mine = kept.filter { $0.group == g }
            guard !mine.isEmpty else { return nil }
            let subs = ResourceState.order.compactMap { k -> Sub? in
                let r = mine.filter { $0.state(in: file).key == k }
                return r.isEmpty ? nil : Sub(key: g.rawValue + "." + k, heading: ResourceState.heading(k), rows: r, folded: isFolded(g.rawValue + "." + k, memory: memory))
            }
            return Section(group: g, subs: subs, folded: isFolded(g.rawValue, memory: memory))
        }
    }

    // MARK: the viewer

    public enum ViewerSubject: Equatable, Sendable { case designBoard, resource(String), film }

    /// What the centre shows, in this order, so that nothing fights for it: the project's design system while its look is being edited; else the resource selected in the
    /// Resources tab; else the film (the player, or the thumbnail at the playhead).
    public static func viewerSubject(designBoardOpen: Bool, resourcesTab: Bool, selectedResource: String?) -> ViewerSubject {
        if designBoardOpen { return .designBoard }
        if resourcesTab, let id = selectedResource { return .resource(id) }
        return .film
    }
}

// MARK: tags and the replacement of a file, as typed operations

public enum ResourceOp: Equatable, Sendable {
    case addTag(id: String, tag: String)
    case removeTag(id: String, tag: String)
    /// Renames a tag on every resource that carries it.
    case renameTag(from: String, to: String)
    /// The corrected file takes the place of the one that was flagged: the checks run again on it.
    case replaceFile(id: String, url: URL)
}

extension ProjectStore {
    static func cleanTag(_ t: String) throws -> String {
        let v = t.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !v.isEmpty, v.count <= 30, !v.contains(","), !v.contains("\n") else { throw AgentError.msg("a tag is a short word or two, without commas") }
        return v
    }

    func planResource(_ op: ResourceOp) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        let rows = Assets.load(self)
        func row(_ id: String) throws -> AssetRow { guard let r = rows.first(where: { $0.id == id }) else { throw AgentError.msg("unknown resource \(id)") }; return r }
        func shown(_ t: [String]) -> String { t.isEmpty ? "(no tag)" : t.joined(separator: ", ") }
        func save(_ mutate: (inout [String: [String]]) -> Void) throws {
            var g = f; var t = g.resourceTags ?? [:]; mutate(&t); t = t.filter { !$0.value.isEmpty }; g.resourceTags = t.isEmpty ? nil : t; try self.save(g)
        }
        switch op {
        case .addTag(let id, let raw):
            let r = try row(id), tag = try Self.cleanTag(raw)
            let before = Resources.tags(of: r, in: f)
            guard !before.contains(tag) else { throw AgentError.msg("no change: \(id) already has the tag \(tag)") }
            if tag == "placeholder", r.status != "approved" { throw AgentError.msg("only a resource that is available can be a placeholder") }
            return (OperationCard(title: "Tag \(r.name) as \(tag)", changes: [Change("Tags of \(id)", shown(before), shown(before + [tag]))]), {
                if tag == "placeholder" { try Assets.update(id, status: .placeholder, note: nil, licence: nil, scenes: nil, in: self) }
                else { try save { $0[id] = ($0[id] ?? []) + [tag] } }
            })
        case .removeTag(let id, let raw):
            let r = try row(id), tag = try Self.cleanTag(raw)
            let before = Resources.tags(of: r, in: f)
            guard before.contains(tag) else { throw AgentError.msg("no change: \(id) does not have the tag \(tag)") }
            return (OperationCard(title: "Remove the tag \(tag) from \(r.name)", changes: [Change("Tags of \(id)", shown(before), shown(before.filter { $0 != tag }))]), {
                if tag == "placeholder" { try Assets.update(id, status: .approved, note: nil, licence: nil, scenes: nil, in: self) }
                else { try save { $0[id] = ($0[id] ?? []).filter { $0 != tag } } }
            })
        case .renameTag(let from, let to):
            let a = try Self.cleanTag(from), b = try Self.cleanTag(to)
            guard a != "placeholder", b != "placeholder" else { throw AgentError.msg("the placeholder tag is the skill's own: it cannot be renamed") }
            guard a != b else { throw AgentError.msg("no change: the tag already is \(b)") }
            let who = (f.resourceTags ?? [:]).filter { $0.value.contains(a) }.keys.sorted()
            guard !who.isEmpty else { throw AgentError.msg("no resource has the tag \(a)") }
            return (OperationCard(title: "Rename the tag \(a) to \(b)", changes: [Change("Tag", a, b), Change("On", "\(who.count) resource\(who.count == 1 ? "" : "s")", who.joined(separator: ", "))]), {
                try save { t in for id in who { var l = t[id] ?? []; l = l.map { $0 == a ? b : $0 }; var seen = Set<String>(); t[id] = l.filter { seen.insert($0).inserted } } }
            })
        case .replaceFile(let id, let url):
            let r = try row(id)
            guard FileManager.default.fileExists(atPath: url.path) else { throw AgentError.msg("the file is not there any more") }
            guard Assets.classify(url.lastPathComponent) == r.type || (ResourceGroup.of(Assets.classify(url.lastPathComponent)) == r.group) else { throw AgentError.msg("the new file is not a \(r.group.title.lowercased().dropLast()) like the one it replaces") }
            return (OperationCard(title: "Replace the file of \(r.name)", changes: [Change("File of \(id)", r.name, url.lastPathComponent), Change("Checks", "the old file's", "run again on the new one: a clean file becomes available, otherwise it still needs attention")]), {
                try Assets.replace(id, with: url, in: self)
            })
        }
    }
}

// MARK: a file that needs attention: why, and what settles it

/// The answers to the rights question, asked only when a file is flagged. Unknown does not settle it: the file stays on Needs attention.
public enum RightsAnswer: String, CaseIterable, Sendable {
    case ownWork = "own work", client = "supplied by the client", licensed = "licensed", free = "free licence", unknown = "unknown"
    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    public var detailHint: String {
        switch self {
        case .ownWork: return "Optional: anything worth remembering"
        case .client: return "Optional: who supplied it, and what they allow"
        case .licensed: return "Optional: the licence, the invoice, what it covers"
        case .free: return "Optional: which licence (for example CC0, OFL)"
        case .unknown: return "Optional: what you know"
        }
    }
    /// The licence note kept in the manifest.
    public func note(detail: String) -> String {
        let d = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return d.isEmpty ? rawValue : rawValue + ": " + d
    }
    /// What the operation is: an approval with this note, except for unknown, which only records it.
    public func operation(id: String, detail: String) -> ProjectOperation {
        .asset(id: id, status: self == .unknown ? nil : .approved, note: nil, licence: note(detail: detail), scenes: nil)
    }
}

public struct ResourceAttention: Equatable, Sendable {
    public let reasons: [String]
    /// The rights question is asked (copyright in the metadata, a font whose licence is unknown or whose flag forbids embedding).
    public let asksRights: Bool
    /// A risk can be accepted with a short reason (a low resolution, a heavy file).
    public let canAcceptRisk: Bool
    /// Only a replaced file (or leaving it out) settles it: a name or a content that suggests real or confidential data.
    public let mustReplace: Bool
    public var isEmpty: Bool { reasons.isEmpty }

    /// For a row that needs attention: the checks run again on its file, in plain words. A row from the skill's own manifest, whose reasons only its note holds, is read from the note.
    public static func of(_ r: AssetRow, store: ProjectStore) -> ResourceAttention {
        guard r.status == "hold" else { return ResourceAttention(reasons: [], asksRights: false, canAcceptRisk: false, mustReplace: false) }
        var flags: [ResourceChecks.Flag] = []
        if !r.original.isEmpty, r.origin != "not copied" { flags = ResourceChecks.flags(store.root.appendingPathComponent("assets/source/" + r.original), rel: r.original, type: r.type) }
        if flags.isEmpty {
            let n = r.notes.lowercased()
            let kind: ResourceChecks.Kind = n.hasPrefix("name suggests") || r.origin == "not copied" ? .sensitive : (n.contains("rights") || n.contains("consent") || n.contains("licen")) ? .rights : .quality
            flags = [ResourceChecks.Flag(kind: kind, reason: r.notes.isEmpty ? "it was put on hold" : r.notes)]
        }
        return ResourceAttention(reasons: flags.map { $0.reason }, asksRights: flags.contains { $0.kind == .rights }, canAcceptRisk: flags.contains { $0.kind == .quality }, mustReplace: flags.contains { $0.kind == .sensitive })
    }
}
