import XCTest
@testable import ShowreelKit

/// Phase S: the scale and layout rules of the storyboard timeline. Everything the strip draws from, tested without a screen.
final class TimelineTests: XCTestCase {
    typealias S = TimelineScale

    // MARK: time and pixels, zoom, anchor

    func testTheWholeFilmFitsTheWidthAndTimeAndPixelsConvertBothWays() {
        for (d, w) in [(30.0, 1000.0), (8.0, 600.0), (180.0, 1400.0), (3.0, 2000.0)] {
            let p = S.fit(duration: d, viewport: w)
            XCTAssertEqual(S.x(d, pps: p) + S.pad, w, accuracy: 0.001, "the end of a \(d) s film lands at the right padding of \(w) px")
            XCTAssertEqual(S.contentWidth(duration: d, pps: p, viewport: w), w, accuracy: 0.001, "no scroll when the film is fitted")
            XCTAssertEqual(S.maxScroll(duration: d, pps: p, viewport: w), 0, accuracy: 0.001)
        }
        for t in [0.0, 1.5, 12.25, 99] { XCTAssertEqual(S.time(atX: S.x(t, pps: 37), pps: 37), t, accuracy: 1e-9) }
        XCTAssertEqual(S.fit(duration: 0, viewport: 1000), 60, "no film yet: a plain default")
        XCTAssertEqual(S.fit(duration: 10, viewport: 10), 60, "no width yet: the same")
        XCTAssertEqual(S.fit(duration: 100000, viewport: 1000), S.minPPS, "never below the floor"); XCTAssertEqual(S.fit(duration: 0.1, viewport: 5000), S.maxPPS, "never above the ceiling")
    }

    func testFrameWidthIsProportionalToDurationAtEveryZoom() {
        for p in [2.0, 7.5, 40, 130, 800] {
            let a = S.x(5, pps: p) - S.x(2, pps: p), b = S.x(11, pps: p) - S.x(8, pps: p)
            XCTAssertEqual(a, b, accuracy: 1e-9, "two 3 s frames are the same width at \(p) px/s"); XCTAssertEqual(S.x(9, pps: p) - S.x(3, pps: p), 6 * p, accuracy: 1e-9)
        }
    }

    func testZoomKeepsTheAnchoredTimeWhereItIsAndStaysInBounds() {
        let dur = 120.0, vp = 1000.0
        var v = S.Viewport(pps: 20, scroll: 400)
        for (f, a) in [(1.25, 500.0), (1.25, 0.0), (0.8, 1000.0), (3.0, 250.0), (0.1, 700.0), (50.0, 640.0)] {
            let t0 = S.time(atX: a + v.scroll, pps: v.pps)
            let n = S.zoom(v, factor: f, anchorX: a, duration: dur, viewport: vp)
            XCTAssertGreaterThanOrEqual(n.pps, S.minPPS); XCTAssertLessThanOrEqual(n.pps, S.maxPPS)
            XCTAssertGreaterThanOrEqual(n.scroll, 0); XCTAssertLessThanOrEqual(n.scroll, S.maxScroll(duration: dur, pps: n.pps, viewport: vp) + 1e-9)
            let moved = S.time(atX: a + n.scroll, pps: n.pps)
            let free = n.scroll > 0 && n.scroll < S.maxScroll(duration: dur, pps: n.pps, viewport: vp)       // not pushed against an edge
            if free { XCTAssertEqual(moved, t0, accuracy: 1e-6, "the time under the anchor stays under it (factor \(f))") }
            v = n
        }
        XCTAssertEqual(S.zoom(S.Viewport(pps: S.maxPPS, scroll: 0), factor: 2, anchorX: 10, duration: 5, viewport: 800).pps, S.maxPPS, "the ceiling holds")
        XCTAssertEqual(S.zoom(S.Viewport(pps: S.minPPS, scroll: 0), factor: 0.5, anchorX: 10, duration: 5, viewport: 800).pps, S.minPPS, "so does the floor")
        XCTAssertEqual(S.stepFactor, 1.25); XCTAssertEqual(S.clamp(.nan), 60)
    }

