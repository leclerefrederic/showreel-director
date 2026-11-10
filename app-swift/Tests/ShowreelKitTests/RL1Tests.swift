import XCTest
@testable import ShowreelKit

/// Phase RL1: the rail has two groups and Clap is one of its entries; the right side shows one panel at a time; the shell geometry and the Film placement.
final class RL1Tests: XCTestCase {
    var dir: URL!
    override func setUp() { dir = makeTempDir("rl1") }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    // MARK: the rail

    func testTwoGroupsInOrderWithASeparator() throws {
        XCTAssertEqual(RailEntry.entries(in: .centre), [.film, .build]); XCTAssertEqual(RailEntry.entries(in: .right), [.inspector, .project, .clap])
        XCTAssertEqual(RailEntry.allCases, [.film, .build, .inspector, .project, .clap])
        XCTAssertEqual(RailEntry.allCases.compactMap { $0.panel }, RightPanel.allCases); XCTAssertNil(RailEntry.film.panel)
        XCTAssertTrue(try source("Theme.swift").contains("Rectangle().fill(theme.hairline).frame(width: 36, height: 1)"), "a thin line between the two groups")
    }

    func testExactlyOneRightPanelAtATimeAndAClickOnTheOpenOneCloses() {
        var s = RailState()
        XCTAssertEqual(s.right, .inspector, "a project with no choice opens with the Inspector")
        s.choose(.clap); XCTAssertEqual(s.right, .clap); XCTAssertEqual(RailEntry.allCases.filter { s.isSelected($0) && $0.group == .right }, [.clap])
        s.choose(.project); XCTAssertEqual(s.right, .project); XCTAssertFalse(s.isSelected(.clap))
        s.choose(.project); XCTAssertNil(s.right, "a second click closes the right side"); XCTAssertEqual(RailEntry.allCases.filter { s.isSelected($0) && $0.group == .right }, [])
        s.choose(.project); XCTAssertEqual(s.right, .project)
        for e in RailEntry.entries(in: .right) { var t = s; t.choose(e); XCTAssertLessThanOrEqual(RailEntry.entries(in: .right).filter { t.isSelected($0) }.count, 1) }
    }

    func testACentreViewAndARightPanelAreIndependent() {
        var s = RailState(right: .clap)
        s.choose(.build); XCTAssertTrue(s.build); XCTAssertEqual(s.right, .clap, "Build never closes a right panel")
        s.choose(.film); XCTAssertFalse(s.build); XCTAssertEqual(s.right, .clap)
        s.choose(.build); s.choose(.build); XCTAssertTrue(s.build, "RB1: a centre view never toggles off; Film is the way back")
        s.choose(.project); XCTAssertEqual(s.right, .project)
        s.choose(.build); XCTAssertTrue(s.build, "opening a right panel did not change the centre")
        var t = RailState(build: true, right: nil); t.choose(.inspector); XCTAssertTrue(t.build); XCTAssertEqual(t.right, .inspector)
        XCTAssertFalse(RailState(checks: true).isSelected(.film), "the list of checks is its own centre: no entry is lit")
    }

    func testASelectionOpensTheInspectorOnlyWhenNothingElseIsOpen() {
        var a = RailState(right: nil); a.selectionHappened(); XCTAssertEqual(a.right, .inspector); XCTAssertFalse(a.inspectorMark)
        var b = RailState(right: .inspector); b.selectionHappened(); XCTAssertEqual(b.right, .inspector)
        var c = RailState(right: .clap); c.selectionHappened(); XCTAssertEqual(c.right, .clap, "the open panel stays"); XCTAssertTrue(c.inspectorMark, "and the Inspector entry gets a mark")
        c.choose(.inspector); XCTAssertEqual(c.right, .inspector); XCTAssertFalse(c.inspectorMark, "the mark goes when the Inspector opens")
        var d = RailState(right: .project); d.selectionHappened(); XCTAssertTrue(d.inspectorMark); d.open(.clap); XCTAssertEqual(d.right, .clap)
        var e = RailState(right: .clap); e.open(.clap); XCTAssertEqual(e.right, .clap, "the shortcut opens, it never toggles closed")
    }

    // MARK: Clap's entry

