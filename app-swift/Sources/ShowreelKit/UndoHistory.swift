import Foundation

/// One line of the history menu: the title of a step and how many steps choosing it goes through (1 for the nearest).
public struct HistoryItem: Equatable, Sendable {
    public let title: String
    public let steps: Int
}

/// What the rail's Undo and Redo buttons list when pressed and held, or right-clicked: the last actions of the stack, newest first, and (apart, dimmed) the ones on the other side.
public struct UndoHistory: Equatable, Sendable {
    public static let menuLimit = 20
    /// The title of a step that was recorded without one.
    public static let untitled = "Untitled action"

    /// Steps to take back, the last one first; steps to do again, the one Redo does first.
    public let undo: [HistoryItem]
    public let redo: [HistoryItem]
    /// How many listed steps had no title of their own.
    public let untitledCount: Int

    public static func title(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? untitled : t
    }

    /// "Undid: Lock S02", "Undid 3 actions: Lock S02; Delete S03; Move S01"; the redo words for `redo`.
    public static func line(redo: Bool, _ titles: [String]) -> String {
        let word = redo ? "Redid" : "Undid"
        return titles.count == 1 ? "\(word): \(titles[0])" : "\(word) \(titles.count) actions: " + titles.joined(separator: "; ")
    }

    static func items(_ raw: [String], limit: Int) -> [HistoryItem] {
        raw.prefix(limit).enumerated().map { HistoryItem(title: title($0.element), steps: $0.offset + 1) }
    }

    public init(undoTitles: [String], redoTitles: [String], limit: Int = UndoHistory.menuLimit) {
        undo = Self.items(undoTitles, limit: limit); redo = Self.items(redoTitles, limit: limit)
        untitledCount = (undoTitles.prefix(limit) + redoTitles.prefix(limit)).filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

extension UndoLog {
    /// The titles of the stacks as the menu lists them (newest first, at most `limit` each).
    public func history(limit: Int = UndoHistory.menuLimit) -> UndoHistory {
        UndoHistory(undoTitles: undos.reversed().map { $0.title }, redoTitles: redos.reversed().map { $0.title }, limit: limit)
    }
}

/// The two buttons of the rail: the same availability as the Edit menu (`Availability.undo`) and a tooltip that names the next action.
public enum RailHistory {
    public static func tooltip(redo: Bool, title: String?, _ a: Availability) -> String {
        if let u = a.why { return u.message }
        let t = title.map { UndoHistory.title($0) } ?? ""
        return (redo ? "Redo: " : "Undo: ") + t + (redo ? " (Shift-Command-Z)" : " (Command-Z)") + ". Press and hold, or right-click, for the last actions"
    }
}
