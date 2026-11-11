import Foundation

/// What a change of the project's look does to the locked scenes: a locked scene refuses a change *to itself*, but it still draws with the project's palette,
/// fonts, background, mood and effects pack unless it has its own. The rule is here; the views draw the warning on the card and ask.
public struct LockedLookWarning: Equatable, Sendable {
    /// The locked scenes that inherit what the change touches, in library order.
    public let scenes: [String]

    public var headline: String {
        let list = LockedLook.list(scenes)
        return scenes.count == 1 ? "\(list) is locked and inherits this look" : "\(list) are locked and inherit this look"
    }

    public var advice: String { "Applying this will change locked scenes. Unlock them first, or give them their own look." }
}

public enum LockedLook {
    /// The locked scenes that inherit at least one of the changed decisions. A scene that has its own value for a decision does not inherit it; the moods and
    /// the effects pack cannot be overridden by a scene, so every locked scene inherits them. Archived scenes are not in the film.
    public static func scenes(changing keys: [DecisionKey], in f: ShowreelFile) -> [String] {
        guard !keys.isEmpty else { return [] }
        return f.scenes.filter { s in
            s.isLocked && !s.archived && s.lockedLook == nil && keys.contains { !f.isOverridden($0, for: s) }          // a locked scene with its copy is never reached
        }.map { $0.id }
    }

    public static func warning(changing keys: [DecisionKey], in f: ShowreelFile) -> LockedLookWarning? {
        let ids = scenes(changing: keys, in: f)
        return ids.isEmpty ? nil : LockedLookWarning(scenes: ids)
    }

    /// "S02", "S02 and S05", "S02, S05 and S07".
    static func list(_ ids: [String]) -> String {
        switch ids.count {
        case 0, 1: return ids.first ?? ""
        default: return ids.dropLast().joined(separator: ", ") + " and " + ids.last!
        }
    }
}

extension LockedLook {
    /// The look a scene is drawn with now, in full: its own palette, fonts and background, else the project's, and the project's moods and effects pack (a scene cannot
    /// override those). Kept in the scene when it is locked.
    public static func copy(of s: ShowreelFile.Scene, in f: ShowreelFile) -> ShowreelFile.Decisions {
        let own = s.overrides, base = f.decisions
        var d = ShowreelFile.Decisions()
        d.palette = own?.palette ?? base.palette
        d.fonts = ShowreelFile.Fonts(titles: own?.fonts?.titles ?? base.fonts?.titles, text: own?.fonts?.text ?? base.fonts?.text)
        d.background = ShowreelFile.Background(id: own?.background?.id ?? base.background?.id, mood: own?.background?.mood ?? base.background?.mood)
        d.moods = base.moods
        d.effectsPack = base.effectsPack
        return d
    }

    /// What unlocking does to the look, when the copy kept at the lock differs from the look the scene would follow now; nil when it does not.
    public static func unlockNote(_ s: ShowreelFile.Scene, in f: ShowreelFile) -> String? {
        guard let copy = s.lockedLook else { return nil }
        var kept = ShowreelFile(name: ""); kept.decisions = copy
        var free = s; free.lockedLook = nil
        let differing = DecisionKey.allCases.filter { kept.decisions == copy && $0.current(kept) != f.effective($0, for: free) }
        guard !differing.isEmpty else { return nil }
        return "it follows the project's look again: " + differing.map { $0.title.lowercased() }.joined(separator: ", ") + " will change"
    }
}

/// DECISION-028: a scene locked before UI2 has no copy of its look and would follow the project's look when it changes. When a project opens, each such scene takes a copy equal to
/// the look it follows now, so nothing changes on screen and the lock holds from then on. The field is the one the lock writes (`lockedLook`); older apps keep what they do not know.
public enum LockedLookMigration {
    /// The locked scenes with no copy, in library order.
    public static func pending(in f: ShowreelFile) -> [String] { f.scenes.filter { $0.isLocked && $0.lockedLook == nil }.map { $0.id } }

    /// The file with each of those scenes holding its copy, and their ids. Nothing else is touched; a second call changes nothing.
    public static func apply(_ f: ShowreelFile) -> (file: ShowreelFile, scenes: [String]) {
        var g = f
        let ids = pending(in: f)
        for i in g.scenes.indices where ids.contains(g.scenes[i].id) { g.scenes[i].lockedLook = LockedLook.copy(of: g.scenes[i], in: f) }
        return (g, ids)
    }

    /// The journal line and the note the owner sees.
    public static func summary(_ n: Int) -> String { "Locked scenes took a copy of their look: \(n) scene\(n == 1 ? "" : "s")" }

    /// On opening: writes the copies and one journal line, and returns the scenes; writes nothing when there are none. A project of an older revision is left alone (nothing is written
    /// before "Update project"; the next opening does it), as is a file that cannot be read. The journal line is not an undo step: undoing it would put back the unprotected state.
    @discardableResult
    public static func run(_ store: ProjectStore) -> [String] {
        guard let f = store.loadShowreel(), !f.isOutdated else { return [] }
        let r = apply(f)
        guard !r.scenes.isEmpty, (try? store.save(r.file)) != nil else { return [] }
        store.noteEvent(author: "app", op: "lockedLook", target: r.scenes.joined(separator: ", "), title: summary(r.scenes.count),
                        before: "the locked scenes followed the project's look", after: "each keeps a copy of its look", note: "DECISION-028")
        return r.scenes
    }
}
