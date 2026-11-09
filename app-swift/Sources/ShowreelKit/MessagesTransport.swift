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
    private let session: URLSession
    private var cap = AgentLimits.modelMaxOutput
    private var report: ((Int) -> Void)?
    private var idle = AgentLimits.idleTimeout
    /// The output cap of the next requests: the model's maximum, lowered once if the API names a lower one.
    public var maxTokens: Int {
        get { lock.lock(); defer { lock.unlock() }; return cap }
        set { lock.lock(); cap = newValue; lock.unlock() }
    }
    public var idleTimeout: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return idle }
        set { lock.lock(); idle = max(1, newValue); lock.unlock() }
    }
    public var onOutput: ((Int) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return report }
        set { lock.lock(); report = newValue; lock.unlock() }
    }

    public init(apiKey: String, model: String, baseURL: String = "", bearer: Bool = false, session: URLSession = .shared) {
        self.session = session
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL.isEmpty ? "https://api.anthropic.com" : baseURL
        self.bearer = bearer
    }

    /// A refusal of the request by the API, kept with its status and body so that the cap can be corrected.
    struct HTTPFailure: Error { let status: Int; let body: String }

    public func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                       onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        let asked = maxTokens
        do { return try await streamOnce(cap: asked, system: system, tools: tools, messages: messages, onText: onText) }
        catch let e as HTTPFailure {
            // the model allows less than asked: the error says how much, and the request is made again once with that
            if e.status == 400, let limit = OutputCap.limit(fromError: e.body, requested: asked) {
                maxTokens = limit
                do { return try await streamOnce(cap: limit, system: system, tools: tools, messages: messages, onText: onText) }
                catch let e2 as HTTPFailure { throw AgentError.msg(Self.describe(e2, requested: limit)) }
            }
            throw AgentError.msg(Self.describe(e, requested: asked))
        }
    }

    /// "API 400 (max_tokens asked: 128000): ..." when the error is about max_tokens, so the cause names the value.
    static func describe(_ e: HTTPFailure, requested: Int) -> String {
        "API \(e.status)" + (e.body.contains("max_tokens") ? " (max_tokens asked: \(requested))" : "") + ": \(clip(e.body, limit: 800))"
    }

    /// The last moment a byte arrived (or the request started), read by the watchdog that cuts a silent stream.
    private final class Pulse: @unchecked Sendable {
        private let lock = NSLock(); private var last = Date(); private(set) var fired = false
        func beat() { lock.lock(); last = Date(); lock.unlock() }
        func silence() -> TimeInterval { lock.lock(); defer { lock.unlock() }; return Date().timeIntervalSince(last) }
        func fire() { lock.lock(); fired = true; lock.unlock() }
        var didFire: Bool { lock.lock(); defer { lock.unlock() }; return fired }
    }

    /// One request, cut with an `IdleTimeout` when no byte arrives for `idleTimeout` seconds (the API's own pings count as bytes).
    private func streamOnce(cap: Int, system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                            onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        let pulse = Pulse(), limit = idleTimeout
        return try await withoutActuallyEscaping(onText) { escaping in
            let text = UncheckedText(escaping)
            let work = Task { try await self.attempt(cap: cap, system: system, tools: tools, messages: messages, pulse: pulse, onText: text.call) }
            let dog = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if pulse.silence() > limit { pulse.fire(); work.cancel(); return }
                }
            }
            defer { dog.cancel() }
            do { return try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() }) }
            catch {
                if pulse.didFire { throw IdleTimeout(seconds: Int(limit)) }
                throw error
            }
        }
    }

    /// `onText` crosses into a task: the agent's callbacks only touch state that tolerates it (they hop to the main queue themselves).
    private struct UncheckedText: @unchecked Sendable { let call: (String) -> Void; init(_ c: @escaping (String) -> Void) { call = c } }

    private func attempt(cap: Int, system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]], pulse: Pulse,
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
            "model": model, "max_tokens": cap, "stream": true,
            "system": system, "tools": tools, "messages": messages,
        ]
        req.httpBody = jsonData(body)

        let (bytes, resp) = try await session.bytes(for: req)
        pulse.beat()
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 {
            var s = ""
            for try await l in bytes.lines { pulse.beat(); s += l + "\n" }
            throw HTTPFailure(status: h.statusCode, body: s)
        }

        var blocks: [Int: [String: Any]] = [:]
        var partial: [Int: String] = [:]
        var stop = "end_turn"
        let report = onOutput
        var chars = 0, sent = 0
        func progress(_ n: Int) { chars += n; if sent == 0 || chars - sent >= 400 { sent = chars; report?(max(1, chars / 4)) } }          // about 4 characters a token, until the API gives the figure
        for try await line in bytes.lines {
            pulse.beat()
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
                    onText(t); progress(t.utf8.count)
                } else if dt == "input_json_delta", let pj = delta["partial_json"] as? String {
                    partial[i] = (partial[i] ?? "") + pj; progress(pj.utf8.count)
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
                if let u = ev["usage"] as? [String: Any], let n = u["output_tokens"] as? Int { report?(n) }
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
