import XCTest
@testable import ShowreelKit

/// BG1c: a scene is tested on its own right after it is written, repaired once on a code error, and layout warnings are listed, never repaired by themselves.
final class BG1cTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    var skill: URL { Skill.root()! }

    override func setUp() {
        dir = makeTempDir("bg1c"); store = ProjectStore(root: dir)
        try? store.create(name: "BG", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "validated"))) }
        _ = try? Film.write(version: v, store: store)
    }
    override func tearDown() { SceneTest.override = nil; try? FileManager.default.removeItem(at: dir) }
    func exists(_ rel: String) -> Bool { FileManager.default.fileExists(atPath: dir.appendingPathComponent(rel).path) }
    func file(_ id: String) -> String { (try? String(contentsOf: dir.appendingPathComponent("v1/scenes/\(id).js"), encoding: .utf8)) ?? "" }

    /// A test of one scene that looks at the file: a call of `ease(` is the error of the trailer, a `//overlap` marker is a layout warning.
    func scripted() {
        SceneTest.override = { id, version in
            let js = (try? String(contentsOf: self.dir.appendingPathComponent("\(version)/scenes/\(id).js"), encoding: .utf8)) ?? ""
            if js.contains("ease(") { return SceneTestResult(codeErrors: ["S\(id.dropFirst()) t=1.00: EXCEPTION ease is not a function"], warnings: [], codeCount: 1, warningCount: 0) }
            if js.contains("//overlap") { return SceneTestResult(codeErrors: [], warnings: ["text collision \"A\" over \"B\""], codeCount: 0, warningCount: 1) }
            return SceneTestResult(codeErrors: [], warnings: [], codeCount: 0, warningCount: 0)
        }
    }

    // MARK: the contract says the exact form of the engine's names

    func testTheContractDescribesEaseAsAnObjectAndMatchesTheEngineAsNodeSeesIt() async throws {
        let text = SceneContract.text(skill: skill)
        XCTAssertTrue(text.contains("SR.ease: an object, never a function"), "ease is an object")
        XCTAssertTrue(text.contains("never SR.ease(...)"))
        // the engine as node sees it: every exported name, its kind, and the functions of each object
        let probe = await Shell.run("command -v node", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "node is needed")
        let js = """
        const fs = require('fs'), w = {}; w.window = w;
        for (const f of ['core.js', 'kit.js']) new Function('window', 'globalThis', fs.readFileSync('\(skill.path)/engine/' + f, 'utf8'))(w, w);
        const out = {}; for (const [ns, o] of [['SR', w.SR], ['SRK', w.SRK]]) for (const [k, v] of Object.entries(o)) out[ns + '.' + k] = typeof v === 'function' ? 'function' : (v && typeof v === 'object' ? 'object:' + Object.keys(v).filter(x => typeof v[x] === 'function').join(',') : 'value');
        console.log(JSON.stringify(out));
        """
        let script = dir.appendingPathComponent("shapes.js"); try js.write(to: script, atomically: true, encoding: .utf8)
        let ran = await Shell.run("node \(BuildRunner.q(script))", in: dir, timeout: 30)
        let r = try XCTUnwrap(ran)
        XCTAssertEqual(r.status, 0, r.err)
        let real = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(r.out.utf8)) as? [String: String])
        XCTAssertGreaterThan(real.count, 20)
        for (name, kind) in real where kind != "value" {
            let line = try XCTUnwrap(text.components(separatedBy: "\n").first { $0.hasPrefix(name + ":") || $0.hasPrefix(name + "(") }, "the contract does not describe \(name)")
            if kind == "function" { XCTAssertTrue(line.contains(": a function"), "\(name) is a function: \(line)") }
            else if kind == "object:" { XCTAssertFalse(line.contains(": a function"), "\(name) is data, not a function: \(line)") }
            else {
                XCTAssertTrue(line.contains("an object, never a function"), "\(name) is an object: \(line)")
                for fn in kind.dropFirst(7).split(separator: ",") { XCTAssertTrue(line.contains(String(fn)), "\(name).\(fn) is missing from: \(line)") }
            }
        }
        // the six functions of ease are named, not just 'ease'
        for fn in ["lin", "in2", "out2", "io2", "in3", "out3", "io3", "outExpo"] { XCTAssertTrue(text.contains(fn)) }
    }

    func testAnObjectThatIsCalledAsAFunctionWouldBeCaughtByTheShapeTest() {
        let wrong = SceneContract.shapes(of: "const ease = t => t;\nG.SR = { ease }", export: "G.SR = {", prefix: "SR")
        XCTAssertTrue(wrong.contains("SR.ease(t): a function"), "the reader tells a function from an object by the engine's text")
        let right = SceneContract.shapes(of: "const ease = { a: t => t, b: t => t * t };\nG.SR = { ease }", export: "G.SR = {", prefix: "SR")
        XCTAssertTrue(right.contains("SR.ease: an object, never a function. Its functions: a, b"))
    }

    // MARK: the test of one scene, for real (the skill's harness, no AI)

    func testTheRealTestOfOneSceneSeesTheEaseErrorAndAWarningApartFromIt() async throws {
        let probe = await Shell.run("command -v python3 && command -v node", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "python3 and node are needed")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v1/scenes"), withIntermediateDirectories: true)
        try "{\"title\": \"T\", \"main\": \"main.js\", \"duration\": 9, \"fonts\": [], \"tokens\": {}, \"weight_budget_mb\": 5}".write(to: dir.appendingPathComponent("v1/project.json"), atomically: true, encoding: .utf8)
        try "return { palette: { bg: '#000', fg: '#fff', accent: '#f00', accent2: '#0f0' }, show: {} };\n".write(to: dir.appendingPathComponent("v1/reel.js"), atomically: true, encoding: .utf8)
        try "const { clamp, ease } = SR;\nreturn function render(g, lt, c) { g.fillText('hi', 40, 40 + ease(clamp(lt, 0, 1))); };\n".write(to: dir.appendingPathComponent("v1/scenes/S01.js"), atomically: true, encoding: .utf8)
        try "const { clamp, ease } = SR;\nreturn function render(g, lt, c) { g.font = '60px sans-serif'; g.fillText('over', 400, 400 + ease.out3(clamp(lt, 0, 1))); g.fillText('over too', 410, 410); };\n".write(to: dir.appendingPathComponent("v1/scenes/S02.js"), atomically: true, encoding: .utf8)
        try "return function render(g, lt, c) { g.fillText('fine', 40, 40); };\n".write(to: dir.appendingPathComponent("v1/scenes/S03.js"), atomically: true, encoding: .utf8)
        let badR = await SceneTest.run(scene: "S01", version: v, store: store, skill: skill); let bad = try XCTUnwrap(badR)
        XCTAssertFalse(bad.ok); XCTAssertTrue(bad.codeErrors.joined().contains("ease is not a function"), "\(bad)")
        XCTAssertGreaterThan(bad.codeCount, 1, "every frame throws"); XCTAssertEqual(bad.codeErrors.count, 1, "listed once, with its count")
        let layR = await SceneTest.run(scene: "S02", version: v, store: store, skill: skill); let lay = try XCTUnwrap(layR)
        XCTAssertTrue(lay.ok, "\(lay)"); XCTAssertGreaterThan(lay.warningCount, 0, "a collision is a warning, not an error")
        let fineR = await SceneTest.run(scene: "S03", version: v, store: store, skill: skill); let fine = try XCTUnwrap(fineR)
        XCTAssertTrue(fine.ok && fine.warningCount == 0, "\(fine)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(".scenetest-v1-S01").path), "the scratch copy is removed")
        // the film as a whole sorts them too: S01 throws on every frame, S02 collides
        let report = await BuildRunner.run(version: v, store: store, skill: skill)
        let logic = try XCTUnwrap(report.steps.first { $0.id == "build.harness" })
        XCTAssertEqual(logic.level, .fail); XCTAssertTrue(logic.detail.contains("code error") && !logic.detail.contains("66 issues"), logic.detail)
        try "return function render(g, lt, c) { g.fillText('ok', 40, 40); };\n".write(to: dir.appendingPathComponent("v1/scenes/S01.js"), atomically: true, encoding: .utf8)
        let clean = await BuildRunner.run(version: v, store: store, skill: skill)
        let ok = try XCTUnwrap(clean.steps.first { $0.id == "build.harness" })
        XCTAssertEqual(ok.level, .ok); XCTAssertTrue(ok.detail.hasPrefix("0 code errors, "), ok.detail)
        let note = try XCTUnwrap(clean.steps.first { $0.id == "build.layout" }, "the warnings are said apart")
        XCTAssertEqual(note.level, .tight); XCTAssertTrue(note.detail.contains("layout warning"))
        XCTAssertTrue(clean.built && clean.harnessClean, "a layout warning does not fail the test")
    }

    func testTheHarnessLinesAreParsed() {
        let out = "issues: 62\ncode errors: 60\nlayout warnings: 2\n  code: S13|en/d t=1.00: EXCEPTION ease is not a function (x60)\n  layout: S15|en/d t=2.00: text collision \"A\" over \"B\"\nnear-empty frames: 0\n"
        let r = SceneTest.parse(out)
        XCTAssertEqual(r?.codeCount, 60); XCTAssertEqual(r?.warningCount, 2)
        XCTAssertEqual(r?.codeErrors, ["S13|en/d t=1.00: EXCEPTION ease is not a function (x60)"]); XCTAssertEqual(r?.warnings.count, 1)
        XCTAssertNil(SceneTest.parse("issues: 3\n"), "an older harness does not sort: the caller falls back")
        XCTAssertEqual(SceneTest.repairsPerScene, 1)
    }

    // MARK: in the Build

    func testASceneThatFailsItsTestIsRepairedOnceWithTheExactError() async throws {
        scripted()
        let m = JobModel()
        m.sceneText = { step, prompt in prompt.contains("FAILED its test") ? "return function render(g, lt, c) { g.fillText('\(step) fixed', 1, 1); };" : (step == "S02" ? "const { ease } = SR; return function render(g, lt, c) { g.fillText('x', 1, ease(lt)); };" : "return function render(g, lt, c) { g.fillText('\(step)', 1, 1); };") }
        var seenStates: [SceneRun.State] = []
        m.onRequest = { step in if step == "S02", (m.prompts["S02"]?.count ?? 0) == 1 { seenStates.append(self.store.activity.snapshot.build?.runs["S02"]?.state ?? .waiting) } }
        var testing: [SceneRun.State] = []
        let base = SceneTest.override!
        SceneTest.override = { id, version in testing.append(self.store.activity.snapshot.build?.runs[id]?.state ?? .waiting); return await base(id, version) }
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(out, .completed(written: 3))
        XCTAssertEqual(m.prompts["S02"]?.count, 2, "one request, one repair")
        let repair = try XCTUnwrap(m.prompts["S02"]?.last)
        XCTAssertTrue(repair.contains("EXCEPTION ease is not a function") && repair.contains("const { ease } = SR;") && repair.contains("an object is never called as a function"), "the exact error and the file are in the request")
        XCTAssertEqual(m.prompts["S01"]?.count, 1); XCTAssertTrue(file("S02").contains("S02 fixed"))
        XCTAssertTrue(testing.contains(.testing), "the state is testing while a test runs")
        XCTAssertEqual(store.activity.snapshot.build?.runs["S02"]?.state, .done)
        let titles = store.journal.entries().filter { $0.op == "build" }.map { $0.title }
        XCTAssertTrue(titles.contains("Repair of S02: the test failed") && titles.contains { $0.hasPrefix("Test of S02: 1 code error") } && titles.contains { $0.hasPrefix("Test of S02: 0 code errors") }, "\(titles)")
    }

    func testTheRepairStateIsVisibleWhileTheRewriteRuns() async throws {
        scripted()
        let m = JobModel()
        var states: [SceneRun.State] = []
        m.sceneText = { step, prompt in
            if prompt.contains("FAILED its test") { states.append(self.store.activity.snapshot.build?.runs[step]?.state ?? .waiting); return "return function render() {};" }
            return step == "S01" ? "return function render() { ease(1); };" : "return function render() {};"
        }
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(states, [.repairing])
    }

    func testASceneThatFailsTwiceIsAnEmptyFrameAndTheBuildGoesOn() async throws {
        scripted()
        let m = JobModel()
        m.sceneText = { step, _ in step == "S02" ? "return function render() { ease(1); };" : "return function render() {};" }
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        guard case .stopped(let stop) = out else { return XCTFail("\(out)") }
        XCTAssertEqual(stop.failedTests, ["S02"]); XCTAssertEqual(stop.cause, "test")
        XCTAssertTrue(stop.message.contains("S02 failed its test even after a rewrite") && stop.message.contains("ease is not a function") && stop.message.contains("empty frame"), stop.message)
        XCTAssertEqual(m.prompts["S02"]?.count, 2, "never more than one repair"); XCTAssertEqual(m.prompts["S03"]?.count, 1, "the other scenes were written")
        XCTAssertTrue(exists("v1/scenes/S01.js") && exists("v1/scenes/S03.js")); XCTAssertFalse(exists("v1/scenes/S02.js"), "an empty frame, not the broken file")
        let run = try XCTUnwrap(store.activity.snapshot.build?.runs["S02"])
        XCTAssertEqual(run.state, .failed); XCTAssertTrue(run.failedTest); XCTAssertTrue(run.failure?.contains("ease") == true)
        XCTAssertEqual(BuildJob.pending(store), "v1", "the button says Continue")
        // Continue the build leaves it aside and finishes; Try again writes it again (and a new repair is allowed in the new Build)
        let again = JobModel()
        let out2 = await BuildJob.run(version: v, store: store, skill: skill, transport: again, skip: ["S02"])
        XCTAssertEqual(out2, .completed(written: 2)); XCTAssertEqual(again.asked, [])
        XCTAssertEqual(store.activity.snapshot.build?.runs["S02"]?.state, .failed)
        let retry = JobModel(); let out3 = await BuildJob.run(version: v, store: store, skill: skill, transport: retry)
        XCTAssertEqual(retry.asked, ["S02"]); XCTAssertEqual(out3, .completed(written: 3))
    }

    func testALayoutWarningDoesNotTriggerARepairButIsListedWithItsCount() async throws {
        scripted()
        let m = JobModel()
        m.sceneText = { step, _ in step == "S03" ? "//overlap\nreturn function render() {};" : "return function render() {};" }
        let out = await BuildJob.run(version: v, store: store, skill: skill, transport: m)
        XCTAssertEqual(out, .completed(written: 3))
        XCTAssertEqual(m.prompts["S03"]?.count, 1, "no repair for a warning")
        let r = try XCTUnwrap(store.activity.snapshot.build?.runs["S03"])
        XCTAssertEqual(r.state, .done); XCTAssertEqual(r.warningCount, 1); XCTAssertEqual(r.warnings, ["text collision \"A\" over \"B\""])
        XCTAssertEqual(store.activity.snapshot.build?.runs["S01"]?.warningCount, 0)
    }

    // MARK: Fix this scene

    func testFixThisSceneIsOneGenerationWithTheWarningAndTheFileAndAConfirmationCard() async throws {
        scripted()
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel())
        store.activity.update { $0.build = nil }                    // the app does this when it has tested the film
        let card = try SceneGeneration.plan(["S02"], version: v, store: store)
        XCTAssertEqual(card.title, "Generate S02 in v1", "a card first")
        let m = JobModel()
        m.sceneText = { _, prompt in XCTAssertTrue(prompt.contains("layout problems") && prompt.contains("text collision \"A\" over \"B\"") && prompt.contains("The file as it is"), prompt); return "return function render() { /* fixed */ };" }
        let done = try await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: m, fixing: ["S02": ["text collision \"A\" over \"B\""]])
        XCTAssertEqual(done, ["S02"]); XCTAssertEqual(m.asked, ["S02"], "one request")
        XCTAssertTrue(file("S02").contains("fixed")); XCTAssertEqual(file("S01").contains("fixed"), false)
    }

    func testALockedSceneIsNeverFixed() async throws {
        scripted()
        _ = await BuildJob.run(version: v, store: store, skill: skill, transport: JobModel())
        store.activity.update { $0.build = nil }
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        let f = try XCTUnwrap(store.loadShowreel())
        XCTAssertNotNil(SceneGeneration.refusal("S02", version: v, in: f, store: store), "the button is disabled with the reason")
        let m = JobModel()
        do { _ = try await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: m, fixing: ["S02": ["x"]]); XCTFail("refused") } catch { XCTAssertTrue(error.localizedDescription.contains("locked") || error.localizedDescription.contains("Locked"), error.localizedDescription) }
        XCTAssertEqual(m.asked, [])
    }
}
