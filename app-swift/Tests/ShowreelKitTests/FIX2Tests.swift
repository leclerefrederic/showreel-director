import XCTest
@testable import ShowreelKit

/// FIX2: a click on a scene, wherever it is made, selects it and moves the preview to it.
final class FIX2Tests: XCTestCase {
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    func testTheRuleMovesThePlayheadToASceneInTheFilmAndNotToAHiddenOne() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fix2-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectStore(root: dir)
        try store.create(name: "T", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        let f = store.loadShowreel()!
        XCTAssertEqual(TimelineNav.focus("S01", in: f), 0)
        XCTAssertEqual(TimelineNav.focus("S03", in: f), 3, "the start of the scene in the film, whether it plays or not")
        XCTAssertNil(TimelineNav.focus("S02", in: f), "a hidden scene is selected and the playhead stays")
        XCTAssertNil(TimelineNav.focus("S99", in: f))
        XCTAssertEqual(TimelineNav.focus("S03", in: f), TimelineNav.step(from: "S01", by: 1, playhead: 0, in: f)?.start, "the arrows and a click agree")
    }

    func testEveryUserClickOnASceneUsesTheOneOperation() throws {
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("func focusScene(_ id: String)"))
        XCTAssertTrue(m.contains("        focusScene(n.id)\n    }"), "stepping goes through the operation")
        XCTAssertTrue(try source("StoryboardListViews.swift").contains("project.focusScene(scene.id)"), "the list row")
        XCTAssertTrue(try source("TimelineViews.swift").contains("project.focusScene(scene.id)"), "the strip frame")
        XCTAssertFalse(try source("TimelineViews.swift").contains("project.playhead = s }; focused"), "the strip has no rule of its own")
        XCTAssertTrue(try source("ResourceViews.swift").contains("project.focusScene(s)"), "the Used in chip")
        XCTAssertTrue(m.contains("case .scene(let id, let tab):\n            focusScene(id)"), "a check's click-through")
        XCTAssertTrue(m.contains("case .scene(let id)?: focusScene(id)"), "the way out of a reason")
        XCTAssertTrue(try source("StoryboardListViews.swift").contains("proxy.scrollTo(\"scene:\" + id)"), "the list follows a selection made elsewhere")
    }
}
