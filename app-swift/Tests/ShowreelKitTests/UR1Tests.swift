import XCTest
@testable import ShowreelKit

/// UR1 (IDEA-052): Undo and Redo in the rail, and a history menu that goes back several steps as one operation.
final class UR1Tests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!

    override func setUp() {
        dir = makeTempDir("ur1"); store = ProjectStore(root: dir)
        try? store.create(name: "U1", conversationLanguage: "en", reelLanguages: ["en"])
        store.undoLog.clear()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func source(_ name: String) throws -> String {
        let d = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        return try String(contentsOf: d.appendingPathComponent(name), encoding: .utf8)
    }
    /// The two data files the undo log keeps.
    private var texts: [String?] { ProjectStore.undoTexts.map { store.read($0) } }
    /// n scenes added one by one; the data after each step (index 0: before the first).
    @discardableResult private func addScenes(_ n: Int) throws -> [[String?]] {
        var states = [texts]
        for i in 1...n { try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Scene \(i)"))); states.append(texts) }
        return states
    }

    func testUndoOfNStepsLeavesTheSameFilesAsNSingleUndosAndRedoOfNRestoresThem() throws {
        let states = try addScenes(5)
        let titles = try store.undo(steps: 3)
        XCTAssertEqual(titles.count, 3); XCTAssertEqual(texts, states[2])
        XCTAssertEqual(store.undoLog.undoCount, 2); XCTAssertEqual(store.undoLog.redos.count, 3)
        let again = try store.redo(steps: 3)
        XCTAssertEqual(texts, states[5]); XCTAssertEqual(again.count, 3); XCTAssertEqual(again, titles.reversed(), "the nearest first on the way back")
        // the same as single steps
        for _ in 0..<3 { try store.undo() }
        XCTAssertEqual(texts, states[2])
    }

    func testTheMenuListMatchesTheStackInOrderCountAndSide() throws {
        try addScenes(25)
        let h = store.undoLog.history()
        XCTAssertEqual(h.undo.count, UndoHistory.menuLimit); XCTAssertEqual(h.undo.map { $0.steps }, Array(1...UndoHistory.menuLimit))
        XCTAssertEqual(h.undo.first?.title, store.undoLog.undoTitle, "newest first")
        XCTAssertTrue(h.redo.isEmpty)
        try store.undo(steps: 3)
        let after = store.undoLog.history()
        XCTAssertEqual(after.redo.count, 3, "the undone ones are on the other side"); XCTAssertEqual(after.redo.first?.title, store.undoLog.redoTitle)
        XCTAssertEqual(after.undo.count, UndoHistory.menuLimit); XCTAssertEqual(store.undoLog.undoCount, 22)
        XCTAssertEqual(store.undoLog.history(limit: 2).undo.count, 2)
    }

    func testAStepThatFailsLeavesWholeStepsAndNamesWhatWasTaken() throws {
        let states = try addScenes(2)
        store.undoLog.undos = [UndoEntry(title: "Broken step", before: [:], after: [:], created: [], removed: ["../outside.txt": Data("x".utf8)])] + store.undoLog.undos
        XCTAssertThrowsError(try store.undo(steps: 3)) { e in
            let m = e.localizedDescription
            XCTAssertTrue(m.hasPrefix("Undid 2 actions: "), m); XCTAssertTrue(m.contains("Then it stopped"), m); XCTAssertTrue(m.contains("1 remaining step is still in the list"), m)
        }
        XCTAssertEqual(texts, states[0], "the two steps taken stay taken")
        XCTAssertEqual(store.undoLog.undoTitle, "Broken step", "the failing step is back on the stack, not lost"); XCTAssertEqual(store.undoLog.undoCount, 1)
        XCTAssertEqual(store.undoLog.redos.count, 2)
        XCTAssertNoThrow(try store.redo(steps: 2)); XCTAssertEqual(texts, states[2], "and Redo still works")
    }

    func testAFirstStepThatFailsThrowsItsOwnErrorAndTooManyStepsAreRefused() throws {
        try addScenes(2)
        XCTAssertThrowsError(try store.undo(steps: 3)) { XCTAssertTrue($0.localizedDescription.contains("only 2 steps to undo"), $0.localizedDescription) }
        XCTAssertThrowsError(try store.undo(steps: 0))
        XCTAssertThrowsError(try store.redo(steps: 1)) { XCTAssertTrue($0.localizedDescription.contains("nothing to redo"), $0.localizedDescription) }
        XCTAssertEqual(store.undoLog.undoCount, 2, "nothing moved")
    }

    func testABuildRefusesTheWholeOperation() throws {
        try addScenes(2)
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        XCTAssertThrowsError(try store.undo(steps: 2)) { XCTAssertEqual($0.localizedDescription, Reasons.building.message) }
        XCTAssertEqual(store.undoLog.undoCount, 2)
        store.activity.update { $0.build = nil }
    }

    func testTheButtonsSayWhatTheEditMenuSaysInEveryState() throws {
        let idle = ProjectActivity.Snapshot()
        var building = ProjectActivity.Snapshot(); building.build = .init(version: "v1", phase: .generating)
        for redo in [false, true] {
            let empty = Availability.undo(idle, can: false, redo: redo), busy = Availability.undo(building, can: true, redo: redo), ok = Availability.undo(idle, can: true, redo: redo)
            XCTAssertEqual(empty.why?.reason, redo ? "Nothing to redo" : "Nothing to undo"); XCTAssertEqual(busy.why?.cause, .building); XCTAssertTrue(ok.isAvailable)
            XCTAssertEqual(RailHistory.tooltip(redo: redo, title: "x", empty), empty.why?.message); XCTAssertEqual(RailHistory.tooltip(redo: redo, title: "x", busy), Reasons.building.message)
            XCTAssertTrue(RailHistory.tooltip(redo: redo, title: "Lock S02", ok).hasPrefix((redo ? "Redo: " : "Undo: ") + "Lock S02"))
        }
        let rail = try source("RailHistoryViews.swift"), app = try source("App.swift")
        XCTAssertTrue(rail.contains("Availability.undo(project.activity, can: redo ? project.canRedo : project.canUndo, redo: redo)"))
        XCTAssertTrue(app.contains("Availability.undo(snap, can: canU)") && app.contains("Availability.undo(snap, can: canR, redo: true)"))
        XCTAssertTrue(rail.contains(".disabledWithReason(a.why?.reason, way: a.why?.way)"), "never a silent disabled control")
    }

    func testEveryStepHasATitleAndAMissingOneGetsAGenericTitleAndIsCounted() throws {
        try addScenes(2)
        try store.apply(.scene(id: "S01", SceneEdit(status: "validated"))); try store.apply(.sceneLock(ids: ["S01"], locked: true))
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        XCTAssertEqual(store.undoLog.history().untitledCount, 0, "every kind of step recorded here carries its title")
        XCTAssertEqual(UndoHistory.title("  "), UndoHistory.untitled)
        let h = UndoHistory(undoTitles: ["Lock S01", ""], redoTitles: ["\n"])
        XCTAssertEqual(h.untitledCount, 2); XCTAssertEqual(h.undo[1].title, UndoHistory.untitled); XCTAssertEqual(h.redo[0].title, UndoHistory.untitled)
    }

    func testTheMessageNamesWhatWasUndone() {
        XCTAssertEqual(UndoHistory.line(redo: false, ["Lock S02"]), "Undid: Lock S02")
        XCTAssertEqual(UndoHistory.line(redo: false, ["A", "B", "C"]), "Undid 3 actions: A; B; C")
        XCTAssertEqual(UndoHistory.line(redo: true, ["A", "B"]), "Redid 2 actions: A; B")
    }

    func testTheRailHasTheTwoButtonsWithTheirIconRolesAndTheMenuStillWorks() throws {
        XCTAssertEqual(IconRole.railUndo.symbol, "arrow.uturn.backward"); XCTAssertEqual(IconRole.railRedo.symbol, "arrow.uturn.forward")
        let rail = try source("RailHistoryViews.swift"), theme = try source("Theme.swift"), app = try source("App.swift")
        XCTAssertTrue(theme.contains("RailHistoryButtons()")); XCTAssertTrue(rail.contains("primaryAction:") && rail.contains(".contextMenu { list }"))
        XCTAssertTrue(rail.contains("project.undo()") && rail.contains("project.redo()"), "the same operations as the menu")
        XCTAssertTrue(app.contains("project?.undo()") && app.contains("project?.redo()") && app.contains(#".keyboardShortcut("z", modifiers: .command)"#))
        XCTAssertEqual(RailEntry.allCases.count, 5, "the rail's five entries are unchanged")
    }
}
