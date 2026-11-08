import XCTest
@testable import ShowreelKit

/// Phase W1c: a scene's content items, the control level, the checks of fixed values, the build message.
final class ContentTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("w1c"); store = ProjectStore(root: dir)
        try? store.create(name: "C", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: "Hello")))
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    var items: [ShowreelFile.ContentItem] { file.scenes[0].content }

    func logo() throws -> String {
        let inbox = makeTempDir("inbox-w1c"); defer { try? FileManager.default.removeItem(at: inbox) }
        let u = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: u, atomically: true, encoding: .utf8)
        try Assets.add([u], to: store)
        return "logo-01"
    }

    // MARK: data

    func testTheCurrentTextBecomesOneTextItemWithEveryAttributeAuto() throws {
        let f = try ShowreelFile.decode(##"{"schema": 1, "name": "M", "scenes": [{"id": "S01", "duration": 3, "text": "Notes, finally calm", "visual": "Logo rises"}, {"id": "S02", "duration": 2}], "futureKey": 1}"##)
        XCTAssertEqual(f.scenes[0].content, [.init(id: "c1", type: "text", text: "Notes, finally calm")])
        XCTAssertTrue(f.scenes[0].content[0].allAuto, "colour auto, animation auto, no instruction")
        XCTAssertEqual(f.scenes[0].text, "Notes, finally calm", "the text is still there")
        XCTAssertEqual(f.scenes[0].visual, "Logo rises", "the note is kept")
        XCTAssertTrue(f.scenes[1].content.isEmpty, "no words, no item")
        XCTAssertNil(f.scenes[0].controlLevel); XCTAssertNil(f.parameters.controlLevel)
        XCTAssertEqual(f.unknown["futureKey"], .number(1))
    }

    func testRoundTripKeepsUnknownKeysEverywhere() throws {
        let json = ##"{"schema": 1, "name": "R", "parameters": {"controlLevel": "guided", "pk": 1}, "scenes": [{"id": "S01", "controlLevel": "precise", "text": "Hi", "content": [{"id": "c1", "type": "text", "text": "Hi", "color": {"mode": "role", "role": "accent", "cx": 1}, "animation": {"mode": "effect", "effect": "Pop", "params": {"speed": 2}, "ax": true}, "instruction": "big", "in": 0.5, "out": 2}, {"id": "c2", "type": "shape", "shape": "rect"}]}]}"##
        let f = try ShowreelFile.decode(json)
        let i = f.scenes[0].content[0]
        XCTAssertEqual(i.color.role, "accent"); XCTAssertEqual(i.animation.effect, "Pop"); XCTAssertEqual(i.instruction, "big")
        XCTAssertEqual(i.unknown["in"], .number(0.5), "timing inside the scene (later phase) survives")
        XCTAssertEqual(f.scenes[0].content[1].unknown["shape"], .string("rect"), "a type this version does not know is kept")
        XCTAssertEqual(f.parameters.controlLevel, "guided"); XCTAssertEqual(f.scenes[0].controlLevel, "precise")
        let back = try ShowreelFile.decode(try f.encoded())
        XCTAssertEqual(back, f)
        XCTAssertEqual(back.scenes[0].content[0].animation.unknown["ax"], .bool(true))
        XCTAssertEqual(back.parameters.unknown["pk"], .number(1))
    }

    func testTheEffectLibraryIsReadFromTheSkill() {
        let all = Look.effects()
        XCTAssertGreaterThanOrEqual(all.count, 240)
        XCTAssertTrue(all.contains("Pop") && all.contains("Cut on beat"))
        XCTAssertEqual(Look.effectCategory("Cut on beat"), EngineCatalogue.transitionCategory)
        for p in Look.packs() { for e in p.effects { XCTAssertTrue(all.contains(e), "\(p.name): \(e)") } }
    }

    // MARK: operations

    func testAddUpdateMoveRemoveAreCardsAndKeepTheTextInStep() throws {
        XCTAssertEqual(items.map { $0.id }, ["c1"], "adding a scene with words made its first text item")
        let card = try store.plan(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Second line", color: "accent", animation: "Pop", params: "speed=2", instruction: "bigger"), after: nil)))
        XCTAssertEqual(card.title, "Add text item to S01")
        XCTAssertTrue(card.changes[0].after.contains("Second line") && card.changes[0].after.contains("colour Accent") && card.changes[0].after.contains("Pop (speed=2)"))
        XCTAssertEqual(items.count, 1, "planning writes nothing")
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Second line", color: "accent", animation: "Pop", params: "speed=2", instruction: "bigger"), after: nil)), expecting: card)
        XCTAssertEqual(items.map { $0.id }, ["c1", "c2"])
        XCTAssertEqual(items[1].color, .init(mode: "role", role: "accent")); XCTAssertEqual(items[1].animation.params, .object(["speed": .number(2)]))
        // priority
        let mv = try store.plan(.content(scene: "S01", .move(item: "c2", after: "start")))
        XCTAssertEqual(mv.changes.first, Change("Priority of S01 c2", "2", "1"))
        try store.apply(.content(scene: "S01", .move(item: "c2", after: "start")))
        XCTAssertEqual(items.map { $0.id }, ["c2", "c1"])
        XCTAssertEqual(file.scenes[0].text, "Second line", "the first text item holds the scene's text")
        XCTAssertEqual(file.contentPosition(scene: "S01", item: "c2", by: 1), "c1")
        XCTAssertNil(file.contentPosition(scene: "S01", item: "c2", by: -1))
        XCTAssertThrowsError(try store.plan(.content(scene: "S01", .move(item: "c2", after: "start"))), "already there")
        // update: only what changes shows
        let up = try store.plan(.content(scene: "S01", .update(item: "c2", ContentEdit(color: "#00FF00"))))
        XCTAssertEqual(up.changes, [Change("S01 c2 colour", "Accent (fixed)", "#00FF00 (fixed)")])
        try store.apply(.content(scene: "S01", .update(item: "c2", ContentEdit(color: "auto", animation: "auto"))))
        XCTAssertTrue(items[0].color == .init() && items[0].animation == .init(), "auto hands the attribute back")
        // remove
        try store.apply(.content(scene: "S01", .remove(item: "c2")))
        XCTAssertEqual(items.map { $0.id }, ["c1"]); XCTAssertEqual(file.scenes[0].text, "Hello")
    }

    func testRefusalsHaveReasons() throws {
        func refuse(_ op: ContentOp, _ needle: String, line: UInt = #line) {
            XCTAssertThrowsError(try store.plan(.content(scene: "S01", op)), line: line) { XCTAssertTrue("\($0)".contains(needle), "\($0)", line: line) }
        }
        refuse(.add(ContentEdit(type: "text", text: "x", color: "fuchsia"), after: nil), "not a colour")
        refuse(.add(ContentEdit(type: "text", text: "x", animation: "No Such Effect"), after: nil), "not in the library")
        refuse(.add(ContentEdit(type: "text"), after: nil), "needs its words")
        refuse(.add(ContentEdit(type: "image"), after: nil), "needs a resource")
        refuse(.add(ContentEdit(type: "image", resource: "logo-77"), after: nil), "unknown asset")
        refuse(.add(ContentEdit(type: "shape"), after: nil), "text, image or audio")
        refuse(.add(ContentEdit(type: "text", text: "x", animation: "Pop", params: "speed"), after: nil), "key=value")
        refuse(.add(ContentEdit(type: "text", text: "x", params: "speed=1"), after: nil), "need an effect")
        refuse(.update(item: "c9", ContentEdit(text: "x")), "no item c9")
        refuse(.update(item: "c1", ContentEdit(text: "Hello")), "no change")
        refuse(.update(item: "c1", ContentEdit(type: "image")), "type does not change")
        refuse(.update(item: "c1", ContentEdit(params: "a=1")), "need an effect")
        refuse(.remove(item: "c9"), "no item c9")
        XCTAssertThrowsError(try store.plan(.content(scene: "S09", .remove(item: "c1"))))
        let id = try logo()
        refuse(.add(ContentEdit(type: "audio", resource: id), after: nil), "is a logo")
        refuse(.add(ContentEdit(type: "image", resource: id, color: "accent"), after: nil), "text only")
        try store.apply(.asset(id: id, status: .excluded, note: nil, licence: nil, scenes: nil))
        refuse(.add(ContentEdit(type: "image", resource: id), after: nil), "excluded")
    }

    func testAnImageItemLinksTheResourceToTheScene() throws {
        let id = try logo()
        let card = try store.plan(.content(scene: "S01", .add(ContentEdit(type: "image", resource: id), after: nil)))
        XCTAssertTrue(card.changes.contains { $0.label == "Linked assets" })
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "image", resource: id), after: nil)))
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, ["S01"], "the manifest says where it is used, as the skill wants")
        XCTAssertEqual(items.map { $0.type }, ["text", "image"])
        XCTAssertEqual(file.scenes[0].text, "Hello", "an image does not touch the words")
    }

    func testEditingTheSceneTextKeepsTheFirstItemInStep() throws {
        try store.apply(.scene(id: "S01", SceneEdit(text: "Changed")))
        XCTAssertEqual(items[0].text, "Changed")
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "text"))))
        try store.apply(.scene(id: "S01", SceneEdit(text: "")))
        XCTAssertEqual(items.count, 1, "an item with something fixed is kept even without words")
        XCTAssertEqual(file.scenes[0].text, "")
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "auto"))))
        try store.apply(.scene(id: "S01", SceneEdit(text: "Back")))
        XCTAssertEqual(items[0].text, "Back")
        try store.apply(.scene(id: "S01", SceneEdit(text: "")))
        XCTAssertTrue(items.isEmpty, "an all-auto item without words goes away")
    }

    func testChangingContentSendsTheSceneBackToReviewAndAfterTheGoTakesTheGoBack() throws {
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true))
        let card = try store.plan(.content(scene: "S01", .add(ContentEdit(type: "text", text: "More"), after: nil)))
        XCTAssertTrue(card.changes.contains(Change("Go", "given", "to be given again")))
        XCTAssertTrue(card.changes.contains(Change("Status", "ok", "open")))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "More"), after: nil)))
        XCTAssertEqual(file.gates["review"], "open"); XCTAssertEqual(file.scenes[0].status, "open")
        // priority alone is a change of the film too
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok"))); try store.apply(.gate("review", passed: true))
        try store.apply(.content(scene: "S01", .move(item: "c2", after: "start")))
        XCTAssertEqual(file.gates["review"], "open")
    }

    // MARK: control level

    func testControlLevelSetsTheDefaultsOfNewItems() throws {
        XCTAssertEqual(file.controlLevel(for: file.scenes[0]), .auto, "auto when nothing says otherwise")
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "A"), after: nil)))
        XCTAssertTrue(items.last!.allAuto, "auto: only the words")
        try store.apply(.parameter(.controlLevel, "guided"))
        XCTAssertEqual(file.controlLevel(for: file.scenes[0]), .guided, "the project's default")
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "B"), after: nil)))
        XCTAssertEqual(items.last?.color, .init(mode: "role", role: "text")); XCTAssertFalse(items.last!.animation.isFixed, "guided fixes the colour of words")
        try store.apply(.scene(id: "S01", SceneEdit(controlLevel: "precise")))
        XCTAssertEqual(file.controlLevel(for: file.scenes[0]), .precise, "the scene's own level wins")
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "C"), after: nil)))
        XCTAssertTrue(items.last!.color.isFixed && items.last!.animation.isFixed, "precise fixes everything")
        XCTAssertTrue(Look.effects().contains(items.last!.animation.effect ?? ""))
        // any attribute still overrides the default
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "D", color: "auto", animation: "auto"), after: nil)))
        XCTAssertTrue(items.last!.allAuto)
        try store.apply(.scene(id: "S01", SceneEdit(controlLevel: "")))
        XCTAssertNil(file.scenes[0].controlLevel)
        XCTAssertThrowsError(try store.plan(.parameter(.controlLevel, "wild"))); XCTAssertThrowsError(try store.plan(.scene(id: "S01", SceneEdit(controlLevel: "wild"))))
    }

    // MARK: checks of fixed values

    func contentCheck() -> CheckResult? { Checks.run(area: "scene", store: store).first { $0.id == "content.S01" } }

    func testChecksOfFixedValues() throws {
        XCTAssertEqual(contentCheck()?.level, .ok, "all auto: nothing to contradict")
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "accent", animation: "Pop"))))
        XCTAssertEqual(contentCheck()?.level, .ok)
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "background"))))
        XCTAssertEqual(contentCheck()?.level, .fail, "text in the background's colour")
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "#101821"))))
        XCTAssertEqual(contentCheck()?.level, .fail, "a colour too close to the background")
        XCTAssertTrue(contentCheck()?.detail.contains("contrast") == true)
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "accent2"))))
        XCTAssertEqual(contentCheck()?.level, .ok)
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C")], title: nil))
        XCTAssertEqual(contentCheck()?.level, .fail, "the palette has no accent 2 any more")
        XCTAssertTrue(contentCheck()?.detail.contains("no accent 2") == true)
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "auto", animation: "Cut on beat"))))
        XCTAssertEqual(contentCheck()?.level, .tight, "a scene transition used as an animation")
        // a hand-edited file with an effect the library does not have, and an unapproved resource
        let id = try logo()
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "image", resource: id), after: nil)))
        XCTAssertTrue(contentCheck()?.detail.contains("proposed") == true, "a resource that is not approved")
        var f = file; f.scenes[0].content[0].animation = .init(mode: "effect", effect: "Zorp"); try store.save(f)
        XCTAssertEqual(contentCheck()?.level, .fail); XCTAssertTrue(contentCheck()?.detail.contains("Zorp") == true)
        try store.apply(.asset(id: id, status: .approved, note: nil, licence: nil, scenes: nil))
        XCTAssertFalse(contentCheck()?.detail.contains("proposed") == true)
    }

    // MARK: tree, markdown, build message, tools

    func testTheTreeFollowsTheContent() throws {
        let id = try logo()
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "image", resource: id, animation: "Pop"), after: nil)))
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(animation: "Pop"))))
        let f = file
        let tree = SceneTree.build(f.scenes[0], in: f, assets: Assets.load(store), store: store)
        XCTAssertEqual(tree[0].nodes.map { $0.id }, ["item.c2"], "Raw lists the image item, once")
        XCTAssertEqual(tree[0].nodes.first?.assetID, id)
        XCTAssertEqual(tree[1].nodes.map { $0.id }, ["item.c1"], "Texts lists the text items")
        XCTAssertEqual(tree[2].nodes.map { $0.title }, ["Pop"]); XCTAssertEqual(tree[2].nodes.first?.detail, "on c1, c2", "Effects lists the effects the items use")
    }

    func testStoryboardMarkdownKeepsTheVisualColumnReadableAndDoesNotPolluteTheNote() throws {
        try store.apply(.scene(id: "S01", SceneEdit(visual: "Logo rises")))
        XCTAssertEqual(ProjectDocs.visualColumn(file.scenes[0]), "Logo rises", "words left to the AI add nothing")
        let id = try logo()
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "accent"))))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "image", resource: id), after: nil)))
        let md = try XCTUnwrap(store.read("storyboard.md"))
        XCTAssertTrue(md.contains("Logo rises Content in priority order: 1. text \u{201C}Hello\u{201D} [colour Accent]; 2. image logo-01"), md)
        // read back, the generated summary does not become the scene's note
        var f = file
        MarkdownRead.apply(storyboard: md, to: &f)
        XCTAssertEqual(f.scenes[0].visual, "Logo rises")
        XCTAssertEqual(f.scenes[0].content, file.scenes[0].content)
        // the user edits the words in the table: the first text item follows
        MarkdownRead.apply(storyboard: md.replacingOccurrences(of: "| Hello ", with: "| Hello again "), to: &f)
        XCTAssertEqual(f.scenes[0].content[0].text, "Hello again"); XCTAssertEqual(f.scenes[0].content[0].color.role, "accent", "its fixed colour stays")
    }

    func testTheBuildMessageListsItemsInPriorityWithFixedAndAuto() throws {
        try store.apply(.scene(id: "S01", SceneEdit(controlLevel: "guided")))
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "accent", instruction: "land on the beat"))))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Second", animation: "Pop", params: "speed=2"), after: "start")))
        let p = BuildRunner.prompt(version: "v1", store: store)
        XCTAssertTrue(p.contains("S01 (control level guided):"))
        let a = try XCTUnwrap(p.range(of: "1. text \u{201C}Second\u{201D}")), b = try XCTUnwrap(p.range(of: "2. text \u{201C}Hello\u{201D}"))
        XCTAssertLessThan(a.lowerBound, b.lowerBound, "priority order")
        XCTAssertTrue(p.contains("colour: FIXED Text (#FFFFFF); animation: FIXED Pop (speed=2)"), "guided: a new item has its colour fixed by default")
        XCTAssertTrue(p.contains("colour: FIXED Accent (#F2AA4C); animation: AUTO; instruction: \u{201C}land on the beat\u{201D}"))
        for needle in ["FIXED", "AUTO", "honour it strictly", "drop the last items first", "not the stacking order"] { XCTAssertTrue(p.contains(needle), needle) }
    }

    func testToolsAddUpdateMoveRemove() async throws {
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let a = await tools.run("add_content_item", ["scene": "S01", "type": "text", "text": "Two", "color": "accent"]).text
        XCTAssertTrue(a.hasPrefix("accepted and applied"), a)
        let u = await tools.run("update_content_item", ["scene": "S01", "item": "c2", "animation": "Pop", "params": "speed=3"]).text
        XCTAssertTrue(u.hasPrefix("accepted and applied"), u)
        let m = await tools.run("move_content_item", ["scene": "S01", "item": "c2", "after": "start"]).text
        XCTAssertTrue(m.hasPrefix("accepted and applied"), m)
        XCTAssertEqual(items.map { $0.id }, ["c2", "c1"])
        let bad = await tools.run("update_content_item", ["scene": "S01", "item": "c2", "animation": "Nope"]).text
        XCTAssertTrue(bad.hasPrefix("refused"), bad)
        let r = await tools.run("remove_content_item", ["scene": "S01", "item": "c2"]).text
        XCTAssertTrue(r.hasPrefix("accepted and applied"), r)
        XCTAssertEqual(ui.cards.last?.title, "Remove text item c2 from S01")
        let lvl = await tools.run("update_parameter", ["key": "controlLevel", "value": "guided"]).text
        XCTAssertTrue(lvl.hasPrefix("accepted and applied"), lvl)
        let names = Tools.definitions.compactMap { $0["name"] as? String }
        XCTAssertTrue(["add_content_item", "update_content_item", "remove_content_item", "move_content_item"].allSatisfy { names.contains($0) })
    }

    func testDuplicatingAScenesContentEditCopiesTheItem() throws {
        let it = ShowreelFile.ContentItem(id: "c1", type: "text", text: "W", color: .init(mode: "custom", hex: "#AA0000"), animation: .init(mode: "effect", effect: "Pop", params: .object(["speed": .number(2)])), instruction: "go")
        let e = it.edit
        XCTAssertEqual(e, ContentEdit(type: "text", text: "W", resource: nil, color: "#AA0000", animation: "Pop", params: "speed=2", instruction: "go"))
        try store.apply(.content(scene: "S01", .add(e, after: nil)))
        XCTAssertEqual(items.last?.color, it.color); XCTAssertEqual(items.last?.animation, it.animation)
    }
}
