import Foundation

/// The steps and gates the app implements and the blocks of its sidebar (`app-swift/shared/process.json`).
/// `tools/check.py` keeps the steps in step with the Gates table of SKILL.md.
public struct ProcessSpec: Decodable, Sendable {
    public struct BlockSpec: Decodable, Sendable, Identifiable, Equatable {
        public let id: String
        public let name: String
        public let icon: String
        public let built: Bool
        public let phase: String?
    }
    public struct StepSpec: Decodable, Sendable, Identifiable, Equatable {
        public let id: String
        public let name: String
        public let gate: String
        public let gateKey: String?
        public let block: String
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
    /// The blocks of the sidebar, in the order of the process. Every id has a view in the app.
    public static let ids = ["project", "look", "resources", "storyboard", "scene", "build", "deliver"]

    /// Whether the user already put something in a block.
    static func hasContent(_ id: String, _ f: ShowreelFile, _ assets: [AssetRow]) -> Bool {
        switch id {
        case "project":
            let p = f.parameters
            return [p.audience, p.message, p.tone, p.constraints].contains { ($0 ?? "").isEmpty == false }
                || !f.reelLanguages.isEmpty || f.decisions.duration != nil || !(f.decisions.formats ?? []).isEmpty
        case "resources": return !assets.isEmpty
        case "look": return f.decisions.palette != nil || f.decisions.fonts != nil || f.decisions.background != nil
        case "storyboard", "scene": return !f.scenes.isEmpty
        default: return false
        }
    }

    public static func status(_ id: String, spec: ProcessSpec, showreel f: ShowreelFile?, assets: [AssetRow]) -> BlockStatus {
        guard let b = spec.block(id), b.built else { return .soon }
        guard let f = f else { return .todo }
        let keys = spec.gateKeys(of: id)
        if !keys.isEmpty, keys.allSatisfy({ f.gates[$0] == "passed" }) { return .validated }
        return hasContent(id, f, assets) ? .inProgress : .todo
    }
}
