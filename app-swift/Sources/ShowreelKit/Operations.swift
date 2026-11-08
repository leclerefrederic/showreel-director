import Foundation

/// One line of a change card: what changes, from what, to what.
public struct Change: Equatable, Sendable {
    public let label: String
    public let before: String
    public let after: String
    public init(_ label: String, _ before: String, _ after: String) { self.label = label; self.before = before; self.after = after }
}

/// A change shown to the user as a plain card ("Set audience", before and after), not as a file diff.
public struct OperationCard: Equatable, Sendable {
    public let title: String
    public let changes: [Change]
    public init(title: String, changes: [Change]) { self.title = title; self.changes = changes }
}

/// The fields of the Project block, by the name the copilot uses.
public enum ParameterKey: String, CaseIterable, Sendable {
    case name, audience, message, tone, constraints, conversationLanguage, reelLanguages, formats, duration, controlLevel

    public var title: String {
        switch self {
        case .name: return "Project name"
        case .audience: return "Audience"
        case .message: return "Message"
        case .tone: return "Tone"
        case .constraints: return "Constraints"
        case .conversationLanguage: return "Conversation language"
        case .reelLanguages: return "Reel languages"
        case .formats: return "Formats"
        case .duration: return "Duration"
        case .controlLevel: return "Control level"
        }
    }

    /// The interview's question behind the field, shown as its help text (references/interview.md, rounds 0, 1 and 4).
    public var help: String {
        switch self {
        case .name: return "The project's name, shown in the library."
        case .audience: return "Who watches, and in what setting: a big screen with sound, a laptop in silence, a phone feed? What do they already know?"
        case .message: return "The one sentence the viewer should remember, and what they should do or feel next (smile, curiosity, \"I want a demo\")."
        case .tone: return "The voice and persona of the film: how should it feel and sound (warm, sober, playful, premium...)?"
        case .constraints: return "Anything that must or must not appear: claims allowed, names to avoid, confidentiality, legal lines, deadline."
        case .conversationLanguage: return "The language used with you during the project (questions, notes, reports). Independent of the reel."
        case .reelLanguages: return "English by default. Add languages the viewer can switch to; the first is the master text. Fonts must cover every language's glyphs."
        case .formats: return "Desktop 16:9 only, or also mobile 9:16? Decide now: 9:16 changes the layout design."
        case .duration: return "How long, in seconds. No default and no cap: you decide. A feasibility check follows the answer."
        case .controlLevel: return "How much you want to decide in each scene: auto (only the words), guided (you fix what matters) or precise (everything). It sets the defaults of new content items; a scene and any attribute can differ."
        }
    }

    public func current(_ f: ShowreelFile) -> String {
        switch self {
        case .name: return f.name
        case .audience: return f.parameters.audience ?? ""
        case .message: return f.parameters.message ?? ""
        case .tone: return f.parameters.tone ?? ""
        case .constraints: return f.parameters.constraints ?? ""
        case .conversationLanguage: return f.conversationLanguage ?? ""
        case .reelLanguages: return f.reelLanguages.joined(separator: ", ")
        case .formats: return (f.decisions.formats ?? []).joined(separator: ", ")
        case .duration: return f.decisions.duration.map { ProjectDocs.seconds($0) + " s" } ?? ""
        case .controlLevel: return f.parameters.controlLevel ?? ""
        }
    }

    public static func list(_ s: String, lowercase: Bool) -> [String] {
        var out: [String] = []
        for p in s.split(whereSeparator: { ",;\n".contains($0) }) {
            let v = p.trimmingCharacters(in: .whitespaces)
            let w = lowercase ? v.lowercased() : v
            if !w.isEmpty, !out.contains(w) { out.append(w) }
        }
        return out
    }

    public func set(_ value: String, in f: inout ShowreelFile) throws {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .name:
            guard !v.isEmpty else { throw AgentError.msg("the project name cannot be empty") }
            f.name = v
        case .audience: f.parameters.audience = v.isEmpty ? nil : v
        case .message: f.parameters.message = v.isEmpty ? nil : v
        case .tone: f.parameters.tone = v.isEmpty ? nil : v
        case .constraints: f.parameters.constraints = v.isEmpty ? nil : v
        case .conversationLanguage: f.conversationLanguage = v.isEmpty ? nil : v.lowercased()
        case .reelLanguages: f.reelLanguages = Self.list(v, lowercase: true)
        case .formats: let l = Self.list(v, lowercase: false); f.decisions.formats = l.isEmpty ? nil : l
        case .duration:
            if v.isEmpty { f.decisions.duration = nil; return }
            let n = v.lowercased().replacingOccurrences(of: "seconds", with: "").replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespaces)
            guard let d = Double(n.replacingOccurrences(of: ",", with: ".")), d > 0 else { throw AgentError.msg("the duration must be a positive number of seconds") }
            f.decisions.duration = d
        case .controlLevel:
            guard v.isEmpty || ControlLevel(rawValue: v.lowercased()) != nil else { throw AgentError.msg("the control level is auto, guided or precise") }
            f.parameters.controlLevel = v.isEmpty ? nil : v.lowercased()
        }
    }
}

