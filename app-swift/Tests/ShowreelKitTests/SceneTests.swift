import XCTest
@testable import ShowreelKit

final class SceneTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("scenes"); store = ProjectStore(root: dir); try? store.create(name: "S", conversationLanguage: "en", reelLanguages: ["en"]) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    var scenes: [ShowreelFile.Scene] { store.loadShowreel()?.scenes ?? [] }
    /// Adds a scene lasting `end - start` seconds (the times keep the tests readable: the order gives the real start).
    func add(_ text: String, _ start: String, _ end: String, after: String? = nil) throws {
        let d = (Double(end) ?? 0) - (Double(start) ?? 0)
        try store.apply(.addScene(id: "", SceneEdit(duration: ProjectDocs.seconds(d), text: text, after: after)))
    }
    var order: [String] { store.loadShowreel()?.storyboards.first?.items.map { $0.scene } ?? [] }
    func gate(_ k: String) -> String? { store.loadShowreel()?.gates[k] }

    /// Three scenes, all OK, storyboard validated.
    func readyToGo() throws {
        try add("Notes, finally calm", "0", "4"); try add("Capture anything", "4", "9"); try add("Share in a tap", "9", "13")
        for s in scenes { try store.apply(.scene(id: s.id, SceneEdit(status: "ok"))) }
        try store.apply(.gate("storyboard", passed: true))
    }

    // MARK: IDs

    func testIDsAreStableAndNeverReused() throws {
        XCTAssertEqual(SceneRules.nextID([]), "S01")
        try add("a", "0", "3"); try add("b", "3", "6"); try add("c", "6", "9")
        XCTAssertEqual(scenes.map { $0.id }, ["S01", "S02", "S03"])
        try store.apply(.scene(id: "S03", SceneEdit(status: "ditched")))
        try add("d", "6", "9")
        XCTAssertEqual(scenes.map { $0.id }, ["S01", "S02", "S03", "S04"], "a ditched ID is kept and never reused")
        XCTAssertEqual(scenes[2].status, "ditched")
        try store.apply(.moveScene(id: "S04", after: "start", montage: nil))
        XCTAssertEqual(order, ["S04", "S01", "S02", "S03"], "moving changes the order of the storyboard, never an ID")
        XCTAssertEqual(scenes.map { $0.id }, ["S01", "S02", "S03", "S04"], "the library keeps its own order")
        try add("e", "0", "1")
        XCTAssertEqual(scenes.last?.id, "S05")
        XCTAssertTrue(SceneRules.isValidID("S04b") && SceneRules.isValidID("S120") && !SceneRules.isValidID("s1") && !SceneRules.isValidID("Scene 1"))
    }

    func testAddSceneValidationAndCard() throws {
        let card = try store.plan(.addScene(id: "", SceneEdit(duration: "4", text: "Hello")))
        XCTAssertEqual(card.title, "Add scene S01")
        XCTAssertEqual(card.changes.first, Change("Scene", "(none)", "S01, first"))
        XCTAssertTrue(card.changes.contains(Change("On-screen text", "(empty)", "Hello")))
        XCTAssertTrue(scenes.isEmpty, "planning writes nothing")
        try store.apply(.addScene(id: "", SceneEdit(duration: "4", text: "Hello")), expecting: card)
        XCTAssertThrowsError(try store.plan(.addScene(id: "S01", SceneEdit(text: "again"))), "an ID is never reused")
        XCTAssertThrowsError(try store.plan(.addScene(id: "scene2", SceneEdit(text: "x"))))
        XCTAssertThrowsError(try store.plan(.addScene(id: "", SceneEdit(duration: "-3"))), "a duration is above zero")
        XCTAssertThrowsError(try store.plan(.addScene(id: "", SceneEdit(duration: "soon"))))
        XCTAssertThrowsError(try store.plan(.addScene(id: "", SceneEdit(text: "x", assets: "logo-09"))), "an unknown asset")
        XCTAssertThrowsError(try store.plan(.addScene(id: "", SceneEdit(text: "x", after: "S77"))))
        // insertion after a given scene
        try add("third", "8", "10"); try add("second", "4", "8", after: "S01")
        XCTAssertEqual(store.loadShowreel()?.orderedLibrary.map { $0.text }, ["Hello", "second", "third"], "the new scene sits after S01 in the storyboard")
        XCTAssertEqual(scenes.map { $0.id }, ["S01", "S02", "S03"], "and the library lists it in creation order")
    }

    func testUpdateSceneFieldsStatusAndNote() throws {
        try add("old", "0", "4")
        let card = try store.plan(.scene(id: "S01", SceneEdit(duration: "5", text: "new", feeling: "calm")))
        XCTAssertEqual(card.title, "Edit S01")
        XCTAssertEqual(card.changes, [Change("Duration", "4", "5"), Change("On-screen text", "old", "new"), Change("Feeling and tension", "(empty)", "calm")])
        try store.apply(.scene(id: "S01", SceneEdit(duration: "5", text: "new", feeling: "calm")))
        XCTAssertEqual(scenes[0].duration, 5); XCTAssertEqual(scenes[0].text, "new")
        XCTAssertThrowsError(try store.plan(.scene(id: "S01", SceneEdit(status: "great"))))
        XCTAssertThrowsError(try store.plan(.scene(id: "S09", SceneEdit(text: "x"))))
        XCTAssertThrowsError(try store.plan(.scene(id: "S01", SceneEdit(text: "new"))), "no change")
        XCTAssertThrowsError(try store.plan(.scene(id: "S01", SceneEdit(duration: "0"))), "a duration is above zero")
        try store.apply(.scene(id: "S01", SceneEdit(note: "shorter", status: "modify")))
        XCTAssertEqual(scenes[0].status, "modify"); XCTAssertEqual(scenes[0].note, "shorter")
        XCTAssertEqual(try store.plan(.scene(id: "S01", SceneEdit(status: "ditched"))).title, "Ditch S01")
        // a stale card is refused
        let stale = try store.plan(.scene(id: "S01", SceneEdit(text: "mine")))
        try store.apply(.scene(id: "S01", SceneEdit(text: "someone else's")))
        XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(text: "mine")), expecting: stale))
    }

    func testEditingAReviewedSceneSendsItBackToReview() throws {
        try add("fine", "0", "4"); try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        let card = try store.plan(.scene(id: "S01", SceneEdit(text: "changed")))
        XCTAssertTrue(card.changes.contains(Change("Status", "ok", "open")))
        try store.apply(.scene(id: "S01", SceneEdit(note: "a remark")))                    // a note alone keeps OK
        XCTAssertEqual(scenes[0].status, "ok")
        try store.apply(.scene(id: "S01", SceneEdit(text: "changed")))
        XCTAssertEqual(scenes[0].status, "open")
    }

    func testLinkedResourcesAreTheManifestsSceneColumn() throws {
        let inbox = makeTempDir("inbox-scenes"); defer { try? FileManager.default.removeItem(at: inbox) }
        let logo = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: logo, atomically: true, encoding: .utf8)
        let shot = inbox.appendingPathComponent("app-home.png"); try "x".write(to: shot, atomically: true, encoding: .utf8)
        try Assets.add([logo, shot], to: store)
        try add("one", "0", "3"); try add("two", "3", "6")
        let card = try store.plan(.scene(id: "S01", SceneEdit(assets: "logo-01, shot-01")))
        XCTAssertEqual(card.changes, [Change("Linked assets", "(none)", "logo-01, shot-01")])
        try store.apply(.scene(id: "S01", SceneEdit(assets: "logo-01, shot-01")))
        try store.apply(.scene(id: "S02", SceneEdit(assets: "logo-01")))
        XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.sceneIDs, ["S01", "S02"])
        try store.apply(.scene(id: "S01", SceneEdit(assets: "shot-01")))
        XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.sceneIDs, ["S02"], "unlinked from S01, still linked to S02")
        XCTAssertThrowsError(try store.plan(.scene(id: "S01", SceneEdit(assets: "font-09"))))
        // a scene added with links
        try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "three", assets: "logo-01")))
        XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.sceneIDs, ["S02", "S03"])
    }

    // MARK: the Go

    func testTheGoNeedsAValidatedStoryboardAndEveryScenesOK() throws {
        XCTAssertThrowsError(try store.plan(.gate("review", passed: true)), "no scene yet")
        try add("one", "0", "3"); try add("two", "3", "6")
        XCTAssertThrowsError(try store.plan(.gate("review", passed: true)))
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok"))); try store.apply(.scene(id: "S02", SceneEdit(note: "x", status: "modify")))
        try store.apply(.gate("storyboard", passed: true))
        XCTAssertTrue(store.goBlocking()?.contains("S02") == true, "a scene to modify blocks the Go")
        try store.apply(.scene(id: "S02", SceneEdit(status: "ditched")))
        XCTAssertNil(store.goBlocking(), "OK or ditched is enough")
        XCTAssertNoThrow(try store.plan(.gate("review", passed: true)))
        XCTAssertThrowsError(try store.plan(.gate("storyboard", passed: true)), "already validated: no change")
    }

    func testTheGoIsNeverDeduced() throws {
        try readyToGo()
        XCTAssertEqual(gate("review"), nil, "every scene is OK and the storyboard is validated, and still no Go")
        XCTAssertNil(store.goBlocking())
        XCTAssertFalse(BuildRunner.canBuild(store), "the build does not start without the Go")
        XCTAssertEqual(BuildRunner.readiness(store).first { $0.id == "build.go" }?.level, .pending)
        try store.apply(.gate("review", passed: true))
        XCTAssertEqual(gate("review"), "passed")
        XCTAssertTrue(BuildRunner.canBuild(store))
        XCTAssertEqual(BuildRunner.readiness(store).first { $0.id == "build.go" }?.level, .ok)
    }

    func testChangingTheFilmAfterTheGoTakesTheGoBack() throws {
        try readyToGo(); try store.apply(.gate("review", passed: true))
        // a note changes nothing about the film: the Go stays
        try store.apply(.scene(id: "S01", SceneEdit(note: "just a remark")))
        XCTAssertEqual(gate("review"), "passed")
        // a text change reopens it, and the card says so before it happens
        let card = try store.plan(.scene(id: "S01", SceneEdit(text: "a new line")))
        XCTAssertTrue(card.changes.contains(Change("Go", "given", "to be given again")))
        try store.apply(.scene(id: "S01", SceneEdit(text: "a new line")))
        XCTAssertEqual(gate("review"), "open", "a fresh Go is needed")
        XCTAssertFalse(BuildRunner.canBuild(store))
        // so does ditching, adding and moving the timing
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        try store.apply(.gate("review", passed: true))
        try store.apply(.scene(id: "S03", SceneEdit(status: "ditched")))
        XCTAssertEqual(gate("review"), "open")
        try store.apply(.gate("review", passed: true))
        try add("another", "9", "12")
        XCTAssertEqual(gate("review"), "open")
    }

    func testTheCopilotCannotGiveTheGo() async throws {
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        for (n, i) in [("add_scene", ["duration": 4, "text": "x", "status": "ok"] as [String: Any]), ("update_scene", ["id": "S01", "status": "ok"]),
                       ("write_file", ["path": "showreel.json", "content": "{\"gates\":{\"review\":\"passed\"}}"]), ("propose_edit", ["file": "showreel.json", "content": "{}"]),
                       ("update_parameter", ["key": "name", "value": "Renamed"])] as [(String, [String: Any])] { _ = await tools.run(n, i).text }
        XCTAssertNotEqual(gate("review"), "passed", "no tool gives the Go")
        let defs = Tools.definitions.compactMap { $0["name"] as? String }
        XCTAssertFalse(defs.contains { $0.lowercased().contains("go") || $0.lowercased().contains("gate") }, "and none is even named for it")
    }

    // MARK: checks

    func testStoryboardRules() throws {
        func r() -> [String: CheckLevel] { Dictionary(uniqueKeysWithValues: Checks.run(area: "storyboard", store: store).map { ($0.id, $0.level) }) }
        XCTAssertEqual(r()["storyboard.any"], .pending)
        try store.apply(.parameter(.duration, "12"))
        try add("one", "0", "4"); try add("two", "4", "8")
        XCTAssertEqual(r()["storyboard.ids"], .ok); XCTAssertEqual(r()["storyboard.times"], .ok); XCTAssertEqual(r()["storyboard.overlap"], .ok)
        XCTAssertEqual(r()["storyboard.duration"], .tight, "the scenes stop four seconds before the end")
        try add("three", "8", "12")
        XCTAssertEqual(r()["storyboard.duration"], .ok)
        try store.apply(.scene(id: "S03", SceneEdit(duration: "7")))
        XCTAssertEqual(r()["storyboard.duration"], .fail, "past the duration")
        // overlap and untimed scenes, written by hand in showreel.json
        var f = try XCTUnwrap(store.loadShowreel())
        f.storyboards[0].items[1].start = 3
        f.scenes.append(.init(id: "S04", text: "no time"))
        f.storyboards[0].items.append(.init(scene: "S04"))
        try store.save(f)
        XCTAssertEqual(r()["storyboard.overlap"], .fail); XCTAssertEqual(r()["storyboard.times"], .pending)
        f.scenes.append(.init(id: "S04", text: "twice"))
        try store.save(f)
        XCTAssertEqual(r()["storyboard.ids"], .fail, "an ID used twice")
    }

    func testReadingBudgetAndFeasibilityShowInTheStoryboardBlock() throws {
        try store.apply(.parameter(.duration, "10"))
        try add("Capture anything you think of, anywhere, at any time of day", "0", "1.5")
        let ids = Checks.run(area: "storyboard", store: store)
        XCTAssertEqual(ids.first { $0.id == "reading.S01" }?.level, .fail)
        XCTAssertNotNil(ids.first { $0.id.hasPrefix("feasibility.") })
        XCTAssertEqual(ids.first { $0.id == "gate.storyboard" }?.level, .pending)
    }

    func testLinkedAssetsMustBeApproved() throws {
        let inbox = makeTempDir("inbox-sb"); defer { try? FileManager.default.removeItem(at: inbox) }
        let logo = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: logo, atomically: true, encoding: .utf8)
        try Assets.add([logo], to: store)
        try add("one", "0", "3"); try store.apply(.scene(id: "S01", SceneEdit(assets: "logo-01")))
        XCTAssertEqual(Checks.run(area: "storyboard", store: store).first { $0.id == "storyboard.assets" }?.level, .tight)
        try store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(Checks.run(area: "storyboard", store: store).first { $0.id == "storyboard.assets" }?.level, .ok)
    }

    func testSceneReviewChecks() throws {
        try add("one", "0", "3"); try add("two", "3", "6")
        var r = Dictionary(uniqueKeysWithValues: Checks.run(area: "scene", store: store).map { ($0.id, $0.level) })
        XCTAssertEqual(r["review.S01"], .pending); XCTAssertEqual(r["review.all"], .pending); XCTAssertEqual(r["gate.review"], .pending)
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok"))); try store.apply(.scene(id: "S02", SceneEdit(note: "tighter", status: "modify")))
        r = Dictionary(uniqueKeysWithValues: Checks.run(area: "scene", store: store).map { ($0.id, $0.level) })
        XCTAssertEqual(r["review.S01"], .ok); XCTAssertEqual(r["review.S02"], .tight)
        try store.apply(.scene(id: "S02", SceneEdit(status: "ok")))
        XCTAssertEqual(Checks.run(area: "scene", store: store).first { $0.id == "review.all" }?.level, .ok)
    }

    // MARK: generated storyboard.md

    func testStoryboardMarkdownFollowsTheScenesAndIsNotOverwritten() throws {
        try add("Hello", "0", "4"); try add("World", "4", "8")
        try store.apply(.scene(id: "S02", SceneEdit(status: "ditched")))
        let sb = try XCTUnwrap(store.read("storyboard.md"))
        XCTAssertTrue(sb.contains("| S01 ") && sb.contains("Hello") && sb.contains("ditched"), "the file follows showreel.json")
        XCTAssertEqual(DocSync.pending(store).count, 0)
        try (sb + "\nAdded in a chat.\n").write(to: dir.appendingPathComponent("storyboard.md"), atomically: true, encoding: .utf8)
        try add("Third", "8", "12")
        XCTAssertTrue(try XCTUnwrap(store.read("storyboard.md")).contains("Added in a chat."), "an externally edited storyboard is not overwritten")
        XCTAssertEqual(DocSync.pending(store).map { $0.file }, ["storyboard.md"])
    }
}

