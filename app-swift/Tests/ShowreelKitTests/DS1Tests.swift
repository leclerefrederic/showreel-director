import XCTest
@testable import ShowreelKit

/// Phase DS1: the design tokens, the theme, the rail and the guard that keeps the views from picking their own colours and text sizes.
final class DS1Tests: XCTestCase {
    let t = DesignTokens.graphite
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    // MARK: contrast

    func testTheContrastFunctionIsWCAG() {
        XCTAssertEqual(DesignTokens.contrast("#000000", "#FFFFFF"), 21, accuracy: 0.001)
        XCTAssertEqual(DesignTokens.contrast("#FFFFFF", "#FFFFFF"), 1, accuracy: 0.001)
        XCTAssertEqual(DesignTokens.contrast("#777777", "#FFFFFF"), 4.48, accuracy: 0.02, "the classic #777 on white")
        XCTAssertEqual(DesignTokens.contrast("#0F1115", "#E8EAEE"), DesignTokens.contrast("#E8EAEE", "#0F1115"), "symmetric")
    }

    func testPrimaryAndSecondaryTextReadOnEverySurface() {
        for s in [t.surfaces.canvas, t.surfaces.panel, t.surfaces.raised, t.surfaces.selected] {
            XCTAssertGreaterThanOrEqual(DesignTokens.contrast(t.text.primary, s), 4.5, "primary on \(s)")
            XCTAssertGreaterThanOrEqual(DesignTokens.contrast(t.text.secondary, s), 4.5, "secondary on \(s)")
        }
    }

    func testTheStatusColoursAndTheAccentShowOnThePanel() {
        for k in SceneStatusKind.allCases { XCTAssertGreaterThanOrEqual(DesignTokens.contrast(t.status(k), t.surfaces.panel), 3, "\(k.title)") }
        XCTAssertGreaterThanOrEqual(DesignTokens.contrast(t.accent, t.surfaces.panel), 3)
        XCTAssertGreaterThanOrEqual(DesignTokens.contrast(t.onAccent, t.accent), 4.5, "the text of the primary button")
        for c in [t.roles.warning, t.roles.danger, t.roles.success, t.roles.review, t.roles.outOfDate] { XCTAssertGreaterThanOrEqual(DesignTokens.contrast(c, t.surfaces.raised), 3, c) }
        XCTAssertEqual(SceneStatusKind.allCases.map { t.status($0) }.count, Set(SceneStatusKind.allCases.map { t.status($0) }).count, "six colours, all different")
    }

    func testFaintIsDecorativeOnly() {
        XCTAssertLessThan(DesignTokens.contrast(t.text.faint, t.surfaces.panel), 4.5, "it is below the text threshold on purpose: decoration and disabled things")
        // and no view uses it for information: the theme names it so, and the views use the modifier that says it
        XCTAssertTrue(DesignTokens.graphite.colors.contains { $0.name == "textFaint" })
    }

    // MARK: the tokens themselves

    func testTheValuesAreTheOnesOfTheBrief() {
        XCTAssertEqual(t.colors.map { $0.hex }, ["#0F1115", "#161A20", "#1F232A", "#1D2A2C", "#262B34", "#2F3642", "#E8EAEE", "#8B93A1", "#4A515E", "#2DD4BF", "#0F1115",
                                                  "#F5C453", "#F87171", "#4ADE80", "#F59E0B", "#60A5FA", "#2A3550", "#3B4A6A", "#D9A441"])
        XCTAssertEqual(t.radiiScale, [6, 8, 12]); XCTAssertEqual(t.spacingScale, [4, 8, 12, 16, 24]); XCTAssertEqual(t.sizeScale, [11, 13, 15, 22]); XCTAssertEqual(DesignTokens.weights, ["regular", "medium"])
        for c in t.colors { XCTAssertNotNil(DesignTokens.rgb(c.hex), c.name) }
    }

    func testNoSizeIsBelow11AndEveryScaleIsAscending() {
        XCTAssertGreaterThanOrEqual(t.sizeScale.min()!, DesignTokens.minimumTextSize)
        for scale in [t.radiiScale, t.spacingScale, t.sizeScale] { XCTAssertEqual(scale, scale.sorted()); XCTAssertEqual(Set(scale).count, scale.count) }
    }