    func testFitSelectionPutsTheSpanInViewAndWholeFilmResetsTheScroll() {
        let v = S.fitSelection(start: 10, end: 14, duration: 60, viewport: 1000)
        XCTAssertEqual(v.pps, (1000 - 2 * S.pad) / 4, accuracy: 1e-9)
        XCTAssertEqual(S.x(10, pps: v.pps) - v.scroll, S.pad, accuracy: 1e-6, "the span starts at the left padding"); XCTAssertEqual(S.x(14, pps: v.pps) - v.scroll, 1000 - S.pad, accuracy: 1e-6)
        XCTAssertEqual(S.fitSelection(start: 0, end: 0, duration: 60, viewport: 1000).pps, S.maxPPS, "a point is a short span (half a second, then the ceiling), not infinity")
        XCTAssertEqual(S.fitAll(duration: 60, viewport: 1000), S.Viewport(pps: S.fit(duration: 60, viewport: 1000), scroll: 0))
    }

    func testTheAnchorIsThePointerThenThePlayheadThenTheMiddle() {
        XCTAssertEqual(S.anchorX(pointerX: 300, playheadX: 700, viewport: 1000), 300)
        XCTAssertEqual(S.anchorX(pointerX: nil, playheadX: 700, viewport: 1000), 700)
        XCTAssertEqual(S.anchorX(pointerX: 1500, playheadX: 700, viewport: 1000), 700, "a pointer outside the strip does not count")
        XCTAssertEqual(S.anchorX(pointerX: nil, playheadX: -50, viewport: 1000), 500)
    }

    func testThePlayheadStaysInViewWhilePlaying() {
        let v = S.Viewport(pps: 100, scroll: 0)
        XCTAssertEqual(S.follow(v, playhead: 3, duration: 60, viewport: 1000), v, "in the middle: nothing moves")
        let n = S.follow(v, playhead: 12, duration: 60, viewport: 1000)
        XCTAssertEqual(S.x(12, pps: 100) - n.scroll, 250, accuracy: 1e-6, "it jumps to put the playhead a quarter in")
        XCTAssertEqual(S.follow(S.Viewport(pps: 100, scroll: 800), playhead: 1, duration: 60, viewport: 1000).scroll, 0, accuracy: 1e-6)
    }

    func testTheSliderIsLogarithmicAndRoundTrips() {
        XCTAssertEqual(S.sliderPosition(S.minPPS), 0, accuracy: 1e-9); XCTAssertEqual(S.sliderPosition(S.maxPPS), 1, accuracy: 1e-9)
        for p in [2.0, 5, 33, 120, 600, 800] { XCTAssertEqual(S.pps(sliderPosition: S.sliderPosition(p)), p, accuracy: p * 1e-9) }
        XCTAssertEqual(S.sliderPosition(40) - S.sliderPosition(20), S.sliderPosition(400) - S.sliderPosition(200), accuracy: 1e-9, "equal steps are equal factors")
        XCTAssertEqual(S.pps(sliderPosition: -3), S.minPPS); XCTAssertEqual(S.pps(sliderPosition: 9), S.maxPPS)
    }

    // MARK: sizes of the lanes

    func testTheLanesFollowThePanelHeight() {
        var lastFrame = 0.0, lastMusic = 0.0
        for h in stride(from: 200.0, through: 900, by: 10) {
            for music in [true, false] {
                let s = TimelineLayout.sizes(panelHeight: h, hasMusic: music)
                XCTAssertLessThanOrEqual(s.total, h + 0.001, "everything fits a panel of \(h)"); XCTAssertGreaterThanOrEqual(s.frame, TimelineLayout.absoluteMinFrame); XCTAssertGreaterThanOrEqual(s.music, TimelineLayout.minMusic)
                if h >= 300 { XCTAssertGreaterThanOrEqual(s.music, music ? 56 : 72, "the music lane gets room for what it holds") }
            }
            let s = TimelineLayout.sizes(panelHeight: h, hasMusic: true)
            XCTAssertGreaterThanOrEqual(s.frame, lastFrame - 0.001, "a taller panel never makes the frames lower"); XCTAssertGreaterThanOrEqual(s.music, lastMusic - 0.001)
            lastFrame = s.frame; lastMusic = s.music
        }
        XCTAssertGreaterThan(TimelineLayout.sizes(panelHeight: 700, hasMusic: true).frame, 250, "a tall panel gives tall frames")
        XCTAssertLessThanOrEqual(TimelineLayout.sizes(panelHeight: 2000, hasMusic: true).music, 170, "the music lane does not swallow the panel")
    }

