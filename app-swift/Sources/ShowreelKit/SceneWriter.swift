import Foundation

/// The agent interface for a request that has no window: the read tools never ask the user anything.
final class SilentUI: AgentUI {
    func text(_ t: String) {}
    func endText() {}
    func tool(_ name: String, _ input: [String: Any]) {}
    func show(_ url: String, _ title: String) {}
    func screenshot(javascript: String?, waitMs: Int) async -> Data? { nil }
    func ask(_ questions: [[String: Any]]) async -> [String] { [] }
}

/// One step of a Build or a generation: a request that may read files (read_file, list_dir) and ends with an answer. It reports the phase Clap is in and the output tokens
/// as they come, into the project's activity under the step's id, so that the panel can show them.
public enum SceneWriter {
    static let readTools: Set<String> = ["read_file", "list_dir"]
    /// After this many answers the tools are taken away: the model must write.
    static let readingTurns = 8

    /// Called with each phase, for the tests (the panel reads the activity).
    nonisolated(unsafe) static var phaseHook: ((ClapPhase) -> Void)?

    private final class Box: @unchecked Sendable { var live = 0 }

    /// The text of the final answer. Throws on an API error, an `IdleTimeout`, a cut answer, or when the model only reads.
    static func answer(step: String, system: String, prompt: String, store: ProjectStore, skill: URL, transport: MessagesTransport) async throws -> String {
        let act = store.activity
        func phase(_ p: ClapPhase) { act.update { $0.build?.clapPhase = p }; phaseHook?(p) }
        func tokens(_ n: Int) { act.update { b in
            guard var x = b.build else { return }
            x.runs[step]?.tokens = n
            x.outputTokens = x.runs.values.reduce(0) { $0 + $1.tokens }
            b.build = x
        } }
        let tools = Tools(project: store.root, skill: skill, ui: SilentUI())
        let defs = Tools.definitions.filter { readTools.contains($0["name"] as? String ?? "") }
        let budgeted = transport as? OutputBudgeted
        defer { budgeted?.onOutput = nil; phase(.preparing) }
        var messages: [[String: Any]] = [["role": "user", "content": prompt]]
        var spent = 0
        for turn in 1...(readingTurns + 2) {
            try Task.checkCancellation()
            act.update { $0.build?.turns = turn }
            phase(.preparing)
            let before = spent, box = Box()
            budgeted?.onOutput = { n in box.live = n; phase(.writing); tokens(before + n) }
            let (content, stop) = try await transport.stream(system: [["type": "text", "text": system]], tools: turn <= readingTurns ? defs : [], messages: messages, onText: { _ in })
            budgeted?.onOutput = nil
            spent = before + box.live
            tokens(spent)
            if stop == "max_tokens" { throw AgentError.msg("the answer reached the maximum output of the model (\(budgeted?.maxTokens ?? AgentLimits.modelMaxOutput) tokens) before the file was complete") }
            let uses = content.filter { ($0["type"] as? String) == "tool_use" }
            if stop == "tool_use", !uses.isEmpty {
                messages.append(["role": "assistant", "content": content])
                phase(.reading)
                var results: [[String: Any]] = []
                for u in uses {
                    let out = await tools.run(u["name"] as? String ?? "", u["input"] as? [String: Any] ?? [:])
                    results.append(["type": "tool_result", "tool_use_id": u["id"] as? String ?? "", "content": out.text])
                }
                messages.append(["role": "user", "content": results])
                continue
            }
            return content.compactMap { ($0["type"] as? String) == "text" ? $0["text"] as? String : nil }.joined()
        }
        throw AgentError.msg("Clap kept reading and did not write the file")
    }
}