/// The decisions of the Look block, by the name the copilot uses (update_decision).
public enum DecisionKey: String, CaseIterable, Sendable {
    case palette, titleFont, textFont, background, backgroundMood, moods, effectsPack

    /// What a scene may override: the palette, the fonts and the background (not the moods or the effects pack).
    public static let sceneKeys: [DecisionKey] = [.palette, .titleFont, .textFont, .background, .backgroundMood]

    public var title: String {
        switch self {
        case .palette: return "Palette"
        case .titleFont: return "Title font"
        case .textFont: return "Text font"
        case .background: return "Background"
        case .backgroundMood: return "Background mood"
        case .moods: return "Moods"
        case .effectsPack: return "Effects pack"
        }
    }

    public func current(_ f: ShowreelFile) -> String {
        let d = f.decisions
        switch self {
        case .palette: return (d.palette ?? []).joined(separator: ", ")
        case .titleFont: return d.fonts?.titles ?? ""
        case .textFont: return d.fonts?.text ?? ""
        case .background: return d.background?.id ?? ""
        case .backgroundMood: return d.background?.mood ?? ""
        case .moods: return (d.moods ?? []).joined(separator: ", ")
        case .effectsPack: return d.effectsPack ?? ""
        }
    }

    /// Sets the value, refusing what the skill's engine does not know (an unknown background, mood or pack).
    public func set(_ value: String, in f: inout ShowreelFile) throws {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        func one(_ allowed: [String], _ what: String) throws {
            if !v.isEmpty, !allowed.contains(v) { throw AgentError.msg("unknown \(what) \"\(v)\": use one of " + allowed.joined(separator: ", ")) }
        }
        switch self {
        case .palette:
            let l = ParameterKey.list(v, lowercase: false).map { $0.uppercased() }
            if let bad = l.first(where: { !EnginePalette.isHex($0) }) { throw AgentError.msg("\"\(bad)\" is not a #RRGGBB colour") }
            if l.count > 6 { throw AgentError.msg("a palette has at most 6 colours (background, text, accent, accent 2, then extras)") }
            f.decisions.palette = l.isEmpty ? nil : l
        case .titleFont, .textFont:
            var fonts = f.decisions.fonts ?? ShowreelFile.Fonts()
            if self == .titleFont { fonts.titles = v.isEmpty ? nil : v } else { fonts.text = v.isEmpty ? nil : v }
            f.decisions.fonts = (fonts.titles == nil && fonts.text == nil && fonts.unknown.isEmpty) ? nil : fonts
        case .background:
            try one(Look.backgroundIDs(), "background")
            var b = f.decisions.background ?? ShowreelFile.Background()
            b.id = v.isEmpty ? nil : v
            f.decisions.background = (b.id == nil && b.mood == nil && b.unknown.isEmpty) ? nil : b
        case .backgroundMood:
            try one(Look.backgroundMoods(), "background mood")
            var b = f.decisions.background ?? ShowreelFile.Background()
            b.mood = v.isEmpty ? nil : v
            f.decisions.background = (b.id == nil && b.mood == nil && b.unknown.isEmpty) ? nil : b
        case .moods:
            let names = Look.packs().map { $0.name }
            let l = ParameterKey.list(v, lowercase: false)
            if let bad = l.first(where: { !names.contains($0) }) { throw AgentError.msg("unknown mood \"\(bad)\": use " + names.joined(separator: ", ")) }
            if l.count > 2 { throw AgentError.msg("choose one or two moods") }
            f.decisions.moods = l.isEmpty ? nil : l
        case .effectsPack:
            try one(Look.packs().map { $0.name }, "effects pack")
            f.decisions.effectsPack = v.isEmpty ? nil : v
        }
    }
}

