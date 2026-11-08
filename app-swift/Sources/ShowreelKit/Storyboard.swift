import Foundation

/// A change to one scene, field by field. Every field is optional: nil leaves it as it is, an empty string clears it.
/// Times are text ("4", "4.5") so that the copilot's tool input and the form share one path.
public struct SceneEdit: Equatable, Sendable {
    public var start: String?
    public var end: String?
    public var text: String?
    public var visual: String?
    public var feeling: String?
    public var handoff: String?
    public var inCuts: String?
    public var note: String?
    public var status: String?        // open, ok, modify, ditched
    public var assets: String?        // ids of the linked assets, comma-separated (the manifest's scene column)
    public var after: String?         // move the scene after this ID; "start" puts it first (a move never changes an ID)

    public init(start: String? = nil, end: String? = nil, text: String? = nil, visual: String? = nil, feeling: String? = nil, handoff: String? = nil,
                inCuts: String? = nil, note: String? = nil, status: String? = nil, assets: String? = nil, after: String? = nil) {
        self.start = start; self.end = end; self.text = text; self.visual = visual; self.feeling = feeling; self.handoff = handoff
        self.inCuts = inCuts; self.note = note; self.status = status; self.assets = assets; self.after = after
    }
}

public enum SceneRules {
    public static let statuses = ["open", "ok", "modify", "ditched"]

    /// The next free ID: one past the highest number ever used, ditched scenes included. IDs are never reused or renumbered.
    public static func nextID(_ scenes: [ShowreelFile.Scene]) -> String {
        let n = scenes.compactMap { Int($0.id.dropFirst().prefix { $0.isNumber }) }.max() ?? 0
        return String(format: "S%02d", n + 1)
    }

