import XCTest
@testable import ShowreelKit

/// A UI with no window. Records what the agent showed and answers proposals as scripted.
final class ScriptedUI: AgentUI, @unchecked Sendable {
    var accept = true
    var foreground: String? = "storyboard.md"
    private(set) var texts: [String] = []
    private(set) var tools: [String] = []
    private(set) var proposals: [Proposal] = []
    private(set) var cards: [OperationCard] = []
    private let cardLock = NSLock()
    private(set) var openedBlocks: [String] = []
    var block: String? = "project"
    /// Called when a proposal is shown, before the answer: lets a test change the file in between.
    var beforeAnswer: (() -> Void)?
    /// Called when the agent announces a tool, before it runs.
    var onTool: (() -> Void)?

    func text(_ t: String) { texts.append(t) }
    func endText() {}
    func tool(_ name: String, _ input: [String: Any]) { tools.append(name); onTool?() }
    func show(_ url: String, _ title: String) {}
    func screenshot(javascript: String?, waitMs: Int) async -> Data? { nil }
    func ask(_ questions: [[String: Any]]) async -> [String] { [] }
    func propose(_ p: Proposal) async -> Bool { proposals.append(p); beforeAnswer?(); return accept }
    func proposeOperation(_ card: OperationCard) async -> Bool { cardLock.lock(); cards.append(card); cardLock.unlock(); beforeAnswer?(); return accept }
    func foregroundBlock() async -> String? { block }
    func openBlock(_ id: String) async { openedBlocks.append(id) }
    func foregroundFile() async -> String? { foreground }
}

/// A model that replays a script: each call returns the next scripted turn and records what it was sent.
final class ScriptedTransport: MessagesTransport {
    var script: [(content: [[String: Any]], stop: String)]
    private(set) var received: [[[String: Any]]] = []
    init(_ script: [(content: [[String: Any]], stop: String)]) { self.script = script }

    func stream(system: [[String: Any]], tools: [[String: Any]], messages: [[String: Any]],
                onText: (String) -> Void) async throws -> (content: [[String: Any]], stop: String) {
        received.append(messages)
        guard !script.isEmpty else { throw AgentError.msg("script exhausted") }
        let turn = script.removeFirst()
        for b in turn.content where (b["type"] as? String) == "text" { onText(b["text"] as? String ?? "") }
        return turn
    }
}

func toolUse(_ id: String, _ name: String, _ input: [String: Any]) -> [String: Any] {
    ["type": "tool_use", "id": id, "name": name, "input": input]
}
func textBlock(_ t: String) -> [String: Any] { ["type": "text", "text": t] }

final class ToolsTests: XCTestCase {
    var dir: URL!
    var ui: ScriptedUI!
    var tools: Tools!
    var store: ProjectStore!