public struct DecisionChange: Equatable, Sendable {
    public let key: DecisionKey
    public let value: String
    public init(_ key: DecisionKey, _ value: String) { self.key = key; self.value = value }
}

/// A typed change to a project, made by the user in a block or proposed by the copilot.
public enum ProjectOperation: Equatable, Sendable {
    case parameter(ParameterKey, String)
    /// One or more decisions of the Look block as one card (a design package changes several at once).
    case decisions([DecisionChange], title: String?)
    case asset(id: String, status: AssetStatus?, note: String?, licence: String?, scenes: String?)
    case gate(String, passed: Bool)
    /// A change to one scene (fields, status with note, linked assets, position).
    case scene(id: String, SceneEdit)
    /// A new scene. `id` empty means the next free one.
    case addScene(id: String, SceneEdit)
    /// Switches a scene on or off in a montage (the master when `montage` is nil).
    case sceneEnabled(id: String, enabled: Bool, montage: String?)
    /// Puts a scene after another one in a montage ("start" for first).
    case moveScene(id: String, after: String, montage: String?)
    /// A scene's own palette, fonts or background. An empty value takes the override away (back to the project's).
    case sceneLook(id: String, [DecisionChange])
    /// Add, change, remove or reorder one content item of a scene.
    case content(scene: String, ContentOp)
}

public enum Operations {
    static func shown(_ s: String) -> String { s.isEmpty ? "(empty)" : s }

    /// The changes between two versions of the file, as card lines (for a re-import).
    public static func diff(_ a: ShowreelFile, _ b: ShowreelFile) -> [Change] {
        var out: [Change] = []
        for k in ParameterKey.allCases where k.current(a) != k.current(b) { out.append(Change(k.title, shown(k.current(a)), shown(k.current(b)))) }
        let pa = (a.decisions.palette ?? []).joined(separator: ", "), pb = (b.decisions.palette ?? []).joined(separator: ", ")
        if pa != pb { out.append(Change("Palette", shown(pa), shown(pb))) }
        let fa = [a.decisions.fonts?.titles, a.decisions.fonts?.text].compactMap { $0 }.joined(separator: " / ")
        let fb = [b.decisions.fonts?.titles, b.decisions.fonts?.text].compactMap { $0 }.joined(separator: " / ")
        if fa != fb { out.append(Change("Fonts", shown(fa), shown(fb))) }
        let ida = Set(a.scenes.map { $0.id }), idb = Set(b.scenes.map { $0.id })
        for s in b.scenes where !ida.contains(s.id) { out.append(Change("Scene \(s.id)", "(none)", s.text.isEmpty ? "added" : s.text)) }
        for s in b.scenes {
            guard let o = a.scenes.first(where: { $0.id == s.id }), o != s else { continue }
            if o.status != s.status { out.append(Change("Scene \(s.id) status", o.status, s.status)) }
            if o.archived != s.archived { out.append(Change("Scene \(s.id) archive", o.archived ? "archived" : "in the library", s.archived ? "archived" : "in the library")) }
            if o.text != s.text { out.append(Change("Text of \(s.id)", shown(o.text), shown(s.text))) }
            if o.duration != s.duration || o.visual != s.visual || o.feeling != s.feeling || o.handoff != s.handoff {
                out.append(Change("Scene \(s.id) details", "before", "changed"))
            }
        }
        for id in ida.subtracting(idb) { out.append(Change("Scene \(id)", "present", "missing from the file")) }
        let oa = a.timeline().map { $0.scene.id }, ob = b.timeline().map { $0.scene.id }
        if oa != ob { out.append(Change("Storyboard order", oa.isEmpty ? "(empty)" : oa.joined(separator: ", "), ob.isEmpty ? "(empty)" : ob.joined(separator: ", "))) }
        return out
    }
}

extension ProjectStore {
    private func needShowreel() throws -> ShowreelFile {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        return f
    }

