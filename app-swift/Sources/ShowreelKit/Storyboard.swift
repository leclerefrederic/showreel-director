import Foundation

/// A change to one scene of the library, field by field. Every field is optional: nil leaves it as it is, an empty string clears it.
/// Times are text ("4", "4.5") so that the copilot's tool input and the form share one path.
public struct SceneEdit: Equatable, Sendable {
    public var duration: String?
    public var text: String?
    public var visual: String?
    public var feeling: String?
    public var handoff: String?
    public var inCuts: String?
    public var note: String?
    public var status: String?        // open, ok, modify, ditched (ditched archives the scene and switches it off everywhere)
    public var archived: Bool?        // true archives (the "delete" of the library); false brings it back, still switched off
    public var assets: String?        // ids of the linked assets, comma-separated (the manifest's scene column)
    public var after: String?         // position in the master montage: after this ID, "start" for first (a move never changes an ID)

    public init(duration: String? = nil, text: String? = nil, visual: String? = nil, feeling: String? = nil, handoff: String? = nil,
                inCuts: String? = nil, note: String? = nil, status: String? = nil, archived: Bool? = nil, assets: String? = nil, after: String? = nil) {
        self.duration = duration; self.text = text; self.visual = visual; self.feeling = feeling; self.handoff = handoff
        self.inCuts = inCuts; self.note = note; self.status = status; self.archived = archived; self.assets = assets; self.after = after
    }
}

/// A scene placed in a montage with the times that follow from the order.
public struct TimedScene: Equatable {
    public let scene: ShowreelFile.Scene
    public let item: ShowreelFile.MontageItem
    public let start: Double?
    public let end: Double?
    public var length: Double? { zip2(start, end).map { $0.1 - $0.0 } }
    private func zip2(_ a: Double?, _ b: Double?) -> (Double, Double)? { a.flatMap { x in b.map { (x, $0) } } }
}

extension ShowreelFile {
    /// The scenes of one montage, in order, with their times. Switched-off and archived scenes are not in it.
    /// A scene starts where the one before ends, unless the item holds a manual start; it ends after its own duration, unless the item holds an end.
    public func timeline(_ montage: Int = 0) -> [TimedScene] {
        guard storyboards.indices.contains(montage) else { return [] }
        var out: [TimedScene] = []
        var t = 0.0
        for it in storyboards[montage].items where it.enabled {
            guard let s = scenes.first(where: { $0.id == it.scene }), !s.archived else { continue }
            let a = it.start ?? t
            let b = it.end ?? s.duration.map { a + $0 }
            out.append(TimedScene(scene: s, item: it, start: a, end: b))
            t = b ?? a
        }
        return out
    }

    /// The scenes of the master montage that are on, in order: what the film shows.
    public var film: [Scene] { timeline().map { $0.scene } }

    /// The `after` that puts `id` just before `target` in a montage (nil: last). nil when it would not move.
    public func position(of id: String, before target: String?, montage: Int = 0) -> String? {
        guard storyboards.indices.contains(montage) else { return nil }
        var ids = storyboards[montage].items.map { $0.scene }
        guard let from = ids.firstIndex(of: id) else { return nil }
        ids.remove(at: from)
        let to: Int
        if let t = target { guard let i = ids.firstIndex(of: t) else { return nil }; to = i } else { to = ids.count }
        guard to != from else { return nil }
        return to == 0 ? "start" : ids[to - 1]
    }

    /// The library in the order of the master montage (switched-off scenes included), then the scenes no montage places.
    public var orderedLibrary: [Scene] {
        let placed = (storyboards.first?.items ?? []).compactMap { it in scenes.first { $0.id == it.scene && !$0.archived } }
        let ids = Set(placed.map { $0.id })
        return placed + scenes.filter { !$0.archived && !ids.contains($0.id) }
    }

    /// The scenes that are not archived, in creation order: what the library lists.
    public var library: [Scene] { scenes.filter { !$0.archived } }

