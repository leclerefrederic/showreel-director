import XCTest
@testable import ShowreelKit

/// SM1: fewer controls, same behaviour. (The rule itself, "every visible scene Ready", is also pinned by `UI2Tests` and `SceneTests`.)
final class SM1Tests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    func testTheRailHasFiveEntriesAndNoneIsLook() {
        XCTAssertEqual(RailEntry.allCases.map { $0.title }, ["Film", "Build", "Inspector", "Project", "Clap"])
        XCTAssertFalse(RailEntry.allCases.contains { $0.rawValue == "look" || $0.title == "Look" })
        XCTAssertEqual(RightPanel.allCases.map { $0.rawValue }, ["inspector", "project", "clap"])
        XCTAssertTrue(RailEntry.project.help.contains("look"), "the Project tooltip says it holds the look")
    }

    func testOpeningAndClosingPanelsKeepsTheRailAndTheScreenInAgreement() {
        var side = RightSide()
        for p in [RightPanel?.some(.project), .clap, .inspector, nil, .project] {
            side.show(p); XCTAssertEqual(side.panel, p)
            var r = RailState(right: side.panel)
            for e in RailEntry.allCases where e.group == .right { XCTAssertEqual(r.isSelected(e), e.panel == p) }
            r.choose(.project); XCTAssertEqual(r.right, p == .project ? nil : .project)
        }
    }

    func testTheProjectTabIsStoredAndOldStoredLookPanelsStillOpen() throws {
        var s = StudioSettings(); s.settingsTab = "look"; s.rightPanel = "project"
        let back = try JSONDecoder().decode(StudioSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.settingsTab, "look"); XCTAssertEqual(back.rightPanel, "project")
        XCTAssertNil(RightPanel(rawValue: "look"), "an older project's \"look\" is mapped to Project on its Look tab by the model")
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("r == \"look\" { settingsTab = .look; restoreRight(.project) }") && m.contains("ProjectTab.stored(s.settingsTab)"))
    }

    func testEveryFormerPathToTheLookLandsOnTheProjectPanelsLookTab() throws {
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("func openSettings(_ tab: SettingsTab = .brief, look: LookSection? = nil) {\n        settingsTab = tab"), "one operation opens Project on a tab")
        XCTAssertTrue(try source("WorkspaceViews.swift").contains("case .project?: ProjectSettingsPanel()"))
        XCTAssertFalse(m.contains("case .look: settingsTab = .look; showProjectSettings = true"))
    }

    func testStartingABuildRecordsTheGoAndTheToolbarHasNoGoControls() throws {
        let m = try source("ProjectModel.swift")
        let run = try XCTUnwrap(m.range(of: "private func runBuild("))
        XCTAssertTrue(String(m[run.lowerBound...].prefix(900)).contains("perform(.gate(\"review\", passed: true))"), "the Build records the Go as the button did")
        let t = try source("TimelineViews.swift")
        for gone in ["FilmStatusChip", "StripPrimaryAction", "GoButton", "Validate storyboard"] { XCTAssertFalse(t.contains(gone), gone) }
        for f in ["StoryboardViews.swift", "FilmStateViews.swift"] { let s = try source(f); XCTAssertFalse(s.contains("struct GoButton") || s.contains("struct GoPanel") || s.contains("struct FilmStatusChip"), f) }
    }

    func testTheEmptyInspectorHasNoProjectSettingsButtonAndTheTopBarKeepsItsControls() throws {
        let i = try source("InspectorViews.swift")
        let a = try XCTUnwrap(i.range(of: "struct ProjectInspector: View {")), b = try XCTUnwrap(i.range(of: "struct GlobalLook: View {"))
        XCTAssertFalse(String(i[a.lowerBound..<b.lowerBound]).contains("Project settings"))
        XCTAssertTrue(String(i[a.lowerBound..<b.lowerBound]).contains("Select a scene, a resource or a transition marker"))
        let top = try source("ProjectView.swift")
        for kept in ["ChecksBadge()", "ViewGroup()", "showCatalogue.toggle()"] { XCTAssertTrue(top.contains(kept), "\(kept): the Catalogue stays (it holds drag actions), see the report") }
        XCTAssertTrue(try source("FormViews.swift").contains("project.openRail(.project)"), "the Project button of the other inspectors stays")
    }

    func testTheBuildSaysWhichScenesAreNotReady() {
        let idle = ProjectActivity.Snapshot()
        let u = Availability.startBuild(in: idle, hasKey: true, canBuild: false, clapRunning: false, notReady: "2 scenes are not Ready (S01, S02)").why
        XCTAssertEqual(u?.reason, "2 scenes are not Ready (S01, S02)")
        XCTAssertEqual(Availability.startBuild(in: idle, hasKey: true, canBuild: true, clapRunning: false), .available)
    }
}
