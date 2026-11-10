import XCTest
@testable import ShowreelKit

/// MT1: the music lane's toolbar.
final class MT1Tests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }
    /// 120 bpm, a bar every 2 s for 64 s, a break at 24 s that returns at 32 s, a drop at 32 s.
    private func full() -> MusicAnalysis {
        MusicAnalysis(duration: 64, bpm: 120, firstBeat: 0, beats: (0..<128).map { Double($0) * 0.5 }, bars: (0..<32).map { Double($0) * 2 }, barEnergy: Array(repeating: 100, count: 32), dropBars: [16],
                      breakdowns: [.init(start: 24, end: 32, beats: 16, returnAt: 32, intro: false)], envelope: [])
    }
    private func flat() -> MusicAnalysis {
        MusicAnalysis(duration: 30, bpm: 90, firstBeat: 0, beats: (0..<45).map { Double($0) * 0.667 }, bars: (0..<11).map { Double($0) * 2.667 }, barEnergy: [], dropBars: [], breakdowns: [], envelope: [])
    }
    private func ctx(_ m: MusicAnalysis?, track: Bool = true, building: Bool = false, analysing: Bool = false) -> MusicToolbarContext {
        MusicToolbarContext(hasTrack: track, music: m, building: building, analysing: analysing)
    }

    func testEachToggleFlipsItsOwnStoredValue() {
        var s = MusicToolbarState()
        XCTAssertTrue(s.beat && s.bars && s.sections && s.drop, "everything shows by default")
        for b in [MusicToolbarButton.beat, .bars, .sections, .drop] {
            let t = s.toggled(b)
            XCTAssertFalse(t.isOn(b)); XCTAssertEqual(MusicToolbarButton.allCases.filter { $0.isToggle && s.isOn($0) && !t.isOn($0) }, [b], "only \(b) changed")
            XCTAssertEqual(t.toggled(b), s)
        }
        XCTAssertEqual(s.toggled(.analyse), s); XCTAssertFalse(s.isOn(.analyse))
        s = s.toggled(.bars)
        let back = try? JSONDecoder().decode(MusicToolbarState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s, "stored and restored")
    }

    func testNoTrackEveryButtonSaysSo() {
        for b in MusicToolbarButton.allCases {
            let u = MusicToolbar.availability(b, ctx(nil, track: false))
            XCTAssertEqual(u?.reason, "No music is attached", "\(b)"); XCTAssertFalse(u?.way.isEmpty ?? true)
        }
    }

    func testATrackNotAnalysedOnlyAllowsAnalyse() {
        for b in [MusicToolbarButton.beat, .bars, .sections, .drop] { XCTAssertEqual(MusicToolbar.availability(b, ctx(nil))?.reason, "The track is not analysed yet") }
        XCTAssertTrue(MusicToolbar.availability(.beat, ctx(nil))?.way.hasPrefix("Run Analyse") == true)
        XCTAssertNil(MusicToolbar.availability(.analyse, ctx(nil)))
    }

    func testAFullAnalysisEnablesEverything() {
        for b in MusicToolbarButton.allCases { XCTAssertNil(MusicToolbar.availability(b, ctx(full())), "\(b)") }
    }

    func testMissingSectionsAndDropsAreDisabledWithTheirReason() {
        XCTAssertEqual(MusicToolbar.availability(.sections, ctx(flat()))?.reason, "No sections were found in this track")
        XCTAssertEqual(MusicToolbar.availability(.drop, ctx(flat()))?.reason, "No drops were found in this track")
        XCTAssertNil(MusicToolbar.availability(.beat, ctx(flat()))); XCTAssertNil(MusicToolbar.availability(.bars, ctx(flat())))
    }

    func testAnalyseIsRefusedDuringABuildAndWhileRunning() {
        XCTAssertEqual(MusicToolbar.availability(.analyse, ctx(full(), building: true))?.cause, .building)
        XCTAssertEqual(MusicToolbar.availability(.analyse, ctx(full(), building: true))?.reason, "A Build is running")
        XCTAssertEqual(MusicToolbar.availability(.analyse, ctx(full(), analysing: true))?.cause, .busy)
        XCTAssertNil(MusicToolbar.availability(.beat, ctx(full(), building: true)), "the toggles are view state: a Build does not stop them")
    }

    func testTheEarlierResultStaysUntilANewOneIsWritten() {
        let old = full(), new = flat()
        XCTAssertEqual(MusicToolbar.music(after: .analysed(new), previous: old), new)
        XCTAssertEqual(MusicToolbar.music(after: .failed("boom"), previous: old), old, "kept on failure")
        XCTAssertEqual(MusicToolbar.music(after: .unavailable("no numpy"), previous: old), old)
        XCTAssertNil(MusicToolbar.music(after: .failed("boom"), previous: nil))
    }

    func testAnalyseStatusRunningThenFailedWithTheReason() {
        XCTAssertEqual(MusicToolbar.analyseStatus(analysing: true, notice: "old"), .running)
        XCTAssertEqual(MusicToolbar.analyseStatus(analysing: false, notice: "The analysis failed: x"), .failed("The analysis failed: x"))
        XCTAssertEqual(MusicToolbar.analyseStatus(analysing: false, notice: nil), .idle)
    }

    func testTheGridOfBeatAndBarsEqualsWhatTheOldMenuShowedForTheSameSettings() {
        let m = full()
        for level in SnapLevel.allCases {
            let s = MusicToolbarState(migrating: level)
            let old = MusicGrid.lines(m, level: level, visible: true, pps: 40, from: 0, to: 64)
            let new = MusicGrid.lines(m, level: MusicToolbar.snapLevel(s, music: m), visible: true, pps: 40, from: 0, to: 64, only: s.kinds)
            XCTAssertEqual(new, old, "\(level)")
            XCTAssertEqual(MusicToolbar.snapLevel(s, music: m), level, "snapping keeps the level the project had")
        }
    }

    func testSnappingFollowsTheFinestVisibleKind() {
        let m = full()
        var s = MusicToolbarState()
        XCTAssertEqual(MusicToolbar.snapLevel(s, music: m), .beat)
        s.beat = false; XCTAssertEqual(MusicToolbar.snapLevel(s, music: m), .bar)
        s.bars = false; XCTAssertEqual(MusicToolbar.snapLevel(s, music: m), .section)
        s.sections = false; XCTAssertEqual(MusicToolbar.snapLevel(s, music: m), .drop)
        s.drop = false; XCTAssertEqual(MusicToolbar.snapLevel(s, music: m), .off)
        XCTAssertEqual(MusicToolbar.snapLevel(MusicToolbarState(), music: nil), .off, "nothing to snap to without an analysis")
        XCTAssertEqual(MusicToolbar.snapLevel(MusicToolbarState(), music: flat()), .beat)
        var onlySections = MusicToolbarState(); onlySections.beat = false; onlySections.bars = false; onlySections.drop = false
        XCTAssertEqual(MusicToolbar.snapLevel(onlySections, music: flat()), .off, "a hidden or missing kind is not a snap point")
    }

    func testHiddenKindsLeaveTheLane() {
        var marks = MusicGrid.laneMarks(full(), pps: 40, from: 0, to: 64)
        XCTAssertFalse(marks.isEmpty)
        var s = MusicToolbarState(); s.bars = false; s.drop = false
        marks = MusicToolbar.filtered(marks, s)
        XCTAssertTrue(marks.bars.isEmpty && marks.drops.isEmpty); XCTAssertFalse(marks.beats.isEmpty); XCTAssertFalse(marks.sections.isEmpty)
    }

    func testSectionsCoverTheTrackWithNames() {
        let sec = MusicToolbar.sections(full())
        XCTAssertEqual(sec.first?.start, 0); XCTAssertEqual(sec.last?.end, 64)
        XCTAssertEqual(sec.map { $0.name }, ["Intro", "Break", "Return"], "the drop and the return share 32 s: one section")
        for (a, b) in zip(sec, sec.dropFirst()) { XCTAssertEqual(a.end, b.start) }
        XCTAssertEqual(MusicToolbar.sections(flat()).count, 1)
    }

    func testTrackNameTruncatedAndBPMOnlyWhenAnalysed() {
        XCTAssertNil(MusicToolbar.trackSummary(file: nil, music: nil))
        XCTAssertEqual(MusicToolbar.trackSummary(file: "assets/prepared/song.mp3", music: nil)?.name, "song.mp3")
        XCTAssertNil(MusicToolbar.trackSummary(file: "a.mp3", music: nil)?.bpm)
        XCTAssertEqual(MusicToolbar.trackSummary(file: "a.mp3", music: full())?.bpm, "120 BPM")
        let long = String(repeating: "x", count: 60) + ".mp3"
        XCTAssertLessThanOrEqual(MusicToolbar.shortName(long).count, 28); XCTAssertTrue(MusicToolbar.shortName(long).hasSuffix(".mp3"))
        XCTAssertEqual(MusicToolbar.shortName("short.mp3"), "short.mp3")
    }

    func testTheBeatMenuLeftTheFilmToolbarAndTheNewViewsUseTokens() throws {
        let strip = try source("TimelineViews.swift")
        XCTAssertFalse(strip.contains("private func snap(") || strip.contains("\"magnet\""), "the Beat menu is gone from the Film toolbar")
        XCTAssertTrue(strip.contains("MusicToolbarView()") && strip.contains("gridToggle(f)") && strip.contains("arrow.up.left.and.down.right.magnifyingglass"))
        let v = try source("MusicToolbarViews.swift")
        for bad in ["Color(red", "Color(white", "Color(hex", "NSColor(", ".white)", ".black)", "Color.white", "Color.black", "#"] { XCTAssertFalse(v.replacingOccurrences(of: "\\u{", with: "").contains(bad), bad) }
        XCTAssertTrue(v.contains("MusicToolbar.availability") && v.contains(".disabledWithReason"))
    }
}
