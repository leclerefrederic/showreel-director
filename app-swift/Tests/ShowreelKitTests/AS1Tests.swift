import XCTest
@testable import ShowreelKit

/// AS1: no Save button; what you type or add is saved.
final class AS1Tests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }
    func session() -> EditSession {
        var s = EditSession(validate: SceneFields.invalid)
        s.load("text", stored: "old", kind: .text); s.load("duration", stored: "3", kind: .numeric); s.load("assets", stored: "", kind: .instant)
        return s
    }

    // MARK: the session rule

    func testTextCommitsOnBlurOnReturnAndAfterThePauseNotBefore() {
        var s = session()
        XCTAssertNil(s.edit("text", draft: "new", at: at(0)))
        XCTAssertTrue(s.due(at: at(0.5)).isEmpty, "not before the pause")
        XCTAssertEqual(s.due(at: at(0.7)), [.init(key: "text", value: "new")])
        XCTAssertTrue(s.due(at: at(5)).isEmpty, "a commit is taken once")
        s.stored("text", "new")
        _ = s.edit("text", draft: "newer", at: at(10)); XCTAssertEqual(s.blur("text")?.value, "newer")
        s.stored("text", "newer")
        _ = s.edit("text", draft: "again", at: at(11)); XCTAssertEqual(s.returnKey("text")?.value, "again")
    }

    func testANumericFieldCommitsOnBlurReturnOrAfterAStepDebounced() {
        var s = session()
        _ = s.edit("duration", draft: "4", at: at(0))
        XCTAssertTrue(s.due(at: at(5)).isEmpty, "typing a number waits for focus loss or Return")
        XCTAssertEqual(s.blur("duration")?.value, "4"); s.stored("duration", "4")
        _ = s.edit("duration", draft: "5", at: at(10), stepped: true); _ = s.edit("duration", draft: "6", at: at(10.2), stepped: true); _ = s.edit("duration", draft: "7", at: at(10.4), stepped: true)
        XCTAssertTrue(s.due(at: at(10.6)).isEmpty, "holding a chevron: no commit per tick")
        XCTAssertEqual(s.due(at: at(10.7)), [.init(key: "duration", value: "7")], "one commit")
    }

    func testASwitchCommitsAtOnce() {
        var s = session()
        XCTAssertEqual(s.edit("assets", draft: "A01", at: at(0)), .init(key: "assets", value: "A01"))
    }

    func testAnInvalidValueNeverCommitsAndTheDraftStays() {
        var s = session()
        _ = s.edit("duration", draft: "abc", at: at(0), stepped: true)
        XCTAssertNotNil(s.field("duration")?.invalid)
        XCTAssertNil(s.blur("duration")); XCTAssertTrue(s.due(at: at(9)).isEmpty); XCTAssertTrue(s.flush().isEmpty)
        XCTAssertEqual(s.field("duration")?.draft, "abc", "the owner's draft is kept")
        _ = s.edit("duration", draft: "-2", at: at(1)); XCTAssertNotNil(s.field("duration")?.invalid)
        s.restore("duration"); XCTAssertEqual(s.field("duration")?.draft, "3"); XCTAssertNil(s.field("duration")?.invalid)
        _ = s.edit("duration", draft: "2,5", at: at(2)); XCTAssertEqual(s.blur("duration")?.value, "2,5", "a comma is read")
    }

    func testAPendingEditIsFlushedBeforeASceneSwitchATabAWindowCloseOrABuild() {
        var s = session()
        _ = s.edit("text", draft: "typed", at: at(0))
        XCTAssertEqual(s.pending, ["text"])
        XCTAssertEqual(s.flush(), [.init(key: "text", value: "typed")], "every one of those moments is a flush")
        s.stored("text", "typed"); XCTAssertTrue(s.pending.isEmpty)
        s.close(); XCTAssertNil(s.field("text"))
    }

    func testAChangeMadeElsewhereUpdatesACleanFieldAndNeverOverwritesADirtyOne() {
        var s = session()
        XCTAssertEqual(s.load("text", stored: "by Clap", kind: .text), .updated); XCTAssertEqual(s.field("text")?.draft, "by Clap")
        _ = s.edit("text", draft: "mine", at: at(0))
        XCTAssertEqual(s.load("text", stored: "by Clap again", kind: .text), .keptDraft)
        XCTAssertEqual(s.field("text")?.draft, "mine")
        XCTAssertEqual(s.blur("text")?.value, "mine", "the owner's commit wins")
    }

    func testToReviewIsAnnouncedOncePerSession() {
        var s = session()
        XCTAssertTrue(s.announceReview("S02")); XCTAssertFalse(s.announceReview("S02")); XCTAssertTrue(s.announceReview("S03"))
        s.close(); XCTAssertTrue(s.announceReview("S02"))
    }

    // MARK: the store

    func makeStore() throws -> (ProjectStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("as1-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ProjectStore(root: dir)
        try store.create(name: "T", conversationLanguage: "en", reelLanguages: ["en"])
        try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "start")))
        return (store, dir)
    }

    func commit(_ store: ProjectStore, _ field: String, _ value: String, at now: Date) throws {
        try store.apply(.scene(id: "S01", SceneFields.edit(field, value)))
        store.coalesceLast(key: SceneFields.undoKey("S01", field), now: now)
    }

    func testCommitsToOneFieldInTwoSecondsAreOneUndoStepAndRedoWorks() throws {
        let (store, dir) = try makeStore(); defer { try? FileManager.default.removeItem(at: dir) }
        let base = store.undoLog.undoCount
        try commit(store, "text", "a", at: at(0)); try commit(store, "text", "ab", at: at(1)); try commit(store, "text", "abc", at: at(2))
        XCTAssertEqual(store.undoLog.undoCount, base + 1, "one step")
        try store.undo(); XCTAssertEqual(store.loadShowreel()?.scenes.first?.text, "start", "Undo restores the previous stored value, in one press")
        try store.redo(); XCTAssertEqual(store.loadShowreel()?.scenes.first?.text, "abc", "Redo puts the edit back")
        XCTAssertEqual(store.undoLog.undoCount, base + 1, "undo and redo record no fresh edit")
    }

    func testAPauseOrAnotherFieldStartsANewUndoStep() throws {
        let (store, dir) = try makeStore(); defer { try? FileManager.default.removeItem(at: dir) }
        let base = store.undoLog.undoCount
        try commit(store, "text", "a", at: at(0)); try commit(store, "text", "ab", at: at(5))
        XCTAssertEqual(store.undoLog.undoCount, base + 2, "a pause longer than the window")
        try commit(store, "feeling", "calm", at: at(5.5)); XCTAssertEqual(store.undoLog.undoCount, base + 3, "another field")
        try store.undo(); XCTAssertEqual(store.loadShowreel()?.scenes.first?.feeling, "")
        XCTAssertEqual(store.loadShowreel()?.scenes.first?.text, "ab")
    }

    func testTheJournalHasOneEntryPerCommit() throws {
        let (store, dir) = try makeStore(); defer { try? FileManager.default.removeItem(at: dir) }
        let before = store.journal.entries().count
        try commit(store, "text", "a", at: at(0)); try commit(store, "text", "ab", at: at(1))
        XCTAssertGreaterThanOrEqual(store.journal.entries().count - before, 2, "both commits are in the journal even when one undo step holds them")
    }

    func testALockedSceneRefusesWithItsReason() throws {
        let (store, dir) = try makeStore(); defer { try? FileManager.default.removeItem(at: dir) }
        try store.apply(.scene(id: "S01", SceneEdit(status: "validated")))
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneFields.edit("text", "no"))))
    }

    // MARK: the form

    func testTheFormHasNoSaveOrRevertAndTheOtherSurfacesKeepWhatMustBeExplicit() throws {
        let views = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        let form = try String(contentsOf: views.appendingPathComponent("StoryboardViews.swift"), encoding: .utf8)
        XCTAssertFalse(form.contains("Save scene")); XCTAssertFalse(form.contains("Button(\"Revert\")"))
        XCTAssertFalse(form.contains("sends this scene back to To review."), "the helper sentence is gone: the status line says it once")
        let look = try String(contentsOf: views.appendingPathComponent("LookViews.swift"), encoding: .utf8)
        XCTAssertFalse(look.contains("Save palette")); XCTAssertFalse(look.contains("Button(\"Revert\")"))
        let pkg = try String(contentsOf: views.appendingPathComponent("PackageViews.swift"), encoding: .utf8)
        XCTAssertTrue(pkg.contains("Save in the library"), "a package is saved on purpose")
    }
}