    func testClapsStateAndItsLabel() {
        XCTAssertEqual(ClapIndicator(working: false, proposals: 0).label, "Clap")
        XCTAssertEqual(ClapIndicator(working: true, proposals: 0).label, "Clap, working")
        XCTAssertEqual(ClapIndicator(working: false, proposals: 2).label, "Clap, 2 proposals waiting")
        XCTAssertEqual(ClapIndicator(working: false, proposals: 1).label, "Clap, 1 proposal waiting")
        XCTAssertEqual(ClapIndicator(working: true, proposals: 3).label, "Clap, working, 3 proposals waiting")
        XCTAssertNil(ClapIndicator(working: false, proposals: 0).badge); XCTAssertEqual(ClapIndicator(working: false, proposals: 3).badge, 3)
    }

    func testThePulseBecomesADotUnderReduceMotion() {
        XCTAssertEqual(ClapIndicator(working: true, proposals: 0).motion(reduceMotion: false), .pulse)
        XCTAssertEqual(ClapIndicator(working: true, proposals: 0).motion(reduceMotion: true), .dot)
        XCTAssertEqual(ClapIndicator(working: false, proposals: 2).motion(reduceMotion: false), .none)
        let r = try? source("Theme.swift"); XCTAssertTrue(r?.contains("accessibilityReduceMotion") == true && r?.contains("ClapPulse") == true)
    }

    func testTheShortcutHasNoConflictAndIsShownInTheTooltip() throws {
        let keys = AppShortcuts.used.map { $0.keys }
        XCTAssertEqual(Set(keys).count, keys.count, "no two actions share a shortcut")
        XCTAssertEqual(keys.filter { $0 == AppShortcuts.clap.keys }.count, 1); XCTAssertEqual(AppShortcuts.clapDisplay, "Shift-Command-A")
        // every letter shortcut the views declare is in the list
        let all = try FileManager.default.contentsOfDirectory(atPath: views.path).filter { $0.hasSuffix(".swift") }
        for f in all {
            let t = try source(f)
            let re = try NSRegularExpression(pattern: #"keyboardShortcut\("(.)"(?:, modifiers: (\[[^\]]*\]|\.\w+))?\)"#)
            for m in re.matches(in: t, range: NSRange(t.startIndex..., in: t)) {
                let key = String(t[Range(m.range(at: 1), in: t)!]), mods = m.range(at: 2).location == NSNotFound ? "" : String(t[Range(m.range(at: 2), in: t)!])
                var parts: [String] = []
                if mods.contains("command") { parts.append("cmd") }; if mods.contains("shift") { parts.append("shift") }; if mods.contains("option") { parts.append("option") }
                let combo = (parts + [key]).joined(separator: "+")
                XCTAssertTrue(keys.contains(combo), "\(f) declares \(combo), which the registry does not know")
            }
        }
        let shell = try source("WorkspaceViews.swift"); XCTAssertTrue(shell.contains("keyboardShortcut(\"a\", modifiers: [.command, .shift])") && shell.contains("project.openClap()"))
        XCTAssertTrue(RailEntry.clap.tooltip().contains(AppShortcuts.clapDisplay), "the tooltip shows it (RB1: the rule is ShowreelKit's `RailEntry.tooltip`)")
        XCTAssertTrue(try source("ChatView.swift").contains("inputFocused = true"), "and the cursor goes to the input")
    }

    // MARK: remembered state

    func testTheOpenPanelAndThePlacementAreSavedAndRestoredPerProject() throws {
        let s = ProjectStore(root: dir); try s.create(name: "R", conversationLanguage: "en", reelLanguages: [])
        XCTAssertNil(s.settings.rightPanel, "no choice: the Inspector"); XCTAssertNil(s.settings.filmPlacement)
        var set = s.settings; set.rightPanel = "clap"; set.filmPlacement = FilmPlacement.fullWidth.rawValue; s.settings = set
        let again = ProjectStore(root: dir).settings
        XCTAssertEqual(again.rightPanel, "clap"); XCTAssertEqual(again.filmPlacement, "full" + "Width")
        set.rightPanel = "none"; s.settings = set; XCTAssertEqual(ProjectStore(root: dir).settings.rightPanel, "none", "a closed right side is remembered too")
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("restoreRight(p)") && m.contains("FilmPlacement(rawValue: $0) } ?? .underPreview") && m.contains("persistShell()"))
        // the placement is not in the sizes
        set.layout = PanelLayout(library: 333); s.settings = set
        XCTAssertEqual(ProjectStore(root: dir).settings.filmPlacement, "fullWidth"); XCTAssertEqual(ProjectStore(root: dir).settings.layout?.libraryWidth, 333)
    }

