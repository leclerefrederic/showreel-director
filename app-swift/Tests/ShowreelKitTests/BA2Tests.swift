import XCTest
@testable import ShowreelKit

/// The API as a stub that stays alive and says little: only keep-alive pings, a trickle of text, or a stream that closes before the end.
final class LiveStub: URLProtocol {
    enum Mode { case pings, trickle, truncated }
    nonisolated(unsafe) static var mode = Mode.pings
    private let stopped = NSLock(); private var done = false
    private var isDone: Bool { stopped.lock(); defer { stopped.unlock() }; return done }
    static func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [LiveStub.self]
        return URLSession(configuration: c)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "text/event-stream"])!, cacheStoragePolicy: .notAllowed)
        let mode = Self.mode
        let text = "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"x\"}}\n\n"
        if mode == .truncated {
            client?.urlProtocol(self, didLoad: Data("data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n\(text)".utf8))
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        DispatchQueue.global().async { [self] in
            while !isDone {
                client?.urlProtocol(self, didLoad: Data((mode == .pings ? "event: ping\ndata: {\"type\":\"ping\"}\n\n" : text).utf8))
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
    }
    override func stopLoading() { stopped.lock(); done = true; stopped.unlock() }
}

final class BA2Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    var skill: URL { Skill.root()! }
    var clean: SceneTestResult { SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }

    override func setUp() {
        dir = makeTempDir("ba2"); store = ProjectStore(root: dir)
        try? store.create(name: "BA", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "validated"))) }
        _ = try? Film.write(version: v, store: store)
        SceneTest.override = { _, _ in SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        AgentLimits.retryDelay = 0
    }
    override func tearDown() { SceneTest.override = nil; AgentLimits.retryDelay = 3; BuildLog.log = nil; try? FileManager.default.removeItem(at: dir) }
    func exists(_ rel: String) -> Bool { FileManager.default.fileExists(atPath: dir.appendingPathComponent(rel).path) }
    func titles() -> [String] { store.journal.entries().filter { $0.op == "build" }.map { $0.title } }
    func transport(_ mode: LiveStub.Mode) -> AnthropicTransport { LiveStub.mode = mode; return AnthropicTransport(apiKey: "k", model: "m", session: LiveStub.session()) }
    func ask(_ t: AnthropicTransport) async throws { _ = try await t.stream(system: [], tools: [], messages: [["role": "user", "content": "hi"]], onText: { _ in }) }

    // MARK: the time rules

    func testPingsAloneNeverKeepARequestAlive() async throws {
        let t = transport(.pings); t.idleTimeout = 30; t.contentTimeout = 1
        let began = Date()
        do { try await ask(t); XCTFail("must be cut") }
        catch let e as ContentTimeout { XCTAssertTrue(e.pingsOnly); XCTAssertEqual(e.localizedDescription, "No content from the API for 1 s, only keep-alive pings") }
        XCTAssertLessThan(Date().timeIntervalSince(began), 6)
        let r = try XCTUnwrap(t.lastRequest)
        XCTAssertEqual(r.cause, "no-content"); XCTAssertGreaterThan(r.pings, 2); XCTAssertGreaterThan(r.bytes, 0)
    }

    func testARequestThatTrickleTextIsCutAtTheMaximum() async throws {
        let t = transport(.trickle); t.idleTimeout = 30; t.contentTimeout = 30; t.requestTimeout = 2
        do { try await ask(t); XCTFail("must be cut") }
        catch let e as RequestTooLong { XCTAssertEqual(e.localizedDescription, "Request exceeded 2 s") }
        XCTAssertEqual(t.lastRequest?.cause, "too-long")
    }

    func testAStreamClosedBeforeTheEndIsAConnectionLost() async throws {
        let t = transport(.truncated)
        do { try await ask(t); XCTFail("an answer that never said it was complete is not an answer") }
        catch let e as ConnectionLost { XCTAssertTrue(e.localizedDescription.hasPrefix("Connection lost")) }
        XCTAssertEqual(t.lastRequest?.cause, "connection-lost")
    }

    func testCancellingTheTaskStopsARunningRequestAtOnce() async throws {
        let t = transport(.pings); t.idleTimeout = 30; t.contentTimeout = 30
        let task = Task { try await ask(t) }
        try await Task.sleep(nanoseconds: 600_000_000)
        let began = Date(); task.cancel()
        do { try await task.value; XCTFail("cancelled") } catch { XCTAssertFalse(isCut(error), "a cancel is not a cut: it is never asked again") }
        XCTAssertLessThan(Date().timeIntervalSince(began), 2)
        XCTAssertEqual(t.lastRequest?.cause, "cancelled")
    }

    // MARK: asking again

    func testALostConnectionIsAskedAgainAndTheBuildGoesOn() async throws {
        let m = JobModel(); m.flaky["S02"] = (ConnectionLost(detail: "network"), 1)
        var notices: [String] = []
        m.onRequest = { [self] _ in if let n = store.activity.snapshot.build?.notice { notices.append(n) } }
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(out, .completed(written: 3))
        XCTAssertEqual(m.asked, ["reel", "S01", "S02", "S02", "S03"], "S02 was asked twice, and nothing else again")
        XCTAssertTrue(notices.contains("Connection lost on S02, retrying (1 of 2)"), "\(notices)")
        XCTAssertNil(store.activity.snapshot.build?.notice, "the line goes away when the retry works")
        XCTAssertTrue(titles().contains("Connection lost on S02, retrying (1 of 2)"), "a journal line per try")
    }

    func testAfterTheRetriesTheSceneFailsAndNothingIsWritten() async throws {
        let m = JobModel(); m.flaky["S02"] = (ContentTimeout(seconds: 120, pingsOnly: true), 5)
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(m.asked.filter { $0 == "S02" }.count, 1 + AgentLimits.stepRetries)
        XCTAssertEqual(stop.cause, "no-content"); XCTAssertEqual(stop.step, "S02")
        XCTAssertTrue(stop.message.contains("No content from the API for 120 s on S02, only keep-alive pings") && stop.message.contains("tried 3 times"), stop.message)
        XCTAssertFalse(exists("v1/scenes/S02.js"), "a request writes nothing: asking again has no effect but its cost")
        XCTAssertEqual(BuildJob.pending(store), "v1", "the Build finishes on Continue")
    }

    func testAnAnswerOfTheAPIIsNeverAskedAgain() async throws {
        let m = JobModel(); m.failOn["S02"] = AgentError.msg("API 429: slow down")
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(m.asked.filter { $0 == "S02" }.count, 1)
    }

    // MARK: the journal and the log

    func testTheJournalSaysTheStartTheRequestsAndTheEnd() async throws {
        let log = makeTempDir("ba2log").appendingPathComponent("build.log"); BuildLog.log = DragLog(url: log)
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel())
        let t = titles()
        for line in ["Build v1 started", "Request the frame started", "Request S02 started", "Request S02 ended", "Build v1 ended: completed"] { XCTAssertTrue(t.contains(line), "\(line) in \(t)") }
        let ended = try XCTUnwrap(store.journal.entries().first { $0.title == "Request S02 ended" })
        XCTAssertTrue(ended.note?.contains("turn 1") == true)
        BuildLog.log?.flush()
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertTrue(text.contains("Build v1 started") && text.contains("Request S03 ended"))
    }

    // MARK: states

    func testACancelDuringTheLastTestNeverGoesOnToTheAssembly() async throws {
        SceneTest.override = { id, _ in if id == "S03" { try? await Task.sleep(nanoseconds: 3_000_000_000) }; return SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        let task = Task { await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel()) }
        while store.activity.snapshot.build?.runs["S03"]?.state != .testing { try await Task.sleep(nanoseconds: 50_000_000) }
        task.cancel()
        let out = await task.value
        guard case .cancelled = out else { return XCTFail("a Build cancelled in its last test is cancelled, not completed: \(out)") }
    }

    func testWhileATestRunsNoRequestIsSaidToBeInFlight() async throws {
        var seen: [(ClapPhase?, SceneRun.State?)] = []
        SceneTest.override = { [self] id, _ in seen.append((store.activity.snapshot.build?.clapPhase, store.activity.snapshot.build?.runs[id]?.state)); return clean }
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel())
        XCTAssertFalse(seen.isEmpty)
        for (phase, state) in seen { XCTAssertNil(phase, "Testing, not Preparing"); XCTAssertEqual(state, .testing) }
    }

    func testTheWarningsOfTheScenesAlreadyWrittenSurviveAStop() async throws {
        SceneTest.override = { id, _ in SceneTestResult(codeErrors: [], warnings: id == "S01" ? ["S01|/d t=1: text outside stage"] : [], codeCount: 0, warningCount: id == "S01" ? 1 : 0) }
        let m = JobModel(); m.failOn["S02"] = AgentError.msg("API 500")
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        guard case .stopped = out else { return XCTFail("\(out)") }
        XCTAssertEqual(store.activity.snapshot.build?.layoutWarnings["S01"], ["S01|/d t=1: text outside stage"])
    }

    func testABrokenFrameStopsTheBuildBeforeAnyScene() async throws {
        SceneTest.override = { id, _ in id == BuildJob.frameStep ? SceneTestResult(codeErrors: ["reel.js: boom"], warnings: [], codeCount: 1, warningCount: 0) : SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        let m = JobModel()
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(m.asked, ["reel"], "one request, not two for each scene")
        XCTAssertEqual(stop.step, "reel"); XCTAssertTrue(stop.message.contains("the frame failed its own test (reel.js: boom)"), stop.message)
        XCTAssertFalse(exists("v1/reel.js") || exists("v1/project.json"), "so that a Build that continues writes the frame again")
        SceneTest.override = { _, _ in SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        let again = JobModel()
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: again)
        XCTAssertEqual(again.asked.first, "reel")
    }

    // MARK: Shell

    func testAProcessThatIgnoresTermIsKilledAndTheCallReturns() async throws {
        let began = Date()
        let r = await Shell.run("trap '' TERM; sleep 30", in: dir, timeout: 1)
        XCTAssertNotNil(r); XCTAssertEqual(r?.timedOut, true)
        XCTAssertLessThan(Date().timeIntervalSince(began), 10)
    }

    func testCancellingTheTaskKillsTheProcess() async throws {
        let task = Task { await Shell.run("sleep 29", in: dir, timeout: 60) }
        try await Task.sleep(nanoseconds: 700_000_000)
        let began = Date(); task.cancel()
        _ = await task.value
        XCTAssertLessThan(Date().timeIntervalSince(began), 5)
    }

    // MARK: Generate, and the one rule for "tested"

    func testGenerateTestsAndRecordsTheSceneLikeABuildDoes() async throws {
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel()); store.activity.update { $0.build = nil }
        SceneModules.markTested(version: v, scene: "S02", ok: true, store: store)
        let r = try await SceneGeneration.generateTested(["S02"], version: v, store: store, skill: skill, transport: JobModel(), overwriting: ["S02"])
        XCTAssertNotNil(r.tests["S02"] ?? nil)
        XCTAssertTrue(SceneModules.isTested(version: v, scene: "S02", store: store), "it passed its test: recorded")
        SceneTest.override = { _, _ in SceneTestResult(codeErrors: ["boom"], warnings: [], codeCount: 1, warningCount: 0) }
        let other = JobModel(); other.sceneText = { step, _ in "return function render() { /* \(step) other */ };" }          // other bytes: the old mark does not carry over
        _ = try await SceneGeneration.generateTested(["S03"], version: v, store: store, skill: skill, transport: other, overwriting: ["S03"])
        XCTAssertFalse(SceneModules.isTested(version: v, scene: "S03", store: store), "a file that failed its test is not recorded as tested")
    }

    func testAGenerationStartedByClapCanBeCancelled() async throws {
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel()); store.activity.update { $0.build = nil }
        let t = transport(.pings); t.idleTimeout = 60; t.contentTimeout = 60; t.requestTimeout = 60
        let task = Task { try await SceneGeneration.generate(["S01"], version: v, store: store, skill: skill, transport: t, overwriting: ["S01"]) }
        while store.activity.snapshot.build == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        try await Task.sleep(nanoseconds: 500_000_000)
        let began = Date()
        XCTAssertTrue(store.activity.cancelRunning())
        do { _ = try await task.value; XCTFail("cancelled") } catch { XCTAssertTrue(error is CancellationError, "\(error)") }
        XCTAssertLessThan(Date().timeIntervalSince(began), 3)
        XCTAssertNil(store.activity.snapshot.build)
    }

    func testAnUntestedSceneIsTestedAgainWithNoRequestAndReusedWhenItPasses() async throws {
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel())
        var book = SceneModules.loadBook(store); book.versions["v1"]?["S02"]?.tested = nil; try SceneModules.save(book, store)     // what S06 was in the owner's project
        _ = try Film.write(version: "v2", store: store)
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.retest, ["S02": "v1"]); XCTAssertEqual(p.reasons["S02"], "never tested: tested now, no request"); XCTAssertFalse(p.unchanged)
        XCTAssertEqual(BuildJob.card(p, store: store, skill: skill, resuming: false).title, "Build v2: 0 scenes will be written, 3 reused unchanged")
        let m = JobModel()
        let out = await BuildJob.run(version: "v2", store: store, skill: skill, transport: m)
        XCTAssertEqual(out, .completed(written: 3))
        XCTAssertEqual(m.asked, [], "no request")
        XCTAssertTrue(SceneModules.isTested(version: "v2", scene: "S02", store: store))
    }

    func testAnUntestedSceneThatFailsItsTestIsWrittenAndTheReasonIsTheBuildBeforeWhenItWasNotReliable() async throws {
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel())
        var book = SceneModules.loadBook(store); book.versions["v1"]?["S02"]?.tested = nil; try SceneModules.save(book, store)
        try SceneModules.recordResult(version: "v1", ok: false, store: store)
        _ = try Film.write(version: "v2", store: store)
        XCTAssertEqual(BuildJob.plan(version: "v2", store: store).reasons["S02"], "the previous build was not reliable: tested again, no request")
        SceneTest.override = { id, _ in id == "S02" ? SceneTestResult(codeErrors: ["boom"], warnings: [], codeCount: 1, warningCount: 0) : SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        let m = JobModel()
        _ = await BuildJob.run(version: "v2", store: store, skill: skill, transport: m)
        XCTAssertEqual(m.asked.first, "S02", "its test failed: it is written")
    }

    func testEachSceneGetsItsOwnTrueReason() throws {
        let f = try XCTUnwrap(store.loadShowreel())
        let s1 = try XCTUnwrap(f.scenes.first { $0.id == "S01" })
        XCTAssertEqual(BuildJob.decide(s1, version: v, in: f, store: store).reason, "never written")
        XCTAssertEqual(BuildJob.decide(s1, version: v, in: f, store: store, force: true).reason, "rewritten on request")
        XCTAssertEqual(BuildJob.decide(s1, version: v, in: f, store: store, skip: ["S01"]).act, .skipped)
    }

    // MARK: the empty folders

    func testAFolderThatHoldsOnlyWhatTheAppWroteIsRemoved() throws {
        let fm = FileManager.default
        for n in ["v2", "v3", "v4"] { _ = try Film.write(version: n, store: store) }
        try fm.createDirectory(at: dir.appendingPathComponent("v3/scenes"), withIntermediateDirectories: true)          // empty scenes/
        try fm.createDirectory(at: dir.appendingPathComponent("v4/scenes"), withIntermediateDirectories: true)
        try "return function(){}".write(to: dir.appendingPathComponent("v4/scenes/S01.js"), atomically: true, encoding: .utf8)     // paid work
        try fm.createDirectory(at: dir.appendingPathComponent("v5"), withIntermediateDirectories: true)
        try "{}".write(to: dir.appendingPathComponent("v5/project.json"), atomically: true, encoding: .utf8)
        let gone = Versions.pruneHusks(store, keep: "v1")
        XCTAssertEqual(gone, ["v2", "v3"])
        XCTAssertTrue(exists("v1/film.json"), "the version a Build could continue stays")
        XCTAssertTrue(exists("v4/scenes/S01.js") && exists("v5/project.json"))
        XCTAssertEqual(Versions.next(store), "v6")
    }
}
