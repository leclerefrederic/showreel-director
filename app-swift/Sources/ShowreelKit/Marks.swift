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

// MARK: the menu items that are disabled

public extension Availability {
    /// Undo and Redo of the Edit menu: why not, in the item's own words (a menu item has no tooltip).
    static func undo(_ s: ProjectActivity.Snapshot, can: Bool, redo: Bool = false) -> Availability {
        if s.isBuilding { return .unavailable(Reasons.building) }
        if !can { return .unavailable(Unavailable(.notReady, reason: redo ? "Nothing to redo" : "Nothing to undo", way: redo ? "Undo something first" : "Make a change first")) }
        return .available
    }
}
