import XCTest
@testable import ShowreelKit

/// A scripted model whose output cap can be set, so that a test sees what the agent asked for.
final class BudgetedTransport: MessagesTransport, OutputBudgeted {
    var maxTokens = 8000
    var script: [(content: [[String: Any]], stop: String)]
    private(set) var capsSeen: [Int] = []
    init(_ script: [(content: [[String: Any]], stop: String)]) { self.script = script }
    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]], onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        capsSeen.append(maxTokens)
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
        XCTAssertEqual(stop, .tokenLimit(8000))
        XCTAssertTrue(ui.tools.isEmpty, "a tool call cut in the middle is not run")
        let kept = a.transcript.last?["content"] as? [[String: Any]] ?? []
        XCTAssertFalse(kept.contains { ($0["type"] as? String) == "tool_use" }, "and not kept in the history")
        XCTAssertTrue(try XCTUnwrap(stop.line).contains("8000 tokens"))
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

    func testTurnLimitAndAbort() async throws {
        let loop = (0..<5).map { ([toolUse("t\($0)", "get_state", [:])], "tool_use") }
        let limited = try await agent(BudgetedTransport(loop)).send("go", budget: AgentBudget(maxTurns: 2, maxTokens: 8000))
        XCTAssertEqual(limited, .turnLimit(2))
        let ui = ScriptedUI()
        let a = try agent(BudgetedTransport(loop), ui: ui)
        ui.onTool = { a.abort() }
        let stopped = try await a.send("go")
        XCTAssertEqual(stopped, .cancelled)
    }

    // MARK: the room a Build gets

    func testBuildBudgetGrowsWithTheScenesUpToTheCeiling() {
        XCTAssertEqual(AgentBudget.build(scenes: 0), .standard)
        XCTAssertEqual(AgentBudget.build(scenes: 2).maxTokens, 11200)
        XCTAssertEqual(AgentBudget.build(scenes: 15).maxTokens, AgentBudget.ceilingTokens)
        XCTAssertEqual(AgentBudget.build(scenes: 15).maxTurns, 100)
        XCTAssertEqual(AgentBudget.build(scenes: 500), AgentBudget(maxTurns: AgentBudget.ceilingTurns, maxTokens: AgentBudget.ceilingTokens), "never unlimited")
    }

    func testTheAgentAsksForTheCapAndPutsItBack() async throws {
        let t = BudgetedTransport([([textBlock("ok")], "end_turn"), ([textBlock("ok")], "end_turn")])
        let a = try agent(t)
        try await a.send("build", budget: .build(scenes: 15))
        XCTAssertEqual(t.capsSeen, [32000]); XCTAssertEqual(t.maxTokens, 8000, "the next question is back to the usual cap")
        try await a.send("hello")
        XCTAssertEqual(t.capsSeen.last, 8000)
    }

    // MARK: what the Build says and leaves

    private func stubVersion(_ v: String, wrote: [String] = []) throws {
        try Film.write(version: v, store: store)
        for f in wrote {
            let u = dir.appendingPathComponent("\(v)/\(f)")
            try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "x".write(to: u, atomically: true, encoding: .utf8)
        }
    }

    func testEachCauseHasItsOwnMessageAndWay() throws {
        let cases: [(AgentStop, String?, String, BuildFailure.Remedy, String)] = [
            (.tokenLimit(8000), nil, "token-limit", .oneByOne, "output limit (8000 tokens)"),
            (.turnLimit(60), nil, "turn-limit", .oneByOne, "60 steps"),
            (.refused, nil, "refused", .tryAgain, "declined"),
            (.emptyReply, nil, "empty-reply", .tryAgain, "without writing anything"),
            (.finished, nil, "no-files", .tryAgain, "in the chat"),
            (.finished, "API 429: rate limited", "api-error", .tryAgain, "API 429"),
        ]
        for (stop, failure, cause, remedy, text) in cases {
            try stubVersion("v1")
            let r = BuildStop.conclude(version: "v1", store: store, stop: stop, failure: failure)
            XCTAssertEqual(r.cause, cause); XCTAssertEqual(r.remedy, remedy)
            XCTAssertTrue(r.message.contains(text), "\(cause): \(r.message)")
            XCTAssertTrue(r.message.hasPrefix("Clap did not write v1."))
            XCTAssertFalse(r.message.contains("see what it said"), "never sends the user to a silent chat")
            XCTAssertEqual(remedy == .oneByOne, r.message.contains("Generate the scenes one by one"))
            let line = try XCTUnwrap(store.journal.entries().last)
            XCTAssertEqual(line.op, "build"); XCTAssertEqual(line.title, "Build v1 stopped: \(cause)"); XCTAssertEqual(line.note, r.message)
        }
    }

    func testNothingPartialAndNothingFrozen() throws {
        try stubVersion("v1")
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        XCTAssertTrue(store.activity.snapshot.isBuilding)
        let r = BuildStop.conclude(version: "v1", store: store, stop: .tokenLimit(8000), failure: nil)
        XCTAssertFalse(store.activity.snapshot.isBuilding, "the project is editable again")
        XCTAssertNil(store.activity.snapshot.build)
        XCTAssertTrue(r.kept.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1").path), "the stub the app wrote is removed")
        XCTAssertEqual(Versions.next(store), "v1", "so that the next Build reuses the name")
        XCTAssertTrue(r.message.contains("Nothing was written in v1."))
        for f in ["project.json", "main.js", "dist"] { XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1/\(f)").path)) }
    }

    func testWhatClapDidWriteIsKeptAndSaid() throws {
        try stubVersion("v1", wrote: ["scenes/S01.js", "scenes/S02.js"])
        let r = BuildStop.conclude(version: "v1", store: store, stop: .tokenLimit(8000), failure: nil)
        XCTAssertEqual(r.kept, ["scenes/S01.js", "scenes/S02.js"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1/scenes/S01.js").path), "no deletion of Clap's files")
        XCTAssertTrue(r.message.contains("2 files Clap wrote stay in v1, not built."))
        XCTAssertFalse(Versions.list(store).contains("v1"))
    }

    // MARK: the retry

    func testOneByOnePromptAsksForOneFilePerAnswer() throws {
        try stubVersion("v1")
        XCTAssertFalse(BuildRunner.prompt(version: "v1", store: store).contains("one per answer"))
        XCTAssertTrue(BuildRunner.prompt(version: "v1", store: store, oneByOne: true).contains("one per answer"))
    }
}
