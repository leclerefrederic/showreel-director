import Foundation

/// Agent loop on the Messages API: streams text, runs tools, repeats until the model stops.
final class Agent {
    private let apiKey: String
    private let model: String
    private let baseURL: String
    private let bearer: Bool
    private let tools: Tools
    private let ui: AgentUI
    private let system: [[String: Any]]
    private var messages: [[String: Any]] = []
    private var aborted = false
    private let lock = NSLock()

    init(apiKey: String, model: String, baseURL: String = "", bearer: Bool = false, project: URL, ui: AgentUI) throws {
        let sp = try Skill.systemPrompt(project: project, lang: nil)
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL.isEmpty ? "https://api.anthropic.com" : baseURL
        self.bearer = bearer
        self.ui = ui
        self.tools = Tools(project: project, skill: sp.root, ui: ui)
        self.system = [["type": "text", "text": sp.text, "cache_control": ["type": "ephemeral"]]]
    }

    func abort() { lock.lock(); aborted = true; lock.unlock() }
    private var isAborted: Bool { lock.lock(); defer { lock.unlock() }; return aborted }
    private func resetAbort() { lock.lock(); aborted = false; lock.unlock() }

    func send(_ text: String) async throws {
        resetAbort()
        messages.append(["role": "user", "content": text])
        var turn = 0
        while turn < 60 && !isAborted {
            turn += 1
            pruneImages(keep: 3)
            let (content, stop) = try await streamOnce()
            if !content.isEmpty { messages.append(["role": "assistant", "content": content]) }
            ui.endText()
            let uses = content.filter { ($0["type"] as? String) == "tool_use" }
            if stop != "tool_use" || uses.isEmpty { return }
            var results: [[String: Any]] = []
            for u in uses {
                let name = u["name"] as? String ?? ""
                let input = u["input"] as? [String: Any] ?? [:]
                ui.tool(name, input)
                let out = await tools.run(name, input)
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
        ui.text("\n[stopped]")
        ui.endText()
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

    private func streamOnce() async throws -> ([[String: Any]], String) {
        guard let url = URL(string: baseURL + "/v1/messages") else { throw AgentError.msg("Invalid endpoint URL: \(baseURL)") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if bearer { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        else { req.setValue(apiKey, forHTTPHeaderField: "x-api-key") }
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 300
        let body: [String: Any] = [
            "model": model, "max_tokens": 8000, "stream": true,
            "system": system, "tools": Tools.definitions, "messages": messages,
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
                    ui.text(t)
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