    /// The end of the last scene of the master, nil when a scene lacks a length.
    public var filmEnd: Double? {
        let tl = timeline()
        guard !tl.isEmpty, !tl.contains(where: { $0.end == nil }) else { return nil }
        return tl.last?.end
    }
}

public enum SceneRules {
    public static let statuses = ["open", "ok", "modify", "ditched"]

    /// The next free ID: one past the highest number ever used, archived scenes included. IDs are never reused or renumbered.
    public static func nextID(_ scenes: [ShowreelFile.Scene]) -> String {
        let n = scenes.compactMap { Int($0.id.dropFirst().prefix { $0.isNumber }) }.max() ?? 0
        return String(format: "S%02d", n + 1)
    }

    public static func isValidID(_ id: String) -> Bool { id.range(of: #"^S\d{2,}[a-z]?$"#, options: .regularExpression) != nil }

    static func time(_ s: String, _ what: String) throws -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        guard let d = Double(t.replacingOccurrences(of: ",", with: ".")), d > 0 else { throw AgentError.msg("the \(what) must be a number of seconds above 0") }
        return d
    }

    /// The scenes the film shows (on in the master montage).
    public static func live(_ f: ShowreelFile) -> [ShowreelFile.Scene] { f.film }

    /// Fields that change what the film shows or when: after the Go, changing one needs a fresh Go.
    static let filmFields = ["Duration", "On-screen text", "Image and motion", "Feeling and tension", "Handoff", "In cuts"]

    /// Applies an edit to a scene. Returns what changed, as card lines. Throws for what is not allowed.
    /// Archiving is done by the caller (it touches the montages too): here only the flags and the fields.
    static func apply(_ e: SceneEdit, to s: inout ShowreelFile.Scene) throws -> [Change] {
        var ch: [Change] = []
        func shown(_ x: String) -> String { x.isEmpty ? "(empty)" : x }
        func set(_ label: String, _ new: String?, _ old: String, _ write: (String) -> Void) {
            guard let n = new?.trimmingCharacters(in: .whitespacesAndNewlines), n != old else { return }
            write(n); ch.append(Change(label, shown(old), shown(n)))
        }
        func secs(_ x: Double?) -> String { x.map { ProjectDocs.seconds($0) } ?? "" }
        if let v = e.duration { let t = try time(v, "duration"); if t != s.duration { ch.append(Change("Duration", shown(secs(s.duration)), shown(secs(t)))); s.duration = t } }
        set("On-screen text", e.text, s.text) { s.text = $0 }
        set("Image and motion", e.visual, s.visual) { s.visual = $0 }
        set("Feeling and tension", e.feeling, s.feeling) { s.feeling = $0 }
        set("Handoff", e.handoff, s.handoff) { s.handoff = $0 }
        set("In cuts", e.inCuts, s.inCuts) { s.inCuts = $0 }
        set("Note", e.note, s.note) { s.note = $0 }
        if let st = e.status {
            guard statuses.contains(st) else { throw AgentError.msg("unknown status \"\(st)\": use open, ok, modify or ditched") }
            if st != s.status { ch.append(Change("Status", s.status, st)); s.status = st }
        } else if s.status == "ok", ch.contains(where: { filmFields.contains($0.label) }) {
            // a reviewed scene that changes needs a new review
            ch.append(Change("Status", "ok", "open")); s.status = "open"
        }
        return ch
    }

    /// What the film is, for deciding whether a change needs a fresh Go: scene, content and timing of every scene that is on.
    static func signature(_ f: ShowreelFile) -> [String] {
        f.timeline().map { t in
            let s = t.scene
            return [s.id, s.text, s.texts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "|"), s.visual, s.feeling, s.handoff, s.inCuts,
                    "\(t.start ?? -1)", "\(t.end ?? -1)", t.item.transition.type, "\(t.item.transition.duration ?? -1)"].joined(separator: "\u{1}")
        }
    }

