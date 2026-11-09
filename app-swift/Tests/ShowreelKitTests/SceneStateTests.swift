import XCTest
@testable import ShowreelKit

/// The three states of a scene (WIP, Validated, Locked): the migration of the old words, the lock and everything it refuses, the menu of the badge.
final class SceneStateTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("states"); store = ProjectStore(root: dir)
        try? store.create(name: "St", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t))) }
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    func scene(_ id: String) -> ShowreelFile.Scene { file.scenes.first { $0.id == id }! }
    func raw() -> String { store.read(ShowreelFile.fileName) ?? "" }
    func validate(_ ids: String...) throws { for id in ids { try store.apply(.scene(id: id, SceneEdit(status: "validated"))) } }

    // MARK: migration

    func testTheOldWordsAreReadAsTheNewStatesAndNothingElseMoves() throws {
        let json = #"{"schema": 1, "name": "M", "x": 1, "scenes": [{"id": "S01", "duration": 3, "status": "ok", "note": "fine", "sceneNew": 7}, {"id": "S02", "duration": 3, "status": "modify", "note": "shorter"}, {"id": "S03", "duration": 3, "status": "open"}, {"id": "S04", "duration": 3}, {"id": "S05", "duration": 3, "status": "ditched"}, {"id": "S06", "duration": 3, "status": "locked"}]}"#
        let f = try ShowreelFile.decode(json)
        XCTAssertEqual(f.scenes.map { $0.status }, ["validated", "wip", "wip", "wip", "ditched", "locked"])
        XCTAssertEqual(f.scenes[1].note, "shorter", "the note of a modify stays"); XCTAssertTrue(f.scenes[1].toModify); XCTAssertFalse(f.scenes[2].toModify)
        XCTAssertEqual(f.scenes[0].note, "fine")
        XCTAssertTrue(f.scenes[4].archived, "a ditched scene stays archived")
        XCTAssertEqual(f.scenes[0].unknown["sceneNew"], .number(7), "keys the app does not know are kept")
        XCTAssertEqual(f.unknown["x"], .number(1))
        XCTAssertTrue(try f.encoded().contains("\"sceneNew\""))
        XCTAssertEqual(try ShowreelFile.decode(f.encoded()), f, "what was read is written and read back unchanged")
        XCTAssertEqual(ShowreelFile.Scene(id: "S09", status: "ok").status, "validated", "a scene built in code says the same words")
        XCTAssertEqual(SceneState.canonical("a word of the future"), "a word of the future", "an unknown word is kept, and counts as WIP")
        XCTAssertEqual(ShowreelFile.Scene(id: "S09", status: "a word of the future").state, .wip)
    }

    func testUpdateProjectListsTheStatesBacksUpAndKeepsEveryNote() throws {
        let json = #"{"schema": 1, "formatRevision": 1, "name": "U", "origin": {"tool": "studio"}, "scenes": [{"id": "S01", "duration": 3, "text": "A", "content": [], "status": "ok"}, {"id": "S02", "duration": 3, "text": "B", "content": [], "status": "modify", "note": "shorter"}], "storyboards": [{"id": "main", "name": "Master", "items": [{"scene": "S01", "enabled": true, "transition": {"type": "cut"}}, {"scene": "S02", "enabled": true, "transition": {"type": "cut"}}]}], "keep": true}"#
        let d = makeTempDir("states-update"); defer { try? FileManager.default.removeItem(at: d) }
        let s = ProjectStore(root: d)
        try json.write(to: d.appendingPathComponent("showreel.json"), atomically: true, encoding: .utf8)
        let original = try Data(contentsOf: d.appendingPathComponent("showreel.json"))
        let plan = try XCTUnwrap(ProjectFormat.plan(s))
        XCTAssertTrue(plan.changes.contains { $0.contains("Review states become WIP, Validated and Locked") && $0.contains("S01") && $0.contains("S02") }, "\(plan.changes)")
        let (b, _) = try ProjectFormat.update(s)
        XCTAssertEqual(try Data(contentsOf: b.url.appendingPathComponent("showreel.json")), original, "the backup is the file as it was")
        let after = try XCTUnwrap(s.loadShowreel())
        XCTAssertEqual(after.scenes.map { $0.status }, ["validated", "wip"]); XCTAssertEqual(after.scenes[1].note, "shorter")
        XCTAssertEqual(after.unknown["keep"], .bool(true))
        XCTAssertEqual(after.revision, ShowreelFile.currentRevision)
        XCTAssertFalse(ProjectFormat.plan(s) != nil, "nothing is left to update")
    }

    func testTheSkillsExportStaysReadable() throws {
        let text = try String(contentsOf: fixtureURL("studio-export/showreel.json"), encoding: .utf8)
        let f = try ShowreelFile.decode(text)
        XCTAssertFalse(f.scenes.isEmpty)
        for s in f.scenes { XCTAssertTrue([SceneState.wip, .ditched].contains(s.state), "the export says open or ditched: \(s.id) is \(s.state)") }
    }

    // MARK: the lock

    func testOnlyAValidatedSceneCanBeLockedAndUnlockingGivesBackValidated() throws {
        XCTAssertThrowsError(try store.plan(.sceneLock(ids: ["S01"], locked: true))) { XCTAssertTrue($0.localizedDescription.contains("validate it before locking")) }
        XCTAssertThrowsError(try store.plan(.sceneLock(ids: ["S09"], locked: true)))
        XCTAssertThrowsError(try store.plan(.sceneLock(ids: [], locked: true)))
        XCTAssertThrowsError(try store.plan(.sceneLock(ids: ["S01"], locked: false)), "nothing to unlock")
        try validate("S01")
        let card = try store.plan(.sceneLock(ids: ["S01"], locked: true))
        XCTAssertEqual(card.title, "Lock S01"); XCTAssertEqual(card.changes, [Change("S01 state", "Validated", "Locked")])
        try store.apply(.sceneLock(ids: ["S01"], locked: true), author: "clap", reason: "the opening is final")
        XCTAssertEqual(scene("S01").state, .locked)
        XCTAssertThrowsError(try store.plan(.sceneLock(ids: ["S01"], locked: true)), "already locked")
        let j = try XCTUnwrap(store.journal.entries().last)
        XCTAssertEqual(j.op, "sceneLock"); XCTAssertEqual(j.author, "clap"); XCTAssertEqual(j.target, "S01"); XCTAssertEqual(j.note, "the opening is final")
        XCTAssertEqual(try store.plan(.sceneLock(ids: ["S01"], locked: false)).title, "Unlock S01")
        try store.apply(.sceneLock(ids: ["S01"], locked: false))
        XCTAssertEqual(scene("S01").state, .validated, "unlocking is explicit and gives back Validated, never WIP")
        try store.undo(); XCTAssertEqual(scene("S01").state, .locked, "undo takes the unlock back")
        try store.undo(); XCTAssertEqual(scene("S01").state, .validated, "and the lock")
        XCTAssertEqual(try store.journal.entries().filter { $0.state == "undone" }.count, 2)
    }

    func testLockAllValidatedIsOneCardAndOneUndo() throws {
        XCTAssertNil(SceneStates.lockAllValidated(file), "no validated scene: nothing to offer")
        try validate("S01", "S03")
        let op = try XCTUnwrap(SceneStates.lockAllValidated(file))
        XCTAssertEqual(op, .sceneLock(ids: ["S01", "S03"], locked: true))
        XCTAssertEqual(try store.plan(op).title, "Lock 2 scenes")
        try store.apply(op)
        XCTAssertEqual(file.scenes.map { $0.state }, [.locked, .wip, .locked])
        try store.undo()
        XCTAssertEqual(file.scenes.map { $0.state }, [.validated, .wip, .validated], "one step")
    }

    func testALockedSceneCountsAsReviewedForTheGoAndTheGoStays() throws {
        try validate("S01", "S02", "S03")
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true))
        XCTAssertNil(store.goBlocking())
        try store.apply(.sceneLock(ids: ["S01", "S03"], locked: true))
        XCTAssertEqual(file.gates["review"], "passed", "a lock changes nothing of the film: the Go stays")
        XCTAssertTrue(Checks.run(area: "scene", store: store).contains { $0.id == "review.all" && $0.level == .ok })
        try store.apply(.sceneLock(ids: ["S02"], locked: false))
        try store.apply(.scene(id: "S02", SceneEdit(text: "changed")))
        XCTAssertEqual(file.gates["review"], "open"); XCTAssertEqual(scene("S02").state, .wip)
    }

    // MARK: what a locked scene refuses

    /// Every kind of operation, so that a new one cannot be added without saying here what a locked scene does with it.
    func kind(_ op: ProjectOperation) -> String {
        switch op {
        case .parameter: return "parameter"
        case .decisions: return "decisions"
        case .asset: return "asset"
        case .gate: return "gate"
        case .scene: return "scene"
        case .addScene: return "addScene"
        case .sceneEnabled: return "sceneEnabled"
        case .moveScene: return "moveScene"
        case .sceneLook: return "sceneLook"
        case .content: return "content"
        case .resize: return "resize"
        case .moveCut: return "moveCut"
        case .transition: return "transition"
        case .track: return "track"
        case .grid: return "grid"
        case .gridSettings: return "gridSettings"
        case .moveAsset: return "moveAsset"
        case .sceneLock: return "sceneLock"
        case .addFontFiles: return "addFontFiles"
        case .resource: return "resource"
        }
    }
    static let allKinds: Set<String> = ["parameter", "decisions", "asset", "gate", "scene", "addScene", "sceneEnabled", "moveScene", "sceneLook", "content", "resize", "moveCut", "transition", "track", "grid", "gridSettings", "moveAsset", "sceneLock", "addFontFiles", "resource"]

    /// A project with a locked S02 between two WIP scenes, a resource and an element in S02.
    func lockedProject() throws -> String {
        let inbox = makeTempDir("states-inbox"); defer { try? FileManager.default.removeItem(at: inbox) }
        let logo = inbox.appendingPathComponent("logo.png"); try Data([0x89, 0x50]).write(to: logo)
        try Assets.add([logo], to: store)
        _ = try? store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil))
        try store.apply(.content(scene: "S02", .add(ContentEdit(type: "text", text: "Second line"), after: nil)))
        try validate("S02")
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        return "logo-01"
    }

    func testALockedSceneRefusesEverythingThatChangesItAndAllowsItsPlaceInTheMontage() throws {
        let logo = try lockedProject()
        let item = try XCTUnwrap(scene("S02").content.first?.id)
        let bg = try XCTUnwrap(Look.backgroundIDs().first)
        let tr = try XCTUnwrap(Look.transitions().first { !Look.isPreviewOnly($0.name) }?.name)
        let refused: [ProjectOperation] = [
            .scene(id: "S02", SceneEdit(text: "changed")), .scene(id: "S02", SceneEdit(duration: "9")), .scene(id: "S02", SceneEdit(note: "a remark")),
            .scene(id: "S02", SceneEdit(status: "wip")), .scene(id: "S02", SceneEdit(status: "ditched")), .scene(id: "S02", SceneEdit(archived: true)),
            .scene(id: "S02", SceneEdit(name: "Middle")), .scene(id: "S02", SceneEdit(controlLevel: "precise")), .scene(id: "S02", SceneEdit(assets: logo)),
            .scene(id: "S02", SceneEdit(visual: "x", after: "start")),
            .sceneLook(id: "S02", [DecisionChange(.background, bg)]),
            .content(scene: "S02", .add(ContentEdit(type: "text", text: "more"), after: nil)), .content(scene: "S02", .update(item: item, ContentEdit(text: "new"))),
            .content(scene: "S02", .remove(item: item)), .content(scene: "S02", .move(item: item, after: "start")),
            .resize(scene: "S02", duration: 7, ripple: true), .resize(scene: "S02", duration: 7, ripple: false),
            .moveCut(before: "S01", after: "S02", at: 3), .moveCut(before: "S02", after: "S03", at: 9),
            .asset(id: logo, status: nil, note: nil, licence: nil, scenes: "S02"),
        ]
        let before = raw()
        for op in refused {
            XCTAssertThrowsError(try store.plan(op), "\(op)") { XCTAssertTrue($0.localizedDescription.contains("S02 is locked: unlock it first"), "\(op): \($0.localizedDescription)") }
            XCTAssertThrowsError(try store.apply(op), "\(op)")
        }
        XCTAssertEqual(raw(), before, "nothing changed: refusing is not a partial write")
        XCTAssertEqual(scene("S02").state, .locked)
        // the allowed ones: the place in the montage, a transition, the unlock itself
        let allowed: [ProjectOperation] = [
            .moveScene(id: "S02", after: "start", montage: nil), .scene(id: "S02", SceneEdit(after: "S03")), .sceneEnabled(id: "S02", enabled: false, montage: nil),
            .sceneEnabled(id: "S02", enabled: true, montage: nil), .transition(from: "S01", TransitionEdit(type: tr)),
            // other scenes and the project's own settings are not a locked scene's business
            .scene(id: "S01", SceneEdit(text: "free")), .resize(scene: "S01", duration: 6, ripple: true), .resize(scene: "S03", duration: 6, ripple: false),
            .parameter(.audience, "Teams"), .asset(id: logo, status: nil, note: "a note", licence: nil, scenes: nil),
        ]
        for op in allowed { XCTAssertNoThrow(try store.apply(op), "\(op)") }
        XCTAssertEqual(scene("S02").state, .locked); XCTAssertEqual(scene("S02").text, "Two", "the locked scene was not touched")
        try store.apply(.sceneLock(ids: ["S02"], locked: false))
        XCTAssertNoThrow(try store.apply(.scene(id: "S02", SceneEdit(text: "now it changes"))), "unlocked: free again")
    }

    func testTheSweepCoversEveryKindOfOperation() throws {
        let logo = try lockedProject()
        let item = try XCTUnwrap(scene("S02").content.first?.id)
        let one: [ProjectOperation] = [
            .parameter(.audience, "x"), .decisions([DecisionChange(.palette, "#000000")], title: nil), .asset(id: logo, status: nil, note: "n", licence: nil, scenes: nil), .gate("storyboard", passed: true),
            .scene(id: "S02", SceneEdit(text: "x")), .addScene(id: "", SceneEdit(text: "x")), .sceneEnabled(id: "S02", enabled: false, montage: nil), .moveScene(id: "S02", after: "start", montage: nil),
            .sceneLook(id: "S02", []), .content(scene: "S02", .remove(item: item)), .resize(scene: "S02", duration: 5, ripple: true), .moveCut(before: "S01", after: "S02", at: 3),
            .transition(from: "S02", nil), .track(asset: nil), .grid(bpm: 100, firstBeat: 0), .gridSettings(snap: nil, ripple: true), .moveAsset(id: logo, after: "start"),
            .sceneLock(ids: ["S02"], locked: false), .addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [])), .resource(.addTag(id: "x", tag: "t"))]
        XCTAssertEqual(Set(one.map(kind)), Self.allKinds, "an operation was added: say here what a locked scene does with it")
        // what changes a scene's insides must name that scene; the rest must not
        let touching = Set(one.filter { !store.scenesChanged(by: $0, in: file).isEmpty }.map(kind))
        XCTAssertEqual(touching, ["scene", "sceneLook", "content", "resize", "moveCut"])
    }

    func testRippleNeverChangesTheLengthOfALockedSceneAndALinkedResourceIsNotAddedToIt() throws {
        let logo = try lockedProject()
        let len = scene("S02").duration, content = scene("S02").content
        try store.apply(.resize(scene: "S01", duration: 7, ripple: true))
        XCTAssertEqual(scene("S02").duration, len, "ripple moves the start, not the length")
        XCTAssertEqual(file.timeline()[1].start, 7)
        try store.apply(.resize(scene: "S01", duration: 5, ripple: false))
        XCTAssertEqual(scene("S02").duration, len); XCTAssertEqual(file.timeline()[1].start, 7, "no ripple: it stays where it is")
        // a resource linked straight into the manifest does not add an element behind the lock
        var rows = Assets.load(store); rows[0].scene = "S02"; try Assets.save(rows, store)
        XCTAssertTrue(try store.completeComposition(reopenGo: false).isEmpty)
        XCTAssertEqual(scene("S02").content, content)
        XCTAssertFalse(Composition.gaps(file, Assets.load(store)).contains { $0.asset.id == logo }, "a locked scene shows no gap to fill")
    }

    func testAStoryboardTableReadBackDoesNotRewriteALockedScene() throws {
        _ = try lockedProject()
        let before = scene("S02")
        var md = try XCTUnwrap(ProjectDocs.storyboard(file))
        md = md.replacingOccurrences(of: "| Two", with: "| Rewritten").replacingOccurrences(of: "locked", with: "wip")
        var f = file
        MarkdownRead.apply(storyboard: md, to: &f)
        XCTAssertEqual(f.scenes.first { $0.id == "S02" }, before, "text, state and the rest of a locked scene stay as the file has them")
        // a table that lost the row does not ditch it either
        var rows = md.components(separatedBy: "\n").filter { !$0.hasPrefix("| S02") }.joined(separator: "\n")
        rows += "\n"
        var g = file
        MarkdownRead.apply(storyboard: rows, to: &g)
        XCTAssertEqual(g.scenes.first { $0.id == "S02" }?.state, .locked)
        XCTAssertFalse(g.scenes.first { $0.id == "S02" }?.archived ?? true)
        // and a table never gives a lock
        var h = file
        h.scenes[0].status = "validated"
        let locked = (ProjectDocs.storyboard(h) ?? "").replacingOccurrences(of: "validated", with: "locked")
        MarkdownRead.apply(storyboard: locked, to: &h)
        XCTAssertNotEqual(h.scenes[0].state, .locked)
    }

    func testDropsOnALockedSceneAreRefusedWithTheReason() throws {
        let logo = try lockedProject()
        let bg = try XCTUnwrap(Look.backgroundIDs().first)
        let inbox = makeTempDir("states-drop"); defer { try? FileManager.default.removeItem(at: inbox) }
        let png = inbox.appendingPathComponent("pic.png"); try Data([0x89, 0x50]).write(to: png)
        let rowsBefore = Assets.load(store).count
        for (item, target) in [(DragItem.resource(logo), DropTarget.scene("S02")), (.background(bg), .scene("S02")), (.files([png]), .scene("S02")),
                               (.files([png]), .contentSlot(scene: "S02", before: nil)), (.effect(Look.effects().first!), .contentItem(scene: "S02", item: "c1"))] {
            guard case .refused(let why) = Drops.verdict(item, on: target, store: store) else { return XCTFail("\(item) on \(target) should be refused") }
            XCTAssertTrue(why.contains("S02 is locked"), why)
            XCTAssertThrowsError(try Drops.drop(item, on: target, store: store))
        }
        XCTAssertEqual(Assets.load(store).count, rowsBefore, "a refused file drop adds nothing to the resources")
        guard case .ok = Drops.verdict(.scene("S02"), on: .reelSlot(before: "S01"), store: store) else { return XCTFail("moving a locked scene in the reel stays possible") }
        try Drops.drop(.scene("S02"), on: .reelSlot(before: "S01"), store: store)
        XCTAssertEqual(file.film.map { $0.id }.first, "S02")
    }

    func testClapCannotChangeALockedSceneAndTheRefusalIsJournalled() async throws {
        let logo = try lockedProject()
        let item = try XCTUnwrap(scene("S02").content.first?.id)
        let ui = ScriptedUI()
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let before = raw(), cards = ui.cards.count
        let calls: [(String, [String: Any])] = [
            ("update_scene", ["id": "S02", "text": "x"]), ("update_scene", ["id": "S02", "status": "wip"]), ("add_content_item", ["scene": "S02", "type": "text", "text": "x"]),
            ("update_content_item", ["scene": "S02", "item": item, "text": "y"]), ("remove_content_item", ["scene": "S02", "item": item]),
            ("move_content_item", ["scene": "S02", "item": item, "after": "start"]), ("set_scene_duration", ["scene": "S02", "duration": 8]),
            ("set_scene_override", ["id": "S02", "key": "background", "value": Look.backgroundIDs().first!]), ("update_asset", ["id": logo, "scenes": "S02"])]
        for (name, input) in calls {
            let out = await tools.run(name, input).text
            XCTAssertTrue(out.hasPrefix("refused:") && out.contains("S02 is locked"), "\(name): \(out)")
        }
        XCTAssertEqual(ui.cards.count, cards, "no card is shown for what is refused")
        XCTAssertEqual(raw(), before)
        XCTAssertEqual(store.journal.entries().filter { $0.state == "refused" && $0.author == "clap" }.count, calls.count, "each refusal is in the journal")
        // the way out is a card the user answers
        let un = await tools.run("lock_scene", ["scenes": ["S02"], "locked": false, "reason": "the user asked for a change"]).text
        XCTAssertTrue(un.hasPrefix("accepted and applied"), un)
        XCTAssertEqual(ui.cards.last?.title, "Unlock S02"); XCTAssertEqual(scene("S02").state, .validated)
        ui.accept = false
        let again = await tools.run("lock_scene", ["scenes": ["S02"], "locked": true]).text
        XCTAssertTrue(again.hasPrefix("refused by the user"), again); XCTAssertEqual(scene("S02").state, .validated, "no implicit lock either")
        let missing = await tools.run("lock_scene", ["scenes": ["S01"]]).text
        XCTAssertEqual(missing, "locked must be true or false")
        let notValidated = await tools.run("lock_scene", ["scenes": ["S01"], "locked": true]).text
        XCTAssertTrue(notValidated.contains("validate it before locking"), notValidated)
        let defs = Tools.definitions.compactMap { $0["name"] as? String }
        XCTAssertTrue(defs.contains("lock_scene"))
    }

    func testTheBuildMessageFlagsLockedScenes() throws {
        try validate("S01", "S02", "S03")
        XCTAssertFalse(BuildRunner.prompt(version: "v1", store: store).contains("Locked scenes"))
        try store.apply(.sceneLock(ids: ["S02", "S03"], locked: true))
        let p = BuildRunner.prompt(version: "v1", store: store)
        XCTAssertTrue(p.contains("Locked scenes (S02, S03)"), "the AI is told which scenes are fixed")
        XCTAssertTrue(p.contains("every scene is Validated or Locked"))
    }

    // MARK: the menu of the badge

    func testTheBadgeMenuOffersWhatEachStateCanReach() throws {
        func menu(_ s: ShowreelFile.Scene) -> [String] { SceneStates.choices(for: s).map { "\($0.state.rawValue)\($0.isCurrent ? "*" : "")\($0.enabled ? "+" : "-")" } }
        XCTAssertEqual(menu(scene("S01")), ["wip*-", "validated+", "locked-"], "WIP: validate; lock is not offered until it is validated")
        XCTAssertNotNil(SceneStates.choices(for: scene("S01")).last?.reason, "and it says why")
        try validate("S01")
        XCTAssertEqual(menu(scene("S01")), ["wip+", "validated*-", "locked+"])
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        let locked = SceneStates.choices(for: scene("S01"))
        XCTAssertEqual(locked.map { "\($0.state.rawValue)\($0.isCurrent ? "*" : "")\($0.enabled ? "+" : "-")" }, ["wip-", "validated+", "locked*-"])
        XCTAssertEqual(locked[1].title, "Unlock (back to Validated)"); XCTAssertNotNil(locked[0].reason)
        // each choice is an operation that the rules accept
        for c in SceneStates.choices(for: scene("S01")) { if let op = c.operation { XCTAssertNoThrow(try store.plan(op), c.title) } }
        try store.apply(try XCTUnwrap(locked[1].operation))
        for c in SceneStates.choices(for: scene("S01")) { if let op = c.operation { XCTAssertNoThrow(try store.plan(op), c.title) } }
        XCTAssertEqual(SceneState.allCases.map { $0.title }, ["WIP", "Validated", "Locked", "Ditched"])
        XCTAssertTrue(SceneState.locked.meaning.contains("place in the montage"))
    }

    func testTheLockSurvivesUndoOfEarlierWorkAndTheFileKeepsTheWord() throws {
        try validate("S01")
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        XCTAssertTrue(raw().contains("\"status\" : \"locked\""))
        let again = try XCTUnwrap(store.loadShowreel())
        XCTAssertEqual(again.scenes[0].state, .locked, "the lock is in the file: it survives closing the project")
        XCTAssertTrue(ShowreelFile.Scene.statuses.contains("locked") && !ShowreelFile.Scene.statuses.contains("ok"))
    }
}