    override func setUpWithError() throws {
        dir = makeTempDir("tools")
        ui = ScriptedUI()
        let skill = try XCTUnwrap(Skill.root(), "the skill folder is found from the source tree")
        tools = Tools(project: dir, skill: skill, ui: ui)
        store = ProjectStore(root: dir)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func run(_ name: String, _ input: [String: Any]) async -> String { await tools.run(name, input).text }

    func testGetStateReturnsShowreelAndForeground() async throws {
        let none = await run("get_state", [:])
        XCTAssertTrue(none.contains("no readable showreel.json"))
        try store.create(name: "State", conversationLanguage: "en", reelLanguages: ["en"])
        let out = await run("get_state", [:])
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any])
        XCTAssertEqual((o["showreel"] as? [String: Any])?["name"] as? String, "State")
        XCTAssertEqual(o["foregroundFile"] as? String, "storyboard.md")
        XCTAssertEqual(o["applyDirectly"] as? Bool, false)
        XCTAssertTrue((o["files"] as? [String] ?? []).contains("brief.md"))
    }

    func testRefusedProposalLeavesTheFile() async throws {
        try store.write("brief.md", "old\n")
        ui.accept = false
        let r = await run("propose_edit", ["file": "brief.md", "content": "new\n", "note": "shorter"])
        XCTAssertTrue(r.hasPrefix("refused by the user"))
        XCTAssertEqual(store.read("brief.md"), "old\n")
        XCTAssertEqual(ui.proposals.first?.note, "shorter")
        XCTAssertEqual(ui.proposals.first?.original, "old\n")
    }

    func testAcceptedProposalIsWrittenAndKeptInHistory() async throws {
        try store.write("brief.md", "old\n")
        let r = await run("propose_edit", ["file": "brief.md", "content": "new\n"])
        XCTAssertTrue(r.hasPrefix("accepted and applied"))
        XCTAssertEqual(store.read("brief.md"), "new\n")
        XCTAssertEqual(store.snapshots("brief.md").count, 1)
    }

    func testProposalForANewFileHasNoOriginal() async {
        let r = await run("propose_edit", ["file": "storyboard.md", "content": "# S\n"])
        XCTAssertTrue(r.hasPrefix("accepted"))
        XCTAssertNil(ui.proposals.first?.original)
    }

    func testProposalIsNotAppliedWhenTheFileChangedMeanwhile() async throws {
        try store.write("brief.md", "old\n")
        ui.beforeAnswer = { try? "edited by the user\n".write(to: self.dir.appendingPathComponent("brief.md"), atomically: true, encoding: .utf8) }
        let r = await run("propose_edit", ["file": "brief.md", "content": "new\n"])
        XCTAssertTrue(r.hasPrefix("not applied"), r)
        XCTAssertEqual(store.read("brief.md"), "edited by the user\n", "the user's version is never overwritten")
    }

    func testApplyDirectlySkipsTheProposal() async throws {
        try store.write("brief.md", "old\n")
        store.settings = StudioSettings(applyDirectly: true)
        let r = await run("propose_edit", ["file": "brief.md", "content": "new\n"])
        XCTAssertTrue(r.hasPrefix("applied directly"))
        XCTAssertTrue(ui.proposals.isEmpty)
        XCTAssertEqual(store.read("brief.md"), "new\n")
        XCTAssertEqual(store.snapshots("brief.md").count, 1, "direct writes are still in the history")
    }

    func testWriteFileOnAnExistingProseFileBecomesAProposal() async throws {
        try store.write("brief.md", "old\n")
        ui.accept = false
        let r = await run("write_file", ["path": "brief.md", "content": "new\n"])
        XCTAssertTrue(r.hasPrefix("refused by the user"))
        XCTAssertEqual(store.read("brief.md"), "old\n")
        XCTAssertEqual(ui.proposals.count, 1)
    }

    func testWriteFileToANewFileOrAScriptIsDirect() async throws {
        let a = await run("write_file", ["path": "notes.md", "content": "n\n"])
        let b = await run("write_file", ["path": "v1/main.js", "content": "//\n"])
        XCTAssertTrue(a.hasPrefix("wrote") && b.hasPrefix("wrote"))
        try store.write("v1/main.js", "// old\n")
        let c = await run("write_file", ["path": "v1/main.js", "content": "// new\n"])
        XCTAssertTrue(c.hasPrefix("wrote"), "code files are not reviewed")
        XCTAssertTrue(ui.proposals.isEmpty)
    }

    func testWritesRefuseToLeaveTheProjectOrEnterStudio() async {
        let a = await run("write_file", ["path": "../escape.txt", "content": "no"])
        let b = await run("write_file", ["path": ".studio/ui.json", "content": "no"])
        let c = await run("propose_edit", ["file": "../escape.md", "content": "no"])
        XCTAssertTrue(a.hasPrefix("refused") && b.hasPrefix("refused") && c.hasPrefix("refused"))
        XCTAssertTrue(ui.proposals.isEmpty)
    }

    func testIdenticalContentIsNotProposed() async throws {
        try store.write("brief.md", "same\n")
        let r = await run("propose_edit", ["file": "brief.md", "content": "same\n"])
        XCTAssertTrue(r.hasPrefix("no change"))
        XCTAssertTrue(ui.proposals.isEmpty)
    }
}

