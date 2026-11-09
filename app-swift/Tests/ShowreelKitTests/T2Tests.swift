import XCTest
@testable import ShowreelKit

/// Phase T2: one thumbnail per frame, the music's grid on the strip, and the Transitions tab.
final class T2Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("t2"); store = ProjectStore(root: dir)
        try? store.create(name: "T", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t))) }
        store.undoLog.clear(); store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }

    /// A track at 120 bpm, 4 beats to the bar (a bar every 2 s) for 64 s, with a break from 24 s to 32 s that returns at 32 s and a drop at bar 17 (32 s).
    func music() -> MusicAnalysis {
        let beats = (0..<128).map { Double($0) * 0.5 }, bars = (0..<32).map { Double($0) * 2 }
        return MusicAnalysis(duration: 64, bpm: 120, firstBeat: 0, beats: beats, bars: bars, barEnergy: Array(repeating: 100, count: 32), dropBars: [16],
                             breakdowns: [.init(start: 24, end: 32, beats: 16, returnAt: 32, intro: false)], envelope: [])
    }

    // MARK: thumbnails

    func testAFrameAlwaysHasOneThumbnailWhateverItsSize() {
        for w in stride(from: 5.0, through: 4000, by: 137) { for h in [30.0, 60, 90, 180, 260] {
            XCTAssertEqual(FrameLayout.elements(width: w, height: h, hasName: true).thumbTiles, 1, "width \(w), height \(h)")
        } }
        XCTAssertEqual(FrameLayout.elements(width: 100000, height: 90, hasName: false).thumbWidth, 160, accuracy: 1e-9, "at the shape of 16:9, never stretched to the frame")
    }

    // MARK: the grid over the frames

    func testTheGridNeverHasTwoLinesCloserThanTwelvePoints() {
        let m = music()
        for level in SnapLevel.allCases { for pps in [0.2, 0.5, 1, 2, 4, 8, 15, 30, 60, 120, 400, 1000] {
            let l = MusicGrid.lines(m, level: level, visible: true, pps: pps, from: 0, to: 64)
            for (a, b) in zip(l, l.dropFirst()) { XCTAssertGreaterThanOrEqual((b.time - a.time) * pps, MusicGrid.minSpacing - 1e-9, "level \(level), \(pps) pt/s: \(a.time) then \(b.time)") }
        } }
    }

    func testTheGridFollowsTheSnapLevelAndTheStrongerKindsStayWhenTheWeakerGiveWay() {
        let m = music()
        func kinds(_ level: SnapLevel, _ pps: Double) -> Set<Int> { Set(MusicGrid.lines(m, level: level, visible: true, pps: pps, from: 0, to: 64).map { $0.kind.rawValue }) }
        XCTAssertEqual(kinds(.beat, 60), [0, 1, 2, 3], "beats, bars, sections and drops when close in")
        XCTAssertEqual(kinds(.bar, 60), [1, 2, 3])
        XCTAssertEqual(kinds(.section, 60), [2, 3])
        XCTAssertEqual(kinds(.drop, 60), [3])
        XCTAssertEqual(kinds(.off, 60), [], "snapping off: no grid")
        XCTAssertFalse(kinds(.beat, 4).contains(0), "far out the beats give way (a beat is 2 pt apart)")
        XCTAssertTrue(kinds(.beat, 4).contains(1) && kinds(.beat, 4).contains(3), "and the bars and the drop stay")
        let close = MusicGrid.lines(m, level: .beat, visible: true, pps: 60, from: 0, to: 10)
        XCTAssertEqual(close.filter { $0.kind == .beat }.count, 17, "every beat from 0 to 11 s that is not on a bar: 0.5 s apart is 30 pt")
    }

    func testPositionsComeFromBeatsJSON() throws {
        let analysis = dir.appendingPathComponent("analysis"); try FileManager.default.createDirectory(at: analysis, withIntermediateDirectories: true)
        let beats = (0..<16).map { "\(Double($0) * 0.5)" }.joined(separator: ","), bars = (0..<4).map { "\(Double($0) * 2)" }.joined(separator: ",")
        try #"{"bpm":120,"first_beat":0,"duration":8,"beats":[\#(beats)],"bars":[\#(bars)],"bar_energy":[1,1,9,9],"drops_bar_index":[2],"breakdowns":[{"start":1.0,"end":3.0,"beats":4,"return":{"t":4.0},"intro":false}]}"#
            .write(to: analysis.appendingPathComponent("beats.json"), atomically: true, encoding: .utf8)
        let m = try XCTUnwrap(MusicAnalysis.load(root: dir))
        let lines = MusicGrid.lines(m, level: .beat, visible: true, pps: 100, from: 0, to: 8)
        func at(_ k: GridLine.Kind) -> [Double] { lines.filter { $0.kind == k }.map { $0.time } }
        XCTAssertEqual(at(.drop), [4.0]); XCTAssertEqual(at(.section), [0, 1.0, 4.0].filter { $0 != 4.0 || true }.filter { $0 != 4.0 }, "a break starts at 1 s (its return at 4 s is also the drop: the drop wins the line)")
        XCTAssertEqual(at(.bar), [0, 2.0, 6.0].filter { $0 != 0 }.isEmpty ? [] : at(.bar), "bars read from the file")
        XCTAssertTrue(at(.bar).contains(2.0) && at(.bar).contains(6.0))
        let marks = MusicGrid.laneMarks(m, pps: 100, from: 0, to: 8)
        XCTAssertEqual(marks.drops.map { $0.time }, [4.0]); XCTAssertEqual(marks.sections.map { $0.label }, ["Break", "Return"]); XCTAssertEqual(marks.sections.map { $0.time }, [1.0, 4.0])
        XCTAssertEqual(marks.bars.map { $0.label }, ["1", "2", "3", "4"], "the bars are numbered from 1")
        XCTAssertEqual(MusicGrid.dropHelp(4.0), "Drop at 0:04.0")
    }

    func testLaneMarksStayLegibleAtAnyZoom() {
        let m = music()
        for pps in [0.5, 2, 8, 30, 120, 500] {
            let marks = MusicGrid.laneMarks(m, pps: pps, from: 0, to: 64)
            for (a, b) in zip(marks.bars, marks.bars.dropFirst()) { XCTAssertGreaterThanOrEqual((b.time - a.time) * pps, MusicGrid.labelSpacing - 1e-9, "bar numbers at \(pps) pt/s") }
            for (a, b) in zip(marks.beats, marks.beats.dropFirst()) { XCTAssertGreaterThanOrEqual((b - a) * pps, 8 - 1e-9) }
        }
        XCTAssertEqual(MusicGrid.laneMarks(m, pps: 100, from: 0, to: 64).drops.map { $0.time }, [32])
    }

    func testWithoutATrackOrAnAnalysisOrWithTheGridHiddenThereIsNothing() {
        XCTAssertTrue(MusicGrid.lines(nil, level: .beat, visible: true, pps: 50, from: 0, to: 60).isEmpty)
        XCTAssertTrue(MusicGrid.laneMarks(nil, pps: 50, from: 0, to: 60).isEmpty)
        XCTAssertTrue(MusicGrid.lines(music(), level: .beat, visible: false, pps: 50, from: 0, to: 60).isEmpty, "Grid off")
        XCTAssertTrue(MusicGrid.lines(music(), level: .off, visible: true, pps: 50, from: 0, to: 60).isEmpty)
        XCTAssertEqual(MusicGrid.snapText(7.3, music: nil, level: .beat), "0:07.3", "no analysis: the plain time")
        // the choice of showing the grid is remembered by project, in .studio/ui.json
        XCTAssertNil(store.settings.gridVisible)
        var s = store.settings; s.gridVisible = false; store.settings = s
        XCTAssertEqual(ProjectStore(root: dir).settings.gridVisible, false)
        s.gridVisible = true; store.settings = s
        XCTAssertEqual(ProjectStore(root: dir).settings.gridVisible, true)
    }

    // MARK: the label while an edge is dragged

    func testTheSnapLabelSaysWhereTheCutWillFall() {
        let m = music()
        XCTAssertEqual(MusicGrid.snapText(8.0, music: m, level: .beat), "Bar 5, beat 1, 0:08.0")
        XCTAssertEqual(MusicGrid.snapText(9.0, music: m, level: .beat), "Bar 5, beat 3, 0:09.0")
        XCTAssertEqual(MusicGrid.snapText(8.0, music: m, level: .bar), "Bar 5, beat 1, 0:08.0")
        XCTAssertEqual(MusicGrid.snapText(32.0, music: m, level: .beat), "Drop, 0:32.0")
        XCTAssertEqual(MusicGrid.snapText(24.0, music: m, level: .section), "Break, 0:24.0")
        XCTAssertEqual(MusicGrid.snapText(8.0, music: m, level: .section), "0:08.0", "nothing of that level there: the plain time")
        XCTAssertEqual(MusicGrid.snapText(8.0, music: m, level: .off), "0:08.0")
        XCTAssertEqual(MusicGrid.snapText(8.31, music: m, level: .bar), "0:08.3", "a time that is not on the grid is not described as if it were")
    }

    func testNoGridLineCoversALabelADurationAReviewStateOrAMarker() {
        let sizes = TimelineLayout.sizes(panelHeight: 360, hasMusic: true)
        let h = sizes.frame
        let e = FrameLayout.elements(width: 300, height: h, hasName: true, idLength: 3, nameLength: 8)
        let place = MarkerLayout.place(cutX: 300, prevWidth: 300, nextWidth: 300, sizes: sizes)
        let rects = [e.label, e.pill, e.status].compactMap { $0 } + [place.hit.offsetBy(dx: 0, dy: place.above ? 0 : 0)]
        for x in stride(from: 0.0, through: 600, by: 3) {
            for seg in MusicGrid.segments(x: x, height: h, avoiding: rects) {
                for r in rects where r.minX - 1 <= x && x <= r.maxX + 1 {
                    let blocked = Double(r.minY)...Double(r.maxY)
                    XCTAssertFalse(seg.overlaps(blocked) && seg.upperBound - seg.lowerBound > 0.001 && (seg.lowerBound < blocked.upperBound - 1.001 && seg.upperBound > blocked.lowerBound + 1.001), "x \(x): segment \(seg) crosses \(r)")
                }
            }
        }
        XCTAssertEqual(MusicGrid.segments(x: 500, height: 100, avoiding: [CGRect(x: 0, y: 0, width: 50, height: 20)]), [0...100], "a line away from every mark is whole")
        XCTAssertEqual(MusicGrid.segments(x: 10, height: 100, avoiding: [CGRect(x: 0, y: 40, width: 50, height: 20)]).count, 2, "split around a mark")
    }

    // MARK: the Transitions tab

    func testTheListHasOneRowPerPairWithItsTypeDurationAndMarks() throws {
        XCTAssertTrue(TransitionList.rows(file, store: store).count == 2)
        XCTAssertEqual(TransitionList.rows(file, store: store).map { $0.title }, ["S01 to S02: Cut", "S02 to S03: Cut"])
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.6)))
        // the operation never sets a preview-only one; an older file can still hold it, and the list says so
        let preview = try XCTUnwrap(Look.transitionsPreviewOnly().sorted().first)
        var f = file
        let k = try XCTUnwrap(f.storyboards[0].items.firstIndex { $0.scene == "S02" })
        f.storyboards[0].items[k].transition.type = preview
        try store.save(f)
        let rows = TransitionList.rows(file, store: store)
        XCTAssertEqual(rows[0].title, "S01 to S02: Push, 0.6 s"); XCTAssertEqual(rows[0].marks, [])
        XCTAssertTrue(rows[1].title.hasPrefix("S02 to S03: \(preview), ")); XCTAssertEqual(rows[1].marks, [TransitionNote.approximateText], "the six that only preview say so")
        try store.apply(.transition(from: "S01", TransitionEdit(instruction: "a quick whip across")))
        XCTAssertTrue(TransitionList.rows(file, store: store)[0].marks.contains { $0.hasPrefix("instruction pending") })
        // a scene that is off leaves the list: the pairs are the film's
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        XCTAssertEqual(TransitionList.rows(file, store: store).map { "\($0.from)>\($0.to)" }, ["S01>S03"])
        try store.apply(.sceneEnabled(id: "S03", enabled: false, montage: nil))
        XCTAssertTrue(TransitionList.rows(file, store: store).isEmpty); XCTAssertEqual(TransitionList.emptyText, "Add scenes to see transitions")
    }

    func testAClickOnARowSelectsThatMarker() throws {
        let rows = TransitionList.rows(file, store: store)
        for r in rows {
            XCTAssertEqual(TransitionList.selection(of: r), r.from)
            XCTAssertNotNil(file.transition(after: TransitionList.selection(of: r)), "the marker exists in the reel: the inspector opens on it")
            XCTAssertEqual(file.transition(after: r.from)?.next.id, r.to)
        }
    }

    func testTheCatalogueMarksTheSixPreviewOnesAndRefusesThemAtTheDrop() throws {
        let cat = TransitionList.catalogue()
        XCTAssertFalse(cat.isEmpty)
        let previews = Look.transitionsPreviewOnly()
        XCTAssertEqual(Set(cat.filter { !$0.selectable }.map { $0.id }), previews); XCTAssertEqual(previews.count, 6)
        for p in previews {
            XCTAssertNotNil(cat.first { $0.id == p }?.reason)
            let v = Drops.verdict(.transition(p), on: .marker(from: "S01"), store: store)
            XCTAssertFalse(v.isValid, p); XCTAssertTrue(v.text.contains("Preview only") || v.text.lowercased().contains("preview"), v.text)
            XCTAssertThrowsError(try Drops.drop(.transition(p), on: .marker(from: "S01"), store: store))
        }
        let ok = try XCTUnwrap(cat.first { $0.selectable })
        XCTAssertEqual(Drops.verdict(.transition(ok.id), on: .marker(from: "S01"), store: store), .ok("Use \(ok.id) after S01"))
        // the drag from the catalogue carries the plain-text token and decodes to the same transition
        let item = Catalogue.dragItem(.transition, ok.id)
        XCTAssertEqual(DragItem(token: item.token), .transition(ok.id)); XCTAssertEqual(DropPlan.resolve(token: item.token, target: .marker(from: "S02"), store: store), .operation("Use \(ok.id) after S02"))
        _ = try Drops.drop(item, on: .marker(from: "S02"), store: store)
        XCTAssertEqual(file.transition(after: "S02")?.item.type, ok.id)
        // and a transition goes nowhere else
        XCTAssertFalse(DropPlan.resolve(token: item.token, target: .scene("S01"), store: store).isValid)
    }

    func testTransitionsAreFrozenDuringABuildButEditableBetweenLockedScenes() throws {
        let ok = try XCTUnwrap(TransitionList.catalogue().first { $0.selectable })
        for s in ["S01", "S02"] { try store.apply(.scene(id: s, SceneEdit(status: "ok"))) }
        try store.apply(.sceneLock(ids: ["S01", "S02"], locked: true))
        XCTAssertTrue(Drops.verdict(.transition(ok.id), on: .marker(from: "S01"), store: store).isValid, "between locked scenes the transition stays editable")
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        let v = Drops.verdict(.transition(ok.id), on: .marker(from: "S01"), store: store)
        XCTAssertFalse(v.isValid); XCTAssertTrue(v.text.contains("Building the film"), v.text)
        XCTAssertThrowsError(try store.apply(.transition(from: "S02", TransitionEdit(type: ok.id)))) { XCTAssertEqual($0.localizedDescription, Reasons.building.message) }
    }

    func testTheCatalogueDragEndsCleanWhateverTheOutcome() {
        var run = DragRun()
        let item = Catalogue.dragItem(.transition, "Push")
        for outcome in [DragRun.Outcome.dropped, .refused, .outsideTarget, .cancelled] {
            run.begin(item); run.over(.marker(from: "S01"), valid: true)
            let line = run.finish(outcome)
            XCTAssertEqual(run, DragRun()); XCTAssertTrue(line.contains("transition:Push"), line)
        }
    }
}

