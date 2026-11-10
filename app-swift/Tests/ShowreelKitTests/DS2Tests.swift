import XCTest
@testable import ShowreelKit

/// Phase DS2: the Film strip and the Storyboard list on the tokens, the strip without clutter, and the motion language.
final class DS2Tests: XCTestCase {
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    // MARK: motion tokens

    func testDurationsAreOnTheScaleAndDirectActionsStayUnder300ms() {
        let m = MotionTokens.standard
        XCTAssertEqual([m.fast, m.base, m.slow], [0.12, 0.2, 0.3])
        for p in MotionTokens.Pattern.allCases {
            let r = m.resolve(p, reduceMotion: false)
            XCTAssertLessThanOrEqual(r.duration, MotionTokens.directLimit, "\(p)")
            XCTAssertGreaterThan(r.duration, 0, "\(p)")
        }
        var slow = MotionTokens(); slow.speed = 0.2
        for p in MotionTokens.Pattern.allCases { XCTAssertLessThanOrEqual(slow.resolve(p, reduceMotion: false).duration, MotionTokens.directLimit) }
    }

    func testSpeedZeroIsOffAndReduceMotionNeverMoves() {
        var m = MotionTokens(); m.speed = 0
        for p in MotionTokens.Pattern.allCases { XCTAssertTrue(m.resolve(p, reduceMotion: false).isNone, "\(p)"); XCTAssertFalse(m.resolve(p, reduceMotion: false).moves) }
        let s = MotionTokens.standard
        for p in MotionTokens.Pattern.allCases {
            let r = s.resolve(p, reduceMotion: true)
            XCTAssertFalse(r.moves, "\(p): Reduce motion turns movement into a fade or nothing")
            XCTAssertLessThanOrEqual(r.duration, s.fast)
        }
        for p in [MotionTokens.Pattern.nudge, .stateChange, .pop] { XCTAssertTrue(s.resolve(p, reduceMotion: true).isNone, "\(p) only moves: nothing under Reduce motion") }
    }

    func testThePanelSpringIsOneTokenAndTheThreePanesUseIt() throws {
        XCTAssertEqual(MotionTokens.standard.panel, MotionTokens.Spring(response: 0.32, damping: 0.82))
        let motion = try source("Motion.swift")
        XCTAssertTrue(motion.contains("static var spring: Animation? { animation(.panel) }"))
        for f in ["LookViews.swift", "ProjectSettingsPanel.swift", "WorkspaceViews.swift"] {
            let t = try source(f)
            XCTAssertFalse(t.contains(".spring(response"), "\(f) has its own spring")
        }
        let uses = try ["LookViews.swift", "ProjectModel.swift", "WorkspaceViews.swift", "ContentViews.swift"].map { try source($0) }.joined()
        XCTAssertTrue(uses.contains("Motion.spring") || uses.contains("Motion.go"), "the panes slide with the token")
    }

    // MARK: guards

