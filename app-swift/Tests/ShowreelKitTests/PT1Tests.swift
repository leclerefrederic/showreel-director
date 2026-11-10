import XCTest
@testable import ShowreelKit

/// PT1: the project's properties in three tabs, and no conversation language in the interface.
final class PT1Tests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }
    private func file(set: Set<String>) -> ShowreelFile {
        var f = ShowreelFile(name: "P")
        if set.contains("reelLanguages") { f.reelLanguages = ["en"] }
        if set.contains("formats") { f.decisions.formats = ["16:9"] }
        if set.contains("duration") { f.decisions.duration = 60 }
        if set.contains("look") { f.decisions.palette = ["#000000", "#FFFFFF"]; f.decisions.fonts = .init(titles: "A", text: "B"); f.decisions.background = .init(id: "x") }
        return f
    }

    func testThreeTabsInOrderWithBriefFormatLook() {
        XCTAssertEqual(ProjectTab.allCases.map { $0.title }, ["Brief", "Format", "Look"])
        XCTAssertEqual(ProjectTab.brief.model().tabs, ProjectTab.allCases)
    }

    func testTheArrowKeysMoveAndWrap() {
        var m = ProjectTab.brief.model()
        m.next(); XCTAssertEqual(m.selected, .format); m.next(); XCTAssertEqual(m.selected, .look); m.next(); XCTAssertEqual(m.selected, .brief)
        m.previous(); XCTAssertEqual(m.selected, .look)
    }

    func testTheDefaultIsTheFirstTabWithSomethingUnsetElseTheLastUsed() {
        XCTAssertEqual(ProjectTab.opening(file(set: []), last: .brief), .format, "film language, formats, duration are on Format")
        XCTAssertEqual(ProjectTab.opening(file(set: ["reelLanguages", "formats", "duration"]), last: .brief), .look)
        XCTAssertEqual(ProjectTab.opening(file(set: ["reelLanguages", "formats", "duration", "look"]), last: .look), .look, "complete: the last used")
        XCTAssertEqual(ProjectTab.opening(file(set: ["reelLanguages", "formats", "duration", "look"]), last: .format), .format)
        XCTAssertEqual(ProjectTab.opening(nil, last: .format), .format)
    }

    func testEachBaseConfigurationItemHasItsTab() {
        for r in ProjectSetup.requirements(file(set: [])) { XCTAssertEqual(ProjectTab.tab(forRequirement: r.id), r.id == "look" ? .look : .format, r.id) }
        XCTAssertEqual(ProjectSetup.requirements(file(set: [])).map { ProjectTab.tab(forRequirement: $0.id) }, [.format, .format, .format, .look])
    }

    func testTheStoredSelectionRestoresAndAnOldTabMigrates() throws {
        for t in ProjectTab.allCases { XCTAssertEqual(ProjectTab.stored(t.storedValue), t) }
        XCTAssertNil(ProjectTab.brief.storedValue)
        XCTAssertEqual(ProjectTab.stored(nil), .brief); XCTAssertEqual(ProjectTab.stored("project"), .brief, "an old Project tab is the Brief")
        XCTAssertEqual(ProjectTab.stored("look"), .look, "a stored Look stays Look"); XCTAssertEqual(ProjectTab.stored("nonsense"), .brief)
        var s = StudioSettings(); s.settingsTab = ProjectTab.format.storedValue
        XCTAssertEqual(ProjectTab.stored(try JSONDecoder().decode(StudioSettings.self, from: JSONEncoder().encode(s)).settingsTab), .format)
    }

    func testEveryFieldOfTheOldFormIsInExactlyOnePlace() throws {
        let names = ProjectFormMap.fields.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(Set(names), ["Project name", "Base configuration", "Audience", "Message", "Tone", "Constraints", "Control level", "Formats", "Target duration", "Film languages"])
        let form = try source("ProjectFormViews.swift")
        for n in ["Project name", "Base configuration", "Audience", "Message", "Tone", "Constraints", "Control level", "Formats", "Target duration", "Film languages"] { XCTAssertEqual(form.components(separatedBy: "\"\(n)\"").count - 1 + form.components(separatedBy: "Text(\"\(n)\")").count - 1 > 0 ? 1 : 0, 1, n) }
        XCTAssertTrue(ProjectFormMap.fields.filter { $0.place == .aboveTabs }.map { $0.name } == ["Project name", "Base configuration"])
        let panel = try source("ProjectSettingsPanel.swift")
        let header = try XCTUnwrap(panel.range(of: "ProjectForm(part: .header)")), tabs = try XCTUnwrap(panel.range(of: "TabBar(tabs: SettingsTab.allCases"))
        XCTAssertLessThan(header.lowerBound, tabs.lowerBound, "the name and the compact base configuration are above the tabs")
        let f = try source("ProjectFormViews.swift")
        XCTAssertTrue(f.contains("ProjectTab.tab(forRequirement: r.id)"), "a checklist item goes to its tab")
    }

    func testTheMultilineFieldsKeepOffTheirBorder() throws {
        XCTAssertGreaterThan(FormLayout.multilinePadding, 0)
        XCTAssertTrue(try source("ProjectFormViews.swift").contains("fieldVerticalPadding"))
        XCTAssertTrue(try source("Theme.swift").contains(".padding(.vertical, vertical)"))
    }

    func testNoConversationLanguageIsOfferedAndTheMacsStillReachesClap() throws {
        for f in ["ProjectFormViews.swift", "ProjectSettingsPanel.swift", "SettingsView.swift", "NewProjectViews.swift"] {
            let s = try source(f).lowercased()
            XCTAssertFalse(s.contains("conversation language") || s.contains(".conversationlanguage"), f)
        }
        XCTAssertTrue(WizardInterview.prompt(projectName: "R", conversationLanguage: "fr").contains("from the user's Mac"))
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("pt1-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: d) }
        let s = ProjectStore(root: d); try s.create(name: "P", conversationLanguage: nil, reelLanguages: [], preferredLanguages: ["fr-FR"])
        XCTAssertEqual(s.loadShowreel()?.conversationLanguage, "fr", "written implicitly from the Mac")
    }

    func testAnOldStoredConversationLanguageIsKeptAndIgnoredWithoutError() throws {
        let f = try ShowreelFile.decode(##"{"schema": 1, "name": "N", "conversationLanguage": "de", "conversationLanguageSource": "user", "scenes": []}"##)
        XCTAssertEqual(f.conversationLanguage, "de")
        XCTAssertTrue(try f.encoded().contains("\"conversationLanguage\""), "never deleted from the file")
    }
}
