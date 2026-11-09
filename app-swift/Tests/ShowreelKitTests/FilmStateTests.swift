import XCTest
@testable import ShowreelKit

/// V2: the state of the film and of each scene from fingerprints, the version that is read, the assembly with no AI, the old format, what the generation offers, what a
/// transition says about itself.
final class FilmStateTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    override func setUp() {
        dir = makeTempDir("filmstate"); store = ProjectStore(root: dir)
        try? store.create(name: "FS", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t, status: "validated"))) }
        store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    var skill: URL { Skill.root()! }
    func status() -> FilmBuild.Status { FilmBuild.status(store) }
    func module(_ w: String) -> String { "return function render(g, lt, c) { g.fillStyle = '#223'; g.fillRect(0, 0, c.SW, c.SH); g.fillStyle = '#fff'; g.fillText('\(w)', 40, 40); };\n" }
    func versionFolder(_ n: String, scenes: [String]?, dist: Bool, result: Bool? = nil, main: String? = nil) throws {
        let d = dir.appendingPathComponent(n); try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        try "{\"title\": \"T\", \"main\": \"main.js\", \"duration\": 12, \"fonts\": [], \"tokens\": {}, \"weight_budget_mb\": 5}".write(to: d.appendingPathComponent("project.json"), atomically: true, encoding: .utf8)
        try Film.text(file).write(to: d.appendingPathComponent("film.json"), atomically: true, encoding: .utf8)
        if let sc = scenes {
            try FileManager.default.createDirectory(at: d.appendingPathComponent("scenes"), withIntermediateDirectories: true)
            for id in sc { try module(id).write(to: d.appendingPathComponent("scenes/\(id).js"), atomically: true, encoding: .utf8) }
        }
        if let m = main { try m.write(to: d.appendingPathComponent("main.js"), atomically: true, encoding: .utf8) }
        if dist { try FileManager.default.createDirectory(at: d.appendingPathComponent("dist"), withIntermediateDirectories: true); try "<html></html>".write(to: d.appendingPathComponent("dist/index.html"), atomically: true, encoding: .utf8) }
        if let r = result { try SceneModules.recordResult(version: n, ok: r, store: store) }
    }
    /// A version assembled as it is now: every scene has a file, the film is recorded.
    func assembledV1() throws {
        try versionFolder(v, scenes: ["S01", "S02", "S03"], dist: true, result: true)
        try SceneModules.recordGeneration(version: v, store: store); try SceneModules.recordAssembly(version: v, store: store)
    }
    func sceneState(_ id: String) -> SceneModules.State { status().scenes[id]!.state }

    // MARK: what makes what stale

    func testWhatMakesTheFilmAndTheScenesStale() throws {
        try assembledV1()
        XCTAssertEqual(status().state, .upToDate); XCTAssertTrue(status().isOK); XCTAssertEqual(status().counter, "Film up to date")
        func expect(_ what: String, film: Bool, scenes: [String], _ change: () throws -> Void, undo: () throws -> Void) throws {
            try change()
            let s = status()
            XCTAssertEqual(s.state, film ? .stale : .upToDate, "\(what): film"); XCTAssertEqual(s.scenes.filter { $0.value.state == .stale }.keys.sorted(), scenes, "\(what): scenes")
            if film { XCTAssertFalse(s.staleReasons.isEmpty, what); XCTAssertEqual(s.counter, scenes.isEmpty ? "Film stale" : "\(scenes.count) scene\(scenes.count == 1 ? "" : "s") to generate"); XCTAssertTrue(s.staleLine?.hasPrefix("Stale since the last assembly: ") == true) }
            try undo()
            XCTAssertTrue(status().isOK, "\(what): back to up to date once put back")
        }
        try expect("order", film: true, scenes: [], { try self.store.apply(.moveScene(id: "S03", after: "start", montage: nil)) }, undo: { try self.store.apply(.moveScene(id: "S03", after: "S02", montage: nil)) })
        try expect("transition", film: true, scenes: [], { try self.store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5))) }, undo: { try self.store.apply(.transition(from: "S01", nil)) })
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5))); try SceneModules.recordAssembly(version: v, store: store)
        try expect("transition length", film: true, scenes: [], { try self.store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.8))) }, undo: { try self.store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5))) })
        try expect("music", film: true, scenes: [], { var f = self.file; f.decisions.track = ShowreelFile.Track(file: "assets/prepared/a.mp3"); try self.store.save(f) }, undo: { var f = self.file; f.decisions.track = nil; try self.store.save(f) })
        try expect("review state", film: false, scenes: [], { try self.store.apply(.scene(id: "S01", SceneEdit(status: "wip"))) }, undo: { try self.store.apply(.scene(id: "S01", SceneEdit(status: "validated"))) })
        try expect("content", film: true, scenes: ["S02"], { try self.store.apply(.scene(id: "S02", SceneEdit(text: "Two, changed"))) }, undo: { try self.store.apply(.scene(id: "S02", SceneEdit(text: "Two"))) })
        try expect("scene length", film: true, scenes: ["S02"], { try self.store.apply(.resize(scene: "S02", duration: 6, ripple: false)) }, undo: { try self.store.apply(.resize(scene: "S02", duration: 4, ripple: false)) })
        try expect("scene look", film: true, scenes: ["S03"], { try self.store.apply(.sceneLook(id: "S03", [DecisionChange(.palette, "#000001, #FFFFFF, #FF0000, #00FF00")])) }, undo: { try self.store.apply(.sceneLook(id: "S03", [DecisionChange(.palette, "")])) })
        // a global look change touches every scene that has no look of its own
        try store.apply(.decisions([DecisionChange(.palette, "#000002, #FFFFFF, #FF0000, #00FF00")], title: nil))
        XCTAssertEqual(status().state, .stale); XCTAssertEqual(status().scenes.filter { $0.value.state == .stale }.keys.sorted(), ["S01", "S02", "S03"])
        try store.apply(.decisions([DecisionChange(.palette, "")], title: nil))
        XCTAssertTrue(status().isOK)
        // a scene file written again: the film is stale (it holds the old file), the scene is up to date
        try module("again").write(to: SceneModules.url(version: v, scene: "S01", store: store), atomically: true, encoding: .utf8)
        XCTAssertEqual(status().state, .stale); XCTAssertEqual(status().staleReasons, ["the file of S01 changed"]); XCTAssertTrue(status().scenes["S01"]!.moduleEdited); XCTAssertEqual(sceneState("S01"), .upToDate)
    }

    func testAStaleSceneIsNeverShownAsUpToDate() throws {
        try assembledV1()
        try store.apply(.scene(id: "S01", SceneEdit(text: "Changed")))
        XCTAssertEqual(sceneState("S01"), .stale); XCTAssertEqual(status().state, .stale)
        XCTAssertFalse(status().isOK)
    }

    // MARK: a locked scene whose inherited look changed

    func testALockedSceneWhoseLookChangedIsStaleAndNeverGeneratedAgainWithoutUnlocking() async throws {
        try assembledV1()
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        XCTAssertEqual(sceneState("S02"), .upToDate, "locking changes no input")
        try store.apply(.decisions([DecisionChange(.palette, "#000009, #FFFFFF, #FF0000, #00FF00")], title: nil))      // what the card of a global change lets the owner apply
        XCTAssertEqual(sceneState("S02"), .stale); XCTAssertEqual(status().state, .stale)
        let a = Availability.regenerate("S02", status(), file: file).why
        XCTAssertEqual(a?.message, "S02 is locked and its look changed. Unlock it to generate it again"); XCTAssertEqual(a?.link, .scene("S02"))
        XCTAssertTrue(Availability.regenerate("S01", status(), file: file).isAvailable)
        // not by the Generate card, the offer, the operation, nor Clap
        XCTAssertThrowsError(try SceneGeneration.plan(["S02"], version: v, store: store)) { XCTAssertEqual($0.localizedDescription, SceneLock.reason("S02")) }
        let m = SceneWriterModel { _ in "```js\nreturn function () {};\n```" }
        let before = try Data(contentsOf: SceneModules.url(version: v, scene: "S02", store: store))
        do { _ = try await SceneGeneration.generate(["S01", "S02"], version: v, store: store, skill: skill, transport: m); XCTFail("refused") } catch {}
        XCTAssertTrue(m.prompts.isEmpty); XCTAssertEqual(try Data(contentsOf: SceneModules.url(version: v, scene: "S02", store: store)), before)
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: skill, ui: ui); tools.sceneTransport = m
        let out = await tools.run("generate_scenes", ["scenes": ["S02"]]).text
        XCTAssertTrue(out.hasPrefix("refused:") && out.contains("S02 is locked"), out); XCTAssertTrue(ui.cards.isEmpty)
        // unlocked, it can be generated again
        try store.apply(.sceneLock(ids: ["S02"], locked: false))
        XCTAssertTrue(Availability.regenerate("S02", status(), file: file).isAvailable)
        XCTAssertNoThrow(try SceneGeneration.plan(["S02"], version: v, store: store))
    }

    // MARK: the version that is read

    func testAnIncompleteVersionIsNeverTheOneThatIsRead() throws {
        try assembledV1()
        // a build that was cancelled: the folder has some scene files and no page
        try versionFolder("v2", scenes: ["S01"], dist: false)
        XCTAssertEqual(Versions.working(store), "v1"); XCTAssertEqual(Versions.incomplete(store), ["v2"]); XCTAssertEqual(Versions.target(store), "v2")
        let s = status()
        XCTAssertEqual(s.playable, "v1"); XCTAssertEqual(s.incomplete, ["v2"]); XCTAssertEqual(s.state, .neverAssembled, "v2 was never assembled")
        XCTAssertEqual(Availability.play(s), .available, "the reader keeps reading the last version that works")
        XCTAssertEqual(BuildProgress.lastWorking(store), "v1")
        // a version whose last test was red is not read either
        try versionFolder("v3", scenes: ["S01", "S02", "S03"], dist: true, result: false)
        XCTAssertEqual(Versions.working(store), "v1"); XCTAssertFalse(Versions.incomplete(store).contains("v3"), "it has a page: it needs attention, it is not incomplete")
        // only incomplete versions: nothing to read, and the way is to assemble
        let d = makeTempDir("only-partial"); defer { try? FileManager.default.removeItem(at: d) }
        let s2 = ProjectStore(root: d); try s2.create(name: "P", conversationLanguage: "en", reelLanguages: ["en"])
        try? FileManager.default.createDirectory(at: d.appendingPathComponent("v1"), withIntermediateDirectories: true)
        try "{}".write(to: d.appendingPathComponent("v1/project.json"), atomically: true, encoding: .utf8)
        XCTAssertNil(Versions.working(s2)); XCTAssertEqual(Versions.incomplete(s2), ["v1"])
        XCTAssertEqual(Availability.play(FilmBuild.status(s2)).why, Reasons.notAssembled); XCTAssertEqual(Reasons.notAssembled.link, .assemble)
        XCTAssertEqual(Availability.play(FilmBuild.status(ProjectStore(root: makeTempDir("none")))).why, Reasons.nothingToAssemble)
    }

    func testABuildCancelledByTheUserLeavesThePartialFolderAndTheOldFilmReads() throws {
        try assembledV1()
        store.activity.update { $0.build = .init(version: "v2", phase: .generating) }
        try versionFolder("v2", scenes: ["S01", "S02"], dist: false)
        store.activity.update { $0.build?.phase = .cancelling }; store.activity.update { $0.build = nil }
        XCTAssertEqual(Versions.working(store), "v1"); XCTAssertEqual(Versions.incomplete(store), ["v2"])
        XCTAssertEqual(Unavailable.Link.assemble, Reasons.notAssembled.link)
    }

    // MARK: the old format

    func testTheOldFormatPlaysAsItIsAndShowsNoSceneStates() throws {
        try versionFolder(v, scenes: nil, dist: true, main: "// hand written\n")
        let s = status()
        XCTAssertEqual(s.state, .legacy); XCTAssertEqual(s.counter, "Old format"); XCTAssertTrue(s.scenes.isEmpty); XCTAssertTrue(s.ungenerated.isEmpty)
        XCTAssertEqual(s.playable, v); XCTAssertEqual(Availability.play(s), .available)
        let a = Availability.assemble(s, in: ProjectActivity.Snapshot()).why
        XCTAssertEqual(a, Reasons.legacy); XCTAssertEqual(FilmBuild.legacySentence, "Old format: scenes cannot be regenerated one by one. A new Build switches to the new format.")
        XCTAssertEqual((a?.message ?? "") + ".", FilmBuild.legacySentence)
        XCTAssertEqual(Availability.generate(["S01"], s, in: ProjectActivity.Snapshot(), hasKey: true, file: file).why, Reasons.legacy)
    }

    // MARK: assembling, with no AI

    func engineThere() async throws {
        let probe = await Shell.run("command -v python3 && command -v node && node -e \"require('jsdom')\"", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "python3, node and jsdom are needed (run the app's setup check)")
    }

    func testAssemblingWithAMissingSceneSucceedsAndStaysFlagged() async throws {
        try await engineThere()
        try versionFolder(v, scenes: ["S01", "S02"], dist: false)
        try SceneModules.recordGeneration(version: v, store: store)
        let r = await FilmAssembly.run(version: v, store: store, skill: skill)
        XCTAssertTrue(r.ok, r.message); XCTAssertEqual(r.ungenerated, ["S03"]); XCTAssertEqual(r.scenes, 3)
        XCTAssertTrue(r.message.hasPrefix("Film assembled: 3 scenes, 0 transitions") && r.message.contains("S03 not generated"), r.message)
        XCTAssertTrue(Versions.hasDist(store, v)); XCTAssertEqual(Versions.working(store), v)
        let s = status()
        XCTAssertEqual(s.state, .upToDate); XCTAssertEqual(s.ungenerated, ["S03"]); XCTAssertFalse(s.isOK, "assembled, but not ok"); XCTAssertEqual(s.counter, "1 scene to generate")
        let html = try String(contentsOf: Versions.distURL(store, v), encoding: .utf8)
        XCTAssertTrue(html.contains("placeholder"), "the empty frame is in the page")
        XCTAssertNil(store.activity.snapshot.build, "the project is editable again")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1.assembling").path), "the working copy is gone")
        XCTAssertEqual(store.journal.entries().last?.op, "assemble")
        // the offer to generate, with the banner of the player
        let offer = SceneGeneration.offer(version: v, store: store, file: file)
        XCTAssertEqual(offer.ids, ["S03"]); XCTAssertEqual(offer.bannerLine, "S03 is not generated: shown as empty frames")
    }

    func testAFailedAssemblyKeepsTheVersionThatWorks() async throws {
        try await engineThere()
        try versionFolder(v, scenes: ["S01", "S02", "S03"], dist: false)
        let ok = await FilmAssembly.run(version: v, store: store, skill: skill)
        XCTAssertTrue(ok.ok, ok.message)
        let page = try Data(contentsOf: Versions.distURL(store, v)), main = try Data(contentsOf: dir.appendingPathComponent("v1/main.js"))
        try store.apply(.moveScene(id: "S03", after: "start", montage: nil))                       // a change: the film is stale
        XCTAssertEqual(status().state, .stale)
        try "{ not json".write(to: dir.appendingPathComponent("v1/project.json"), atomically: true, encoding: .utf8)     // the engine will fail
        let bad = await FilmAssembly.run(version: v, store: store, skill: skill)
        XCTAssertFalse(bad.ok); XCTAssertTrue(bad.message.hasPrefix("Assembly failed, v1 is unchanged and still the film that works."), bad.message); XCTAssertTrue(bad.message.contains("Build v1"), "the engine's own error")
        XCTAssertEqual(try Data(contentsOf: Versions.distURL(store, v)), page, "the page is the one that worked"); XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("v1/main.js")), main)
        XCTAssertEqual(Versions.working(store), v); XCTAssertEqual(SceneModules.result(version: v, store: store)?.ok, true, "a failed assembly does not turn the result red")
        XCTAssertNil(store.activity.snapshot.build); XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1.assembling").path))
        XCTAssertEqual(status().state, .stale, "still stale: nothing was assembled")
    }

    func testAssemblyIsRefusedWhileABuildRunsAndInTheOldFormat() async throws {
        try versionFolder(v, scenes: ["S01"], dist: false)
        store.activity.update { $0.build = .init(version: "v2", phase: .generating) }
        let r = await FilmAssembly.run(version: v, store: store, skill: skill)
        XCTAssertFalse(r.ok); XCTAssertEqual(r.message, Reasons.building.message)
        XCTAssertEqual(Availability.assemble(status(), in: store.activity.snapshot).why, Reasons.building)
        store.activity.reset()
        try versionFolder("v2", scenes: nil, dist: false, main: "// old\n")
        let old = await FilmAssembly.run(version: "v2", store: store, skill: skill)
        XCTAssertFalse(old.ok); XCTAssertEqual(old.message, FilmBuild.legacySentence)
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("v2/main.js"), encoding: .utf8), "// old\n")
    }

    func testClapCanAssembleWithNoAICard() async throws {
        try await engineThere()
        try versionFolder(v, scenes: ["S01", "S02", "S03"], dist: false)
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: skill, ui: ui)
        let out = await tools.run("assemble_film", [:]).text
        XCTAssertTrue(out.hasPrefix("Film assembled: 3 scenes"), out); XCTAssertTrue(ui.cards.isEmpty, "free: no card")
        XCTAssertTrue(Tools.definitions.contains { ($0["name"] as? String) == "assemble_film" })
        XCTAssertEqual(store.journal.entries().last?.author, "clap")
        try versionFolder("v2", scenes: nil, dist: false, main: "// old\n")
        let old = await tools.run("assemble_film", [:]).text
        XCTAssertTrue(old.hasPrefix("refused: Old format"), old)
        store.activity.update { $0.build = .init(version: "v2", phase: .generating) }
        let frozen = await tools.run("assemble_film", ["version": "v1"]).text
        XCTAssertTrue(frozen.contains("Building the film"), frozen)
    }

    // MARK: generating what is not generated

    func testTheOfferLeavesOutLockedScenesWithTheirReasonAndIsOneCard() throws {
        try versionFolder(v, scenes: ["S02"], dist: false)
        try SceneModules.recordGeneration(version: v, store: store)
        try store.apply(.sceneLock(ids: ["S03"], locked: true))
        let o = SceneGeneration.offer(version: v, store: store, file: file)
        XCTAssertEqual(o.ids, ["S01"]); XCTAssertEqual(o.excluded.map { $0.id }, ["S03"]); XCTAssertEqual(o.excluded.first?.reason, SceneLock.reason("S03"))
        XCTAssertEqual(o.bannerLine, "S01 and S03 are not generated: shown as empty frames")
        try store.apply(.sceneLock(ids: ["S03"], locked: false))
        let all = SceneGeneration.offer(version: v, store: store, file: file)
        XCTAssertEqual(all.ids, ["S01", "S03"])
        let card = try SceneGeneration.plan(all.ids, version: v, store: store)
        XCTAssertEqual(card.title, "Generate 2 scenes in v1: S01, S03", "one card for the scenes")
        XCTAssertEqual(card.changes.filter { $0.label.hasSuffix(".js") }.map { $0.label }, ["v1/scenes/S01.js", "v1/scenes/S03.js"])
        let cost = try XCTUnwrap(card.changes.first { $0.label == "Cost" })
        XCTAssertTrue(cost.after.hasPrefix("2 model calls, about ") && cost.after.contains("tokens in and up to 6k out (an estimate)"), cost.after)
        XCTAssertEqual(SceneGeneration.estimate(["S01"], version: v, store: store, skill: skill).calls, 1)
        // the reasons of the buttons
        let s = status(), snap = ProjectActivity.Snapshot()
        XCTAssertEqual(Availability.generate(all.ids, s, in: snap, hasKey: false, file: file).why, Reasons.noKey)
        XCTAssertEqual(Availability.generate(all.ids, s, in: snap, hasKey: true, file: file), .available)
        XCTAssertEqual(Availability.generate([], s, in: snap, hasKey: true, file: file).why?.reason, "No scene to generate")
        var b = snap; b.build = .init(version: v, phase: .generating)
        XCTAssertEqual(Availability.generate(all.ids, s, in: b, hasKey: true, file: file).why, Reasons.building)
        XCTAssertEqual(Availability.assemble(s, in: snap), .available)
    }

    // MARK: what a transition says about itself

    func testTheNotesOfATransition() throws {
        try versionFolder(v, scenes: ["S01", "S02", "S03"], dist: true, result: true)
        try SceneModules.recordGeneration(version: v, store: store)
        XCTAssertNil(TransitionNotes.note(after: "S01", in: file, store: store), "a cut says nothing")
        let preview = try XCTUnwrap(Look.transitionsPreviewOnly().first)
        var data = file; data.storyboards[0].items[0].transition.type = preview; try store.save(data)       // such a transition cannot be chosen any more: it is in a project made before
        XCTAssertEqual(TransitionNotes.note(after: "S01", in: file, store: store), TransitionNote(approximate: true, instruction: nil))
        XCTAssertEqual(TransitionNote.approximateText, "approximate render at assembly")
        try store.apply(.transition(from: "S02", TransitionEdit(type: "Push", duration: 0.5)))
        XCTAssertNil(TransitionNotes.note(after: "S02", in: file, store: store), "a transition that works, with no instruction")
        // an instruction is read by a generation, never by the assembly
        try store.apply(.transition(from: "S02", TransitionEdit(type: "Push", duration: 0.5, instruction: "the card becomes the logo")))
        var n = try XCTUnwrap(TransitionNotes.note(after: "S02", in: file, store: store))
        XCTAssertEqual(n.instruction, .pending(scenes: ["S02", "S03"])); XCTAssertEqual(n.instructionText, "instruction pending: used at the next generation of S02 and S03")
        try SceneModules.recordGeneration(version: v, scenes: ["S02"], store: store)
        XCTAssertEqual(TransitionNotes.note(after: "S02", in: file, store: store)?.instruction, .pending(scenes: ["S02", "S03"]), "both scenes must have been generated with it")
        try SceneModules.recordGeneration(version: v, scenes: ["S02", "S03"], store: store)
        n = try XCTUnwrap(TransitionNotes.note(after: "S02", in: file, store: store)); XCTAssertEqual(n.instruction, .used)
        try store.apply(.transition(from: "S02", TransitionEdit(type: "Push", duration: 0.5, instruction: "another idea")))
        XCTAssertEqual(TransitionNotes.note(after: "S02", in: file, store: store)?.instruction, .pending(scenes: ["S02", "S03"]), "a new instruction is pending again")
        XCTAssertFalse(status().scenes.values.contains { $0.state == .stale }, "a transition's instruction never makes a scene stale")
        // the old format cannot use an instruction at all
        try FileManager.default.removeItem(at: dir.appendingPathComponent("v1/scenes"))
        XCTAssertEqual(TransitionNotes.note(after: "S02", in: file, store: store)?.instructionText, "instruction not applied yet")
    }

    func testTheGenerationPromptQuotesThePassageInstruction() throws {
        try versionFolder(v, scenes: nil, dist: false)
        try store.apply(.transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5, instruction: "the card becomes the logo")))
        let p = SceneGeneration.prompt(scene: "S02", version: v, store: store, skill: skill)
        XCTAssertTrue(p.contains("the card becomes the logo"), "the instruction reaches the model at generation")
        XCTAssertTrue(Build_filmJSONCarriesIt())
    }
    func Build_filmJSONCarriesIt() -> Bool { Film.text(file).contains("the card becomes the logo") }
}