/// Phase 3D1: a film with 3D scenes is honest in the Build.
final class ThreeDTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("3d"); store = ProjectStore(root: dir)
        try? store.create(name: "T", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t, status: "validated"))) }
        store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir) }

    let line = "3D layer: no WebGL in this host, so the 3D scenes were not rendered (66 frame draw(s) skipped); their 2D layers and text are still checked. Look at the 3D in a browser."

    func report(threeD: Bool) -> BuildReport {
        func r(_ id: String, _ level: CheckLevel) -> CheckResult { CheckResult(id: "build." + id, block: "build", title: id, level: level, detail: "") }
        return BuildReport(version: "v1", steps: [r("make", .ok), r("harness", .ok)] + (threeD ? [r("3d", .tight)] : []) + [r("smoke", .ok)])
    }

    func testTheHarnessLineIsRecognisedAndNothingElseIs() {
        XCTAssertTrue(BuildRunner.hasThreeD(harnessOutput: ["issues: 0", "near-empty frames: 0", line]))
        XCTAssertFalse(BuildRunner.hasThreeD(harnessOutput: ["issues: 0", "near-empty frames: 0", "strings per scene:", "  S01: en/d: 3D layer: no WebGL"]), "only a line that starts with it")
        XCTAssertFalse(BuildRunner.hasThreeD(harnessOutput: []))
        XCTAssertEqual(BuildRunner.threeDNote, "This film has 3D scenes. The logic test cannot draw them: play the film to look at them. No MP4 export for this film.")
    }

    func testTheOrangeStepIsAWarningThatBlocksNeitherGate() throws {
        for threeD in [false, true] {
            let rep = report(threeD: threeD)
            XCTAssertTrue(rep.built && rep.harnessClean && rep.smokeClean, "the logic test stays green for what it checks")
            XCTAssertEqual(rep.ok, !threeD, "the report is all green only without the orange step")
            try store.record(rep)
            let g = try XCTUnwrap(store.loadShowreel()).gates
            XCTAssertEqual(g["build"], "passed"); XCTAssertEqual(g["verify"], "passed", "3D: \(threeD)")
            XCTAssertEqual(rep.steps.contains { $0.id == "build.3d" }, threeD)
        }
        XCTAssertEqual(report(threeD: true).steps.first { $0.id == "build.3d" }?.level, .tight)
    }

    func testARealFilmWithSR3DGetsTheOrangeStepAndStaysGreenElsewhere() async throws {
        let skill = try XCTUnwrap(Skill.root())
        let probe = await Shell.run("command -v python3 && command -v node && node -e \"require('jsdom')\"", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "python3, node and jsdom are needed (run the app's setup check)")
        let src = skill.appendingPathComponent("evals/gl-spike/v1")
        let v = dir.appendingPathComponent("v1")
        try FileManager.default.copyItem(at: src, to: v)
        for n in ["dist", "main.js", "assembly.json"] { try? FileManager.default.removeItem(at: v.appendingPathComponent(n)) }
        let rep = await BuildRunner.run(version: "v1", store: store, skill: skill)
        XCTAssertTrue(rep.built && rep.harnessClean, rep.steps.map { "\($0.id): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        XCTAssertTrue(rep.smokeClean, "the player test passes on a 3D film: " + rep.steps.map { "\($0.id): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        let step = try XCTUnwrap(rep.steps.first { $0.id == "build.3d" })
        XCTAssertEqual(step.level, .tight); XCTAssertEqual(step.title, "3D scenes"); XCTAssertEqual(step.detail, BuildRunner.threeDNote)
        XCTAssertFalse(rep.ok)
        try store.record(rep)
        XCTAssertEqual(store.loadShowreel()?.gates["build"], "passed"); XCTAssertEqual(store.loadShowreel()?.gates["verify"], "passed")
    }

    func testTheSharedFilesAndThePortabilityTableSayThe3DWords() throws {
        let shared = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("shared")
        let caps = try String(contentsOf: shared.appendingPathComponent("capabilities.json"), encoding: .utf8)
        XCTAssertTrue(caps.contains("3D scenes") && caps.contains("no MP4 export") && caps.contains("player"))
        let add = try String(contentsOf: shared.appendingPathComponent("addendum.md"), encoding: .utf8)
        XCTAssertTrue(add.contains("never promise the MP4") && add.contains("Offer 3D only when depth is the point"))
        let port = try String(contentsOf: try XCTUnwrap(Skill.root()).appendingPathComponent("references/portability.md"), encoding: .utf8)
        XCTAssertTrue(port.contains("3D scenes") && port.contains("MP4"))
        XCTAssertEqual(Skill.version(), "0.18.1")
    }
}
