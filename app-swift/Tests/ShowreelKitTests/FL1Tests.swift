import XCTest
@testable import ShowreelKit

/// FL1: the scenes of the Film look like film.
final class FL1Tests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    func testTheGridIsUnderTheFramesAndThePlayheadOverEverything() {
        let o = StripLayerOrder.self
        XCTAssertLessThan(o.z(.background), o.z(.grid))
        XCTAssertLessThan(o.z(.grid), o.z(.frames))
        XCTAssertLessThan(o.z(.frames), o.z(.transitionMarkers))
        XCTAssertLessThan(o.z(.transitionMarkers), o.z(.musicMarkers))
        XCTAssertEqual(o.bottomToTop.last, .playhead)
        XCTAssertEqual(o.bottomToTop.count, Set(o.bottomToTop).count)
    }

    func testThumbnailInAWideFrameIsCentredHorizontally() {
        let r = ThumbnailFit.rect(in: CGRect(x: 0, y: 10, width: 400, height: 90), aspect: 16.0 / 9)
        XCTAssertEqual(r.height, 90, accuracy: 0.01); XCTAssertEqual(r.width, 160, accuracy: 0.01)
        XCTAssertEqual(r.midX, 200, accuracy: 0.01); XCTAssertEqual(r.midY, 55, accuracy: 0.01)
    }

    func testThumbnailInANarrowFrameIsCentredVerticallyAndNotCropped() {
        let r = ThumbnailFit.rect(in: CGRect(x: 0, y: 0, width: 80, height: 200), aspect: 16.0 / 9)
        XCTAssertEqual(r.width, 80, accuracy: 0.01); XCTAssertEqual(r.height, 45, accuracy: 0.01)
        XCTAssertEqual(r.midY, 100, accuracy: 0.01); XCTAssertEqual(r.minX, 0)
    }

    func testATallImageIsFitWhole() {
        let r = ThumbnailFit.rect(in: CGRect(x: 0, y: 0, width: 300, height: 100), aspect: 0.5)
        XCTAssertEqual(r.height, 100, accuracy: 0.01); XCTAssertEqual(r.width, 50, accuracy: 0.01); XCTAssertEqual(r.midX, 150, accuracy: 0.01)
    }

    func testNoImageYetUsesTheShapeOfACapture() {
        let r = ThumbnailFit.rect(in: CGRect(x: 0, y: 0, width: 160, height: 90), aspect: nil)
        XCTAssertEqual(r, CGRect(x: 0, y: 0, width: 160, height: 90))
        XCTAssertEqual(ThumbnailFit.rect(in: CGRect(x: 0, y: 0, width: 0, height: 0), aspect: nil).width, 0)
    }

    func testPerforationsGrowWithWidthAndVanishBelowTheMinimum() {
        XCTAssertEqual(ReelFrame.perforationCount(width: ReelFrame.minWidth - 1), 0)
        let a = ReelFrame.perforationCount(width: 100), b = ReelFrame.perforationCount(width: 400)
        XCTAssertGreaterThan(a, 0); XCTAssertGreaterThan(b, a)
    }

    func testPerforationsStayInsideTheirBandsAndTheCaps() {
        let l = ReelFrame.layout(width: 200, height: 120)
        XCTAssertGreaterThan(l.band, 0)
        for p in l.perforations {
            XCTAssertGreaterThanOrEqual(p.minX, l.capStart.maxX); XCTAssertLessThanOrEqual(p.maxX, l.capEnd.minX)
            XCTAssertTrue(p.maxY <= l.band || p.minY >= 120 - l.band, "never in the content")
        }
        XCTAssertEqual(l.content.minY, l.band); XCTAssertEqual(l.content.height, 120 - 2 * l.band, accuracy: 0.01)
    }

    func testCapsExistAtEveryWidthAndOnlyCapsRemainWhenNarrow() {
        for w in [1.0, 10, 59, 60, 200, 2000] {
            let l = ReelFrame.layout(width: w, height: 120)
            XCTAssertGreaterThan(l.capStart.width, 0); XCTAssertGreaterThan(l.capEnd.width, 0)
            if w < ReelFrame.minWidth { XCTAssertTrue(l.perforations.isEmpty); XCTAssertEqual(l.band, 0) }
        }
    }

    func testAShortFrameHasNoBands() {
        let l = ReelFrame.layout(width: 300, height: ReelFrame.minHeight - 1)
        XCTAssertEqual(l.band, 0); XCTAssertTrue(l.perforations.isEmpty)
    }

    func testTheNewDrawingUsesTokensNotColourLiterals() throws {
        let src = try source("ReelFrameViews.swift")
        for bad in ["Color(red", "Color(white", "Color(hex", "NSColor(", ".white)", ".black)", "Color.white", "Color.black"] { XCTAssertFalse(src.contains(bad), bad) }
        XCTAssertTrue(try source("Theme.swift").contains("var thumbBackdrop"))
    }

    func testTheStripStacksTheLayersByTheOrderType() throws {
        let src = try source("TimelineViews.swift")
        for l in ["grid", "frames", "transitionMarkers", "playhead"] { XCTAssertTrue(src.contains("StripLayerOrder.z(.\(l))"), l) }
        XCTAssertFalse(src.contains("theme.strip.frame)"), "the frame sits on the translucent backdrop")
    }
}