final class OperationToolTests: XCTestCase {
    var dir: URL!
    var ui: ScriptedUI!
    var tools: Tools!
    var store: ProjectStore!

    override func setUpWithError() throws {
        dir = makeTempDir("optools")
        ui = ScriptedUI()
        tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        store = ProjectStore(root: dir)
        try store.create(name: "Ops", conversationLanguage: "en", reelLanguages: ["en"])
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func run(_ name: String, _ input: [String: Any]) async -> String { await tools.run(name, input).text }

    func testUpdateParameterShowsAPlainCardAndAppliesOnAccept() async throws {
        let r = await run("update_parameter", ["key": "audience", "value": "Product teams"])
        XCTAssertTrue(r.hasPrefix("accepted and applied"), r)
        XCTAssertEqual(ui.cards.first?.title, "Set audience")
        XCTAssertEqual(ui.cards.first?.changes, [Change("Audience", "(empty)", "Product teams")])
        XCTAssertEqual(store.loadShowreel()?.parameters.audience, "Product teams")
        XCTAssertTrue(ui.proposals.isEmpty, "no file diff for modelled data")
    }

    func testRefusalLeavesTheProject() async throws {
        ui.accept = false
        let r = await run("update_parameter", ["key": "tone", "value": "bold"])
        XCTAssertTrue(r.hasPrefix("refused by the user"))
        XCTAssertNil(store.loadShowreel()?.parameters.tone)
    }

    func testApplyDirectlySkipsTheCard() async throws {
        store.settings = StudioSettings(applyDirectly: true)
        let r = await run("update_parameter", ["key": "message", "value": "Calm notes"])
        XCTAssertTrue(r.hasPrefix("applied directly"), r)
        XCTAssertTrue(ui.cards.isEmpty)
        XCTAssertEqual(store.loadShowreel()?.parameters.message, "Calm notes")
    }

    func testAChangeMadeMeanwhileMakesTheCardStale() async throws {
        ui.beforeAnswer = { try? self.store.apply(.parameter(.tone, "someone else's tone")) }
        let r = await run("update_parameter", ["key": "tone", "value": "mine"])
        XCTAssertTrue(r.contains("changed since the proposal"), r)
        XCTAssertEqual(store.loadShowreel()?.parameters.tone, "someone else's tone")
    }

    func testBadKeysAndValuesAreRefusedWithoutACard() async throws {
        let a = await run("update_parameter", ["key": "colour", "value": "red"])
        let b = await run("update_parameter", ["key": "duration", "value": "soon"])
        let c = await run("update_parameter", ["key": "audience", "value": ""])
        XCTAssertTrue(a.hasPrefix("unknown parameter") && b.hasPrefix("refused") && c.hasPrefix("refused"), "\(a) | \(b) | \(c)")
        XCTAssertTrue(ui.cards.isEmpty)
    }

    func testUpdateAssetByIDWithItsGuards() async throws {
        let inbox = makeTempDir("inbox2"); defer { try? FileManager.default.removeItem(at: inbox) }
        let logo = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: logo, atomically: true, encoding: .utf8)
        let secret = inbox.appendingPathComponent("customers-real-data.csv"); try "a,b\n".write(to: secret, atomically: true, encoding: .utf8)
        try Assets.add([logo, secret], to: store)
        let ok = await run("update_asset", ["id": "logo-01", "status": "approved", "scenes": "S01"])
        XCTAssertTrue(ok.hasPrefix("accepted and applied"), ok)
        XCTAssertEqual(ui.cards.last?.title, "Approve Acme Logo.svg")
        XCTAssertEqual(Assets.load(store).first?.status, "approved")
        let held = await run("update_asset", ["id": "logo-01", "status": "hold"])
        XCTAssertTrue(held.hasPrefix("refused") && held.contains("note"), held)
        let risky = await run("update_asset", ["id": "data-01", "status": "approved"])
        XCTAssertTrue(risky.hasPrefix("refused"), risky)
        let bad = await run("update_asset", ["id": "logo-01", "status": "great"])
        XCTAssertTrue(bad.hasPrefix("unknown status"))
        XCTAssertEqual(ui.cards.count, 1, "only the valid change was shown to the user")
    }