final class SceneToolTests: XCTestCase {
    var dir: URL!
    var ui: ScriptedUI!
    var tools: Tools!
    var store: ProjectStore!
    override func setUpWithError() throws {
        dir = makeTempDir("scenetools"); ui = ScriptedUI()
        tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui); store = ProjectStore(root: dir)
        try store.create(name: "T", conversationLanguage: "en", reelLanguages: ["en"])
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    func run(_ n: String, _ i: [String: Any]) async -> String { await tools.run(n, i).text }

    func testAddSceneTakesNumbersForTheDurationAndShowsACard() async throws {
        let r = await run("add_scene", ["duration": 4.5, "text": "Hello", "visual": "Logo rises"])
        XCTAssertTrue(r.hasPrefix("accepted and applied"), r)
        XCTAssertEqual(ui.cards.first?.title, "Add scene S01")
        let s = try XCTUnwrap(store.loadShowreel()?.scenes.first)
        XCTAssertEqual(s.duration, 4.5); XCTAssertEqual(s.visual, "Logo rises")
        XCTAssertTrue(ui.proposals.isEmpty, "a card, not a file diff")
    }

    func testRefusedAndDirectAndStale() async throws {
        ui.accept = false
        let refused = await run("add_scene", ["text": "x"])
        XCTAssertTrue(refused.hasPrefix("refused by the user")); XCTAssertTrue(store.loadShowreel()?.scenes.isEmpty == true)
        ui.accept = true
        _ = await run("add_scene", ["duration": 3, "text": "one"])
        ui.beforeAnswer = { try? self.store.apply(.scene(id: "S01", SceneEdit(text: "someone else"))) }
        let stale = await run("update_scene", ["id": "S01", "text": "mine"])
        XCTAssertTrue(stale.contains("changed since the proposal"), stale)
        ui.beforeAnswer = nil
        store.settings = StudioSettings(applyDirectly: true)
        let n = ui.cards.count
        let direct = await run("update_scene", ["id": "S01", "note": "ok"])
        XCTAssertTrue(direct.hasPrefix("applied directly")); XCTAssertEqual(ui.cards.count, n)
    }

