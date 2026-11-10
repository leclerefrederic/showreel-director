import Foundation

/// One item as the stage draws it: what it says, and which of its attributes the AI has not decided yet.
public struct StageItem: Equatable, Sendable {
    public let id: String
    public let type: String
    public let text: String
    public let resource: String?
    /// The colour of words, resolved from a palette role or a custom hex; nil when it is auto (drawn neutral) or when the role is not in the palette.
    public let colorHex: String?
    public let colorIsAI: Bool
    public let animation: String?
    public let animationIsAI: Bool
}

/// What a scene shows at a time: the items on screen, drawn from the content only. It never invents what the AI has not produced: an auto colour or animation is drawn neutral and flagged.
public struct StageFrame: Equatable, Sendable {
    public let time: Double
    public let items: [StageItem]
    /// The palette's background colour for the scene, when it has one.
    public let backgroundHex: String?
    public var aiDecides: Bool { items.contains { $0.colorIsAI || $0.animationIsAI } }
    public var texts: [StageItem] { items.filter { $0.type == "text" } }
    public var images: [StageItem] { items.filter { $0.type == "image" } }
    public var sounds: [StageItem] { items.filter { $0.type == "audio" } }
}

public enum Stage {
    public static func frame(of scene: ShowreelFile.Scene, in file: ShowreelFile?, at t: Double) -> StageFrame {
        let items = ContentTiming.active(in: scene, at: t).map { i -> StageItem in
            var hex: String?
            if i.type == "text" { hex = i.color.mode == "role" ? file?.paletteHex(i.color.role, for: scene) : i.color.mode == "custom" ? i.color.hex : nil }
            return StageItem(id: i.id, type: i.type, text: i.text ?? "", resource: i.resource, colorHex: hex, colorIsAI: i.type == "text" && !i.color.isFixed,
                             animation: i.animation.mode == "effect" ? i.animation.effect : nil, animationIsAI: i.type != "audio" && !i.animation.isFixed)
        }
        return StageFrame(time: t, items: items, backgroundHex: file?.paletteHex("background", for: scene))
    }

    /// What a reader of the screen is told: the scene, the time, what is on screen, and what the AI still decides.
    public static func description(of f: StageFrame, scene: ShowreelFile.Scene) -> String {
        let what = f.items.isEmpty ? "nothing on screen" : f.items.map { $0.type == "text" ? "\u{201C}\($0.text)\u{201D}" : "\($0.type) \($0.resource ?? "")" }.joined(separator: ", ")
        return "\(scene.label) at \(ProjectDocs.seconds(f.time)) s: \(what)" + (f.aiDecides ? ". The AI decides the colours and animations that are not fixed." : "")
    }
}
