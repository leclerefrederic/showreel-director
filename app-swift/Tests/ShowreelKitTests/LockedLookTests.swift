import XCTest
@testable import ShowreelKit

/// A change of the global look and the locked scenes that inherit it: which scenes, the card's warning, the user's choice, Clap's card.
final class LockedLookTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("lockedlook"); store = ProjectStore(root: dir)
        try? store.create(name: "LL", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three", "Four"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t))) }
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    var otherBackground: String { Look.backgroundIDs().first { $0 != file.decisions.background?.id }! }
    func lock(_ ids: String...) throws {
        for id in ids { try store.apply(.scene(id: id, SceneEdit(status: "validated"))) }
        try store.apply(.sceneLock(ids: ids, locked: true))
    }
    func palette(_ n: Int) -> ProjectOperation { .decisions([DecisionChange(.palette, "#00000\(n), #FFFFFF, #FF0000, #00FF00")], title: nil) }

    func testOnlyLockedScenesThatInheritTheChangedPartAreListed() throws {
        try lock("S02", "S03")
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.palette, "#111111, #EEEEEE, #FF0000, #00FF00")]))        // unlocked, own palette
        // S03 gets its own palette before it is locked: do it through a second project state
        var f = file
        var s3 = try XCTUnwrap(f.scenes.first { $0.id == "S03" })
        var d = ShowreelFile.Decisions(); d.palette = ["#222222", "#EEEEEE", "#FF0000", "#00FF00"]
        s3.overrides = d
        f.scenes = f.scenes.map { $0.id == "S03" ? s3 : $0 }
        XCTAssertEqual(LockedLook.scenes(changing: [.palette], in: f), ["S02"], "S03 has its own palette; S01 is not locked; S04 is not locked")
        XCTAssertEqual(LockedLook.scenes(changing: [.titleFont], in: f), ["S02", "S03"], "S03 only overrides the palette: it inherits the fonts")
        XCTAssertEqual(LockedLook.scenes(changing: [.moods], in: f), ["S02", "S03"], "a scene cannot override the moods")
        XCTAssertEqual(LockedLook.scenes(changing: [.effectsPack], in: f), ["S02", "S03"], "nor the effects pack")
        XCTAssertEqual(LockedLook.scenes(changing: [], in: f), [])
        XCTAssertEqual(LockedLook.scenes(changing: [.palette, .textFont], in: f), ["S02", "S03"], "one inherited part is enough")
    }

    func testTheBackgroundMoodFollowsItsOwnKeyNotTheGroup() throws {
        try lock("S02")
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.background, otherBackground)]))
        var f = file
        var s2 = try XCTUnwrap(f.scenes.first { $0.id == "S02" })
        var d = ShowreelFile.Decisions(); var b = ShowreelFile.Background(); b.id = otherBackground; d.background = b
        s2.overrides = d
        f.scenes = f.scenes.map { $0.id == "S02" ? s2 : $0 }
        XCTAssertEqual(LockedLook.scenes(changing: [.background], in: f), [], "it has its own background")
        XCTAssertEqual(LockedLook.scenes(changing: [.backgroundMood], in: f), ["S02"], "but it inherits the mood of the background")
    }

    func testTheCardCarriesTheWarningWithTheOwnersWords() throws {
        try lock("S02", "S03")
        let card = try store.plan(palette(1))
        let w = try XCTUnwrap(card.lockWarning)
        XCTAssertEqual(w.scenes, ["S02", "S03"])
        XCTAssertEqual(w.headline, "S02 and S03 are locked and inherit this look")
        XCTAssertEqual(w.advice, "Applying this will change locked scenes. Unlock them first, or give them their own look.")
        XCTAssertEqual(LockedLookWarning(scenes: ["S02"]).headline, "S02 is locked and inherits this look")
        XCTAssertEqual(LockedLookWarning(scenes: ["S01", "S02", "S04"]).headline, "S01, S02 and S04 are locked and inherit this look")
    }

    func testNoWarningWhenNoLockedSceneInheritsOrNothingChanges() throws {
        XCTAssertNil(try store.plan(palette(1)).lockWarning, "no locked scene")
        try lock("S02")
        try store.apply(palette(1))
        XCTAssertThrowsError(try store.plan(palette(1)), "no change is still refused")
        XCTAssertNil(try store.plan(.parameter(.audience, "Everyone")).lockWarning, "only a look change carries it")
        // a change that touches only what the scene owns
        var f = file
        var s2 = try XCTUnwrap(f.scenes.first { $0.id == "S02" })
        var d = ShowreelFile.Decisions(); d.palette = ["#222222", "#EEEEEE", "#FF0000", "#00FF00"]
        s2.overrides = d
        f.scenes = f.scenes.map { $0.id == "S02" ? s2 : $0 }
        try store.save(f)
        XCTAssertNil(try store.plan(palette(2)).lockWarning, "S02 has its own palette")
        XCTAssertNotNil(try store.plan(.decisions([DecisionChange(.palette, "#000009, #FFFFFF, #FF0000, #00FF00"), DecisionChange(.effectsPack, Look.packs().first!.name)], title: nil)).lockWarning)
    }

    func testTheUserMayApplyAnywayAndTheLockedSceneStaysLocked() throws {
        try lock("S02")
        let card = try store.plan(palette(3))
        try store.apply(palette(3), expecting: card)
        XCTAssertEqual(file.decisions.palette?.first, "#000003")
        XCTAssertEqual(file.scenes.first { $0.id == "S02" }?.state, .locked, "the lock is not touched")
    }

    func testACardMadeBeforeASceneWasLockedIsNotAppliedBlind() throws {
        let card = try store.plan(palette(4))
        XCTAssertNil(card.lockWarning)
        try lock("S02")
        XCTAssertThrowsError(try store.apply(palette(4), expecting: card), "the user never saw the warning") { XCTAssertTrue($0.localizedDescription.contains("changed since")) }
    }

    func testClapsLookToolShowsTheWarningAndApplyDirectlyDoesNotSkipIt() async throws {
        try lock("S02")
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let out = await tools.run("update_decision", ["key": "palette", "value": "#000005, #FFFFFF, #FF0000, #00FF00"]).text
        XCTAssertTrue(out.hasPrefix("accepted and applied"), out)
        XCTAssertTrue(out.contains("S02 is locked and inherits this look"), "Clap is told too: \(out)")
        XCTAssertEqual(ui.cards.last?.lockWarning?.scenes, ["S02"])
        var s = store.settings; s.applyDirectly = true; store.settings = s
        let n = ui.cards.count
        _ = await tools.run("update_decision", ["key": "titleFont", "value": Look.freeFonts().first!.name]).text
        XCTAssertEqual(ui.cards.count, n + 1, "apply-directly does not cover a change that redraws a locked scene")
        let direct = await tools.run("update_decision", ["key": "textFont", "value": Look.freeFonts().last!.name]).text
        XCTAssertTrue(direct.contains("S02 is locked and inherits"), direct)
        // without a locked scene, apply-directly works as before
        try store.apply(.sceneLock(ids: ["S02"], locked: false))
        let free = await tools.run("update_decision", ["key": "moods", "value": Look.packs().first!.name]).text
        XCTAssertTrue(free.hasPrefix("applied directly"), free)
    }

    func testClapsSceneLevelToolsAreUnchangedByTheRule() async throws {
        try lock("S02")
        let ui = ScriptedUI(); ui.accept = false
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let out = await tools.run("update_decision", ["key": "palette", "value": "#000006, #FFFFFF, #FF0000, #00FF00"]).text
        XCTAssertTrue(out.hasPrefix("refused by the user"), out)
        XCTAssertNotEqual(file.decisions.palette?.first, "#000006", "refusing changes nothing")
    }

    func testTheViewsOnlyDrawTheCardAndTheModelAsksBeforeApplying() throws {
        let v = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        func src(_ n: String) -> String { (try? String(contentsOf: v.appendingPathComponent(n), encoding: .utf8)) ?? "" }
        let model = src("ProjectModel.swift")
        XCTAssertTrue(model.contains("card.lockWarning != nil") && model.contains("pendingLook = PendingLookChange"), "perform asks first")
        XCTAssertFalse(src("SceneStateViews.swift").contains("isOverridden"), "no rule in a view")
        XCTAssertTrue(src("ChatView.swift").contains("LockedLookNotice(warning: w)"), "Clap's card draws it")
    }
}
