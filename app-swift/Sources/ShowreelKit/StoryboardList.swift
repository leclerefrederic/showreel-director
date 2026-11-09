import Foundation

/// The Storyboard list of the left panel: the plan of the montage as one flat list, scenes in order, with one thin line between two consecutive scenes for the transition between them,
/// and under it the scenes that are not in the storyboard. The strip at the bottom is another view of the same storyboard, with the same selection.
public struct StoryboardList: Equatable, Sendable {
    public enum Entry: Equatable, Identifiable, Sendable {
        case scene(String)
        /// "Flip card \u{00B7} 0.55 s", "Cut": the passage out of `from` into `to`, with a glyph by type and what the marker says about itself.
        case transition(TransitionLine)
        public var id: String {
            switch self { case .scene(let s): return "scene:" + s; case .transition(let t): return "transition:" + t.from }
        }
    }

    public struct TransitionLine: Equatable, Sendable {
        public let from: String
        public let to: String
        public let text: String
        public let glyph: String
        public let isCut: Bool
        public let marks: [String]
        public var tooltip: String { "\(from) to \(to)" }
    }

    /// The columns of a scene row: the ID, the name as the title and the first words under it, the duration rounded to 0.1 s.
    public struct SceneRow: Equatable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let duration: String
    }

    /// A scene that is not in the storyboard: hidden. A scene that was archived or ditched in an older project is read as hidden, and the reason is kept as a note.
    public struct NotIn: Equatable, Identifiable, Sendable {
        public let id: String
        public let text: String
        public let note: String?
        public var why: String { "Hidden: it stays in the project, not in the film" + (note.map { ". " + $0 } ?? "") }
        public var wayBack: String { "Show" }
    }

    public let entries: [Entry]
    public let notIn: [NotIn]
    public var sceneIDs: [String] { entries.compactMap { if case .scene(let s) = $0 { return s }; return nil } }

    /// The glyph of a transition by its type; scissors for a cut.
    public static func glyph(_ type: String, isCut: Bool) -> String {
        if isCut { return "scissors" }
        let t = type.lowercased()
        if t.contains("flip") || t.contains("card") { return "rectangle.on.rectangle.angled" }
        if t.contains("dissolve") || t.contains("fade") || t.contains("blur") { return "circle.lefthalf.filled" }
        if t.contains("zoom") || t.contains("scale") { return "plus.magnifyingglass" }
        if t.contains("push") || t.contains("slide") || t.contains("wipe") || t.contains("curtain") { return "arrow.right" }
        return "arrow.left.arrow.right"
    }

    /// The text of a transition line: "Flip card \u{00B7} 0.55 s", "Cut".
    public static func text(_ r: TransitionRow) -> String { r.isCut ? "Cut" : r.type + (r.seconds.map { " \u{00B7} \(ProjectDocs.seconds($0)) s" } ?? "") }

    /// "3.2 s": the length of the scene in the film, rounded to 0.1 s; a dash when it has none.
    public static func durationText(_ d: Double?) -> String { d.map { String(format: "%.1f s", ($0 * 10).rounded() / 10) } ?? "\u{2013}" }

    public static func row(_ s: ShowreelFile.Scene, in f: ShowreelFile) -> SceneRow {
        let words = s.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        let len = f.timeline().first { $0.scene.id == s.id }?.length ?? s.duration
        let name = (s.name ?? "").isEmpty ? nil : s.name
        return SceneRow(id: s.id, title: name ?? (words.isEmpty ? "(no text)" : words), subtitle: name == nil ? "" : words, duration: durationText(len))
    }

    public static func build(_ f: ShowreelFile, store: ProjectStore) -> StoryboardList {
        let film = f.film.map { $0.id }
        let lines = Dictionary(uniqueKeysWithValues: TransitionList.rows(f, store: store).map { ($0.from, $0) })
        var entries: [Entry] = []
        for (n, id) in film.enumerated() {
            entries.append(.scene(id))
            if n + 1 < film.count, let r = lines[id] {
                entries.append(.transition(TransitionLine(from: r.from, to: r.to, text: text(r), glyph: glyph(r.type, isCut: r.isCut), isCut: r.isCut, marks: r.marks)))
            }
        }
        let inFilm = Set(film)
        let hidden = f.orderedLibrary.filter { !inFilm.contains($0.id) } + f.scenes.filter { $0.archived }
        let notIn = hidden.map { s -> NotIn in
            let was = s.state == .ditched ? "Was ditched." : s.archived ? "Was archived." : nil
            let note = [was, s.note.isEmpty ? nil : "Note: " + s.note].compactMap { $0 }.joined(separator: " ")
            return NotIn(id: s.id, text: s.text, note: note.isEmpty ? nil : note)
        }
        return StoryboardList(entries: entries, notIn: notIn)
    }

    /// The scene that follows `id` in the list, for the arrow keys and the drop slots; nil at the end.
    public func next(after id: String?) -> String? { sceneIDs.firstIndex(of: id ?? "").flatMap { $0 + 1 < sceneIDs.count ? sceneIDs[$0 + 1] : nil } }
}