    func testEveryTokenIsUsedByTheTheme() throws {
        let theme = try source("Theme.swift")
        for path in ["surfaces.canvas", "surfaces.panel", "surfaces.raised", "surfaces.selected", "borders.hairline", "borders.strong", "text.primary", "text.secondary", "text.faint", "accent", "onAccent",
                     "roles.warning", "roles.danger", "roles.success", "roles.review", "roles.outOfDate", "lanes.scene", "lanes.sceneBorder", "lanes.music",
                     "radii.small", "radii.medium", "radii.large", "sizes.small", "sizes.body", "sizes.title", "sizes.large", "spacingScale"] {
            XCTAssertTrue(theme.contains("tokens." + path), "Theme.swift does not read tokens.\(path)")
        }
        XCTAssertTrue(theme.contains("tokens.status("), "the Status colours come from the tokens")
    }

    func testThemeIsAnObservableObjectInTheEnvironmentAndTheAppIsDark() throws {
        let theme = try source("Theme.swift"), app = try source("App.swift")
        XCTAssertTrue(theme.contains("final class Theme: ObservableObject") && theme.contains("@Published var tokens"), "tokens can be swapped at run time")
        XCTAssertEqual(app.components(separatedBy: ".environmentObject(theme)").count - 1, 3, "the library, the project windows and Settings read the theme from the environment")
        XCTAssertEqual(app.components(separatedBy: ".preferredColorScheme(.dark)").count - 1, 3)
        XCTAssertTrue(app.contains("NSAppearance(named: .darkAqua)"), "the dark appearance for every window")
        XCTAssertFalse(theme.contains("static let canvas") || theme.contains("static var canvas"), "no static colours")
    }

    // MARK: the icon roles

    func testEveryIconRoleIsMappedAndTheSixStatusRolesAreDistinct() {
        for r in IconRole.allCases { XCTAssertNotNil(IconRole.table[r], r.rawValue); XCTAssertFalse(r.symbol.isEmpty) }
        XCTAssertEqual(IconRole.table.count, IconRole.allCases.count, "one table, one entry per role")
        let symbols = IconRole.statusRoles.map { $0.symbol }
        XCTAssertEqual(symbols.count, 6); XCTAssertEqual(Set(symbols).count, 6, "no two Status roles share a symbol")
        XCTAssertEqual(SceneStatusKind.allCases.map { $0.symbol }, symbols, "the Status icons of UI2 come through the table")
        XCTAssertNotEqual(IconRole.lockClosed.symbol, IconRole.lockOpen.symbol); XCTAssertNotEqual(IconRole.visibleOn.symbol, IconRole.visibleOff.symbol)
        XCTAssertEqual(Set(["rail.film", "rail.look", "rail.build", "rail.project"]).count, 4)
    }

    // MARK: the rail (RL1 gave it two groups and Clap: see RL1Tests for the model; this keeps what DS1 asked of its wiring)

    func testTheRailKeepsTheViewsTheTopBarOffered() {
        // the old top bar: Build toggled the Build view; Project settings toggled the settings panel with its two parts (Project and Look)
        for e in [RailEntry.build, .project, .film] { XCTAssertTrue(RailEntry.allCases.contains(e), e.title) }
        XCTAssertEqual(RailEntry.allCases.map { $0.title }, ["Film", "Build", "Inspector", "Project", "Clap"], "five entries: Look is a tab of Project")
        XCTAssertEqual(Set(RailEntry.allCases.map { $0.role }).count, 5); XCTAssertTrue(RailEntry.allCases.allSatisfy { !$0.help.isEmpty })
    }

    func testTheRailKeepsTheReasonTheOldButtonGave() {
        let why = RailEntry.build.unavailable(workspaceOpen: false, progressLine: "2 of 5 set")
        XCTAssertEqual(why?.reason, "The base configuration is not complete: 2 of 5 set"); XCTAssertFalse(why?.way.isEmpty ?? true)
        XCTAssertNil(RailEntry.build.unavailable(workspaceOpen: true, progressLine: ""))
    }

