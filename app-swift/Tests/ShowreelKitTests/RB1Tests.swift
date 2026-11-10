import XCTest
@testable import ShowreelKit

/// Phase RB1: the behaviour of the rail's buttons as one rule (ShowreelKit), and the rail always showing what is on screen.
final class RB1Tests: XCTestCase {
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }
    let allRight: [RightPanel?] = [nil] + RightPanel.allCases.map { Optional($0) }

    // MARK: the rule, row by row

    func testAClickOnARightPanelClosedOpensItAndOnTheOpenOneClosesIt() {
        for p in RightPanel.allCases {
            let e = RailEntry.entry(for: p)
            var s = RailState(right: nil); s.choose(e); XCTAssertEqual(s.right, p, "closed side: opens")
            s.choose(e); XCTAssertNil(s.right, "already open: closes")
            for other in RightPanel.allCases where other != p { var t = RailState(right: other); t.choose(e); XCTAssertEqual(t.right, p, "another panel open: this one replaces it") }
        }
    }

    func testACentreViewNeverTogglesOffAndNeverTouchesTheRightSide() {
        for r in allRight {
            for e in [RailEntry.film, .build] {
                var s = RailState(right: r); s.choose(e); let once = s; s.choose(e)
                XCTAssertEqual(s, once, "a second click on the active centre view does nothing"); XCTAssertTrue(s.isSelected(e)); XCTAssertEqual(s.right, r)
            }
            var s = RailState(build: true, right: r); s.choose(.film); XCTAssertTrue(s.isSelected(.film)); XCTAssertFalse(s.isSelected(.build))
            var t = RailState(checks: true, right: r); t.choose(.build); XCTAssertTrue(t.isSelected(.build)); XCTAssertFalse(t.checks)
            var u = RailState(checks: true, right: r); u.choose(.film); XCTAssertTrue(u.isSelected(.film))
        }
    }

    func testARightPanelNeverTouchesTheCentre() {
        for e in RailEntry.entries(in: .right) {
            var s = RailState(build: true, right: nil); s.choose(e); XCTAssertTrue(s.build)
            var t = RailState(checks: true, right: nil); t.choose(e); XCTAssertTrue(t.checks)
        }
    }

    func testExactlyOneEntryOfEachGroupIsLitAtMostAndTheCentreAlwaysHasOne() {
        let centres: [RailState] = [RailState(), RailState(build: true), RailState(checks: true)]
        for c in centres { for r in allRight {
            var s = c; s.right = r
            XCTAssertLessThanOrEqual(RailEntry.entries(in: .centre).filter { s.isSelected($0) }.count, 1)
            XCTAssertEqual(RailEntry.entries(in: .right).filter { s.isSelected($0) }.count, r == nil ? 0 : 1)
        } }
        XCTAssertEqual(RailEntry.entries(in: .centre).filter { RailState().isSelected($0) }, [.film])
    }

    func testAnUnavailableEntrySaysWhyAndHowToGetItBackInItsTooltipAndItsLabel() {
        for e in RailEntry.allCases {
            let u = e.unavailable(workspaceOpen: false, progressLine: "2 of 5 set")
            let t = e.tooltip(unavailable: u)
            XCTAssertTrue(t.contains("The base configuration is not complete: 2 of 5 set") && t.contains("Finish it, then open the workspace") && t.hasPrefix(e.title))
            XCTAssertFalse(e.tooltip().contains("not complete"))
        }
    }

    func testTheArrowsMoveInsideAGroupAndWrapInTheRailsOrder() {
        XCTAssertEqual(RailEntry.film.neighbour(1), .build); XCTAssertEqual(RailEntry.build.neighbour(1), .film, "wraps inside the centre group")
        XCTAssertEqual(RailEntry.film.neighbour(-1), .build)
        let right = RailEntry.entries(in: .right)
        XCTAssertEqual(right, [.inspector, .look, .project, .clap])
        for (i, e) in right.enumerated() { XCTAssertEqual(e.neighbour(1), right[(i + 1) % 4]); XCTAssertEqual(e.neighbour(-1), right[(i + 3) % 4]) }
        XCTAssertEqual(RailEntry.clap.neighbour(1), .inspector, "wraps inside the right group")
        for e in RailEntry.allCases { XCTAssertEqual(e.neighbour(1).group, e.group, "an arrow never leaves its group"); XCTAssertEqual(e.neighbour(0), e) }
    }

    // MARK: tooltips and accessibility

    func testEveryTooltipHasTheNameAndTheShortcutWhenThereIsOne() {
        for e in RailEntry.allCases {
            XCTAssertTrue(e.tooltip().hasPrefix(e.title), "\(e.title): the tooltip starts with the name")
            XCTAssertTrue(e.tooltip().contains(e.help))
            XCTAssertEqual(e.tooltip().hasSuffix(")") && e.tooltip().contains("(Shift-"), e.shortcut != nil, "a shortcut shows exactly when the entry has one")
        }
        XCTAssertEqual(RailEntry.allCases.compactMap { $0.shortcut }, ["Shift-Command-A"])
        XCTAssertTrue(RailEntry.clap.tooltip(clap: ClapIndicator(working: true, proposals: 2)).hasPrefix("Clap, working, 2 proposals waiting. "))
    }

    func testEveryEntryHasAnAccessibilityLabelAndAHint() {
        for e in RailEntry.allCases { XCTAssertFalse(e.label().isEmpty); XCTAssertFalse(e.help.isEmpty) }
        XCTAssertEqual(RailEntry.inspector.label(marked: true), "Inspector, a new selection is waiting"); XCTAssertEqual(RailEntry.inspector.label(), "Inspector")
        XCTAssertEqual(RailEntry.clap.label(clap: ClapIndicator(working: false, proposals: 1)), "Clap, 1 proposal waiting")
    }

    // MARK: the rail and the screen agree

    func testRightSideWritingAPanelAlwaysMakesItTheVisibleOneFromAnyState() {
        let states: [RightSide] = [RightSide(), RightSide(closed: true), RightSide(clap: true), RightSide(closed: true, clap: true), RightSide(settings: .look), RightSide(clap: true, settings: .project), RightSide(closed: true, settings: .look)]
        for st in states { for p in allRight { var s = st; s.show(p); XCTAssertEqual(s.panel, p, "\(st) then show(\(String(describing: p)))") } }
        XCTAssertEqual(RightSide().panel, .inspector); XCTAssertEqual(RightSide(clap: true).panel, .clap); XCTAssertEqual(RightSide(settings: .look).panel, .look)
        XCTAssertNil(RightSide(closed: true, clap: true, settings: .project).panel)
    }

    func testABuildStartingShowsTheBuildAndClapWhateverWasOpen() {
        for r in allRight { for c in [RailState(), RailState(build: true), RailState(checks: true)] {
            var s = c; s.right = r; s.buildStarted()
            XCTAssertTrue(s.isSelected(.build)); XCTAssertTrue(s.isSelected(.clap)); XCTAssertFalse(s.isSelected(.film)); XCTAssertEqual(s.right, .clap)
        } }
    }

    func testTheInspectorMarkNeverShowsOnTheOpenInspectorAndGoesWhenItOpens() {
        XCTAssertFalse(RailState(right: .inspector, inspectorMark: true).inspectorMarked, "a mark on a lit entry says nothing")
        XCTAssertTrue(RailState(right: .look, inspectorMark: true).inspectorMarked); XCTAssertTrue(RailState(right: nil, inspectorMark: true).inspectorMarked)
        for p in RightPanel.allCases { var s = RailState(right: .clap, inspectorMark: true); s.open(p); XCTAssertEqual(s.inspectorMark, p != .inspector) }
    }

    func testASelectionLeavesTheRailMatchingWhatIsShown() {
        for r in allRight {
            var s = RailState(right: r); s.selectionHappened()
            if r == nil || r == .inspector { XCTAssertEqual(s.right, .inspector); XCTAssertFalse(s.inspectorMarked) } else { XCTAssertEqual(s.right, r); XCTAssertTrue(s.inspectorMarked) }
            XCTAssertEqual(RailEntry.entries(in: .right).filter { s.isSelected($0) }.count, 1)
        }
    }

    func testTheLaunchStateAndTheResetAndTheLayoutButtonDoNotTouchTheRail() throws {
        XCTAssertEqual(RailState(), RailState(build: false, checks: false, right: .inspector), "a project with no choice opens on the Film and the Inspector")
        XCTAssertTrue(RailState().isSelected(.film) && RailState().isSelected(.inspector))
        let m = try source("ProjectModel.swift")
        func body(_ f: String) -> String { let r = m.range(of: f)!; return String(m[r.upperBound...].prefix(260)) }
        for f in ["func resetLayout() {", "func toggleFilmPlacement() {", "func setLayout(_ l: PanelLayout) {"] {
            let b = body(f); XCTAssertFalse(b.contains("rightClosed") || b.contains("centerMode") || b.contains("showProjectSettings") || b.contains("applyRail"), "\(f) leaves the rail alone")
        }
    }

    func testEveryWayToOpenClapOrAPanelGoesThroughTheRailsOperations() throws {
        // the four places that used to set Clap's tab by hand (which did nothing when the tab was already Clap and a settings panel or a closed side covered it)
        for (f, call) in [("ProjectModel.swift", "var rail = railState; rail.buildStarted(); applyRail(rail)"), ("ProjectModel.swift", "showCopilot = true; showClap()"), ("ChatModel.swift", "project.showClap(); project.clapSection"), ("StoryboardListViews.swift", "project.showClap()")] {
            XCTAssertTrue(try source(f).contains(call), "\(f): \(call)")
        }
        var hand = 0
        for f in try FileManager.default.contentsOfDirectory(atPath: views.path) where f.hasSuffix(".swift") {
            hand += try source(f).components(separatedBy: "inspectorTab = .copilot").count - 1
        }
        XCTAssertEqual(hand, 2, "only the two writes inside the model's own rail code remain (restoreRight and setRight)")
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("var rightPanel: RightPanel? { rightSide.panel }") && m.contains("var r = rightSide; r.show(p)"))
        XCTAssertTrue(m.contains("func openRail(_ e: RailEntry)") && m.contains("func openSettings(") && m.contains("project.openRail(.project)") == false)
        XCTAssertTrue(try source("FormViews.swift").contains("project.openRail(.project)"), "the Project button of the inspector headers uses the rail's operation")
    }

    func testTheRailViewOnlyCallsTheRuleAndDrawsTheSixStates() throws {
        let t = try source("Theme.swift")
        for needle in ["e.tooltip(clap: ind, marked: marked, unavailable: why)", "e.label(clap: ind, marked: marked)", "f.neighbour(1)", "f.neighbour(-1)", ".disabledWithReason(why?.reason, way: why?.way)",
                       "configuration.isPressed", "hovering ? theme.raised", "ringed ? theme.accent", ".animation(Motion.quick, value: selected)", ".accessibilityAddTraits(state.isSelected(e) ? [.isButton, .isSelected] : .isButton)"] {
            XCTAssertTrue(t.contains(needle), needle)
        }
    }
}
