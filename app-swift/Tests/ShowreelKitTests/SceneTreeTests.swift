import XCTest
@testable import ShowreelKit

/// Phase W1b: the scene tree, node statuses and the scene-level overrides of background and look.
final class SceneTreeTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("w1b"); store = ProjectStore(root: dir)
        try? store.create(name: "T", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C"), DecisionChange(.background, "aurora"), DecisionChange(.titleFont, "Anton")], title: nil))
        try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: "Hello", status: "ok")))
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }

    func testNoOverrideByDefaultAndTheTreeShowsInheritedValues() throws {
        XCTAssertNil(file.scenes[0].overrides)
        XCTAssertFalse(try String(contentsOf: dir.appendingPathComponent("showreel.json")).contains("overrides"), "absent from the file by default")
        let tree = SceneTree.build(file.scenes[0], in: file, assets: Assets.load(store), store: store)
        XCTAssertEqual(tree.map { $0.group }, [.composition, .effects, .look])
        XCTAssertEqual(tree[2].nodes.map { $0.id }, ["background", "palette", "fonts"], "the look: background, palette, fonts")
        let bg = try XCTUnwrap(tree[2].nodes.first)
        XCTAssertEqual(bg.origin, .inherited); XCTAssertEqual(bg.detail, "aurora")
        XCTAssertEqual(tree[2].nodes.map { $0.origin }, [.inherited, .inherited, .inherited])
        XCTAssertEqual(tree[0].nodes.first?.detail, "\u{201C}Hello\u{201D}", "the words are the first element of the composition"); XCTAssertTrue(tree[1].nodes.isEmpty, "no effect yet")
        XCTAssertEqual(tree[0].nodes.count, 1)
    }

    func testOverridingAndRevertingAreTypedOperationsWithCards() throws {
        let card = try store.plan(.sceneLook(id: "S01", [DecisionChange(.background, "duotone")]))
        XCTAssertEqual(card.title, "Override the look of S01")
        XCTAssertEqual(card.changes, [Change("S01 background", "inherited: aurora", "overridden: duotone")])
        XCTAssertNil(file.scenes[0].overrides, "planning writes nothing")
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.background, "duotone"), DecisionChange(.palette, "#000000, #FFFFFF")]), expecting: nil)
        let f = file
        XCTAssertEqual(f.effective(.background, for: f.scenes[0]), "duotone"); XCTAssertTrue(f.isOverridden(.palette, for: f.scenes[0]))
        XCTAssertEqual(f.effective(.titleFont, for: f.scenes[0]), "Anton", "what is not overridden is inherited")
        XCTAssertEqual(f.decisions.background?.id, "aurora", "the project is untouched")
        let node = try XCTUnwrap(SceneTree.build(f.scenes[0], in: f, assets: [], store: store)[2].nodes.first)
        XCTAssertEqual(node.origin, .overridden); XCTAssertEqual(node.projectValue, "aurora")
        // invalid values are refused like the project's
        XCTAssertThrowsError(try store.plan(.sceneLook(id: "S01", [DecisionChange(.background, "nope")])))
        XCTAssertThrowsError(try store.plan(.sceneLook(id: "S01", [DecisionChange(.palette, "red, blue")])))
        XCTAssertThrowsError(try store.plan(.sceneLook(id: "S01", [DecisionChange(.moods, "Kinetic punch")])), "a scene overrides the look, not the moods")
        XCTAssertThrowsError(try store.plan(.sceneLook(id: "S09", [DecisionChange(.background, "duotone")])))
        XCTAssertThrowsError(try store.plan(.sceneLook(id: "S01", [DecisionChange(.background, "duotone")])), "no change")
        // revert, one key and then everything: the key disappears from the file
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.background, "")]))
        XCTAssertEqual(file.effective(.background, for: file.scenes[0]), "aurora")
        let rev = try store.plan(.sceneLook(id: "S01", [DecisionChange(.palette, "")]))
        XCTAssertEqual(rev.title, "Revert S01 to the project look")
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.palette, "")]))
        XCTAssertNil(file.scenes[0].overrides)
        XCTAssertFalse(try String(contentsOf: dir.appendingPathComponent("showreel.json")).contains("overrides"))
    }

    func testOverridesSurviveARoundTripWithUnknownKeysAndOldFilesMigrateUntouched() throws {
        let old = try ShowreelFile.decode(#"{"schema": 1, "name": "O", "scenes": [{"id": "S01", "duration": 2}]}"#)
        XCTAssertNil(old.scenes[0].overrides, "an older file has no override: nothing is added")
        var f = try ShowreelFile.decode(##"{"schema": 1, "name": "O", "scenes": [{"id": "S01", "duration": 2, "overrides": {"background": {"id": "aurora", "future": 1}, "palette": ["#000000", "#FFFFFF"], "newThing": true}}]}"##)
        XCTAssertEqual(f.scenes[0].overrides?.background?.id, "aurora")
        f.scenes[0].unknown["sceneKey"] = .bool(true)
        let back = try ShowreelFile.decode(try f.encoded())
        XCTAssertEqual(back, f)
        XCTAssertEqual(back.scenes[0].overrides?.unknown["newThing"], .bool(true))
        XCTAssertEqual(back.scenes[0].overrides?.background?.unknown["future"], .number(1))
    }

    func testChangingASceneLookAfterTheGoTakesTheGoBack() throws {
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true))
        let card = try store.plan(.sceneLook(id: "S01", [DecisionChange(.background, "duotone")]))
        XCTAssertTrue(card.changes.contains(Change("Go", "given", "to be given again")))
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.background, "duotone")]))
        XCTAssertEqual(file.gates["review"], "open")
    }

    func testNodeStatusesFromTheAssetRules() throws {
        let inbox = makeTempDir("inbox-w1b"); defer { try? FileManager.default.removeItem(at: inbox) }
        let logo = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: logo, atomically: true, encoding: .utf8)
        let song = inbox.appendingPathComponent("theme.mp3"); try Data(count: 9_000_000).write(to: song)
        let gone = inbox.appendingPathComponent("shot.png"); try "x".write(to: gone, atomically: true, encoding: .utf8)
        try Assets.add([logo, song, gone], to: store)
        _ = try store.apply(.asset(id: "logo-01", status: .proposed, note: nil, licence: nil, scenes: nil))
        let ids = Assets.load(store).map { $0.id }
        try store.apply(.scene(id: "S01", SceneEdit(assets: ids.joined(separator: ", "))))
        let rows = Assets.load(store)
        func st(_ id: String) -> NodeStatus { Assets.nodeStatus(rows.first { $0.id == id }!, store: store) }
        XCTAssertEqual(st("logo-01"), .toApprove, "proposed: still to approve")
        _ = try? store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(Assets.nodeStatus(Assets.load(store).first { $0.id == "logo-01" }!, store: store), .approved)
        XCTAssertEqual(st("audio-01"), .overBudget, "a 9 MB sound is over the weight rule")
        let png = try XCTUnwrap(rows.first { $0.id == "shot-01" })
        try FileManager.default.removeItem(at: dir.appendingPathComponent("assets/" + png.file))
        XCTAssertEqual(Assets.nodeStatus(png, store: store), .missing)
        try store.apply(.asset(id: "shot-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(Assets.nodeStatus(Assets.load(store).first { $0.id == "shot-01" }!, store: store), .excluded)
        let tree = SceneTree.build(file.scenes[0], in: file, assets: Assets.load(store), store: store)
        XCTAssertEqual(Set(tree[0].nodes.compactMap { $0.assetID }), Set(ids), "every linked resource is a node of the composition")
    }

    func testToolSetsAndRevertsAnOverride() async throws {
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let r = await tools.run("set_scene_override", ["id": "S01", "key": "background", "value": "duotone"]).text
        XCTAssertTrue(r.hasPrefix("accepted and applied"), r)
        XCTAssertEqual(ui.cards.last?.title, "Override the look of S01")
        let bad = await tools.run("set_scene_override", ["id": "S01", "key": "moods", "value": "x"]).text
        XCTAssertTrue(bad.hasPrefix("unknown key"), bad)
        _ = await tools.run("set_scene_override", ["id": "S01", "key": "background", "value": ""])
        XCTAssertNil(file.scenes[0].overrides)
        let state = await tools.run("get_state", [:]).text
        XCTAssertTrue(state.contains("storyboards"))
    }

    func testBuildPromptListsSceneOverrides() throws {
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.background, "duotone")]))
        XCTAssertTrue(BuildRunner.prompt(version: "v1", store: store).contains("S01: background duotone"))
    }
}
