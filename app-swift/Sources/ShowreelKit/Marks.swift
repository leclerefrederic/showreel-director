import Foundation

// MARK: what is marked, and where

/// The surfaces that draw scenes and resources. A mark is decided once for an element and drawn the same on every surface that shows it.
public enum Surface: String, CaseIterable, Sendable { case list, tree, reel, inspector, resources }

public enum Marks {
    /// The temporary mark of an element: why it is read-only now (the build is running, a proposal of Clap waits on it, Clap is applying changes to it), with the way out.
    /// nil when it is free. A lock is not temporary: it is the review badge.
    public static func temporary(_ ref: ElementRef, in s: ProjectActivity.Snapshot) -> Unavailable? {
        if s.isBuilding { return Reasons.building }
        if let p = s.proposal(blocking: ref) { return Reasons.proposal(p) }
        if case .applying(let refs)? = s.clap, refs.contains(where: { $0.overlaps(ref) }) {
            return Reasons.clapWorking(refs.compactMap { if case .scene(let i) = $0 { return i } else { return nil } })
        }
        return nil
    }

    /// What a surface draws: the elements that can carry a mark on it.
    public static func elements(on surface: Surface, file: ShowreelFile?, assets: [AssetRow]) -> [ElementRef] {
        let library = file?.library ?? []
        switch surface {
        case .list: return library.map { .scene($0.id) }
        case .reel: return (file?.film ?? []).map { .scene($0.id) }
        case .tree: return library.flatMap { s in [ElementRef.scene(s.id)] + s.content.map { ElementRef.item(scene: s.id, item: $0.id) } }
        case .inspector: return library.map { .scene($0.id) } + assets.map { .asset($0.id) }
        case .resources: return assets.map { .asset($0.id) }
        }
    }

    /// The marked elements of a surface, with their reason.
    public static func marked(on surface: Surface, file: ShowreelFile?, assets: [AssetRow], in s: ProjectActivity.Snapshot) -> [ElementRef: Unavailable] {
        var out: [ElementRef: Unavailable] = [:]
        for e in elements(on: surface, file: file, assets: assets) { if let u = temporary(e, in: s) { out[e] = u } }
        return out
    }
}

// MARK: the layout of the marks of a scene

/// The one rule of the layout. A scene has two persistent badges, side by side in this order: the review state (WIP, Validated, Locked; round), then the build state (not
/// generated, up to date, stale, edited by hand; square). The temporary mark (a proposal waiting, the build running) is a veil, a thin tinted outline around the whole row
/// or frame, and a small button at the end: it never sits on top of a badge. The same on the list, the tree, the reel and the inspector.
public enum MarkLayout {
    public enum Badge: Int, CaseIterable, Sendable { case review, build }

    public static func badges(for scene: ShowreelFile.Scene, film: FilmBuild.Status) -> [Badge] {
        if scene.archived { return [.review] }
        return film.state != .legacy && film.target != nil && film.scenes[scene.id] != nil ? [.review, .build] : [.review]
    }

    /// The temporary mark is never one of the badges.
    public static let temporaryIsABadge = false
}

// MARK: the menu items that are disabled

public extension Availability {
    /// Undo and Redo of the Edit menu: why not, in the item's own words (a menu item has no tooltip).
    static func undo(_ s: ProjectActivity.Snapshot, can: Bool, redo: Bool = false) -> Availability {
        if s.isBuilding { return .unavailable(Reasons.building) }
        if !can { return .unavailable(Unavailable(.notReady, reason: redo ? "Nothing to redo" : "Nothing to undo", way: redo ? "Undo something first" : "Make a change first")) }
        return .available
    }
}
