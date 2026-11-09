import Foundation

/// The review state of a scene. WIP is the default (it includes "to modify": WIP with a note), Validated is "OK", Locked is Validated that nothing may
/// change. Ditched archives the scene. A file from before revision 2 says open, ok or modify: they are read as WIP, Validated and WIP (the note stays).
public enum SceneState: String, CaseIterable, Sendable {
    case wip, validated, locked, ditched

    public var title: String {
        switch self { case .wip: return "WIP"; case .validated: return "Validated"; case .locked: return "Locked"; case .ditched: return "Ditched" }
    }

    /// What a state means, for the tooltip of its badge.
    public var meaning: String {
        switch self {
        case .wip: return "Work in progress: not reviewed yet, or sent back with a note"
        case .validated: return "Validated: reviewed and OK. It is not locked: a change sends it back to WIP"
        case .locked: return "Locked: nothing in it can change (content, duration, look). Its place in the montage can still move"
        case .ditched: return "Ditched: archived, its ID stays reserved"
        }
    }

    /// Validated or Locked: the scene counts as reviewed for the Go.
    public var isReviewed: Bool { self == .validated || self == .locked }

    /// The state a word stands for, including the words of revision 1 (open, ok, modify) and of the skill's export.
    public static func parse(_ raw: String) -> SceneState? {
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "", "open", "modify", "wip": return .wip
        case "ok", "validated": return .validated
        case "locked": return .locked
        case "ditched", "ditch": return .ditched
        default: return nil
        }
    }

    /// The word kept in the file: the current one when the word is known, the word itself when it is not (nothing is lost).
    public static func canonical(_ raw: String) -> String { parse(raw)?.rawValue ?? raw }
}

/// The lock of a scene: what it refuses, with a reason, and the one operation that unlocks it. The rules are here; the views only relay the reason.
public enum SceneLock {
    public static func reason(_ id: String) -> String {
        "\(id) is locked: unlock it first (its place in the montage can still move)"
    }
}

extension ProjectStore {
    /// The scenes an operation would change. A locked one refuses it. Moving a scene in a montage, switching it on or off, a transition leaving it and the
    /// lock itself never change what is inside the scene: they are allowed.
    func scenesChanged(by op: ProjectOperation, in f: ShowreelFile) -> [String] {
        switch op {
        case .scene(let id, var e):
            e.after = nil                                  // a position only is a montage matter
            return e == SceneEdit() ? [] : [id]
        case .sceneLook(let id, _): return [id]
        case .content(let id, _): return [id]
        case .resize(let id, _, _): return [id]             // the scene's own edge; a ripple moves the others' starts, never their lengths
        case .moveCut(let a, let b, _): return [a, b]
        case .asset(let id, _, _, _, let scenes):
            guard let wanted = scenes else { return [] }
            let before = Set(Assets.load(self).first { $0.id == id }?.sceneIDs ?? [])
            return before.symmetricDifference(Set(ParameterKey.list(wanted, lowercase: false))).sorted()
        default: return []
        }
    }

    /// Why an operation is refused because it touches a locked scene; nil when it does not.
    func lockRefusal(_ op: ProjectOperation) -> String? {
        guard let f = loadShowreel() else { return nil }
        for id in scenesChanged(by: op, in: f) where f.scenes.first(where: { $0.id == id })?.isLocked == true { return SceneLock.reason(id) }
        return nil
    }

    /// Lock or unlock scenes as one card. Only a Validated scene can be locked (a lock never validates by itself); unlocking gives back Validated.
    func planLock(_ ids: [String], locked: Bool) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        guard !ids.isEmpty else { throw AgentError.msg("no scene to \(locked ? "lock" : "unlock")") }
        var g = f
        var lines: [Change] = []
        for id in ids {
            guard let i = g.scenes.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
            let s = g.scenes[i]
            guard !s.archived else { throw AgentError.msg("\(id) is archived: bring it back first") }
            if locked {
                if s.state == .locked { continue }
                guard s.state == .validated else { throw AgentError.msg("\(id) is \(s.state.title): validate it before locking it (a lock never validates a scene)") }
                g.scenes[i].status = SceneState.locked.rawValue
            } else {
                if s.state != .locked { continue }
                g.scenes[i].status = SceneState.validated.rawValue
            }
            lines.append(Change("\(id) state", s.state.title, g.scenes[i].state.title))
        }
        guard !lines.isEmpty else { throw AgentError.msg("no change: " + (ids.count == 1 ? "\(ids[0]) already is \(locked ? "locked" : "not locked")" : "the scenes already are \(locked ? "locked" : "not locked")")) }
        let title = (locked ? "Lock " : "Unlock ") + (lines.count == 1 ? ids.first { id in lines[0].label.hasPrefix(id + " ") } ?? ids[0] : "\(lines.count) scenes")
        return finish(title: title, changes: lines, from: f, to: g)
    }
}

/// One line of the menu a scene's badge opens: a state, whether it can be chosen now, why not, and the operation that does it.
public struct StateChoice: Equatable, Sendable {
    public let state: SceneState
    /// What the menu says: the state, or "Unlock" for the way out of Locked.
    public let title: String
    public let isCurrent: Bool
    public let reason: String?
    public let operation: ProjectOperation?
    public var enabled: Bool { operation != nil }
}

/// The state-change menu and the batch lock. The views draw the choices and run `operation`; nothing else decides what a state change is.
public enum SceneStates {
    /// WIP, Validated and Locked, each with the operation that reaches it from the scene's state (Ditch stays in the Review block: it archives).
    public static func choices(for s: ShowreelFile.Scene) -> [StateChoice] {
        func edit(_ st: SceneState) -> ProjectOperation { .scene(id: s.id, SceneEdit(status: st.rawValue)) }
        let now = s.state
        func choice(_ st: SceneState, title: String? = nil, _ op: ProjectOperation?, why: String? = nil) -> StateChoice {
            StateChoice(state: st, title: title ?? st.title, isCurrent: now == st, reason: op == nil && now != st ? why : nil, operation: now == st ? nil : op)
        }
        switch now {
        case .locked:
            return [choice(.wip, nil, why: "Unlock it first: a locked scene does not go back to WIP directly"),
                    choice(.validated, title: "Unlock (back to Validated)", .sceneLock(ids: [s.id], locked: false)),
                    choice(.locked, nil)]
        case .validated:
            return [choice(.wip, edit(.wip)), choice(.validated, nil), choice(.locked, .sceneLock(ids: [s.id], locked: true))]
        default:
            return [choice(.wip, nil), choice(.validated, edit(.validated)), choice(.locked, nil, why: "Validate it first: a lock never validates a scene")]
        }
    }

    /// "Lock all validated": one card for every Validated scene of the library that is not archived; nil when there is none.
    public static func lockAllValidated(_ f: ShowreelFile) -> ProjectOperation? {
        let ids = f.scenes.filter { !$0.archived && $0.state == .validated }.map { $0.id }
        return ids.isEmpty ? nil : .sceneLock(ids: ids, locked: true)
    }
}
