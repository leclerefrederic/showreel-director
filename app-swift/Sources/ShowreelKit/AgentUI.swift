import Foundation

/// An edit the copilot offers on a file. The user accepts or refuses it; nothing is written before that.
public struct Proposal: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let file: String          // path relative to the project folder
    public let original: String?     // content the proposal was based on; nil when the file does not exist yet
    public let proposed: String
    public let note: String

    public init(file: String, original: String?, proposed: String, note: String) {
        self.file = file; self.original = original; self.proposed = proposed; self.note = note
    }
}

/// What the agent loop and the tools need from the interface.
public protocol AgentUI: AnyObject {
    func text(_ t: String)
    func endText()
    func tool(_ name: String, _ input: [String: Any])
    /// The tool call is over (its result goes back to the model).
    func toolDone(_ name: String)
    func show(_ url: String, _ title: String)
    func screenshot(javascript: String?, waitMs: Int) async -> Data?
    func ask(_ questions: [[String: Any]]) async -> [String]
    /// Shows the diff and waits for the answer: true = accepted. The caller writes the file.
    func propose(_ p: Proposal) async -> Bool
    /// A typed change shown as a plain card (before and after): true = accepted. The caller applies it.
    func proposeOperation(_ card: OperationCard) async -> Bool
    /// The project file the user has in front of them, if any (relative path).
    func foregroundFile() async -> String?
    /// The block of the sidebar the user is in (project, resources, ...), if any.
    func foregroundBlock() async -> String?
    /// Switches the window to a block.
    func openBlock(_ id: String) async
    /// Clap added to, changed or took something out of the project's memory: shown in the conversation in a plain word.
    func memoryNote(_ text: String) async
}

public extension AgentUI {
    func toolDone(_ name: String) {}
    func memoryNote(_ text: String) async {}
    func propose(_ p: Proposal) async -> Bool { false }
    func proposeOperation(_ card: OperationCard) async -> Bool { false }
    func foregroundFile() async -> String? { nil }
    func foregroundBlock() async -> String? { nil }
    func openBlock(_ id: String) async {}
}
