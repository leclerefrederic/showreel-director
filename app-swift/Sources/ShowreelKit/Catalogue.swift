import Foundation

/// The three catalogues that are picked where they are used: effects (an item's animation), scene transitions (a marker of the reel) and
/// backgrounds (a scene's own). The choice is a typed operation; the drag from the Catalogue palette builds the very same one.
public enum CatalogueKind: String, CaseIterable, Sendable {
    case effect, transition, background

    public var title: String { self == .effect ? "Effects" : self == .transition ? "Transitions" : "Backgrounds" }
}

public struct CatalogueChoice: Equatable, Identifiable, Sendable {
    public let id: String
    public let group: String          // the category of an effect, the energy of a transition
    public let detail: String
    /// False for the six transitions that only run as previews: shown, never chosen.
    public let selectable: Bool
    public let reason: String?
}

/// Where a choice goes.
public enum CatalogueTarget: Equatable, Sendable {
    case item(scene: String, item: String)      // an effect becomes the item's animation
    case marker(from: String)                   // a transition becomes the passage after this scene
    case scene(String)                          // a background becomes this scene's own
}

public enum Catalogue {
    /// What the picker lists, from the skill's catalogue files.
    public static func choices(_ kind: CatalogueKind) -> [CatalogueChoice] {
        switch kind {
        case .effect:
            return Look.effectDetails().filter { $0.cat != EngineCatalogue.transitionCategory }
                .map { CatalogueChoice(id: $0.name, group: $0.cat, detail: $0.desc, selectable: true, reason: nil) }
        case .transition:
            let preview = Look.transitionsPreviewOnly()
            return Look.transitions().map {
                CatalogueChoice(id: $0.name, group: $0.energy, detail: $0.desc, selectable: !preview.contains($0.name),
                                reason: preview.contains($0.name) ? "Preview only: it does not run between two real scenes, so it cannot be chosen for a montage" : nil)
            }
        case .background:
            return Look.backgroundIDs().map { CatalogueChoice(id: $0, group: "", detail: "", selectable: true, reason: nil) }
        }
    }

    /// The item a row of the picker or of the Catalogue palette drags.
    public static func dragItem(_ kind: CatalogueKind, _ id: String) -> DragItem {
        switch kind { case .effect: return .effect(id); case .transition: return .transition(id); case .background: return .background(id) }
    }

    /// The typed operation of a choice. `choice` may be "auto" (an item's animation back to the AI) or "cut" (a transition back to the default).
    public static func operation(_ kind: CatalogueKind, choice: String, target: CatalogueTarget) throws -> ProjectOperation {
        switch (kind, target) {
        case (.effect, .item(let scene, let item)): return .content(scene: scene, .update(item: item, ContentEdit(animation: choice)))
        case (.transition, .marker(let from)): return .transition(from: from, TransitionEdit(type: choice))
        case (.background, .scene(let id)): return .sceneLook(id: id, [DecisionChange(.background, choice)])
        default: throw AgentError.msg("\(kind.title.lowercased()) do not go there")
        }
    }

    /// What the target uses now ("auto" and "cut" for the defaults), to mark it in the picker.
    public static func current(_ kind: CatalogueKind, target: CatalogueTarget, in f: ShowreelFile) -> String {
        switch (kind, target) {
        case (.effect, .item(let s, let i)):
            let a = f.scenes.first { $0.id == s }?.content.first { $0.id == i }?.animation
            return a?.mode == "effect" ? (a?.effect ?? "auto") : "auto"
        case (.transition, .marker(let from)): return f.transition(after: from)?.item.type ?? "cut"
        case (.background, .scene(let id)): return f.scenes.first { $0.id == id }.map { f.effective(.background, for: $0) } ?? ""
        default: return ""
        }
    }
}