    func testLowFramesGetAMarkerRowAboveThem() {
        XCTAssertEqual(TimelineLayout.sizes(panelHeight: 200, hasMusic: true).markerRow, TimelineLayout.markerRowHeight)
        XCTAssertEqual(TimelineLayout.sizes(panelHeight: 600, hasMusic: true).markerRow, 0)
        for h in stride(from: 200.0, through: 800, by: 5) {
            let s = TimelineLayout.sizes(panelHeight: h, hasMusic: true)
            XCTAssertTrue(s.markerRow > 0 || s.frame >= TimelineLayout.markerMiddleThreshold, "frames that are low always get the row (\(h))")
        }
    }

    // MARK: what a frame shows

    func testTheIDStaysAtEveryWidthAndTheNameOnlyWhenThereIsRoom() {
        let m = { (w: Double, name: Bool) in FrameLayout.mode(width: w, hasName: name) }
        XCTAssertEqual(m(10, true), .none); XCTAssertEqual(m(30, true), .shortID); XCTAssertEqual(m(60, true), .id); XCTAssertEqual(m(119, true), .id)
        XCTAssertEqual(m(120, true), .idAndName); XCTAssertEqual(m(400, false), .id, "no name, nothing to add"); XCTAssertEqual(m(22, false), .shortID)
        XCTAssertEqual(FrameLayout.fontSize, 11, "nothing under 11 pt")
        let wide = FrameLayout.elements(width: 300, height: 120, hasName: true, idLength: 3, nameLength: 12)
        XCTAssertNotNil(wide.label); XCTAssertNotNil(wide.pill); XCTAssertNotNil(wide.status); XCTAssertNotNil(wide.eye)
        let narrow = FrameLayout.elements(width: 40, height: 120, hasName: true)
        XCTAssertNil(narrow.pill, "the duration pill needs width"); XCTAssertNil(narrow.status); XCTAssertNotNil(narrow.label)
        XCTAssertNil(FrameLayout.elements(width: 300, height: 40, hasName: false).pill, "nor does it fit a low frame")
    }

    func testThumbnailsKeepTheirShapeAndRepeatAcrossALongFrame() {
        let e = FrameLayout.elements(width: 640, height: 90, hasName: false)
        XCTAssertEqual(e.thumbWidth, 160, accuracy: 1e-9, "16:9 at the lane's height"); XCTAssertEqual(e.thumbTiles, 4)
        XCTAssertEqual(FrameLayout.elements(width: 100, height: 90, hasName: false).thumbTiles, 1, "a frame narrower than one thumbnail crops it")
        XCTAssertEqual(FrameLayout.elements(width: 100000, height: 90, hasName: false).thumbTiles, 10, "capped")
        XCTAssertEqual(FrameLayout.elements(width: 100, height: 200, hasName: false).thumbWidth, 200 * 16 / 9, accuracy: 1e-9, "taller frames, bigger thumbnails")
    }

    // MARK: the transition markers never cover a label or a duration

