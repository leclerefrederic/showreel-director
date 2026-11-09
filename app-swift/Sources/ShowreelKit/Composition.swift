import Foundation

/// A resource linked to a scene is always an element of its composition. The manifest says which resources a scene uses; the scene's content says how.
/// This keeps the two in step: a linked image, logo, video or sound that has no element gets one, with every attribute auto (nothing is fixed for the user).
public enum Composition {
    /// The elements that are missing: a resource linked to a scene (in the manifest) that none of the scene's elements uses. A font, a file that needs
    /// attention and an excluded one cannot be an element: they stay linked, and show as such.
    public static func gaps(_ f: ShowreelFile, _ rows: [AssetRow]) -> [(scene: Int, asset: AssetRow, type: String)] {
        var out: [(scene: Int, asset: AssetRow, type: String)] = []
        for (si, s) in f.scenes.enumerated() where !s.archived && !s.isLocked {          // a locked scene is never completed behind its back
            for r in rows where r.sceneIDs.contains(s.id) && r.status != "excluded" && r.status != "hold" {
                guard let t = ContentRules.elementType(for: r.type), !s.content.contains(where: { $0.resource == r.id }) else { continue }
                out.append((si, r, t))
            }
        }
        return out
    }

    /// Adds the missing elements to a file in memory. Returns what it made ("S01 logo-01").
    @discardableResult
    public static func complete(_ f: inout ShowreelFile, _ rows: [AssetRow]) -> [String] {
        var made: [String] = []
        for g in gaps(f, rows) {
            guard !f.scenes[g.scene].content.contains(where: { $0.resource == g.asset.id }) else { continue }
            f.scenes[g.scene].content.append(ShowreelFile.ContentItem(id: ContentRules.nextID(f.scenes[g.scene].content), type: g.type, resource: g.asset.id))
            made.append("\(f.scenes[g.scene].id) \(g.asset.id)")
        }
        return made
    }
}

extension ProjectStore {
    /// Creates the missing elements and saves. `reopenGo` is true when the user (or the copilot) just linked something, which is a change to the film.
    /// Returns what it made.
    @discardableResult
    public func completeComposition(reopenGo: Bool) throws -> [String] {
        guard var f = loadShowreel() else { return [] }
        let made = Composition.complete(&f, Assets.load(self))
        guard !made.isEmpty else { return [] }
        if reopenGo, f.gates["review"] == "passed", made.contains(where: { m in f.film.contains { m.hasPrefix($0.id + " ") } }) { f.gates["review"] = "open" }
        try save(f)
        return made
    }

    /// Whether an operation can link a resource to a scene (so the composition must be completed).
    func linksResources(_ op: ProjectOperation) -> Bool {
        switch op {
        case .scene(_, let e), .addScene(_, let e): return e.assets != nil
        case .asset(_, _, _, _, let scenes): return scenes != nil
        default: return false
        }
    }
}
