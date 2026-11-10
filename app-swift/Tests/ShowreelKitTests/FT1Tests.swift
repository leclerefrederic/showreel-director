import XCTest
@testable import ShowreelKit

/// FT1: the Film toolbar, simplified (no Ripple, no Add scene, the zoom group last).
final class FT1Tests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    func testTheZoomGroupIsTheLastControlOfTheToolbar() throws {
        let src = try source("TimelineViews.swift")
        let a = try XCTUnwrap(src.range(of: "private var right: some View {")), b = try XCTUnwrap(src.range(of: "private var zoom: some View {"))
        let body = String(src[a.lowerBound..<b.lowerBound])
        let order = ["gridToggle(f)", "zoom "].map { body.range(of: $0)?.lowerBound }
        XCTAssertFalse(order.contains { $0 == nil }, "\(order)")
        XCTAssertEqual(order.compactMap { $0 }, order.compactMap { $0 }.sorted())
    }

    func testTheToolbarHasNoRippleAndNoAddSceneMenu() throws {
        let src = try source("TimelineViews.swift")
        XCTAssertFalse(src.lowercased().contains("ripple")); XCTAssertFalse(src.contains("addMenu")); XCTAssertFalse(src.contains("Add scene"))
        for f in ["ProjectModel.swift", "SelfCheck.swift"] { XCTAssertFalse(try source(f).contains("ripple"), f) }
    }

    func testEveryWayToAddASceneIsStillThere() throws {
        let list = try source("StoryboardListViews.swift")
        XCTAssertTrue(list.contains("project.addScene()") && list.contains("\"New\""), "the Storyboard's New creates a scene")
        XCTAssertTrue(list.contains("Not in the storyboard"), "a scene that is not in the film comes back from its own section")
        XCTAssertTrue(try source("StoryboardViews.swift").contains("project.addScene()"), "the storyboard page keeps its Add scene")
    }

    func testAnOldStoredRippleValueIsIgnoredAndKept() throws {
        let f = try ShowreelFile.decode(##"{"schema": 1, "name": "N", "scenes": [{"id": "S01"}], "storyboards": [{"id": "main", "name": "M", "ripple": false, "items": [{"scene": "S01", "enabled": true}]}]}"##)
        XCTAssertEqual(f.film.count, 1)
        let out = try f.encoded()
        XCTAssertTrue(out.contains("\"ripple\""), "an unknown field of an older file is carried, not dropped")
    }
}