    func testAMarkerNeverTouchesALabelOrADurationAtAnyZoomOrHeight() {
        for panel in stride(from: 200.0, through: 800, by: 15) {
            let sizes = TimelineLayout.sizes(panelHeight: panel, hasMusic: true)
            for w in [14.0, 20, 30, 44, 60, 90, 130, 260, 600] {
                for named in [false, true] {
                    let next = FrameLayout.elements(width: w, height: sizes.frame, hasName: named, idLength: 4, nameLength: 20)
                    let prev = FrameLayout.elements(width: w, height: sizes.frame, hasName: named, idLength: 4, nameLength: 20)
                    let marker = MarkerLayout.place(cutX: 500, prevWidth: w, nextWidth: w, sizes: sizes)
                    guard marker.visible else { continue }
                    // the next frame starts at the cut; the previous one ends there
                    let nextRects = [next.label, next.pill, next.status, next.eye].compactMap { $0 }.map { $0.offsetBy(dx: 500, dy: 0) }
                    let prevRects = [prev.label, prev.pill, prev.status, prev.eye].compactMap { $0 }.map { $0.offsetBy(dx: 500 - w, dy: 0) }
                    for r in nextRects + prevRects { XCTAssertFalse(marker.rect.intersects(r), "panel \(panel), width \(w): marker \(marker.rect) covers \(r)") }
                }
            }
        }
    }

    func testAMarkerSitsOnTheCutWithAGenerousHitAreaAndHidesWhenThereIsNoRoom() {
        let big = TimelineLayout.sizes(panelHeight: 600, hasMusic: true), low = TimelineLayout.sizes(panelHeight: 200, hasMusic: true)
        let a = MarkerLayout.place(cutX: 300, prevWidth: 200, nextWidth: 200, sizes: big)
        XCTAssertEqual(a.rect.midX, 300, accuracy: 1e-9); XCTAssertEqual(a.size, 26); XCTAssertEqual(MarkerLayout.place(cutX: 300, prevWidth: 200, nextWidth: 200, sizes: low).size, 22, "in its row it fits the row"); XCTAssertFalse(a.above); XCTAssertEqual(a.rect.midY, big.frame / 2, accuracy: 1e-9, "in the middle of the frames")
        XCTAssertGreaterThanOrEqual(a.hit.width, a.rect.width + 16); XCTAssertGreaterThanOrEqual(a.hit.height, a.rect.height + 16)
        let b = MarkerLayout.place(cutX: 300, prevWidth: 200, nextWidth: 200, sizes: low)
        XCTAssertTrue(b.above); XCTAssertLessThan(b.rect.maxY, 0, "above the frames, in its own row"); XCTAssertGreaterThanOrEqual(b.rect.minY, -low.markerRow)
        XCTAssertFalse(MarkerLayout.place(cutX: 300, prevWidth: 8, nextWidth: 200, sizes: big).visible, "frames too narrow to hold a diamond")
        XCTAssertEqual(MarkerLayout.place(cutX: 300, prevWidth: 18, nextWidth: 200, sizes: big).size, 16, accuracy: 1e-9, "it shrinks to fit")
    }

    // MARK: the ruler

    func testTheRulerKeepsItsLabelsApartAtEveryZoom() {
        for pps in [2.0, 3, 5, 10, 25, 60, 150, 400, 800] {
            let ticks = TimelineRuler.ticks(pps: pps, from: 0, to: 60)
            let labelled = ticks.filter { $0.label != nil && $0.kind == .time }
            XCTAssertFalse(labelled.isEmpty, "\(pps)")
            XCTAssertTrue(labelled.allSatisfy { $0.major }, "only the major ticks carry a label")
            let gaps = zip(labelled, labelled.dropFirst()).map { ($1.time - $0.time) * pps }
            XCTAssertTrue(gaps.allSatisfy { $0 >= TimelineRuler.labelSpacing - 0.01 }, "labels stay \(TimelineRuler.labelSpacing) px apart at \(pps) px/s: \(gaps.min() ?? 0)")
            XCTAssertEqual(ticks.first?.time, 0); XCTAssertTrue(ticks.contains { $0.time == 0 && $0.label != nil })
            XCTAssertTrue(ticks.allSatisfy { $0.time >= 0 })
        }
        let step = { (p: Double) in TimelineRuler.majorStep(pps: p) }
        XCTAssertGreaterThan(step(2), step(20)); XCTAssertGreaterThan(step(20), step(200)); XCTAssertGreaterThan(step(200), step(800) - 1e-9)
        XCTAssertEqual(step(64), 1); XCTAssertEqual(step(800), 0.1, "close in: tenths of a second")
    }

