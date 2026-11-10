import XCTest
@testable import ShowreelKit

/// Phase W4: timing of each content item inside its scene, and a stage drawn from the content.
final class W4Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    override func setUp() {
        dir = makeTempDir("w4"); store = ProjectStore(root: dir)
        try? store.create(name: "W", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: "Hello")))
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    var scene: ShowreelFile.Scene { file.scenes[0] }

    func item(_ id: String, _ a: Double?, _ b: Double?, text: String = "x") -> ShowreelFile.ContentItem { .init(id: id, type: "text", text: text, timeIn: a, timeOut: b) }
    func sceneWith(_ items: [ShowreelFile.ContentItem], duration: Double? = 4) -> ShowreelFile.Scene { var s = ShowreelFile.Scene(id: "S01", duration: duration); s.content = items; return s }

    // MARK: the rules

    func testTimingIsValidatedInsideTheSceneWithTheWayOut() {
        let d = 4.0
        XCTAssertNil(ContentTiming.validate(ContentTimes(start: 0, end: 4), duration: d)); XCTAssertNil(ContentTiming.validate(ContentTimes(start: 1, end: 2.5), duration: d)); XCTAssertNil(ContentTiming.validate(ContentTimes(), duration: d), "auto is always fine")
        XCTAssertTrue(ContentTiming.validate(ContentTimes(start: -1, end: 2), duration: d)!.contains("cannot be before the start"))
        XCTAssertTrue(ContentTiming.validate(ContentTimes(start: 0, end: 4.5), duration: d)!.contains("cannot be after the end of the scene (4 s)"))
        XCTAssertTrue(ContentTiming.validate(ContentTimes(start: 2, end: 2), duration: d)!.contains("at least 0.1 s after In"), "In before Out")
        XCTAssertTrue(ContentTiming.validate(ContentTimes(start: 3, end: 2), duration: d)!.contains("at least 0.1 s after In"))
        XCTAssertTrue(ContentTiming.validate(ContentTimes(start: 3.95, end: nil), duration: d)!.contains("before the end"))
        XCTAssertNil(ContentTiming.validate(ContentTimes(start: 100, end: 120), duration: nil), "with no duration only the order is checked")
        XCTAssertNotNil(ContentTiming.validate(ContentTimes(start: nil, end: 0.05), duration: nil))
    }

    func testActiveItemsAtSeveralTimesWithOverlapAndTheLastInstant() {
        let s = sceneWith([item("c1", nil, nil), item("c2", 1, 3), item("c3", 2, nil), item("c4", nil, 1)])
        func ids(_ t: Double) -> [String] { ContentTiming.active(in: s, at: t).map { $0.id } }
        XCTAssertEqual(ids(0), ["c1", "c4"], "an item with no timing is there all along; Out is not included")
        XCTAssertEqual(ids(1), ["c1", "c2"], "at Out the item has left, at In the next one is there")
        XCTAssertEqual(ids(2.5), ["c1", "c2", "c3"], "overlap is allowed, in priority order")
        XCTAssertEqual(ids(3), ["c1", "c3"])
        XCTAssertEqual(ids(4), ["c1", "c3"], "an item that runs to the end is still there on the last instant")
        XCTAssertEqual(ContentTiming.active(in: sceneWith([item("c1", 1, 3)]), at: 3).count, 0, "an item that ends before the end has left at Out")
    }

    func testDurationShrinkAndGrowMoveTheTimes() {
        var s = sceneWith([item("c1", 1, 4), item("c2", 3, 3.5), item("c3", 0.5, 2), item("c4", nil, nil)])
        let lines = ContentTiming.follow(&s, from: 4, to: 2)
        XCTAssertEqual(s.content[0].timing, ContentTimes(start: 1, end: 2), "an Out past the new end is pulled back to it")
        XCTAssertEqual(s.content[1].timing, ContentTimes(start: 1.9, end: 2), "an In past the new end keeps 0.1 s before it")
        XCTAssertEqual(s.content[2].timing, ContentTimes(start: 0.5, end: 2), "what fits is untouched")
        XCTAssertFalse(s.content[3].timing.isFixed, "auto stays auto")
        XCTAssertEqual(lines.count, 2, "the card names the items that moved")
        var g = sceneWith([item("c1", 1, 4), item("c2", 1, 3)])
        ContentTiming.follow(&g, from: 4, to: 6)
        XCTAssertEqual(g.content[0].timing, ContentTimes(start: 1, end: 6), "an Out that was the old end follows a longer scene")
        XCTAssertEqual(g.content[1].timing, ContentTimes(start: 1, end: 3), "any other time stays")
    }

    func testResizingASceneMovesTheItemsOfItWithTheCardLines() throws {
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 1, end: 4)))))
        try store.apply(.resize(scene: "S01", duration: 2))
        XCTAssertEqual(scene.content[0].timing, ContentTimes(start: 1, end: 2))
        let card = try store.plan(.resize(scene: "S01", duration: 3))
        XCTAssertTrue(card.changes.contains { $0.label.contains("c1 timing") && $0.after.contains("out 3 s") }, "an Out that was the end follows the scene when it grows, and the card says so")
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 1, end: 1.5)))))
        let still = try store.plan(.resize(scene: "S01", duration: 3))
        XCTAssertFalse(still.changes.contains { $0.label.contains("c1 timing") }, "an Out that was not the end stays where it is")
    }

    // MARK: the project file

    func testAnOldProjectOpensAndSavesUnchangedWithNoInOrOut() throws {
        let json = ##"{"schema": 1, "name": "M", "scenes": [{"id": "S01", "duration": 3, "text": "Hi", "content": [{"id": "c1", "type": "text", "text": "Hi", "color": {"mode": "auto"}, "animation": {"mode": "auto"}, "futureKey": 7}]}]}"##
        let f = try ShowreelFile.decode(json)
        XCTAssertFalse(f.scenes[0].content[0].timing.isFixed); XCTAssertTrue(f.scenes[0].content[0].allAuto)
        let out = String(data: try JSONEncoder().encode(f), encoding: .utf8)!
        XCTAssertFalse(out.contains("\"in\"") || out.contains("\"out\""), "no timing is written for an item that has none")
        XCTAssertTrue(out.contains("futureKey"), "an unknown key is kept")
        let t = try ShowreelFile.decode(##"{"schema": 1, "name": "M", "scenes": [{"id": "S01", "duration": 3, "content": [{"id": "c1", "type": "text", "text": "Hi", "in": 0.5, "out": 2}]}]}"##)
        XCTAssertEqual(t.scenes[0].content[0].timing, ContentTimes(start: 0.5, end: 2))
        let back = String(data: try JSONEncoder().encode(t), encoding: .utf8)!
        XCTAssertTrue(back.contains("\"in\"") && back.contains("\"out\""), "the keys are in and out")
    }

    // MARK: the typed operations

    func testTheTimingIsSetByATypedOperationRefusedOutsideTheSceneAndClearedToAuto() throws {
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 1, end: 2.5)))))
        XCTAssertEqual(scene.content[0].timeIn, 1); XCTAssertEqual(scene.content[0].timeOut, 2.5)
        XCTAssertThrowsError(try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 1, end: 9)))))) { XCTAssertTrue("\($0)".contains("after the end of the scene (4 s)")) }
        XCTAssertEqual(scene.content[0].timeOut, 2.5, "a refused value writes nothing")
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes()))))
        XCTAssertFalse(scene.content[0].timing.isFixed, "both bounds cleared: auto again")
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Second", times: ContentTimes(start: 2, end: 3)), after: nil)))
        XCTAssertEqual(scene.content[1].timing, ContentTimes(start: 2, end: 3), "a new item can carry its timing")
        let card = try store.plan(.content(scene: "S01", .update(item: "c2", ContentEdit(times: ContentTimes(start: 2.5, end: 3.5)))))
        XCTAssertTrue(card.changes.contains { $0.label.contains("timing") && $0.after.contains("in 2.5 s, out 3.5 s") })
    }

    func testALockedSceneRefusesTheTimingAndSaysWhy() throws {
        try store.apply(.scene(id: "S01", SceneEdit(status: "validated")))
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        XCTAssertThrowsError(try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 1, end: 2))))))
        let u = try XCTUnwrap(Availability.edit(.item(scene: "S01", item: "c1"), in: ProjectActivity.Snapshot(), file: file).why)
        XCTAssertEqual(u.cause, .locked); XCTAssertEqual(u.reason, "S01 is locked"); XCTAssertTrue(u.way.contains("Unlock"))
    }

    func testTimingEditsOfOneFieldInTwoSecondsAreOneUndoStep() throws {
        let base = store.undoLog.undoCount, key = "item:S01:c1:times"
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 0.5, end: 3))))); store.coalesceLast(key: key, now: at(0))
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 1, end: 3))))); store.coalesceLast(key: key, now: at(1))
        XCTAssertEqual(store.undoLog.undoCount, base + 1, "one step")
        try store.undo(); XCTAssertFalse(scene.content[0].timing.isFixed, "Undo restores the timing from before the first edit")
    }

    func testTheStoryboardColumnAndTheBuildMessageCarryTheTiming() throws {
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 1, end: 3)))))
        XCTAssertTrue(ProjectDocs.visualColumn(scene).contains("in 1 s, out 3 s"))
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes()))))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "B"), after: nil)))
        let brief = BuildRunner.contentBrief(file)
        XCTAssertTrue(brief.contains("timing in the scene: AUTO"))
        try store.apply(.content(scene: "S01", .update(item: "c2", ContentEdit(times: ContentTimes(start: 2, end: 4)))))
        XCTAssertTrue(BuildRunner.contentBrief(file).contains("timing in the scene: FIXED in 2 s, out 4 s"))
    }

    // MARK: the stage

    func testTheStageResolvesColoursFromThePaletteAndDrawsAutoNeutralAndFlagged() throws {
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(color: "accent"))))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Custom", color: "#112233"), after: nil)))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Auto"), after: nil)))
        let f = Stage.frame(of: scene, in: file, at: 1)
        XCTAssertEqual(f.texts.map { $0.text }, ["Hello", "Custom", "Auto"])
        XCTAssertEqual(f.texts[0].colorHex, "#F2AA4C", "a palette role is resolved from the project's palette"); XCTAssertFalse(f.texts[0].colorIsAI)
        XCTAssertEqual(f.texts[1].colorHex, "#112233")
        XCTAssertNil(f.texts[2].colorHex, "an auto colour is not invented"); XCTAssertTrue(f.texts[2].colorIsAI); XCTAssertTrue(f.texts[2].animationIsAI)
        XCTAssertTrue(f.aiDecides); XCTAssertEqual(f.backgroundHex, "#101820")
        XCTAssertTrue(Stage.description(of: f, scene: scene).contains("The AI decides"))
    }

    func testTheStageShowsOnlyTheItemsActiveAtThatTime() throws {
        try store.apply(.content(scene: "S01", .update(item: "c1", ContentEdit(times: ContentTimes(start: 0, end: 2)))))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Late", times: ContentTimes(start: 2, end: 4)), after: nil)))
        XCTAssertEqual(Stage.frame(of: scene, in: file, at: 1).texts.map { $0.text }, ["Hello"])
        XCTAssertEqual(Stage.frame(of: scene, in: file, at: 3).texts.map { $0.text }, ["Late"])
        XCTAssertTrue(Stage.frame(of: sceneWith([item("c1", 1, 2)]), in: nil, at: 3).items.isEmpty)
    }

    func testAnImageComesFromItsResource() {
        var s = sceneWith([item("c1", nil, nil)]); s.content.append(.init(id: "c2", type: "image", resource: "logo-01"))
        let f = Stage.frame(of: s, in: nil, at: 1)
        XCTAssertEqual(f.images.map { $0.resource }, ["logo-01"]); XCTAssertNil(f.images[0].colorHex); XCTAssertFalse(f.images[0].colorIsAI, "a colour applies to words only")
    }

    // MARK: the thumbnails and the viewer

    func testAScenePicturedOnceUnlessItsStillsReallyDiffer() {
        XCTAssertEqual(ContentTiming.stills(of: sceneWith([item("c1", nil, nil), item("c2", nil, nil)]), limit: 4).count, 1, "no timing: one thumbnail")
        XCTAssertEqual(ContentTiming.stills(of: sceneWith([item("c1", nil, nil)]), limit: 4), [3], "three quarters through, as the strip always did")
        XCTAssertEqual(ContentTiming.stills(of: sceneWith([item("c1", 0, 2), item("c2", 0, 2)]), limit: 4).count, 1, "two items that come and go together are one still")
        let two = ContentTiming.stills(of: sceneWith([item("c1", 0, 2), item("c2", 2, 4)]), limit: 4); XCTAssertEqual(two, [1, 3], "two states that differ: two stills, at the middle of each")
        XCTAssertEqual(ContentTiming.stills(of: sceneWith([item("c1", 0, 1), item("c2", 1, 2), item("c3", 2, 3), item("c4", 3, 4)]), limit: 3).count, 3, "never more than the limit")
        XCTAssertEqual(ContentTiming.stills(of: sceneWith([item("c1", 0, 1), item("c2", 2, 4)]), limit: 4).count, 2, "nothing on screen is not a still")
        XCTAssertEqual(ContentTiming.stills(of: sceneWith([]), limit: 4).count, 1)
        // the strip lays out the tiles only when the stills differ and the frame is wide enough for each at the 16:9 shape
        let one = FrameLayout.elements(width: 600, height: 120, hasName: false), many = FrameLayout.elements(width: 600, height: 120, hasName: false, stills: 3), narrow = FrameLayout.elements(width: 100, height: 120, hasName: false, stills: 3)
        XCTAssertEqual(one.thumbTiles, 1); XCTAssertEqual(many.thumbTiles, 3); XCTAssertEqual(narrow.thumbTiles, 1, "a narrow frame keeps one")
        XCTAssertEqual(many.thumb.width, many.thumbWidth * 3, accuracy: 0.001)
    }

    func testTheViewerFollowsThePlayheadAndKnowsHowFarIntoTheScene() throws {
        try store.apply(.addScene(id: "", SceneEdit(duration: "2", text: "Two")))
        let f = file
        XCTAssertEqual(TimelineNav.sceneAndTime(at: 1, in: f)?.scene.id, "S01"); XCTAssertEqual(TimelineNav.sceneAndTime(at: 1, in: f)?.time ?? -1, 1, accuracy: 0.001)
        let b = try XCTUnwrap(TimelineNav.sceneAndTime(at: 5, in: f)); XCTAssertEqual(b.scene.id, "S02"); XCTAssertEqual(b.time, 1, accuracy: 0.001, "1 s into the second scene")
        XCTAssertEqual(TimelineNav.sceneAndTime(at: 6, in: f)?.scene.id, "S02", "the very end belongs to the last scene")
        XCTAssertNil(TimelineNav.sceneAndTime(at: 99, in: f))
    }

    func testTheViewsDrawFromTheRulesAndNeverFromTheirOwn() throws {
        let views = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        func src(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }
        let stage = try src("StageViews.swift"), ws = try src("WorkspaceViews.swift"), tl = try src("TimelineViews.swift"), cv = try src("ContentViews.swift"), iv = try src("InspectorViews.swift")
        XCTAssertTrue(stage.contains("Stage.frame(of: scene") && stage.contains("Stage.description") && stage.contains("AI decides"), "the picture is the stage model, flagged and described")
        XCTAssertTrue(ws.contains("if scene.content.isEmpty { EngineSceneThumb") && ws.contains("StageThumb(scene: scene, time: time ?? ContentTiming.stillTime(of: scene)"))
        XCTAssertTrue(tl.contains("SceneFrameImage(scene: scene)") && !tl.contains("SceneThumb("), "W4b: the strip shows the captured PNG, not the schematic drawing")
        XCTAssertTrue(cv.contains("ContentTiming.validate(t, duration: sceneDuration)") && cv.contains("ContentEdit(times:") && cv.contains("undoKey: \"item:\\(scene):\\(item.id):times\""), "the control validates, then writes through the operation, grouped for undo")
        XCTAssertTrue(cv.contains(".disabledWithReason(sceneDuration == nil"), "no silent disabled control")
        XCTAssertTrue(iv.contains("project.sceneAtPlayhead?.time"), "the viewer follows the playhead into the scene")
    }
}