    func testNoViewOutsideMotionWritesARawDurationOrCurve() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: views.path).filter { $0.hasSuffix(".swift") && $0 != "Motion.swift" }
        let re = try NSRegularExpression(pattern: #"\.(easeOut|easeIn|easeInOut|linear|spring|interpolatingSpring|timingCurve)\(|Animation\.[a-z]+\(|withAnimation\([^)]*duration"#)
        var raw: [String: Int] = [:]
        for f in files.sorted() {
            let t = try source(f)
            let n = re.numberOfMatches(in: t, range: NSRange(t.startIndex..., in: t))
            if n > 0 { raw[f] = n }
        }
        XCTAssertLessThanOrEqual(raw.values.reduce(0, +), Self.allowedRawMotion.values.reduce(0, +), "a view writes a raw duration or curve: use Motion (\(raw))")
        for (f, n) in raw { XCTAssertLessThanOrEqual(n, Self.allowedRawMotion[f] ?? 0, "\(f): \(n) raw durations or curves, allowed \(Self.allowedRawMotion[f] ?? 0)") }
    }

    /// What exists today and may only go down.
    static let allowedRawMotion: [String: Int] = [:]

    func testTheStripAndTheListPickNoColour() throws {
        for f in ["TimelineViews.swift", "StoryboardListViews.swift"] {
            let t = try source(f)
            let re = try NSRegularExpression(pattern: #"Color\(red:|Color\(white:|Color\(nsColor:|NSColor\(|(?<![\w])\.(red|orange|green|blue|yellow|teal|purple|gray|pink|white|black)\b|Color\.(red|orange|green|blue|yellow|teal|purple|gray|pink|white|black)\b"#)
            XCTAssertEqual(re.numberOfMatches(in: t, range: NSRange(t.startIndex..., in: t)), 0, "\(f) picks a colour by itself")
            XCTAssertFalse(t.contains("StripColor"), "\(f): the strip reads Theme")
        }
    }

    // MARK: thumbnail and diamond

    func testTheThumbnailAlwaysLiesInsideItsFrame() {
        for w in stride(from: 1.0, through: 600.0, by: 7) {
            for h in [36.0, 44, 60, 72, 90, 103, 104, 120, 180] {
                let e = FrameLayout.elements(width: w, height: h, hasName: true, idLength: 3, nameLength: 12)
                let frame = CGRect(x: 0, y: 0, width: w, height: h)
                XCTAssertTrue(frame.insetBy(dx: -0.001, dy: -0.001).contains(e.thumb), "thumbnail \(e.thumb) outside \(w)x\(h)")
                XCTAssertEqual(e.thumb.minX, 0, "cropped from the left")
                XCTAssertLessThanOrEqual(e.thumb.width, e.thumb.height * 16 / 9 + 0.001)
                for b in [e.header, e.footer].compactMap({ $0 }) { XCTAssertFalse(b.intersects(e.thumb.insetBy(dx: 0.01, dy: 0.01)), "a band under the picture at \(w)x\(h)") }
                if h < FrameLayout.bandMinHeight { XCTAssertNil(e.header); XCTAssertNil(e.footer) }
            }
        }
    }

    func testLabelStatusAndDurationLiveInTheirBandsWhenTheFrameHasThem() {
        let e = FrameLayout.elements(width: 300, height: 120, hasName: true, idLength: 3, nameLength: 8)
        XCTAssertNotNil(e.header); XCTAssertNotNil(e.footer)
        for r in [e.label, e.status].compactMap({ $0 }) { XCTAssertTrue(e.header!.contains(r)) }
        if let p = e.pill { XCTAssertTrue(e.footer!.contains(p)) }
    }

    func testTheStatusIconAndTheDiamondNeverOverlapAtAnyWidth() {
        // the height of a frame and the room above it come from the same rule as in the app: a short frame has its diamonds in a row of their own
        for panel in stride(from: 160.0, through: 700.0, by: 20) {
            for music in [true, false] {
                let sizes = TimelineLayout.sizes(panelHeight: panel, hasMusic: music)
                for w in stride(from: 8.0, through: 500.0, by: 6) {
                    let place = MarkerLayout.place(cutX: 300, prevWidth: w, nextWidth: w, sizes: sizes)
                    for right in [true, false] {
                        let c = FrameLayout.diamondClearances(width: w, height: sizes.frame, hasName: true, marker: place, onRightCut: right)
                        XCTAssertTrue(c.status, "the Status icon is under a diamond at \(w)x\(sizes.frame) (panel \(panel))")
                    }
                }
            }
        }
    }

    // MARK: identity and run state

    func testRowsAndFramesHaveStableIdsForAnimation() {
        XCTAssertEqual(StoryboardList.Entry.scene("S01").id, "scene:S01")
        let t = StoryboardList.TransitionLine(from: "S01", to: "S02", text: "Cut", glyph: "scissors", isCut: true, marks: [])
        XCTAssertEqual(StoryboardList.Entry.transition(t).id, "transition:S01")
        XCTAssertNotEqual(StoryboardList.Entry.scene("S01").id, StoryboardList.Entry.transition(t).id)
    }

    func testEveryRunStateHasItsOwnLabelAndIconWhateverTheMotion() {
        let states: [SceneRun.State] = [.waiting, .writing, .testing, .repairing, .done, .failed]
        let looks = states.map(RunAppearance.look)
        XCTAssertEqual(Set(looks.map { $0.label }).count, 6)
        XCTAssertEqual(Set(looks.map { $0.role.symbol }).count, 6)
        XCTAssertEqual(RunAppearance.look(.waiting).motion, .still)
        XCTAssertFalse(RunAppearance.look(.done).replacesStatus, "a finished scene settles into its Status icon")
        XCTAssertEqual(Set([RunAppearance.look(.writing).motion, RunAppearance.look(.testing).motion, RunAppearance.look(.repairing).motion]).count, 3)
    }

    func testTheNewStripTokensKeepTheirValuesAndReadOnTheirLane() {
        let t = DesignTokens.graphite
        XCTAssertEqual(t.strip.bg, "#131418"); XCTAssertEqual(t.strip.frame, "#2B2D36"); XCTAssertEqual(t.strip.playhead, "#FF544D")
        let lane = t.strip.lane
        XCTAssertGreaterThan(DesignTokens.contrast(DesignTokens.blend("#FFFFFF", alpha: t.strip.text, over: lane), lane), 7)
        XCTAssertGreaterThan(DesignTokens.contrast(DesignTokens.blend("#FFFFFF", alpha: t.strip.dim, over: lane), lane), 4.5)
        XCTAssertGreaterThan(DesignTokens.contrast(t.strip.wave, t.strip.ruler), 4.5)
        XCTAssertGreaterThan(DesignTokens.contrast(t.mark, t.surfaces.panel), 4.5)
        XCTAssertGreaterThan(DesignTokens.contrast(t.lockOn, t.surfaces.panel), 4.5)
    }
}
