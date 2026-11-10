import XCTest
@testable import ShowreelKit

/// Phase CL1: the conversation language comes from the Mac and is no longer a question.
final class CL1Tests: XCTestCase {
    var dir: URL!
    override func setUp() { dir = makeTempDir("cl1") }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    var shared: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("shared") }

    func testTheMacsLanguageMapsToTheFirstSupportedOne() {
        XCTAssertEqual(ProjectLanguages.system(preferred: ["fr-FR", "en-US"]), "fr", "a French Mac gives French")
        XCTAssertEqual(ProjectLanguages.system(preferred: ["ja-JP", "zh-Hans"]), "en", "an unsupported language gives English")
        XCTAssertEqual(ProjectLanguages.system(preferred: ["ja-JP", "de-DE", "fr"]), "de", "the first supported one wins")
        XCTAssertEqual(ProjectLanguages.system(preferred: []), "en", "an empty list gives English")
        XCTAssertEqual(ProjectLanguages.system(preferred: ["pt_BR"]), "pt"); XCTAssertEqual(ProjectLanguages.system(preferred: ["ES-mx"]), "es")
        for l in ProjectLanguages.all { XCTAssertEqual(ProjectLanguages.system(preferred: [l.code]), l.code, "every language of the picker is supported") }
    }

    func testANewProjectStoresTheMappedLanguageOnceAndSaysWhereItCameFrom() throws {
        let s = ProjectStore(root: dir)
        let f = try s.create(name: "P", conversationLanguage: nil, reelLanguages: [], preferredLanguages: ["fr-FR"])
        XCTAssertEqual(f.conversationLanguage, "fr"); XCTAssertEqual(f.conversationLanguageSource, "system"); XCTAssertEqual(ConversationLanguage.origin(s.loadShowreel()), "From your Mac")
        XCTAssertEqual(ProjectStore(root: dir).loadShowreel()?.conversationLanguage, "fr", "stored in the project: reading it again does not ask the Mac")
        // a language given on purpose is kept as it is
        let d2 = makeTempDir("cl1b"); defer { try? FileManager.default.removeItem(at: d2) }
        let g = try ProjectStore(root: d2).create(name: "Q", conversationLanguage: "de", reelLanguages: [], preferredLanguages: ["fr"])
        XCTAssertEqual(g.conversationLanguage, "de"); XCTAssertNil(g.conversationLanguageSource)
    }

    func testAnExistingProjectIsNeverChanged() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let raw = #"{"schema": 1, "name": "Old", "conversationLanguage": "es"}"#
        try raw.write(to: dir.appendingPathComponent(ShowreelFile.fileName), atomically: true, encoding: .utf8)
        let s = ProjectStore(root: dir)
        let f = try XCTUnwrap(s.loadShowreel())
        XCTAssertEqual(f.conversationLanguage, "es"); XCTAssertNil(f.conversationLanguageSource); XCTAssertEqual(ConversationLanguage.origin(f), "Kept from before")
        XCTAssertEqual(s.read(ShowreelFile.fileName), raw, "reading it writes nothing")
        var old = f; old.conversationLanguage = nil
        XCTAssertEqual(ConversationLanguage.origin(old), "Not set", "a project with none keeps none: nothing fills it in")
    }

    func testTheBaseConfigurationIsFourItemsAndTheLanguageNeverWaitsForIt() throws {
        let s = ProjectStore(root: dir)
        var f = try s.create(name: "P", conversationLanguage: "en", reelLanguages: [])
        f.conversationLanguage = nil; try s.save(f)
        XCTAssertEqual(ProjectSetup.requirements(f).map { $0.id }, ["reelLanguages", "formats", "duration", "look"])
        XCTAssertEqual(ProjectSetup.progress(f).line, "0 of 4 set"); XCTAssertFalse(ProjectSetup.missing(f).contains { $0.id == "conversationLanguage" })
        try s.apply(.parameter(.reelLanguages, "en")); try s.apply(.parameter(.formats, "16:9")); try s.apply(.parameter(.duration, "30"))
        try s.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2"), DecisionChange(.titleFont, "Fredoka"), DecisionChange(.textFont, "Nunito"), DecisionChange(.background, Look.backgroundIDs().first!)], title: nil))
        let g = try XCTUnwrap(s.loadShowreel())
        XCTAssertNil(g.conversationLanguage); XCTAssertTrue(ProjectSetup.isComplete(g), "complete with no conversation language"); XCTAssertEqual(ProjectSetup.progress(g).line, "4 of 4 set")
        XCTAssertNoThrow(try s.finishSetup(), "the workspace-opening rule does not wait for it")
    }

    func testTheWizardNoLongerAsksItAndItsPromptSaysSo() throws {
        let s = ProjectStore(root: dir); try s.create(name: "P", conversationLanguage: nil, reelLanguages: [], preferredLanguages: ["fr"])
        let steps = Wizard.steps(assets: [], spec: ProcessSpec.load())
        XCTAssertFalse(steps.contains { $0.id == "project.conversationLanguage" }); XCTAssertEqual(steps.first?.id, "project.reelLanguages", "one step fewer")
        XCTAssertEqual(WizardInterview.headers, ["Film language", "Formats", "Duration", "About the film"]); XCTAssertEqual(WizardInterview.questions.count, 4)
        XCTAssertFalse(WizardInterview.questions.contains { ($0["question"] as? String)?.contains("talk in") == true })
        let p = WizardInterview.prompt(projectName: "Reel", conversationLanguage: "fr")
        XCTAssertTrue(p.contains("Never ask which language to talk in") && p.contains("French") && p.contains("from the user's Mac"), "Clap's first message is in the stored language")
        XCTAssertFalse(p.contains("`base` (conversationLanguage"))
    }

    func testTheCollapsedControlIsNotAmongTheRequiredFieldsAndChangingItIsJournalledAndUndoable() throws {
        let form = try String(contentsOf: views.appendingPathComponent("ProjectFormViews.swift"), encoding: .utf8)
        XCTAssertFalse(form.contains("Conversation language") || form.contains("moreArea") || form.contains("DisclosureGroup"), "PT1: the interface offers no conversation language")
        let s = ProjectStore(root: dir); try s.create(name: "P", conversationLanguage: nil, reelLanguages: [], preferredLanguages: ["fr"])
        s.undoLog.clear()
        try s.apply(.parameter(.conversationLanguage, "de"))
        var f = try XCTUnwrap(s.loadShowreel())
        XCTAssertEqual(f.conversationLanguage, "de"); XCTAssertEqual(ConversationLanguage.origin(f), "Set by you")
        let j = try XCTUnwrap(s.journal.entries().last); XCTAssertEqual(j.op, "parameter"); XCTAssertEqual(j.author, "user")
        try s.undo()
        f = try XCTUnwrap(s.loadShowreel())
        XCTAssertEqual(f.conversationLanguage, "fr"); XCTAssertEqual(ConversationLanguage.origin(f), "From your Mac", "Undo brings back the value and its origin")
    }

    func testTheAddendumCarriesTheInstructionAndTheSharedFilesAgree() throws {
        let add = try String(contentsOf: shared.appendingPathComponent("addendum.md"), encoding: .utf8)
        for needle in ["settled by the app, never asked", "Reply in the language the user writes in", "use the project's stored language for your very first message", "never ask which language to talk in", "on-screen languages are a different question and are still asked", "Ask the four setup questions"] {
            XCTAssertTrue(add.contains(needle), needle)
        }
        let caps = try String(contentsOf: shared.appendingPathComponent("capabilities.json"), encoding: .utf8)
        XCTAssertTrue(caps.contains("the conversation language is the Mac's") && !caps.contains("n of 5 set") && !caps.contains("(conversation and reel languages"))
        let tools = try String(contentsOf: shared.appendingPathComponent("tools.json"), encoding: .utf8)
        XCTAssertFalse(tools.contains("\"conversationLanguage\": {"), "the starting pack no longer carries it")
    }
}
