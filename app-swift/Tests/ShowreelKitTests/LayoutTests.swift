import XCTest
@testable import ShowreelKit

/// The sizes of the workspace's panels: remembered per project, a floor, no ceiling, resettable.
final class LayoutTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("layout"); store = ProjectStore(root: dir) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testSizesSurviveAClosedAndReopenedProject() throws {
        XCTAssertNil(store.settings.layout, "no layout until the user drags a divider")
        XCTAssertTrue(PanelLayout().isStandard)
        var s = store.settings; s.layout = PanelLayout(library: 420, inspector: 610.5, strip: 333); store.settings = s
        let reopened = ProjectStore(root: dir)                                  // a new session reads ui.json again
        let l = try XCTUnwrap(reopened.settings.layout)
        XCTAssertEqual(l, PanelLayout(library: 420, inspector: 610.5, strip: 333))
        XCTAssertEqual([l.libraryWidth, l.inspectorWidth, l.stripHeight], [420, 610.5, 333])
        let text = try XCTUnwrap(reopened.read(".studio/ui.json"))
        XCTAssertTrue(text.contains("\"layout\""), "kept in .studio/ui.json")
    }

    func testThereIsAFloorAndNoCeiling() {
        let l = PanelLayout(library: 10, inspector: 50, strip: -4)
        XCTAssertEqual(l.libraryWidth, PanelLayout.minLibrary); XCTAssertEqual(l.inspectorWidth, PanelLayout.minInspector); XCTAssertEqual(l.stripHeight, PanelLayout.minStrip)
        let big = PanelLayout(library: 5000, inspector: 9000, strip: 4000)
        XCTAssertEqual([big.libraryWidth, big.inspectorWidth, big.stripHeight], [5000, 9000, 4000], "no maximum is imposed")
        XCTAssertEqual(PanelLayout(library: .nan, inspector: .infinity).library, nil, "something that is not a size is dropped")
        XCTAssertEqual(PanelLayout(library: .nan, inspector: .infinity).inspector, nil)
    }

    func testAFileWrittenByHandIsFlooredWhenRead() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".studio"), withIntermediateDirectories: true)
        try #"{"mode": "expert", "layout": {"library": 12, "inspector": 700}}"#.write(to: dir.appendingPathComponent(".studio/ui.json"), atomically: true, encoding: .utf8)
        let l = try XCTUnwrap(store.settings.layout)
        XCTAssertEqual(l.library, PanelLayout.minLibrary, "under the floor: the floor"); XCTAssertEqual(l.inspector, 700); XCTAssertNil(l.strip)
        XCTAssertEqual(l.stripHeight, PanelLayout.standardStrip, "an absent size is the standard one")
    }

    func testEachProjectKeepsItsOwnSizesAndTheOtherSettingsAreUntouched() throws {
        let other = makeTempDir("layout2"); defer { try? FileManager.default.removeItem(at: other) }
        let b = ProjectStore(root: other)
        var s = store.settings; s.mode = StudioSettings.beginner; s.applyDirectly = true; s.decided = ["project.tone"]; s.layout = PanelLayout(library: 300); store.settings = s
        XCTAssertNil(b.settings.layout, "another project is not affected")
        var t = store.settings; t.layout = PanelLayout(library: 300, strip: 250); store.settings = t
        XCTAssertEqual(store.settings.mode, StudioSettings.beginner); XCTAssertTrue(store.settings.applyDirectly); XCTAssertEqual(store.settings.decided, ["project.tone"])
        XCTAssertEqual(store.settings.layout?.strip, 250)
    }

    func testResetGoesBackToTheStandardLayoutAndLeavesNoKey() throws {
        var s = store.settings; s.layout = PanelLayout(library: 500, inspector: 500, strip: 500); store.settings = s
        XCTAssertFalse(PanelLayout(library: 500).isStandard)
        s = store.settings; s.layout = nil; store.settings = s                  // what "Reset layout" writes
        XCTAssertNil(store.settings.layout)
        XCTAssertFalse(try XCTUnwrap(store.read(".studio/ui.json")).contains("layout"))
        XCTAssertEqual([PanelLayout().libraryWidth, PanelLayout().inspectorWidth, PanelLayout().stripHeight], [PanelLayout.standardLibrary, PanelLayout.standardInspector, PanelLayout.standardStrip])
    }

    func testAnOldUIFileHasNoLayout() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".studio"), withIntermediateDirectories: true)
        try #"{"mode": "beginner", "applyDirectly": false, "decided": []}"#.write(to: dir.appendingPathComponent(".studio/ui.json"), atomically: true, encoding: .utf8)
        XCTAssertNil(store.settings.layout); XCTAssertEqual(store.settings.mode, StudioSettings.beginner)
    }
}
