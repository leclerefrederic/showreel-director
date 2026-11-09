import XCTest
@testable import ShowreelKit

/// P5: the mode chosen at creation (and the migration of the old words), the Wizard card without a key, the progress of the base configuration, the interview gate derived,
/// the starting pack (all cards, one, none), and a wizard that cannot go on.
final class SetupFlowTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("setupflow"); store = ProjectStore(root: dir)
        try? store.create(name: "Su", conversationLanguage: nil, reelLanguages: [], mode: StudioSettings.wizard)
        store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }

    // MARK: the mode

    func testTheModeIsChosenOnceAtCreationAndTheOldWordsAreRead() throws {
        XCTAssertEqual(store.settings.mode, "wizard")
        let d = makeTempDir("setupflow2"); defer { try? FileManager.default.removeItem(at: d) }
        let m = ProjectStore(root: d); try m.create(name: "M", conversationLanguage: nil, reelLanguages: [], mode: StudioSettings.manual)
        XCTAssertEqual(m.settings.mode, "manual"); XCTAssertTrue(m.needsSetup)
        let defaultMode = ProjectStore(root: makeTempDir("setupflow3")); try defaultMode.create(name: "D", conversationLanguage: nil, reelLanguages: [])
        XCTAssertEqual(defaultMode.settings.mode, "wizard", "Wizard is the default")
        // the older words: beginner is wizard, expert is manual, and an unknown one is manual
        for (old, new) in [("beginner", "wizard"), ("expert", "manual"), ("wizard", "wizard"), ("manual", "manual"), ("nonsense", "manual")] {
            let s = try JSONDecoder().decode(StudioSettings.self, from: Data("{\"mode\":\"\(old)\"}".utf8)); XCTAssertEqual(s.mode, new, old)
        }
        // an old ui.json on disk: the setting migrates, the project file is not touched and keeps its format revision
        try FileManager.default.createDirectory(at: d.appendingPathComponent(".studio"), withIntermediateDirectories: true)
        try #"{"mode": "beginner", "setupRequired": true}"#.write(to: d.appendingPathComponent(".studio/ui.json"), atomically: true, encoding: .utf8)
        let before = try Data(contentsOf: d.appendingPathComponent("showreel.json"))
        XCTAssertEqual(ProjectStore(root: d).settings.mode, "wizard")
        XCTAssertEqual(try Data(contentsOf: d.appendingPathComponent("showreel.json")), before, "reading the setting writes nothing in the project")
        XCTAssertNil(ProjectFormat.plan(m), "Update project has nothing to list: the mode never was in showreel.json")
        XCTAssertEqual(m.loadShowreel()?.formatRevision, ShowreelFile.currentRevision)
        var s2 = m.settings; s2.mode = "wizard"; m.settings = s2
        XCTAssertTrue(try XCTUnwrap(m.read(".studio/ui.json")).contains("\"wizard\""), "written with the new word")
    }

    func testTheWizardNeedsAKeyAndSaysSoWithTheWayOut() {
        XCTAssertEqual(Availability.wizard(hasKey: true), .available)
        let u = Availability.wizard(hasKey: false).why
        XCTAssertEqual(u?.reason, "Wizard needs an API key"); XCTAssertEqual(u?.cause, .noKey); XCTAssertEqual(u?.link, .key)
        XCTAssertEqual(u?.way, "Open Settings to connect one (Command-,), or choose Manual")
    }

    // MARK: the base configuration

    func testTheProgressOfTheBaseConfigurationField1by1() throws {
        func line() -> String { ProjectSetup.progress(file).line }
        XCTAssertEqual(line(), "0 of 5 set"); XCTAssertEqual(ProjectSetup.requirements(file).map { $0.id }, ["conversationLanguage", "reelLanguages", "formats", "duration", "look"])
        try store.apply(.parameter(.conversationLanguage, "en")); XCTAssertEqual(line(), "1 of 5 set")
        try store.apply(.parameter(.reelLanguages, "en, fr")); XCTAssertEqual(line(), "2 of 5 set")
        try store.apply(.parameter(.formats, "16:9")); XCTAssertEqual(line(), "3 of 5 set")
        try store.apply(.parameter(.duration, "30")); XCTAssertEqual(line(), "4 of 5 set"); XCTAssertFalse(ProjectSetup.isComplete(file))
        // the look is one of the five, set only when its palette, fonts and background all are
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil)); XCTAssertEqual(line(), "4 of 5 set")
        try store.apply(.decisions([DecisionChange(.titleFont, "Fredoka"), DecisionChange(.textFont, "Nunito")], title: nil)); XCTAssertEqual(line(), "4 of 5 set")
        try store.apply(.decisions([DecisionChange(.background, Look.backgroundIDs().first!)], title: nil)); XCTAssertEqual(line(), "5 of 5 set"); XCTAssertTrue(ProjectSetup.isComplete(file))
        XCTAssertTrue(ProjectSetup.requirements(file).allSatisfy { $0.isSet })
        // optional parts never count
        XCTAssertEqual(ProjectSetup.optional, ["audience", "message", "tone"])
    }

    func complete() throws {
        try store.apply(.parameter(.conversationLanguage, "en")); try store.apply(.parameter(.reelLanguages, "en")); try store.apply(.parameter(.formats, "16:9")); try store.apply(.parameter(.duration, "30"))
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2"), DecisionChange(.titleFont, "Fredoka"), DecisionChange(.textFont, "Nunito"), DecisionChange(.background, Look.backgroundIDs().first!)], title: nil))
    }

    func testTheWorkspaceOpensOnlyWhenTheBaseIsCompleteAndTheInterviewGateFollowsWithoutAButton() throws {
        XCTAssertTrue(store.needsSetup); XCTAssertThrowsError(try store.finishSetup()) { XCTAssertTrue($0.localizedDescription.contains("still needs")) }
        XCTAssertEqual(file.gateState("interview"), "open"); XCTAssertNil(file.gates["interview"])
        try complete()
        XCTAssertEqual(file.gateState("interview"), "passed", "derived from the base configuration, no one pressed anything")
        XCTAssertEqual(file.gates["interview"], "passed", "and written, so that what reads the file sees it")
        XCTAssertTrue(store.read("brief.md")?.contains("interview: passed") == true, "the brief says it too")
        XCTAssertNoThrow(try store.finishSetup()); XCTAssertFalse(store.needsSetup)
        // a gate that an older project already had stays passed
        let d = makeTempDir("setupflow4"); defer { try? FileManager.default.removeItem(at: d) }
        let old = ProjectStore(root: d); try old.create(name: "O", conversationLanguage: nil, reelLanguages: [])
        var f = old.loadShowreel()!; f.gates["interview"] = "passed"; try old.save(f)
        XCTAssertEqual(old.loadShowreel()?.gateState("interview"), "passed", "nothing a project had is taken away")
        // the readers of the gates (the block's status, the checks) use the derived state
        XCTAssertEqual(Checks.run(area: "project", store: store).filter { $0.id.hasPrefix("project.gate") || $0.title.lowercased().contains("interview") }.allSatisfy { $0.level == .ok }, true)
    }

    func testTheDurationHintFollowsTheFeasibilityRules() throws {
        XCTAssertNil(ProjectSetup.durationHint(file))
        try store.apply(.parameter(.duration, "30"))
        let h = try XCTUnwrap(ProjectSetup.durationHint(file)); XCTAssertFalse(h.text.isEmpty)
        for n in [1, 3] { try store.apply(.addScene(id: "", SceneEdit(duration: "0.2", text: "word \(n)"))) }
        XCTAssertNotNil(ProjectSetup.durationHint(file))
    }

    func testLanguagesByCode() {
        XCTAssertEqual(ProjectLanguages.name("fr"), "French"); XCTAssertEqual(ProjectLanguages.code(forName: "german"), "de"); XCTAssertEqual(ProjectLanguages.code(forName: "en"), "en"); XCTAssertNil(ProjectLanguages.code(forName: "Klingon"))
        XCTAssertEqual(ProjectLanguages.name("xx"), "xx")
    }

    // MARK: the interview and the starting pack

    func pack() -> [String: Any] {
        ["base": ["conversationLanguage": "en", "reelLanguages": "en, fr", "formats": "16:9, 9:16", "duration": "30"], "brief": ["audience": "Teams", "tone": "Warm"],
         "look": ["palette": "#101820, #FFFFFF, #F2AA4C, #4CC2F2", "titleFont": "Fredoka", "textFont": "Nunito", "background": Look.backgroundIDs().first!],
         "scenes": [["text": "Hello", "duration": "4"], ["text": "How it works", "duration": "6", "feeling": "calm"], ["text": "Try it", "duration": 5]]]
    }

    func testTheInterviewQuestionsAreFixedAndTheirAnswersBecomeTypedChanges() throws {
        XCTAssertEqual(WizardInterview.questions.map { $0["header"] as? String }, WizardInterview.headers)
        let p = WizardInterview.prompt(projectName: "Reel", conversationLanguage: nil)
        for needle in ["ask_user ONCE", "propose_starter_pack", "Conversation language", "nothing is saved until they accept", "Do not change anything with any other tool", "Reel"] { XCTAssertTrue(p.contains(needle), needle) }
        let ops = WizardInterview.operations(from: ["Conversation language": "French", "Film language": "French, English", "Formats": "Desktop 16:9, Mobile 9:16", "Duration": "45 s", "About the film": "Skip"], file: file)
        XCTAssertEqual(ops, [.parameter(.conversationLanguage, "fr"), .parameter(.reelLanguages, "fr, en"), .parameter(.formats, "16:9, 9:16"), .parameter(.duration, "45")])
        XCTAssertTrue(WizardInterview.operations(from: ["Duration": "a while", "Formats": "huge"], file: file).isEmpty, "only what is understood, never a guess")
    }

    func testTheStarterPackIsFewCardsAndAcceptingAllOneOrNone() async throws {
        let cards = try StarterPack.cards(pack(), store: store)
        XCTAssertEqual(cards.map { $0.id }, ["base", "look", "scenes"]); XCTAssertEqual(cards.map { $0.card.title }, ["Base configuration", "Look", "Scenes and their order (3)"])
        XCTAssertTrue(cards[0].card.changes.contains { $0.label == "Audience" }, "the optional brief rides on the base card"); XCTAssertEqual(cards[2].card.changes.count, 3)
        XCTAssertEqual(file.scenes.count, 0, "nothing is saved by building the cards")
        // all accepted, through Clap's tool with the proposals answered together
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let all = await tools.run("propose_starter_pack", pack()).text
        XCTAssertTrue(all.hasPrefix("accepted and applied: Base configuration, Look, Scenes and their order (3)"), all)
        XCTAssertEqual(ui.cards.count, 3, "three cards, proposed at once"); XCTAssertEqual(file.scenes.map { $0.text }, ["Hello", "How it works", "Try it"])
        XCTAssertTrue(ProjectSetup.isComplete(file)); XCTAssertEqual(file.gateState("interview"), "passed"); XCTAssertEqual(file.reelLanguages, ["en", "fr"])
        XCTAssertEqual(store.journal.entries().filter { $0.author == "clap" && $0.state == "applied" }.count >= 3, true, "each operation is in the journal")
        try tools.store.undo(); XCTAssertTrue(file.scenes.isEmpty, "the scenes card was one undo step"); XCTAssertTrue(ProjectSetup.isComplete(file), "the other cards stay")
    }

    func testAcceptingOnlyOneCardAndRefusingAllSaveWhatTheyShould() async throws {
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        ui.accept = false
        let none = await tools.run("propose_starter_pack", pack()).text
        XCTAssertTrue(none.hasPrefix("nothing was saved") && none.contains("Refused by the user"), none)
        XCTAssertTrue(file.scenes.isEmpty); XCTAssertNil(file.decisions.palette); XCTAssertEqual(file.reelLanguages, []); XCTAssertEqual(ProjectSetup.progress(file).line, "0 of 5 set")
        XCTAssertEqual(store.journal.entries().filter { $0.state == "refused" }.count, 3, "each refused card is in the journal")
        // one card only: the answers per card
        final class OnlyLook: AgentUI, @unchecked Sendable {
            var accepted: [String] = []
            func text(_ t: String) {}; func endText() {}; func tool(_ n: String, _ i: [String: Any]) {}; func show(_ u: String, _ t: String) {}
            func screenshot(javascript: String?, waitMs: Int) async -> Data? { nil }; func ask(_ q: [[String: Any]]) async -> [String] { [] }
            func proposeOperation(_ card: OperationCard) async -> Bool { if card.title == "Look" { accepted.append(card.title); return true }; return false }
        }
        let ui2 = OnlyLook(); let t2 = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui2)
        let one = await t2.run("propose_starter_pack", pack()).text
        XCTAssertTrue(one.hasPrefix("accepted and applied: Look"), one)
        XCTAssertEqual(file.decisions.palette?.count, 4); XCTAssertTrue(file.scenes.isEmpty); XCTAssertEqual(file.reelLanguages, [])
        XCTAssertEqual(ProjectSetup.progress(file).line, "1 of 5 set"); XCTAssertThrowsError(try store.finishSetup(), "the workspace stays closed while the base is incomplete")
    }

    func testABadValueIsAnErrorToClapNeverABrokenCardAndTheFreezeApplies() async throws {
        var bad = pack(); bad["look"] = ["palette": "red, blue"]
        XCTAssertThrowsError(try StarterPack.cards(bad, store: store)) { XCTAssertTrue($0.localizedDescription.contains("not a #RRGGBB")) }
        XCTAssertThrowsError(try StarterPack.cards([:], store: store)); XCTAssertThrowsError(try StarterPack.cards(["scenes": [["duration": "3"]]], store: store))
        XCTAssertThrowsError(try StarterPack.cards(["music": "audio-99"], store: store))
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        let frozen = await tools.run("propose_starter_pack", pack()).text
        XCTAssertTrue(frozen.hasPrefix("refused:") && frozen.contains("Building the film"), frozen); XCTAssertTrue(ui.cards.isEmpty)
        store.activity.reset()
        XCTAssertTrue(Tools.definitions.contains { ($0["name"] as? String) == "propose_starter_pack" })
    }

    func testAWizardThatCannotGoOnKeepsTheAnswersAndTheWayToManual() throws {
        // the answers given before the failure become typed changes (journalled, undoable), the base is then what the answers say
        let answers = ["Conversation language": "English", "Film language": "English, French", "Formats": "Desktop 16:9", "Duration": "30 s"]
        for op in WizardInterview.operations(from: answers, file: file) { try store.apply(op) }
        XCTAssertEqual(ProjectSetup.progress(file).line, "4 of 5 set", "four answers, the look is still to choose in the form")
        XCTAssertEqual(file.reelLanguages, ["en", "fr"]); XCTAssertEqual(file.decisions.duration, 30)
        var s = store.settings; s.mode = StudioSettings.manual; store.settings = s     // the way out
        XCTAssertEqual(ProjectStore(root: dir).settings.mode, "manual"); XCTAssertTrue(ProjectStore(root: dir).needsSetup, "the workspace stays closed")
        XCTAssertEqual(store.journal.entries().filter { $0.op == "parameter" }.count, 4)
        try store.undo(); XCTAssertEqual(ProjectSetup.progress(file).line, "3 of 5 set")
    }
}
