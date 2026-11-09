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
            s.isLocked && !s.archived && keys.contains { !f.isOverridden($0, for: s) }
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
