import Foundation

/// A row of the Transitions tab: the passage between two consecutive scenes of the film.
public struct TransitionRow: Equatable, Identifiable, Sendable {
    /// The scene it leaves (the marker's own id).
    public let from: String
    public let to: String
    public let type: String
    public let seconds: Double?
    public let isCut: Bool
    /// What the marker says about itself: "approximate render at assembly", "instruction pending...".
    public let marks: [String]
    public var id: String { from }
    /// "S01 to S02: Push, 0.6 s", or "S01 to S02: Cut".
    public var title: String { "\(from) to \(to): " + (isCut ? "Cut" : type + (seconds.map { ", \(ProjectDocs.seconds($0)) s" } ?? "")) }
}

public enum TransitionList {
    public static let emptyText = "Add scenes to see transitions"

    /// One row per pair of consecutive scenes of the film, in order. Fewer than two scenes: none.
    public static func rows(_ f: ShowreelFile, store: ProjectStore) -> [TransitionRow] {
        let tl = f.timeline()
        guard tl.count > 1 else { return [] }
        return (0..<(tl.count - 1)).map { i in
            let t = tl[i].item.transition
            let a = tl[i].scene, b = tl[i + 1].scene
            let seconds = t.isCut ? nil : (t.duration ?? f.defaultTransitionDuration(t.type, between: a, and: b))
            return TransitionRow(from: a.id, to: b.id, type: t.isCut ? "cut" : t.type, seconds: seconds, isCut: t.isCut, marks: TransitionNotes.note(after: a.id, in: f, store: store)?.lines ?? [])
        }
    }

    /// The transitions of the catalogue, with the six that only run as previews marked and refused at the drop, each with its reason.
    public static func catalogue() -> [CatalogueChoice] { Catalogue.choices(.transition) }

    /// The selection that clicking a row makes: the marker after the scene. It is the same selection a click on the marker makes.
    public static func selection(of row: TransitionRow) -> String { row.from }
}
