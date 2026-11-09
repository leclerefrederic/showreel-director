import Foundation

/// Agent loop on the Messages API: streams text, runs tools, repeats until the model stops.
public final class Agent {
    private let transport: MessagesTransport
    private let tools: Tools
    private let ui: AgentUI
    private let system: [[String: Any]]
    private var messages: [[String: Any]] = []
    private var aborted = false
    private let lock = NSLock()

    /// `transport` defaults to the real API; `history` seeds the conversation (a previous session of the project).
    public init(apiKey: String, model: String, baseURL: String = "", bearer: Bool = false, project: URL, ui: AgentUI,
                transport: MessagesTransport? = nil, history: [[String: Any]] = []) throws {
        let sp = try Skill.systemPrompt(project: project, lang: nil)
        self.transport = transport ?? AnthropicTransport(apiKey: apiKey, model: model, baseURL: baseURL, bearer: bearer)
        self.messages = history
        self.ui = ui
        self.tools = Tools(project: project, skill: sp.root, ui: ui)
        self.tools.sceneTransport = self.transport
        // what the project remembers, as data, from its own files: the same whichever model is used and however often the project was reopened
        var text = sp.text
        if let resume = ProjectResume.block(store: ProjectStore(root: project)) { text += "\n\n" + resume }
        self.system = [["type": "text", "text": text, "cache_control": ["type": "ephemeral"]]]
    }

    /// The system prompt the model is given (for tests).
    public var systemText: String { (system.first?["text"] as? String) ?? "" }

    /// The conversation so far, in the API's format (for tests).
    public var transcript: [[String: Any]] { messages }

    public func abort() { lock.lock(); aborted = true; lock.unlock() }
    private var isAborted: Bool { lock.lock(); defer { lock.unlock() }; return aborted }
    private func resetAbort() { lock.lock(); aborted = false; lock.unlock() }

    /// `context` is a short line about the project's state (step, open gates, file in front of the user), sent with the message. `budget` is what this request may use
    /// (steps and output tokens per answer); the result says how the turn ended, so that a stop that is not a normal end can be told to the user.
    @discardableResult
    public func send(_ text: String, context: String? = nil, budget: AgentBudget = .standard) async throws -> AgentStop {
        resetAbort()
        let first: String = context.map { "[Studio context] \($0)\n\n" + text } ?? text
        messages.append(["role": "user", "content": first])
        let budgeted = transport as? OutputBudgeted
        budgeted?.maxTokens = budget.maxTokens
        defer { budgeted?.maxTokens = AgentBudget.standard.maxTokens }
        var turn = 0
        while turn < budget.maxTurns && !isAborted {
            turn += 1
            pruneImages(keep: 3)
            let (content, stop) = try await transport.stream(system: system, tools: Tools.definitions, messages: messages,
                                                             onText: { [ui] in ui.text($0) })
            // a tool call cut by the output cap is incomplete: it is neither run nor kept in the history
            let kept = stop == "max_tokens" ? content.filter { ($0["type"] as? String) != "tool_use" } : content
            if !kept.isEmpty { messages.append(["role": "assistant", "content": kept]) }
            ui.endText()
            if stop == "max_tokens" { return .tokenLimit(budget.maxTokens) }
            let uses = content.filter { ($0["type"] as? String) == "tool_use" }
            if stop != "tool_use" || uses.isEmpty {
                if stop == "refusal" { return .refused }
                if stop != "end_turn" && stop != "tool_use" && stop != "stop_sequence" { return .other(stop) }
                return content.isEmpty ? .emptyReply : .finished
            }
            var results: [[String: Any]] = []
            for u in uses {
                let name = u["name"] as? String ?? ""
                let input = u["input"] as? [String: Any] ?? [:]
                ui.tool(name, input)
                let out = await tools.run(name, input)
                ui.toolDone(name)
                var content: Any = out.text
                if let img = out.image {
                    let blocks: [[String: Any]] = [
                        ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": img.base64EncodedString()]],
                        ["type": "text", "text": out.text],
                    ]
                    content = blocks
                }
                results.append(["type": "tool_result", "tool_use_id": u["id"] as? String ?? "", "content": content])
            }
            messages.append(["role": "user", "content": results])
        }
        if isAborted { ui.text("\n[stopped]"); ui.endText(); return .cancelled }
        ui.endText()
        return .turnLimit(budget.maxTurns)
    }

    /// Screenshots are heavy: keep the last few in the history and replace older ones by a short note.
    private func pruneImages(keep: Int) {
        var spots: [(Int, Int)] = []
        for (i, m) in messages.enumerated() {
            guard let arr = m["content"] as? [[String: Any]] else { continue }
            for (j, b) in arr.enumerated() {
                if (b["type"] as? String) == "tool_result", b["content"] is [[String: Any]] { spots.append((i, j)) }
            }
        }
        for (i, j) in spots.dropLast(keep) {
            guard var arr = messages[i]["content"] as? [[String: Any]] else { continue }
            arr[j]["content"] = "[earlier screenshot removed to save space]"
            messages[i]["content"] = arr
        }
    }
}
