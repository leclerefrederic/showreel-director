import XCTest
@testable import ShowreelKit

/// A model that answers each request for a scene file with `reply(prompt)` and keeps what it was asked.
final class SceneWriterModel: MessagesTransport, @unchecked Sendable {
    var reply: (String) -> String
    private(set) var prompts: [String] = []
    init(_ reply: @escaping (String) -> String) { self.reply = reply }
    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]], onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        let p = (messages.last?["content"] as? String) ?? ""
        prompts.append(p)
        return ([["type": "text", "text": reply(p)]], "end_turn")
    }
}

/// Scene files: the assembler, the generation of some scenes only, the fingerprints and the states computed from them.
final class SceneModuleTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    override func setUp() {
        dir = makeTempDir("v1mods"); store = ProjectStore(root: dir)
        try? store.create(name: "M", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "validated"))) }
        try? "{\"title\": \"M\", \"main\": \"main.js\", \"duration\": 9, \"fonts\": [], \"tokens\": {}, \"weight_budget_mb\": 5}".write(to: {
            try? FileManager.default.createDirectory(at: dir.appendingPathComponent("v1"), withIntermediateDirectories: true); return dir.appendingPathComponent("v1/project.json") }(), atomically: true, encoding: .utf8)
        _ = try? Film.write(version: v, store: store)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var skill: URL { Skill.root()! }
    var file: ShowreelFile { store.loadShowreel()! }
    func bytes(_ rel: String) -> Data? { try? Data(contentsOf: dir.appendingPathComponent(rel)) }
    func module(_ id: String, _ word: String) -> String { "const { clamp } = SR;\nreturn function render(g, lt, c) { g.fillStyle = '#222'; g.fillRect(0, 0, c.SW, c.SH); g.fillStyle = '#fff'; g.fillText('\(word)', 40, 40 + clamp(lt, 0, 1)); };\n" }
    /// The model writes a distinct body per scene, named after what it was asked for.
    func fake(_ word: String = "v1") -> SceneWriterModel {
        SceneWriterModel { p in
            let id = p.range(of: #"scenes/(S\d+)\.js"#, options: .regularExpression).map { String(p[$0].dropFirst(7).dropLast(3)) } ?? "S00"
            return "Here is the file.\n```js\n" + self.module(id, "\(id)-\(word)") + "```\nDone."
        }
    }
    func assemble() async throws -> (out: String, main: String, json: [String: Any]) {
        let r = await Shell.run("python3 '\(skill.path)/scripts/assemble.py' '\(dir.path)/\(v)'", in: dir, timeout: 60)
        let res = try XCTUnwrap(r); XCTAssertEqual(res.status, 0, res.err)
        let main = try String(contentsOf: dir.appendingPathComponent("\(v)/main.js"), encoding: .utf8)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("\(v)/assembly.json"))) as? [String: Any])
        return (res.out, main, json)
    }
    func zone(_ id: String, in main: String) -> String {
        guard let a = main.range(of: "  // >>> scene \(id) "), let b = main.range(of: "  // <<< scene \(id)\n") else { return "" }
        return String(main[a.lowerBound..<b.upperBound])
    }

    // MARK: generating some scenes only

    func testGeneratingTwoScenesWritesOnlyThoseFilesAndTheAssemblerFlagsTheThird() async throws {
        let m = fake()
        let done = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(done, ["S01", "S02"]); XCTAssertEqual(m.prompts.count, 2, "one call per scene")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("v1/scenes").path).sorted(), ["S01.js", "S02.js"])
        XCTAssertTrue(try XCTUnwrap(bytes("v1/scenes/S01.js")).starts(with: Data("const { clamp }".utf8)), "the file is the code block of the answer, without the chat around it")
        let a = try await assemble()
        XCTAssertEqual(a.json["ungenerated"] as? [String], ["S03"], "the film still assembles; the scene with no file is listed for machines")
        XCTAssertTrue(a.main.contains("placeholder(\"S03\"") && a.out.contains("not generated"))
        // one scene generated again: its file changes, the others do not, and main.js changes only in its zone
        let s1 = bytes("v1/scenes/S01.js"), film = bytes("v1/film.json"), reel = bytes("v1/reel.js")
        let before = a.main
        _ = try await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: fake("again"))
        XCTAssertEqual(bytes("v1/scenes/S01.js"), s1, "the other scene file is identical byte for byte")
        XCTAssertEqual(bytes("v1/film.json"), film); XCTAssertEqual(bytes("v1/reel.js"), reel)
        XCTAssertNil(bytes("v1/scenes/S03.js"), "a scene that was not asked for gets no file")
        let b = try await assemble()
        XCTAssertNotEqual(zone("S02", in: before), zone("S02", in: b.main)); XCTAssertTrue(zone("S02", in: b.main).contains("S02-again"))
        XCTAssertEqual(zone("S01", in: before), zone("S01", in: b.main))
        XCTAssertEqual(before.replacingOccurrences(of: zone("S02", in: before), with: ""), b.main.replacingOccurrences(of: zone("S02", in: b.main), with: ""), "main.js differs only inside the zone of S02")
        let again = try await assemble()
        XCTAssertEqual(again.main, b.main, "the same inputs give the same bytes")
        XCTAssertEqual(store.journal.entries().filter { $0.op == "generate" }.count, 2, "each generation is in the journal")
    }

    func testALockedSceneIsRefusedWithTheReasonAndNothingIsAskedOrWritten() async throws {
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        let m = fake()
        do { _ = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: skill, transport: m); XCTFail("a locked scene is refused") }
        catch { XCTAssertEqual(error.localizedDescription, SceneLock.reason("S02")) }
        XCTAssertTrue(m.prompts.isEmpty, "the model was not called, not even for the scene that was fine")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1/scenes").path), "nothing was written")
        // unlocked: it goes through
        try store.apply(.sceneLock(ids: ["S02"], locked: false))
        _ = try await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: m)
        XCTAssertNotNil(bytes("v1/scenes/S02.js"))
    }

    func testNothingCanBeLockedWhileTheModelWorksAndTheProjectIsEditableAgainAfter() async throws {
        let me = self
        var duringLock = "", duringState: ProjectActivity.Snapshot?
        let m = SceneWriterModel { _ in
            do { try me.store.apply(.sceneLock(ids: ["S01"], locked: true)) } catch { duringLock = error.localizedDescription }
            duringState = me.store.activity.snapshot
            return "```js\nreturn function () {};\n```"
        }
        _ = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(duringLock, Reasons.building.message, "the freeze of a build applies to a generation")
        XCTAssertEqual(duringState?.build?.phase, .generating); XCTAssertEqual(duringState?.build?.total, 2)
        XCTAssertNil(store.activity.snapshot.build, "the end lifts it")
        XCTAssertNoThrow(try store.apply(.sceneLock(ids: ["S01"], locked: true)))
        // an error and a cancellation lift it too
        let bad = SceneWriterModel { _ in "no code" }
        _ = try? await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: bad)
        XCTAssertNil(store.activity.snapshot.build)
        let task = Task { try await SceneGeneration.generate(["S02", "S03"], version: v, store: store, skill: skill, transport: self.fake()) }
        task.cancel()
        _ = try? await task.value
        XCTAssertNil(store.activity.snapshot.build)
        XCTAssertNil(bytes("v1/scenes/S03.js"), "a cancelled generation writes nothing for the scenes it did not reach")
    }

    func testOtherRefusalsAndAModelThatReturnsNoCode() async throws {
        try store.apply(.sceneEnabled(id: "S03", enabled: false, montage: nil))
        for (ids, needle) in [(["S09"], "unknown scene"), (["S03"], "switched off"), ([], "no scene"), (["S01", "S01"], "twice")] {
            do { _ = try await SceneGeneration.generate(ids, version: v, store: store, skill: skill, transport: fake()); XCTFail("refused \(ids)") } catch { XCTAssertTrue(error.localizedDescription.contains(needle), error.localizedDescription) }
        }
        do { _ = try await SceneGeneration.generate(["S01"], version: "v7", store: store, skill: skill, transport: fake()); XCTFail() } catch { XCTAssertTrue(error.localizedDescription.contains("does not exist")) }
        let none = SceneWriterModel { _ in "I cannot do that." }
        do { _ = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: skill, transport: none); XCTFail() } catch { XCTAssertTrue(error.localizedDescription.contains("nothing was written")) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1/scenes").path))
    }

    func testAVersionInTheOlderFormatIsNotGeneratedSceneByScene() async throws {
        try "// hand written\n".write(to: dir.appendingPathComponent("v1/main.js"), atomically: true, encoding: .utf8)
        do { _ = try await SceneGeneration.generate(["S01"], version: v, store: store, skill: skill, transport: fake()); XCTFail() } catch { XCTAssertTrue(error.localizedDescription.contains("older format")) }
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("v1/main.js"), encoding: .utf8), "// hand written\n", "main.js is untouched")
        XCTAssertFalse(SceneModules.usesSceneFiles(version: v, store: store))
    }

    func testThePromptHasTheContractTheSceneAndItsNeighbours() async throws {
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5)))
        let m = fake()
        _ = try await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: m)
        let p = try XCTUnwrap(m.prompts.first)
        for needle in ["v1/scenes/S02.js", "## Scene files", "return function render(g, lt, c)", "Previous scene: S01", "next scene: S03", "Push", "3 s long", "Two", "#101820"] { XCTAssertTrue(p.contains(needle), needle) }
    }

    // MARK: Clap's tool

    func testClapGeneratesScenesThroughACardAndNeverALockedOne() async throws {
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: skill, ui: ui)
        let none = await tools.run("generate_scenes", ["scenes": ["S01"]]).text
        XCTAssertTrue(none.hasPrefix("not available"), none)
        tools.sceneTransport = fake()
        try store.apply(.sceneLock(ids: ["S03"], locked: true))
        let locked = await tools.run("generate_scenes", ["scenes": ["S03"]]).text
        XCTAssertTrue(locked.hasPrefix("refused:") && locked.contains(SceneLock.reason("S03")), locked); XCTAssertTrue(ui.cards.isEmpty, "no card for what is refused")
        ui.accept = false
        let no = await tools.run("generate_scenes", ["scenes": ["S01", "S02"]]).text
        XCTAssertTrue(no.hasPrefix("refused by the user"), no); XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1/scenes").path))
        XCTAssertEqual(ui.cards.last?.title, "Generate 2 scenes in v1: S01, S02"); XCTAssertTrue(ui.cards.last?.changes.contains { $0.label == "v1/scenes/S01.js" && $0.before == "not generated" } == true)
        ui.accept = true
        let yes = await tools.run("generate_scenes", ["scenes": ["S01", "S02"]]).text
        XCTAssertTrue(yes.hasPrefix("generated S01, S02 in v1"), yes); XCTAssertNotNil(bytes("v1/scenes/S02.js")); XCTAssertNil(bytes("v1/scenes/S03.js"))
        XCTAssertTrue(Tools.definitions.contains { ($0["name"] as? String) == "generate_scenes" })
        XCTAssertEqual(store.journal.entries().last { $0.op == "generate" }?.author, "clap")
    }

    // MARK: fingerprints and states

    func testTheStateOfAScenePerFingerprint() async throws {
        func st(_ id: String) -> SceneModules.State { SceneModules.statuses(version: v, store: store)[id]!.state }
        XCTAssertEqual(SceneModules.statuses(version: v, store: store).mapValues { $0.state }, ["S01": .notGenerated, "S02": .notGenerated, "S03": .notGenerated])
        _ = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: skill, transport: fake())
        XCTAssertEqual([st("S01"), st("S02"), st("S03")], [.upToDate, .upToDate, .notGenerated])
        let rec = try XCTUnwrap(SceneModules.record(version: v, scene: "S01", store: store)); XCTAssertEqual(rec.module.count, 64); XCTAssertEqual(rec.inputs.count, 32)
        // what does NOT make a scene stale: the order of the montage, a transition, a state change, the length of another scene
        try store.apply(.moveScene(id: "S02", after: "start", montage: nil))
        try store.apply(.transition(from: "S02", TransitionEdit(type: "Push", duration: 0.5)))
        try store.apply(.scene(id: "S01", SceneEdit(status: "wip")))
        XCTAssertEqual([st("S01"), st("S02")], [.upToDate, .upToDate], "the montage order, a transition and a review state are not inputs of a module")
        // what does: content, length, control level, the effective look
        try store.apply(.scene(id: "S01", SceneEdit(text: "One, changed")))
        XCTAssertEqual([st("S01"), st("S02")], [.stale, .upToDate], "changing the content makes that scene stale and no other")
        try store.apply(.scene(id: "S01", SceneEdit(text: "One")))
        XCTAssertEqual(st("S01"), .upToDate, "put back, it is current again")
        try store.apply(.resize(scene: "S02", duration: 4))
        XCTAssertEqual([st("S01"), st("S02")], [.upToDate, .stale], "the scene's own length")
        try store.apply(.resize(scene: "S02", duration: 3))
        XCTAssertEqual(st("S02"), .upToDate)
        try store.apply(.decisions([DecisionChange(.palette, "#000001, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        XCTAssertEqual([st("S01"), st("S02"), st("S03")], [.stale, .stale, .notGenerated], "a global look change makes every generated scene stale")
        _ = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: skill, transport: fake())
        try store.apply(.sceneLook(id: "S01", [DecisionChange(.palette, "#000002, #FFFFFF, #F2AA4C, #4CC2F2")]))
        XCTAssertEqual([st("S01"), st("S02")], [.stale, .upToDate], "a scene's own look is its input")
        _ = try await SceneGeneration.generate(["S01"], version: v, store: store, skill: skill, transport: fake())
        try store.apply(.decisions([DecisionChange(.palette, "#000003, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        XCTAssertEqual([st("S01"), st("S02")], [.upToDate, .stale], "a global palette change does not touch a scene that has its own palette")
        try store.apply(.decisions([DecisionChange(.effectsPack, Look.packs().first!.name)], title: nil))
        XCTAssertEqual(st("S01"), .stale, "the effects pack is inherited by every scene")
    }

    func testAFileEditedByHandStaysUpToDateButIsMarkedAndAFileWithNoRecordIsStale() async throws {
        _ = try await SceneGeneration.generate(["S01"], version: v, store: store, skill: skill, transport: fake())
        try (module("S01", "by hand")).write(to: SceneModules.url(version: v, scene: "S01", store: store), atomically: true, encoding: .utf8)
        let s = SceneModules.statuses(version: v, store: store)["S01"]
        XCTAssertEqual(s, SceneModules.Status(state: .upToDate, moduleEdited: true))
        try module("S02", "hand-made").write(to: SceneModules.url(version: v, scene: "S02", store: store), atomically: true, encoding: .utf8)
        XCTAssertEqual(SceneModules.statuses(version: v, store: store)["S02"]?.state, .stale, "a file nothing recorded cannot be called current")
        try "  \n".write(to: SceneModules.url(version: v, scene: "S02", store: store), atomically: true, encoding: .utf8)
        XCTAssertEqual(SceneModules.statuses(version: v, store: store)["S02"]?.state, .notGenerated, "an empty file is no module")
        // a record of another version says nothing about this one
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v2/scenes"), withIntermediateDirectories: true)
        try module("S01", "v2").write(to: SceneModules.url(version: "v2", scene: "S01", store: store), atomically: true, encoding: .utf8)
        XCTAssertEqual(SceneModules.statuses(version: "v2", store: store)["S01"]?.state, .stale)
    }

    // MARK: the whole version in the new format, and the older one

    func testAFilmInSceneFilesBuildsAndPlaysAndTheOlderFormatStillDoes() async throws {
        let probe = await Shell.run("command -v python3 && command -v node && node -e \"require('jsdom')\"", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "python3, node and jsdom are needed (run the app's setup check)")
        let sk = try XCTUnwrap(Skill.root())
        _ = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: sk, transport: fake())
        let part = await BuildRunner.run(version: v, store: store, skill: sk)
        XCTAssertTrue(part.built && part.harnessClean && part.smokeClean, part.steps.map { "\($0.title): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        let gone = try XCTUnwrap(part.steps.first { $0.id == "build.scenes" })
        XCTAssertEqual(gone.level, .tight); XCTAssertTrue(gone.detail.contains("S03 not generated"), gone.detail)
        XCTAssertFalse(part.ok, "a film with a placeholder is built, not finished")
        _ = try await SceneGeneration.generate(["S03"], version: v, store: store, skill: sk, transport: fake())
        let full = await BuildRunner.run(version: v, store: store, skill: sk)
        XCTAssertTrue(full.ok, full.steps.map { "\($0.title): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        XCTAssertEqual(full.steps.map { $0.id }, ["build.make", "build.harness", "build.smoke"])
        let html = try String(contentsOf: Versions.distURL(store, v), encoding: .utf8)
        XCTAssertTrue(html.contains("S02-v1") && html.contains("G.SRT"), "the scene files went into the page, with the compositor")
        // the older format: a version with only a hand-written main.js builds and plays as before
        let old = dir.appendingPathComponent("v2"); try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Film.write(version: "v2", store: store)
        try FileManager.default.copyItem(at: dir.appendingPathComponent("v1/project.json"), to: old.appendingPathComponent("project.json"))
        let sc = ["S01", "S02", "S03"].map { "\($0): (g, lt, c) => { g.fillStyle = '#334'; g.fillRect(0, 0, c.SW, c.SH); g.fillStyle = '#fff'; g.fillText('\($0) old', 40, 40); }" }.joined(separator: ", ")
        try """
        (function () { const film = window.SRF.fromData({ \(sc) }, { palette: { bg: '#111111', fg: '#ffffff', accent: '#ffffff', accent2: '#888888' } });
          window.SHOWREEL = { title: { en: 'Old' }, slug: 'old', footnote: { en: '' }, languages: [{ id: 'en', label: 'EN' }], formats: { d: [1600, 900] }, formatLabels: { d: 'Desktop' },
            controls: { pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true, notes: false },
            ui: { en: { reduced: 'Reduced motion', reducedOn: 'Reduced motion: on', play: 'Play', pause: 'Pause', muted: 'Sound off', sound: 'Sound on', rp: 'Replay', lp: 'Loop', fm: 'Format', lg: 'Language', startSound: 'Start with sound', startSilent: 'Start without sound' } },
            pageColor: '#000', setup() {}, render: film.render }; })();
        """.write(to: old.appendingPathComponent("main.js"), atomically: true, encoding: .utf8)
        let before = try Data(contentsOf: old.appendingPathComponent("main.js"))
        let oldReport = await BuildRunner.run(version: "v2", store: store, skill: sk)
        XCTAssertTrue(oldReport.ok, oldReport.steps.map { "\($0.title): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        XCTAssertEqual(try Data(contentsOf: old.appendingPathComponent("main.js")), before, "the hand-written main.js is not touched")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.appendingPathComponent("assembly.json").path), "nothing is assembled in the older format")
        XCTAssertEqual(oldReport.steps.map { $0.id }, ["build.make", "build.harness", "build.smoke"])
    }
}
