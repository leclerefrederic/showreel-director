import XCTest
@testable import ShowreelKit

final class WizardTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let spec = ProcessSpec.load()
    override func setUp() { dir = makeTempDir("wizard"); store = ProjectStore(root: dir) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    var steps: [WizardStep] { Wizard.steps(assets: Assets.load(store), spec: spec) }
    func decided(_ s: WizardStep) -> Bool { Wizard.isDecided(s, file: store.loadShowreel(), assets: Assets.load(store), settings: store.settings, spec: spec) }
    func resume() -> String? {
        Wizard.firstUndecided(steps, file: store.loadShowreel(), assets: Assets.load(store), settings: store.settings, spec: spec).map { steps[$0].id }
    }

    func testModeDefaults() throws {
        XCTAssertEqual(store.settings.mode, "manual", "a folder with no setting is manual")
        try store.create(name: "New", conversationLanguage: nil, reelLanguages: [])
        XCTAssertEqual(store.settings.mode, "wizard", "a new project starts in the wizard unless it was created manual")
        var s = store.settings; s.mode = "manual"; store.settings = s
        XCTAssertEqual(ProjectStore(root: dir).settings.mode, "manual")
        XCTAssertEqual(try JSONDecoder().decode(StudioSettings.self, from: Data("{\"applyDirectly\":true}".utf8)), StudioSettings(applyDirectly: true, mode: "manual"), "an old ui.json keeps its setting")
        XCTAssertEqual(try JSONDecoder().decode(StudioSettings.self, from: Data("{\"mode\":\"nonsense\"}".utf8)).mode, "manual")
    }

    func testSwitchingModeLosesNothing() throws {
        try store.create(name: "Switch", conversationLanguage: nil, reelLanguages: [])
        try store.apply(.parameter(.audience, "Teams"))
        store.markDecided("project.constraints")
        let before = store.loadShowreel()
        var s = store.settings; s.mode = "manual"; store.settings = s
        s = store.settings; s.mode = "wizard"; store.settings = s
        XCTAssertEqual(store.loadShowreel(), before, "the data does not depend on the mode")
        XCTAssertEqual(store.settings.decided, ["project.constraints"], "nor do the wizard's own marks")
        XCTAssertEqual(store.loadShowreel()?.parameters.audience, "Teams")
    }

    func testStepsFollowTheInterviewAndThePlan() throws {
        try store.create(name: "S", conversationLanguage: nil, reelLanguages: [])
        let ids = steps.map { $0.id }
        XCTAssertEqual(Array(ids.prefix(8)), ["project.conversationLanguage", "project.reelLanguages", "project.audience", "project.message", "project.tone",
                                              "project.duration", "project.formats", "project.constraints"])
        XCTAssertTrue(ids.contains("project.summary") && ids.contains("resources.files") && ids.contains("resources.summary"))
        XCTAssertEqual(Array(ids.suffix(1)), ["soon.deliver"], "blocks not built yet plug in as coming soon")
        XCTAssertFalse(ids.contains("soon.look"), "the look block is built: its steps are real")
        XCTAssertTrue(steps.filter { !$0.isBuilt }.allSatisfy { $0.id.hasPrefix("soon.") })
        XCTAssertTrue(steps.prefix(3).allSatisfy { !$0.title.isEmpty && !$0.help.isEmpty }, "every step has the question as its title and a help")
        XCTAssertEqual(steps[0].title, "Which language should we use together for this project?")
    }

    func testChoicesAreOfferedWithRecommendationsButNeverPreRecorded() throws {
        try store.create(name: "C", conversationLanguage: nil, reelLanguages: [])
        let s = Wizard.steps(assets: [], spec: spec, systemLanguage: "fr")
        guard case .single(_, let opts, let rec, _) = s[0].kind else { return XCTFail() }
        XCTAssertTrue(opts.count >= 5); XCTAssertEqual(rec, "fr", "the recommendation follows the system language")
        guard case .multi(_, _, let recLangs) = s[1].kind else { return XCTFail() }
        XCTAssertEqual(recLangs, ["en"], "English by default, as the skill says")
        guard case .multi(_, _, let recFormats) = s[6].kind else { return XCTFail() }
        XCTAssertEqual(recFormats, ["16:9"])
        guard case .number(_, let presets) = s[5].kind else { return XCTFail() }
        XCTAssertEqual(presets.map { $0.value }, ["30", "60", "90"])
        // looking at the steps wrote nothing, and nothing counts as decided
        let f = try XCTUnwrap(store.loadShowreel())
        XCTAssertNil(f.conversationLanguage); XCTAssertTrue(f.reelLanguages.isEmpty); XCTAssertNil(f.decisions.duration); XCTAssertNil(f.decisions.formats)
        XCTAssertEqual(Wizard.steps(assets: [], spec: spec, systemLanguage: "zz").first.flatMap { s -> String? in
            if case .single(_, _, let r, _) = s.kind { return r }; return nil }, nil, "no recommendation for a language that is not offered")
    }

    func testAnswersAreTheTypedOperationsOfTheBlocksAndTheWizardResumes() throws {
        try store.create(name: "W", conversationLanguage: nil, reelLanguages: [])
        XCTAssertEqual(resume(), "project.conversationLanguage")
        try store.apply(.parameter(.conversationLanguage, "fr"))          // the same operation as the block's picker
        XCTAssertEqual(resume(), "project.reelLanguages")
        XCTAssertTrue(decided(steps[0]))
        // "Decide later" writes nothing: the wizard comes back to the same step
        XCTAssertEqual(resume(), "project.reelLanguages")
        try store.apply(.parameter(.reelLanguages, "en, fr"))
        try store.apply(.parameter(.audience, "Teams"))
        XCTAssertEqual(resume(), "project.message")
        // a value entered in Expert mode counts: the wizard resumes after it
        try store.apply(.parameter(.message, "Calm notes"))
        try store.apply(.parameter(.tone, "warm"))
        XCTAssertEqual(resume(), "project.duration")
        // an optional question answered "nothing special" is settled without a value
        try store.apply(.parameter(.duration, "45")); try store.apply(.parameter(.formats, "16:9"))
        XCTAssertEqual(resume(), "project.constraints")
        store.markDecided("project.constraints")
        XCTAssertNil(store.loadShowreel()?.parameters.constraints, "no value was invented")
        XCTAssertEqual(resume(), "project.summary")
        try store.apply(.gate("interview", passed: true))
        XCTAssertEqual(resume(), "resources.files")
    }

    func testAssetStepsFollowTheManifestAndOnlyAChoiceDecidesThem() throws {
        try store.create(name: "Assets", conversationLanguage: nil, reelLanguages: [])
        let inbox = makeTempDir("inbox-wiz"); defer { try? FileManager.default.removeItem(at: inbox) }
        let logo = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: logo, atomically: true, encoding: .utf8)
        let doc = inbox.appendingPathComponent("brand-guide.pdf"); try "x".write(to: doc, atomically: true, encoding: .utf8)
        let shot = inbox.appendingPathComponent("app-home.png"); try "x".write(to: shot, atomically: true, encoding: .utf8)
        try Assets.add([logo, doc, shot], to: store)
        let assetSteps = steps.filter { $0.id.hasPrefix("resources.asset.") }.map { $0.id }
        XCTAssertEqual(assetSteps, ["resources.asset.logo-01", "resources.asset.shot-01"], "a listed document needs no decision")
        let step = try XCTUnwrap(steps.first { $0.id == "resources.asset.logo-01" })
        _ = try store.apply(.asset(id: "logo-01", status: .proposed, note: nil, licence: nil, scenes: nil))
        XCTAssertFalse(decided(step), "a proposed asset is not decided: nothing is pre-accepted")
        _ = try? store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil))
        XCTAssertTrue(decided(step))
        try store.apply(.asset(id: "shot-01", status: .hold, note: "waiting for a better capture", licence: nil, scenes: nil))
        XCTAssertFalse(decided(try XCTUnwrap(steps.first { $0.id == "resources.asset.shot-01" })), "a hold is still open")
        XCTAssertTrue(decided(try XCTUnwrap(steps.first { $0.id == "resources.files" })))
    }

    func testProgressCountsBuiltStepsOnly() throws {
        try store.create(name: "Prog", conversationLanguage: nil, reelLanguages: [])
        var p = Wizard.progress(steps, file: store.loadShowreel(), assets: [], settings: store.settings, spec: spec)
        XCTAssertEqual(p.decided, 0)
        XCTAssertEqual(p.total, steps.filter { $0.isBuilt }.count)
        XCTAssertFalse(steps.filter { !$0.isBuilt }.isEmpty)
        try store.apply(.parameter(.audience, "Teams"))
        p = Wizard.progress(steps, file: store.loadShowreel(), assets: [], settings: store.settings, spec: spec)
        XCTAssertEqual(p.decided, 1)
    }

    func testSuggestWithAIAsksForACardNotAWrite() throws {
        try store.create(name: "AI", conversationLanguage: nil, reelLanguages: [])
        let tone = try XCTUnwrap(steps.first { $0.id == "project.tone" })
        let prompt = Wizard.suggestionPrompt(tone)
        XCTAssertTrue(prompt.contains(tone.title) && prompt.contains("update_parameter") && prompt.contains("key tone") && prompt.contains("accept or refuse"))
        let asset = Wizard.suggestionPrompt(WizardStep(id: "resources.asset.logo-01", area: "resources", title: "Use x?", help: "", kind: .asset("logo-01")))
        XCTAssertTrue(asset.contains("Do not change it"))
        for s in steps { XCTAssertFalse(Wizard.suggestionPrompt(s).isEmpty, s.id) }
    }
}

