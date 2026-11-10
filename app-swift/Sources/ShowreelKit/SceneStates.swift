import Foundation

/// The review state of a scene. WIP is the default (it includes "to modify": WIP with a note), Validated is "OK", Locked is Validated that nothing may
/// change. Ditched archives the scene. A file from before revision 2 says open, ok or modify: they are read as WIP, Validated and WIP (the note stays).
public enum SceneState: String, CaseIterable, Sendable {
    case wip, validated, locked, ditched

    public var title: String {
        switch self { case .wip: return "To review"; case .validated: return "Ready"; case .locked: return "Locked"; case .ditched: return "Ditched" }
    }

    /// What a state means, for the tooltip of its badge.
    public var meaning: String {
        switch self {
        case .wip: return "To review: not Ready yet, or Ready was switched off to ask for a change"
        case .validated: return "Ready: you are satisfied with it. It is not locked: a change sends it back to To review"
        case .locked: return "Locked: frozen in time and space, visible or hidden. Nothing in it can change and nothing before it can move it"
        case .ditched: return "Ditched (an older project): read as a hidden scene"
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
    public static let makeReadyFirst = "Make the scene Ready first"
    public static func reason(_ id: String) -> String {
        "\(id) is locked: unlock it first"
    }
}

extension ProjectStore {
    /// The scenes an operation would change. A locked one refuses it: its content, look, length, visibility, place, deletion. A transition leaving it and the lock itself
    /// are allowed. A change elsewhere that would move its start is refused by `lockShiftRefusal`, where the new file is known.
    func scenesChanged(by op: ProjectOperation, in f: ShowreelFile) -> [String] {
        switch op {
        case .scene(let id, let e): return e == SceneEdit() ? [] : [id]          // a position too: a locked scene does not move
        case .sceneEnabled(let id, _, _): return [id]                            // nor does its visibility change
        case .moveScene(let id, _, _): return [id]
        case .deleteScene(let id): return [id]
        case .sceneLook(let id, _): return [id]
        case .content(let id, _): return [id]
        case .resize(let id, _): return [id]             // the scene's own edge; the scenes after it move, their lengths never change
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

    /// Lock or unlock scenes as one card. Only a Ready scene can be locked (a lock never makes a scene Ready by itself); unlocking gives back Ready. Locking takes a copy of the
    /// look the scene is drawn with (palette, fonts, background, moods, effects pack): a later change of the project's look no longer reaches it. Unlocking drops the copy.
    func planLock(_ ids: [String], locked: Bool) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        guard !ids.isEmpty else { throw AgentError.msg("no scene to \(locked ? "lock" : "unlock")") }
        var g = f
        var lines: [Change] = []
        for id in ids {
            guard let i = g.scenes.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
            let s = g.scenes[i]
            if locked {
                if s.state == .locked { continue }
                guard s.state == .validated else { throw AgentError.msg("\(id) is not Ready: \(SceneLock.makeReadyFirst)") }
                g.scenes[i].status = SceneState.locked.rawValue
                g.scenes[i].lockedLook = LockedLook.copy(of: s, in: f)
                lines.append(Change("\(id) state", s.state.title, g.scenes[i].state.title))
                lines.append(Change("\(id) look", "follows the project's look", "a copy is kept: the project's look no longer reaches it"))
            } else {
                if s.state != .locked { continue }
                g.scenes[i].status = SceneState.validated.rawValue
                g.scenes[i].lockedLook = nil
                lines.append(Change("\(id) state", s.state.title, g.scenes[i].state.title))
                if let note = LockedLook.unlockNote(s, in: f) { lines.append(Change("\(id) look", "the copy kept at the lock", note)) }
            }
        }
        guard !lines.isEmpty else { throw AgentError.msg("no change: " + (ids.count == 1 ? "\(ids[0]) already is \(locked ? "locked" : "not locked")" : "the scenes already are \(locked ? "locked" : "not locked")")) }
        let changed = Set(lines.compactMap { l in ids.first { l.label.hasPrefix($0 + " ") } })
        let title = (locked ? "Lock " : "Unlock ") + (changed.count == 1 ? changed.first! : "\(changed.count) scenes")
        return try finish(title: title, changes: lines, from: f, to: g)
    }
}

/// "Lock all" and the rules of the three switches live in `SceneSwitches` (SceneStatus.swift).
public enum SceneStates {
    /// "Lock all validated": one card for every Validated scene of the library that is not archived; nil when there is none.
    public static func lockAllValidated(_ f: ShowreelFile) -> ProjectOperation? {
        let ids = f.scenes.filter { !$0.archived && $0.state == .validated }.map { $0.id }
        return ids.isEmpty ? nil : .sceneLock(ids: ids, locked: true)
    }
}