    func testShowreelJSONAndTheManifestRefuseFileWrites() async throws {
        let a = await run("write_file", ["path": "showreel.json", "content": "{}"])
        let b = await run("propose_edit", ["file": "showreel.json", "content": "{}"])
        let c = await run("write_file", ["path": "assets/MANIFEST.csv", "content": "x"])
        XCTAssertTrue(a.hasPrefix("refused") && b.hasPrefix("refused") && c.hasPrefix("refused"))
        XCTAssertTrue(ui.proposals.isEmpty)
        XCTAssertEqual(store.loadShowreel()?.name, "Ops")
    }

    func testOpenBlock() async throws {
        let a = await run("open_block", ["block": "library"])
        XCTAssertEqual(ui.openedBlocks, ["library"]); XCTAssertTrue(a.hasPrefix("opened"))
        let b = await run("open_block", ["block": "deliver"])
        XCTAssertTrue(b.contains("not built yet") && b.contains("phase D"), b)
        XCTAssertEqual(ui.openedBlocks, ["library"], "an unbuilt zone is not opened")
        let c = await run("open_block", ["block": "nope"])
        XCTAssertTrue(c.hasPrefix("unknown block"))
    }

    func testGetStateListsBlocksAndAssets() async throws {
        try store.apply(.parameter(.audience, "Teams"))
        let inbox = makeTempDir("inbox3"); defer { try? FileManager.default.removeItem(at: inbox) }
        let f = inbox.appendingPathComponent("theme.mp3"); try "x".write(to: f, atomically: true, encoding: .utf8)
        try Assets.add([f], to: store)
        let state = await run("get_state", [:])
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(state.utf8)) as? [String: Any])
        let blocks = try XCTUnwrap(o["blocks"] as? [[String: String]])
        XCTAssertEqual(blocks.first { $0["id"] == "inspector" }?["status"], "inProgress")
        XCTAssertEqual(blocks.first { $0["id"] == "deliver" }?["status"], "soon")
        XCTAssertEqual((o["assets"] as? [[String: String]])?.first?["id"], "audio-01")
        XCTAssertEqual(o["foregroundBlock"] as? String, "project")
        XCTAssertEqual((o["showreel"] as? [String: Any])?["origin"] as? [String: String], ["tool": "studio"])
    }

    func testAgentLoopWithATypedOperation() async throws {
        let t = ScriptedTransport([
            ([toolUse("t1", "get_state", [:]), toolUse("t2", "update_parameter", ["key": "tone", "value": "warm"])], "tool_use"),
            ([textBlock("Set.")], "end_turn"),
        ])
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t)
        try await agent.send("make the tone warm", context: "block: project")
        XCTAssertEqual(store.loadShowreel()?.parameters.tone, "warm")
        XCTAssertEqual(ui.cards.map { $0.title }, ["Set tone"])
        let results = try XCTUnwrap(t.received[1].last?["content"] as? [[String: Any]])
        XCTAssertTrue((results[1]["content"] as? String ?? "").hasPrefix("accepted and applied"))
    }
}

