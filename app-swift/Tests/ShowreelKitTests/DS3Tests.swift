import XCTest
@testable import ShowreelKit

/// Phase DS3: the form system, the stepper rule, the tab bar model and the pane widths.
final class DS3Tests: XCTestCase {
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    func testEveryFormLengthIsOnTheSpacingGrid() {
        let unit = DesignTokens.graphite.spacing.xs
        for v in FormLayout.lengths { XCTAssertEqual(v.truncatingRemainder(dividingBy: unit), 0, "\(v) is not on the grid of \(unit)") }
        XCTAssertEqual(FormLayout.fieldRadius, DesignTokens.graphite.radii.small, "the field radius is a token")
        XCTAssertGreaterThanOrEqual(FormLayout.fieldHeight, 24)
    }

    func testAMultiLineFieldGrowsWithItsTextAndScrollsOnlyPastTheLimit() {
        XCTAssertEqual(FormLayout.areaLines(for: "short", width: 300).lines, FormLayout.minLines)
        XCTAssertFalse(FormLayout.areaLines(for: "two\nlines", width: 300).scrolls, "no scroll track on two lines")
        let long = (0..<20).map { "line \($0)" }.joined(separator: "\n")
        let r = FormLayout.areaLines(for: long, width: 300)
        XCTAssertEqual(r.lines, FormLayout.maxLines); XCTAssertTrue(r.scrolls)
    }

    func testTheStepperMovesByOneFineAndCoarseAndClamps() {
        let n = NumericField.duration
        XCTAssertEqual(n.stepped(3, up: true).value, 4); XCTAssertEqual(n.stepped(3, up: false).value, 2)
        XCTAssertEqual(n.stepped(3, up: true, .fine).value, 3.1, accuracy: 1e-9); XCTAssertEqual(n.stepped(3, up: false, .fine).value, 2.9, accuracy: 1e-9)
        XCTAssertEqual(n.stepped(3, up: true, .coarse).value, 8); XCTAssertEqual(n.stepped(3, up: false, .coarse).value, 0.1, accuracy: 1e-9, "clamped at the least")
        XCTAssertNotNil(n.stepped(3, up: false, .coarse).message, "a clamp says so")
        XCTAssertEqual(n.stepped(599.5, up: true).value, 600); XCTAssertEqual(n.stepped(600, up: true).value, 600)
        XCTAssertFalse(n.canStep(600, up: true)); XCTAssertTrue(n.canStep(600, up: false)); XCTAssertFalse(n.canStep(0.1, up: false))
    }

    func testValuesAreRoundedToATenthAndTypedValuesAreClampedWithAMessage() {
        let n = NumericField.duration
        XCTAssertEqual(n.display(2.04), "2"); XCTAssertEqual(n.display(2.46), "2.5"); XCTAssertEqual(n.round(0.1 + 0.2), 0.3, accuracy: 1e-9)
        XCTAssertEqual(n.typed("2,5").result?.value, 2.5)
        let big = n.typed("9999"); XCTAssertEqual(big.result?.value, 600); XCTAssertNotNil(big.result?.message, "never clamped silently")
        let zero = n.typed("0"); XCTAssertEqual(zero.result?.value, 0.1); XCTAssertNotNil(zero.result?.message)
        XCTAssertNil(n.typed("abc").result); XCTAssertNotNil(n.typed("abc").error)
        XCTAssertNil(n.typed("3").result?.message)
    }

    func testASteppedChangeCommitsOnceAfterTheDebounce() {
        var s = EditSession(validate: SceneFields.invalid); s.load("duration", stored: "3", kind: .numeric)
        let t = Date(timeIntervalSince1970: 5)
        for (i, v) in ["4", "5", "6"].enumerated() { _ = s.edit("duration", draft: v, at: t.addingTimeInterval(Double(i) * 0.1)); s.markStepped("duration", at: t.addingTimeInterval(Double(i) * 0.1)) }
        XCTAssertTrue(s.due(at: t.addingTimeInterval(0.4)).isEmpty); XCTAssertEqual(s.due(at: t.addingTimeInterval(0.6)).map { $0.value }, ["6"])
    }

