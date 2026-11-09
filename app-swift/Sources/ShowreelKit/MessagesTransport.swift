import Foundation

/// One streamed call to the Messages API. The agent loop only knows this protocol, so tests can script the model.
public protocol MessagesTransport {
    /// Streams text through `onText` and returns the content blocks and the stop reason.
    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String)
}

/// The real transport: the Messages API over URLSession, server-sent events.
public final class AnthropicTransport: MessagesTransport, OutputBudgeted, @unchecked Sendable {   // the only mutable state is `maxTokens`, behind a lock
    let apiKey: String
    let model: String
    let baseURL: String
    let bearer: Bool
    private let lock = NSLock()
    private var cap = AgentBudget.standard.maxTokens
    /// The output cap of the next requests; the agent raises it for a Build and puts it back.
    public var maxTokens: Int {
        get { lock.lock(); defer { lock.unlock() }; return cap }
        set { lock.lock(); cap = newValue; lock.unlock() }
    }

    public init(apiKey: String, model: String, baseURL: String = "", bearer: Bool = false) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL.isEmpty ? "https://api.anthropic.com" : baseURL
        self.bearer = bearer
    }

    public func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                       onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        guard let url = URL(string: baseURL + "/v1/messages") else { throw AgentError.msg("Invalid endpoint URL: \(baseURL)") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if bearer { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        else { req.setValue(apiKey, forHTTPHeaderField: "x-api-key") }
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 300
        let body: [String: Any] = [
            "model": model, "max_tokens": maxTokens, "stream": true,
            "system": system, "tools": tools, "messages": messages,
        ]
        req.httpBody = jsonData(body)

        let (bytes, resp) = try await URLSession.shared.bytes(for: req)
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 {
            var s = ""
            for try await l in bytes.lines { s += l + "\n" }
            throw AgentError.msg("API \(h.statusCode): \(clip(s, limit: 800))")
        }

        var blocks: [Int: [String: Any]] = [:]
        var partial: [Int: String] = [:]
        var stop = "end_turn"
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let d = payload.data(using: .utf8),
                  let ev = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let type = ev["type"] as? String else { continue }
            let i = ev["index"] as? Int ?? 0
            switch type {
            case "content_block_start":
                var b = ev["content_block"] as? [String: Any] ?? [:]
                let bt = b["type"] as? String ?? ""
                if bt == "text" { b["text"] = "" }
                if bt == "tool_use" { partial[i] = "" }
                blocks[i] = b
            case "content_block_delta":
                let delta = ev["delta"] as? [String: Any] ?? [:]
                let dt = delta["type"] as? String ?? ""
                if dt == "text_delta", let t = delta["text"] as? String {
                    var b = blocks[i] ?? ["type": "text"]
                    b["text"] = (b["text"] as? String ?? "") + t
                    blocks[i] = b
                    onText(t)
                } else if dt == "input_json_delta", let pj = delta["partial_json"] as? String {
                    partial[i] = (partial[i] ?? "") + pj
                }
            case "content_block_stop":
                if let s = partial[i], var b = blocks[i] {
                    if s.isEmpty {
                        b["input"] = [String: Any]()
                    } else if let obj = try? JSONSerialization.jsonObject(with: Data(s.utf8)) {
                        b["input"] = obj
                    } else {
                        b["input"] = [String: Any]()
                    }
                    blocks[i] = b
                }
            case "message_delta":
                if let delta = ev["delta"] as? [String: Any], let sr = delta["stop_reason"] as? String { stop = sr }
            case "error":
                let e = ev["error"] as? [String: Any]
                throw AgentError.msg("API error: \(e?["message"] as? String ?? "unknown")")
            default:
                break
            }
        }
        let content = blocks.keys.sorted().compactMap { blocks[$0] }.filter { b in
            !((b["type"] as? String) == "text" && (b["text"] as? String ?? "").isEmpty)
        }
        return (content, stop)
    }
}