final class AgentLoopTests: XCTestCase {
    var dir: URL!
    override func setUp() { dir = makeTempDir("agent") }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testLoopRunsToolsThenStops() async throws {
        let ui = ScriptedUI()
        let store = ProjectStore(root: dir)
        try store.write("brief.md", "old\n")
        let t = ScriptedTransport([
            ([textBlock("Looking."), toolUse("t1", "get_state", [:]), toolUse("t2", "propose_edit", ["file": "brief.md", "content": "new\n", "note": "tighter"])], "tool_use"),
            ([textBlock("Done.")], "end_turn"),
        ])
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t)
        try await agent.send("tighten the brief", context: "step: interview")

        XCTAssertEqual(ui.texts.joined(), "Looking.Done.")
        XCTAssertEqual(ui.tools, ["get_state", "propose_edit"])
        XCTAssertEqual(store.read("brief.md"), "new\n", "the proposal was accepted and written")
        XCTAssertEqual(t.received.count, 2)

        // the first request carries the context line and the message
        let first = try XCTUnwrap(t.received[0].first?["content"] as? String)
        XCTAssertTrue(first.hasPrefix("[Studio context] step: interview"))
        XCTAssertTrue(first.hasSuffix("tighten the brief"))
        // the second request carries both tool results, in order
        let results = try XCTUnwrap(t.received[1].last?["content"] as? [[String: Any]])
        XCTAssertEqual(results.map { $0["tool_use_id"] as? String }, ["t1", "t2"])
        XCTAssertTrue((results[1]["content"] as? String ?? "").hasPrefix("accepted and applied"))
    }

    func testRefusalIsReportedToTheModel() async throws {
        let ui = ScriptedUI(); ui.accept = false
        let store = ProjectStore(root: dir)
        try store.write("brief.md", "old\n")
        let t = ScriptedTransport([
            ([toolUse("t1", "propose_edit", ["file": "brief.md", "content": "new\n"])], "tool_use"),
            ([textBlock("Understood.")], "end_turn"),
        ])
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t)
        try await agent.send("change it")
        XCTAssertEqual(store.read("brief.md"), "old\n")
        let results = try XCTUnwrap(t.received[1].last?["content"] as? [[String: Any]])
        XCTAssertTrue((results[0]["content"] as? String ?? "").hasPrefix("refused by the user"))
    }

    func testAbortStopsTheLoop() async throws {
        let ui = ScriptedUI()
        let t = ScriptedTransport([([toolUse("t1", "get_state", [:])], "tool_use"), ([textBlock("never")], "end_turn")])
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t)
        ui.onTool = { agent.abort() }
        try await agent.send("go")
        XCTAssertEqual(t.received.count, 1, "no second request after the abort")
        XCTAssertTrue(ui.texts.joined().contains("[stopped]"))
    }

    func testHistorySeedsTheConversation() async throws {
        let ui = ScriptedUI()
        let t = ScriptedTransport([([textBlock("ok")], "end_turn")])
        let seed = ChatStore.seed(from: [ChatRecord(role: "user", text: "earlier question"), ChatRecord(role: "assistant", text: "earlier answer")])
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: t, history: seed)
        try await agent.send("next")
        XCTAssertEqual(t.received[0].count, 3)
        XCTAssertEqual(t.received[0][0]["content"] as? String, "earlier question")
    }

    func testTransportErrorsPropagate() async throws {
        let ui = ScriptedUI()
        let agent = try Agent(apiKey: "test", model: "test", project: dir, ui: ui, transport: ScriptedTransport([]))
        do { try await agent.send("x"); XCTFail("expected an error") }
        catch { XCTAssertTrue("\(error)".contains("script exhausted") || error.localizedDescription.contains("script exhausted")) }
    }

    func testSystemPromptHasTheCopilotAddendumAndNoPlaceholders() throws {
        let sp = try Skill.systemPrompt(project: dir, lang: nil)
        XCTAssertFalse(sp.text.contains("{{"))
        XCTAssertTrue(["propose_edit", "get_state", "update_parameter", "update_asset", "open_block"].allSatisfy { sp.text.contains($0) })
    }

    func testEveryDefinedToolHasAnImplementation() async throws {
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        for d in Tools.definitions {
            let name = try XCTUnwrap(d["name"] as? String)
            let out = await tools.run(name, [:]).text
            XCTAssertFalse(out.hasPrefix("unknown tool"), "\(name) is defined in tools.json but not implemented")
        }
    }
}

