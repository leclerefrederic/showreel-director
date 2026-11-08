import Foundation

public enum SceneGroup: String, CaseIterable, Sendable {
    case raw, texts, effects, background, look
    public var title: String { self == .raw ? "Raw" : rawValue.capitalized }
}

/// The status of a resource used by a scene, from the asset rules the app already has (no AI).
public enum NodeStatus: String, Sendable {
    case approved, toApprove = "to approve", missing, overBudget = "over budget", excluded
}

public enum NodeOrigin: String, Sendable { case inherited, overridden }

public struct SceneNode: Equatable, Identifiable, Sendable {
    public let id: String            // unique inside the scene
    public let title: String
    public let detail: String
    public var status: NodeStatus?
    public var origin: NodeOrigin?
    public var assetID: String?
    public var projectValue: String? // for an overridden node: what the project says
}

public struct SceneGroupNodes: Equatable, Identifiable, Sendable {
    public let group: SceneGroup
    public let nodes: [SceneNode]
    public var id: String { group.rawValue }
}

public enum SceneTree {
    /// What composes one scene: the resources linked to it (Raw), its words (Texts), its effects (none until layers exist), its background
    /// and its look (inherited from the project unless the scene overrides them). Statuses are computed from the manifest and the files.
    public static func build(_ scene: ShowreelFile.Scene, in f: ShowreelFile, assets: [AssetRow], store: ProjectStore) -> [SceneGroupNodes] {
        // the items of the content list first, by type; then the resources the manifest links to the scene that no item uses
        func facts(_ i: ShowreelFile.ContentItem) -> String {
            [i.color.isFixed ? "colour \(i.color.text)" : nil, i.animation.isFixed ? i.animation.text : nil, i.hasInstruction ? "instruction" : nil].compactMap { $0 }.joined(separator: " · ")
        }
        var raw: [SceneNode] = []
        for (n, i) in scene.content.enumerated() where i.type != "text" {
            let a = assets.first { $0.id == i.resource }
            raw.append(SceneNode(id: "item." + i.id, title: (i.type == "image" ? "Image · " : "Sound · ") + (a?.name ?? i.resource ?? "(no resource)"),
                                 detail: "priority \(n + 1)" + (facts(i).isEmpty ? "" : " · " + facts(i)), status: a.map { Assets.nodeStatus($0, store: store) } ?? .missing, assetID: a?.id))
        }
        let used = Set(scene.content.compactMap { $0.resource })
        for a in assets where a.sceneIDs.contains(scene.id) && !used.contains(a.id) {
            raw.append(SceneNode(id: "raw." + a.id, title: a.name, detail: "\(a.id) · \(a.type)", status: Assets.nodeStatus(a, store: store), assetID: a.id))
        }
        var texts: [SceneNode] = []
        for (n, i) in scene.content.enumerated() where i.type == "text" {
            texts.append(SceneNode(id: "item." + i.id, title: "Text \(n + 1)", detail: "\u{201C}\(i.text ?? "")\u{201D}" + (facts(i).isEmpty ? "" : " · " + facts(i))))
        }
        if scene.content.allSatisfy({ $0.type != "text" }), !scene.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { texts.append(SceneNode(id: "text.master", title: "Text", detail: scene.text)) }
        for (l, t) in scene.texts.sorted(by: { $0.key < $1.key }) where !t.isEmpty { texts.append(SceneNode(id: "text." + l, title: l, detail: t)) }
        func node(_ id: String, _ title: String, _ keys: [DecisionKey]) -> SceneNode {
            let over = keys.contains { f.isOverridden($0, for: scene) }
            let value = keys.map { f.effective($0, for: scene) }.filter { !$0.isEmpty }.joined(separator: ", ")
            let proj = keys.map { $0.current(f) }.filter { !$0.isEmpty }.joined(separator: ", ")
            return SceneNode(id: id, title: title, detail: value.isEmpty ? "(none)" : value, origin: over ? .overridden : .inherited, projectValue: over ? (proj.isEmpty ? "(none)" : proj) : nil)
        }
        return [
            SceneGroupNodes(group: .raw, nodes: raw),
            SceneGroupNodes(group: .texts, nodes: texts),
            SceneGroupNodes(group: .effects, nodes: effects(scene)),
            SceneGroupNodes(group: .background, nodes: [node("background", "Background", [.background, .backgroundMood])]),
            SceneGroupNodes(group: .look, nodes: [node("palette", "Palette", [.palette]), node("fonts", "Fonts", [.titleFont, .textFont])]),
        ]
    }

    /// The effects the scene uses: the animation of each item that names one, with the items it is on.
    static func effects(_ scene: ShowreelFile.Scene) -> [SceneNode] {
        var order: [String] = [], on: [String: [String]] = [:]
        for i in scene.content where i.animation.mode == "effect" {
            guard let e = i.animation.effect else { continue }
            if on[e] == nil { order.append(e) }
            on[e, default: []].append(i.id)
        }
        return order.map { SceneNode(id: "effect." + $0, title: $0, detail: "on " + on[$0]!.joined(separator: ", ")) }
    }
}

extension Assets {
    /// approved, to approve (proposed, held, placeholder), missing (the listed file is not there) or over budget (the weight rules of the manifest).
    public static func nodeStatus(_ a: AssetRow, store: ProjectStore) -> NodeStatus {
        if a.status == "excluded" { return .excluded }
        let rel = a.file.isEmpty ? (a.original.isEmpty ? "" : "source/" + a.original) : a.file
        if !rel.isEmpty {
            let url = store.root.appendingPathComponent("assets/" + rel)
            if !FileManager.default.fileExists(atPath: url.path) { return .missing }
            if heavyReason(url, type: a.type) != nil { return .overBudget }
        }
        return a.status == "approved" ? .approved : .toApprove
    }
}
