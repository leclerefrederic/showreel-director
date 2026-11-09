import XCTest
@testable import ShowreelKit

/// BG1d: a Build writes only the scenes that changed; the others are taken over from the version before, with no request.
final class BG1dTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    var skill: URL { Skill.root()! }

    override func setUp() async throws {
        dir = makeTempDir("bg1d"); store = ProjectStore(root: dir)
        try store.create(name: "BG", conversationLanguage: "en", reelLanguages: ["en"])
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        for t in ["One", "Two", "Three"] { try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "validated"))) }
        SceneTest.override = { _, _ in SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0) }
        try await firstBuild()
    }
    override func tearDown() { SceneTest.override = nil; try? FileManager.default.removeItem(at: dir) }

    /// v1: everything written, as a first Build does. The activity is cleared as the app does after the test of the film.
    func firstBuild() async throws {
        _ = try Film.write(version: "v1", store: store)
        let out = await BuildJob.run(version: "v1", store: store, skill: skill, transport: JobModel())
        XCTAssertEqual(out, .completed(written: 3))
        store.activity.update { $0.build = nil }; BuildJob.finish(store)
    }
    func next() throws { _ = try Film.write(version: "v2", store: store) }
    func bytes(_ rel: String) -> Data? { try? Data(contentsOf: dir.appendingPathComponent(rel)) }
    func exists(_ rel: String) -> Bool { FileManager.default.fileExists(atPath: dir.appendingPathComponent(rel).path) }
    func run(_ m: JobModel, options: BuildJob.Options? = nil) async -> JobOutcome {
        let o = await BuildJob.run(version: "v2", store: store, skill: skill, transport: m, options: options)
        store.activity.update { $0.build = nil }; BuildJob.finish(store); return o
    }
    func titles() -> [String] { store.journal.entries().filter { $0.op == "build" }.map { $0.title } }

    func testNothingChangedMeansNoRequestAndTheFilesAreCopiedAsTheyAre() async throws {
        try next()
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.write, []); XCTAssertEqual(p.reuse.count, 3); XCTAssertEqual(p.frameFrom, "v1"); XCTAssertFalse(p.needsFrame); XCTAssertTrue(p.unchanged)
        let c = BuildJob.card(p, store: store, skill: skill, resuming: false)
        XCTAssertEqual(c.title, "Nothing changed since the last build")
        XCTAssertFalse(c.changes.contains { $0.before.contains("Cost") || $0.before == "Cost" }, "no cost to announce")
        let before = titles().count
        let m = JobModel(); let out = await run(m)
        XCTAssertEqual(out, .completed(written: 3)); XCTAssertEqual(m.asked, [], "not one request")
        for f in ["scenes/S01.js", "scenes/S02.js", "scenes/S03.js", "project.json", "reel.js"] { XCTAssertEqual(bytes("v2/\(f)"), bytes("v1/\(f)"), "\(f) is the same bytes") }
        let now = Array(titles().dropFirst(before))
        XCTAssertTrue(now.contains("S01 reused from v1") && now.contains("Frame (project.json, reel.js) reused from v1"))
        XCTAssertFalse(now.contains { $0.hasSuffix(" written") && $0.hasPrefix("S0") }, "no scene was written")
    }

    func testAChangedSceneIsTheOnlyOneWrittenAndTheCardSaysTheNumbers() async throws {
        try store.apply(.scene(id: "S02", SceneEdit(text: "Two, changed")))
        try next()
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.write, ["S02"]); XCTAssertEqual(p.reuse.keys.sorted(), ["S01", "S03"]); XCTAssertEqual(p.reasons["S02"], "its content, look or music changed")
        let c = BuildJob.card(p, store: store, skill: skill, resuming: false)
        XCTAssertEqual(c.title, "Build v2: 1 scene will be written, 2 reused unchanged")
        XCTAssertTrue(c.changes.contains { $0.after.contains("1 model call,") && $0.after.contains("about 1 min") }, "the cost and time are those of the written scene only")
        let before = titles().count
        let m = JobModel(); m.sceneText = { step, _ in "return function render() { /* \(step) new */ };" }; _ = await run(m)
        XCTAssertEqual(m.asked, ["S02"], "one request")
        XCTAssertEqual(bytes("v2/scenes/S01.js"), bytes("v1/scenes/S01.js")); XCTAssertNotEqual(bytes("v2/scenes/S02.js"), bytes("v1/scenes/S02.js"))
        let now = Array(titles().dropFirst(before))
        XCTAssertTrue(now.contains("S02 written") && now.contains("S01 reused from v1") && now.contains("S03 reused from v1"), "\(now)")
        // the next Build after that one: all three are up to date again
        _ = try Film.write(version: "v3", store: store)
        XCTAssertTrue(BuildJob.plan(version: "v3", store: store).unchanged)
    }

    func testAScenesThatWasNeverWrittenOrFailedItsTestIsWritten() async throws {
        try FileManager.default.removeItem(at: dir.appendingPathComponent("v1/scenes/S03.js"))       // never written (or removed after a failed test)
        SceneModules.markTested(version: "v1", scene: "S01", ok: false, store: store)               // its file failed its test
        try next()
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.write, ["S01", "S03"]); XCTAssertEqual(p.reuse.keys.sorted(), ["S02"])
        XCTAssertEqual(p.reasons["S01"], "failed its test"); XCTAssertTrue(p.reasons["S03"]?.hasPrefix("no file yet") == true)
    }

    func testAHandEditedSceneIsWrittenOnlyWithTheConfirmation() async throws {
        try store.apply(.scene(id: "S01", SceneEdit(text: "One, changed")))
        try "return function render(g, lt, c) { /* my edit */ };\n".write(to: dir.appendingPathComponent("v1/scenes/S01.js"), atomically: true, encoding: .utf8)
        try next()
        var p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.handEdited, ["S01"]); XCTAssertEqual(p.write, [], "out of date, but edited by hand: not written"); XCTAssertEqual(p.reuse["S01"], "v1")
        let m = JobModel(); _ = await run(m); XCTAssertEqual(m.asked, [], "the edit is taken over as it is")
        XCTAssertTrue(String(decoding: bytes("v2/scenes/S01.js") ?? Data(), as: UTF8.self).contains("my edit"))
        BuildJob.startOver(version: "v2", store: store)
        p = BuildJob.plan(version: "v2", store: store, overwrite: ["S01"])
        XCTAssertEqual(p.write, ["S01"], "ticked: it is written again"); XCTAssertEqual(p.handEdited, [])
        let m2 = JobModel(); _ = await run(m2, options: BuildJob.Options(overwrite: ["S01"])); XCTAssertEqual(m2.asked, ["S01"])
    }

    func testALockedSceneIsTakenOverAndNeverWritten() async throws {
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        try next()
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.locked, ["S02"]); XCTAssertEqual(p.reuse["S02"], "v1")
        let c = BuildJob.card(p, store: store, skill: skill, resuming: false)
        XCTAssertEqual(c.title, "Nothing changed since the last build")
        // with a changed neighbour the card counts the lock
        try store.apply(.scene(id: "S01", SceneEdit(text: "One, changed")))
        let c2 = BuildJob.card(BuildJob.plan(version: "v2", store: store), store: store, skill: skill, resuming: false)
        XCTAssertEqual(c2.title, "Build v2: 1 scene will be written, 2 reused unchanged (1 locked)")
        let m = JobModel(); _ = await run(m); XCTAssertEqual(m.asked, ["S01"])
        XCTAssertEqual(bytes("v2/scenes/S02.js"), bytes("v1/scenes/S02.js"))
    }

    func testRewriteEverythingWritesEveryUnlockedSceneAndTheFrameButNotTheLockedOne() async throws {
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        try next()
        let p = BuildJob.plan(version: "v2", store: store, force: true)
        XCTAssertEqual(p.write, ["S01", "S03"]); XCTAssertTrue(p.needsFrame); XCTAssertEqual(p.calls, 3)
        let m = JobModel(); _ = await run(m, options: BuildJob.Options(force: true))
        XCTAssertEqual(m.asked, ["reel", "S01", "S03"]); XCTAssertEqual(bytes("v2/scenes/S02.js"), bytes("v1/scenes/S02.js"))
        // a Build that continues keeps being a rewrite of everything: the flag is kept with the Build
        XCTAssertTrue(BuildJob.options(store).force == false, "finished: the marker is gone")
    }

    func testAContinuedRewriteEverythingStaysARewriteEverything() async throws {
        try next()
        let m = JobModel(); m.failOn["S02"] = AgentError.msg("API 500: boom")
        _ = await BuildJob.run(version: "v2", store: store, skill: skill, transport: m, options: BuildJob.Options(force: true))
        store.activity.update { $0.build = nil }
        XCTAssertTrue(BuildJob.options(store).force)
        let again = JobModel(); _ = await BuildJob.run(version: "v2", store: store, skill: skill, transport: again)
        XCTAssertEqual(again.asked, ["S02", "S03"], "S02 and S03 are written, not taken over from v1; S01 and the frame were written already")
    }

    func testALookChangeMakesStaleOnlyTheScenesThatInheritIt() async throws {
        try store.apply(.sceneLook(id: "S02", [DecisionChange(.palette, "#000000, #FFFFFF, #FF0000, #00FF00")]))
        _ = try Film.write(version: "v1", store: store)
        SceneModules.markTested(version: "v1", scene: "S02", ok: true, store: store)
        try? SceneModules.recordGeneration(version: "v1", scenes: ["S02"], store: store); SceneModules.markTested(version: "v1", scene: "S02", ok: true, store: store)
        try store.apply(.decisions([DecisionChange(.palette, "#202830, #EEEEEE, #AA3300, #3399FF")], title: nil))
        try next()
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.write, ["S01", "S03"], "S02 has its own palette: the project's changed nothing for it"); XCTAssertEqual(p.reuse.keys.sorted(), ["S02"])
        XCTAssertTrue(p.needsFrame, "the frame holds the project's palette: it is written again")
    }

    func testTheBriefMakesTheScenesOutOfDate() async throws {
        try store.apply(.parameter(.tone, "calm"))
        try next()
        XCTAssertEqual(BuildJob.plan(version: "v2", store: store).write, ["S01", "S02", "S03"], "what the scenes were written under changed")
    }

    func testAnOlderContractIsSaidAndNeverForcesARewrite() async throws {
        var book = SceneModules.loadBook(store)
        for id in ["S01", "S02"] { book.versions["v1"]?[id]?.contract = "old" }
        try SceneModules.save(book, store)
        try next()
        let p = BuildJob.plan(version: "v2", store: store)
        XCTAssertEqual(p.write, []); XCTAssertEqual(p.olderContract.sorted(), ["S01", "S02"])
        let c = BuildJob.card(p, store: store, skill: skill, resuming: false)
        XCTAssertTrue(c.changes.contains { $0.before.contains("2 reused scenes were written under an older contract") && $0.after.contains("Rewrite everything") })
    }

    func testTheFilmIsAssembledToTheSameBytesWithOrWithoutReuse() async throws {
        let probe = await Shell.run("command -v python3", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "python3 is needed")
        try "{\"title\": \"T\", \"main\": \"main.js\", \"duration\": 9, \"fonts\": [], \"tokens\": {}, \"weight_budget_mb\": 5}".write(to: dir.appendingPathComponent("v1/project.json"), atomically: true, encoding: .utf8)
        try next()
        _ = await run(JobModel())                      // everything reused
        let fresh = dir.appendingPathComponent("v3"); try FileManager.default.createDirectory(at: fresh.appendingPathComponent("scenes"), withIntermediateDirectories: true)
        for f in ["project.json", "reel.js", "film.json"] { try FileManager.default.copyItem(at: dir.appendingPathComponent("v1/\(f)"), to: fresh.appendingPathComponent(f)) }
        for id in ["S01", "S02", "S03"] { try FileManager.default.copyItem(at: dir.appendingPathComponent("v1/scenes/\(id).js"), to: fresh.appendingPathComponent("scenes/\(id).js")) }
        for v in ["v1", "v2", "v3"] { let r = await Shell.run("python3 '\(skill.path)/scripts/assemble.py' '\(dir.path)/\(v)'", in: dir, timeout: 60); XCTAssertEqual(r?.status, 0, r?.err ?? "") }
        XCTAssertEqual(bytes("v2/main.js"), bytes("v1/main.js")); XCTAssertEqual(bytes("v3/main.js"), bytes("v1/main.js"))
    }
}