    func testRulerLabelsReadAsTimeAndOnlyShowDecimalsWhenCloseIn() {
        XCTAssertEqual(TimelineRuler.label(5, step: 5), "0:05"); XCTAssertEqual(TimelineRuler.label(65, step: 5), "1:05"); XCTAssertEqual(TimelineRuler.label(600, step: 60), "10:00")
        XCTAssertEqual(TimelineRuler.label(4.5, step: 0.5), "0:04.5"); XCTAssertEqual(TimelineRuler.label(4.25, step: 0.25), "0:04.2"); XCTAssertEqual(TimelineRuler.label(1.05, step: 0.05), "0:01.05")
    }

    func testTheRulerOnlyReturnsWhatIsInView() {
        let t = TimelineRuler.ticks(pps: 100, from: 30, to: 34)
        XCTAssertTrue(t.allSatisfy { $0.time >= 29 && $0.time <= 35.1 }, "\(t.map { $0.time })")
        XCTAssertTrue(TimelineRuler.ticks(pps: 100, from: 5, to: 4).isEmpty); XCTAssertTrue(TimelineRuler.ticks(pps: 0, from: 0, to: 4).isEmpty)
    }

    func testBarsAreNumberedAndThinnedAndBeatsAppearOnlyCloseIn() {
        let bars = (0..<64).map { Double($0) * 2 }, beats = (0..<256).map { Double($0 * 5) / 10 }            // 2 s bars, 0.5 s beats
        let near = TimelineRuler.ticks(pps: 100, from: 0, to: 20, bars: bars, beats: beats)
        let farTicks = TimelineRuler.ticks(pps: 6, from: 0, to: 120, bars: bars, beats: beats)
        let nearBars = near.filter { $0.kind == .bar }, farBars = farTicks.filter { $0.kind == .bar }
        XCTAssertEqual(nearBars.first?.label, "1"); XCTAssertEqual(nearBars.dropFirst().first?.label, "2", "every bar when there is room")
        XCTAssertLessThan(farBars.count, 64, "thinned when zoomed out")
        let gaps = zip(farBars, farBars.dropFirst()).map { ($1.time - $0.time) * 6 }
        XCTAssertTrue(gaps.allSatisfy { $0 >= 56 }, "numbers stay apart: \(gaps.min() ?? 0)")
        XCTAssertFalse(near.filter { $0.kind == .beat }.isEmpty, "beats close in"); XCTAssertTrue(farTicks.filter { $0.kind == .beat }.isEmpty, "none when zoomed out")
        XCTAssertTrue(TimelineRuler.ticks(pps: 100, from: 0, to: 20).allSatisfy { $0.kind == .time }, "no music, no bars")
    }

    // MARK: moving around the film

