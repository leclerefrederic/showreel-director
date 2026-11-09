import XCTest
@testable import ShowreelKit

/// A model for a Build: answers the frame request with its two blocks and each scene request with a file, or fails/stalls on a scene as scripted.
final class JobModel: MessagesTransport, OutputBudgeted, @unchecked Sendable {
    var maxTokens = AgentLimits.modelMaxOutput
    var onOutput: ((Int) -> Void)?
    var idleTimeout: TimeInterval = 90
    private(set) var asked: [String] = []          // the step of each request: "reel" or the scene ID
    var failOn: [String: Error] = [:]
    var readFirst = false                          // answer the first request of each step with a read_file call
    var onRequest: ((String) -> Void)?
    private var read: Set<String> = []
    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]], onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        let p = (messages.first?["content"] as? String) ?? ""
        let step = p.range(of: #"scenes/(S\d+)\.js"#, options: .regularExpression).map { String(p[$0].dropFirst(7).dropLast(3)) } ?? BuildJob.frameStep
        onRequest?(step)
        if messages.count == 1 { asked.append(step) }
        if let e = failOn[step] { throw e }
        onOutput?(400)
        if readFirst, !read.contains(step) { read.insert(step); return ([toolUse("r-\(step)", "read_file", ["path": "references/engine.md", "limit": 5])], "tool_use") }
        if step == BuildJob.frameStep { return ([["type": "text", "text": "```json\n{\"title\": \"T\", \"tokens\": {}, \"fonts\": []}\n```\n```js\nreturn { palette: { bg: '#000', fg: '#fff', accent: '#f00', accent2: '#0f0' }, show: {} };\n```"]], "end_turn") }
        return ([["type": "text", "text": "```js\nconst { clamp } = SR;\nreturn function render(g, lt, c) { g.fillText('\(step)', 40, 40 + SRK.slam + clamp(lt, 0, 1)); };\n```"]], "end_turn")
    }
}