    /// What the operation would change, without changing anything. Throws when it is not allowed.
    public func plan(_ op: ProjectOperation) throws -> OperationCard {
        switch op {
        case .parameter(let key, let value):
            let f = try needShowreel()
            var g = f
            try key.set(value, in: &g)
            let before = key.current(f), after = key.current(g)
            guard before != after else { throw AgentError.msg("no change: \(key.title) already is \(Operations.shown(before))") }
            return OperationCard(title: "Set \(key.title.lowercased())", changes: [Change(key.title, Operations.shown(before), Operations.shown(after))])
        case .decisions(let list, let title):
            let f = try needShowreel()
            var g = f
            var ch: [Change] = []
            for d in list {
                let before = d.key.current(g)
                try d.key.set(d.value, in: &g)
                let after = d.key.current(g)
                if before != after { ch.append(Change(d.key.title, Operations.shown(before), Operations.shown(after))) }
            }
            guard !ch.isEmpty else { throw AgentError.msg("no change: the look already is that") }
            return OperationCard(title: title ?? (ch.count == 1 ? "Set " + ch[0].label.lowercased() : "Change the look"), changes: ch)
        case .asset(let id, let status, let note, let licence, let scenes):
            let rows = Assets.load(self)
            guard let r = rows.first(where: { $0.id == id }) else { throw AgentError.msg("unknown asset \(id)") }
            if let why = Assets.refusal(for: r, status: status, note: note) { throw AgentError.msg(why) }
            var ch: [Change] = []
            if let s = status, s.rawValue != r.status { ch.append(Change("Status", r.status, s.rawValue)) }
            if let n = note, n != r.notes { ch.append(Change("Note", Operations.shown(r.notes), Operations.shown(n))) }
            if let l = licence, l != r.licenceNote { ch.append(Change("Licence note", Operations.shown(r.licenceNote), Operations.shown(l))) }
            if let s = scenes, s != r.scene { ch.append(Change("Scenes", Operations.shown(r.scene), Operations.shown(s))) }
            guard !ch.isEmpty else { throw AgentError.msg("no change for \(id)") }
            let verb = status.map { $0 == .approved ? "Approve" : $0 == .excluded ? "Exclude" : $0 == .hold ? "Hold" : "Mark \($0.rawValue)" } ?? "Update"
            return OperationCard(title: "\(verb) \(r.name)", changes: ch)
        case .scene(let id, let edit): return try planScene(id, edit, adding: false).card
        case .addScene(let id, let edit): return try planScene(id, edit, adding: true).card
        case .sceneEnabled(let id, let on, let m): return try planEnabled(id, enabled: on, montage: m).card
        case .moveScene(let id, let after, let m): return try planMove(id, after: after, montage: m).card
        case .sceneLook(let id, let ch): return try planSceneLook(id, ch).card
        case .content(let id, let op): return try planContent(id, op).card
        case .gate(let key, let passed):
            let f = try needShowreel()
            guard ShowreelFile.gateKeys.contains(key) else { throw AgentError.msg("unknown gate \(key)") }
            if passed, key == "storyboard", SceneRules.live(f).isEmpty { throw AgentError.msg("the storyboard has no scene yet") }
            if passed, key == "review", let why = goBlocker(f) { throw AgentError.msg("the Go cannot be given: \(why)") }
            let before = f.gates[key] ?? "open", after = passed ? "passed" : "open"
            guard before != after else { throw AgentError.msg("no change: gate \(key) already is \(before)") }
            return OperationCard(title: passed ? "Validate \(key)" : "Reopen \(key)", changes: [Change("Gate \(key)", before, after)])
        }
    }

    /// Performs an operation. With `expecting`, it first checks that the project still is what the card was made from.
    public func apply(_ op: ProjectOperation, expecting card: OperationCard? = nil) throws {
        let now = try plan(op)
        if let c = card, c.changes != now.changes { throw AgentError.msg("not applied: the project changed since the proposal was made. Read the state again and propose again.") }
        switch op {
        case .parameter(let key, let value):
            var f = try needShowreel()
            try key.set(value, in: &f)
            try save(f)
        case .decisions(let list, _):
            var f = try needShowreel()
            for d in list { try d.key.set(d.value, in: &f) }
            try save(f)
        case .asset(let id, let status, let note, let licence, let scenes):
            try Assets.update(id, status: status, note: note, licence: licence, scenes: scenes, in: self)
        case .scene(let id, let edit): try planScene(id, edit, adding: false).run()
        case .addScene(let id, let edit): try planScene(id, edit, adding: true).run()
        case .sceneEnabled(let id, let on, let m): try planEnabled(id, enabled: on, montage: m).run()
        case .moveScene(let id, let after, let m): try planMove(id, after: after, montage: m).run()
        case .sceneLook(let id, let ch): try planSceneLook(id, ch).run()
        case .content(let id, let op): try planContent(id, op).run()
        case .gate(let key, let passed):
            var f = try needShowreel()
            f.gates[key] = passed ? "passed" : "open"
            try save(f)
        }
    }
}