    // MARK: the shell geometry

    let windows = [CGSize(width: 1180, height: 700), CGSize(width: 1440, height: 860), CGSize(width: 1000, height: 560), CGSize(width: 1920, height: 1000)]

    func testUnderThePreviewTheRailThePanelsSpanTheFullHeightAndTheStripIsAsWideAsTheCentre() {
        for w in windows {
            for right in [RightPanel?.some(.inspector), .project, .clap, nil] {
                let f = ShellLayout.frames(window: w, placement: .underPreview, sizes: PanelLayout(), right: right)
                let usable = Double(w.height) - 2 * ShellLayout.gap
                XCTAssertEqual(Double(f.rail.height), Double(w.height)); XCTAssertEqual(Double(f.left.height), usable, accuracy: 0.001)
                if let r = f.right { XCTAssertEqual(Double(r.height), usable, accuracy: 0.001); XCTAssertEqual(Double(r.maxX), Double(w.width) - ShellLayout.gap, accuracy: 0.001) } else { XCTAssertEqual(Double(f.preview.maxX), Double(w.width) - ShellLayout.gap, accuracy: 0.001, "no right panel: the centre takes its room") }
                XCTAssertEqual(f.film.width, f.preview.width, "the strip is as wide as the centre column"); XCTAssertEqual(f.film.minX, f.preview.minX)
                XCTAssertEqual(Double(f.preview.height + f.film.height) + ShellLayout.gap, usable, accuracy: 0.001, "the preview on top, the strip under it")
                XCTAssertEqual(Double(f.left.minX), ShellLayout.rail)
                if ShellLayout.isAllowed(w, .underPreview, right: right) { XCTAssertGreaterThanOrEqual(f.centreWidth, ShellLayout.minCentre(.underPreview) - 0.001) }
            }
        }
    }

    func testAtFullWidthTheStripSpansFromTheLeftPanelToTheRightPanelAndTheRailStaysFullHeight() {
        for w in windows {
            let f = ShellLayout.frames(window: w, placement: .fullWidth, sizes: PanelLayout(), right: .inspector)
            XCTAssertEqual(Double(f.rail.height), Double(w.height))
            XCTAssertEqual(Double(f.film.minX), ShellLayout.rail); XCTAssertEqual(Double(f.film.maxX), Double(w.width) - ShellLayout.gap, accuracy: 0.001)
            XCTAssertEqual(f.film.maxY, CGFloat(Double(w.height) - ShellLayout.gap), accuracy: 0.001)
            XCTAssertEqual(f.left.height, f.preview.height); XCTAssertEqual(f.right?.height, f.preview.height, "the panels are shorter")
            XCTAssertEqual(Double(f.left.height + f.film.height) + 3 * ShellLayout.gap, Double(w.height), accuracy: 0.001)
            XCTAssertLessThan(f.left.height, ShellLayout.frames(window: w, placement: .underPreview, sizes: PanelLayout(), right: .inspector).left.height)
        }
    }

