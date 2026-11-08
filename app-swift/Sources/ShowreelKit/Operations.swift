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
    case name, audience, message, tone, constraints, conversationLanguage, reelLanguages, formats, duration

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
        }
    }
}

/// A typed change to a project, made by the user in a block or proposed by the copilot.
public enum ProjectOperation: Equatable, Sendable {
    case parameter(ParameterKey, String)
    case asset(id: String, status: AssetStatus?, note: String?, licence: String?, scenes: String?)
    case gate(String, passed: Bool)
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
            if o.text != s.text { out.append(Change("Text of \(s.id)", shown(o.text), shown(s.text))) }
            if o.start != s.start || o.end != s.end || o.visual != s.visual || o.feeling != s.feeling || o.handoff != s.handoff {
                out.append(Change("Scene \(s.id) details", "before", "changed"))
            }
        }
        for id in ida.subtracting(idb) { out.append(Change("Scene \(id)", "present", "missing from the file")) }
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
        case .gate(let key, let passed):
            let f = try needShowreel()
            guard ShowreelFile.gateKeys.contains(key) else { throw AgentError.msg("unknown gate \(key)") }
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
        case .asset(let id, let status, let note, let licence, let scenes):
            try Assets.update(id, status: status, note: note, licence: licence, scenes: scenes, in: self)
        case .gate(let key, let passed):
            var f = try needShowreel()
            f.gates[key] = passed ? "passed" : "open"
            try save(f)
        }
    }
}
