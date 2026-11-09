import CryptoKit
import XCTest
@testable import ShowreelKit

final class BG2BTests: XCTestCase {
    var dirs: [URL] = []
    var skill: URL { Skill.root()! }
    let ids = ["S01", "S02", "S03", "S04", "S05", "S06"]

    override func setUp() { SceneTest.override = { _, _ in SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }; AgentLimits.retryDelay = 0; AgentLimits.busyBaseDelay = 0 }
    override func tearDown() { SceneTest.override = nil; AgentLimits.retryDelay = 3; AgentLimits.busyBaseDelay = 5; dirs.forEach { try? FileManager.default.removeItem(at: $0) } }

    func project(scenes: Int = 6) -> ProjectStore {
        let d = makeTempDir("bg2b"); dirs.append(d)
        let st = ProjectStore(root: d)
        try? st.create(name: "BG2", conversationLanguage: "en", reelLanguages: ["en"])
        for n in 0..<scenes { try? st.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Scene \(n + 1)", feeling: "calm \(n + 1)", status: "validated"))) }
        _ = try? Film.write(version: "v1", store: st)
        return st
    }
    func exists(_ st: ProjectStore, _ rel: String) -> Bool { FileManager.default.fileExists(atPath: st.root.appendingPathComponent(rel).path) }
    func titles(_ st: ProjectStore) -> [String] { st.journal.entries().filter { $0.op == "build" }.map { $0.title } }

    // MARK: the window

    func testNeverMoreThanTheChosenNumberInFlightAndEveryRecordSurvives() async throws {
        for w in 1...4 {
            let st = project(); let m = JobModel(); for i in ids { m.pause[i] = 0.25 }
            let out = await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: w)
            XCTAssertEqual(out, .completed(written: 6), "width \(w)")
            let sceneMax = w                                  // the frame is asked alone first: its request is never in flight with a scene's
            XCTAssertLessThanOrEqual(m.maxInFlight, sceneMax, "width \(w)"); XCTAssertEqual(m.maxInFlight, sceneMax, "the window is really filled at width \(w)")
            XCTAssertEqual(m.overlapped, [], "no two requests for the same file")
            for i in ids { XCTAssertTrue(SceneModules.isTested(version: "v1", scene: i, store: st), "\(i) record kept at width \(w): the records are written one at a time") }
            XCTAssertEqual(m.asked.first, "reel", "the frame is written first, alone")
        }
    }