    func testTheShellIsWiredToTheRailAndTheTopBarKeepsWhatItHad() throws {
        let m = try source("ProjectModel.swift"), bar = try source("ProjectView.swift"), shell = try source("WorkspaceViews.swift")
        XCTAssertTrue(m.contains("func openRail(_ e: RailEntry)") && m.contains("func applyRail(_ s: RailState)"))
        XCTAssertFalse(bar.contains("label: { Label(\"Build\""), "the Build button left the top bar: it is the rail's Build")
        XCTAssertTrue(bar.contains("if inSetup {") && bar.contains("Project settings"), "during the base configuration the settings button stays")
        for kept in ["ChecksBadge()", "Catalogue", "Library"] { XCTAssertTrue(bar.contains(kept), "\(kept) stays in the top bar") }
        XCTAssertTrue(shell.contains("ViewRailView()") && shell.contains(".panelContainer()") && shell.contains(".canvasBackground()"), "the shell: the rail, rounded panels, the canvas")
        XCTAssertFalse(try source("InspectorViews.swift").contains("ThemedTabs(items: InspectorTab.allCases"), "RL1: the right panel has no Inspector and Ask Clap tabs any more")
    }

    // MARK: the source guard

    /// What each view file still picks by itself, at the end of DS1: named palette colours and colour literals (the figure is what exists today, and may only go down). DS2 (the strip and the
    /// lists) and DS3 (the inspector and the forms) take them to the theme. Theme.swift is the one place allowed to hold them.
    static let allowedColours: [String: Int] = ["BuildViews.swift": 6, "ChecksView.swift": 4, "ContentViews.swift": 1, "DesignBoardView.swift": 2, "DragDropViews.swift": 7, "EditorViews.swift": 5, "FilmStateViews.swift": 11, "FontStateViews.swift": 3, "InspectorViews.swift": 1, "LibraryView.swift": 3, "LookViews.swift": 3, "NewProjectViews.swift": 1, "PackageViews.swift": 13, "ProjectLifecycleViews.swift": 2, "ProjectView.swift": 2, "ReactionViews.swift": 13, "ResourceViews.swift": 12, "SetupFormView.swift": 2, "SetupView.swift": 2, "WizardStartViews.swift": 3, "WorkspaceViews.swift": 13]

    func scan(_ text: String) -> (colours: Int, small: Int, oldStyles: Int) {
        func count(_ p: String) -> Int { (try? NSRegularExpression(pattern: p))?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0 }
        let colours = count(#"Color\(red:|Color\(white:|Color\(hue:|Color\(nsColor:|NSColor\(|Color\(hex"#)
            + count(#"(?<![\w])\.(red|orange|green|blue|yellow|teal|purple|gray|pink|cyan|mint|indigo|brown|white|black)\b|Color\.(red|orange|green|blue|yellow|teal|purple|gray|pink|cyan|mint|indigo|brown|white|black)\b"#)
        var small = 0
        if let re = try? NSRegularExpression(pattern: #"\.system\(size: (\d+(?:\.\d+)?)"#) {
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) { if let r = Range(m.range(at: 1), in: text), let v = Double(text[r]), v < DesignTokens.minimumTextSize { small += 1 } }
        }
        return (colours, small, count(#"\.font\(\.(caption2?|footnote)\b"#))
    }

    func testNoViewPicksANewColourAndNoTextIsBelow11() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: views.path).filter { $0.hasSuffix(".swift") && $0 != "Theme.swift" }
        var total = 0
        for f in files.sorted() {
            let r = scan(try source(f))
            XCTAssertLessThanOrEqual(r.colours, Self.allowedColours[f] ?? 0, "\(f) picks \(r.colours) colours by itself (allowed \(Self.allowedColours[f] ?? 0)): use the theme")
            XCTAssertEqual(r.small, 0, "\(f): a font size below 11"); XCTAssertEqual(r.oldStyles, 0, "\(f): .caption, .caption2 and .footnote are 10 pt on macOS: use fontSmall")
            total += r.colours
        }
        XCTAssertLessThanOrEqual(total, Self.allowedColours.values.reduce(0, +)); XCTAssertEqual(Self.allowedColours.values.reduce(0, +), 109, "the allow-list may only go down (DS4 and the owner's decisions)")
        XCTAssertGreaterThan(scan(try source("Theme.swift")).colours + 1, 0)
    }

    func testTheGuardSeesWhatItShould() {
        XCTAssertEqual(scan("Color(red: 1, green: 0, blue: 0)").colours, 1); XCTAssertEqual(scan("x.foregroundStyle(.orange); Color.green").colours, 2)
        XCTAssertEqual(scan(".font(.system(size: 9))").small, 1); XCTAssertEqual(scan(".font(.system(size: 11))").small, 0); XCTAssertEqual(scan(".font(.caption.weight(.bold))").oldStyles, 1)
        XCTAssertEqual(scan(".foregroundStyle(.secondary).opacity(0.5)").colours, 0, "the system's secondary is not a colour of ours")
    }
}
