import XCTest
@testable import ShowreelKit

/// RS1 (DECISION-023): a left panel whose divider was never dragged gives the Resources the height of the Film strip.
final class RS1Tests: XCTestCase {
    func testTheResourcesAreAsTallAsTheStripForSeveralWindowHeights() {
        for window in [700.0, 900.0, 1200.0] {
            let total = window - 2 * ShellLayout.gap - 6                       // the panel's height minus the divider's handle
            let f = LibrarySplit.defaultFraction(total: total, stripHeight: PanelLayout.standardStrip, placement: .underPreview)
            let h = LibrarySplit.heights(total: total, fraction: f, state: .open)
            XCTAssertEqual(h.resources, PanelLayout.standardStrip, accuracy: 0.001, "window \(window)")
        }
    }

    func testAStripTheOwnerDraggedTallerMovesTheDefaultWithIt() {
        let f = LibrarySplit.defaultFraction(total: 800, stripHeight: 400, placement: .underPreview)
        XCTAssertEqual(LibrarySplit.heights(total: 800, fraction: f, state: .open).resources, 400, accuracy: 0.001)
    }

    func testTheDefaultStaysInsideTheRangeAtTheSmallestAndAbsurdSizes() {
        let min = ShellLayout.minimumWindow(.underPreview).height - 2 * ShellLayout.gap - 6
        let small = LibrarySplit.defaultFraction(total: min, stripHeight: PanelLayout.minStrip, placement: .underPreview)
        XCTAssertTrue((LibrarySplit.minFraction...LibrarySplit.maxFraction).contains(small))
        XCTAssertEqual(LibrarySplit.defaultFraction(total: 400, stripHeight: 395, placement: .underPreview), LibrarySplit.minFraction)
        XCTAssertEqual(LibrarySplit.defaultFraction(total: 400, stripHeight: 0, placement: .underPreview), LibrarySplit.maxFraction)
        XCTAssertEqual(LibrarySplit.defaultFraction(total: 0, stripHeight: 300, placement: .underPreview), LibrarySplit.standard)
        XCTAssertEqual(LibrarySplit.defaultFraction(total: 500, stripHeight: .nan, placement: .underPreview), LibrarySplit.standard)
    }

    func testAtFullWidthTheStripIsNotBesideThePanelSoTheOldTwoThirdsStay() {
        XCTAssertEqual(LibrarySplit.defaultFraction(total: 700, stripHeight: 300, placement: .fullWidth), LibrarySplit.standard)
    }

    func testADraggedDividerIsKnownAndKeptAndAFreshPanelIsNotDragged() {
        XCTAssertNil(PanelLayout().split)
        let dragged = PanelLayout().replacing(split: 0.5)
        XCTAssertEqual(dragged.split, 0.5)
        XCTAssertEqual(dragged.splitFraction, 0.5)
        XCTAssertFalse(dragged.isStandard)
    }

    func testTheViewUsesTheStoredSplitBeforeTheDefault() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        let src = try String(contentsOf: dir.appendingPathComponent("StoryboardListViews.swift"), encoding: .utf8)
        XCTAssertTrue(src.contains("project.layout.split ?? LibrarySplit.defaultFraction"))
    }
}