    public static func isValidID(_ id: String) -> Bool { id.range(of: #"^S\d{2,}[a-z]?$"#, options: .regularExpression) != nil }

    static func time(_ s: String, _ what: String) throws -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        guard let d = Double(t.replacingOccurrences(of: ",", with: ".")), d >= 0 else { throw AgentError.msg("the \(what) time must be a number of seconds, 0 or more") }
        return d
    }

    public static func live(_ f: ShowreelFile) -> [ShowreelFile.Scene] { f.scenes.filter { $0.status != "ditched" } }

    /// Fields that change what the film shows or when: after the Go, changing one needs a fresh Go.
    static func changesTheFilm(_ e: SceneEdit) -> Bool {
        [e.start, e.end, e.text, e.visual, e.feeling, e.handoff, e.inCuts].contains { $0 != nil } || e.assets != nil
    }

    /// Applies an edit to a scene. Returns what changed, as card lines. Throws for what is not allowed.
    static func apply(_ e: SceneEdit, to s: inout ShowreelFile.Scene) throws -> [Change] {
        var ch: [Change] = []
        func shown(_ x: String) -> String { x.isEmpty ? "(empty)" : x }
        func set(_ label: String, _ new: String?, _ old: String, _ write: (String) -> Void) {
            guard let n = new?.trimmingCharacters(in: .whitespacesAndNewlines), n != old else { return }
            write(n); ch.append(Change(label, shown(old), shown(n)))
        }
        func secs(_ x: Double?) -> String { x.map { ProjectDocs.seconds($0) } ?? "" }
        if let v = e.start { let t = try time(v, "start"); if t != s.start { ch.append(Change("Start", shown(secs(s.start)), shown(secs(t)))); s.start = t } }
        if let v = e.end { let t = try time(v, "end"); if t != s.end { ch.append(Change("End", shown(secs(s.end)), shown(secs(t)))); s.end = t } }
        if let a = s.start, let b = s.end, b <= a { throw AgentError.msg("\(s.id) must end after it starts (\(secs(a)) to \(secs(b)))") }
        set("On-screen text", e.text, s.text) { s.text = $0 }
        set("Image and motion", e.visual, s.visual) { s.visual = $0 }
        set("Feeling and tension", e.feeling, s.feeling) { s.feeling = $0 }
        set("Handoff", e.handoff, s.handoff) { s.handoff = $0 }
        set("In cuts", e.inCuts, s.inCuts) { s.inCuts = $0 }
        set("Note", e.note, s.note) { s.note = $0 }
        if let st = e.status {
            guard statuses.contains(st) else { throw AgentError.msg("unknown status \"\(st)\": use open, ok, modify or ditched") }
            if st != s.status { ch.append(Change("Status", s.status, st)); s.status = st }
        } else if s.status == "ok", ch.contains(where: { ["Start", "End", "On-screen text", "Image and motion", "Feeling and tension", "Handoff", "In cuts"].contains($0.label) }) {
            // a reviewed scene that changes needs a new review
            ch.append(Change("Status", "ok", "open")); s.status = "open"
        }
        return ch
    }
}

extension ProjectStore {
    /// The scene-edit and add-scene plans, kept here so `plan` stays readable. Returns the card and a closure that performs it.
    func planScene(_ id: String, _ edit: SceneEdit, adding: Bool) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        var g = f
        var changes: [Change] = []
        var sceneID = id
        var assetRows = Assets.load(self)
        var newRows = assetRows
        if adding {
            sceneID = id.isEmpty ? SceneRules.nextID(f.scenes) : id
            guard SceneRules.isValidID(sceneID) else { throw AgentError.msg("\"\(sceneID)\" is not a scene ID (S01, S02...)") }
            guard !f.scenes.contains(where: { $0.id == sceneID }) else { throw AgentError.msg("\(sceneID) already exists: IDs are never reused") }
            var s = ShowreelFile.Scene(id: sceneID)
            var e = edit; e.after = nil
            changes = try SceneRules.apply(e, to: &s)
            var at = g.scenes.count
            if let a = edit.after, !a.isEmpty {
                if a == "start" { at = 0 } else if let i = g.scenes.firstIndex(where: { $0.id == a }) { at = i + 1 } else { throw AgentError.msg("no scene \(a) to insert after") }
            }
            g.scenes.insert(s, at: at)
            let where_ = at == 0 ? "first" : "after \(g.scenes[at - 1].id)"
            changes.insert(Change("Scene", "(none)", "\(sceneID), \(where_)"), at: 0)
        } else {
            guard let i = g.scenes.firstIndex(where: { $0.id == sceneID }) else { throw AgentError.msg("unknown scene \(sceneID)") }
            var s = g.scenes[i]
            changes = try SceneRules.apply(edit, to: &s)
            g.scenes[i] = s
            if let a = edit.after, !a.isEmpty {
                guard a == "start" || (a != sceneID && g.scenes.contains { $0.id == a }) else { throw AgentError.msg("no scene \(a) to move after") }
                let moved = g.scenes.remove(at: g.scenes.firstIndex { $0.id == sceneID }!)
                let to = a == "start" ? 0 : g.scenes.firstIndex { $0.id == a }! + 1
                let from = i
                g.scenes.insert(moved, at: to)
                if to != from { changes.append(Change("Position", "\(from + 1)", "\(to + 1)")) }
            }
        }
        if let wanted = edit.assets {
            let ids = Set(ParameterKey.list(wanted, lowercase: false))
            if let bad = ids.first(where: { x in !assetRows.contains { $0.id == x } }) { throw AgentError.msg("unknown asset \(bad)") }
            let before = assetRows.filter { $0.sceneIDs.contains(sceneID) }.map { $0.id }
            for k in newRows.indices {
                var list = newRows[k].sceneIDs
                if ids.contains(newRows[k].id) { if !list.contains(sceneID) { list.append(sceneID) } } else { list.removeAll { $0 == sceneID } }
                newRows[k].scene = list.joined(separator: ", ")
            }
            let after = newRows.filter { $0.sceneIDs.contains(sceneID) }.map { $0.id }
            if before != after { changes.append(Change("Linked assets", before.isEmpty ? "(none)" : before.joined(separator: ", "), after.isEmpty ? "(none)" : after.joined(separator: ", "))) }
            assetRows = newRows
        }
        guard !changes.isEmpty else { throw AgentError.msg("no change for \(sceneID)") }
        // after the Go, a change to what the film shows needs a fresh Go: it is never kept silently
        var reopen = false
        if f.gates["review"] == "passed", adding || SceneRules.changesTheFilm(edit) || (edit.status != nil && edit.status != "ok") {
            reopen = true
            changes.append(Change("Go", "given", "to be given again"))
        }
        let title = adding ? "Add scene \(sceneID)" : (edit.status == "ditched" ? "Ditch \(sceneID)" : "Edit \(sceneID)")
        let rows = assetRows, newGraph = g, linked = edit.assets != nil
        return (OperationCard(title: title, changes: changes), {
            var out = newGraph
            if reopen { out.gates["review"] = "open" }
            if linked { try Assets.save(rows, self) }
            try self.save(out)
        })
    }

    /// Why the Go cannot be given yet, or nil when it can.
    public func goBlocking() -> String? {
        guard let f = loadShowreel() else { return "there is no project data yet" }
        return goBlocker(f)
    }

    /// Why the Go cannot be given yet, or nil. The Go is only ever given by an explicit action of the user: nothing derives it.
    func goBlocker(_ f: ShowreelFile) -> String? {
        let live = SceneRules.live(f)
        if live.isEmpty { return "there is no scene yet" }
        if f.gates["storyboard"] != "passed" { return "the storyboard is not validated yet" }
        let notOK = live.filter { $0.status != "ok" }
        if !notOK.isEmpty { return "every scene must be OK or ditched first (\(notOK.map { $0.id }.joined(separator: ", ")) \(notOK.count == 1 ? "is" : "are") not)" }
        return nil
    }
}
