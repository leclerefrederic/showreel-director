import XCTest
@testable import ShowreelKit

/// Phase P1: the design system board, the current-choice partitions, the switches of a scene's look, the confirmation of a look drop, and a scene's
/// composition (every linked resource is an element). The rules are ShowreelKit's; the views only draw them.
final class ErgonomicsTests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("p1"); inbox = makeTempDir("p1-inbox"); store = ProjectStore(root: dir)
        try? store.create(name: "P", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2"), DecisionChange(.background, Look.backgroundIDs()[0]), DecisionChange(.titleFont, "Anton")], title: nil))
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        store.undoLog.clear()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    var file: ShowreelFile { store.loadShowreel()! }
    func scene(_ id: String) -> ShowreelFile.Scene { file.scenes.first { $0.id == id }! }
    func make(_ name: String, _ body: String = "x") -> URL { let u = inbox.appendingPathComponent(name); try? body.write(to: u, atomically: true, encoding: .utf8); return u }
    @discardableResult func add(_ names: [String]) throws -> [AssetRow] { try Assets.add(names.map { make($0) }, to: store) }
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    // MARK: the design system board

    func testTheBoardSaysWhatEachColourIsForAndHowReadableItIs() throws {
        try store.apply(.decisions([DecisionChange(.backgroundMood, "punch"), DecisionChange(.effectsPack, Look.packs()[0].name), DecisionChange(.textFont, "Inter")], title: nil))
        try store.apply(.parameter(.message, "  Notes, finally calm  "))
        let b = DesignBoard.make(file)
        XCTAssertEqual(b.swatches.map { $0.role }, ["Background", "Text", "Accent", "Accent 2"])
        XCTAssertEqual(b.swatches.map { $0.hex }, ["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2"])
        XCTAssertEqual(b.swatches[0].on, "#FFFFFF", "white on the dark background"); XCTAssertEqual(b.swatches[1].on, "#000000", "black on the white text colour")
        XCTAssertEqual(b.contrasts.map { $0.title }, ["Text on background", "Accent on background", "Accent 2 on background"])
        XCTAssertEqual(b.contrasts[0].ratio, Contrast.ratio("#FFFFFF", "#101820"), accuracy: 0.001); XCTAssertEqual(b.contrasts[2].ratio, Contrast.ratio("#4CC2F2", "#101820"), accuracy: 0.001)
        XCTAssertEqual(b.contrasts[0].level, .ok); XCTAssertTrue(b.contrasts.allSatisfy { !$0.detail.isEmpty })
        XCTAssertEqual([b.titleFont, b.textFont], ["Anton", "Inter"]); XCTAssertEqual(b.backgroundMood, "punch"); XCTAssertEqual(b.background, Look.backgroundIDs()[0])
        XCTAssertEqual(b.pack, Look.packs()[0].name)
        XCTAssertTrue(Look.packs()[0].effects.contains(b.sampleEffect), "the sample plays an effect of the chosen pack")
        XCTAssertEqual(b.sampleText, "Notes, finally calm", "the project's message, trimmed")
        XCTAssertTrue(b.hasPalette)
    }

    func testTheBoardOfAnEmptyOrOddProjectStillDraws() throws {
        var f = ShowreelFile(name: "Empty")
        let b = DesignBoard.make(f)
        XCTAssertTrue(b.swatches.isEmpty && b.contrasts.isEmpty && !b.hasPalette)
        XCTAssertNil(b.titleFont); XCTAssertNil(b.background); XCTAssertEqual(b.sampleText, DesignBoard.placeholderText); XCTAssertEqual(b.sampleEffect, "Fade", "a plain default stands in")
        f.decisions.palette = ["red", "#FFFFFF"]
        let odd = DesignBoard.make(f)
        XCTAssertEqual(odd.swatches.count, 2); XCTAssertTrue(odd.contrasts.isEmpty, "no contrast is computed on a colour that is not #RRGGBB")
        f.parameters.message = String(repeating: "word ", count: 30)
        XCTAssertEqual(DesignBoard.make(f).sampleText.count, 40)
        f.decisions.moods = [Look.packs()[1].name]
        XCTAssertTrue(Look.packs()[1].effects.contains(DesignBoard.make(f).sampleEffect), "with no pack, the first mood")
    }

    func testTheBoardFollowsTheDecisionsAtOnce() throws {
        let before = DesignBoard.make(file)
        try store.apply(.decisions([DecisionChange(.palette, "#000000, #FFFF00")], title: nil))
        let after = DesignBoard.make(file)
        XCTAssertNotEqual(before, after); XCTAssertEqual(after.swatches.map { $0.hex }, ["#000000", "#FFFF00"]); XCTAssertEqual(after.contrasts.count, 1)
    }

    // MARK: the current choice, then the others

    func testThePartitionPinsTheCurrentChoiceAndNeverRepeatsIt() {
        let ids = ["a", "b", "c", "d"]
        let p = LookChoices.split(ids, id: { $0 }, current: "c")
        XCTAssertEqual(p.current, "c"); XCTAssertEqual(p.others, ["a", "b", "d"], "order kept, the current one is not repeated")
        XCTAssertNil(LookChoices.split(ids, id: { $0 }, current: "zz").current); XCTAssertEqual(LookChoices.split(ids, id: { $0 }, current: "zz").others, ids)
        XCTAssertNil(LookChoices.split(ids, id: { $0 }, current: nil).current); XCTAssertEqual(LookChoices.split(ids, id: { $0 }, current: "").others, ids)
        let m = LookChoices.split(ids, id: { $0 }, currents: ["d", "a", "nope"])
        XCTAssertEqual(m.current, ["d", "a"], "the current ones in the order chosen"); XCTAssertEqual(m.others, ["b", "c"])
        XCTAssertEqual(LookChoices.split([String](), id: { $0 }, current: "x").others, [])
    }

    func testEachEditorsOptionsSplitCleanlyAroundTheProjectsChoice() throws {
        // looks
        let looks = LookPackages.all(); let p = looks[2]
        XCTAssertNil(LookChoices.currentLook(file), "a mix of choices is not any starting look")
        try store.apply(.decisions(p.decisions, title: "Choose the look: \(p.name)"))
        XCTAssertEqual(LookChoices.currentLook(file), p.id)
        let sl = LookChoices.split(looks, id: { $0.id }, current: LookChoices.currentLook(file))
        XCTAssertEqual(sl.current?.id, p.id); XCTAssertEqual(sl.others.count, looks.count - 1); XCTAssertFalse(sl.others.contains { $0.id == p.id })
        try store.apply(.decisions([DecisionChange(.palette, "#000000, #FFFFFF")], title: nil))
        XCTAssertNil(LookChoices.currentLook(file), "changing one part leaves the look")
        // palettes
        XCTAssertNil(LookChoices.currentPalette(file)); try store.apply(.decisions([DecisionChange(.palette, looks[0].palette.joined(separator: ", "))], title: nil))
        XCTAssertEqual(LookChoices.currentPalette(file), looks[0].id)
        // backgrounds, packs, fonts
        let bgs = Look.backgroundIDs(), cur = file.decisions.background?.id
        let sb = LookChoices.split(bgs, id: { $0 }, current: cur); XCTAssertEqual(sb.others.count, bgs.count - 1); XCTAssertFalse(sb.others.contains(cur ?? "-"))
        try store.apply(.decisions([DecisionChange(.effectsPack, Look.packs()[0].name)], title: nil))
        let sp = LookChoices.split(Look.packs(), id: { $0.name }, current: file.decisions.effectsPack)
        XCTAssertEqual(sp.current?.name, Look.packs()[0].name); XCTAssertEqual(sp.others.count, Look.packs().count - 1)
        try store.apply(.decisions([DecisionChange(.moods, "\(Look.packs()[0].name), \(Look.packs()[1].name)")], title: nil))
        let sm = LookChoices.split(Look.packs(), id: { $0.name }, currents: file.decisions.moods ?? [])
        XCTAssertEqual(sm.current.map { $0.name }, [Look.packs()[0].name, Look.packs()[1].name]); XCTAssertEqual(sm.others.count, Look.packs().count - 2)
    }

    // MARK: a scene's look: one switch per group

    func testBeforeTheSwitchTheSceneShowsTheProjectsValuesLocked() throws {
        let f = file, s = scene("S01")
        for g in SceneLookGroup.allCases { let st = LookOverrides.state(g, scene: s, in: f); XCTAssertTrue(st.locked && !st.overridden, g.rawValue); XCTAssertEqual(st.values, st.project) }
        XCTAssertEqual(LookOverrides.state(.palette, scene: s, in: f).values[.palette], "#101820, #FFFFFF, #F2AA4C, #4CC2F2")
        XCTAssertTrue(LookOverrides.groups(of: s, in: f).isEmpty, "no badge")
        XCTAssertEqual(SceneLookGroup.background.keys, [.background, .backgroundMood]); XCTAssertEqual(SceneLookGroup.fonts.keys, [.titleFont, .textFont])
    }

    func testSwitchingOnTakesTheProjectsValuesForThisSceneAndSwitchingOffGivesThemBack() throws {
        let f = file, s = scene("S01")
        let on = try XCTUnwrap(LookOverrides.enable(.palette, scene: s, in: f))
        let card = try store.plan(on)
        XCTAssertEqual(card.title, "Override the look of S01")
        try store.apply(on)
        XCTAssertTrue(LookOverrides.state(.palette, scene: scene("S01"), in: file).overridden)
        XCTAssertEqual(file.effective(.palette, for: scene("S01")), "#101820, #FFFFFF, #F2AA4C, #4CC2F2", "the film does not change by switching on")
        XCTAssertEqual(LookOverrides.groups(of: scene("S01"), in: file), [.palette], "the badge shows")
        XCTAssertTrue(LookOverrides.groups(of: scene("S02"), in: file).isEmpty, "only this scene")
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.palette, "#000000, #FFFFFF")]))        // edited for this scene
        XCTAssertEqual(file.decisions.palette, ["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2"], "the project is untouched")
        // switching off: the very operation of "Revert to project"
        XCTAssertEqual(LookOverrides.disable(.palette, scene: "S01"), .sceneLook(id: "S01", [DecisionChange(.palette, "")]))
        try store.apply(LookOverrides.disable(.palette, scene: "S01"))
        XCTAssertNil(scene("S01").overrides); XCTAssertTrue(LookOverrides.groups(of: scene("S01"), in: file).isEmpty)
        XCTAssertThrowsError(try store.plan(LookOverrides.disable(.palette, scene: "S01")), "nothing to give back")
    }

    func testTheGroupsAreIndependentAndTheBackgroundGroupHoldsItsMood() throws {
        let s = scene("S02")
        try store.apply(LookOverrides.enable(.background, scene: s, in: file)!)
        try store.apply(.sceneLook(id: "S02", [DecisionChange(.backgroundMood, "tech")]))
        try store.apply(LookOverrides.enable(.fonts, scene: s, in: file)!)
        XCTAssertEqual(LookOverrides.groups(of: scene("S02"), in: file), [.background, .fonts])
        try store.apply(LookOverrides.disable(.background, scene: "S02"))
        XCTAssertEqual(LookOverrides.groups(of: scene("S02"), in: file), [.fonts], "the background and its mood went back, the fonts stay")
        XCTAssertNil(scene("S02").overrides?.background)
    }

    func testThereIsNothingToCopyWhenTheProjectHasNoValueYet() throws {
        try store.apply(.decisions([DecisionChange(.background, "")], title: nil))
        XCTAssertNil(LookOverrides.enable(.background, scene: scene("S01"), in: file), "the editor unlocks, and the first choice creates the override")
        XCTAssertNotNil(LookOverrides.enable(.palette, scene: scene("S01"), in: file))
        XCTAssertNotNil(LookOverrides.enable(.fonts, scene: scene("S01"), in: file), "the title font is there to copy")
    }

    func testAnOverrideAfterTheGoTakesTheGoBackAndUndoGivesItBack() throws {
        for id in ["S01", "S02", "S03"] { try store.apply(.scene(id: id, SceneEdit(status: "ok"))) }
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true)); store.undoLog.clear()
        try store.apply(LookOverrides.enable(.palette, scene: scene("S01"), in: file)!)
        XCTAssertEqual(file.gates["review"], "open"); try store.undo(); XCTAssertEqual(file.gates["review"], "passed"); XCTAssertNil(scene("S01").overrides)
    }

    // MARK: dropping a look on a scene asks first

    func testOnlyADropThatReplacesALookAsksAndItAsksTheShortQuestion() throws {
        let q = "Replace for this scene only?"
        let bg = Look.backgroundIDs()[1], pid = LookPackages.all()[0].id
        XCTAssertEqual(Drops.confirmation(.background(bg), on: .scene("S01")), q)
        XCTAssertEqual(Drops.confirmation(.palette(pid), on: .scene("S01")), q)
        XCTAssertEqual(Drops.confirmation(.look(pid), on: .sceneNode(scene: "S01", group: .look, node: "palette")), q, "a node of the tree stands for the scene")
        XCTAssertNil(Drops.confirmation(.effect("Pop"), on: .contentItem(scene: "S01", item: "c1")))
        XCTAssertNil(Drops.confirmation(.transition("Push"), on: .marker(from: "S01")))
        XCTAssertNil(Drops.confirmation(.resource("logo-01"), on: .scene("S01")))
        XCTAssertNil(Drops.confirmation(.scene("S01"), on: .reelSlot(before: nil)))
        XCTAssertNil(Drops.confirmation(.background(bg), on: .marker(from: "S01")), "a pair that cannot be dropped asks nothing: it is refused")
        // a no changes nothing: asking does not touch the data, and the drop itself is still what it was
        let before = [store.read(ShowreelFile.fileName)]
        _ = Drops.confirmation(.background(bg), on: .scene("S01"))
        XCTAssertEqual([store.read(ShowreelFile.fileName)], before)
        try Drops.drop(.background(bg), on: .scene("S01"), store: store)
        XCTAssertEqual(scene("S01").overrides?.background?.id, bg)
    }

    // MARK: composition: a linked resource is an element

    func testLinkingAResourceMakesItAnElementWithEveryAttributeAuto() throws {
        try add(["Acme Logo.svg", "theme.mp3"])
        try store.apply(.scene(id: "S01", SceneEdit(assets: "logo-01, audio-01")))
        let c = scene("S01").content
        XCTAssertEqual(c.map { $0.type }, ["text", "image", "audio"], "after the words, in the order of the links")
        XCTAssertEqual(c.compactMap { $0.resource }, ["logo-01", "audio-01"])
        XCTAssertTrue(c[1].allAuto && c[2].allAuto, "nothing is fixed for the user")
        XCTAssertEqual(try store.completeComposition(reopenGo: true), [], "idempotent")
        try store.apply(.scene(id: "S01", SceneEdit(note: "again")))
        XCTAssertEqual(scene("S01").content.count, 3, "no duplicate")
        let tree = SceneTree.build(scene("S01"), in: file, assets: Assets.load(store), store: store)
        XCTAssertEqual(tree[0].nodes.map { $0.id }, ["item.c1", "item.c2", "item.c3"])
        XCTAssertFalse(tree[0].nodes.contains { $0.id.hasPrefix("raw.") }, "no linked resource is left outside the composition")
    }

    func testTheOtherWaysToLinkAndWhatCannotBeAnElement() throws {
        try add(["Acme Logo.svg", "Brand.ttf", "client-photo.jpg", "Other logo.svg"])
        try store.apply(.asset(id: "logo-01", status: nil, note: nil, licence: nil, scenes: "S02"))                    // the resource says which scene
        XCTAssertEqual(scene("S02").content.compactMap { $0.resource }, ["logo-01"])
        try store.apply(.scene(id: "S03", SceneEdit(assets: "font-01, photo-01")))
        XCTAssertEqual(scene("S03").content.compactMap { $0.resource }, [], "a font is not shown, and a file that needs attention is not used")
        let tree = SceneTree.build(scene("S03"), in: file, assets: Assets.load(store), store: store)
        XCTAssertEqual(Set(tree[0].nodes.filter { $0.id.hasPrefix("raw.") }.compactMap { $0.assetID }), ["font-01", "photo-01"], "they stay visible, linked")
        try store.apply(.addScene(id: "", SceneEdit(duration: "2", text: "New", assets: "logo-02")))
        XCTAssertEqual(file.scenes.last?.content.compactMap { $0.resource }, ["logo-02"])
        // a drop on a scene is a link: it becomes an element
        try Drops.drop(.resource("logo-02"), on: .scene("S01"), store: store)
        XCTAssertEqual(scene("S01").content.compactMap { $0.resource }, ["logo-02"])
    }

    func testAnElementThatLeavesTakesItsLinkWithItSoItDoesNotComeBack() throws {
        try add(["Acme Logo.svg", "Other logo.svg"])
        try store.apply(.scene(id: "S01", SceneEdit(assets: "logo-01")))
        let item = scene("S01").content.last!.id
        try store.apply(.content(scene: "S01", .remove(item: item)))
        XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.sceneIDs, [], "unlinked with its element")
        try store.apply(.scene(id: "S01", SceneEdit(note: "later")))
        XCTAssertFalse(scene("S01").content.contains { $0.resource == "logo-01" }, "and it does not come back")
        // replacing the resource of an element releases the old one
        try store.apply(.scene(id: "S02", SceneEdit(assets: "logo-01")))
        let it = scene("S02").content.last!.id
        try store.apply(.content(scene: "S02", .update(item: it, ContentEdit(resource: "logo-02"))))
        XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.sceneIDs, []); XCTAssertEqual(Assets.load(store).first { $0.id == "logo-02" }?.sceneIDs, ["S02"])
        XCTAssertEqual(scene("S02").content.compactMap { $0.resource }, ["logo-02"])
        // used twice in one scene: the link stays until the last element goes
        try store.apply(.content(scene: "S02", .add(ContentEdit(type: "image", resource: "logo-02"), after: nil)))
        let twice = scene("S02").content.filter { $0.resource == "logo-02" }.map { $0.id }
        try store.apply(.content(scene: "S02", .remove(item: twice[0])))
        XCTAssertEqual(Assets.load(store).first { $0.id == "logo-02" }?.sceneIDs, ["S02"])
    }

    func testLinkingIsUndoneWithItsElementInOneStep() throws {
        try add(["Acme Logo.svg"]); store.undoLog.clear()
        let before = [store.read(ShowreelFile.fileName), store.read(Assets.manifestPath)]
        try store.apply(.scene(id: "S01", SceneEdit(assets: "logo-01")))
        XCTAssertEqual(store.undoLog.undoCount, 1)
        try store.undo()
        XCTAssertEqual([store.read(ShowreelFile.fileName), store.read(Assets.manifestPath)], before)
    }

    func testAnOldFilesElementsComeWithTheUpdateAndOpeningWritesNothing() throws {
        try add(["Acme Logo.svg", "theme.mp3"])
        // an older project: the manifest links resources to scenes that have no element for them
        var rows = Assets.load(store); rows[0].scene = "S01, S02"; rows[1].scene = "S03"; try Assets.save(rows, store)
        for id in ["S01", "S02", "S03"] { try store.apply(.scene(id: id, SceneEdit(status: "ok"))) }
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true))
        var old = file; old.formatRevision = nil; try store.write(ShowreelFile.fileName, try old.encoded())      // from before the revisions
        let go = file.gates["review"], statuses = file.scenes.map { $0.status }, words = file.scenes.map { $0.text }
        let onDisk = store.read(ShowreelFile.fileName)
        XCTAssertEqual(scene("S01").content.compactMap { $0.resource }, [], "the file as the older version left it")
        _ = ProjectFormat.plan(store); _ = Checks.run(area: "scene", store: store); _ = SceneTree.build(scene("S01"), in: file, assets: Assets.load(store), store: store)
        XCTAssertEqual(store.read(ShowreelFile.fileName), onDisk, "opening and reading write nothing")
        XCTAssertEqual(try Composition.gaps(file, Assets.load(store)).map { "\(file.scenes[$0.scene].id) \($0.asset.id)" }, ["S01 logo-01", "S02 logo-01", "S03 audio-01"])
        try ProjectFormat.update(store)
        XCTAssertEqual(scene("S01").content.compactMap { $0.resource }, ["logo-01"]); XCTAssertEqual(scene("S03").content.last?.type, "audio")
        XCTAssertEqual(file.gates["review"], go, "the Go is left alone"); XCTAssertEqual(file.scenes.map { $0.status }, statuses); XCTAssertEqual(file.scenes.map { $0.text }, words)
        XCTAssertEqual(Assets.load(store).map { $0.scene }, ["S01, S02", "S03"], "the links are untouched")
        XCTAssertFalse(store.undoLog.canUndo, "an update is not something to undo: it has its backup")
    }

    func testAFileFromTheSkillIsNotTakenOverBeforeTheUserActs() throws {
        try add(["Acme Logo.svg"])
        var rows = Assets.load(store); rows[0].scene = "S01"; try Assets.save(rows, store)
        var f = file; f.origin = ShowreelFile.Origin(tool: "skill"); f.formatRevision = nil
        try store.write(ShowreelFile.fileName, try f.encoded())            // exactly as the skill's export leaves it
        let before = store.read(ShowreelFile.fileName)
        _ = ProjectFormat.plan(store); _ = Checks.run(area: "project", store: store)
        XCTAssertEqual(store.read(ShowreelFile.fileName), before)
        XCTAssertEqual(file.origin?.tool, "skill", "the app does not become the owner before the user acts")
        XCTAssertEqual(scene("S01").content.compactMap { $0.resource }, [])
        XCTAssertTrue(ProjectFormat.plan(store)!.changes.contains { $0.contains("owner of showreel.json") }, "and the update says so before it does")
    }

    // MARK: the inspector and the tree speak the same structure

    func testTheTreeAndTheInspectorHaveTheSameThreeGroupsAfterSettings() throws {
        XCTAssertEqual(SceneGroup.allCases, [.composition, .effects, .look])
        let tree = SceneTree.build(scene("S01"), in: file, assets: [], store: store)
        XCTAssertEqual(tree.map { $0.group }, [.composition, .effects, .look])
        XCTAssertEqual(tree[2].nodes.map { $0.title }, ["Background", "Palette", "Fonts"])
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("case settings, composition, effects, look"), "Settings, Composition, Effects, Look")
        for g in ["case .composition: self = .composition", "case .effects: self = .effects", "case .look: self = .look"] { XCTAssertTrue(m.contains(g), g) }
        let i = try source("InspectorViews.swift")
        XCTAssertTrue(i.contains("SceneCompositionTab(id: id)")); XCTAssertFalse(i.contains("SceneContentTab")); XCTAssertFalse(i.contains(".resources:"), "no separate Resources tab")
        XCTAssertTrue(try source("WorkspaceViews.swift").contains("project.selectNode(scene, g.group, nil)"), "a click on a group opens its tab")
    }
}