    func testTheMinimumWindowOfEachModeAndAnythingSmallerIsRefused() {
        for p in FilmPlacement.allCases {
            for r in [RightPanel?.some(.inspector), .project, nil] {
                let m = ShellLayout.minimumWindow(p, right: r)
                XCTAssertTrue(ShellLayout.isAllowed(m, p, right: r)); XCTAssertFalse(ShellLayout.isAllowed(CGSize(width: m.width - 1, height: m.height), p, right: r)); XCTAssertFalse(ShellLayout.isAllowed(CGSize(width: m.width, height: m.height - 1), p, right: r))
                let f = ShellLayout.frames(window: m, placement: p, sizes: PanelLayout(), right: r)
                XCTAssertEqual(Double(f.leftWidth), ShellLayout.minLeft, accuracy: 0.001); XCTAssertEqual(Double(f.centreWidth), ShellLayout.minCentre(p), accuracy: 0.001, "at the minimum every region has exactly its floor")
                XCTAssertGreaterThanOrEqual(Double(f.film.height), ShellLayout.minFilm - 0.001); XCTAssertGreaterThanOrEqual(Double(f.preview.height), ShellLayout.minPreviewHeight - 0.001)
            }
        }
        XCTAssertGreaterThan(ShellLayout.minimumWindow(.fullWidth).height, ShellLayout.minimumWindow(.underPreview).height - 1)
        XCTAssertLessThan(ShellLayout.minimumWindow(.underPreview, right: nil).width, ShellLayout.minimumWindow(.underPreview, right: .inspector).width)
        XCTAssertGreaterThan(ShellLayout.minimumWindow(.underPreview, right: .project).width, ShellLayout.minimumWindow(.underPreview, right: .inspector).width, "Look and Project need a wider panel")
    }

    func testTheSizesTheOwnerChoseAreNeverChangedByThePlacementOrASmallWindow() {
        let stored = PanelLayout(library: 340, inspector: 420, strip: 320, settings: 600, split: 0.6, resources: .collapsed)
        let before = stored
        let big = CGSize(width: 1800, height: 1000), small = CGSize(width: 1000, height: 600)
        let a = ShellLayout.frames(window: big, placement: .underPreview, sizes: stored, right: .inspector)
        XCTAssertEqual(a.leftWidth, 340); XCTAssertEqual(a.rightWidth, 420); XCTAssertEqual(a.filmHeight, 320)
        let b = ShellLayout.frames(window: big, placement: .fullWidth, sizes: stored, right: .inspector)
        XCTAssertEqual(b.leftWidth, 340); XCTAssertEqual(b.rightWidth, 420); XCTAssertEqual(b.filmHeight, 320, "the placement only arranges the regions around the same values")
        let c = ShellLayout.frames(window: small, placement: .underPreview, sizes: stored, right: .inspector)
        XCTAssertLessThan(c.leftWidth + c.rightWidth, 340 + 420, "a small window clamps them for drawing")
        let again = ShellLayout.frames(window: big, placement: .underPreview, sizes: stored, right: .inspector)
        XCTAssertEqual(again, a, "and a bigger window brings the choices back"); XCTAssertEqual(stored, before, "nothing was overwritten")
        XCTAssertEqual(ShellLayout.frames(window: big, placement: .underPreview, sizes: stored, right: .project).rightWidth, 600, "Look and Project use their own stored width")
    }

    func testTheResetRestoresTheStandardProportionsAndKeepsThePlacement() throws {
        let s = ProjectStore(root: dir); try s.create(name: "R", conversationLanguage: "en", reelLanguages: [])
        var set = s.settings; set.layout = PanelLayout(library: 340, inspector: 420, strip: 320); set.filmPlacement = "fullWidth"; s.settings = set
        XCTAssertFalse(ShellLayout.standardSizes.isStandard == false, "the standard is the empty layout")
        set.layout = ShellLayout.standardSizes.isStandard ? nil : ShellLayout.standardSizes; s.settings = set      // what `resetLayout` writes
        let after = ProjectStore(root: dir).settings
        XCTAssertNil(after.layout); XCTAssertEqual(after.filmPlacement, "fullWidth", "the reset does not change the placement")
        XCTAssertEqual(ShellLayout.frames(window: CGSize(width: 1400, height: 800), placement: .underPreview, sizes: PanelLayout(), right: .inspector).leftWidth, PanelLayout.standardLibrary)
        let m = try source("ProjectModel.swift"); XCTAssertTrue(m.contains("func resetLayout() { setLayout(ShellLayout.standardSizes) }"))
    }

    // MARK: the Film placement button and the view group