final class ProcessAndVersionTests: XCTestCase {
    func testEveryBlockHasAnAIFieldAndOnlyBuildRequiresGeneration() throws {
        let spec = try XCTUnwrap(ProcessSpec.load())
        XCTAssertTrue(spec.blocks.allSatisfy { ["none", "optional", "required"].contains($0.ai) })
        XCTAssertEqual(spec.blocks.filter { $0.ai == "required" }.map { $0.id }, ["build"])
        XCTAssertEqual(spec.block("build")?.built, true, "the build block exists; without a key it explains what it needs")
        XCTAssertEqual(spec.block("deliver")?.ai, "none")
    }

    func testSkillVersionIsReadAndAgreesWithTheRelease() throws {
        let v = try XCTUnwrap(Skill.version())
        XCTAssertNotNil(v.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression))
        let root = try XCTUnwrap(Skill.root())
        let md = try String(contentsOf: root.appendingPathComponent("SKILL.md"), encoding: .utf8)
        XCTAssertTrue(md.contains("version: \"\(v)\""), "the version is the one in SKILL.md")
        let repo = root.deletingLastPathComponent()
        let log = try String(contentsOf: repo.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
        XCTAssertTrue(log.contains("## \(v) "), "and the one at the top of the changelog")
        let rel = try JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("tools/released.json"))) as? [String: String]
        XCTAssertEqual(rel?["version"], v)
    }
}
