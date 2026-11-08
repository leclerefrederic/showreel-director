import XCTest
@testable import ShowreelKit

/// Phase W1: the scene library, the montage, the migration of the phase T shape, and the operations on them.
final class WorkspaceDataTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("w1"); store = ProjectStore(root: dir); try? store.create(name: "W", conversationLanguage: "en", reelLanguages: ["en"]) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    var file: ShowreelFile { store.loadShowreel()! }
    func add(_ text: String, _ d: String = "3", after: String? = nil) throws {
        try store.apply(.addScene(id: "", SceneEdit(duration: d, text: text, after: after)))
    }

    /// A showreel.json as phase T wrote it: start and end inside each scene, no montage, a ditched scene, a gap, an unknown key.
    static let phaseT = """
    {"schema": 1, "name": "Old", "created": "2026-11-01", "step": "storyboard", "reelLanguages": ["en"], "futureKey": {"kept": true},
     "decisions": {"duration": 20, "formats": ["9:16"]}, "gates": {"storyboard": "passed"},
     "scenes": [
       {"id": "S01", "start": 0, "end": 4, "text": "One", "status": "ok", "handoff": "wipe", "scenePrivate": 7},
       {"id": "S02", "start": 4, "end": 9, "text": "Two", "status": "modify", "note": "shorter"},
       {"id": "S03", "start": 9, "end": 12, "text": "Gone", "status": "ditched"},
       {"id": "S04", "start": 14, "end": 16, "text": "After a gap"}
     ]}
    """

    func testPhaseTFileMigratesToALibraryAndOneMontage() throws {
        let f = try ShowreelFile.decode(Self.phaseT)
        XCTAssertEqual(f.scenes.map { $0.id }, ["S01", "S02", "S03", "S04"])
        XCTAssertEqual(f.scenes.map { $0.duration }, [4, 5, 3, 2], "the scene keeps its own length")
        XCTAssertEqual(f.scenes[2].archived, true, "a ditched scene is archived")
        XCTAssertEqual(f.storyboards.count, 1)
        let m = f.storyboards[0]
        XCTAssertEqual(m.items.map { $0.scene }, ["S01", "S02", "S03", "S04"])
        XCTAssertEqual(m.items.map { $0.enabled }, [true, true, false, true], "the ditched scene is off")
        XCTAssertEqual(m.items[3].start, 14, "a start the order does not give is kept as an override")
        XCTAssertNil(m.items[0].start); XCTAssertNil(m.items[1].start)
        XCTAssertEqual(m.items[0].transition.type, "cut")
        let tl = f.timeline()
        XCTAssertEqual(tl.map { $0.scene.id }, ["S01", "S02", "S04"])
        XCTAssertEqual(tl.map { $0.start }, [0, 4, 14]); XCTAssertEqual(tl.map { $0.end }, [4, 9, 16], "no timing is lost")
        // the first save writes the new shape
        try store.save(f)
        let text = try XCTUnwrap(store.read("showreel.json"))
        XCTAssertTrue(text.contains("\"storyboards\"") && text.contains("\"duration\""))
        XCTAssertFalse(text.contains("\"start\" : 0") || text.contains("\"end\""), "start and end are not written back into the scenes")
        let again = try ShowreelFile.decode(text)
        XCTAssertEqual(again.scenes, f.scenes); XCTAssertEqual(again.storyboards, f.storyboards, "and reading it again gives the same library and montage")
        XCTAssertEqual(again.origin?.tool, "studio", "the app owns the file from its first save")
    }

    func testUnknownKeysSurviveTheMigrationAndTheRoundTrip() throws {
        var f = try ShowreelFile.decode(Self.phaseT)
        XCTAssertEqual(f.unknown["futureKey"], .object(["kept": .bool(true)]))
        XCTAssertEqual(f.scenes[0].unknown["scenePrivate"], .number(7))
        f.storyboards[0].unknown["cutNote"] = .string("master"); f.storyboards[0].items[0].unknown["tag"] = .bool(true)
        f.storyboards[0].items[0].transition = .init(type: "push", duration: 0.5, params: .object(["dir": .string("left")]))
        f.storyboards[0].items[0].transition.unknown["future"] = .number(1)
        f.storyboards.append(.init(id: "short", name: "Short", format: "9:16", items: [.init(scene: "S01")]))
        let back = try ShowreelFile.decode(try f.encoded())
        XCTAssertEqual(back, f)
        XCTAssertEqual(back.storyboards[0].items[0].transition.unknown["future"], .number(1))
        XCTAssertEqual(back.storyboards[0].unknown["cutNote"], .string("master"))
        XCTAssertEqual(back.storyboards.count, 2, "the data allows several montages")
    }

    func testPhaseADictionaryOfReviewStatesStillReads() throws {
        let f = try ShowreelFile.decode(#"{"schema": 1, "name": "A", "scenes": {"S01": {"status": "ok", "note": ""}, "S02": {"status": "modify", "note": "shorter"}}}"#)
        XCTAssertEqual(f.scenes.map { $0.id }, ["S01", "S02"])
        XCTAssertEqual(f.storyboards[0].items.map { $0.scene }, ["S01", "S02"])
        XCTAssertNil(f.scenes[0].duration, "no length known: the check asks for one")
    }

    func testAFileWithAMontageIsNotMigratedAgain() throws {
        let json = #"{"schema": 1, "name": "N", "scenes": [{"id": "S01", "duration": 2, "start": 30, "end": 31}, {"id": "S02", "duration": 3}], "storyboards": [{"id": "main", "name": "Master", "items": [{"scene": "S02", "enabled": true}, {"scene": "S01", "enabled": false}]}]}"#
        let f = try ShowreelFile.decode(json)
        XCTAssertEqual(f.storyboards[0].items.map { $0.scene }, ["S02", "S01"], "the montage in the file wins")
        XCTAssertEqual(f.scenes[0].duration, 2, "an explicit duration wins over the old start and end")
        XCTAssertEqual(f.film.map { $0.id }, ["S02"])
    }

    // MARK: archive, ditch, ids

    func testDeletingASceneArchivesItAndTheIDIsReserved() throws {
        try add("a"); try add("b"); try add("c")
        let card = try store.plan(.scene(id: "S02", SceneEdit(archived: true)))
        XCTAssertEqual(card.title, "Archive S02")
        XCTAssertTrue(card.changes.contains { $0.label == "Library" })
        try store.apply(.scene(id: "S02", SceneEdit(archived: true)))
        XCTAssertEqual(file.library.map { $0.id }, ["S01", "S03"], "it leaves the lists")
        XCTAssertEqual(file.scenes.map { $0.id }, ["S01", "S02", "S03"], "and stays in the file")
        XCTAssertEqual(file.film.map { $0.id }, ["S01", "S03"], "and is off in the montage")
        try add("d")
        XCTAssertEqual(file.scenes.last?.id, "S04", "the archived ID is never reused")
        XCTAssertThrowsError(try store.plan(.addScene(id: "S02", SceneEdit(text: "again"))))
        // brought back: in the library again, still off until the user switches it on
        try store.apply(.scene(id: "S02", SceneEdit(archived: false)))
        XCTAssertEqual(file.library.map { $0.id }.contains("S02"), true)
        XCTAssertEqual(file.film.map { $0.id }.contains("S02"), false)
        try store.apply(.sceneEnabled(id: "S02", enabled: true, montage: nil))
        XCTAssertEqual(file.film.map { $0.id }.contains("S02"), true)
    }

    func testDitchArchivesTheSceneAndSwitchesItOffInEveryMontage() throws {
        try add("a"); try add("b")
        var f = file
        f.storyboards.append(.init(id: "short", name: "Short", items: [.init(scene: "S02"), .init(scene: "S01")]))
        try store.save(f)
        let card = try store.plan(.scene(id: "S02", SceneEdit(note: "no", status: "ditched")))
        XCTAssertEqual(card.title, "Ditch S02")
        XCTAssertEqual(card.changes.filter { $0.label.hasPrefix("Montage") }.count, 2, "the card names both montages")
        try store.apply(.scene(id: "S02", SceneEdit(note: "no", status: "ditched")))
        let g = file
        XCTAssertEqual(g.scenes[1].archived, true); XCTAssertEqual(g.scenes[1].status, "ditched")
        XCTAssertTrue(g.storyboards.allSatisfy { m in m.items.first { $0.scene == "S02" }?.enabled == false })
        XCTAssertEqual(g.timeline(1).map { $0.scene.id }, ["S01"])
        // bringing it back with another status un-archives it
        try store.apply(.scene(id: "S02", SceneEdit(status: "open")))
        XCTAssertEqual(file.scenes[1].archived, false)
    }

    // MARK: switching on and off, reordering

    func testSwitchingASceneOffKeepsItInTheLibraryAndTheFile() throws {
        try add("a"); try add("b"); try add("c")
        let card = try store.plan(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        XCTAssertEqual(card.title, "Switch S02 off")
        XCTAssertEqual(card.changes, [Change("S02 in Master", "on", "off")])
        XCTAssertEqual(file.film.count, 3, "planning writes nothing")
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        XCTAssertEqual(file.film.map { $0.id }, ["S01", "S03"])
        XCTAssertEqual(file.library.count, 3, "still in the library")
        XCTAssertEqual(file.timeline().map { $0.start }, [0, 3], "the film closes the gap: times follow the order")
        XCTAssertThrowsError(try store.plan(.sceneEnabled(id: "S02", enabled: false, montage: nil)), "no change")
        XCTAssertThrowsError(try store.plan(.sceneEnabled(id: "S09", enabled: true, montage: nil)))
        XCTAssertThrowsError(try store.plan(.sceneEnabled(id: "S01", enabled: false, montage: "nope")))
    }

    func testReorderingChangesTheOrderAndTheTimesNotTheIDs() throws {
        try add("a", "2"); try add("b", "3"); try add("c", "4")
        let card = try store.plan(.moveScene(id: "S03", after: "start", montage: nil))
        XCTAssertEqual(card.changes, [Change("Position of S03", "3", "1")])
        try store.apply(.moveScene(id: "S03", after: "start", montage: nil))
        XCTAssertEqual(file.film.map { $0.id }, ["S03", "S01", "S02"])
        XCTAssertEqual(file.timeline().map { $0.start }, [0, 4, 6])
        try store.apply(.moveScene(id: "S03", after: "S02", montage: nil))
        XCTAssertEqual(file.film.map { $0.id }, ["S01", "S02", "S03"])
        XCTAssertThrowsError(try store.plan(.moveScene(id: "S03", after: "S03", montage: nil)))
        XCTAssertThrowsError(try store.plan(.moveScene(id: "S03", after: "S77", montage: nil)))
        XCTAssertThrowsError(try store.plan(.moveScene(id: "S03", after: "S02", montage: nil)), "already there")
        XCTAssertEqual(file.scenes.map { $0.id }, ["S01", "S02", "S03"])
    }

    func testPositionBeforeATarget() throws {
        try add("a"); try add("b"); try add("c")
        let f = file
        XCTAssertEqual(f.position(of: "S03", before: "S01"), "start")
        XCTAssertEqual(f.position(of: "S01", before: "S03"), "S02")
        XCTAssertEqual(f.position(of: "S01", before: nil), "S03", "dropped after the last one")
        XCTAssertNil(f.position(of: "S02", before: "S03"), "already there")
        XCTAssertNil(f.position(of: "S02", before: "S77"), "an unknown target")
    }

    func testAddingAfterASceneUsesTheMontageNotTheLibrary() throws {
        try add("a"); try add("b")
        try add("middle", after: "S01")
        XCTAssertEqual(file.film.map { $0.id }, ["S01", "S03", "S02"])
        XCTAssertEqual(file.scenes.map { $0.id }, ["S01", "S02", "S03"])
    }

    func testChangesAfterTheGoTakeItBackIncludingSwitchesAndMoves() throws {
        try add("a"); try add("b"); try add("c")
        for s in file.scenes { try store.apply(.scene(id: s.id, SceneEdit(status: "ok"))) }
        try store.apply(.gate("storyboard", passed: true))
        func giveGo() throws { try store.apply(.gate("review", passed: true)) }
        try giveGo()
        let off = try store.plan(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        XCTAssertTrue(off.changes.contains(Change("Go", "given", "to be given again")), "the card says so before it happens")
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        XCTAssertEqual(file.gates["review"], "open")
        try store.apply(.sceneEnabled(id: "S02", enabled: true, montage: nil))
        try giveGo()
        try store.apply(.moveScene(id: "S03", after: "start", montage: nil))
        XCTAssertEqual(file.gates["review"], "open", "reordering changes the film")
        try giveGo()
        try store.apply(.scene(id: "S01", SceneEdit(duration: "4")))
        XCTAssertEqual(file.gates["review"], "open", "so does a duration")
        XCTAssertEqual(file.scenes[0].status, "open", "and the changed scene goes back to review")
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        try giveGo()
        try store.apply(.scene(id: "S01", SceneEdit(note: "remark")))
        XCTAssertEqual(file.gates["review"], "passed", "a note does not")
        // switching on a scene nobody reviewed cannot keep the Go either
        try store.apply(.scene(id: "S01", SceneEdit(archived: true)))
        XCTAssertEqual(file.gates["review"], "open")
    }

    func testTheGoNeedsEverySceneThatIsOnAndNoOtherScene() throws {
        try add("a"); try add("b")
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        try store.apply(.gate("storyboard", passed: true))
        XCTAssertTrue(store.goBlocking()?.contains("S02") == true)
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        XCTAssertNil(store.goBlocking(), "a scene that is off does not need a review")
    }

    // MARK: checks and the generated storyboard

    func testChecksFollowTheMontage() throws {
        try store.apply(.parameter(.duration, "10"))
        try add("Notes that stay calm", "4"); try add("Capture", "4"); try add("Third scene", "4")
        func r() -> [String: CheckLevel] { Dictionary(uniqueKeysWithValues: Checks.run(area: "storyboard", store: store).map { ($0.id, $0.level) }) }
        XCTAssertEqual(r()["storyboard.duration"], .fail, "12 s of scenes in a 10 s film")
        try store.apply(.sceneEnabled(id: "S03", enabled: false, montage: nil))
        XCTAssertEqual(r()["storyboard.duration"], .tight, "8 s: switching a scene off is how the film is shortened")
        XCTAssertNil(r()["reading.S03"], "a scene that is off is not judged")
        try store.apply(.scene(id: "S02", SceneEdit(duration: "6")))
        XCTAssertEqual(r()["storyboard.duration"], .ok)
        // a library scene no montage places is only a warning
        var f = file; f.scenes.append(.init(id: "S09", duration: 2, text: "lost")); try store.save(f)
        XCTAssertEqual(r()["storyboard.loose"], .tight)
    }

    func testStoryboardMarkdownRoundTripsOrderOffAndArchive() throws {
        try add("One", "4"); try add("Two", "5"); try add("Three", "3")
        try store.apply(.moveScene(id: "S03", after: "start", montage: nil))
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        try store.apply(.scene(id: "S01", SceneEdit(archived: true)))
        let md = try XCTUnwrap(store.read("storyboard.md"))
        XCTAssertTrue(md.contains("off"), "a scene that is off says so in the Time column")
        XCTAssertTrue(md.contains("archived"), "an archived scene stays in the table with its ID")
        let ids = md.components(separatedBy: "\n").filter { $0.hasPrefix("| S") }.map { String($0.dropFirst(2).prefix(3)) }
        XCTAssertEqual(ids, ["S03", "S01", "S02"], "the table follows the montage's order, and every scene is in it")
        // someone edits the table outside the app: swap the order of S03 and S02, give S03 another length, switch S02 on
        var f = file
        var edited = md.replacingOccurrences(of: "| off ", with: "| 5-7 s ")
        edited = edited.replacingOccurrences(of: "0-3 s", with: "0-9 s")
        MarkdownRead.apply(storyboard: edited, to: &f)
        XCTAssertEqual(f.scenes.first { $0.id == "S02" }?.duration, 2)
        XCTAssertEqual(f.film.contains { $0.id == "S02" }, true, "a time instead of off switches the scene on")
        XCTAssertEqual(f.scenes.first { $0.id == "S03" }?.duration, 9)
        XCTAssertEqual(f.scenes.first { $0.id == "S01" }?.archived, true, "archived stays archived")
        XCTAssertEqual(f.scenes.count, 3, "no scene is lost")
    }

    func testTheMarkdownTableDoesNotLoseAnIDThatLeftIt() throws {
        try add("One"); try add("Two")
        var f = file
        MarkdownRead.apply(storyboard: "| ID | Time | On-screen text |\n|---|---|---|\n| S01 | 0-3 s | One |\n", to: &f)
        XCTAssertEqual(f.scenes.map { $0.id }, ["S01", "S02"])
        XCTAssertEqual(f.scenes[1].archived, true, "the missing ID stays, archived and ditched: it is never reused")
        XCTAssertEqual(f.scenes[1].status, "ditched")
    }

    // MARK: the copilot's tools

    func testToolsEnableAndMoveShowCards() async throws {
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        for t in ["a", "b", "c"] { _ = await tools.run("add_scene", ["duration": 3, "text": t]) }
        let off = await tools.run("enable_scene", ["id": "S02", "enabled": false]).text
        XCTAssertTrue(off.hasPrefix("accepted and applied"), off)
        let mv = await tools.run("move_scene", ["id": "S03", "after": "start"]).text
        XCTAssertTrue(mv.hasPrefix("accepted and applied"), mv)
        XCTAssertEqual(file.film.map { $0.id }, ["S03", "S01"])
        XCTAssertEqual(ui.cards.suffix(2).map { $0.title }, ["Switch S02 off", "Move S03"])
        let bad = await tools.run("enable_scene", ["id": "S02"]).text
        XCTAssertTrue(bad.contains("true or false"))
        let state = await tools.run("get_state", [:]).text
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(state.utf8)) as? [String: Any])
        XCTAssertEqual((o["film"] as? [[String: Any]])?.compactMap { $0["scene"] as? String }, ["S03", "S01"], "the copilot reads the film with its times")
        XCTAssertNotNil((o["showreel"] as? [String: Any])?["storyboards"])
        let defs = Tools.definitions.compactMap { $0["name"] as? String }
        XCTAssertTrue(defs.contains("enable_scene") && defs.contains("move_scene"))
    }

    func testTheSkillExportDecodesIntoLibraryAndMontage() throws {
        let text = try String(contentsOf: fixtureURL("studio-export/showreel.json"), encoding: .utf8)
        let f = try ShowreelFile.decode(text)
        XCTAssertEqual(f.storyboards.count, 1)
        XCTAssertEqual(f.storyboards[0].items.map { $0.scene }, ["S01", "S02", "S03"])
        XCTAssertEqual(f.storyboards[0].items.map { $0.enabled }, [true, true, false], "the DITCH row is switched off")
        XCTAssertEqual(f.scenes[2].archived, true, "and archived")
        XCTAssertEqual(f.scenes.map { $0.duration }, [4, 5, 3])
        XCTAssertEqual(f.scenes[0].handoff, "wipe left", "the handoff column is the passage note")
        XCTAssertEqual(f.film.map { $0.id }, ["S01", "S02"])
        XCTAssertEqual(f.timeline().map { $0.end }, [4, 9])
    }
}
