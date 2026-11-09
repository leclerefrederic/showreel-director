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
    private final class StatsBox: @unchecked Sendable { var value: RequestStats? }

    /// The text of the final answer. Throws on an API answer that is not retryable, a cut or a busy API that stayed after the retries, a cut answer, or when the model only reads.
    /// A request that was cut (a lost connection, a stream closed early, no content, too long) is asked again up to `AgentLimits.stepRetries` times; one the API refused as busy
    /// (429, 529, a retryable 5xx) up to `AgentLimits.busyRetries` times, after the wait it asks for. Both kinds count on one counter per step, and a request writes nothing, so
    /// asking again has no effect but its cost. `onBusy` is told each time the API said 429 or 529 (a parallel Build lowers its width).
    static func answer(step: String, system: String, prompt: String, store: ProjectStore, skill: URL, transport: MessagesTransport, onBusy: ((Int) -> Void)? = nil) async throws -> String {
        let act = store.activity, version = act.snapshot.build?.version ?? ""
        let label = step == BuildJob.frameStep ? "the frame" : step
        var tries = 0
        while true {
            do {
                let text = try await once(step: step, label: label, version: version, system: system, prompt: prompt, store: store, skill: skill, transport: transport)
                if tries > 0 { act.update { $0.build?.runs[step]?.notice = nil } }
                return text
            }
            catch var e where isCut(e) || e is APIBusy {
                if Task.isCancelled { throw CancellationError() }
                e = labelled(e, label)
                let busy = e as? APIBusy
                if let b = busy, b.status == 429 || b.status == 529 { onBusy?(b.status) }
                guard tries < (busy == nil ? AgentLimits.stepRetries : AgentLimits.busyRetries) else {
                    if tries > 0 { throw Exhausted(underlying: e, tries: tries + 1) }
                    throw e
                }
                tries += 1
                if let b = busy {
                    // the wait the API asked for (or an exponential one); it is outside every request, so no time rule of the transport runs while the app waits
                    let wait = AgentLimits.busyDelay(retryAfter: b.retryAfter, attempt: tries)
                    store.logBuild(version, "Waiting for the API on \(label), retry in \(Int(wait.rounded())) s (\(tries) of \(AgentLimits.busyRetries))", note: "attempt \(tries), kind: the API is busy (\(b.status), \(b.kind))" + (b.retryAfter.map { ", retry-after \(Int($0)) s" } ?? ", no retry-after, exponential wait"))
                    let until = Date().addingTimeInterval(wait)
                    while true {
                        let left = until.timeIntervalSinceNow
                        act.update { $0.build?.runs[step]?.notice = "Waiting for the API, retry in \(max(0, Int(left.rounded(.up)))) s (\(tries) of \(AgentLimits.busyRetries))"; $0.build?.runs[step]?.tokens = 0 }
                        if left <= 0 { break }
                        try await Task.sleep(nanoseconds: UInt64(min(left, 1) * 1_000_000_000))          // a Cancel ends the wait at once
                    }
                } else {
                    let line = (e is ConnectionLost ? "Connection lost on \(label)" : e.localizedDescription) + ", retrying (\(tries) of \(AgentLimits.stepRetries))"
                    act.update { $0.build?.runs[step]?.notice = line; $0.build?.runs[step]?.tokens = 0 }
                    store.logBuild(version, line, note: "attempt \(tries), kind: the request was cut (\(e.localizedDescription))")
                    try await Task.sleep(nanoseconds: UInt64(max(0, AgentLimits.retryDelay) * 1_000_000_000))
                }
            }
        }
    }

    /// The same error with the step it happened on.
    static func labelled(_ e: Error, _ label: String) -> Error {
        if var c = e as? ContentTimeout { c.step = label; return c }
        if var r = e as? RequestTooLong { r.step = label; return r }
        if var l = e as? ConnectionLost { l.step = label; return l }
        return e
    }

    /// A step that stayed cut after its retries: the last cause, and that it was tried again.
    struct Exhausted: Error, LocalizedError {
        let underlying: Error; let tries: Int
        var errorDescription: String? { underlying.localizedDescription + " (tried \(tries) times)" }
    }

    /// One try of the step: the chain of requests (reading files, then the answer), logged in the journal and the app's log.
    private static func once(step: String, label: String, version: String, system: String, prompt: String, store: ProjectStore, skill: URL, transport: MessagesTransport) async throws -> String {
        let act = store.activity
        func phase(_ p: ClapPhase) { act.update { $0.build?.clapPhase = p; $0.build?.runs[step]?.clapPhase = p }; phaseHook?(p) }
        func tokens(_ n: Int) { act.update { b in
            guard var x = b.build else { return }
            x.runs[step]?.tokens = n; x.runs[step]?.lastData = Date()
            x.outputTokens = x.runs.values.reduce(0) { $0 + $1.tokens }
            b.build = x
        } }
        let tools = Tools(project: store.root, skill: skill, ui: SilentUI())
        let defs = Tools.definitions.filter { readTools.contains($0["name"] as? String ?? "") }
        let budgeted = transport as? OutputBudgeted
        defer { act.update { $0.build?.clapPhase = nil; $0.build?.runs[step]?.clapPhase = nil } }          // no request is in flight any more: the panel does not say "Preparing"
        var messages: [[String: Any]] = [["role": "user", "content": prompt]]
        var spent = 0
        for turn in 1...(readingTurns + 2) {
            try Task.checkCancellation()
            act.update { $0.build?.turns = turn; $0.build?.runs[step]?.lastData = Date() }
            phase(.preparing)
            let before = spent, box = Box(), began = Date()
            let stats = StatsBox()
            store.logBuild(version, "Request \(label) started", note: "turn \(turn)")
            let content: [[String: Any]], stop: String
            do { (content, stop) = try await transport.stream(system: [["type": "text", "text": system]], tools: turn <= readingTurns ? defs : [], messages: messages, onText: { _ in },
                                                              onOutput: { n in box.live = n; phase(.writing); tokens(before + n) }, onStats: { stats.value = $0 }) }
            catch {
                act.update { $0.build?.runs[step]?.requestSeconds += Date().timeIntervalSince(began) }
                store.logBuild(version, "Request \(label) failed", note: "turn \(turn), " + (stats.value?.line ?? String(format: "%.0f s", Date().timeIntervalSince(began))) + ": " + error.localizedDescription)
                throw error
            }
            act.update { $0.build?.runs[step]?.requestSeconds += Date().timeIntervalSince(began) }
            spent = before + box.live
            tokens(spent)
            store.logBuild(version, "Request \(label) ended", note: "turn \(turn), " + (stats.value?.line ?? String(format: "%.0f s, stop_reason %@", Date().timeIntervalSince(began), stop)))
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
