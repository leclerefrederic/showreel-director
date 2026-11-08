import XCTest
@testable import ShowreelKit

/// A UI with no window. Records what the agent showed and answers proposals as scripted.
final class ScriptedUI: AgentUI, @unchecked Sendable {
    var accept = true
    var foreground: String? = "storyboard.md"
    private(set) var texts: [String] = []
    private(set) var tools: [String] = []
    private(set) var proposals: [Proposal] = []
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
        XCTAssertTrue(sp.text.contains("propose_edit") && sp.text.contains("get_state"))
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
