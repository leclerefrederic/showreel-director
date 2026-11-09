import Foundation

/// One streamed call to the Messages API. The agent loop only knows this protocol, so tests can script the model.
public protocol MessagesTransport {
    /// Streams text through `onText` and returns the content blocks and the stop reason.
    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String)
    /// The same, for requests that run at the same time: the output tokens and what the request did are reported to this call's own closures, never to state the transport shares.
    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                onText: (String) -> Void, onOutput: ((Int) -> Void)?, onStats: ((RequestStats) -> Void)?) async throws -> (content: [[String: Any]], stop: String)
}

extension MessagesTransport {
    /// A transport that does not report (a test's) just streams.
    public func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                       onText: (String) -> Void, onOutput: ((Int) -> Void)?, onStats: ((RequestStats) -> Void)?) async throws -> (content: [[String: Any]], stop: String) {
        try await stream(system: system, tools: tools, messages: messages, onText: onText)
    }
}

/// The real transport: the Messages API over URLSession, server-sent events.
public final class AnthropicTransport: MessagesTransport, OutputBudgeted, RequestWatched, @unchecked Sendable {   // the only mutable state is `maxTokens`, behind a lock
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
    private var contentLimit = AgentLimits.contentTimeout
    private var requestLimit = AgentLimits.requestTimeout
    private var last: RequestStats?
    /// Seconds without text or a tool argument (pings do not count) before the request is cut.
    public var contentTimeout: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return contentLimit }
        set { lock.lock(); contentLimit = max(1, newValue); lock.unlock() }
    }
    /// The longest one request may take.
    public var requestTimeout: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return requestLimit }
        set { lock.lock(); requestLimit = max(1, newValue); lock.unlock() }
    }
    /// What the last request did, whether it ended well or was cut.
    public var lastRequest: RequestStats? { lock.lock(); defer { lock.unlock() }; return last }
    fileprivate func finished(_ call: Call, _ r: RequestStats) { lock.lock(); last = r; lock.unlock(); call.onStats?(r) }
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

    /// What one call reports to: its own closures, so that requests at the same time do not mix their figures.
    struct Call: @unchecked Sendable { let onOutput: ((Int) -> Void)?; let onStats: ((RequestStats) -> Void)? }

    /// A refusal of the request by the API, kept with its status and body so that the cap can be corrected.
    struct HTTPFailure: Error { let status: Int; let body: String; var retryAfter: TimeInterval? = nil; var shouldRetry: String? = nil }

    public func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                       onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        try await stream(system: system, tools: tools, messages: messages, onText: onText, onOutput: nil, onStats: nil)
    }

    public func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                       onText: (String) -> Void, onOutput: ((Int) -> Void)?, onStats: ((RequestStats) -> Void)?) async throws -> (content: [[String: Any]], stop: String) {
        let asked = maxTokens
        let call = Call(onOutput: onOutput ?? self.onOutput, onStats: onStats)
        do { return try await streamOnce(cap: asked, call: call, system: system, tools: tools, messages: messages, onText: onText) }
        catch let e as HTTPFailure {
            // the model allows less than asked: the error says how much, and the request is made again once with that
            if e.status == 400, let limit = OutputCap.limit(fromError: e.body, requested: asked) {
                maxTokens = limit
                do { return try await streamOnce(cap: limit, call: call, system: system, tools: tools, messages: messages, onText: onText) }
                catch let e2 as HTTPFailure {
                    if APIBusy.isRetryable(status: e2.status, shouldRetry: e2.shouldRetry) { throw APIBusy(status: e2.status, body: e2.body, retryAfter: e2.retryAfter) }
                    throw AgentError.msg(Self.describe(e2, requested: limit))
                }
            }
            if APIBusy.isRetryable(status: e.status, shouldRetry: e.shouldRetry) { throw APIBusy(status: e.status, body: e.body, retryAfter: e.retryAfter) }
            throw AgentError.msg(Self.describe(e, requested: asked))
        }
    }

    /// "API 400 (max_tokens asked: 128000): ..." when the error is about max_tokens, so the cause names the value.
    static func describe(_ e: HTTPFailure, requested: Int) -> String {
        "API \(e.status)" + (e.body.contains("max_tokens") ? " (max_tokens asked: \(requested))" : "") + ": \(clip(e.body, limit: 800))"
    }

    /// What the watchdog reads, and what the request records for the log: the last byte, the last content, the pings, the bytes.
    private final class Pulse: @unchecked Sendable {
        enum Cut { case idle, noContent, tooLong }
        private let lock = NSLock(); private let began = Date(); private var last = Date(), lastContent = Date()
        private(set) var cut: Cut?; private var pingCount = 0, byteCount = 0, tokens = 0, stop: String?
        func beat(bytes: Int = 0) { lock.lock(); last = Date(); byteCount += bytes; lock.unlock() }
        func content() { lock.lock(); lastContent = Date(); lock.unlock() }
        func ping() { lock.lock(); pingCount += 1; lock.unlock() }
        func note(tokens t: Int? = nil, stop s: String? = nil) { lock.lock(); if let t { tokens = t }; if let s { stop = s }; lock.unlock() }
        /// The rule that is broken now, if any; the first one that is stays.
        func check(idle: TimeInterval, content c: TimeInterval, total: TimeInterval) -> Cut? {
            lock.lock(); defer { lock.unlock() }
            if cut != nil { return cut }
            let now = Date()
            if now.timeIntervalSince(began) > total { cut = .tooLong }
            else if now.timeIntervalSince(lastContent) > c { cut = .noContent }
            else if now.timeIntervalSince(last) > idle { cut = .idle }
            return cut
        }
        var didFire: Bool { lock.lock(); defer { lock.unlock() }; return cut != nil }
        var sawPings: Bool { lock.lock(); defer { lock.unlock() }; return pingCount > 0 }
        var sawStop: Bool { lock.lock(); defer { lock.unlock() }; return stop != nil }
        func stats(cause: String) -> RequestStats { lock.lock(); defer { lock.unlock() }; return RequestStats(seconds: Date().timeIntervalSince(began), bytes: byteCount, pings: pingCount, contentTokens: tokens, stopReason: stop, cause: cause) }
    }

    /// One request, cut with an error that says why: nothing for `idleTimeout` seconds (pings count), no text or tool argument for `contentTimeout` (pings do not count),
    /// or more than `requestTimeout` in all. A dropped connection or a stream closed before the end is a `ConnectionLost`.
    private func streamOnce(cap: Int, call: Call, system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                            onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        let pulse = Pulse(), idle = idleTimeout, noContent = contentTimeout, total = requestTimeout
        return try await withoutActuallyEscaping(onText) { escaping in
            let text = UncheckedText(escaping)
            let work = Task { try await self.attempt(cap: cap, call: call, system: system, tools: tools, messages: messages, pulse: pulse, onText: text.call) }
            let dog = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    if pulse.check(idle: idle, content: noContent, total: total) != nil { work.cancel(); return }
                }
            }
            defer { dog.cancel() }
            do {
                let r = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
                finished(call, pulse.stats(cause: "ok"))
                return r
            } catch {
                if let c = pulse.cut {
                    switch c {
                    case .idle: finished(call, pulse.stats(cause: "idle")); throw IdleTimeout(seconds: Int(idle))
                    case .noContent: finished(call, pulse.stats(cause: "no-content")); throw ContentTimeout(seconds: Int(noContent), pingsOnly: pulse.sawPings)
                    case .tooLong: finished(call, pulse.stats(cause: "too-long")); throw RequestTooLong(seconds: Int(total))
                    }
                }
                if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { finished(call, pulse.stats(cause: "cancelled")); throw error }
                if let u = error as? URLError { finished(call, pulse.stats(cause: "connection-lost")); throw ConnectionLost(detail: u.localizedDescription) }
                if let h = error as? HTTPFailure { finished(call, pulse.stats(cause: "http \(h.status)")) } else if error is ConnectionLost { finished(call, pulse.stats(cause: "connection-lost")) } else { finished(call, pulse.stats(cause: "error")) }
                throw error
            }
        }
    }

    /// `onText` crosses into a task: the agent's callbacks only touch state that tolerates it (they hop to the main queue themselves).
    private struct UncheckedText: @unchecked Sendable { let call: (String) -> Void; init(_ c: @escaping (String) -> Void) { call = c } }

    private func attempt(cap: Int, call: Call, system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]], pulse: Pulse,
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
            for try await l in bytes.lines { pulse.beat(bytes: l.utf8.count + 1); s += l + "\n" }
            throw HTTPFailure(status: h.statusCode, body: s, retryAfter: h.value(forHTTPHeaderField: "retry-after").flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }, shouldRetry: h.value(forHTTPHeaderField: "x-should-retry"))
        }

        var blocks: [Int: [String: Any]] = [:]
        var partial: [Int: String] = [:]
        var stop = "end_turn"
        let report = call.onOutput
        var chars = 0, sent = 0
        func progress(_ n: Int) { chars += n; if sent == 0 || chars - sent >= 400 { sent = chars; report?(max(1, chars / 4)) } }          // about 4 characters a token, until the API gives the figure
        for try await line in bytes.lines {
            pulse.beat(bytes: line.utf8.count + 1)
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let d = payload.data(using: .utf8),
                  let ev = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let type = ev["type"] as? String else { continue }
            let i = ev["index"] as? Int ?? 0
            switch type {
            case "ping": pulse.ping()
            case "content_block_start":
                var b = ev["content_block"] as? [String: Any] ?? [:]
                let bt = b["type"] as? String ?? ""
                if bt == "text" { b["text"] = "" }
                if bt == "tool_use" { partial[i] = "" }
                blocks[i] = b
            case "content_block_delta":
                let delta = ev["delta"] as? [String: Any] ?? [:]
                let dt = delta["type"] as? String ?? ""
                if ["text_delta", "input_json_delta", "thinking_delta"].contains(dt) { pulse.content() }          // only content resets the no-content rule: pings and the rest do not
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
                if let delta = ev["delta"] as? [String: Any], let sr = delta["stop_reason"] as? String { stop = sr; pulse.note(stop: sr) }
                if let u = ev["usage"] as? [String: Any], let n = u["output_tokens"] as? Int { report?(n); pulse.note(tokens: n) }
            case "message_stop":
                if !pulse.sawStop { pulse.note(stop: stop) }
            case "error":
                let e = ev["error"] as? [String: Any]
                throw AgentError.msg("API error: \(e?["message"] as? String ?? "unknown")")
            default:
                break
            }
        }
        guard pulse.sawStop else { throw ConnectionLost(detail: "the stream closed before the answer was complete") }
        let content = blocks.keys.sorted().compactMap { blocks[$0] }.filter { b in
            !((b["type"] as? String) == "text" && (b["text"] as? String ?? "").isEmpty)
        }
        return (content, stop)
    }
}