final class DecisionToolTests: XCTestCase {
    var dir: URL!
    var ui: ScriptedUI!
    var tools: Tools!
    var store: ProjectStore!
    override func setUpWithError() throws {
        dir = makeTempDir("dectools"); ui = ScriptedUI()
        tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui); store = ProjectStore(root: dir)
        try store.create(name: "D", conversationLanguage: "en", reelLanguages: ["en"])
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    func run(_ n: String, _ i: [String: Any]) async -> String { await tools.run(n, i).text }

    func testUpdateDecisionShowsACardAndAppliesOnAccept() async throws {
        let r = await run("update_decision", ["key": "palette", "value": "#101820, #FFFFFF, #F2AA4C"])
        XCTAssertTrue(r.hasPrefix("accepted and applied"), r)
        XCTAssertEqual(ui.cards.first?.title, "Set palette")
        XCTAssertEqual(ui.cards.first?.changes, [Change("Palette", "(empty)", "#101820, #FFFFFF, #F2AA4C")])
        XCTAssertEqual(store.loadShowreel()?.decisions.palette, ["#101820", "#FFFFFF", "#F2AA4C"])
        XCTAssertTrue(ui.proposals.isEmpty, "no file diff")
    }

    func testRefusalApplyDirectlyAndStale() async throws {
        ui.accept = false
        let refused = await run("update_decision", ["key": "titleFont", "value": "Anton"])
        XCTAssertTrue(refused.hasPrefix("refused by the user"))
        XCTAssertNil(store.loadShowreel()?.decisions.fonts)
        ui.accept = true
        ui.beforeAnswer = { try? self.store.apply(.decisions([DecisionChange(.titleFont, "Poppins")], title: nil)) }
        let stale = await run("update_decision", ["key": "titleFont", "value": "Anton"])
        XCTAssertTrue(stale.contains("changed since the proposal"), stale)
        XCTAssertEqual(store.loadShowreel()?.decisions.fonts?.titles, "Poppins")
        ui.beforeAnswer = nil
        store.settings = StudioSettings(applyDirectly: true)
        let cardsBefore = ui.cards.count
        let direct = await run("update_decision", ["key": "effectsPack", "value": "Cinematic"])
        XCTAssertTrue(direct.hasPrefix("applied directly"))
        XCTAssertEqual(ui.cards.count, cardsBefore)
        XCTAssertEqual(store.loadShowreel()?.decisions.effectsPack, "Cinematic")
    }

    func testBadKeysAndValuesAreRefusedWithoutACard() async throws {
        let a = await run("update_decision", ["key": "colour", "value": "red"])
        let b = await run("update_decision", ["key": "background", "value": "sparkles"])
        let c = await run("update_decision", ["key": "palette", "value": "red, blue"])
        let d = await run("update_decision", ["key": "moods", "value": "Cinematic, Deadpan, Clean product"])
        XCTAssertTrue(a.hasPrefix("unknown decision") && b.hasPrefix("refused") && c.hasPrefix("refused") && d.hasPrefix("refused"), "\(a) | \(b) | \(c) | \(d)")
        XCTAssertTrue(b.contains("aurora"), "the refusal lists the ids the engine knows")
        XCTAssertTrue(ui.cards.isEmpty)
    }

    func testOpenBlockInspectorOpens() async throws {
        let r = await run("open_block", ["block": "inspector"])
        XCTAssertTrue(r.hasPrefix("opened"), r)
        XCTAssertEqual(ui.openedBlocks, ["inspector"])
        let old = await run("open_block", ["block": "look"])
        XCTAssertTrue(old.hasPrefix("unknown block"), "the sidebar's blocks are gone: \(old)")
    }
}
