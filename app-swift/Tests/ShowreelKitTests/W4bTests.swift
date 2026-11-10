import XCTest
@testable import ShowreelKit

/// W4b: a scene's thumbnail is a PNG captured from the real scene. The capture itself needs a screen; its keys, states, storage and queue do not.
final class W4bTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    override func setUp() {
        dir = makeTempDir("w4b"); store = ProjectStore(root: dir)
        try? store.create(name: "M", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t, status: "validated"))) }
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    func writeModule(_ id: String, _ body: String = "x") throws {
        let u = SceneModules.url(version: v, scene: id, store: store)
        try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "return function render(){ /* \(body) */ };\n".write(to: u, atomically: true, encoding: .utf8)
    }
    func built(_ ids: [String] = ["S01", "S02", "S03"]) throws { for i in ids { try writeModule(i) }; try SceneModules.recordGeneration(version: v, store: store) }
    func png() -> Data { Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]) }
    func job(_ id: String) throws -> SceneThumbs.Job { try XCTUnwrap(SceneThumbs.job(for: id, in: file, version: v, store: store)) }

    func testPlaceholderSaysWhyThereIsNoPicture() throws {
        let f = file
        guard case .placeholder(let none) = SceneThumbs.state(of: f.scenes[0], in: f, version: nil, store: store) else { return XCTFail() }
        XCTAssertTrue(none.contains("No film is built yet") && none.contains("Build"))
        guard case .placeholder(let unwritten) = SceneThumbs.state(of: f.scenes[0], in: f, version: v, store: store) else { return XCTFail() }
        XCTAssertTrue(unwritten.contains("not written yet"))
        try built()
        guard case .placeholder(let notYet) = SceneThumbs.state(of: file.scenes[0], in: file, version: v, store: store) else { return XCTFail() }
        XCTAssertTrue(notYet.contains("Refresh thumbnail"))
    }

    func testAJobPutsTheInstantInsideTheSceneInTheFilm() throws {
        try built()
        let j2 = try job("S02")
        XCTAssertEqual(j2.time, 4 + j2.instant, accuracy: 0.001, "S02 starts after S01's 4 s")
        XCTAssertTrue(j2.instant >= 0 && j2.instant < 4)
        XCTAssertNil(SceneThumbs.job(for: "S99", in: file, version: v, store: store))
    }

    func testFreshThenStaleWhenTheSceneChangesThenStaleWhenTheFilmIsBuiltAgain() throws {
        try built()
        let u = try SceneThumbs.record(job("S01"), png: png(), store: store)
        XCTAssertEqual(SceneThumbs.state(of: file.scenes[0], in: file, version: v, store: store), .fresh(u))
        XCTAssertTrue(u.path.hasPrefix(dir.appendingPathComponent(SceneThumbs.folder).path), "the PNG never leaves .studio")
        try store.apply(.scene(id: "S01", SceneEdit(text: "Another words")))
        guard case .stale(_, let why, let needsBuild) = SceneThumbs.state(of: file.scenes[0], in: file, version: v, store: store) else { return XCTFail("a changed scene is marked") }
        XCTAssertTrue(needsBuild && why.contains("Build"))
        XCTAssertFalse(SceneThumbs.capturable(in: file, version: v, store: store).contains("S01"), "a capture of the old file would not make it fresh: no loop")
        try built(["S01"]); try writeModule("S01", "rebuilt"); try SceneModules.recordGeneration(version: v, scenes: ["S01"], store: store)
        guard case .stale(_, _, let nb) = SceneThumbs.state(of: file.scenes[0], in: file, version: v, store: store) else { return XCTFail() }
        XCTAssertFalse(nb, "the film was built again: a capture brings it up to date")
        XCTAssertTrue(SceneThumbs.capturable(in: file, version: v, store: store).contains("S01"))
    }

    func testTheKeyChangesOnlyWithWhatChangesTheImage() throws {
        try built()
        let a = try SceneThumbs.record(job("S01"), png: png(), store: store)
        let same = try SceneThumbs.record(job("S01"), png: png(), store: store)
        XCTAssertEqual(a, same, "same inputs, same file")
        try store.apply(.scene(id: "S01", SceneEdit(duration: "6")))
        let longer = try SceneThumbs.record(job("S01"), png: png(), store: store)
        XCTAssertNotEqual(a, longer, "the duration changes the picture")
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.path), "the file it replaces goes")
        try store.apply(.scene(id: "S01", SceneEdit(note: "a remark")))
        XCTAssertEqual(try SceneThumbs.record(job("S01"), png: png(), store: store), longer, "a note is not an input")
    }

    func testTheLookAndAResourceChangeStalenessThroughTheScenesInputs() throws {
        try built()
        _ = try SceneThumbs.record(job("S02"), png: png(), store: store)
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        if case .fresh = SceneThumbs.state(of: file.scenes[1], in: file, version: v, store: store) { XCTFail("a look change makes the picture out of date") }
    }

    func testAFailureKeepsThePlaceholderWithItsReasonUntilTheFileChanges() throws {
        try built()
        SceneThumbs.recordFailure(try job("S03"), reason: "The film page did not load.", store: store)
        XCTAssertEqual(SceneThumbs.state(of: file.scenes[2], in: file, version: v, store: store), .failed(reason: "The film page did not load."))
        XCTAssertFalse(SceneThumbs.capturable(in: file, version: v, store: store).contains("S03"), "no retry loop on the same file")
        try writeModule("S03", "new")
        XCTAssertTrue(SceneThumbs.capturable(in: file, version: v, store: store).contains("S03"), "a new file is tried again")
    }

    func testOrphansGoWhenASceneIsDeletedAndOldProjectsOpenUnchanged() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(SceneThumbs.folder).path), "an old project has no thumbnail folder")
        XCTAssertEqual(SceneThumbs.cleanOrphans(in: file, store: store), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(SceneThumbs.folder).path), "cleaning creates nothing")
        try built()
        let u1 = try SceneThumbs.record(job("S01"), png: png(), store: store), u2 = try SceneThumbs.record(job("S02"), png: png(), store: store)
        try Data([1]).write(to: dir.appendingPathComponent(SceneThumbs.folder + "/stray.png"))
        try store.apply(.deleteScene(id: "S02"))
        XCTAssertEqual(SceneThumbs.cleanOrphans(in: file, store: store), 2, "the deleted scene's PNG and the stray one")
        XCTAssertTrue(FileManager.default.fileExists(atPath: u1.path)); XCTAssertFalse(FileManager.default.fileExists(atPath: u2.path))
        XCTAssertGreaterThan(SceneThumbs.size(store), 0)
    }

    func testAPathWithADirectoryIsRefused() {
        XCTAssertNil(SceneThumbs.url(.init(file: "../x.png", module: "", inputs: "", instant: 0, version: v), store))
        XCTAssertNil(SceneThumbs.url(.init(file: "a/b.png", module: "", inputs: "", instant: 0, version: v), store))
        XCTAssertNil(SceneThumbs.url(.init(file: "x.jpg", module: "", inputs: "", instant: 0, version: v), store))
    }

    func testTheQueueIsOrderedOneAtATimeAndCancellable() {
        var q = SceneThumbQueue()
        q.enqueue(["S01", "S02", "S01", "S03"])
        XCTAssertEqual(q.pending, ["S01", "S02", "S03"], "each scene once")
        XCTAssertEqual(q.next(), "S01"); XCTAssertNil(q.next(), "one at a time")
        q.enqueue(["S01"]); XCTAssertEqual(q.pending, ["S02", "S03"], "the running scene is not queued twice")
        q.cancel("S02"); XCTAssertEqual(q.pending, ["S03"])
        q.finish(); XCTAssertEqual(q.next(), "S03")
        q.cancel(); q.finish(); XCTAssertTrue(q.isIdle)
    }

    func testRefreshExplainsWhyItCannotRun() {
        var busy = ProjectActivity.Snapshot(); busy.build = .init(version: "v2", phase: .generating, started: Date())
        XCTAssertEqual(SceneThumbs.refreshAvailability(.placeholder(reason: "x"), activity: busy).why?.cause, .building)
        XCTAssertNotNil(SceneThumbs.refreshAvailability(.placeholder(reason: "No film is built yet."), activity: .init()).why)
        XCTAssertNotNil(SceneThumbs.refreshAvailability(.fresh(URL(fileURLWithPath: "/x.png")), activity: .init()).why?.way)
        XCTAssertTrue(SceneThumbs.refreshAvailability(.stale(URL(fileURLWithPath: "/x.png"), why: "w", needsBuild: false), activity: .init()).isAvailable)
        XCTAssertTrue(SceneThumbs.refreshAvailability(.failed(reason: "r"), activity: .init()).isAvailable)
    }

    /// W4c: captures made by 0.21.0 were blank (the hidden window did not paint) but recorded as fresh. They carry no capture format, so they must be taken again.
    func testACaptureOfAnOlderFormatIsNotTrustedAndIsTakenAgain() throws {
        try built()
        let j = try job("S01")
        let u = try SceneThumbs.record(j, png: png(), store: store)
        XCTAssertEqual(SceneThumbs.state(of: file.scenes[0], in: file, version: v, store: store), .fresh(u))
        var book = SceneThumbs.loadBook(store); book.entries["S01"]?.format = nil; try SceneThumbs.saveBook(book, store)
        guard case .placeholder = SceneThumbs.state(of: file.scenes[0], in: file, version: v, store: store) else { return XCTFail("an old blank picture must not show as fresh") }
        XCTAssertTrue(SceneThumbs.capturable(in: file, version: v, store: store).contains("S01"))
        XCTAssertEqual(SceneThumbs.capturable(in: file, version: v, store: store).count, 3)
    }

    func testTheTimecodeIsTheOneTheFilmPageWrites() {
        XCTAssertEqual(SceneThumbs.timecode(0), "0:00"); XCTAssertEqual(SceneThumbs.timecode(4.5), "0:04"); XCTAssertEqual(SceneThumbs.timecode(75.9), "1:15")
        XCTAssertEqual(SceneThumbs.timecode(-3), "0:00")
    }

    func testAFrameIsNeverEmpty() {
        for (w, h) in [(1.0, 1.0), (5.0, 3.0), (20.0, 20.0)] {
            let e = FrameLayout.elements(width: w, height: h, hasName: false)
            XCTAssertGreaterThanOrEqual(e.thumb.height, 1); XCTAssertGreaterThan(e.thumb.width, 0); XCTAssertGreaterThan(e.thumbWidth, 0)
        }
    }

    func testTheViewsDrawTheStateAndNeverDecideIt() throws {
        let src = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        let v = try String(contentsOf: src.appendingPathComponent("SceneFrameViews.swift"), encoding: .utf8)
        XCTAssertTrue(v.contains("project.sceneThumbs[scene.id]") && v.contains("refreshAvailability") && v.contains(".disabledWithReason"))
        let m = try String(contentsOf: src.appendingPathComponent("SceneThumbModel.swift"), encoding: .utf8)
        XCTAssertTrue(m.contains("SceneThumbs.quietDelay") && m.contains("activity.build == nil"), "a quiet delay, never during a build")
    }
}
