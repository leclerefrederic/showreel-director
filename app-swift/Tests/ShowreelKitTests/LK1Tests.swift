import XCTest
@testable import ShowreelKit

/// LK1 (DECISION-028): a project opened by the app gives each scene locked before UI2 a copy of its look. Every test works on a temporary project, never on the owner's.
final class LK1Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let oldPalette = "#101820, #FFFFFF, #F2AA4C, #4CC2F2", newPalette = "#000005, #FFFFFF, #FF0000, #00FF00"

    override func setUp() {
        dir = makeTempDir("lk1"); store = ProjectStore(root: dir)
        try? store.create(name: "L1", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three", "Four"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        try? store.apply(.decisions([DecisionChange(.palette, oldPalette)], title: nil))
        store.undoLog.clear()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    func scene(_ id: String) -> ShowreelFile.Scene { file.scenes.first { $0.id == id }! }
    var raw: String { store.read(ShowreelFile.fileName) ?? "" }

    /// S01 locked before UI2 (no copy), S02 locked after UI2 (with its copy), S03 Ready, S04 in progress.
    func makeOldProject() throws {
        for id in ["S01", "S02", "S03"] { try store.apply(.scene(id: id, SceneEdit(status: "validated"))) }
        try store.apply(.sceneLock(ids: ["S01", "S02"], locked: true))
        try stripLockedLook(store, ["S01"])
    }

    func testAPreUI2LockedSceneGetsItsCopyAndTheFileChangesOnlyThere() throws {
        try makeOldProject()
        let before = file
        XCTAssertEqual(LockedLookMigration.pending(in: before), ["S01"])
        XCTAssertEqual(LockedLookMigration.run(store), ["S01"])
        var expected = before; expected.scenes[0].lockedLook = LockedLook.copy(of: before.scenes[0], in: before)
        XCTAssertEqual(file, expected, "only S01's copy is new")
        XCTAssertEqual(scene("S01").lockedLook?.palette, ["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2"], "the copy is the look in use")
        XCTAssertEqual(file.effective(.palette, for: scene("S01")), before.effective(.palette, for: before.scenes[0]), "nothing changes on screen")
    }

    func testASecondOpenWritesNothingAndTheJournalLineIsWrittenOnce() throws {
        try makeOldProject()
        XCTAssertEqual(LockedLookMigration.run(store), ["S01"])
        let after = raw, mtime = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(ShowreelFile.fileName).path)[.modificationDate] as? Date
        usleep(20_000)
        XCTAssertEqual(LockedLookMigration.run(store), [])
        XCTAssertEqual(raw, after)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(ShowreelFile.fileName).path)[.modificationDate] as? Date, mtime, "no spurious change of the date")
        let lines = store.journal.entries().filter { $0.op == "lockedLook" }
        XCTAssertEqual(lines.count, 1); XCTAssertEqual(lines[0].title, "Locked scenes took a copy of their look: 1 scene"); XCTAssertEqual(lines[0].author, "app"); XCTAssertEqual(lines[0].target, "S01")
    }

    func testUnlockedScenesAndScenesLockedAfterUI2AreUntouchedAndNothingIsWrittenWithoutAnOldLock() throws {
        for id in ["S01", "S02"] { try store.apply(.scene(id: id, SceneEdit(status: "validated"))) }
        try store.apply(.sceneLock(ids: ["S02"], locked: true))
        let before = raw
        XCTAssertEqual(LockedLookMigration.run(store), [])
        XCTAssertEqual(raw, before, "unlocked and already-copied scenes: no write at all")
        XCTAssertTrue(store.journal.entries().filter { $0.op == "lockedLook" }.isEmpty)
        XCTAssertNil(scene("S01").lockedLook); XCTAssertNil(scene("S03").lockedLook); XCTAssertNil(scene("S04").lockedLook)
    }

    func testAfterAGlobalLookChangeTheMigratedSceneKeepsItsLookAndAnUnmigratedControlFollows() throws {
        try makeOldProject()
        try store.apply(.scene(id: "S04", SceneEdit(status: "validated"))); try store.apply(.sceneLock(ids: ["S04"], locked: true)); try stripLockedLook(store, ["S04"])
        LockedLookMigration.run(store)
        let control = try { () -> ShowreelFile in var f = file; f.scenes[3].lockedLook = nil; return f }()          // S04 as if it had not been migrated
        try store.apply(.decisions([DecisionChange(.palette, newPalette)], title: nil))
        XCTAssertEqual(file.effective(.palette, for: scene("S01")), oldPalette, "the migrated scene keeps its old look")
        var after = control; after.decisions = file.decisions
        XCTAssertEqual(after.effective(.palette, for: after.scenes[3]), newPalette, "the unmigrated control follows the change")
    }

    func testAProjectWithNoDecisionsStillKeepsItsCopyAcrossTheRoundTrip() throws {
        var f = file; f.decisions = ShowreelFile.Decisions()
        for i in f.scenes.indices { f.scenes[i].status = "validated" }
        f.scenes[0].status = "locked"; try store.save(f)
        XCTAssertEqual(LockedLookMigration.run(store), ["S01"])
        XCTAssertNotNil(scene("S01").lockedLook, "an empty copy is still a copy")
        XCTAssertEqual(LockedLookMigration.run(store), [], "so a second open finds nothing to do")
    }

    func testAnOutdatedProjectOrAnUnreadableFileIsLeftAlone() throws {
        try makeOldProject()
        var f = file; f.formatRevision = 1; try store.save(f)
        let outdated = raw
        XCTAssertEqual(LockedLookMigration.run(store), []); XCTAssertEqual(raw, outdated, "nothing is written before Update project")
        try store.write(ShowreelFile.fileName, "not json", source: .user)
        XCTAssertEqual(LockedLookMigration.run(store), []); XCTAssertEqual(raw, "not json")
    }

    func testTheCopyIsNotAnUndoStepSoTheMigrationCannotBeUndoneIntoTheOldState() throws {
        try makeOldProject(); store.undoLog.clear()
        LockedLookMigration.run(store)
        XCTAssertFalse(store.undoLog.canUndo, "the journal line is an event, not an operation")
    }

    func testTheSummaryAndTheOpeningOfTheModel() throws {
        XCTAssertEqual(LockedLookMigration.summary(1), "Locked scenes took a copy of their look: 1 scene")
        XCTAssertEqual(LockedLookMigration.summary(3), "Locked scenes took a copy of their look: 3 scenes")
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        let m = try String(contentsOf: dir.appendingPathComponent("ProjectModel.swift"), encoding: .utf8)
        let run = try XCTUnwrap(m.range(of: "LockedLookMigration.run(store)")), first = try XCTUnwrap(m.range(of: "store.loadShowreel()?.snapLevel()"))
        XCTAssertLessThan(run.lowerBound, first.lowerBound, "the copies are taken before anything reads the file for drawing")
        XCTAssertTrue(m.contains("showToast(LockedLookMigration.summary(migrated.count)"))
    }
}
