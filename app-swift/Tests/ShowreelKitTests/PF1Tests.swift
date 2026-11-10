import XCTest
@testable import ShowreelKit

/// PF1: a click on a scene of the Storyboard list acts at once, as a click in the Film does.
final class PF1Tests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    func testBothTapsReachTheSameOperation() throws {
        XCTAssertTrue(try source("TimelineViews.swift").contains(".onTapGesture { project.focusScene(scene.id); focused = true }"), "the Film's frame")
        XCTAssertTrue(try source("StoryboardListViews.swift").contains(".onTapGesture { project.focusScene(scene.id) }"), "the list's row")
    }

    func testTheRowsSingleTapIsNotBehindADoubleTapGesture() throws {
        let src = try source("StoryboardListViews.swift")
        XCTAssertFalse(src.contains(".onTapGesture(count: 2)"), "a double-tap recognised first holds the single tap back for the double-click interval")
        let single = try XCTUnwrap(src.range(of: ".onTapGesture { project.focusScene(scene.id) }")), double = try XCTUnwrap(src.range(of: ".simultaneousGesture(TapGesture(count: 2).onEnded { project.beginRename(scene.id) })"))
        XCTAssertLessThan(single.lowerBound, double.lowerBound)
    }

    func testTheOperationKeepsFIX2sOrderAndCommitsAPendingEditFirst() throws {
        let m = try source("ProjectModel.swift")
        let a = try XCTUnwrap(m.range(of: "func focusScene(_ id: String) {")), b = try XCTUnwrap(m.range(of: "func stepScene(by delta: Int)"))
        let body = String(m[a.lowerBound..<b.lowerBound])
        let order = ["select(.scene(id))", "playhead = start", "setViewport("].map { body.range(of: $0)?.lowerBound }
        XCTAssertFalse(order.contains { $0 == nil }); XCTAssertEqual(order.compactMap { $0 }, order.compactMap { $0 }.sorted(), "selection, then the playhead, then the Film's scroll")
        let sel = try XCTUnwrap(m.range(of: "func select(_ x: Selection) {"))
        XCTAssertTrue(String(m[sel.lowerBound...].prefix(200)).contains("activeAutosave?.flush()"), "a pending edit is committed before the selection changes (AS1)")
    }

    func testTheProbeReturnsTheBodysValue() {
        var n = 0
        XCTAssertEqual(DebugProbe.interval("test") { n += 1; return 7 }, 7); XCTAssertEqual(n, 1)
    }
}
