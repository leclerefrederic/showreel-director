import XCTest
@testable import ShowreelKit

/// Phase UI2: the Status icon, three switches (Visible, Ready, Locked), Delete scene and a real lock. The rules are ShowreelKit's; the views only draw them.
final class UI2Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!

    override func setUp() {
        dir = makeTempDir("ui2"); store = ProjectStore(root: dir)
        try? store.create(name: "U2", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three", "Four"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        store.undoLog.clear()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    func scene(_ id: String) -> ShowreelFile.Scene { file.scenes.first { $0.id == id }! }
    var idle: ProjectActivity.Snapshot { ProjectActivity.Snapshot() }
    var building: ProjectActivity.Snapshot { var s = ProjectActivity.Snapshot(); s.build = .init(version: "v1", phase: .generating); return s }
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }
    func ready(_ ids: String...) throws { for id in ids { try store.apply(.scene(id: id, SceneEdit(status: "validated"))) } }
    func lock(_ ids: String...) throws { try ready(contentsOf: ids); try store.apply(.sceneLock(ids: ids, locked: true)) }
    func ready(contentsOf ids: [String]) throws { for id in ids { try store.apply(.scene(id: id, SceneEdit(status: "validated"))) } }
    let upToDate = SceneModules.Status(state: .upToDate, moduleEdited: false)
    let stale = SceneModules.Status(state: .stale, moduleEdited: false)
    let missing = SceneModules.Status(state: .notGenerated, moduleEdited: false)
    func status(_ s: ShowreelFile.Scene, build: SceneModules.Status?, failed: String? = nil, warnings: Int = 0, visible: Bool = true) -> SceneStatus {
        SceneStatuses.status(SceneStatusInput(scene: s, visible: visible, build: build, failedTest: failed, warnings: warnings))
    }

    // MARK: the Status icon

    func testEachOfTheSixStatesAndTheirPriority() throws {
        try ready("S01")
        let wip = scene("S02"), rdy = scene("S01")
        XCTAssertEqual(status(wip, build: upToDate, failed: "boom", warnings: 2).kind, .needsAttention)
        XCTAssertEqual(status(wip, build: missing).kind, .notWritten)
        XCTAssertEqual(status(wip, build: nil).kind, .notWritten, "no version yet: no file yet")
        XCTAssertEqual(status(wip, build: stale, warnings: 1).kind, .outOfDate)
        XCTAssertEqual(status(wip, build: upToDate, warnings: 1).kind, .layoutWarning)
        XCTAssertEqual(status(wip, build: upToDate).kind, .toReview)
        XCTAssertEqual(status(rdy, build: upToDate).kind, .ready)
        XCTAssertEqual(SceneStatusKind.allCases.map { $0.symbol }.count, Set(SceneStatusKind.allCases.map { $0.symbol }).count, "six icons")
        XCTAssertEqual(SceneStatusKind.allCases.map { $0.tone }, [.red, .grey, .blue, .yellow, .orange, .green])
        XCTAssertEqual(SceneStatusKind.allCases.map { $0.title }, ["Needs attention", "Not written", "Out of date", "Layout warning", "To review", "Ready"])
    }

    func testReadyOnlyWhenTheFileIsUpToDateAndTheTooltipListsEveryState() throws {
        try ready("S01")
        let rdy = scene("S01")
        XCTAssertEqual(status(rdy, build: stale).kind, .outOfDate, "Ready but out of date is not Ready")
        XCTAssertFalse(status(rdy, build: stale).lines.contains { $0.kind == .ready })
        // several states at once: the icon is the worst, the tooltip lists them all
        let many = status(scene("S02"), build: stale, warnings: 3)
        XCTAssertEqual(many.kind, .outOfDate); XCTAssertEqual(many.lines.map { $0.kind }, [.outOfDate, .layoutWarning, .toReview])
        for l in many.lines { XCTAssertTrue(many.tooltip.contains(l.text)) }
        XCTAssertTrue(many.tooltip.contains("3 layout warnings") && many.tooltip.contains("Generate it again"), "the way to fix it")
        let hand = status(rdy, build: SceneModules.Status(state: .upToDate, moduleEdited: true))
        XCTAssertEqual(hand.kind, .ready); XCTAssertTrue(hand.tooltip.contains("Edited by hand"), "edited by hand is a line of the tooltip, not a state")
        XCTAssertEqual(SceneStatusKind.allCases.count, 6)
        let review = status(scene("S03"), build: upToDate)
        XCTAssertTrue(review.tooltip.contains("not Ready yet"))
    }

    func testTheInstructionIsInTheToReviewTooltipAndAReadySceneAskedForAChangeIsToReview() throws {
        try ready("S01")
        try store.apply(.scene(id: "S01", SceneEdit(note: "shorter, please", status: "wip")))
        let s = status(scene("S01"), build: upToDate)
        XCTAssertEqual(s.kind, .toReview); XCTAssertTrue(s.tooltip.contains("shorter, please"))
    }

    func testALockedSceneSaysWhatIsUnavailableAndWhy() throws {
        try lock("S02")
        let s = status(scene("S02"), build: stale)
        XCTAssertTrue(s.tooltip.contains("Out of date, locked: unlock it to rewrite it"), s.tooltip)
        XCTAssertTrue(status(scene("S02"), build: missing).tooltip.contains("unlock it to write it"))
        XCTAssertTrue(status(scene("S02"), build: upToDate, failed: "boom").tooltip.contains("Locked: unlock it to rewrite it"))
        XCTAssertEqual(status(scene("S02"), build: upToDate).kind, .ready, "a locked scene is Ready by construction")
    }

    func testAHiddenSceneHasOnlyItsReviewState() throws {
        try ready("S01")
        XCTAssertEqual(status(scene("S01"), build: nil, visible: false).kind, .ready)
        XCTAssertEqual(status(scene("S02"), build: nil, failed: "x", warnings: 4, visible: false).kind, .toReview, "no file in the film: nothing about a file")
    }

    func testTheListAndTheStripCallTheSameFunctionAndTheOldBadgesAreGone() throws {
        let all = try FileManager.default.contentsOfDirectory(atPath: views.path).filter { $0.hasSuffix(".swift") }.map { ($0, try source($0)) }
        for (n, t) in all { XCTAssertFalse(t.contains("SceneBadges") || t.contains("BuildIndicator") || t.contains("SceneStateBadge"), "\(n): the review round and the build square are gone") }
        XCTAssertTrue(try source("StoryboardListViews.swift").contains("SceneStatusIcon(scene: scene)"))
        XCTAssertTrue(try source("TimelineViews.swift").contains("SceneStatusIcon(scene: scene"), "the strip's frame")
        XCTAssertTrue(try source("FilmStateViews.swift").contains("SceneStatuses.status("), "one function decides")
        XCTAssertFalse(try source("FilmStateViews.swift").contains("static func mark("), "no second rule in the view")
    }

    func testTheLegendHasTheSixStatesTheEyeAndTheLock() {
        XCTAssertEqual(SceneStatuses.legend.map { $0.title }, ["Needs attention", "Not written", "Out of date", "Layout warning", "To review", "Ready", "Visible", "Locked"])
        XCTAssertEqual(SceneStatuses.legend.suffix(2).map { $0.symbol }, [IconRole.visibleOn.symbol, IconRole.lockClosed.symbol])
        XCTAssertTrue(SceneStatuses.legend.allSatisfy { !$0.meaning.isEmpty })
    }

    // MARK: the rows

    func testTheRowColumnsAndTheRoundedDuration() throws {
        try store.apply(.scene(id: "S01", SceneEdit(duration: "3.26", name: "Opening")))
        let r = StoryboardList.row(scene("S01"), in: file)
        XCTAssertEqual(r.id, "S01"); XCTAssertEqual(r.title, "Opening"); XCTAssertEqual(r.subtitle, "One"); XCTAssertEqual(r.duration, "3.3 s")
        let u = StoryboardList.row(scene("S02"), in: file)
        XCTAssertEqual(u.title, "Two"); XCTAssertEqual(u.subtitle, "", "no name: the words are the title")
        XCTAssertEqual(StoryboardList.durationText(nil), "\u{2013}"); XCTAssertEqual(StoryboardList.durationText(0.04), "0.0 s")
    }

    func testTheTransitionLineTextHasNoToAndAGlyphByType() {
        func row(_ type: String, _ s: Double?, cut: Bool = false) -> TransitionRow { TransitionRow(from: "S01", to: "S02", type: type, seconds: s, isCut: cut, marks: []) }
        XCTAssertEqual(StoryboardList.text(row("Flip card", 0.55)), "Flip card \u{00B7} 0.55 s")
        XCTAssertEqual(StoryboardList.text(row("cut", nil, cut: true)), "Cut")
        XCTAssertEqual(StoryboardList.glyph("cut", isCut: true), "scissors")
        XCTAssertNotEqual(StoryboardList.glyph("Flip card", isCut: false), StoryboardList.glyph("Cross dissolve", isCut: false))
    }

    func testDitchedAndArchivedScenesAreHiddenScenesAndShowingOneBringsItBack() throws {
        try store.apply(.scene(id: "S02", SceneEdit(note: "too long", status: "ditched")))
        try store.apply(.scene(id: "S03", SceneEdit(archived: true)))
        let l = StoryboardList.build(file, store: store)
        XCTAssertEqual(l.notIn.map { $0.id }, ["S02", "S03"])
        XCTAssertEqual(l.notIn[0].note, "Was ditched. Note: too long"); XCTAssertEqual(l.notIn[1].note, "Was archived.")
        XCTAssertTrue(l.notIn.allSatisfy { $0.wayBack == "Show" })
        try store.apply(.sceneEnabled(id: "S02", enabled: true, montage: nil))
        XCTAssertEqual(scene("S02").state, .wip); XCTAssertFalse(scene("S02").archived); XCTAssertTrue(file.film.map { $0.id }.contains("S02"))
        XCTAssertEqual(file.scenes.first { $0.id == "S02" }?.note, "too long", "the reason stays as the instruction")
    }

    // MARK: the switches

    func testVisibleReadyAndLockedAvailability() throws {
        let s1 = scene("S01")
        XCTAssertNotNil(SceneSwitches.visible(s1, in: file, activity: idle).operation)
        XCTAssertEqual(SceneSwitches.ready(s1, activity: idle).operation, .scene(id: "S01", SceneEdit(status: "validated")))
        let notReady = SceneSwitches.locked(s1, activity: idle)
        XCTAssertNil(notReady.operation); XCTAssertEqual(notReady.unavailable?.reason, "Make the scene Ready first"); XCTAssertFalse(notReady.unavailable?.way.isEmpty ?? true)
        try ready("S01")
        XCTAssertEqual(SceneSwitches.locked(scene("S01"), activity: idle).operation, .sceneLock(ids: ["S01"], locked: true))
        XCTAssertEqual(SceneSwitches.ready(scene("S01"), activity: idle).operation, .scene(id: "S01", SceneEdit(status: "wip")), "Ready off gives To review")
        try store.apply(SceneSwitches.ready(scene("S01"), activity: idle).operation!)
        XCTAssertEqual(scene("S01").state, .wip)
    }

    func testALockedSceneRefusesVisibleReadyAndDeleteWithItsReasonButCanBeUnlocked() throws {
        try lock("S02")
        let s = scene("S02")
        for sw in [SceneSwitches.visible(s, in: file, activity: idle), SceneSwitches.ready(s, activity: idle), SceneSwitches.delete(s, activity: idle)] {
            XCTAssertNil(sw.operation); XCTAssertTrue(sw.unavailable?.reason.contains("S02 is locked") == true); XCTAssertFalse(sw.unavailable?.way.isEmpty ?? true, "and how to get out of it")
        }
        XCTAssertEqual(SceneSwitches.locked(s, activity: idle).operation, .sceneLock(ids: ["S02"], locked: false), "unlocking is always possible")
        XCTAssertTrue(SceneSwitches.ready(s, activity: idle).on, "a locked scene is Ready")
    }

    func testDuringABuildEverySwitchSaysSo() throws {
        let s = scene("S01")
        for sw in [SceneSwitches.visible(s, in: file, activity: building), SceneSwitches.ready(s, activity: building), SceneSwitches.locked(s, activity: building), SceneSwitches.delete(s, activity: building)] {
            XCTAssertNil(sw.operation); XCTAssertEqual(sw.unavailable, Reasons.building)
        }
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }; defer { store.activity.update { $0.build = nil } }
        XCTAssertThrowsError(try store.plan(.deleteScene(id: "S01"))) { XCTAssertTrue($0.localizedDescription.contains("Building")) }
    }

    // MARK: Delete scene

    func testDeleteIsConfirmedNamesWhatIsLostIsJournalledAndUndoRestoresTheSceneAndItsPlace() throws {
        try store.apply(.scene(id: "S02", SceneEdit(name: "Middle")))
        try store.apply(.transition(from: "S02", TransitionEdit(type: "Push", duration: 0.5)))
        let before = file
        let losses = store.deletionLosses("S02")
        XCTAssertTrue(losses.contains { $0.contains("Two") } && losses.contains { $0.contains("element") } && losses.contains { $0.contains("Push") }, "\(losses)")
        let p = SceneSwitches.deletePrompt(scene("S02"), losses: losses)
        XCTAssertEqual(p.title, "Delete scene S02 \u{00B7} Middle?"); XCTAssertTrue(p.message.contains("loses") && p.message.contains("never given") && p.message.contains("Undo"), p.message)
        let card = try store.plan(.deleteScene(id: "S02"))
        XCTAssertEqual(card.title, "Delete scene S02 \u{00B7} Middle"); XCTAssertTrue(card.changes.contains { $0.label == "Lost" })
        try store.apply(.deleteScene(id: "S02"))
        XCTAssertNil(file.scenes.first { $0.id == "S02" }); XCTAssertEqual(file.film.map { $0.id }, ["S01", "S03", "S04"])
        let j = try XCTUnwrap(store.journal.entries().last); XCTAssertEqual(j.op, "deleteScene"); XCTAssertEqual(j.target, "S02")
        // its ID is never given again
        try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "New")))
        XCTAssertNil(file.scenes.first { $0.id == "S02" }); XCTAssertEqual(file.scenes.last?.id, "S05")
        XCTAssertThrowsError(try store.plan(.addScene(id: "S02", SceneEdit(text: "x"))))
        try store.undo()                        // the new scene
        try store.undo()                        // the deletion
        XCTAssertEqual(file.scenes.map { $0.id }, before.scenes.map { $0.id }); XCTAssertEqual(file.film.map { $0.id }, ["S01", "S02", "S03", "S04"], "back in its place")
        XCTAssertEqual(scene("S02").name, "Middle"); XCTAssertEqual(file.storyboards.first?.items.first { $0.scene == "S02" }?.transition.type, "Push", "with its transition")
    }

    func testDeleteUnlinksItsResourcesAndUndoLinksThemAgain() throws {
        let inbox = makeTempDir("ui2-inbox"); defer { try? FileManager.default.removeItem(at: inbox) }
        let svg = inbox.appendingPathComponent("Acme Logo.svg"); try "x".write(to: svg, atomically: true, encoding: .utf8)
        try Assets.add([svg], to: store)
        try store.apply(.scene(id: "S02", SceneEdit(assets: "logo-01")))
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, ["S02"])
        XCTAssertTrue(store.deletionLosses("S02").contains { $0.contains("link to") })
        try store.apply(.deleteScene(id: "S02"))
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, [])
        try store.undo()
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, ["S02"])
    }

    func testDeleteIsRefusedOnALockedScene() throws {
        try lock("S02")
        XCTAssertThrowsError(try store.plan(.deleteScene(id: "S02"))) { XCTAssertEqual($0.localizedDescription, "S02 is locked: unlock it first") }
        XCTAssertNotNil(file.scenes.first { $0.id == "S02" })
    }

    // MARK: the lock

    func testALockedSceneRefusesAChangeElsewhereThatWouldMoveItsStart() throws {
        try lock("S03")                                  // starts at 6 s: 0:06
        let why = "S03 is locked at 0:06: unlock it, or change a scene after it"
        let before = try XCTUnwrap(store.read(ShowreelFile.fileName))
        let refused: [(String, ProjectOperation)] = [
            ("a scene inserted before it", .addScene(id: "", SceneEdit(duration: "3", text: "New", after: "start"))),
            ("a scene deleted before it", .deleteScene(id: "S01")),
            ("a scene hidden before it", .sceneEnabled(id: "S01", enabled: false, montage: nil)),
            ("an earlier scene lengthened", .resize(scene: "S01", duration: 5)),
            ("an earlier scene shortened", .scene(id: "S02", SceneEdit(duration: "2"))),
            ("an earlier scene moved after it", .moveScene(id: "S01", after: "S03", montage: nil)),
        ]
        for (what, op) in refused {
            XCTAssertThrowsError(try store.plan(op), what) { XCTAssertEqual($0.localizedDescription, why, what) }
            XCTAssertThrowsError(try store.apply(op), what)
        }
        XCTAssertEqual(store.read(ShowreelFile.fileName), before, "refusing writes nothing")
        // changes after it, and its own transition, are free
        try store.apply(.scene(id: "S04", SceneEdit(duration: "9")))
        try store.apply(.transition(from: "S03", TransitionEdit(type: "Push", duration: 0.5)))
        try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Last")))
        XCTAssertEqual(file.timeline().first { $0.scene.id == "S03" }?.start, 6)
    }

    func testAHiddenLockedSceneIsFrozenToo() throws {
        try ready("S02")
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        XCTAssertThrowsError(try store.plan(.sceneEnabled(id: "S02", enabled: true, montage: nil))) { XCTAssertEqual($0.localizedDescription, "S02 is locked: unlock it first") }
        XCTAssertThrowsError(try store.plan(.moveScene(id: "S02", after: "S03", montage: nil)))
        XCTAssertThrowsError(try store.plan(.deleteScene(id: "S02")))
        // the scene right before it cannot be taken away from its side either
        XCTAssertThrowsError(try store.plan(.moveScene(id: "S01", after: "S03", montage: nil))) { XCTAssertTrue($0.localizedDescription.hasPrefix("S02 is locked (hidden, after S01)"), $0.localizedDescription) }
    }

    func testLockingKeepsACopyOfTheLookAndAGlobalChangeNoLongerReachesTheScene() throws {
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        try ready("S02")
        XCTAssertNil(scene("S02").lockedLook)
        let card = try store.plan(.sceneLock(ids: ["S02"], locked: true))
        XCTAssertTrue(card.changes.contains { $0.label == "S02 look" })
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        let kept = try XCTUnwrap(scene("S02").lockedLook)
        XCTAssertEqual(kept.palette, ["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2"])
        let change = DecisionChange(.palette, "#000005, #FFFFFF, #FF0000, #00FF00")
        let cardAfter = try store.plan(.decisions([change], title: nil))
        XCTAssertNil(cardAfter.lockWarning, "the apply-anyway card no longer lists a locked scene that has its copy")
        try store.apply(.decisions([change], title: nil))
        XCTAssertEqual(file.effective(.palette, for: scene("S02")), "#101820, #FFFFFF, #F2AA4C, #4CC2F2", "the locked scene keeps the look it had")
        XCTAssertEqual(file.effective(.palette, for: scene("S01")), "#000005, #FFFFFF, #FF0000, #00FF00", "the others follow")
        XCTAssertNotEqual(SceneModules.inputs(of: scene("S02"), in: file), "", "its fingerprint did not move: it is not out of date")
    }

    func testUnlockingDropsTheCopyAndSaysWhenTheLookWouldChange() throws {
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        try lock("S02")
        XCTAssertNil(LockedLook.unlockNote(scene("S02"), in: file), "the copy is the look now: nothing to say")
        try store.apply(.decisions([DecisionChange(.palette, "#000005, #FFFFFF, #FF0000, #00FF00")], title: nil))
        XCTAssertEqual(LockedLook.unlockNote(scene("S02"), in: file), "it follows the project's look again: palette will change")
        let card = try store.plan(.sceneLock(ids: ["S02"], locked: false))
        XCTAssertTrue(card.changes.contains { $0.label == "S02 look" && $0.after.contains("palette") }, "said on the unlock card")
        try store.apply(.sceneLock(ids: ["S02"], locked: false))
        XCTAssertNil(scene("S02").lockedLook); XCTAssertEqual(file.effective(.palette, for: scene("S02")), "#000005, #FFFFFF, #FF0000, #00FF00")
        try store.undo()
        XCTAssertNotNil(scene("S02").lockedLook, "Undo brings the lock and its copy back")
    }

    func testALegacyLockedSceneWithNoCopyStillFollowsTheProjectAndIsListedOnTheCard() throws {
        try lock("S02")
        try stripLockedLook(store, ["S02"])
        let card = try store.plan(.decisions([DecisionChange(.palette, "#000005, #FFFFFF, #FF0000, #00FF00")], title: nil))
        XCTAssertEqual(card.lockWarning?.scenes, ["S02"], "a project locked before UI2: as before, until the scene is locked again")
    }

    func testALockedSceneIsNeverRewrittenByABuildGenerateOrFix() async throws {
        try lock("S02")
        let f = file
        // a locked scene with no file yet: excluded, listed as locked on the card, never written, even by Rewrite everything
        for force in [false, true] {
            let p = BuildJob.plan(version: "v1", store: store, force: force)
            XCTAssertFalse(p.write.contains("S02"), "force: \(force)"); XCTAssertEqual(p.locked, ["S02"]); XCTAssertEqual(p.skipped, ["S02"])
        }
        let card = BuildJob.card(BuildJob.plan(version: "v1", store: store), store: store, skill: try XCTUnwrap(Skill.root()), resuming: false)
        let line = try XCTUnwrap(card.changes.first { $0.label.hasPrefix("Locked: S02") })
        XCTAssertTrue(line.before.contains("never rewritten") && line.after.contains("empty frame"), "\(line)")
        XCTAssertEqual(SceneGeneration.refusal("S02", version: "v1", in: f, store: store), SceneLock.reason("S02"), "Generate and Fix this scene")
    }

    // MARK: the Go and the existing projects

    func testTheGoReadsEveryVisibleSceneAndIgnoresTheHiddenOnes() throws {
        try store.apply(.gate("storyboard", passed: true))
        XCTAssertTrue(store.goBlocking()?.contains("not Ready") == true)
        try ready("S01", "S02", "S03")
        try store.apply(.sceneLock(ids: ["S03"], locked: true))
        XCTAssertTrue(store.goBlocking()?.contains("S04") == true, "S04 is not Ready")
        try store.apply(.sceneEnabled(id: "S04", enabled: false, montage: nil))
        XCTAssertNil(store.goBlocking(), "a locked scene counts, a hidden one is ignored")
        let r = Checks.run(area: "scene", store: store).first { $0.id == "review.all" }
        XCTAssertEqual(r?.title, "Every visible scene is Ready"); XCTAssertEqual(r?.level, .ok)
        try store.apply(.sceneEnabled(id: "S04", enabled: true, montage: nil))
        let bad = Checks.run(area: "scene", store: store).first { $0.id == "review.all" }
        XCTAssertEqual(bad?.level, .pending); XCTAssertTrue(bad?.detail.contains("S04 not Ready yet") == true, bad?.detail ?? "")
        let build = BuildRunner.readiness(store).first { $0.id == "build.reviewed" }
        XCTAssertTrue(build?.detail.contains("S04 not Ready yet") == true)
    }

    func testAnExistingProjectIsReadWithoutMigration() throws {
        // a locked scene with no Ready before, a scene validated, one with a modify note, an ditched one: all read as the new model says, the file untouched
        var f = file
        f.scenes[0].status = "locked"; f.scenes[1].status = "validated"
        f.scenes[2].status = "wip"; f.scenes[2].note = "make it shorter"
        f.scenes[3].status = "ditched"; f.scenes[3].archived = true
        try store.save(f)
        let raw = try XCTUnwrap(store.read(ShowreelFile.fileName))
        XCTAssertTrue(file.scenes[0].state.isReviewed, "a locked scene is Ready by construction"); XCTAssertEqual(file.scenes[0].state.title, "Locked")
        XCTAssertTrue(file.scenes[1].state.isReviewed); XCTAssertEqual(file.scenes[1].state.title, "Ready", "validated before this phase: Ready")
        XCTAssertEqual(status(file.scenes[2], build: upToDate).kind, .toReview); XCTAssertTrue(status(file.scenes[2], build: upToDate).tooltip.contains("make it shorter"))
        let l = StoryboardList.build(file, store: store)
        XCTAssertEqual(l.notIn.map { $0.id }, ["S04"]); XCTAssertEqual(l.notIn[0].note, "Was ditched.")
        XCTAssertEqual(store.read(ShowreelFile.fileName), raw, "reading writes nothing")
        // the stored words did not change
        XCTAssertTrue(raw.contains("\"validated\"") && raw.contains("\"locked\"") && raw.contains("\"ditched\""))
    }

    // MARK: Clap

    func testSetReadyAndDeleteSceneAreOnlyEverCardsEvenWithApplyDirectly() async throws {
        var s = store.settings; s.applyDirectly = true; store.settings = s
        let ui = ScriptedUI(); ui.accept = false
        let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let r1 = await tools.run("set_ready", ["id": "S01", "ready": true]).text
        XCTAssertTrue(r1.hasPrefix("refused by the user"), r1); XCTAssertEqual(ui.cards.count, 1, "a card, though apply-directly is on"); XCTAssertEqual(scene("S01").state, .wip)
        let r2 = await tools.run("delete_scene", ["id": "S02"]).text
        XCTAssertTrue(r2.hasPrefix("refused by the user"), r2); XCTAssertEqual(ui.cards.count, 2); XCTAssertNotNil(file.scenes.first { $0.id == "S02" })
        ui.accept = true
        let ok = await tools.run("set_ready", ["id": "S01", "ready": true]).text
        XCTAssertTrue(ok.hasPrefix("accepted and applied"), ok); XCTAssertEqual(scene("S01").state, .validated)
        let del = await tools.run("delete_scene", ["id": "S02"]).text
        XCTAssertTrue(del.hasPrefix("accepted and applied"), del); XCTAssertNil(file.scenes.first { $0.id == "S02" })
        // other changes still apply directly with the setting, but Clap cannot set the review state through them
        let ui2 = ScriptedUI(); let t2 = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui2)
        let viaUpdate = await t2.run("update_scene", ["id": "S03", "status": "validated", "text": "Three!"]).text
        XCTAssertTrue(viaUpdate.hasPrefix("applied directly"), viaUpdate); XCTAssertEqual(scene("S03").state, .wip, "the status of update_scene is ignored: set_ready is the way")
        let viaArchive = await t2.run("update_scene", ["id": "S03", "archived": true, "note": "x"]).text
        XCTAssertFalse(scene("S03").archived, viaArchive)
    }

    func testTheReviewToolsAreGoneFromTheToolDefinitions() throws {
        let defs = Tools.definitions
        let names = defs.compactMap { $0["name"] as? String }
        XCTAssertTrue(names.contains("set_ready") && names.contains("delete_scene") && names.contains("lock_scene"))
        for n in ["add_scene", "update_scene"] {
            let props = ((defs.first { $0["name"] as? String == n }?["input_schema"] as? [String: Any])?["properties"] as? [String: Any]) ?? [:]
            XCTAssertNil(props["status"], n); XCTAssertNil(props["archived"], n); XCTAssertNotNil(props["note"], "the instruction")
        }
        let doc = (defs.first { $0["name"] as? String == "set_ready" }?["description"] as? String) ?? ""
        XCTAssertTrue(doc.contains("always a card"))
        XCTAssertFalse(names.contains { ["ok_scene", "modify_scene", "ditch_scene", "archive_scene"].contains($0) })
    }

    func testTheInterfaceHasNoOKModifyDitchOrArchive() throws {
        for n in ["StoryboardViews.swift", "StoryboardListViews.swift", "InspectorViews.swift", "TimelineViews.swift", "WorkspaceViews.swift", "SceneStateViews.swift"] {
            let t = try source(n)
            for w in ["\"MODIFY\"", "\"DITCH\"", "\"OK\"", "Button(\"Archive", "archiveScene", "SceneDecision"] { XCTAssertFalse(t.contains(w), "\(n) offers \(w)") }
        }
        let insp = try source("InspectorViews.swift"), sw = try source("StoryboardViews.swift")
        XCTAssertTrue(insp.contains("SceneSwitchesView(id: id)"))
        for w in ["\"Visible\"", "\"Ready\"", "\"Locked\"", "Delete scene"] { XCTAssertTrue(sw.contains(w), w) }
        XCTAssertEqual(SceneState.allCases.prefix(3).map { $0.title }, ["To review", "Ready", "Locked"])
    }
}
