import XCTest
@testable import ShowreelKit

/// The API as a stub that answers with a script of statuses (with headers), then with a short complete answer.
final class StatusStub: URLProtocol {
    nonisolated(unsafe) static var script: [(status: Int, headers: [String: String], body: String)] = []
    nonisolated(unsafe) static var seen = 0
    static func session(_ s: [(Int, [String: String], String)]) -> URLSession {
        script = s.map { (status: $0.0, headers: $0.1, body: $0.2) }; seen = 0
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [StatusStub.self]
        return URLSession(configuration: c)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let n = Self.seen; Self.seen += 1
        if n < Self.script.count {
            let r = Self.script[n]
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: r.status, httpVersion: nil, headerFields: r.headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(r.body.utf8))
        } else {
            let sse = "data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"```js\\nreturn function render() {};\\n```\"}}\n\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":9}}\n\n"
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "text/event-stream"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(sse.utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class BG2ATests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    var skill: URL { Skill.root()! }

    override func setUp() {
        dir = makeTempDir("bg2a"); store = ProjectStore(root: dir)
        try? store.create(name: "BG", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "validated"))) }
        _ = try? Film.write(version: v, store: store)
        SceneTest.override = { _, _ in SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        AgentLimits.retryDelay = 0; AgentLimits.busyBaseDelay = 0
    }
    override func tearDown() { SceneTest.override = nil; AgentLimits.retryDelay = 3; AgentLimits.busyBaseDelay = 5; try? FileManager.default.removeItem(at: dir) }
    func titles() -> [String] { store.journal.entries().filter { $0.op == "build" }.map { $0.title } }
    func busy(_ status: Int, _ after: TimeInterval? = 0) -> APIBusy { APIBusy(status: status, body: "slow down", retryAfter: after) }

    func testTheWaitIsTheHeadersOrAnExponentialOneWithACeiling() {
        XCTAssertEqual(AgentLimits.busyDelay(retryAfter: 20, attempt: 3), 20)
        XCTAssertEqual(AgentLimits.busyDelay(retryAfter: 9999, attempt: 1), AgentLimits.busyMaxDelay, "a long retry-after is capped")
        AgentLimits.busyBaseDelay = 5
        XCTAssertEqual((1...6).map { AgentLimits.busyDelay(retryAfter: nil, attempt: $0) }, [5, 10, 20, 40, 80, 120])
    }

    func testWhatIsRetryable() {
        for s in [429, 529, 502, 503, 504] { XCTAssertTrue(APIBusy.isRetryable(status: s, shouldRetry: nil), "\(s)") }
        XCTAssertTrue(APIBusy.isRetryable(status: 500, shouldRetry: "true"))
        XCTAssertFalse(APIBusy.isRetryable(status: 500, shouldRetry: nil)); XCTAssertFalse(APIBusy.isRetryable(status: 500, shouldRetry: "false"))
        for s in [400, 401, 403, 404, 413] { XCTAssertFalse(APIBusy.isRetryable(status: s, shouldRetry: "true"), "\(s) never changes") }
    }

    func testTheTransportReadsRetryAfterAndRaisesTheBusyError() async throws {
        for (status, headers) in [(429, ["retry-after": "7"]), (529, [:]), (503, [:]), (500, ["x-should-retry": "true"])] as [(Int, [String: String])] {
            let t = AnthropicTransport(apiKey: "k", model: "m", session: StatusStub.session([(status, headers, "{\"error\":\"x\"}")]))
            do { _ = try await t.stream(system: [], tools: [], messages: [["role": "user", "content": "hi"]], onText: { _ in }); XCTFail("\(status)") }
            catch let e as APIBusy { XCTAssertEqual(e.status, status); XCTAssertEqual(e.retryAfter, headers["retry-after"].flatMap { Double($0) }); XCTAssertTrue(e.localizedDescription.hasPrefix("API \(status):")) }
        }
    }

    func testA400IsNeverRetriedAndKeepsTheAPIsText() async throws {
        let t = AnthropicTransport(apiKey: "k", model: "m", session: StatusStub.session([(400, [:], "{\"error\":{\"message\":\"messages: bad shape\"}}")]))
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: t)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(StatusStub.seen, 1); XCTAssertTrue(stop.message.contains("API 400") && stop.message.contains("messages: bad shape"), stop.message)
    }

    func testA429WithRetryAfterWaitsThenWorksAndTheJournalSaysTheKind() async throws {
        let t = AnthropicTransport(apiKey: "k", model: "m", session: StatusStub.session([(429, ["retry-after": "1"], "{\"error\":\"rate\"}")]))
        var notices: [String] = []
        let watcher = Task { while !Task.isCancelled { if let n = store.activity.snapshot.build?.notice, notices.last != n { notices.append(n) }; try? await Task.sleep(nanoseconds: 100_000_000) } }
        let began = Date()
        let answer = try await SceneWriterProbe.answer(store: store, skill: skill, transport: t)
        watcher.cancel()
        XCTAssertTrue(answer.contains("return function"))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(began), 0.9, "it waited what the API asked")
        XCTAssertTrue(notices.contains { $0.hasPrefix("Waiting for the API, retry in") && $0.hasSuffix("(1 of 5)") }, "\(notices)")
        let line = try XCTUnwrap(store.journal.entries().first { $0.title.hasPrefix("Waiting for the API on S01, retry in 1 s (1 of 5)") })
        XCTAssertTrue(line.note?.contains("429") == true && line.note?.contains("retry-after 1 s") == true && line.note?.contains("kind: the API is busy") == true, line.note ?? "")
    }

    func testA529AndARetryable5xxAreRetriedWithoutAHeader() async throws {
        let t = AnthropicTransport(apiKey: "k", model: "m", session: StatusStub.session([(529, [:], "overloaded"), (503, [:], "down"), (500, ["x-should-retry": "true"], "oops")]))
        _ = try await SceneWriterProbe.answer(store: store, skill: skill, transport: t)
        XCTAssertEqual(StatusStub.seen, 4)
        XCTAssertEqual(titles().filter { $0.hasPrefix("Waiting for the API") }.count, 3, "one journal line per attempt")
    }

    func testBothKindsShareOneCounterPerScene() async throws {
        // two cuts and three busy answers: five retries, the sixth request works
        let m = JobModel(); m.sequence["S02"] = [ConnectionLost(detail: "a"), ConnectionLost(detail: "b"), busy(429), busy(529), busy(429)]
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(out, .completed(written: 3)); XCTAssertEqual(m.asked.filter { $0 == "S02" }.count, 6)
        let notes = store.journal.entries().compactMap { $0.note }.filter { $0.hasPrefix("attempt ") }
        XCTAssertEqual(notes.count, 5); XCTAssertTrue(notes[0].contains("the request was cut") && notes[2].contains("the API is busy"), "\(notes)")
        // a sixth retry is one too many, whatever the kinds
        _ = try Film.write(version: "v2", store: store); _ = try Film.write(version: "v3", store: store)
        let m2 = JobModel(); m2.sequence["S02"] = [busy(429), busy(429), busy(429), busy(429), busy(429), busy(429)]
        let out2 = await BuildJob.run(version: "v2", store: store, skill: skill, transport: m2, options: .init(force: true))
        guard case .stopped(let stop) = out2 else { return XCTFail("\(out2)") }
        XCTAssertEqual(m2.asked.filter { $0 == "S02" }.count, 6); XCTAssertEqual(stop.cause, "api-busy"); XCTAssertTrue(stop.message.contains("tried 6 times"), stop.message)
        // a cut after the two cut retries is not retried even if busy answers left room
        let m3 = JobModel(); m3.sequence["S02"] = [ConnectionLost(detail: "1"), ConnectionLost(detail: "2"), ConnectionLost(detail: "3")]
        let out3 = await BuildJob.run(version: "v3", store: store, skill: skill, transport: m3, options: .init(force: true))
        guard case .stopped(let s3) = out3 else { return XCTFail("\(out3)") }
        XCTAssertEqual(s3.cause, "connection-lost")
    }

    func testACancelEndsTheWaitAtOnce() async throws {
        let m = JobModel(); m.sequence["S01"] = [busy(429, 30)]
        let task = Task { await BuildJob.run(version: v, store: store, skill: skill, transport: m) }
        while store.activity.snapshot.build?.notice == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        let began = Date(); task.cancel()
        let out = await task.value
        guard case .cancelled = out else { return XCTFail("\(out)") }
        XCTAssertLessThan(Date().timeIntervalSince(began), 2)
    }

    func testTheTimeRulesDoNotRunWhileTheAppWaits() async throws {
        let t = AnthropicTransport(apiKey: "k", model: "m", session: StatusStub.session([(429, ["retry-after": "2"], "rate")]))
        t.idleTimeout = 1; t.contentTimeout = 1; t.requestTimeout = 1
        let answer = try await SceneWriterProbe.answer(store: store, skill: skill, transport: t)
        XCTAssertTrue(answer.contains("return function"), "a 2 s wait with 1 s rules: each attempt has its own clock")
    }
}

/// One scene's request through the real step writer, with the activity a Build would have.
enum SceneWriterProbe {
    static func answer(store: ProjectStore, skill: URL, transport: MessagesTransport) async throws -> String {
        store.activity.update { $0.build = .init(version: "v1", phase: .generating); $0.build?.order = ["S01"]; $0.build?.runs["S01"] = SceneRun() }
        return try await SceneGeneration.scene("S01", version: "v1", store: store, skill: skill, transport: transport)
    }
}