final class BG1Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    var skill: URL { Skill.root()! }

    override func setUp() {
        dir = makeTempDir("bg1"); store = ProjectStore(root: dir)
        try? store.create(name: "BG", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "validated"))) }
        _ = try? Film.write(version: v, store: store)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    func exists(_ rel: String) -> Bool { FileManager.default.fileExists(atPath: dir.appendingPathComponent(rel).path) }

    // MARK: the contract comes from the skill

    func testTheContractIsReadFromTheSkillAndCoversEveryKitFunction() throws {
        let text = SceneContract.text(skill: skill)
        let kit = try String(contentsOf: skill.appendingPathComponent("engine/kit.js"), encoding: .utf8)
        let line = try XCTUnwrap(kit.components(separatedBy: "\n").first { $0.contains("G.SRK = {") })
        let names = line.drop { $0 != "{" }.dropFirst().prefix { $0 != "}" }.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertGreaterThan(names.count, 10)
        for n in names { XCTAssertTrue(text.contains("SRK.\(n)"), "the contract does not name SRK.\(n): it diverged from kit.js") }
        let tmpl = try String(contentsOf: skill.appendingPathComponent("engine/scene.template.js"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(text.contains(tmpl), "the template is given as it is")
        XCTAssertTrue(text.contains("Contract of a scene file"), "the section of engine.md")
        XCTAssertTrue(text.contains("SRB.draw"), "the backgrounds' API")
        XCTAssertLessThan(text.count, 24_000, "a compact contract, not the engine")
    }

    func testChangingTheSkillChangesTheContract() throws {
        let tmp = makeTempDir("skillcopy"); defer { try? FileManager.default.removeItem(at: tmp) }
        for f in ["references/engine.md", "engine/kit.js", "engine/backgrounds.js", "engine/scene.template.js"] {
            try FileManager.default.createDirectory(at: tmp.appendingPathComponent((f as NSString).deletingLastPathComponent), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: skill.appendingPathComponent(f), to: tmp.appendingPathComponent(f))
        }
        let k = tmp.appendingPathComponent("engine/kit.js")
        try (try String(contentsOf: k, encoding: .utf8)).replacingOccurrences(of: "SRK.hash(n, seed)", with: "SRK.NEWHELPER(x)").write(to: k, atomically: true, encoding: .utf8)
        XCTAssertTrue(SceneContract.text(skill: tmp).contains("SRK.NEWHELPER"))
        XCTAssertFalse(SceneContract.text(skill: skill).contains("SRK.NEWHELPER"))
    }

    func testTheScenePromptCarriesTheContractTheMusicTheNeighboursAndTheReadingNote() throws {
        try "return function render(g, lt, c) { SRK.slam(); SRK.slam(); SRK.shake(); };\n".write(to: { try? FileManager.default.createDirectory(at: dir.appendingPathComponent("v1/scenes"), withIntermediateDirectories: true); return dir.appendingPathComponent("v1/scenes/S01.js") }(), atomically: true, encoding: .utf8)
        let p = SceneGeneration.prompt(scene: "S02", version: v, store: store, skill: skill)
        XCTAssertTrue(p.contains("SRK.slam(g, str, x, y, size, color, bt, startBeat, o)"), "the kit's signatures, from kit.js")
        XCTAssertTrue(p.contains("Previous scene: S01") && p.contains("Look this scene uses"))
        XCTAssertTrue(p.contains("S01: \u{201C}One\u{201D}") && p.contains("SRK.slam, SRK.shake"), "a summary of the scene already written, computed from its file")
        XCTAssertFalse(p.contains("- S02:"), "never the scene being written")
        XCTAssertTrue(SceneGeneration.system.contains("not normally necessary"))
        XCTAssertNil(SceneContract.music(scene: "S02", store: store), "no analysed track: no music line")
    }

    func testTheSummaryIsEmptyWhileNothingIsWritten() { XCTAssertEqual(SceneContract.summary(version: v, store: store, excluding: "S01"), "") }

    // MARK: the plan

    func testThePlanWritesEverySceneAndKeepsWhatIsUpToDate() async throws {
        var p = BuildJob.plan(version: v, store: store)
        XCTAssertEqual(p.write, ["S01", "S02", "S03"]); XCTAssertTrue(p.needsFrame); XCTAssertEqual(p.calls, 4)
        let m = JobModel()
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        p = BuildJob.plan(version: v, store: store)
        XCTAssertEqual(p.write, []); XCTAssertFalse(p.needsFrame); XCTAssertEqual(p.keep, ["S01", "S02", "S03"]); XCTAssertEqual(p.calls, 0)
    }

    func testALockedSceneIsCarriedOverFromAnEarlierVersionNotWritten() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v1/scenes"), withIntermediateDirectories: true)
        try "return function render() { /* the locked one */ };\n".write(to: dir.appendingPathComponent("v1/scenes/S02.js"), atomically: true, encoding: .utf8)
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        _ = try Film.write(version: "v2", store: store)
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.carry, ["S02": "v1"]); XCTAssertEqual(p.write, ["S01", "S03"])
    }

    func testTheCardSaysTheCallsAndAnEstimate() throws {
        let p = BuildJob.plan(version: v, store: store)
        let c = BuildJob.card(p, store: store, skill: skill, resuming: false)
        XCTAssertEqual(c.title, "Build v1: 4 calls, one scene at a time")
        XCTAssertTrue(c.changes.contains { $0.after.contains("4 model calls") && $0.after.contains("(an estimate)") })
        XCTAssertTrue(c.changes.contains { $0.before.contains("assembled with no AI") })
    }

    // MARK: running, states, stopping, continuing

    func testARunWritesEachFileThenTheStatesAreDoneAndTheMarkerStays() async throws {
        let m = JobModel()
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(out, .completed(written: 3))
        XCTAssertEqual(m.asked, ["reel", "S01", "S02", "S03"], "the frame first, then one request per scene")
        for f in ["project.json", "reel.js", "scenes/S01.js", "scenes/S02.js", "scenes/S03.js"] { XCTAssertTrue(exists("v1/\(f)"), f) }
        let b = try XCTUnwrap(store.activity.snapshot.build)
        XCTAssertEqual(b.order, ["reel", "S01", "S02", "S03"]); XCTAssertEqual(b.done, 3)
        XCTAssertTrue(b.runs.values.allSatisfy { $0.state == .done && $0.tokens == 400 }, "tokens counted per step")
        XCTAssertEqual(b.outputTokens, 1600, "and in total")
        XCTAssertEqual(BuildJob.pending(store), "v1", "until the app has assembled and tested it")
        BuildJob.finish(store); XCTAssertNil(BuildJob.pending(store))
        let proj = try JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("v1/project.json"))) as? [String: Any]
        XCTAssertEqual(proj?["main"] as? String, "main.js")
    }

    func testTheStateOfEachSceneIsVisibleWhileItRuns() async throws {
        let m = JobModel()
        var seen: [String: [SceneRun.State]] = [:]
        m.onRequest = { step in
            let b = self.store.activity.snapshot.build
            if step == "S02" { seen["S02"] = ["S01", "S02", "S03"].compactMap { b?.runs[$0]?.state } }
        }
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(seen["S02"], [.done, .writing, .waiting])
    }

    func testPhasesReadingPreparingWriting() async throws {
        let m = JobModel(); m.readFirst = true
        var phases: [ClapPhase] = []
        SceneWriter.phaseHook = { phases.append($0) }
        defer { SceneWriter.phaseHook = nil }
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(Array(phases.prefix(5)), [.preparing, .writing, .reading, .preparing, .writing], "wait for the first token (Preparing), tokens (Writing), a read tool (Reading), then again")
        XCTAssertEqual(store.activity.snapshot.build?.clapPhase, .preparing)
    }

    func testASceneThatFailsKeepsTheOthersAndSaysWhichAndWhy() async throws {
        let m = JobModel(); m.failOn["S02"] = IdleTimeout(seconds: 90)
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(stop.step, "S02"); XCTAssertEqual(stop.cause, "idle-timeout"); XCTAssertEqual(stop.written, 1)
        XCTAssertTrue(stop.message.contains("No answer from the API for 90 s") && stop.message.contains("S02"), stop.message)
        XCTAssertTrue(exists("v1/scenes/S01.js")); XCTAssertFalse(exists("v1/scenes/S02.js")); XCTAssertFalse(exists("v1/scenes/S03.js"))
        XCTAssertEqual(store.activity.snapshot.build?.runs["S02"]?.state, .failed)
        XCTAssertEqual(store.activity.snapshot.build?.runs["S03"]?.state, .waiting)
        let line = try XCTUnwrap(store.journal.entries().last(where: { $0.op == "build" }))
        XCTAssertEqual(line.title, "Build v1 stopped at S02: idle-timeout")
        // continue: only the missing ones are asked, S01 is not written again
        let again = JobModel()
        let out2 = await BuildJob.run(version: v, store: store, skill: skill, transport: again)
        XCTAssertEqual(out2, .completed(written: 3)); XCTAssertEqual(again.asked, ["S02", "S03"], "the frame and S01 are kept")
    }

    func testContinuingCanLeaveTheFailedSceneAside() async throws {
        let m = JobModel(); m.failOn["S02"] = AgentError.msg("API 500: boom")
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        let again = JobModel()
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: again, skip: ["S02"])
        XCTAssertEqual(again.asked, ["S03"]); XCTAssertEqual(out, .completed(written: 2))
        XCTAssertFalse(exists("v1/scenes/S02.js"), "an empty frame until it is generated")
        XCTAssertEqual(store.activity.snapshot.build?.runs["S02"]?.state, .failed)
    }

    func testTheFrameFailingStopsBeforeAnyScene() async throws {
        let m = JobModel(); m.failOn["reel"] = AgentError.msg("API 429: slow down")
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(stop.step, "reel"); XCTAssertEqual(m.asked, ["reel"]); XCTAssertTrue(stop.message.contains("API 429"))
    }

    func testCancellingStopsAtOnceAndKeepsWhatIsWritten() async throws {
        let m = JobModel(); m.failOn["S02"] = CancellationError()
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(out, .cancelled(written: 1))
        XCTAssertTrue(exists("v1/scenes/S01.js")); XCTAssertEqual(store.activity.snapshot.build?.runs["S02"]?.state, .waiting)
        XCTAssertEqual(BuildJob.pending(store), "v1")
    }

    func testStartOverRemovesWhatTheBuildWroteAndKeepsTheMontage() async throws {
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel())
        BuildJob.startOver(version: v, store: store)
        XCTAssertTrue(exists("v1/film.json"))
        for f in ["project.json", "reel.js", "scenes"] { XCTAssertFalse(exists("v1/\(f)"), f) }
        XCTAssertEqual(BuildJob.plan(version: v, store: store).calls, 4)
        XCTAssertEqual(store.journal.entries().last?.title, "Build v1: started over")
    }

    func testTheFrameAnswerIsTwoBlocks() {
        XCTAssertNotNil(BuildJob.extractFrame("```json\n{\"title\": \"x\"}\n```\n```js\nreturn {};\n```"))
        XCTAssertNil(BuildJob.extractFrame("```json\n{\"nope\": 1}\n```\n```js\nreturn {};\n```"), "no title")
        XCTAssertNil(BuildJob.extractFrame("```json\n{\"title\": \"x\"}\n```"), "no reel.js")
    }

    func testTheStepsLines() {
        XCTAssertEqual(BuildProgress.tokensLine(12400), "12 400 tokens"); XCTAssertNil(BuildProgress.tokensLine(0))
        XCTAssertEqual(AgentLimits.idleTimeout, 90)
    }

    // MARK: the stream

    func testASilentStreamIsCutWithTheTimeoutMessage() async throws {
        let t = AnthropicTransport(apiKey: "k", model: "m", session: SilentStub.session())
        t.idleTimeout = 1
        let began = Date()
        do { _ = try await t.stream(system: [], tools: [], messages: [["role": "user", "content": "hi"]], onText: { _ in }); XCTFail("must be cut") }
        catch let e as IdleTimeout { XCTAssertEqual(e.seconds, 1); XCTAssertEqual(e.localizedDescription, "No answer from the API for 1 s") }
        XCTAssertLessThan(Date().timeIntervalSince(began), 6)
    }

    func testToolArgumentsAreCountedAndTheFirstBytesGivePreparingThenWriting() async throws {
        let t = AnthropicTransport(apiKey: "k", model: "m", session: SilentStub.session(sse: SilentStub.toolStream(chars: 2000)))
        var seen: [Int] = []
        t.onOutput = { seen.append($0) }
        _ = try await t.stream(system: [], tools: [], messages: [["role": "user", "content": "hi"]], onText: { _ in })
        XCTAssertGreaterThan(seen.count, 2); XCTAssertGreaterThan(seen.first ?? 0, 0, "the first bytes already report")
        XCTAssertTrue(seen.contains { $0 >= 400 }, "2000 characters of a tool's script argument count as about 500 tokens")
        XCTAssertEqual(seen.last, 777, "and the API's own figure replaces the estimate at the end")
    }
}

/// The API as a stub: either never says a byte (the request hangs) or streams a tool call with a long argument.
final class SilentStub: URLProtocol {
    nonisolated(unsafe) static var body: String?
    static func session(sse: String? = nil) -> URLSession {
        body = sse
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [SilentStub.self]
        return URLSession(configuration: c)
    }
    static func toolStream(chars: Int) -> String {
        var s = "data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"tool_use\",\"id\":\"t\",\"name\":\"write_file\",\"input\":{}}}\n\n"
        for _ in 0..<(chars / 100) { s += "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"\(String(repeating: "a", count: 100))\"}}\n\n" }
        s += "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":777}}\n\n"
        return s
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let body = Self.body else { return }          // nothing at all: the request hangs
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "text/event-stream"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
