import Foundation

/// What the menu of a resource offers without a drag: the scenes it can be added to, each with its reason when it cannot, and "Use as the project's music" for a track.
/// The actions are the same typed operations a drop does (`Drops`), so the cards, the freeze during a build, the journal and Undo are the same.
public enum ResourceMenu {
    public struct SceneChoice: Equatable, Identifiable, Sendable {
        public let id: String
        public let label: String
        /// Why this scene cannot take the resource now (greyed in the menu); nil when it can.
        public let reason: String?
    }

    /// The scenes of the film, in order. A locked scene is listed greyed with its reason, an archived one is left out, and while a build runs every scene is greyed.
    public static func sceneChoices(asset id: String, store: ProjectStore) -> [SceneChoice] {
        guard let f = store.loadShowreel() else { return [] }
        let building = store.buildRefusal()?.localizedDescription
        return f.film.filter { !$0.archived }.map { s in
            if let b = building { return SceneChoice(id: s.id, label: s.label, reason: b) }
            switch Drops.verdict(.resource(id), on: .scene(s.id), store: store) {
            case .ok: return SceneChoice(id: s.id, label: s.label, reason: nil)
            case .refused(let why): return SceneChoice(id: s.id, label: s.label, reason: why)
            }
        }
    }

    /// Why the resource cannot go in any scene (a file that needs attention, an excluded one, a type no scene uses), or nil.
    public static func addRefusal(asset id: String, store: ProjectStore) -> String? {
        let c = sceneChoices(asset: id, store: store)
        if c.isEmpty { return "No scene is in the film yet" }
        if c.allSatisfy({ $0.reason != nil }) { return c.first?.reason }
        return nil
    }

    /// Whether "Use as the project's music" is offered (a track only) and why it is greyed.
    public static func music(asset id: String, store: ProjectStore) -> (offered: Bool, reason: String?) {
        guard let r = Assets.load(store).first(where: { $0.id == id }), r.type == "audio" else { return (false, nil) }
        if let b = store.buildRefusal() { return (true, b.localizedDescription) }
        if case .refused(let why) = Drops.verdict(.resource(id), on: .musicLane, store: store) { return (true, why) }
        if store.loadShowreel()?.decisions.track?.file == "assets/" + r.file { return (true, "\(r.name) already is the music") }
        return (true, nil)
    }

    @discardableResult
    public static func add(asset id: String, to scene: String, store: ProjectStore) -> DropPlan.Outcome {
        DropPlan.perform(token: DragItem.resource(id).token, target: .scene(scene), store: store).outcome
    }

    @discardableResult
    public static func useAsMusic(asset id: String, store: ProjectStore) -> DropPlan.Outcome {
        DropPlan.perform(token: DragItem.resource(id).token, target: .musicLane, store: store).outcome
    }
}