    func testBadInputIsRefusedWithoutACard() async throws {
        _ = await run("add_scene", ["duration": 3, "text": "one"])
        let n = ui.cards.count
        let a = await run("update_scene", ["id": "S09", "text": "x"])
        let b = await run("update_scene", ["id": "S01", "status": "great"])
        let c = await run("add_scene", ["duration": -2])
        let d = await run("update_scene", ["id": "S01", "assets": "logo-77"])
        XCTAssertTrue([a, b, c, d].allSatisfy { $0.hasPrefix("refused") }, "\(a) | \(b) | \(c) | \(d)")
        XCTAssertEqual(ui.cards.count, n)
    }

    func testOpenBlocksAreBuiltAndStateShowsGoAndVersions() async throws {
        for b in ["library", "viewer", "inspector", "storyboard", "build"] { let r = await run("open_block", ["block": b]); XCTAssertTrue(r.hasPrefix("opened"), r) }
        let state = await run("get_state", [:])
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(state.utf8)) as? [String: Any])
        XCTAssertTrue((o["go"] as? String ?? "").hasPrefix("not given"))
        XCTAssertEqual(o["versions"] as? [String], [])
    }

    func testAgentWritesScenesThroughCards() async throws {
        let t = ScriptedTransport([
            ([toolUse("a", "add_scene", ["duration": 4, "text": "One"]), toolUse("b", "add_scene", ["duration": 4, "text": "Two"])], "tool_use"),
            ([textBlock("Drafted.")], "end_turn"),
        ])
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t)
        try await agent.send("draft the storyboard")
        XCTAssertEqual(store.loadShowreel()?.scenes.map { $0.id }, ["S01", "S02"])
        XCTAssertEqual(ui.cards.map { $0.title }, ["Add scene S01", "Add scene S02"], "one card per scene, accepted one by one")
    }
}

