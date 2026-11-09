import XCTest
@testable import ShowreelKit

/// Phase W2: durations and cuts on the reel, transitions, the music grid and the checks that follow from them.
final class ReelTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("w2"); store = ProjectStore(root: dir)
        try? store.create(name: "R", conversationLanguage: "en", reelLanguages: ["en"])
        for (t, d) in [("One", "4"), ("Two", "4"), ("Three", "4")] { try? store.apply(.addScene(id: "", SceneEdit(duration: d, text: t))) }
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    func starts() -> [Double?] { file.timeline().map { $0.start } }
    func dur(_ id: String) -> Double? { file.scenes.first { $0.id == id }?.duration }
    func check(_ id: String) -> CheckResult? { Checks.run(area: "storyboard", store: store).first { $0.id == id } }

    /// A 120 BPM analysis: beats every half second, a bar every two, a drop at bar 5 (8 s) after a calm bar, a break from 12 s to 14 s.
    func writeAnalysis(drops: [Int] = [4], energy: [Double]? = nil, duration: Double = 24) throws {
        let beats = stride(from: 0.0, to: duration, by: 0.5).map { $0 }
        let bars = stride(from: 0.0, to: duration, by: 2.0).map { $0 }
        let be = energy ?? bars.indices.map { $0 < 4 ? 0.2 : $0 == 4 ? 0.9 : 0.8 }
        let j: [String: Any] = ["duration": duration, "bpm": 120.0, "first_beat": 0.0, "beats": beats, "bars": bars, "bar_energy": be, "drops_bar_index": drops,
                                "breakdowns": [["start": 12.0, "end": 14.0, "beats": 4, "return": ["t": 14.0, "beat": 28, "next_bar": 8, "next_bar_t": 14.0]], ["start": 0.0, "end": 2.0, "beats": 4, "intro": true]]]
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("analysis"), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: j).write(to: dir.appendingPathComponent("analysis/beats.json"))
    }

    func attachTrack() throws {
        if Assets.load(store).contains(where: { $0.id == "audio-01" }) { try store.apply(.track(asset: "audio-01")); return }
        let inbox = makeTempDir("inbox-w2"); defer { try? FileManager.default.removeItem(at: inbox) }
        let u = inbox.appendingPathComponent("theme.mp3"); try Data(count: 100).write(to: u)
        try Assets.add([u], to: store)
        _ = try? store.apply(.asset(id: "audio-01", status: .approved, note: nil, licence: nil, scenes: nil))
        try store.apply(.track(asset: "audio-01"))
    }

    // MARK: data

    func testNewFieldsRoundTripAndOldFilesMigrateUntouched() throws {
        let old = try ShowreelFile.decode(##"{"schema": 1, "name": "O", "decisions": {"track": {"file": "assets/prepared/a.mp3", "bpm": 120}}, "scenes": [{"id": "S01", "duration": 3}, {"id": "S02", "duration": 3}]}"##)
        XCTAssertNil(old.decisions.track?.firstBeat); XCTAssertNil(old.storyboards[0].snap); XCTAssertEqual(old.snapLevel(), .beat); XCTAssertTrue(old.ripple())
        XCTAssertEqual(old.storyboards[0].items[0].transition.type, "cut")
        let f = try ShowreelFile.decode(##"{"schema": 1, "name": "N", "decisions": {"track": {"file": "x.mp3", "bpm": 90.5, "firstBeat": 0.3, "manual": true, "tk": 1}}, "scenes": [{"id": "S01"}, {"id": "S02"}], "storyboards": [{"id": "main", "name": "M", "snap": "bar", "ripple": false, "mk": 2, "items": [{"scene": "S01", "enabled": true, "transition": {"type": "Push", "duration": 0.5, "params": {"dir": "left"}, "instruction": "match the card", "tx": 3}}, {"scene": "S02"}]}]}"##)
        XCTAssertEqual(f.snapLevel(), .bar); XCTAssertFalse(f.ripple())
        XCTAssertEqual(f.decisions.track?.firstBeat, 0.3); XCTAssertEqual(f.decisions.track?.manual, true)
        XCTAssertEqual(f.storyboards[0].items[0].transition.instruction, "match the card")
        let back = try ShowreelFile.decode(try f.encoded())
        XCTAssertEqual(back, f)
        XCTAssertEqual(back.decisions.track?.unknown["tk"], .number(1)); XCTAssertEqual(back.storyboards[0].unknown["mk"], .number(2)); XCTAssertEqual(back.storyboards[0].items[0].transition.unknown["tx"], .number(3))
    }

    // MARK: durations and cuts

    func testResizeRipplesByDefaultAndCanLeaveTheNextSceneWhereItIs() throws {
        XCTAssertEqual(starts(), [0, 4, 8])
        let card = try store.plan(.resize(scene: "S01", duration: 6, ripple: true))
        XCTAssertEqual(card.changes, [Change("S01 duration", "4 s", "6 s")])
        try store.apply(.resize(scene: "S01", duration: 6, ripple: true))
        XCTAssertEqual(starts(), [0, 6, 10], "the following scenes shift")
        let off = try store.plan(.resize(scene: "S01", duration: 3, ripple: false))
        XCTAssertTrue(off.changes.contains(Change("S02 start", "follows S01", "stays at 6 s")))
        try store.apply(.resize(scene: "S01", duration: 3, ripple: false))
        XCTAssertEqual(starts(), [0, 6, 10], "ripple off: the next scene stays, a gap opens")
        XCTAssertEqual(file.filmEnd, 14)
        XCTAssertThrowsError(try store.plan(.resize(scene: "S01", duration: 0.05, ripple: true)))
        XCTAssertThrowsError(try store.plan(.resize(scene: "S01", duration: 3, ripple: true)), "no change")
        XCTAssertThrowsError(try store.plan(.resize(scene: "S09", duration: 3, ripple: true)))
    }

    func testMovingACutTradesTimeBetweenTwoScenes() throws {
        let card = try store.plan(.moveCut(before: "S01", after: "S02", at: 5))
        XCTAssertEqual(card.changes, [Change("S01 duration", "4 s", "5 s"), Change("S02 duration", "4 s", "3 s")])
        try store.apply(.moveCut(before: "S01", after: "S02", at: 5))
        XCTAssertEqual(starts(), [0, 5, 8], "the third scene does not move")
        XCTAssertEqual(file.filmEnd, 12)
        XCTAssertThrowsError(try store.plan(.moveCut(before: "S01", after: "S03", at: 5)), "not consecutive")
        XCTAssertThrowsError(try store.plan(.moveCut(before: "S01", after: "S02", at: 0.05)), "a scene lasts at least 0.1 s")
        XCTAssertThrowsError(try store.plan(.moveCut(before: "S01", after: "S02", at: 8)))
    }

    func testReelChangesTakeTheGoBack() throws {
        for s in file.scenes { try store.apply(.scene(id: s.id, SceneEdit(status: "ok"))) }
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true))
        let card = try store.plan(.resize(scene: "S02", duration: 5, ripple: true))
        XCTAssertTrue(card.changes.contains(Change("Go", "given", "to be given again")))
        XCTAssertTrue(card.changes.contains(Change("State", "Validated", "WIP")))
        try store.apply(.resize(scene: "S02", duration: 5, ripple: true))
        XCTAssertEqual(file.gates["review"], "open")
        try store.apply(.scene(id: "S02", SceneEdit(status: "ok"))); try store.apply(.gate("review", passed: true))
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push")))
        XCTAssertEqual(file.gates["review"], "open", "a transition changes the film")
    }

    // MARK: transitions

    func testTransitionsBelongToThePairAndDefaultToACut() throws {
        XCTAssertTrue(file.storyboards[0].items.allSatisfy { $0.transition.isCut })
        let card = try store.plan(.transition(from: "S01", TransitionEdit(type: "push")))
        XCTAssertEqual(card.title, "Set the transition from S01 to S02")
        XCTAssertEqual(card.changes, [Change("S01 \u{2192} S02 transition", "Cut on beat", "Push 1.2 s")], "the library's duration, case does not matter")
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5, params: "dir=left", instruction: "the card becomes the logo")))
        let t = file.storyboards[0].items[0].transition
        XCTAssertEqual(t.type, "Push"); XCTAssertEqual(t.duration, 0.5); XCTAssertEqual(t.params, .object(["dir": .string("left")])); XCTAssertEqual(t.instruction, "the card becomes the logo")
        XCTAssertEqual(file.transition(after: "S01")?.next.id, "S02")
        // the field lives on the outgoing scene's item: switching S02 off pairs S01 with S03
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        XCTAssertEqual(file.transition(after: "S01")?.next.id, "S03"); XCTAssertEqual(file.transition(after: "S01")?.item.type, "Push")
        try store.apply(.sceneEnabled(id: "S02", enabled: true, montage: nil))
        // a longer one is capped by the shorter scene
        try store.apply(.resize(scene: "S02", duration: 1, ripple: true))
        try store.apply(.transition(from: "S02", TransitionEdit(type: "Cross dissolve")))
        XCTAssertEqual(file.storyboards[0].items[1].transition.duration, 0.5, "half of the shorter scene")
        // back to a cut
        XCTAssertEqual(try store.plan(.transition(from: "S01", nil)).title, "Cut from S01 to S02")
        try store.apply(.transition(from: "S01", nil))
        XCTAssertTrue(file.storyboards[0].items[0].transition.isCut)
        try store.apply(.transition(from: "S02", TransitionEdit(type: "cut")))
        XCTAssertTrue(file.storyboards[0].items[1].transition.isCut)
    }

    func testTransitionRefusals() throws {
        XCTAssertThrowsError(try store.plan(.transition(from: "S03", TransitionEdit(type: "Push"))), "the last scene has no successor")
        XCTAssertThrowsError(try store.plan(.transition(from: "S01", TransitionEdit(type: "Pop"))), "an effect that is not a transition")
        XCTAssertThrowsError(try store.plan(.transition(from: "S01", TransitionEdit(type: "Warp 9"))))
        XCTAssertThrowsError(try store.plan(.transition(from: "S01", TransitionEdit(duration: 0.5))), "a cut has no duration")
        XCTAssertThrowsError(try store.plan(.transition(from: "S01", TransitionEdit(params: "a=1"))))
        XCTAssertThrowsError(try store.plan(.transition(from: "S01", nil)), "already a cut")
        XCTAssertThrowsError(try store.plan(.transition(from: "S09", TransitionEdit(type: "Push"))))
        try store.apply(.sceneEnabled(id: "S03", enabled: false, montage: nil))
        XCTAssertThrowsError(try store.plan(.transition(from: "S02", TransitionEdit(type: "Push"))), "S02 is now the last scene on")
        XCTAssertGreaterThanOrEqual(Look.transitions().count, 40)
        XCTAssertTrue(Look.transitions().contains { $0.name == "Cut on beat" })
    }

    // MARK: music, grid, analysis

    func testTheTrackMustBeAnApprovedAudioFile() throws {
        let inbox = makeTempDir("inbox-w2b"); defer { try? FileManager.default.removeItem(at: inbox) }
        let u = inbox.appendingPathComponent("theme.mp3"); try Data(count: 100).write(to: u)
        let l = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: l, atomically: true, encoding: .utf8)
        try Assets.add([u, l], to: store)
        _ = try store.apply(.asset(id: "audio-01", status: .proposed, note: nil, licence: nil, scenes: nil))
        XCTAssertThrowsError(try store.plan(.track(asset: "audio-01")), "proposed, not approved")
        XCTAssertThrowsError(try store.plan(.track(asset: "logo-01")), "not audio")
        XCTAssertThrowsError(try store.plan(.track(asset: "audio-09")))
        XCTAssertThrowsError(try store.plan(.track(asset: nil)), "there is none to remove")
        _ = try? store.apply(.asset(id: "audio-01", status: .approved, note: nil, licence: nil, scenes: nil))
        let card = try store.plan(.track(asset: "audio-01"))
        XCTAssertEqual(card.changes, [Change("Music", "(none)", "theme.mp3")])
        try store.apply(.track(asset: "audio-01"))
        XCTAssertEqual(file.decisions.track?.file, "assets/prepared/audio-01-theme.mp3")
        XCTAssertThrowsError(try store.plan(.track(asset: "audio-01")), "already the music")
        try store.apply(.track(asset: ""))
        XCTAssertNil(file.decisions.track)
    }

    func testGridCorrectionIsMarkedManual() throws {
        XCTAssertThrowsError(try store.plan(.grid(bpm: 120, firstBeat: nil)), "attach the music first")
        try attachTrack()
        let card = try store.plan(.grid(bpm: 128, firstBeat: 0.35))
        XCTAssertEqual(card.changes.map { $0.label }, ["Tempo", "First beat"])
        try store.apply(.grid(bpm: 128, firstBeat: 0.35))
        let t = try XCTUnwrap(file.decisions.track)
        XCTAssertEqual(t.bpm, 128); XCTAssertEqual(t.firstBeat, 0.35); XCTAssertEqual(t.manual, true)
        XCTAssertThrowsError(try store.plan(.grid(bpm: 500, firstBeat: nil))); XCTAssertThrowsError(try store.plan(.grid(bpm: nil, firstBeat: -1)))
        XCTAssertThrowsError(try store.plan(.grid(bpm: 128, firstBeat: nil)), "no change")
        // a new track resets what was corrected
        try store.apply(.track(asset: ""))
        try attachTrack()
        XCTAssertNil(file.decisions.track?.manual)
    }

    func testAnalysisGridSnapAndMarkers() throws {
        try writeAnalysis()
        let a = try XCTUnwrap(MusicAnalysis.load(root: dir))
        XCTAssertEqual(a.bpm, 120); XCTAssertEqual(a.bars.count, 12); XCTAssertEqual(a.dropTimes, [8])
        XCTAssertEqual(a.strongestDrop, 8)
        XCTAssertEqual(a.breaks.map { $0.start }, [12], "the intro is not a break to mark")
        XCTAssertEqual(a.returns, [14])
        XCTAssertEqual(a.sections, [0, 8, 12, 14])
        XCTAssertEqual(a.snap(3.9, level: .beat), 4); XCTAssertEqual(a.snap(2.9, level: .bar), 2); XCTAssertEqual(a.snap(9.7, level: .section), 8)
        XCTAssertEqual(a.snap(13.2, level: .drop), 14); XCTAssertEqual(a.snap(3.9, level: .off), 3.9)
        XCTAssertEqual(a.snap(3.7, level: .beat, within: 0.1), 3.7, "nothing near enough")
        XCTAssertEqual(a.gridKind(4.02), "bar"); XCTAssertEqual(a.gridKind(4.5), "beat"); XCTAssertNil(a.gridKind(4.25))
        XCTAssertEqual(a.barIndex(at: 8.3), 4)
        XCTAssertNil(MusicAnalysis.load(root: makeTempDir("none")))
        try store.apply(.gridSettings(snap: "bar", ripple: false))
        XCTAssertEqual(file.snapLevel(), .bar); XCTAssertFalse(file.ripple())
        XCTAssertThrowsError(try store.plan(.gridSettings(snap: "never", ripple: nil)))
        XCTAssertThrowsError(try store.plan(.gridSettings(snap: "bar", ripple: false)), "no change")
    }

    // MARK: checks of the reel

    func testStartsOnTheMusic() throws {
        XCTAssertEqual(check("reel.music")?.level, .pending, "no music yet")
        try attachTrack()
        XCTAssertEqual(check("reel.music")?.level, .pending, "no analysis yet")
        try writeAnalysis()
        XCTAssertEqual(check("reel.starts")?.level, .ok, "starts at 4 and 8")
        try store.apply(.resize(scene: "S01", duration: 4.3, ripple: true))
        XCTAssertEqual(check("reel.starts")?.level, .tight); XCTAssertTrue(check("reel.starts")?.detail.contains("S02 starts at 4.3 s") == true)
        try store.apply(.resize(scene: "S01", duration: 4.5, ripple: true))
        XCTAssertEqual(check("reel.starts")?.level, .ok, "S02 at 4.5 and S03 at 8.5 are both on a beat")
    }

    func testStrongestMomentOnTheStrongestDropAndACalmBarBefore() throws {
        try attachTrack(); try writeAnalysis()
        XCTAssertEqual(check("reel.drop")?.level, .ok, "S03 starts at 8 s, on the strongest drop")
        XCTAssertEqual(check("reel.calm")?.level, .ok)
        try store.apply(.scene(id: "S02", SceneEdit(feeling: "huge, 5/5")))
        XCTAssertEqual(check("reel.drop")?.level, .tight, "the most intense scene is S02, not the one on the drop")
        try store.apply(.moveScene(id: "S02", after: "S03", montage: nil))
        XCTAssertEqual(check("reel.drop")?.level, .ok, "S02 now starts at 8, on the drop")
    }

    func testDropCheckWithoutDropOrWithBusyBarBefore() throws {
        try attachTrack(); try writeAnalysis(drops: [], energy: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5])
        XCTAssertEqual(check("reel.drop")?.level, .tight, "no drop, so the return after the break (14 s) counts: no scene starts there")
        XCTAssertTrue(check("reel.drop")?.detail.contains("14 s") == true)
        try writeAnalysis(energy: [0.8, 0.8, 0.8, 0.8, 0.85, 0.9, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8])
        XCTAssertEqual(check("reel.calm")?.level, .tight, "the bar before the drop is as loud as the drop")
    }

    func testFilmAndMusicLength() throws {
        try attachTrack(); try writeAnalysis(duration: 24)
        XCTAssertEqual(check("reel.length")?.level, .tight, "12 s of film for 24 s of music")
        try store.apply(.resize(scene: "S03", duration: 15, ripple: true))
        XCTAssertEqual(check("reel.length")?.level, .ok, "ends at 23 s of 24")
        try store.apply(.resize(scene: "S03", duration: 20, ripple: true))
        XCTAssertEqual(check("reel.length")?.level, .fail, "past the end of the music")
    }

    func testTransitionChecks() throws {
        XCTAssertNil(check("reel.transition-length"), "only cuts: nothing to say")
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5)))
        XCTAssertEqual(check("reel.transition-length")?.level, .ok)
        XCTAssertEqual(check("reel.transition-text")?.level, .tight, "the words of both scenes are on screen all the time, without in/out times")
        // words with their own times, outside the transition: fine
        var f = file
        f.scenes[0].content[0].unknown["in"] = .number(0); f.scenes[0].content[0].unknown["out"] = .number(3)
        f.scenes[1].content[0].unknown["in"] = .number(1); f.scenes[1].content[0].unknown["out"] = .number(4)
        try store.save(f)
        XCTAssertEqual(check("reel.transition-text")?.level, .ok, "S01's words leave at 3 s, S02's come in at 1 s: the 0.5 s of the transition is clear")
        try store.apply(.transition(from: "S01", TransitionEdit(duration: 5)))
        XCTAssertEqual(check("reel.transition-length")?.level, .fail, "longer than a scene")
        XCTAssertTrue(check("reel.transition-length")?.detail.contains("Push lasts 5 s") == true)
    }

    func testFlashesPerSecond() throws {
        XCTAssertEqual(check("reel.flashes")?.level, .ok)
        for id in ["S01", "S02", "S03"] { try store.apply(.resize(scene: id, duration: 0.4, ripple: true)) }
        try store.apply(.addScene(id: "", SceneEdit(duration: "0.4", text: "four")))
        XCTAssertEqual(check("reel.flashes")?.level, .fail, "three scene changes within one second")
        XCTAssertTrue(check("reel.flashes")?.detail.contains("under 3 per second") == true)
    }

    // MARK: the build message and the tools

    func testBuildMessageMentionsTransitionsAndTheGrid() throws {
        try attachTrack(); try writeAnalysis()
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5, instruction: "match cut on the card")))
        let p = BuildRunner.prompt(version: "v1", store: store)
        XCTAssertTrue(p.contains("S01 -> S02: Push 0.5 s \u{201C}match cut on the card\u{201D}"), p)
        XCTAssertTrue(p.contains("overlaps the end of the outgoing scene") && p.contains("length does not change"))
        XCTAssertTrue(p.contains("Music grid, constant tempo: 120 BPM, first beat 0 s, 12 bars"))
        XCTAssertTrue(p.contains("Strongest drop at 8 s") && p.contains("S02 4 s (bar)") && p.contains("S03 8 s (bar)"))
        XCTAssertTrue(p.contains("Breaks (bass out): 12-14 s"))
    }

    func testTools() async throws {
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let a = await tools.run("set_scene_duration", ["scene": "S01", "duration": 5]).text
        XCTAssertTrue(a.hasPrefix("accepted and applied"), a); XCTAssertEqual(dur("S01"), 5)
        let b = await tools.run("set_transition", ["from": "S01", "type": "Iris", "instruction": "the lens becomes the iris"]).text
        XCTAssertTrue(b.hasPrefix("accepted and applied"), b)
        let c = await tools.run("set_transition", ["from": "S03", "type": "Iris"]).text
        XCTAssertTrue(c.hasPrefix("refused"), c)
        try attachTrack(); try writeAnalysis()
        let d = await tools.run("set_grid", ["bpm": 126, "first_beat": 0.2]).text
        XCTAssertTrue(d.hasPrefix("accepted and applied"), d)
        let e = await tools.run("set_track", ["asset": ""]).text
        XCTAssertTrue(e.hasPrefix("accepted and applied"), e)
        let names = Tools.definitions.compactMap { $0["name"] as? String }
        XCTAssertTrue(["set_scene_duration", "set_transition", "set_track", "set_grid"].allSatisfy { names.contains($0) })
        try attachTrack()
        let state = await tools.run("get_state", [:]).text
        XCTAssertTrue(state.contains("strongestDrop"), "the copilot reads the grid")
    }

    // MARK: waveform and the analysis script

    func writeWav(_ url: URL, rate: Int = 8000, seconds: Double, sample: (Int) -> Int16) throws {
        let n = Int(Double(rate) * seconds)
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + n * 2)); d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(UInt32(n * 2))
        for i in 0..<n { var s = sample(i).littleEndian; d.append(Data(bytes: &s, count: 2)) }
        try d.write(to: url)
    }

    func testWaveformPeaks() throws {
        let u = dir.appendingPathComponent("w.wav")
        try writeWav(u, seconds: 4) { i in i < 16000 ? 0 : Int16(20000 * sin(Double(i) * 0.3)) }
        let p = try XCTUnwrap(Audio.peaks(u, buckets: 4))
        XCTAssertEqual(p.count, 4)
        XCTAssertLessThan(p[0], 0.05); XCTAssertLessThan(p[1], 0.05); XCTAssertGreaterThan(p[2], 0.9); XCTAssertGreaterThan(p[3], 0.9)
        XCTAssertNil(Audio.peaks(dir.appendingPathComponent("missing.wav"), buckets: 4))
    }

    func testTheAnalysisRunsFromTheAppAndTakesTheUsersCorrection() async throws {
        let probe = await Shell.run("command -v ffmpeg && python3 -c 'import numpy'", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "ffmpeg and numpy are needed (run the app's setup check)")
        let skill = try XCTUnwrap(Skill.root())
        // a kick (80 Hz burst) every half second for 16 s: 120 BPM
        let u = dir.appendingPathComponent("assets/prepared"); try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        try writeWav(u.appendingPathComponent("audio-01-kick.wav"), rate: 22050, seconds: 16) { i in
            let t = Double(i) / 22050, ph = t.truncatingRemainder(dividingBy: 0.5)
            return Int16(24000 * exp(-ph * 14) * sin(2 * .pi * 80 * ph))
        }
        var f = file; f.decisions.track = .init(file: "assets/prepared/audio-01-kick.wav"); try store.save(f)
        guard case .analysed(let a) = await Audio.analyse(store: store, skill: skill, bpm: 120, firstBeat: 0.25) else { return XCTFail("no analysis") }
        XCTAssertEqual(a.bpm, 120, accuracy: 0.5); XCTAssertEqual(a.firstBeat, 0.25, accuracy: 0.02)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("analysis/env.json").path), "outputs stay in the project")
        XCTAssertFalse(a.envelope.isEmpty)
        try store.recordAnalysis(a)
        XCTAssertEqual(file.decisions.track?.bpm, 120)
        // without a track
        try store.apply(.track(asset: ""))
        guard case .unavailable = await Audio.analyse(store: store, skill: skill) else { return XCTFail("expected unavailable") }
    }
}