    func testTheFilmIsTheSameWhateverTheOrderTheFilesArrivedIn() async throws {
        var hashes: [String] = []
        for w in 1...4 {
            let st = project(); let m = JobModel()
            // the first scenes are the slowest: with several at once the files arrive in another order
            for (n, i) in ids.enumerated() { m.pause[i] = 0.06 * Double(ids.count - n) }
            _ = await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: w)
            let r = await Shell.run("python3 '\(skill.path)/scripts/assemble.py' '\(st.root.path)/v1'", in: st.root, timeout: 60)
            guard let r, r.status == 0 else { throw XCTSkip("python3 is not available here") }
            let main = try String(contentsOf: st.root.appendingPathComponent("v1/main.js"), encoding: .utf8)
            hashes.append(SceneModules.hex(SHA256.hash(data: Data(main.utf8))))
        }
        XCTAssertEqual(Set(hashes).count, 1, "the same film at 1, 2, 3 and 4 at once")
    }

    // MARK: failures

    func testOneSceneFailingAmongThreeInFlightLetsTheOthersFinishAndContinueResumes() async throws {
        let st = project(); let m = JobModel(); m.failOn["S02"] = AgentError.msg("API 500: boom")
        m.pause["S01"] = 0.4; m.pause["S03"] = 0.4
        let out = await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: 3)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(stop.step, "S02"); XCTAssertTrue(stop.message.contains("API 500: boom"))
        XCTAssertTrue(exists(st, "v1/scenes/S01.js") && exists(st, "v1/scenes/S03.js"), "the scenes in flight were not stopped")
        XCTAssertFalse(exists(st, "v1/scenes/S02.js")); XCTAssertEqual(m.asked.filter { ["S04", "S05", "S06"].contains($0) }, [], "after a hard failure no new scene starts")
        XCTAssertEqual(BuildJob.pending(st), "v1", "offers Continue")
        let again = JobModel()
        let out2 = await BuildJob.run(version: "v1", store: st, skill: skill, transport: again, width: 3)
        XCTAssertEqual(out2, .completed(written: 6)); XCTAssertEqual(Set(again.asked), ["S02", "S04", "S05", "S06"], "S01 and S03 are kept, the frame too")
    }

    func testAFailedTestOfOneSceneDoesNotStopTheOthers() async throws {
        let st = project()
        SceneTest.override = { id, _ in id == "S02" ? SceneTestResult(codeErrors: ["boom"], warnings: [], codeCount: 1, warningCount: 0) : SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        let out = await BuildJob.run(version: "v1", store: st, skill: skill, transport: JobModel(), width: 3)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(stop.failedTests, ["S02"]); XCTAssertEqual(Set(ids.filter { exists(st, "v1/scenes/\($0).js") }), Set(ids).subtracting(["S02"]))
    }

    // MARK: the API limiting requests

    func testA429LowersTheNumberAtOnceByOneAndNeverBelowOne() async throws {
        let st = project(); let m = JobModel()
        for i in ["S01", "S02", "S03"] { m.sequence[i] = [APIBusy(status: 429, body: "limit", retryAfter: 0)] }          // the three in flight meet it together
        let out = await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: 3)
        XCTAssertEqual(out, .completed(written: 6))
        XCTAssertEqual(titles(st).filter { $0.hasPrefix("Lowered to") }, ["Lowered to 2 scenes at once: the API is limiting requests"], "once, not three times")
        XCTAssertEqual(st.activity.snapshot.build?.width, 2); XCTAssertEqual(st.activity.snapshot.build?.widthNotice, "Lowered to 2 scenes at once: the API is limiting requests")
        // at 1 there is nowhere to go
        let st1 = project(); let m1 = JobModel(); m1.sequence["S01"] = [APIBusy(status: 529, body: "overloaded", retryAfter: 0)]
        _ = await BuildJob.run(version: "v1", store: st1, skill: skill, transport: m1, width: 1)
        XCTAssertEqual(titles(st1).filter { $0.hasPrefix("Lowered to") }, []); XCTAssertEqual(st1.activity.snapshot.build?.width, 1)
    }

    func testAGateNeverGoesBelowOneAndWaitsBetweenLowerings() {
        let g = WidthGate(2)
        XCTAssertEqual(g.lower(), 1); XCTAssertNil(g.lower()); XCTAssertEqual(g.current, 1)
        WidthGate.debounce = 0; defer { WidthGate.debounce = 15 }
        let g2 = WidthGate(4); XCTAssertEqual(g2.lower(), 3); XCTAssertEqual(g2.lower(), 2); XCTAssertEqual(g2.lower(), 1); XCTAssertNil(g2.lower())
    }

    // MARK: Cancel

    func testCancelWithThreeRequestsInFlightStopsThemAllKeepsWhatIsWrittenAndContinueFinishes() async throws {
        let st = project(); let m = JobModel(); for i in ids { m.pause[i] = 5 }; m.pause["S01"] = 0.1                    // S01 is done before the Cancel
        let task = Task { await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: 3) }
        while m.inFlightNow.count < 3 { try await Task.sleep(nanoseconds: 50_000_000) }
        let began = Date(); task.cancel()
        let out = await task.value
        guard case .cancelled(let n) = out else { return XCTFail("\(out)") }
        XCTAssertLessThan(Date().timeIntervalSince(began), 2); XCTAssertLessThanOrEqual(n, 3)
        XCTAssertEqual(m.inFlightNow, [], "every request in flight was stopped")
        XCTAssertTrue(titles(st).contains("Build v1 ended: cancelled"))
        XCTAssertEqual(BuildJob.pending(st), "v1")
        let done = ids.filter { exists(st, "v1/scenes/\($0).js") }
        let again = JobModel()
        let out2 = await BuildJob.run(version: "v1", store: st, skill: skill, transport: again, width: 3)
        XCTAssertEqual(out2, .completed(written: 6))
        XCTAssertTrue(Set(again.asked).isDisjoint(with: Set(done)), "what was written and tested is kept")
    }

    // MARK: what every request carries, and the journal

    func testEveryRequestCarriesTheStoryboardOneLinePerScene() async throws {
        let st = project(); let m = JobModel()
        _ = await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: 3)
        XCTAssertEqual(m.storyboardSeen.count, 7); XCTAssertTrue(m.storyboardSeen.values.allSatisfy { $0 })
        let p = try XCTUnwrap(m.prompts["S03"]?.first)
        for i in ids { XCTAssertTrue(p.contains("- \(i)"), i) }
        XCTAssertTrue(p.contains("- S03 (this scene):") && p.contains("mood: calm 4") && p.contains("passage into the next scene:") && p.contains("none (last scene)"))
        XCTAssertTrue(p.contains("Scenes already written in this version"), "the summary of the finished scenes still exists")
    }

    func testTheJournalHasOneLineForEachRequest() async throws {
        let st = project(); let m = JobModel(); m.sequence["S02"] = [ConnectionLost(detail: "x")]
        _ = await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: 3)
        let t = titles(st)
        for i in ids { XCTAssertEqual(t.filter { $0 == "Request \(i) started" }.count, m.asked.filter { $0 == i }.count, i) }
        XCTAssertEqual(t.filter { $0 == "Request S02 started" }.count, 2); XCTAssertTrue(t.contains("Connection lost on S02, retrying (1 of 2)"))
    }

    // MARK: the estimate and what a Build measured

    func testTheEstimateUsesTheMeasuredSpeedWhenThereIsOneAndTheDefaultOtherwise() throws {
        let st = project()
        let p = BuildJob.plan(version: "v1", store: st)
        func time(_ w: Int) -> Change? { BuildJob.card(p, store: st, skill: skill, resuming: false, width: w).changes.first { $0.label == "Time" } }
        XCTAssertTrue(time(3)?.after.contains("125 output tokens a second, the default until a Build measures it") == true, time(3)?.after ?? "")
        XCTAssertNil(BuildStats.last(st))
        BuildStats.write(.init(tokensPerSecond: 250, sceneTokens: 3000, width: 3, real: 100, generation: 250, scenes: 6), version: "v1", store: st)
        XCTAssertEqual(BuildStats.last(st)?.tokensPerSecond, 250)
        XCTAssertTrue(time(3)?.after.contains("250 output tokens a second, measured on the last Build") == true, time(3)?.after ?? "")
        let slow = BuildStats.estimate(scenes: 6, frame: true, width: 1, store: st).seconds, fast = BuildStats.estimate(scenes: 6, frame: true, width: 3, store: st).seconds
        XCTAssertLessThan(fast, slow); XCTAssertEqual(slow, 7 * 3000 / 250.0, accuracy: 0.01, "the frame and six scenes, one at a time")
        XCTAssertEqual(fast, 3000 / 250.0 * 3, accuracy: 0.01, "the frame alone, then two waves of three")
        XCTAssertEqual(BuildStats.estimate(scenes: 0, frame: false, width: 3, store: st).seconds, 0)
    }

    func testABuildRecordsItsSpeedItsRealTimeAndTheTimeAddedUp() async throws {
        let st = project(scenes: 3); let m = JobModel(); for i in ["S01", "S02", "S03"] { m.pause[i] = 1.1 }
        _ = await BuildJob.run(version: "v1", store: st, skill: skill, transport: m, width: 3)
        let r = try XCTUnwrap(BuildStats.last(st))
        XCTAssertEqual(r.width, 3); XCTAssertEqual(r.scenes, 3); XCTAssertGreaterThan(r.tokensPerSecond, 0)
        XCTAssertGreaterThan(r.generation, r.real, "three scenes at once: the time added up is more than the real time")
        XCTAssertEqual(r.sceneTokens, 400)
    }
}