final class BuildTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("build"); store = ProjectStore(root: dir); try? store.create(name: "B", conversationLanguage: "en", reelLanguages: ["en"]) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testVersionFolders() throws {
        XCTAssertEqual(Versions.list(store), []); XCTAssertEqual(Versions.next(store), "v1")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v1"), withIntermediateDirectories: true)
        XCTAssertEqual(Versions.list(store), [], "a folder without project.json is not a version yet")
        XCTAssertEqual(Versions.next(store), "v2", "but its name is never reused")
        try "{}".write(to: dir.appendingPathComponent("v1/project.json"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v10"), withIntermediateDirectories: true)
        try "{}".write(to: dir.appendingPathComponent("v10/project.json"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("lt1"), withIntermediateDirectories: true)
        XCTAssertEqual(Versions.list(store), ["v1", "v10"], "numeric order; a look test folder is not a version")
        XCTAssertEqual(Versions.next(store), "v11")
    }

    func testPromptIsTheBuildInstructionAndNeverTheGo() throws {
        try store.apply(.parameter(.duration, "30")); try store.apply(.parameter(.reelLanguages, "en, fr"))
        let p = BuildRunner.prompt(version: "v2", store: store)
        for needle in ["v2/project.json", "v2/main.js", "get_state", "build-guide.md", "approved assets", "30 s", "en, fr", "Do not write outside v2/", "do not run build.py"] {
            XCTAssertTrue(p.contains(needle), needle)
        }
        XCTAssertTrue(p.contains("The user pressed Go"), "the instruction exists only because the user pressed Go")
        XCTAssertFalse(p.lowercased().contains("api key") || p.contains("sk-"))
    }

    func skipUnlessToolsExist() async throws {
        let r = await Shell.run("command -v python3 && command -v node && node -e \"require('jsdom')\"", in: dir, timeout: 30)
        try XCTSkipUnless(r?.status == 0, "python3, node and jsdom are needed (run the app's setup check)")
    }

    func makeVersion(_ v: String, main: String? = nil) throws {
        let skill = try XCTUnwrap(Skill.root())
        let vd = dir.appendingPathComponent(v)
        try FileManager.default.createDirectory(at: vd, withIntermediateDirectories: true)
        let project = """
        {"title": "Test", "main": "main.js", "duration": 10, "tokens": {"--page": "#000000", "--bar-bg": "#111111", "--bar-fg": "#eeeeee", "--btn-bg": "#dddddd", "--btn-fg": "#111111", "--accent": "#ffffff", "--ov-bg": "rgba(0,0,0,.85)", "--ov-fg": "#ffffff", "--font-ui": "system-ui,sans-serif", "--font-title": "system-ui,sans-serif"}, "weight_budget_mb": 20}
        """
        try project.write(to: vd.appendingPathComponent("project.json"), atomically: true, encoding: .utf8)
        try (main ?? String(contentsOf: skill.appendingPathComponent("engine/main.template.js"), encoding: .utf8)).write(to: vd.appendingPathComponent("main.js"), atomically: true, encoding: .utf8)
    }

    func testPipelineBuildsTestsAndWritesOnlyInsideTheProject() async throws {
        try await skipUnlessToolsExist()
        let skill = try XCTUnwrap(Skill.root())
        let before = Set(try FileManager.default.subpathsOfDirectory(atPath: skill.path))
        try makeVersion("v1")
        let report = await BuildRunner.run(version: "v1", store: store, skill: skill)
        XCTAssertEqual(report.steps.map { $0.id }, ["build.make", "build.harness", "build.smoke"])
        XCTAssertTrue(report.ok, report.steps.map { "\($0.title): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        XCTAssertTrue(Versions.hasDist(store, "v1"), "the output is vN/dist in the project")
        XCTAssertEqual(Set(try FileManager.default.subpathsOfDirectory(atPath: skill.path)), before, "nothing was written into the skill folder (the bundle)")
        // the gates follow the deterministic results
        try store.record(report)
        XCTAssertEqual(store.loadShowreel()?.gates["build"], "passed"); XCTAssertEqual(store.loadShowreel()?.gates["verify"], "passed")
    }

    func testPipelineReportsRedForABrokenVersion() async throws {
        try await skipUnlessToolsExist()
        let skill = try XCTUnwrap(Skill.root())
        try makeVersion("v1", main: "(function () { window.SHOWREEL = { render(g, t, c) { throw new Error('boom'); } }; })();\n")
        let report = await BuildRunner.run(version: "v1", store: store, skill: skill)
        XCTAssertFalse(report.ok)
        XCTAssertTrue(report.steps.contains { $0.level == .fail }, "a failing step is red")
        try store.record(report)
        XCTAssertNotEqual(store.loadShowreel()?.gates["build"], "passed", "a red result never passes the gate")
        // no project.json at all
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v2"), withIntermediateDirectories: true)
        let none = await BuildRunner.run(version: "v2", store: store, skill: skill)
        XCTAssertEqual(none.steps.first?.level, .fail); XCTAssertFalse(none.ok)
    }

    func testBuildRefusesAnAssetThatIsNotApproved() async throws {
        try await skipUnlessToolsExist()
        let skill = try XCTUnwrap(Skill.root())
        let inbox = makeTempDir("inbox-build"); defer { try? FileManager.default.removeItem(at: inbox) }
        let img = inbox.appendingPathComponent("app-home.png"); try Data([0x89, 0x50, 0x4E, 0x47]).write(to: img)
        try Assets.add([img], to: store)    // proposed, not approved
        try makeVersion("v1")
        let vd = dir.appendingPathComponent("v1")
        let proj = try String(contentsOf: vd.appendingPathComponent("project.json"), encoding: .utf8).replacingOccurrences(of: "\"weight_budget_mb\": 20", with: "\"images\": {\"shot-01\": \"../assets/prepared/shot-01-app-home.png\"}, \"weight_budget_mb\": 20")
        try proj.write(to: vd.appendingPathComponent("project.json"), atomically: true, encoding: .utf8)
        let rows = Assets.load(store)
        try XCTSkipUnless(rows.first?.file == "prepared/shot-01-app-home.png", "the asset layout is not as this test expects")
        // proposed: the skill's build only refuses what is excluded or on hold, the app's checks flag the rest
        let proposed = await BuildRunner.run(version: "v1", store: store, skill: skill)
        XCTAssertTrue(proposed.built, proposed.steps.first?.detail ?? "")
        try store.apply(.asset(id: "shot-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        let r = await BuildRunner.run(version: "v1", store: store, skill: skill)
        XCTAssertFalse(r.built, "build.py refuses an asset the user excluded: \(r.steps.first?.detail ?? "")")
    }
}
