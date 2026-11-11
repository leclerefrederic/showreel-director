import XCTest
@testable import ShowreelKit

/// SC1 (DECISION-027): shortcuts for the Inspector, Project and its Look tab, in the family of Shift-Command-A.
final class SC1Tests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    func testEachShortcutBelongsToItsPanelAndIsInTheFamilyOfClaps() {
        XCTAssertEqual(AppShortcuts.inspector.keys, "cmd+shift+i"); XCTAssertEqual(AppShortcuts.project.keys, "cmd+shift+j"); XCTAssertEqual(AppShortcuts.look.keys, "cmd+shift+y")
        for s in [AppShortcuts.inspector, AppShortcuts.project, AppShortcuts.look] { XCTAssertTrue(s.keys.hasPrefix("cmd+shift+"), s.keys); XCTAssertTrue(AppShortcuts.used.contains(s)) }
        XCTAssertEqual(AppShortcuts.clap.keys, "cmd+shift+a"); XCTAssertEqual(AppShortcuts.clapDisplay, "Shift-Command-A")
    }

    func testNoTwoShortcutsOfTheAppAreEqualAndNoneIsThePageSetupOfTheSystem() {
        let keys = AppShortcuts.used.map { $0.keys }
        XCTAssertEqual(Set(keys).count, keys.count, "no two actions share a shortcut")
        XCTAssertFalse(keys.contains("cmd+shift+p"))
    }

    func testTheTooltipsOfTheEntriesNameTheirShortcuts() {
        XCTAssertTrue(RailEntry.inspector.tooltip().contains("Shift-Command-I"))
        XCTAssertTrue(RailEntry.project.tooltip().contains("Shift-Command-J")); XCTAssertTrue(RailEntry.project.tooltip().contains("Shift-Command-Y"))
        XCTAssertTrue(RailEntry.clap.tooltip().contains("Shift-Command-A"))
        XCTAssertNil(RailEntry.film.shortcut); XCTAssertNil(RailEntry.build.shortcut)
    }

    func testAShortcutOpensItsPanelFromAClosedSideAndFromAnotherPanelAndNeverToggles() {
        for p in [RightPanel.inspector, .project] {
            var s = RailState(right: nil); s.open(p); XCTAssertEqual(s.right, p)
            s.open(p); XCTAssertEqual(s.right, p, "a repeat does nothing")
            var other = RailState(right: .clap); other.open(p); XCTAssertEqual(other.right, p)
        }
    }

    func testTheRightSideShowsTheProjectPanelForTheLookShortcutAndTheModelPutsTheTabOnLook() throws {
        var side = RightSide(closed: true); side.show(.project); XCTAssertEqual(side.panel, .project)
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("func showLook()")); XCTAssertTrue(m.contains("showProject()\n        if settingsTab != .look { settingsTab = .look }"))
        XCTAssertTrue(m.contains("s.open(.project)"))
    }

    func testTheMenuListsThemAndAnUnavailableOneSaysWhy() throws {
        let app = try source("App.swift")
        for k in ["AppShortcuts.inspector", "AppShortcuts.project", "AppShortcuts.look"] { XCTAssertTrue(app.contains(k), k) }
        XCTAssertTrue(app.contains("entry.unavailable(workspaceOpen:")); XCTAssertTrue(app.contains(".disabled(project == nil || why != nil)"))
        let u = RailEntry.project.unavailable(workspaceOpen: false, progressLine: "audience missing")
        XCTAssertNotNil(u); XCTAssertTrue(u?.message.contains("audience missing") ?? false)
        XCTAssertNil(RailEntry.inspector.unavailable(workspaceOpen: true, progressLine: ""))
    }

    func testClapsShortcutIsStillWiredByTheWorkspaceAsBefore() throws {
        XCTAssertTrue(try source("WorkspaceViews.swift").contains(#"project.openClap() }.keyboardShortcut("a", modifiers: [.command, .shift])"#))
    }
}