    func testTheTabModelHasOneSelectedTabAndTheArrowsWrap() throws {
        var m = try XCTUnwrap(TabBarModel(tabs: ["settings", "composition", "look"], selected: "composition"))
        XCTAssertEqual(m.tabs.filter { m.isSelected($0) }.count, 1)
        m.next(); XCTAssertEqual(m.selected, "look"); m.next(); XCTAssertEqual(m.selected, "settings", "wraps")
        m.previous(); XCTAssertEqual(m.selected, "look")
        m.select("nowhere"); XCTAssertEqual(m.selected, "look", "an unknown tab is ignored")
        XCTAssertEqual(TabBarModel(tabs: ["a"], selected: "zzz")?.selected, "a", "an unknown start falls to the first")
        XCTAssertNil(TabBarModel<String>(tabs: [], selected: ""))
    }

    func testASceneHasThreeTabsAndTheEffectsTabIsGone() throws {
        XCTAssertTrue(try source("ProjectModel.swift").contains("case settings, composition, look\n"), "three tabs for a scene")
        XCTAssertFalse(try source("InspectorViews.swift").contains("SceneEffectsTab(id: id)"), "the Effects tab is removed")
    }

    func testPaneWidthsAreWiderBetweenALeastAndAMostAndNeverOverwritten() {
        XCTAssertGreaterThan(PanelLayout.standardInspector, 390); XCTAssertGreaterThan(PanelLayout.standardSettings, 560)
        for r in [RightPanel.inspector, .project, .clap] {
            XCTAssertGreaterThanOrEqual(PaneWidth.clamp(1, for: r), ShellLayout.rightMin(r)); XCTAssertLessThanOrEqual(PaneWidth.clamp(99999, for: r), PaneWidth.maximum(r))
        }
        let stored = PanelLayout(inspector: 5000)
        let f = ShellLayout.frames(window: CGSize(width: 3000, height: 900), placement: .underPreview, sizes: stored, right: .inspector)
        XCTAssertEqual(f.rightWidth, PaneWidth.inspectorMax, "clamped for drawing")
        XCTAssertEqual(stored.inspector, 5000, "the stored width is not overwritten")
        XCTAssertEqual(ShellLayout.standardSizes.inspectorWidth, PanelLayout.standardInspector, "the reset restores the default")
    }

    func testTheInspectorTheFormsTheClapPanelAndSettingsPickNoColour() throws {
        let files = ["InspectorViews", "ContentViews", "ReelViews", "StoryboardViews", "SceneStateViews", "ProjectFormViews", "ProjectSettingsPanel", "LookViews", "PickerViews", "ChatView", "HistoryViews", "BlockViews", "SettingsView", "FormViews", "SceneAutosave"]
        let re = try NSRegularExpression(pattern: #"Color\(red:|Color\(white:|Color\(nsColor:|NSColor\(|(?<![\w])\.(red|orange|green|blue|yellow|teal|purple|gray|pink|white|black)\b|Color\.(red|orange|green|blue|yellow|teal|purple|gray|pink|white|black)\b"#)
        for f in files { let t = try source(f + ".swift"); XCTAssertEqual(re.numberOfMatches(in: t, range: NSRange(t.startIndex..., in: t)), 0, "\(f) picks a colour by itself") }
    }

    func testTheIconRowsUseTheFormSlotsAndNothingOffersDuplicateForAScene() throws {
        let form = try source("FormViews.swift")
        XCTAssertTrue(form.contains("FormLayout.iconSlot") && form.contains("FormLayout.trailingSlot"))
        XCTAssertTrue(try source("StoryboardViews.swift").contains("IconRow(symbol: systemImage, title: title)"), "the State switches share the slots")
        for f in ["InspectorViews.swift", "WorkspaceViews.swift", "TimelineViews.swift", "StoryboardListViews.swift"] { XCTAssertFalse(try source(f).contains("duplicateScene"), "\(f) still offers Duplicate for a scene") }
        let state = try source("StoryboardViews.swift")
        XCTAssertFalse(state.contains("Instruction (what to change"), "no Instruction field in the State section")
        XCTAssertTrue(state.contains("Earlier note:"), "a stored note is shown read-only")
    }

    func testTheProjectButtonOpensTheProjectPanelLikeTheRailAndEveryInspectorHeaderHasIt() throws {
        let form = try source("FormViews.swift")
        XCTAssertTrue(form.contains("project.openRail(.project)"))
        let insp = try source("InspectorViews.swift")
        XCTAssertEqual(insp.components(separatedBy: "ProjectButton()").count - 1, 2, "the shared header and the scene inspector's own")
        XCTAssertFalse(insp.contains("project.selection = .none } label: { Label(\"Project\""))
    }
}
