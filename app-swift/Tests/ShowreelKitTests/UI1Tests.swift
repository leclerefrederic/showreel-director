import XCTest
@testable import ShowreelKit

/// Phase UI1: the left panel is the Storyboard (a flat list) with the Resources below. The rules are ShowreelKit's; the views only draw them.
final class UI1Tests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!

    override func setUp() {
        dir = makeTempDir("ui1"); inbox = makeTempDir("ui1-inbox"); store = ProjectStore(root: dir)
        try? store.create(name: "U", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        store.undoLog.clear()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    var file: ShowreelFile { store.loadShowreel()! }
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }
    func list() -> StoryboardList { StoryboardList.build(file, store: store) }

    // MARK: the flat list (UI2 changed the wording of the lines and merged archived and ditched scenes into hidden ones)

    func testScenesInOrderWithOneLineBetweenTwoOfThem() throws {
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Cross dissolve", duration: 0.8)))
        let l = list()
        XCTAssertEqual(l.entries.map { $0.id }, ["scene:S01", "transition:S01", "scene:S02", "transition:S02", "scene:S03"], "no line after the last scene")
        guard case .transition(let t) = l.entries[1] else { return XCTFail() }
        XCTAssertEqual(t.from, "S01"); XCTAssertEqual(t.to, "S02"); XCTAssertEqual(t.text, "Cross dissolve \u{00B7} 0.8 s"); XCTAssertFalse(t.isCut); XCTAssertEqual(t.tooltip, "S01 to S02")
        guard case .transition(let cut) = l.entries[3] else { return XCTFail() }
        XCTAssertEqual(cut.text, "Cut"); XCTAssertTrue(cut.isCut); XCTAssertEqual(cut.glyph, "scissors")
    }

    func testASingleSceneHasNoTransitionLine() throws {
        let d = makeTempDir("ui1-one"); defer { try? FileManager.default.removeItem(at: d) }
        let s = ProjectStore(root: d); try s.create(name: "One", conversationLanguage: "en", reelLanguages: ["en"])
        try s.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Only")))
        XCTAssertEqual(StoryboardList.build(s.loadShowreel()!, store: s).entries.map { $0.id }, ["scene:S01"])
    }

    func testTheMarksOfTheTransitionAreKept() throws {
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5, instruction: "match cut on the card")))
        guard case .transition(let t) = list().entries[1] else { return XCTFail() }
        XCTAssertFalse(t.marks.isEmpty, "an instruction that is pending or an approximate render says so on the line")
    }

    func testTheScenesThatAreNotInTheStoryboardAreHiddenScenesWithTheirWayBack() throws {
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        try store.apply(.scene(id: "S03", SceneEdit(archived: true)))
        let l = list()
        XCTAssertEqual(l.sceneIDs, ["S01"]); XCTAssertEqual(l.notIn.map { $0.id }, ["S02", "S03"])
        XCTAssertEqual(l.notIn[0].wayBack, "Show"); XCTAssertTrue(l.notIn[0].why.hasPrefix("Hidden")); XCTAssertNil(l.notIn[0].note)
        XCTAssertEqual(l.notIn[1].note, "Was archived.", "an archived scene is a hidden scene, and the reason is kept as a note")
    }

    func testMovingASceneMovesItsOutgoingTransitionWithIt() throws {
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5)))
        try store.apply(.moveScene(id: "S01", after: "S02", montage: nil))
        let l = list()
        XCTAssertEqual(l.sceneIDs, ["S02", "S01", "S03"])
        guard let i = l.entries.firstIndex(where: { $0.id == "scene:S01" }), case .transition(let t) = l.entries[i + 1] else { return XCTFail("a line follows S01") }
        XCTAssertEqual(t.from, "S01"); XCTAssertEqual(t.text, "Push \u{00B7} 0.5 s", "the passage out of S01 went with it")
    }

    // MARK: the icons (UI2 replaced the four-icon set by the Status, Visible and Locked columns: see UI2Tests)

    // MARK: the selection

    func testTheListTheStripAndTheInspectorUseTheOneSelection() throws {
        let listV = try source("StoryboardListViews.swift"), strip = try source("TimelineViews.swift"), inspector = try source("InspectorViews.swift")
        XCTAssertTrue(listV.contains("project.select(.scene(scene.id))") && strip.contains("project.select(.scene(scene.id))"), "a click on a scene row or on a frame is the same call")
        XCTAssertTrue(listV.contains("project.selectTransition(from: line.from)") && strip.contains("selectTransition(from:"), "a click on a transition line or on the marker is the same call")
        XCTAssertTrue(listV.contains("project.selection.sceneID == scene.id"), "the row is lit when the strip or an inspector node selects the scene")
        let ws = try source("WorkspaceViews.swift")
        XCTAssertTrue(inspector.contains("SceneTreeView(scene: id)") && ws.contains("project.selectNode(scene"), "the overview selects through the same model")
        for v in [listV, strip, inspector] { XCTAssertFalse(v.contains("selectedScene"), "no second selection state") }
        XCTAssertEqual(TransitionList.selection(of: TransitionRow(from: "S01", to: "S02", type: "cut", seconds: nil, isCut: true, marks: [])), "S01", "the line selects the marker the diamond selects")
    }

    func testTheListHasItsKeysAndTheNewPanelNoTabs() throws {
        let v = try source("StoryboardListViews.swift")
        XCTAssertTrue(v.contains("stepScene(by: 1)") && v.contains("stepScene(by: -1)") && v.contains("setEnabled(id, false)"), "arrows move between scenes, Delete switches the scene off")
        XCTAssertFalse(try source("WorkspaceViews.swift").contains("LibraryTabs"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: views.appendingPathComponent("TransitionsViews.swift").path), "the Transitions tab is gone: its lines are in the Storyboard")
    }

    // MARK: drops

    func testAResourceIsAcceptedByASceneRowAFrameAndTheOverview() throws {
        try Assets.add([{ let u = inbox.appendingPathComponent("Acme Logo.svg"); try? "x".write(to: u, atomically: true, encoding: .utf8); return u }()], to: store)
        for target in [DropTarget.scene("S01"),                                                          // a row of the list and a frame of the strip
                       .sceneNode(scene: "S01", group: .composition, node: nil)] {                         // the overview of the inspector
            XCTAssertEqual(Drops.verdict(.resource("logo-01"), on: target, store: store), .ok("Link Acme Logo.svg to S01"), "\(target)")
        }
        let strip = try source("TimelineViews.swift"), listV = try source("StoryboardListViews.swift"), inspector = try source("InspectorViews.swift")
        XCTAssertTrue(strip.contains(".dropTarget(.scene(scene.id))") && listV.contains(".dropTarget(.scene(scene.id))") && inspector.contains(".dropTarget(.scene(id))"), "the three places declare the target")
    }

    func testALockedSceneRefusesTheDropWithItsReasonAndABuildRefusesEverything() throws {
        try Assets.add([{ let u = inbox.appendingPathComponent("Acme Logo.svg"); try? "x".write(to: u, atomically: true, encoding: .utf8); return u }()], to: store)
        try store.apply(.scene(id: "S02", SceneEdit(status: "validated"))); try store.apply(.sceneLock(ids: ["S02"], locked: true))
        XCTAssertEqual(Drops.verdict(.resource("logo-01"), on: .scene("S02"), store: store), .refused(SceneLock.reason("S02")))
        XCTAssertEqual(Drops.verdict(.resource("logo-01"), on: .sceneNode(scene: "S02", group: .composition, node: nil), store: store), .refused(SceneLock.reason("S02")))
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        let v = Drops.verdict(.resource("logo-01"), on: .scene("S01"), store: store)
        XCTAssertFalse(v.isValid); XCTAssertTrue(v.text.contains("Building"), v.text)
        store.activity.update { $0.build = nil }
    }

    // MARK: the memory of the layout

    func testTheDividerAndTheResourcesStateAreSavedAndRestored() throws {
        var s = store.settings
        s.layout = PanelLayout(library: 320, split: 0.5, resources: .collapsed)
        store.settings = s
        let again = ProjectStore(root: dir).settings.layout
        XCTAssertEqual(again?.splitFraction, 0.5); XCTAssertEqual(again?.resourcesState, .collapsed); XCTAssertEqual(again?.libraryWidth, 320)
        let ex = PanelLayout(split: 0.7, resources: .expanded); s.layout = ex; store.settings = s
        XCTAssertEqual(ProjectStore(root: dir).settings.layout?.resourcesState, .expanded)
        s.layout = PanelLayout(); store.settings = s
        XCTAssertEqual(ProjectStore(root: dir).settings.layout?.splitFraction ?? LibrarySplit.standard, LibrarySplit.standard)
        XCTAssertTrue(PanelLayout().isStandard); XCTAssertFalse(PanelLayout(resources: .collapsed).isStandard); XCTAssertFalse(PanelLayout(split: 0.5).isStandard)
        XCTAssertEqual(PanelLayout(library: 300).replacing(split: 0.4).library, 300, "changing the divider keeps the other sizes")
    }

    func testTheSplitGivesTwoThirdsOneThirdAndKeepsEachSectionUsable() {
        let h = LibrarySplit.heights(total: 600, fraction: LibrarySplit.standard, state: .open)
        XCTAssertEqual(h.storyboard, 400, accuracy: 0.5); XCTAssertEqual(h.resources, 200, accuracy: 0.5); XCTAssertEqual(h.storyboard + h.resources, 600, accuracy: 0.001)
        let c = LibrarySplit.heights(total: 600, fraction: 0.5, state: .collapsed), e = LibrarySplit.heights(total: 600, fraction: 0.5, state: .expanded)
        XCTAssertEqual(c.resources, LibrarySplit.header); XCTAssertEqual(c.storyboard, 600 - LibrarySplit.header)
        XCTAssertEqual(e.storyboard, LibrarySplit.header); XCTAssertEqual(e.resources, 600 - LibrarySplit.header)
        let tight = LibrarySplit.heights(total: 300, fraction: 0.85, state: .open)
        XCTAssertGreaterThanOrEqual(tight.resources, LibrarySplit.minResources); XCTAssertEqual(tight.storyboard + tight.resources, 300, accuracy: 0.001)
        XCTAssertEqual(LibrarySplit.fraction(total: 600, storyboardHeight: 400, moved: 1000), LibrarySplit.maxFraction); XCTAssertEqual(LibrarySplit.fraction(total: 600, storyboardHeight: 400, moved: -1000), LibrarySplit.minFraction)
    }

    // MARK: the Checks badge

    func testTheBadgeCountsWhatTheTabCounted() throws {
        func e(_ id: String, _ l: CheckLevel) -> CheckEntry { CheckEntry(result: CheckResult(id: id, block: "project", title: id, level: l, detail: ""), group: .project, target: .project) }
        let entries = [e("a", .fail), e("b", .tight), e("c", .tight), e("d", .ok), e("e", .pending)]
        let v = CheckBadge.value(entries)
        XCTAssertEqual(v.count, CheckPanel.attention(entries)); XCTAssertEqual(v.count, 3); XCTAssertEqual(v.tone, .problem); XCTAssertEqual(v.label, "Checks 3")
        XCTAssertEqual(CheckBadge.value([e("a", .tight)]).tone, .attention)
        let clear = CheckBadge.value([e("d", .ok), e("e", .pending)])
        XCTAssertEqual(clear.count, 0); XCTAssertEqual(clear.tone, .clear); XCTAssertTrue(clear.help.hasPrefix("Nothing needs attention"))
        XCTAssertTrue(try source("ProjectView.swift").contains("ChecksBadge()"), "the badge is in the top bar")
        XCTAssertTrue(try source("InspectorViews.swift").contains("ChecksLibrary()"), "its list opens in the centre, grouped as the tab was")
    }
}
