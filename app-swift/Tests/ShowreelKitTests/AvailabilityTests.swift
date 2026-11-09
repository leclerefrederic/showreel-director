import XCTest
@testable import ShowreelKit

/// The state and reason model: what is available, why not and how to get it back; the freeze during a build; a proposal waiting on elements; the status line;
/// the warning on closing. The views read all of it and decide nothing.
final class AvailabilityTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    var act: ProjectActivity { store.activity }
    override func setUp() {
        dir = makeTempDir("avail"); store = ProjectStore(root: dir)
        try? store.create(name: "Av", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t, status: "validated"))) }
        act.reset()
    }
    override func tearDown() { act.reset(); try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    var raw: String { store.read(ShowreelFile.fileName) ?? "" }
    func build(_ phase: ProjectActivity.Build.Phase = .generating, started: Date = Date()) { act.update { $0.build = .init(version: "v3", phase: phase, started: started) } }

    // MARK: every case where something is refused or disabled

    func testEachCaseSaysWhyAndHowToGetItBack() throws {
        let f = file
        var s = ProjectActivity.Snapshot()
        XCTAssertEqual(Availability.edit(.scene("S01"), in: s, file: f), .available)
        // a build in progress
        s.build = .init(version: "v3", phase: .generating)
        var u = try XCTUnwrap(Availability.edit(.scene("S01"), in: s, file: f).why)
        XCTAssertEqual(u.cause, .building); XCTAssertEqual(u.reason, "Building the film: any change now would affect the film under construction"); XCTAssertEqual(u.way, "Wait for the end, or Cancel the build"); XCTAssertEqual(u.link, .build)
        s.build = nil
        // a proposal waiting on the element
        s.proposals = [.init(id: "p1", title: "Set S02 duration", targets: [.scene("S02")])]
        u = try XCTUnwrap(Availability.edit(.scene("S02"), in: s, file: f).why)
        XCTAssertEqual(u.cause, .proposal); XCTAssertTrue(u.reason.hasPrefix("Waiting for your answer on a proposal from Clap")); XCTAssertEqual(u.link, .proposal("p1")); XCTAssertTrue(u.way.contains("Accept or refuse"))
        XCTAssertEqual(Availability.edit(.scene("S01"), in: s, file: f), .available, "an element the proposal does not touch stays editable")
        XCTAssertEqual(Availability.edit(.item(scene: "S02", item: "i1"), in: s, file: f).why?.cause, .proposal, "the items of a scene the proposal touches")
        s.proposals = [.init(id: "p2", title: "Edit text", targets: [.item(scene: "S01", item: "i1")])]
        XCTAssertEqual(Availability.edit(.item(scene: "S01", item: "i2"), in: s, file: f), .available, "another item of the same scene is free")
        XCTAssertEqual(Availability.edit(.scene("S01"), in: s, file: f).why?.cause, .proposal, "the scene's own fields overlap its item")
        s.proposals = []
        // a lock
        try store.apply(.sceneLock(ids: ["S03"], locked: true))
        u = try XCTUnwrap(Availability.edit(.scene("S03"), in: s, file: file).why)
        XCTAssertEqual(u.cause, .locked); XCTAssertEqual(u.reason, "S03 is locked"); XCTAssertEqual(u.link, .scene("S03")); XCTAssertTrue(u.way.contains("Unlock"))
        // Clap applying changes to it
        s.clap = .applying([.scene("S01")])
        u = try XCTUnwrap(Availability.edit(.scene("S01"), in: s, file: file).why)
        XCTAssertEqual(u.cause, .clapWorking); XCTAssertEqual(u.reason, "Clap is applying changes to S01")
        XCTAssertEqual(Availability.edit(.scene("S02"), in: s, file: file), .available)
        s.clap = .thinking; XCTAssertEqual(Availability.edit(.scene("S01"), in: s, file: file), .available, "thinking changes nothing yet")
        // the order of the reasons: a build wins over a proposal, a proposal over a lock
        s.build = .init(version: "v3", phase: .testing); s.proposals = [.init(id: "p", title: "t", targets: [.scene("S03")])]
        XCTAssertEqual(Availability.edit(.scene("S03"), in: s, file: file).why?.cause, .building)
        s.build = nil; XCTAssertEqual(Availability.edit(.scene("S03"), in: s, file: file).why?.cause, .proposal)
    }

    func testTheBuildButtonAndTheQuestionToClap() {
        let idle = ProjectActivity.Snapshot()
        XCTAssertEqual(Availability.startBuild(in: idle, hasKey: true, canBuild: true, clapRunning: false), .available)
        XCTAssertEqual(Availability.startBuild(in: idle, hasKey: false, canBuild: true, clapRunning: false).why, Reasons.noKey)
        XCTAssertEqual(Availability.startBuild(in: idle, hasKey: true, canBuild: true, clapRunning: true).why, Reasons.clapBusy)
        let w = Availability.startBuild(in: idle, hasKey: true, canBuild: false, clapRunning: false).why
        XCTAssertEqual(w?.cause, .notReady); XCTAssertTrue(w?.reason.contains("Go") == true)
        var b = idle; b.build = .init(version: "v1", phase: .generating)
        XCTAssertEqual(Availability.startBuild(in: b, hasKey: true, canBuild: true, clapRunning: false).why?.cause, .building)
        XCTAssertEqual(Availability.askClap(in: idle, hasKey: false, clapRunning: false).why?.link, .key)
        XCTAssertEqual(Availability.askClap(in: b, hasKey: true, clapRunning: false), .available, "a question can be asked during a build")
        for u in [Reasons.building, Reasons.noKey, Reasons.clapBusy, Reasons.locked("S01"), Reasons.clapWorking(["S01"])] { XCTAssertFalse(u.reason.isEmpty || u.way.isEmpty, "\(u.cause): a reason and a way")}
    }

    // MARK: the freeze during a build

    /// Every operation, once. The switch has no default: a new operation does not compile until it is classified here, and so in `buildPolicy`.
    func sample(_ op: ProjectOperation) -> ProjectOperation {
        switch op {
        case .parameter: return .parameter(.audience, "Everyone")
        case .decisions: return .decisions([DecisionChange(.palette, "#101010, #FFFFFF, #FF0000, #00FF00")], title: nil)
        case .asset: return .asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil)
        case .gate: return .gate("storyboard", passed: true)
        case .scene: return .scene(id: "S01", SceneEdit(text: "Changed"))
        case .addScene: return .addScene(id: "", SceneEdit(duration: "3", text: "New"))
        case .deleteScene: return .deleteScene(id: "S01")
        case .sceneEnabled: return .sceneEnabled(id: "S02", enabled: false, montage: nil)
        case .moveScene: return .moveScene(id: "S03", after: "start", montage: nil)
        case .sceneLook: return .sceneLook(id: "S01", [DecisionChange(.background, Look.backgroundIDs().first!)])
        case .content: return .content(scene: "S01", .add(ContentEdit(type: "text", text: "x"), after: nil))
        case .resize: return .resize(scene: "S01", duration: 6, ripple: false)
        case .moveCut: return .moveCut(before: "S01", after: "S02", at: 5)
        case .transition: return .transition(from: "S01", TransitionEdit(type: "Push", duration: 0.5))
        case .track: return .track(asset: nil)
        case .grid: return .grid(bpm: 120, firstBeat: 0)
        case .gridSettings: return .gridSettings(snap: "bar", ripple: true)
        case .moveAsset: return .moveAsset(id: "logo-01", after: "start")
        case .sceneLock: return .sceneLock(ids: ["S01"], locked: true)
        case .addFontFiles: return .addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "Fredoka-Bold.ttf", data: Data("x".utf8))]))
        case .resource: return .resource(.addTag(id: "logo-01", tag: "logo"))
        }
    }
    var everyOperation: [ProjectOperation] {
        [.parameter(.audience, ""), .decisions([], title: nil), .asset(id: "", status: nil, note: nil, licence: nil, scenes: nil), .gate("", passed: true), .scene(id: "", SceneEdit()), .addScene(id: "", SceneEdit()),
         .sceneEnabled(id: "", enabled: true, montage: nil), .moveScene(id: "", after: "", montage: nil), .sceneLook(id: "", []), .content(scene: "", .remove(item: "")), .resize(scene: "", duration: 1, ripple: false),
         .moveCut(before: "", after: "", at: 1), .transition(from: "", nil), .track(asset: nil), .grid(bpm: nil, firstBeat: nil), .gridSettings(snap: nil, ripple: nil), .moveAsset(id: "", after: ""), .sceneLock(ids: [], locked: true), .addFontFiles(FontPayload(family: "", dir: "", files: [])), .resource(.renameTag(from: "a", to: "b"))].map(sample)
    }

    func testEveryOperationIsRefusedDuringABuildAndTheProjectStaysAsItWas() throws {
        XCTAssertEqual(everyOperation.count, 20)
        let before = raw
        for op in everyOperation { if let e = try? store.plan(op) { XCTAssertFalse(e.title.isEmpty) } }
        build()
        for op in everyOperation {
            XCTAssertEqual(op.buildPolicy, .refused)
            XCTAssertThrowsError(try store.plan(op), op.kind) { XCTAssertEqual($0.localizedDescription, Reasons.building.message) }
            XCTAssertThrowsError(try store.apply(op), op.kind) { XCTAssertEqual($0.localizedDescription, Reasons.building.message, op.kind) }
        }
        XCTAssertEqual(raw, before, "nothing changed")
        XCTAssertEqual(Reasons.building.message, "Building the film: any change now would affect the film under construction. Wait for the end, or Cancel the build")
    }

    func testUndoRedoFilesAndUpdatesAreFrozenToo() throws {
        try store.apply(.scene(id: "S01", SceneEdit(text: "Before the build")))
        try store.apply(.scene(id: "S01", SceneEdit(text: "Undone")))
        _ = try store.undo()
        build()
        for (what, run) in [("undo", { _ = try self.store.undo() }), ("redo", { _ = try self.store.redo() }), ("transaction", { _ = try self.store.transaction("x") {} }),
                            ("update", { _ = try ProjectFormat.update(self.store) }), ("restore", { try ProjectFormat.restore(self.store, ProjectBackup(id: "b", url: self.dir, date: nil, revision: 1, files: [], absent: [])) })] as [(String, () throws -> Void)] {
            XCTAssertThrowsError(try run(), what) { XCTAssertEqual($0.localizedDescription, Reasons.building.message, what) }
        }
        XCTAssertNotNil(store.buildRefusal())
        act.reset()
        XCTAssertNil(store.buildRefusal())
        XCTAssertNoThrow(try store.redo(), "after the build the undo history is still there")
    }

    func testTheEditingComesBackAfterSuccessErrorAndCancel() throws {
        for ending in ["success", "error", "cancel"] {
            build(.generating)
            XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(text: "during \(ending)"))))
            if ending == "cancel" { act.update { $0.build?.phase = .cancelling }; XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(text: "still stopping"))), "cancelling is not finished yet") }
            if ending == "success" { act.update { $0.build?.phase = .testing }; XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(text: "testing")))) }
            act.update { $0.build = nil }                      // what the window does at the end, whatever the end was
            XCTAssertNoThrow(try store.apply(.scene(id: "S01", SceneEdit(text: "after \(ending)"))), ending)
            XCTAssertEqual(file.scenes[0].text, "after \(ending)")
        }
    }

    func testWhatClapCanStillDoDuringABuild() async throws {
        build(.generating)
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let typed = await tools.run("update_scene", ["id": "S01", "text": "x"]).text
        XCTAssertTrue(typed.hasPrefix("refused:") && typed.contains("Building the film"), typed); XCTAssertTrue(ui.cards.isEmpty, "no card for what cannot be done")
        let outside = await tools.run("write_file", ["path": "notes.txt", "content": "hi"]).text
        XCTAssertTrue(outside.hasPrefix("refused:") && outside.contains("Building the film"), outside)
        let inside = await tools.run("write_file", ["path": "v3/scenes/S01.js", "content": "return function () {};\n"]).text
        XCTAssertTrue(inside.hasPrefix("wrote"), "the build writes its own version folder: \(inside)")
        let gen = await tools.run("generate_scenes", ["scenes": ["S01"]]).text
        XCTAssertTrue(gen.contains("not available") || gen.contains("Building the film"), gen)
        act.update { $0.build?.phase = .testing }
        let late = await tools.run("write_file", ["path": "v3/scenes/S02.js", "content": "return function () {};\n"]).text
        XCTAssertTrue(late.hasPrefix("refused:"), "once the files are written, nothing more is written: \(late)")
        let st = await tools.run("get_state", [:]).text
        XCTAssertFalse(st.hasPrefix("refused"), "looking is always possible")
    }

    // MARK: a proposal waiting on elements

    func testAProposalBlocksWhatItTouchesAndOnlyThat() throws {
        let op = ProjectOperation.resize(scene: "S02", duration: 6, ripple: false)
        let card = try store.plan(op)
        XCTAssertEqual(card.targets, [.scene("S02")], "the card knows what it touches")
        act.addProposal(.init(id: "p1", title: card.title, targets: card.targets))
        XCTAssertThrowsError(try store.apply(.scene(id: "S02", SceneEdit(text: "mine")))) { XCTAssertTrue($0.localizedDescription.hasPrefix("Waiting for your answer on a proposal from Clap"), $0.localizedDescription) }
        XCTAssertThrowsError(try store.apply(.content(scene: "S02", .add(ContentEdit(type: "text", text: "x"), after: nil))), "an item of the scene")
        XCTAssertNoThrow(try store.apply(.scene(id: "S01", SceneEdit(text: "free"))), "another scene is free")
        XCTAssertNoThrow(try store.apply(.parameter(.audience, "Everyone")), "a setting nobody proposed to change is free")
        // answering lifts it, and the accepted change itself goes through
        act.removeProposal("p1")
        XCTAssertNoThrow(try store.apply(op, expecting: card))
        // a look proposal blocks that setting only
        let look = ProjectOperation.decisions([DecisionChange(.palette, "#101010, #FFFFFF, #FF0000, #00FF00")], title: nil)
        act.addProposal(.init(id: "p2", title: "palette", targets: look.targets))
        XCTAssertEqual(look.targets, [.setting("look.palette")])
        XCTAssertThrowsError(try store.apply(.decisions([DecisionChange(.palette, "#202020, #FFFFFF, #FF0000, #00FF00")], title: nil)))
        XCTAssertNoThrow(try store.apply(.decisions([DecisionChange(.titleFont, Look.freeFonts().first!.name)], title: nil)))
        // the elements a proposal concerns, listed for the views
        act.addProposal(.init(id: "p3", title: "x", targets: [.item(scene: "S01", item: "i1")]))
        XCTAssertEqual(act.snapshot.proposals.flatMap { $0.targets }.count, 2)
        XCTAssertEqual(act.snapshot.proposal(blocking: .scene("S01"))?.id, "p3")
    }

    func testEveryOperationNamesWhatItTouches() {
        for op in everyOperation {
            let t = op.targets
            switch op {
            case .addScene: XCTAssertTrue(t.isEmpty, "a new scene has no ID yet")
            default: XCTAssertFalse(t.isEmpty, op.kind)
            }
        }
        XCTAssertEqual(ProjectOperation.moveCut(before: "S01", after: "S02", at: 1).targets, [.scene("S01"), .scene("S02")])
        XCTAssertEqual(ProjectOperation.content(scene: "S01", .update(item: "i3", ContentEdit())).targets, [.item(scene: "S01", item: "i3")])
        XCTAssertEqual(ProjectOperation.track(asset: nil).targets, [.setting("music")])
        XCTAssertTrue(ElementRef.scene("S01").overlaps(.item(scene: "S01", item: "i1"))); XCTAssertFalse(ElementRef.scene("S01").overlaps(.item(scene: "S02", item: "i1")))
        XCTAssertFalse(ElementRef.asset("a").overlaps(.scene("a")))
    }

    // MARK: the line at the bottom of the window

    func testTheStatusLineOfEveryKindOfOperation() throws {
        for op in everyOperation {
            guard let card = try? store.plan(op) else { continue }
            let l = StatusLine.applied(op, card: card)
            XCTAssertTrue(l.text.hasPrefix("Applied: ") && l.text.count > 12, "\(op.kind): \(l.text)"); XCTAssertTrue(l.undoable); XCTAssertEqual(l.targets, op.targets)
        }
        let resize = try store.plan(.resize(scene: "S01", duration: 6, ripple: false))
        let l = StatusLine.applied(.resize(scene: "S01", duration: 6, ripple: false), card: resize)
        XCTAssertTrue(l.text.contains("S01") && l.text.contains("6"), l.text)
        let multi = try store.plan(.decisions([DecisionChange(.palette, "#101010, #FFFFFF, #FF0000, #00FF00"), DecisionChange(.effectsPack, Look.packs().first!.name)], title: nil))
        XCTAssertTrue(StatusLine.applied(.parameter(.audience, "x"), card: multi).text.contains("(+1 more)"))
        build()
        var why = ""
        do { try store.apply(.scene(id: "S01", SceneEdit(text: "x"))) } catch { why = error.localizedDescription }
        let r = StatusLine.refused(why, op: .scene(id: "S01", SceneEdit()))
        XCTAssertEqual(r.kind, .refused); XCTAssertTrue(r.text.hasPrefix("Not done: Building the film") && r.text.contains("Cancel the build")); XCTAssertFalse(r.undoable)
    }

    // MARK: closing

    func testNothingInProgressNoAlert() {
        for c in CloseGuard.Context.allCases { XCTAssertNil(CloseGuard.alert(ProjectActivity.Snapshot(), context: c, lastWorking: "v1")) }
    }

    func testABuildRunningAlert() throws {
        var s = ProjectActivity.Snapshot(); s.build = .init(version: "v3", phase: .generating, started: Date(timeIntervalSince1970: 0))
        let a = try XCTUnwrap(CloseGuard.alert(s, context: .quit, scenes: (2, 6), lastWorking: "v2", now: Date(timeIntervalSince1970: 250)))
        XCTAssertEqual(a.title, "A build is running"); XCTAssertEqual(a.keep, "Keep working"); XCTAssertEqual(a.confirm, "Cancel build and quit"); XCTAssertTrue(a.cancelsBuild)
        let t = a.lines.joined(separator: " ")
        for n in ["scene 3 of 6, 4 min", "the build stops", "stays in v3", "not assembled and not tested", "last working version (v2)", "Tokens already used are not refunded"] { XCTAssertTrue(t.contains(n), n + " | " + t) }
        XCTAssertEqual(CloseGuard.alert(s, context: .closeWindow, lastWorking: nil)?.confirm, "Cancel build and close")
        XCTAssertTrue(CloseGuard.alert(s, context: .closeWindow, lastWorking: nil)?.lines.joined().contains("no working version yet") == true)
        XCTAssertEqual(CloseGuard.alert(s, context: .updateProject, lastWorking: "v2")?.confirm, "Cancel build and update")
        XCTAssertEqual(CloseGuard.alert(s, context: .restoreBackup, lastWorking: "v2")?.confirm, "Cancel build and restore")
        s.build?.phase = .testing
        let tt = try XCTUnwrap(CloseGuard.alert(s, context: .quit, lastWorking: "v2"))
        XCTAssertEqual(tt.title, "The film is being tested"); XCTAssertTrue(tt.lines.joined().contains("No tokens are used in this step") && tt.lines.joined().contains("Test it again"))
    }

    func testClapAnsweringAndProposalsWaitingAlerts() throws {
        var s = ProjectActivity.Snapshot(); s.clap = .thinking
        let a = try XCTUnwrap(CloseGuard.alert(s, context: .closeWindow, lastWorking: "v1"))
        XCTAssertEqual(a.title, "Clap is working"); XCTAssertEqual(a.confirm, "Close anyway"); XCTAssertTrue(a.interruptsClap && !a.cancelsBuild)
        XCTAssertTrue(a.lines.joined().contains("what it already changed stays") && a.lines.joined().contains("can be undone") && a.lines.joined().contains("not refunded"))
        s.clap = nil
        s.proposals = [.init(id: "1", title: "A", targets: []), .init(id: "2", title: "B", targets: [], isFile: true)]
        let p = try XCTUnwrap(CloseGuard.alert(s, context: .quit, lastWorking: "v1"))
        XCTAssertEqual(p.title, "Clap is waiting for your answer"); XCTAssertEqual(p.proposals, 2); XCTAssertEqual(p.confirm, "Quit anyway")
        let t = p.lines.joined()
        XCTAssertTrue(t.contains("2 proposals from Clap are waiting") && t.contains("recorded as refused in the journal") && t.contains("the file stays as it is"), t)
        s.proposals = [.init(id: "1", title: "A", targets: [])]
        XCTAssertTrue(CloseGuard.alert(s, context: .updateProject, lastWorking: nil)?.lines.joined().contains("1 proposal from Clap is waiting") == true)
        XCTAssertEqual(CloseGuard.alert(s, context: .updateProject, lastWorking: nil)?.confirm, "Stop Clap and update")
        XCTAssertNil(CloseGuard.alert(s, context: .openOtherProject, lastWorking: nil), "another project opens in its own window and interrupts nothing")
    }

    func testAProposalNotAnsweredIsRecordedAsRefused() throws {
        store.noteUnanswered(.init(id: "p", title: "Set S02 duration", targets: [.scene("S02")]))
        let e = try XCTUnwrap(store.journal.entries().last)
        XCTAssertEqual(e.state, "refused"); XCTAssertEqual(e.author, "clap"); XCTAssertEqual(e.title, "Set S02 duration"); XCTAssertTrue(e.note?.contains("not answered") == true)
    }

    // MARK: what Clap is doing

    func testWhatClapIsDoingFromItsToolCalls() {
        XCTAssertEqual(ClapActivity.work(for: "get_state", input: [:]), .thinking)
        XCTAssertEqual(ClapActivity.work(for: "read_file", input: ["path": "brief.md"]), .thinking)
        XCTAssertEqual(ClapActivity.work(for: "update_scene", input: ["id": "S02", "duration": 6]), .applying([.scene("S02")]))
        XCTAssertEqual(ClapActivity.work(for: "lock_scene", input: ["scenes": ["S01", "S03"], "locked": true]), .applying([.scene("S01"), .scene("S03")]))
        XCTAssertEqual(ClapActivity.work(for: "set_transition", input: ["from": "S01"]), .applying([.scene("S01")]))
        XCTAssertEqual(ClapActivity.work(for: "update_decision", input: ["key": "palette"]), .applying([]))
        var s = ProjectActivity.Snapshot()
        XCTAssertNil(ClapActivity.label(s))
        s.clap = .thinking; XCTAssertEqual(ClapActivity.label(s), "Clap is thinking\u{2026}")
        s.clap = .applying([]); XCTAssertEqual(ClapActivity.label(s), "Clap is applying changes\u{2026}")
        s.proposals = [.init(id: "1", title: "t", targets: [])]; XCTAssertEqual(ClapActivity.label(s), "Waiting for your answer: 1 proposal from Clap")
        s.proposals.append(.init(id: "2", title: "u", targets: [])); XCTAssertEqual(ClapActivity.label(s), "Waiting for your answer: 2 proposals from Clap")
        XCTAssertTrue(ElementRef.setting("look").overlaps(.setting("look.palette")) && !ElementRef.setting("look").overlaps(.setting("lookup")) && !ElementRef.setting("music").overlaps(.setting("look.palette")))
    }

    // MARK: progress

    func testTheProgressOfAScenePerSceneBuild() throws {
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("v3/scenes"), withIntermediateDirectories: true)
        XCTAssertEqual(BuildProgress.scenes(version: "v3", store: store).done, 0)
        XCTAssertEqual(BuildProgress.scenes(version: "v3", store: store).current, "S01")
        try "return function () {};\n".write(to: dir.appendingPathComponent("v3/scenes/S01.js"), atomically: true, encoding: .utf8)
        try "return function () {};\n".write(to: dir.appendingPathComponent("v3/scenes/S02.js"), atomically: true, encoding: .utf8)
        let p = BuildProgress.scenes(version: "v3", store: store)
        XCTAssertEqual([p.done, p.total], [2, 3]); XCTAssertEqual(p.current, "S03"); XCTAssertEqual(BuildProgress.sceneLine(done: p.done, total: p.total), "Scene 3 of 3")
        XCTAssertEqual(BuildProgress.sceneLine(done: 5, total: 3), "Scene 3 of 3"); XCTAssertNil(BuildProgress.sceneLine(done: 0, total: 0))
        XCTAssertEqual(BuildProgress.elapsed(42), "42 s"); XCTAssertEqual(BuildProgress.elapsed(250), "4 min")
        XCTAssertNil(BuildProgress.lastWorking(store))
    }
}