    func testTheButtonsPictogramMatchesTheLayoutAndItsTooltipNamesTheStateAndTheAction() throws {
        XCTAssertEqual(FilmPlacement.underPreview.tooltip, "Film under the preview. Click for full width"); XCTAssertEqual(FilmPlacement.fullWidth.tooltip, "Film at full width. Click for under the preview")
        XCTAssertEqual(FilmPlacement.underPreview.role, .layoutUnderPreview); XCTAssertEqual(FilmPlacement.fullWidth.role, .layoutFullWidth)
        XCTAssertEqual(FilmPlacement.underPreview.other, .fullWidth); XCTAssertEqual(FilmPlacement.fullWidth.other.other, .fullWidth)
        for r in [IconRole.layoutUnderPreview, .layoutFullWidth] { XCTAssertNotNil(IconRole.table[r]); XCTAssertTrue(r.isPictogram, "drawn by the theme, replaceable by a skin") }
        XCTAssertNotEqual(IconRole.layoutUnderPreview.symbol, IconRole.layoutFullWidth.symbol); XCTAssertFalse(IconRole.resetLayout.isPictogram)
        let t = try source("Theme.swift")
        XCTAssertTrue(t.contains("LayoutPictogram(placement: p)") && t.contains(".accessibilityValue(p.name)") && t.contains(".help(p.tooltip)"))
        XCTAssertTrue(t.contains("\"The proportions are already standard\"") && t.contains("Restore the standard proportions") && t.contains("Motion.go { project.resetLayout() }"))
    }

    func testTheTopBarKeepsWhatItHadAndTheViewGroupIsAtItsRightEnd() throws {
        let bar = try source("ProjectView.swift")
        XCTAssertFalse(bar.contains("Reset layout"), "one reset: the old control is replaced")
        let badge = try XCTUnwrap(bar.range(of: "ChecksBadge()")), cat = try XCTUnwrap(bar.range(of: "Button { project.showCatalogue.toggle() }")), group = try XCTUnwrap(bar.range(of: "ViewGroup()"))
        XCTAssertLessThan(badge.lowerBound, cat.lowerBound); XCTAssertLessThan(cat.lowerBound, group.lowerBound, "after the Checks badge and the Catalogue")
        XCTAssertTrue(bar.contains("Button { openWindow(id: \"library\") }") && bar.contains("BuildProgressPanel(compact: true); ClapActivityChip()"))
    }

    func testTheStripIsNamedFilmAndTheListStoryboardAndTheStripToolbarFitsTheCentreColumn() throws {
        XCTAssertTrue(try source("TimelineViews.swift").contains("Label(\"Film\", systemImage:")); XCTAssertFalse(try source("TimelineViews.swift").contains("Label(\"Storyboard\""))
        XCTAssertTrue(try source("StoryboardListViews.swift").contains("SectionHeader(title: \"Storyboard\""))
        XCTAssertFalse(try source("TimelineViews.swift").contains("Validate storyboard"), "the implicit Go: no validation button in the toolbar (SM1)")
        XCTAssertEqual(TimelineLayout.toolbarRows(width: 900), 1); XCTAssertEqual(TimelineLayout.toolbarRows(width: 520), 2)
        XCTAssertEqual(TimelineLayout.sizes(panelHeight: 400, hasMusic: true, toolbarRows: 2).toolbar, 2 * TimelineLayout.toolbar)
        XCTAssertLessThan(TimelineLayout.sizes(panelHeight: 400, hasMusic: true, toolbarRows: 2).frame, TimelineLayout.sizes(panelHeight: 400, hasMusic: true).frame)
    }

    func testEveryRoleIsMappedAndTheNewOnesAreDistinct() {
        for r in IconRole.allCases { XCTAssertNotNil(IconRole.table[r], r.rawValue) }
        XCTAssertEqual(IconRole.table.count, IconRole.allCases.count)
        let rail = RailEntry.allCases.map { $0.role.symbol }; XCTAssertEqual(Set(rail).count, rail.count, "one icon per entry")
        XCTAssertEqual(Set(IconRole.statusRoles.map { $0.symbol }).count, 6)
    }

    func testEveryUnavailableEntryHasAReasonAndAWayBack() {
        for e in RailEntry.allCases {
            let u = e.unavailable(workspaceOpen: false, progressLine: "1 of 4 set")
            XCTAssertNotNil(u); XCTAssertFalse(u?.reason.isEmpty ?? true); XCTAssertFalse(u?.way.isEmpty ?? true); XCTAssertNil(e.unavailable(workspaceOpen: true, progressLine: ""))
        }
    }
}
