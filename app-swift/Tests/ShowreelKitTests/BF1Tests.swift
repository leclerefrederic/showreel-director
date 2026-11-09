import XCTest
@testable import ShowreelKit

/// A scripted model whose output cap can be set, so that a test sees what the agent asked for.
final class BudgetedTransport: MessagesTransport, OutputBudgeted {
    var maxTokens = AgentLimits.modelMaxOutput
    var onOutput: ((Int) -> Void)?
    var idleTimeout: TimeInterval = 90
    /// What the fake model "writes" in each answer, reported while it is written.
    var writes = 500
    var script: [(content: [[String: Any]], stop: String)]
    private(set) var capsSeen: [Int] = []
    init(_ script: [(content: [[String: Any]], stop: String)]) { self.script = script }
    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]], onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        capsSeen.append(maxTokens)
        onOutput?(writes)
        guard !script.isEmpty else { throw AgentError.msg("script exhausted") }
        return script.removeFirst()
    }
}

/// BF1: when the agent stops without writing the version, the cause is known and said, nothing partial stays and nothing stays frozen.
final class BF1Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUpWithError() throws {
        dir = makeTempDir("bf1")
        store = ProjectStore(root: dir)
        try store.create(name: "BF", conversationLanguage: "en", reelLanguages: ["en"])
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func agent(_ t: MessagesTransport, ui: ScriptedUI = ScriptedUI()) throws -> Agent { try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t) }

    // MARK: how the turn ended

    func testOutputCapStopsWithoutRunningTheCutToolCall() async throws {
        let ui = ScriptedUI()
        let t = BudgetedTransport([([textBlock("Writing."), toolUse("t1", "write_file", ["path": "v1/project.json"])], "max_tokens")])
        let a = try agent(t, ui: ui)
        let stop = try await a.send("go")
        XCTAssertEqual(stop, .tokenLimit(AgentLimits.modelMaxOutput))
        XCTAssertTrue(ui.tools.isEmpty, "a tool call cut in the middle is not run")
        let kept = a.transcript.last?["content"] as? [[String: Any]] ?? []
        XCTAssertFalse(kept.contains { ($0["type"] as? String) == "tool_use" }, "and not kept in the history")
        XCTAssertTrue(try XCTUnwrap(stop.line).contains("maximum output of the model (128000 tokens)"))
    }

    func testEachOtherEndIsNamed() async throws {
        func end(_ content: [[String: Any]], _ stop: String) async throws -> AgentStop {
            try await agent(BudgetedTransport([(content, stop)])).send("go")
        }
        let refused = try await end([], "refusal"), empty = try await end([], "end_turn"), said = try await end([textBlock("Done.")], "end_turn"), odd = try await end([textBlock("x")], "pause_turn")
        XCTAssertEqual(refused, .refused); XCTAssertEqual(empty, .emptyReply); XCTAssertEqual(said, .finished); XCTAssertEqual(odd, .other("pause_turn"))
        XCTAssertNil(AgentStop.finished.line); XCTAssertNil(AgentStop.cancelled.line)
        for s in [AgentStop.refused, .emptyReply, .other("pause_turn"), .turnLimit(3)] { XCTAssertNotNil(s.line) }
    }

    func testTheLoopGuardAndTheAbort() async throws {
        let loop = (0..<(AgentLimits.loopGuardSteps + 5)).map { ([toolUse("t\($0)", "get_state", [:])], "tool_use") }
        let limited = try await agent(BudgetedTransport(loop)).send("go")
        XCTAssertEqual(limited, .turnLimit(AgentLimits.loopGuardSteps))
        XCTAssertTrue(try XCTUnwrap(limited.line).contains("loop guard (1000 steps)"))
        let ui = ScriptedUI()
        let a = try agent(BudgetedTransport(loop), ui: ui)
        ui.onTool = { a.abort() }
        let stopped = try await a.send("go")
        XCTAssertEqual(stopped, .cancelled)
    }

    // MARK: no budget of the product

    func testOneConstantForTheOutputAndNoAdaptiveBudget() async throws {
        XCTAssertEqual(AgentLimits.modelMaxOutput, 128_000)
        XCTAssertEqual(AgentLimits.loopGuardSteps, 1000)
        XCTAssertEqual(AnthropicTransport(apiKey: "k", model: "m").maxTokens, AgentLimits.modelMaxOutput, "the real transport starts from the model's maximum")
        // a question, a Build and a generation all go through send(): the agent never changes the cap, whatever the project holds
        let t = BudgetedTransport([([textBlock("ok")], "end_turn"), ([textBlock("ok")], "end_turn")])
        let a = try agent(t)
        try await a.send("build the 15 scenes")
        try await a.send("hello")
        XCTAssertEqual(t.capsSeen, [AgentLimits.modelMaxOutput, AgentLimits.modelMaxOutput])
        let src = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelKit/BuildStop.swift"), encoding: .utf8)
        XCTAssertFalse(src.contains("AgentBudget"), "no adaptive budget any more")
    }

    func testTheCounterOfStepsAndTokensMovesWhileItRuns() async throws {
        let ui = ScriptedUI()
        let t = BudgetedTransport([([toolUse("t1", "get_state", [:])], "tool_use"), ([toolUse("t2", "get_state", [:])], "tool_use"), ([textBlock("done")], "end_turn")])
        t.writes = 500
        try await agent(t, ui: ui).send("go")
        let seen = ui.progressSeen
        XCTAssertEqual(seen.map { $0.turns }.max(), 3)
        XCTAssertEqual(seen.last?.tokens, 1500, "each answer adds to the total")
        XCTAssertTrue(zip(seen, seen.dropFirst()).allSatisfy { $0.tokens <= $1.tokens }, "never goes back")
        XCTAssertNil(BuildProgress.usageLine(turns: 0, outputTokens: 0))
        XCTAssertEqual(BuildProgress.usageLine(turns: 7, outputTokens: 12400), "Step 7, about 12 400 output tokens")
        var b = ProjectActivity.Build(version: "v1", phase: .generating); b.turns = 3; b.outputTokens = 1500
        XCTAssertEqual(b.turns, 3)
    }

    // MARK: the model allows less than the maximum

    func testTheErrorNamesTheModelsMaximum() {
        let body = #"{"type":"error","error":{"type":"invalid_request_error","message":"max_tokens: 128000 > 64000, which is the maximum allowed number of output tokens for claude-test"}}"#
        XCTAssertEqual(OutputCap.limit(fromError: body, requested: 128_000), 64_000)
        XCTAssertNil(OutputCap.limit(fromError: body, requested: 32_000), "only a value below the one asked counts")
        XCTAssertNil(OutputCap.limit(fromError: "invalid x-api-key", requested: 128_000))
        XCTAssertNil(OutputCap.limit(fromError: #"{"error":{"message":"max_tokens must be positive"}}"#, requested: 128_000), "no number in the error: no guess")
    }

    func testARefusedCapIsAskedAgainOnceWithTheValueTheErrorGives() async throws {
        let stub = CapStub.session(limit: 64_000)
        let t = AnthropicTransport(apiKey: "k", model: "m", session: stub)
        let (content, stop) = try await t.stream(system: [], tools: [], messages: [["role": "user", "content": "hi"]], onText: { _ in })
        XCTAssertEqual(stop, "end_turn"); XCTAssertEqual(content.count, 1)
        XCTAssertEqual(CapStub.asked, [128_000, 64_000], "asked once more, with the model's own maximum")
        XCTAssertEqual(t.maxTokens, 64_000, "and kept for the next requests")
    }

    func testAnErrorThatNamesNoValueIsNotRetriedAndCitesTheValueAsked() async throws {
        let stub = CapStub.session(limit: nil)
        let t = AnthropicTransport(apiKey: "k", model: "m", session: stub)
        do { _ = try await t.stream(system: [], tools: [], messages: [["role": "user", "content": "hi"]], onText: { _ in }); XCTFail("must fail") }
        catch {
            let text = error.localizedDescription
            XCTAssertTrue(text.contains("API 400") && text.contains("max_tokens asked: 128000"), text)
        }
        XCTAssertEqual(CapStub.asked, [128_000], "no second try without a value to try")
    }
}

/// The API replaced by a stub: refuses a max_tokens above `limit` with the real error text, and records each max_tokens it was asked.
final class CapStub: URLProtocol {
    nonisolated(unsafe) static var asked: [Int] = []
    nonisolated(unsafe) static var limit: Int?
    static func session(limit: Int?) -> URLSession {
        asked = []; Self.limit = limit
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [CapStub.self]
        return URLSession(configuration: c)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let s = request.httpBodyStream { s.open(); var buf = [UInt8](repeating: 0, count: 65536); while s.hasBytesAvailable { let n = s.read(&buf, maxLength: buf.count); if n <= 0 { break }; body.append(buf, count: n) }; s.close() }
        let asked = ((try? JSONSerialization.jsonObject(with: body)) as? [String: Any])?["max_tokens"] as? Int ?? 0
        Self.asked.append(asked)
        let refuse = Self.limit.map { asked > $0 } ?? true
        let url = request.url!
        if refuse {
            let msg = Self.limit.map { "max_tokens: \(asked) > \($0), which is the maximum allowed number of output tokens for claude-test" } ?? "max_tokens is not accepted"
            let data = Data(#"{"type":"error","error":{"type":"invalid_request_error","message":"\#(msg)"}}"#.utf8)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        } else {
            let sse = "data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"ok\"}}\n\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":1}}\n\n"
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "text/event-stream"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(sse.utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
