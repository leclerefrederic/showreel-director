import Foundation

/// The steps and gates the app implements and the zones of its editing workspace (`app-swift/shared/process.json`).
/// A step sits in a zone (`block`: where the user does it) and has an `area` (what it is about: project, resources, look, storyboard, scene,
/// build): the checks and the wizard are organised by area.
/// `tools/check.py` keeps the steps in step with the Gates table of SKILL.md.
public struct ProcessSpec: Decodable, Sendable {
    public struct BlockSpec: Decodable, Sendable, Identifiable, Equatable {
        public let id: String
        public let name: String
        public let icon: String
        public let built: Bool
        public let phase: String?
        /// Whether the block needs an AI: none, optional (a suggestion or review the user asks for) or required (generation: Build only).
        public let ai: String
    }
    public struct StepSpec: Decodable, Sendable, Identifiable, Equatable {
        public let id: String
        public let name: String
        public let gate: String
        public let gateKey: String?
        public let block: String
        public let area: String
        public let built: Bool
        public let produces: [String]
    }
    public let blocks: [BlockSpec]
    public let steps: [StepSpec]

    public static func load() -> ProcessSpec? {
        guard let u = resource("shared", dev: "app-swift/shared")?.appendingPathComponent("process.json"),
              let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(ProcessSpec.self, from: d)
    }

    public func block(_ id: String) -> BlockSpec? { blocks.first { $0.id == id } }
    public func gateKeys(of block: String) -> [String] { steps.filter { $0.block == block }.compactMap { $0.gateKey } }
    public func gateKeys(area: String) -> [String] { steps.filter { $0.area == area }.compactMap { $0.gateKey } }
    public func isBuilt(area: String) -> Bool { steps.contains { $0.area == area && $0.built } }
}

public enum BlockStatus: String, Sendable {
    case soon, todo, inProgress, validated

    public var label: String {
        switch self {
        case .soon: return "Coming soon"
        case .todo: return "To do"
        case .inProgress: return "In progress"
        case .validated: return "Validated"
        }
    }
}

public enum Blocks {
    /// The zones of the workspace. Every id has a view in the app.
    public static let ids = ["library", "viewer", "inspector", "storyboard", "build", "deliver"]

    /// The areas the checks and the wizard are organised by, in the order of the process.
    public static let areas = ["project", "resources", "look", "storyboard", "scene", "build"]

    /// Whether the user already put something in a zone.
    static func hasContent(_ id: String, _ f: ShowreelFile, _ assets: [AssetRow]) -> Bool {
        switch id {
        case "inspector":
            let p = f.parameters
            return [p.audience, p.message, p.tone, p.constraints].contains { ($0 ?? "").isEmpty == false }
                || !f.reelLanguages.isEmpty || f.decisions.duration != nil || !(f.decisions.formats ?? []).isEmpty
                || f.decisions.palette != nil || f.decisions.fonts != nil || f.decisions.background != nil
        case "library": return !assets.isEmpty || !f.library.isEmpty
        case "viewer", "storyboard": return !f.film.isEmpty
        case "build": return f.gates["review"] == "passed"
        default: return false
        }
    }

    public static func status(_ id: String, spec: ProcessSpec, showreel f: ShowreelFile?, assets: [AssetRow]) -> BlockStatus {
        guard let b = spec.block(id), b.built else { return .soon }
        guard let f = f else { return .todo }
        let keys = spec.gateKeys(of: id)
        if !keys.isEmpty, keys.allSatisfy({ f.gateState($0) == "passed" }) { return .validated }
        return hasContent(id, f, assets) ? .inProgress : .todo
    }
}