    /// Puts `id` after `after` ("start" for first) in a montage, adding it when it is not there. Returns the old and new position.
    @discardableResult
    static func place(_ id: String, after: String?, in m: inout ShowreelFile.Montage, enabled: Bool? = nil) throws -> (from: Int?, to: Int) {
        let from = m.items.firstIndex { $0.scene == id }
        var item = from.map { m.items.remove(at: $0) } ?? ShowreelFile.MontageItem(scene: id)
        if let e = enabled { item.enabled = e }
        var at = m.items.count
        if let a = after, !a.isEmpty {
            if a == "start" { at = 0 }
            else if a != id, let i = m.items.firstIndex(where: { $0.scene == a }) { at = i + 1 }
            else { throw AgentError.msg("no scene \(a) in the montage to put \(id) after") }
        } else if let f = from { at = f }
        m.items.insert(item, at: at)
        return (from, at)
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
            var e = edit; e.after = nil; e.archived = nil
            changes = try SceneRules.apply(e, to: &s)
            if s.status == "ditched" { s.archived = true }
            g.scenes.append(s)
            if g.storyboards.isEmpty { g.storyboards = [ShowreelFile.Montage(format: g.decisions.formats?.first)] }
            let at = try SceneRules.place(sceneID, after: edit.after, in: &g.storyboards[0], enabled: !s.archived)
            let where_ = at.to == 0 ? "first" : "after \(g.storyboards[0].items[at.to - 1].scene)"
            changes.insert(Change("Scene", "(none)", "\(sceneID), \(where_)"), at: 0)
        } else {
            guard let i = g.scenes.firstIndex(where: { $0.id == sceneID }) else { throw AgentError.msg("unknown scene \(sceneID)") }
            var s = g.scenes[i]
            changes = try SceneRules.apply(edit, to: &s)
            let wasArchived = s.archived
            if s.status == "ditched" { s.archived = true }
            else if edit.status != nil, f.scenes[i].status == "ditched" { s.archived = false }
            if let a = edit.archived { s.archived = a }
            if s.archived != wasArchived {
                changes.append(Change(s.archived ? "Library" : "Archive", s.archived ? "in the library" : "archived", s.archived ? "archived (ID \(sceneID) stays reserved)" : "back in the library, switched off"))
            }
            g.scenes[i] = s
            if s.archived {
                for k in g.storyboards.indices { for j in g.storyboards[k].items.indices where g.storyboards[k].items[j].scene == sceneID && g.storyboards[k].items[j].enabled {
                    g.storyboards[k].items[j].enabled = false
                    changes.append(Change("Montage \(g.storyboards[k].name)", "\(sceneID) on", "\(sceneID) off"))
                } }
            }
            if let a = edit.after, !a.isEmpty, !g.storyboards.isEmpty {
                let r = try SceneRules.place(sceneID, after: a, in: &g.storyboards[0])
                if r.from != r.to { changes.append(Change("Position", r.from.map { "\($0 + 1)" } ?? "(not in the montage)", "\(r.to + 1)")) }
            }
        }
        var linkChanged = false
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
            if before != after {
                changes.append(Change("Linked assets", before.isEmpty ? "(none)" : before.joined(separator: ", "), after.isEmpty ? "(none)" : after.joined(separator: ", ")))
                linkChanged = true
            }
            assetRows = newRows
        }
        guard !changes.isEmpty else { throw AgentError.msg("no change for \(sceneID)") }
        let title = adding ? "Add scene \(sceneID)" : (edit.status == "ditched" ? "Ditch \(sceneID)" : edit.archived == true ? "Archive \(sceneID)" : "Edit \(sceneID)")
        let rows = assetRows, newGraph = g, linked = linkChanged
        let inFilm = g.film.contains { $0.id == sceneID } || f.film.contains { $0.id == sceneID }
        return finish(title: title, changes: changes, from: f, to: newGraph, extraFilmChange: linked && inFilm) { if linked { try Assets.save(rows, self) } }
    }

    /// The common end of the typed operations that change the scenes or a montage. After the Go, a change to what the film shows
    /// takes the Go back (a card line says so): it is never kept silently. `before` runs first (the manifest, for linked assets).
    func finish(title: String, changes: [Change], from f: ShowreelFile, to g: ShowreelFile, extraFilmChange: Bool = false,
                before: @escaping () throws -> Void = {}) -> (card: OperationCard, run: () throws -> Void) {
        var changes = changes
        var out = g
        var reopen = false
        if f.gates["review"] == "passed", extraFilmChange || SceneRules.signature(f) != SceneRules.signature(g) || g.film.contains(where: { $0.status != "ok" }) {
            reopen = true
            changes.append(Change("Go", "given", "to be given again"))
        }
        if reopen { out.gates["review"] = "open" }
        return (OperationCard(title: title, changes: changes), { try before(); try self.save(out) })
    }

    /// Switches a scene on or off in a montage (the master when `montage` is nil). Nothing is created or deleted.
    func planEnabled(_ id: String, enabled: Bool, montage: String?) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        var g = f
        guard let s = g.scenes.first(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
        guard let k = montage.flatMap({ m in g.storyboards.firstIndex { $0.id == m } }) ?? (montage == nil && !g.storyboards.isEmpty ? 0 : nil) else { throw AgentError.msg("unknown montage \(montage ?? "")") }
        if enabled, s.archived { throw AgentError.msg("\(id) is archived: bring it back in the library first") }
        let was = g.storyboards[k].items.first { $0.scene == id }?.enabled ?? false
        guard was != enabled else { throw AgentError.msg("no change: \(id) already is \(enabled ? "on" : "off") in \(g.storyboards[k].name)") }
        if let j = g.storyboards[k].items.firstIndex(where: { $0.scene == id }) { g.storyboards[k].items[j].enabled = enabled }
        else { g.storyboards[k].items.append(ShowreelFile.MontageItem(scene: id, enabled: enabled)) }
        let c = [Change("\(id) in \(g.storyboards[k].name)", was ? "on" : "off", enabled ? "on" : "off")]
        return finish(title: enabled ? "Switch \(id) on" : "Switch \(id) off", changes: c, from: f, to: g)
    }

    /// Moves a scene in a montage (the master when `montage` is nil). The ID never changes.
    func planMove(_ id: String, after: String, montage: String?) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        var g = f
        guard g.scenes.contains(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
        guard let k = montage.flatMap({ m in g.storyboards.firstIndex { $0.id == m } }) ?? (montage == nil && !g.storyboards.isEmpty ? 0 : nil) else { throw AgentError.msg("unknown montage \(montage ?? "")") }
        guard g.storyboards[k].items.contains(where: { $0.scene == id }) else { throw AgentError.msg("\(id) is not in \(g.storyboards[k].name): switch it on first") }
        let r = try SceneRules.place(id, after: after, in: &g.storyboards[k])
        guard r.from != r.to else { throw AgentError.msg("no change: \(id) already is there") }
        return finish(title: "Move \(id)", changes: [Change("Position of \(id)", "\((r.from ?? 0) + 1)", "\(r.to + 1)")], from: f, to: g)
    }

    /// Why the Go cannot be given yet, or nil when it can.
    public func goBlocking() -> String? {
        guard let f = loadShowreel() else { return "there is no project data yet" }
        return goBlocker(f)
    }

    /// Why the Go cannot be given yet, or nil. The Go is only ever given by an explicit action of the user: nothing derives it.
    func goBlocker(_ f: ShowreelFile) -> String? {
        let live = SceneRules.live(f)
        if live.isEmpty { return "there is no scene on in the storyboard yet" }
        if f.gates["storyboard"] != "passed" { return "the storyboard is not validated yet" }
        let notOK = live.filter { $0.status != "ok" }
        if !notOK.isEmpty { return "every scene must be OK first (\(notOK.map { $0.id }.joined(separator: ", ")) \(notOK.count == 1 ? "is" : "are") not)" }
        return nil
    }
}
