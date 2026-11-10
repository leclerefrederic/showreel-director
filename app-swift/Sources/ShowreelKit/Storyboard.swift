import Foundation

/// A change to one scene of the library, field by field. Every field is optional: nil leaves it as it is, an empty string clears it.
/// Times are text ("4", "4.5") so that the copilot's tool input and the form share one path.
public struct SceneEdit: Equatable, Sendable {
    /// The label the user gives the scene (shown next to its ID). Empty clears it. The ID never changes.
    public var name: String?
    public var duration: String?
    public var text: String?
    public var visual: String?
    public var feeling: String?
    public var handoff: String?
    public var inCuts: String?
    public var note: String?
    public var status: String?        // wip, validated, ditched (the old open, ok, modify are read too; ditched archives the scene and switches it off everywhere)
    public var archived: Bool?        // true archives (the "delete" of the library); false brings it back, still switched off
    public var controlLevel: String?  // auto, guided, precise; empty: the project's
    public var assets: String?        // ids of the linked assets, comma-separated (the manifest's scene column)
    public var after: String?         // position in the master montage: after this ID, "start" for first (a move never changes an ID)

    public init(duration: String? = nil, text: String? = nil, visual: String? = nil, feeling: String? = nil, handoff: String? = nil,
                inCuts: String? = nil, note: String? = nil, status: String? = nil, archived: Bool? = nil, assets: String? = nil, after: String? = nil, controlLevel: String? = nil, name: String? = nil) {
        self.controlLevel = controlLevel; self.name = name
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

    /// The value a scene uses for a look decision: its own override, or the project's.
    public func effective(_ key: DecisionKey, for scene: Scene) -> String {
        var tmp = ShowreelFile(name: "")
        if let kept = scene.lockedLook { tmp.decisions = kept; return key.current(tmp) }          // a locked scene keeps the look it had when it was locked
        tmp.decisions = scene.overrides ?? Decisions()
        let own = key.current(tmp)
        return own.isEmpty ? key.current(self) : own
    }

    /// Whether the scene has its own value for it.
    public func isOverridden(_ key: DecisionKey, for scene: Scene) -> Bool {
        var tmp = ShowreelFile(name: "")
        tmp.decisions = scene.overrides ?? Decisions()
        return !key.current(tmp).isEmpty
    }

    func describe(_ key: DecisionKey, for scene: Scene) -> String {
        let v = effective(key, for: scene)
        return isOverridden(key, for: scene) ? "overridden: \(v)" : "inherited: \(v.isEmpty ? "(none)" : v)"
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
    public static let statuses = SceneState.allCases.map { $0.rawValue }

    /// The next free ID: one past the highest number ever used, archived scenes included. IDs are never reused or renumbered.
    public static func nextID(_ scenes: [ShowreelFile.Scene], retired: [String] = []) -> String {
        let n = (scenes.map { $0.id } + retired).compactMap { Int($0.dropFirst().prefix { $0.isNumber }) }.max() ?? 0
        return String(format: "S%02d", n + 1)
    }

    public static let nameLimit = 60

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
        if let raw = e.name {
            let n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.contains("\n"), n.count <= nameLimit else { throw AgentError.msg("a scene name is one line of at most \(nameLimit) characters") }
            guard !isValidID(n) else { throw AgentError.msg("a name cannot look like a scene ID (\(n)): the ID is what the film refers to") }
            if (n.isEmpty ? nil : n) != s.name { ch.append(Change("Name", shown(s.name ?? ""), n.isEmpty ? "(none)" : n)); s.name = n.isEmpty ? nil : n }
        }
        if let v = e.duration { let t = try time(v, "duration"); if t != s.duration { ch.append(Change("Duration", shown(secs(s.duration)), shown(secs(t)))); s.duration = t } }
        set("On-screen text", e.text, s.text) { s.setMasterText($0) }
        if let v = e.controlLevel?.trimmingCharacters(in: .whitespaces).lowercased() {
            guard v.isEmpty || ControlLevel(rawValue: v) != nil else { throw AgentError.msg("the control level is auto, guided or precise (empty: the project's)") }
            if (v.isEmpty ? nil : v) != s.controlLevel { ch.append(Change("Control level", s.controlLevel ?? "(project's)", v.isEmpty ? "(project's)" : v)); s.controlLevel = v.isEmpty ? nil : v }
        }
        set("Image and motion", e.visual, s.visual) { s.visual = $0 }
        set("Feeling and tension", e.feeling, s.feeling) { s.feeling = $0 }
        set("Handoff", e.handoff, s.handoff) { s.handoff = $0 }
        set("In cuts", e.inCuts, s.inCuts) { s.inCuts = $0 }
        set("Note", e.note, s.note) { s.note = $0 }
        if let raw = e.status {
            guard let st = SceneState.parse(raw) else { throw AgentError.msg("unknown state \"\(raw)\": use wip, validated or ditched") }
            guard st != .locked else { throw AgentError.msg("a scene is locked with the lock operation, once it is validated") }
            if st != s.state { ch.append(Change("State", s.state.title, st.title)); s.status = st.rawValue }
        } else if s.state == .validated, ch.contains(where: { filmFields.contains($0.label) }) {
            // a validated scene that changes needs a new review
            ch.append(Change("State", SceneState.validated.title, SceneState.wip.title)); s.status = SceneState.wip.rawValue
        }
        return ch
    }

    /// What the film is, for deciding whether a change needs a fresh Go: scene, content and timing of every scene that is on.
    static func signature(_ f: ShowreelFile) -> [String] {
        f.timeline().map { t in
            let s = t.scene
            return [s.id, s.text, "\(String(describing: s.overrides))", "\(s.content)", s.texts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "|"), s.visual, s.feeling, s.handoff, s.inCuts,
                    "\(t.start ?? -1)", "\(t.end ?? -1)", "\(t.item.transition)"].joined(separator: "\u{1}")
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
            sceneID = id.isEmpty ? SceneRules.nextID(f.scenes, retired: f.retiredIDs ?? []) : id
            guard SceneRules.isValidID(sceneID) else { throw AgentError.msg("\"\(sceneID)\" is not a scene ID (S01, S02...)") }
            guard !f.scenes.contains(where: { $0.id == sceneID }), !(f.retiredIDs ?? []).contains(sceneID) else { throw AgentError.msg("\(sceneID) already exists or was deleted: IDs are never reused") }
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
        let label = g.scenes.first { $0.id == sceneID }?.label ?? sceneID
        let renamedOnly = !adding && edit.name != nil && changes.allSatisfy { $0.label == "Name" }
        let title = adding ? "Add scene \(label)" : (edit.status == "ditched" ? "Ditch \(label)" : edit.archived == true ? "Archive \(label)" : renamedOnly ? "Rename \(sceneID)" : "Edit \(label)")
        let rows = assetRows, newGraph = g, linked = linkChanged
        let inFilm = g.film.contains { $0.id == sceneID } || f.film.contains { $0.id == sceneID }
        return try finish(title: title, changes: changes, from: f, to: newGraph, extraFilmChange: linked && inFilm) { if linked { try Assets.save(rows, self) } }
    }

    /// The common end of the typed operations that change the scenes or a montage. After the Go, a change to what the film shows
    /// takes the Go back (a card line says so): it is never kept silently. `before` runs first (the manifest, for linked assets).
    func finish(title: String, changes: [Change], from f: ShowreelFile, to g: ShowreelFile, extraFilmChange: Bool = false,
                before: @escaping () throws -> Void = {}) throws -> (card: OperationCard, run: () throws -> Void) {
        if let why = lockShiftRefusal(from: f, to: g) { throw AgentError.msg(why) }
        var changes = changes
        var out = g
        var reopen = false
        if f.gates["review"] == "passed", extraFilmChange || SceneRules.signature(f) != SceneRules.signature(g) || g.film.contains(where: { !$0.state.isReviewed }) {
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
        var lines: [Change] = []
        if enabled, s.archived {          // an archived or ditched scene is a hidden scene: showing it brings it back
            if let i = g.scenes.firstIndex(where: { $0.id == id }) {
                g.scenes[i].archived = false
                if g.scenes[i].state == .ditched { g.scenes[i].status = SceneState.wip.rawValue }
            }
            lines.append(Change("\(id) was", "archived or ditched", "hidden, now shown"))
        }
        let was = g.storyboards[k].items.first { $0.scene == id }?.enabled ?? false
        guard was != enabled else { throw AgentError.msg("no change: \(id) already is \(enabled ? "on" : "off") in \(g.storyboards[k].name)") }
        if let j = g.storyboards[k].items.firstIndex(where: { $0.scene == id }) { g.storyboards[k].items[j].enabled = enabled }
        else { g.storyboards[k].items.append(ShowreelFile.MontageItem(scene: id, enabled: enabled)) }
        let c = lines + [Change("\(id) in \(g.storyboards[k].name)", was ? "on" : "off", enabled ? "on" : "off")]
        return try finish(title: enabled ? "Switch \(id) on" : "Switch \(id) off", changes: c, from: f, to: g)
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
        return try finish(title: "Move \(id)", changes: [Change("Position of \(id)", "\((r.from ?? 0) + 1)", "\(r.to + 1)")], from: f, to: g)
    }

    /// Sets or removes the scene's own background and look. An empty value takes the override away: the scene follows the project again.
    func planSceneLook(_ id: String, _ changes: [DecisionChange]) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        guard let i = f.scenes.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
        guard !changes.isEmpty else { throw AgentError.msg("nothing to change") }
        var g = f
        var tmp = ShowreelFile(name: "")
        tmp.decisions = g.scenes[i].overrides ?? ShowreelFile.Decisions()
        var lines: [Change] = []
        for c in changes {
            guard DecisionKey.sceneKeys.contains(c.key) else { throw AgentError.msg("a scene can override the palette, the fonts and the background, not \(c.key.title.lowercased())") }
            let before = g.describe(c.key, for: g.scenes[i])
            try c.key.set(c.value, in: &tmp)
            g.scenes[i].overrides = tmp.decisions == ShowreelFile.Decisions() ? nil : tmp.decisions
            let after = g.describe(c.key, for: g.scenes[i])
            if before != after { lines.append(Change("\(id) \(c.key.title.lowercased())", before, after)) }
        }
        guard !lines.isEmpty else { throw AgentError.msg("no change for \(id)") }
        let reverts = changes.allSatisfy { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        return try finish(title: reverts ? "Revert \(id) to the project look" : "Override the look of \(id)", changes: lines, from: f, to: g)
    }

    /// Why the Build cannot start yet, or nil when it can: the implicit Go is that every visible scene is Ready.
    public func goBlocking() -> String? {
        guard let f = loadShowreel() else { return "there is no project data yet" }
        return goBlocker(f)
    }

    /// Why the Build cannot start yet, or nil. The Go is implicit (SM1): every visible scene is Ready (a locked scene is, a hidden one is not counted). Starting the Build records it in the file.
    func goBlocker(_ f: ShowreelFile) -> String? {
        let live = SceneRules.live(f)
        if live.isEmpty { return "there is no scene on in the storyboard yet" }
        let notOK = live.filter { !$0.state.isReviewed }
        if !notOK.isEmpty { return "\(notOK.count) scene\(notOK.count == 1 ? " is" : "s are") not Ready (\(notOK.map { $0.id }.joined(separator: ", ")))" }
        return nil
    }
}

// MARK: the lock freezes a scene in time and space

/// Where a scene is: when it plays if it is visible, what comes before it in the montage if it is hidden.
struct ScenePlace: Equatable {
    var visible: Bool
    var start: Double?
    var end: Double?
    var after: String?
}

extension ShowreelFile {
    func place(of id: String) -> ScenePlace? {
        guard scenes.contains(where: { $0.id == id }), let m = storyboards.first, let i = m.items.firstIndex(where: { $0.scene == id }) else { return nil }
        let on = m.items[i].enabled && !(scenes.first { $0.id == id }?.archived ?? false)
        if on, let t = timeline().first(where: { $0.scene.id == id }) { return ScenePlace(visible: true, start: t.start.map { ($0 * 1e6).rounded() / 1e6 }, end: t.end.map { ($0 * 1e6).rounded() / 1e6 }, after: nil) }
        return ScenePlace(visible: false, start: nil, end: nil, after: i > 0 ? m.items[i - 1].scene : nil)
    }
}

extension ProjectStore {
    /// "0:24": where a locked scene starts, for the reasons that name it.
    static func clock(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

    /// A locked scene is frozen in time and space, visible or hidden: a change elsewhere that would move its start (a scene inserted, deleted, shown, hidden, lengthened or
    /// shortened before it) is refused, and so is any move of its place. Nil when no locked scene moves.
    func lockShiftRefusal(from f: ShowreelFile, to g: ShowreelFile) -> String? {
        for s in f.scenes where s.isLocked {
            let a = f.place(of: s.id), b = g.place(of: s.id)
            guard a != b else { continue }
            if let a = a, a.visible, let t = a.start { return "\(s.id) is locked at \(Self.clock(t)): unlock it, or change a scene after it" }
            return "\(s.id) is locked" + (a?.after.map { " (hidden, after \($0))" } ?? " (hidden, first)") + ": unlock it, or change a scene after it"
        }
        return nil
    }

    /// What deleting a scene loses, one line each: its words, elements, own look, linked resources and the transition that leaves it.
    public func deletionLosses(_ id: String) -> [String] {
        guard let f = loadShowreel(), let s = f.scenes.first(where: { $0.id == id }) else { return [] }
        var out: [String] = []
        if !s.text.isEmpty { out.append("its words \u{201C}\(s.text.count > 60 ? String(s.text.prefix(60)) + "\u{2026}" : s.text)\u{201D}") }
        if !s.content.isEmpty { out.append("its \(s.content.count) element\(s.content.count == 1 ? "" : "s")") }
        if s.overrides != nil { out.append("its own look") }
        let linked = Assets.load(self).filter { $0.sceneIDs.contains(id) }
        if !linked.isEmpty { out.append("its link to \(linked.map { $0.name }.joined(separator: ", ")) (the files stay in the resources)") }
        if let m = f.storyboards.first?.items.first(where: { $0.scene == id }), !m.transition.isCut { out.append("the transition that leaves it (\(m.transition.type))") }
        if !s.note.isEmpty { out.append("its instruction") }
        return out
    }

    func planDelete(_ id: String) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        guard let s = f.scenes.first(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
        var g = f
        g.scenes.removeAll { $0.id == id }
        for k in g.storyboards.indices { g.storyboards[k].items.removeAll { $0.scene == id } }
        g.retiredIDs = Array(Set((g.retiredIDs ?? []) + [id])).sorted()
        var rows = Assets.load(self)
        var relinked = false
        for k in rows.indices where rows[k].sceneIDs.contains(id) { rows[k].scene = rows[k].sceneIDs.filter { $0 != id }.joined(separator: ", "); relinked = true }
        let lost = deletionLosses(id)
        var changes = [Change("Scene \(s.label)", "in the project", "deleted (\(id) is never given again)")]
        if !lost.isEmpty { changes.append(Change("Lost", lost.joined(separator: "; "), "gone, Undo brings them back")) }
        let save = rows
        return try finish(title: "Delete scene \(s.label)", changes: changes, from: f, to: g, extraFilmChange: f.film.contains { $0.id == id }) { if relinked { try Assets.save(save, self) } }
    }
}