    func testTheSceneUnderTheHeadAndTheStepsBetweenScenes() throws {
        let dir = makeTempDir("tl"); defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectStore(root: dir)
        try store.create(name: "T", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three", "Four"] { try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        try store.apply(.sceneEnabled(id: "S03", enabled: false, montage: nil))           // S01 0-3, S02 3-6, S04 6-9
        let f = store.loadShowreel()!
        XCTAssertEqual(TimelineNav.scene(at: 0, in: f)?.id, "S01"); XCTAssertEqual(TimelineNav.scene(at: 2.99, in: f)?.id, "S01")
        XCTAssertEqual(TimelineNav.scene(at: 3, in: f)?.id, "S02", "a cut belongs to the scene that starts there"); XCTAssertEqual(TimelineNav.scene(at: 7, in: f)?.id, "S04")
        XCTAssertEqual(TimelineNav.scene(at: 9, in: f)?.id, "S04", "the very end is still the last scene"); XCTAssertNil(TimelineNav.scene(at: 9.5, in: f)); XCTAssertNil(TimelineNav.scene(at: -1, in: f))
        XCTAssertEqual(TimelineNav.step(from: "S01", by: 1, playhead: 0, in: f)?.id, "S02"); XCTAssertEqual(TimelineNav.step(from: "S02", by: 1, playhead: 0, in: f)?.id, "S04", "a scene that is off is skipped")
        XCTAssertEqual(TimelineNav.step(from: "S04", by: -1, playhead: 0, in: f)?.start, 3)
        XCTAssertNil(TimelineNav.step(from: "S04", by: 1, playhead: 0, in: f)); XCTAssertNil(TimelineNav.step(from: "S01", by: -1, playhead: 0, in: f))
        XCTAssertEqual(TimelineNav.step(from: nil, by: 1, playhead: 4, in: f)?.id, "S04", "with nothing selected, from the scene under the playhead")
        XCTAssertEqual(TimelineNav.step(from: nil, by: 1, playhead: 100, in: f)?.id, "S01", "past the end, forwards starts at the first")
        XCTAssertEqual(TimelineNav.span(of: "S02", transition: false, in: f)?.start, 3); XCTAssertEqual(TimelineNav.span(of: "S02", transition: false, in: f)?.end, 6)
        XCTAssertEqual(TimelineNav.span(of: "S02", transition: true, in: f)?.end, 9, "a transition: both scenes it joins"); XCTAssertNil(TimelineNav.span(of: "S03", transition: false, in: f))
        let a = TimelineNav.advance(8.9, by: 0.2, end: 9); XCTAssertTrue(a.ended); XCTAssertEqual(a.time, 9)
        XCTAssertFalse(TimelineNav.advance(1, by: 0.2, end: 9).ended); XCTAssertEqual(TimelineNav.timecode(75.25), "1:15.2"); XCTAssertEqual(TimelineNav.timecode(0), "0:00.0")
    }

    // MARK: remembered per project

    func testTheScaleAndTheScrollAreRememberedPerProject() throws {
        let dir = makeTempDir("tl-ui"); defer { try? FileManager.default.removeItem(at: dir) }
        let store = ProjectStore(root: dir)
        XCTAssertNil(store.settings.timeline, "no memory: the strip opens on the whole film")
        var s = store.settings; s.timeline = TimelineMemory(pps: 87.5, scroll: 410, fitAll: false); store.settings = s
        let t = try XCTUnwrap(ProjectStore(root: dir).settings.timeline)
        XCTAssertEqual(t, TimelineMemory(pps: 87.5, scroll: 410, fitAll: false))
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".studio"), withIntermediateDirectories: true)
        try #"{"mode": "expert", "layout": {"library": 300}}"#.write(to: dir.appendingPathComponent(".studio/ui.json"), atomically: true, encoding: .utf8)
        XCTAssertNil(store.settings.timeline); XCTAssertEqual(store.settings.layout?.library, 300, "a file from before still reads, and keeps the rest")
        XCTAssertGreaterThanOrEqual(PanelLayout.standardStrip, PanelLayout.minStrip); XCTAssertGreaterThanOrEqual(PanelLayout.minStrip, TimelineLayout.sizes(panelHeight: PanelLayout.minStrip, hasMusic: true).total - 0.001, "the smallest strip still holds every lane")
    }

    // MARK: the music lane takes drops

    func testAnAudioResourceOrFileDroppedOnTheMusicLaneBecomesTheMusic() throws {
        let dir = makeTempDir("tl-music"), inbox = makeTempDir("tl-inbox"); defer { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
        let store = ProjectStore(root: dir)
        try store.create(name: "M", conversationLanguage: "en", reelLanguages: ["en"])
        func file(_ n: String) -> URL { let u = inbox.appendingPathComponent(n); try? "x".write(to: u, atomically: true, encoding: .utf8); return u }
        XCTAssertTrue(Drops.applies(.resource("x"), to: .musicLane)); XCTAssertTrue(Drops.applies(.files([]), to: .musicLane))
        XCTAssertFalse(Drops.applies(.transition("Push"), to: .musicLane)); XCTAssertFalse(Drops.applies(.scene("S01"), to: .musicLane)); XCTAssertFalse(Drops.applies(.effect("Pop"), to: .musicLane))
        XCTAssertFalse(DropTarget.musicLane.isSlot)
        let rows = try Assets.add([file("theme.mp3"), file("Acme Logo.svg")], to: store)
        XCTAssertTrue(Drops.verdict(.resource(rows[1].id), on: .musicLane, store: store).text.contains("not music"), "a logo is not music")
        XCTAssertFalse(Drops.verdict(.resource(rows[0].id), on: .musicLane, store: store).isValid, "an audio file that nobody approved yet is refused by the track rule")
        try store.apply(.asset(id: rows[0].id, status: .approved, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(Drops.verdict(.resource(rows[0].id), on: .musicLane, store: store), .ok("Use theme.mp3 as the music"))
        try Drops.drop(.resource(rows[0].id), on: .musicLane, store: store)
        XCTAssertEqual(store.loadShowreel()?.decisions.track?.file, "assets/" + (Assets.load(store).first { $0.id == rows[0].id }?.file ?? "?"))
        try store.undo()
        XCTAssertNil(store.loadShowreel()?.decisions.track?.file, "undone")
        // a file from the Finder: added, approved (the user dropped it as the music) and attached, as one step
        let r = try Drops.drop(.files([file("beat.wav")]), on: .musicLane, store: store)
        XCTAssertEqual(r.title, "Use beat.wav as the music")
        XCTAssertEqual(Assets.load(store).first { $0.name == "beat.wav" }?.status, "approved"); XCTAssertNotNil(store.loadShowreel()?.decisions.track?.file)
        try store.undo()
        XCTAssertNil(Assets.load(store).first { $0.name == "beat.wav" }, "the added file goes with it"); XCTAssertNil(store.loadShowreel()?.decisions.track?.file)
        XCTAssertThrowsError(try Drops.drop(.files([file("shot.png")]), on: .musicLane, store: store)) { XCTAssertTrue($0.localizedDescription.contains("not music")) }
    }

    // MARK: the views draw what the kit says (a scan of their sources)

    func testTheStripWiresTheKitsRulesAndKeepsText11PointsOrMore() throws {
        let v = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        let t = try String(contentsOf: v.appendingPathComponent("TimelineViews.swift"), encoding: .utf8)
        for text in t.components(separatedBy: "\n") where text.contains("Text(") {
            XCTAssertFalse(text.contains(".caption") || text.contains(".footnote"), "text under 11 pt: \(text.trimmingCharacters(in: .whitespaces).prefix(90))")
            let re = try NSRegularExpression(pattern: #"size: (\d+)"#)
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let n = Int((text as NSString).substring(with: m.range(at: 1)))!
                XCTAssertGreaterThanOrEqual(n, 11, "text under 11 pt: \(text.trimmingCharacters(in: .whitespaces).prefix(90))")
            }
        }
        for rule in ["TimelineLayout.sizes(", "TimelineRuler.ticks(", "FrameLayout.elements(", "MarkerLayout.place(", "TimelineScale.contentWidth(", "TimelineNav.timecode("] { XCTAssertTrue(t.contains(rule), rule) }
        for key in [#"keyboardShortcut("-", modifiers: .command)"#, #"keyboardShortcut("=", modifiers: .command)"#, #"keyboardShortcut("+", modifiers: .command)"#, #"keyboardShortcut("0", modifiers: .command)"#, "MagnificationGesture()", "case 49:", "case 123:", "case 124:"] {
            XCTAssertTrue(t.contains(key), key)
        }
        for need in ["Choose music", ".dropTarget(.musicLane)", "Fit selection", "magnet", "Add scene", "StripPrimaryAction()", "backward.end.fill", "forward.end.fill"] { XCTAssertTrue(t.contains(need), need) }
        XCTAssertFalse(try String(contentsOf: v.appendingPathComponent("ProjectView.swift"), encoding: .utf8).contains("GoButton()"), "the strip carries the one primary action: no second Go in the window's toolbar")
        let m = try String(contentsOf: v.appendingPathComponent("ProjectModel.swift"), encoding: .utf8)
        XCTAssertTrue(m.contains("private(set) var fitAll = true"), "the strip opens on the whole film")
        XCTAssertFalse(m.contains("var pps"), "no second scale beside the kit's")
    }
}
