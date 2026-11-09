import XCTest
@testable import ShowreelKit

/// Phase W5: the name of a scene, undo and redo of every typed operation, and the rules of every drop (validity, result, refusal).
final class InteractionTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    var inbox: URL!
    override func setUp() {
        dir = makeTempDir("w5"); inbox = makeTempDir("w5-inbox"); store = ProjectStore(root: dir)
        try? store.create(name: "W", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        store.undoLog.clear()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    var file: ShowreelFile { store.loadShowreel()! }
    func scene(_ id: String) -> ShowreelFile.Scene { file.scenes.first { $0.id == id }! }
    func make(_ name: String, _ body: String = "x") -> URL { let u = inbox.appendingPathComponent(name); try? body.write(to: u, atomically: true, encoding: .utf8); return u }
    @discardableResult func addAssets(_ names: [String]) throws -> [AssetRow] { try Assets.add(names.map { make($0) }, to: store) }
    func texts() -> [String?] { [store.read(ShowreelFile.fileName), store.read(Assets.manifestPath)] }

    // MARK: the name of a scene

    func testARenamedSceneKeepsItsIDAndTheNameIsOnlyALabel() throws {
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        try store.apply(.gate("storyboard", passed: true))
        for id in ["S02", "S03"] { try store.apply(.scene(id: id, SceneEdit(status: "ok"))) }
        try store.apply(.gate("review", passed: true))
        let docs = ProjectDocs.storyboard(file), film = Film.text(file)
        let card = try store.plan(.scene(id: "S01", SceneEdit(name: "  Opening  ")))
        XCTAssertEqual(card.title, "Rename S01"); XCTAssertEqual(card.changes, [Change("Name", "(empty)", "Opening")])
        try store.apply(.scene(id: "S01", SceneEdit(name: "  Opening  ")))
        XCTAssertEqual(scene("S01").id, "S01"); XCTAssertEqual(scene("S01").name, "Opening"); XCTAssertEqual(scene("S01").label, "S01 \u{00B7} Opening")
        XCTAssertEqual(scene("S02").label, "S02", "no name: the ID alone")
        XCTAssertEqual(scene("S01").status, "validated", "a label is not a change to the film: no new review")
        XCTAssertEqual(file.gates["review"], "passed", "and the Go stays given")
        XCTAssertEqual(ProjectDocs.storyboard(file), docs, "storyboard.md does not depend on the name")
        XCTAssertEqual(Film.text(file), film, "nor does the montage the build reads")
        XCTAssertTrue(store.read(ShowreelFile.fileName)!.contains("\"name\" : \"Opening\""))
        try store.apply(.scene(id: "S01", SceneEdit(name: "")))
        XCTAssertNil(scene("S01").name); XCTAssertFalse(store.read(ShowreelFile.fileName)!.contains("Opening"), "an empty name clears the key")
        XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(name: "")))) { XCTAssertTrue($0.localizedDescription.contains("no change")) }
    }

    func testANameCannotLookLikeAnIDOrRunOnForever() throws {
        for bad in ["S02", "S10", "S01a"] { XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(name: bad)))) { XCTAssertTrue($0.localizedDescription.contains("look like a scene ID"), bad) } }
        XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(name: "two\nlines"))))
        XCTAssertThrowsError(try store.apply(.scene(id: "S01", SceneEdit(name: String(repeating: "x", count: 61)))))
        try store.apply(.scene(id: "S01", SceneEdit(name: "Scene two")))
        XCTAssertEqual(scene("S01").name, "Scene two")
        let added = try store.plan(.addScene(id: "", SceneEdit(duration: "2", name: "Closing")))
        XCTAssertEqual(added.title, "Add scene S04 \u{00B7} Closing")
    }

    func testTheNameIsAKeyOfTheFileAndOldFilesMigrateWithoutLoss() throws {
        let old = ##"{"schema": 1, "name": "M", "scenes": [{"id": "S01", "duration": 3, "text": "Hi", "extraKey": [1, 2]}, {"id": "S02", "name": "Kept", "duration": 2, "status": "ok"}], "futureKey": {"a": 1}}"##
        let f = try ShowreelFile.decode(old)
        XCTAssertNil(f.scenes[0].name); XCTAssertEqual(f.scenes[1].name, "Kept")
        XCTAssertEqual(f.scenes[0].unknown["extraKey"], .array([.number(1), .number(2)]))
        XCTAssertEqual(f.unknown["futureKey"], .object(["a": .number(1)]))
        let again = try ShowreelFile.decode(try f.encoded())
        XCTAssertEqual(again, f, "round trip")
        XCTAssertFalse(try f.encoded().contains("\"name\" : \"\""), "no empty name is ever written")
        let blank = try ShowreelFile.decode(##"{"schema": 1, "name": "M", "scenes": [{"id": "S01", "name": "   "}]}"##)
        XCTAssertNil(blank.scenes[0].name)
    }

    func testTheCopilotSeesTheNameAndCanSetIt() throws {
        XCTAssertEqual(Tools.sceneEdit(["name": "Intro", "duration": 3]).name, "Intro")
        try store.apply(.scene(id: "S02", SceneEdit(name: "Middle")))
        XCTAssertTrue(store.read(ShowreelFile.fileName)!.contains("Middle"), "get_state returns showreel.json: the name is in it")
        XCTAssertEqual(try store.duplicateScene("S02"), "S04")
        XCTAssertEqual(scene("S04").name, "Middle copy", "a copy is told apart by its label")
    }

    // MARK: undo and redo

    /// The operation changes the project, undo puts both data files back exactly, redo does it again exactly.
    func roundTrip(_ op: ProjectOperation, file: StaticString = #filePath, line: UInt = #line) throws {
        let before = texts()
        try store.apply(op)
        let after = texts()
        XCTAssertNotEqual(before, after, "\(op) changed nothing", file: file, line: line)
        XCTAssertTrue(store.undoLog.canUndo, file: file, line: line)
        try store.undo()
        XCTAssertEqual(texts(), before, "undo of \(op)", file: file, line: line)
        XCTAssertTrue(store.undoLog.canRedo, file: file, line: line)
        try store.redo()
        XCTAssertEqual(texts(), after, "redo of \(op)", file: file, line: line)
        store.undoLog.clear()
    }

    func testEveryTypedOperationUndoesAndRedoes() throws {
        try addAssets(["Acme Logo.svg", "theme.mp3"])
        try store.apply(.asset(id: "audio-01", status: .approved, note: nil, licence: nil, scenes: nil))
        store.undoLog.clear()
        try roundTrip(.parameter(.audience, "Developers"))
        try roundTrip(.decisions([DecisionChange(.palette, "#000000, #FFFFFF, #FF0000")], title: nil))
        try roundTrip(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil))
        try roundTrip(.asset(id: "logo-01", status: nil, note: "a note", licence: nil, scenes: nil))
        try roundTrip(.gate("assets", passed: true))
        try roundTrip(.scene(id: "S01", SceneEdit(visual: "A big logo")))
        try roundTrip(.addScene(id: "", SceneEdit(duration: "2", text: "Four")))
        try roundTrip(.sceneEnabled(id: "S02", enabled: false, montage: nil))
        try roundTrip(.moveScene(id: "S03", after: "start", montage: nil))
        try roundTrip(.sceneLook(id: "S01", [DecisionChange(.background, Look.backgroundIDs()[0])]))
        try roundTrip(.content(scene: "S01", .add(ContentEdit(type: "text", text: "More"), after: nil)))
        try roundTrip(.content(scene: "S01", .update(item: "c1", ContentEdit(text: "Changed"))))
        try roundTrip(.content(scene: "S01", .remove(item: "c1")))
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Second"), after: nil))); store.undoLog.clear()
        try roundTrip(.content(scene: "S01", .move(item: "c3", after: "start")))
        try roundTrip(.resize(scene: "S01", duration: 5, ripple: true))
        try roundTrip(.moveCut(before: "S03", after: "S01", at: 2))   // S03 is first since the move above, S02 is off
        try roundTrip(.transition(from: "S03", TransitionEdit(type: Look.transitions().first { !Look.isPreviewOnly($0.name) }!.name)))
        try roundTrip(.track(asset: "audio-01"))
        try roundTrip(.grid(bpm: 120, firstBeat: 0.25))
        try roundTrip(.gridSettings(snap: "bar", ripple: false))
        try roundTrip(.moveAsset(id: "audio-01", after: "start"))
    }

    func testASeriesOfOperationsUndoesStepByStepAndRedoesInOrder() throws {
        var states = [texts()]
        let ops: [ProjectOperation] = [.scene(id: "S01", SceneEdit(name: "A")), .moveScene(id: "S03", after: "start", montage: nil), .resize(scene: "S02", duration: 6, ripple: true),
                                       .content(scene: "S01", .add(ContentEdit(type: "text", text: "Two"), after: nil)), .sceneEnabled(id: "S01", enabled: false, montage: nil)]
        for op in ops { try store.apply(op); states.append(texts()) }
        XCTAssertEqual(store.undoLog.undoCount, 5)
        for i in stride(from: 4, through: 0, by: -1) { try store.undo(); XCTAssertEqual(texts(), states[i], "after undoing step \(i + 1)") }
        XCTAssertFalse(store.undoLog.canUndo); XCTAssertThrowsError(try store.undo())
        for i in 1...5 { try store.redo(); XCTAssertEqual(texts(), states[i], "after redoing step \(i)") }
        XCTAssertFalse(store.undoLog.canRedo)
        try store.undo(); try store.undo()
        try store.apply(.scene(id: "S02", SceneEdit(name: "B")))
        XCTAssertFalse(store.undoLog.canRedo, "a new change ends the redo line")
    }

    func testUndoTakesTheGoBackWithTheReviewStateAndTheArchive() throws {
        for id in ["S01", "S02", "S03"] { try store.apply(.scene(id: id, SceneEdit(status: "ok"))) }
        try store.apply(.gate("storyboard", passed: true)); try store.apply(.gate("review", passed: true))
        store.undoLog.clear()
        let given = texts()
        try store.apply(.resize(scene: "S02", duration: 5, ripple: true))
        XCTAssertEqual(file.gates["review"], "open", "the change took the Go back"); XCTAssertEqual(scene("S02").status, "wip")
        try store.undo()
        XCTAssertEqual(texts(), given); XCTAssertEqual(file.gates["review"], "passed", "the Go is given again by the undo"); XCTAssertEqual(scene("S02").status, "validated")
        try store.redo()
        XCTAssertEqual(file.gates["review"], "open")
        try store.undo()
        // archive and bring back
        try store.apply(.scene(id: "S03", SceneEdit(archived: true)))
        XCTAssertTrue(scene("S03").archived); XCTAssertEqual(file.film.map { $0.id }, ["S01", "S02"])
        try store.undo()
        XCTAssertFalse(scene("S03").archived); XCTAssertEqual(file.film.map { $0.id }, ["S01", "S02", "S03"], "back in the film where it was")
        XCTAssertEqual(file.gates["review"], "passed")
        // the Go itself
        try store.apply(.gate("review", passed: false)); try store.undo()
        XCTAssertEqual(file.gates["review"], "passed")
        // a review decision
        try store.apply(.scene(id: "S01", SceneEdit(note: "shorter", status: "modify"))); try store.undo()
        XCTAssertEqual(scene("S01").status, "validated"); XCTAssertEqual(scene("S01").note, "")
    }

    func testAnExcludedResourceComesBackWithItsPreparedFile() throws {
        try addAssets(["Acme Logo.svg"])
        try store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil)); store.undoLog.clear()
        let row = Assets.load(store).first!, prepared = dir.appendingPathComponent("assets/" + row.file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.path))
        try store.apply(.asset(id: "logo-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.path), "excluding removes the prepared copy")
        try store.undo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.path), "undo gives the file back")
        XCTAssertEqual(Assets.load(store).first?.status, "approved")
        try store.redo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.path))
    }

    func testDroppedFilesAreTakenBackAndComeBackWithUndoAndRedo() throws {
        let r = try Drops.drop(.files([make("Acme Logo.svg", "<svg/>")]), on: .scene("S01"), store: store)
        XCTAssertEqual(store.undoLog.undoCount, 1, "adding the file and linking it is one step")
        XCTAssertEqual(r.title, "Add Acme Logo.svg to S01")
        let row = Assets.load(store).first!
        let source = dir.appendingPathComponent("assets/source/Acme Logo.svg"), prepared = dir.appendingPathComponent("assets/" + row.file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path) && FileManager.default.fileExists(atPath: prepared.path))
        try store.undo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path)); XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.path))
        XCTAssertTrue(Assets.load(store).isEmpty, "the row is gone too")
        try store.redo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path) && FileManager.default.fileExists(atPath: prepared.path))
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, ["S01"])
    }

    func testDuplicatingASceneIsOneStep() throws {
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Second words"), after: nil))); store.undoLog.clear()
        let before = texts()
        let n = try store.duplicateScene("S01")
        XCTAssertEqual(n, "S04"); XCTAssertEqual(scene("S04").content.count, 2); XCTAssertEqual(file.film.map { $0.id }, ["S01", "S04", "S02", "S03"])
        XCTAssertEqual(store.undoLog.undoCount, 1)
        try store.undo()
        XCTAssertEqual(texts(), before)
        try store.redo()
        XCTAssertEqual(scene("S04").content.count, 2)
    }

    func testTheStackIsClearedWhenTheFileChangesOutsideTheApp() throws {
        try store.apply(.scene(id: "S01", SceneEdit(name: "A"))); try store.apply(.scene(id: "S02", SceneEdit(name: "B")))
        try store.undo()
        XCTAssertTrue(store.undoIsValid())
        // someone edits the file (an editor, a script, the copilot's file tool)
        var f = file; f.name = "Edited elsewhere"
        try store.write(ShowreelFile.fileName, try f.encoded())
        XCTAssertFalse(store.undoIsValid())
        XCTAssertThrowsError(try store.redo()) { XCTAssertTrue($0.localizedDescription.contains("outside the app")) }
        XCTAssertFalse(store.undoLog.canUndo || store.undoLog.canRedo, "both stacks are forgotten")
        XCTAssertEqual(file.name, "Edited elsewhere", "and the outside edit was not overwritten")
        // the model's own check (after the watcher saw a change)
        try store.apply(.scene(id: "S01", SceneEdit(name: "C")))
        XCTAssertFalse(store.dropUndoIfStale())
        try store.write(ShowreelFile.fileName, store.read(ShowreelFile.fileName)!.replacingOccurrences(of: "\"C\"", with: "\"D\""))
        XCTAssertTrue(store.dropUndoIfStale()); XCTAssertFalse(store.undoLog.canUndo)
    }

    func testTheStackHasALimit() throws {
        for i in 0..<(UndoLog.limit + 10) { try store.apply(.scene(id: "S01", SceneEdit(note: "n\(i)"))) }
        XCTAssertEqual(store.undoLog.undoCount, UndoLog.limit)
        XCTAssertEqual(store.undoLog.undoTitle, "Edit S01")
    }

    func testAFailedOperationLeavesNothingToUndo() throws {
        XCTAssertThrowsError(try store.apply(.scene(id: "S99", SceneEdit(note: "x"))))
        XCTAssertFalse(store.undoLog.canUndo)
        XCTAssertThrowsError(try Drops.drop(.scene("S01"), on: .librarySlot(before: "S02"), store: store)) // already there
        XCTAssertFalse(store.undoLog.canUndo)
    }

    // MARK: drops: the tokens and the table of kinds

    func testTokensRoundTrip() {
        let items: [DragItem] = [.resource("logo-01"), .background("Plain"), .look("p1"), .palette("p1"), .effect("Ink/paper inversion"), .pack("Kinetic"), .transition("Push"),
                                 .scene("S02"), .content(scene: "S01", item: "c3"), .files([])]
        for i in items { XCTAssertEqual(DragItem(token: i.token), i, i.token) }
        XCTAssertNil(DragItem(token: "hello")); XCTAssertNil(DragItem(token: "studio:nothing:x")); XCTAssertNil(DragItem(token: "studio:content:novalue"))
        XCTAssertEqual(DragItem.library(kind: "effects", id: "pack:Kinetic"), .pack("Kinetic"))
        XCTAssertEqual(DragItem.library(kind: "effects", id: "Pop"), .effect("Pop"))
        XCTAssertEqual(DragItem.library(kind: "transitions", id: "Push"), .transition("Push"))
        XCTAssertEqual(DragItem.library(kind: "backgrounds", id: "Plain"), .background("Plain"))
        XCTAssertNil(DragItem.library(kind: "palettes", id: "project")); XCTAssertNil(DragItem.library(kind: "fonts", id: "Inter"))
    }

    func testEachKindOfItemHasItsKindOfTargetAndNothingElse() {
        let targets: [DropTarget] = [.scene("S01"), .sceneNode(scene: "S01", group: .composition, node: nil), .contentItem(scene: "S01", item: "c1"), .contentSlot(scene: "S01", before: nil),
                                     .reelSlot(before: nil), .librarySlot(before: nil), .assetSlot(before: nil), .marker(from: "S01"), .resourceList]
        func ok(_ i: DragItem) -> [DropTarget] { targets.filter { Drops.applies(i, to: $0) } }
        XCTAssertEqual(ok(.resource("x")), [.scene("S01"), .sceneNode(scene: "S01", group: .composition, node: nil), .contentItem(scene: "S01", item: "c1"), .contentSlot(scene: "S01", before: nil), .assetSlot(before: nil)])
        XCTAssertEqual(ok(.background("x")), [.scene("S01"), .sceneNode(scene: "S01", group: .composition, node: nil)])
        XCTAssertEqual(ok(.look("x")), ok(.background("x"))); XCTAssertEqual(ok(.palette("x")), ok(.background("x")))
        XCTAssertEqual(ok(.effect("x")), [.contentItem(scene: "S01", item: "c1")])
        XCTAssertTrue(ok(.pack("x")).isEmpty, "a pack is a project choice")
        XCTAssertEqual(ok(.transition("x")), [.marker(from: "S01")])
        XCTAssertEqual(ok(.scene("S01")), [.reelSlot(before: nil), .librarySlot(before: nil)])
        XCTAssertEqual(ok(.content(scene: "S01", item: "c1")), [.contentSlot(scene: "S01", before: nil)])
        XCTAssertEqual(ok(.files([])), [.scene("S01"), .sceneNode(scene: "S01", group: .composition, node: nil), .contentSlot(scene: "S01", before: nil), .assetSlot(before: nil), .resourceList])
        XCTAssertEqual(Drops.applies(.effect("x"), to: .sceneNode(scene: "S01", group: .composition, node: "item.c1")), true, "the node of an item stands for the item")
        XCTAssertEqual(Drops.verdict(.transition("Push"), on: .scene("S01"), store: store), .refused("A transition goes on the marker between two scenes"))
    }

    // MARK: drops: what each one does

    func testAResourceDroppedOnASceneOrANodeLinksItAndNothingElse() throws {
        try addAssets(["Acme Logo.svg", "brand-notes.pdf"])
        let v = Drops.verdict(.resource("logo-01"), on: .scene("S01"), store: store)
        XCTAssertEqual(v, .ok("Link Acme Logo.svg to S01"))
        XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.scene, "", "a verdict changes nothing")
        let r = try Drops.drop(.resource("logo-01"), on: .sceneNode(scene: "S01", group: .composition, node: nil), store: store)
        XCTAssertEqual(r.scene, "S01"); XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.sceneIDs, ["S01"])
        XCTAssertEqual(Drops.verdict(.resource("logo-01"), on: .scene("S01"), store: store), .refused("Acme Logo.svg is already linked to S01"))
        XCTAssertTrue(Drops.verdict(.resource("note-01"), on: .scene("S01"), store: store).text.contains("not used in a scene") || Drops.verdict(.resource("doc-01"), on: .scene("S01"), store: store).text.contains("not used in a scene"))
        XCTAssertEqual(Drops.verdict(.resource("nope-01"), on: .scene("S01"), store: store), .refused("unknown asset nope-01"))
        try store.apply(.asset(id: "logo-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(Drops.verdict(.resource("logo-01"), on: .scene("S02"), store: store), .refused("Acme Logo.svg is excluded: it cannot be used"))
    }

    func testAResourceThatNeedsAttentionCannotBeDropped() throws {
        try addAssets(["client-photo.jpg"])
        let row = try XCTUnwrap(Assets.load(store).first)
        XCTAssertEqual(row.status, "hold")
        let v = Drops.verdict(.resource(row.id), on: .scene("S01"), store: store)
        XCTAssertFalse(v.isValid); XCTAssertTrue(v.text.contains("needs attention first"), v.text)
        XCTAssertFalse(Drops.verdict(.resource(row.id), on: .contentSlot(scene: "S01", before: nil), store: store).isValid)
    }

    func testAResourceDroppedInTheContentListMakesAnItemAtThatPlace() throws {
        try addAssets(["Acme Logo.svg", "theme.mp3", "Brand.ttf"])
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Second"), after: nil)))
        var ids: [String] { scene("S01").content.map { $0.id } }
        XCTAssertEqual(ids, ["c1", "c2"])
        try Drops.drop(.resource("logo-01"), on: .contentSlot(scene: "S01", before: "c2"), store: store)
        XCTAssertEqual(scene("S01").content.map { $0.type }, ["text", "image", "text"], "between the two texts")
        XCTAssertEqual(scene("S01").content[1].resource, "logo-01"); XCTAssertEqual(Assets.load(store).first { $0.id == "logo-01" }?.sceneIDs, ["S01"], "and it is linked")
        try Drops.drop(.resource("audio-01"), on: .contentSlot(scene: "S01", before: nil), store: store)
        XCTAssertEqual(scene("S01").content.last?.type, "audio", "at the end")
        try Drops.drop(.resource("audio-01"), on: .contentSlot(scene: "S02", before: nil), store: store)
        XCTAssertEqual(scene("S02").content.last?.type, "audio")
        let v = Drops.verdict(.resource("font-01"), on: .contentSlot(scene: "S01", before: nil), store: store)
        XCTAssertTrue(v.text.contains("cannot be a content item"), v.text)
        // replacing the resource of an image item
        try addAssets(["Other logo.svg"])
        let img = scene("S01").content[1].id
        try Drops.drop(.resource("logo-02"), on: .contentItem(scene: "S01", item: img), store: store)
        XCTAssertEqual(scene("S01").content[1].resource, "logo-02")
        XCTAssertTrue(Drops.verdict(.resource("logo-02"), on: .contentItem(scene: "S01", item: "c1"), store: store).text.contains("text item has words"))
        XCTAssertTrue(Drops.verdict(.resource("audio-01"), on: .contentItem(scene: "S01", item: img), store: store).text.contains("is a audio"), "an image item does not take a sound")
    }

    func testABackgroundOrALookDroppedOnASceneOverridesThatSceneOnly() throws {
        let bg = Look.backgroundIDs()[0]
        let r = try Drops.drop(.background(bg), on: .scene("S02"), store: store)
        XCTAssertEqual(r.title, "Use the \(bg) background in S02")
        XCTAssertEqual(scene("S02").overrides?.background?.id, bg); XCTAssertNil(scene("S01").overrides); XCTAssertNil(file.decisions.background?.id, "the project is untouched")
        XCTAssertEqual(Drops.verdict(.background(bg), on: .scene("S02"), store: store).isValid, false, "same again: no change")
        XCTAssertEqual(Drops.verdict(.background("Nonexistent"), on: .scene("S01"), store: store).text.hasPrefix("unknown background"), true)
        let p = try XCTUnwrap(LookPackages.all().first)
        try Drops.drop(.look(p.id), on: .sceneNode(scene: "S03", group: .look, node: "palette"), store: store)
        let o = try XCTUnwrap(scene("S03").overrides)
        XCTAssertEqual(o.palette, p.palette.map { $0.uppercased() }); XCTAssertEqual(o.background?.id, p.background)
        XCTAssertNil(o.moods); XCTAssertNil(o.effectsPack, "moods and the pack belong to the project: the scene takes only what a scene may override")
        XCTAssertNil(file.decisions.moods)
        let q = try XCTUnwrap(LookPackages.all().dropFirst().first(where: { $0.palette != p.palette }))
        try Drops.drop(.palette(q.id), on: .scene("S01"), store: store)
        XCTAssertEqual(scene("S01").overrides?.palette, q.palette.map { $0.uppercased() }); XCTAssertNil(scene("S01").overrides?.background, "only the palette")
        XCTAssertEqual(store.undoLog.undoCount, 3)
    }

    func testAnEffectSetsTheAnimationOfAnItemAndNothingElseTakesIt() throws {
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Two"), after: nil)))
        let name = Look.effects().first { !Look.transitions().map { $0.name }.contains($0) }!
        try Drops.drop(.effect(name), on: .contentItem(scene: "S01", item: "c2"), store: store)
        XCTAssertEqual(scene("S01").content[1].animation, .init(mode: "effect", effect: name)); XCTAssertFalse(scene("S01").content[0].animation.isFixed)
        try addAssets(["theme.mp3"])
        try Drops.drop(.resource("audio-01"), on: .contentSlot(scene: "S01", before: nil), store: store)
        let sound = scene("S01").content.last!.id
        XCTAssertEqual(Drops.verdict(.effect(name), on: .contentItem(scene: "S01", item: sound), store: store), .refused("a sound has no animation"))
        XCTAssertEqual(Drops.verdict(.effect(name), on: .scene("S01"), store: store).text, "An effect goes on a content item")
        XCTAssertEqual(Drops.verdict(.pack("Kinetic"), on: .contentItem(scene: "S01", item: "c1"), store: store).isValid, false)
        XCTAssertEqual(Drops.verdict(.effect("Nonexistent"), on: .contentItem(scene: "S01", item: "c1"), store: store).text.hasPrefix("unknown effect"), true)
    }

    func testATransitionOnAMarkerAndTheRefusalsOfAMarker() throws {
        let good = Look.transitions().first { !Look.isPreviewOnly($0.name) }!.name
        try Drops.drop(.transition(good), on: .marker(from: "S01"), store: store)
        XCTAssertEqual(file.storyboards[0].items[0].transition.type, good)
        let v = Drops.verdict(.transition(Look.transitionsPreviewOnly().first!), on: .marker(from: "S02"), store: store)
        XCTAssertTrue(v.text.contains("preview only"), v.text)
        XCTAssertTrue(Drops.verdict(.transition(good), on: .marker(from: "S03"), store: store).text.contains("last scene"), "no marker after the last scene")
        XCTAssertEqual(Drops.verdict(.resource("x"), on: .marker(from: "S01"), store: store).text, "A resource goes on a scene, in a scene's content list or in the resources list")
    }

    func testScenesAreReorderedInTheLibraryAndTheReelAndAnOffSceneIsSwitchedOn() throws {
        try Drops.drop(.scene("S03"), on: .librarySlot(before: "S01"), store: store)
        XCTAssertEqual(file.orderedLibrary.map { $0.id }, ["S03", "S01", "S02"])
        try Drops.drop(.scene("S03"), on: .librarySlot(before: nil), store: store)
        XCTAssertEqual(file.orderedLibrary.map { $0.id }, ["S01", "S02", "S03"])
        XCTAssertEqual(Drops.verdict(.scene("S02"), on: .librarySlot(before: "S02"), store: store).isValid, false, "dropped on itself")
        XCTAssertEqual(Drops.verdict(.scene("S02"), on: .librarySlot(before: "S03"), store: store).isValid, false, "already just before S03")
        XCTAssertEqual(Drops.verdict(.scene("S01"), on: .reelSlot(before: nil), store: store).isValid, true)
        store.undoLog.clear()
        try store.apply(.sceneEnabled(id: "S02", enabled: false, montage: nil)); store.undoLog.clear()
        let r = try Drops.drop(.scene("S02"), on: .reelSlot(before: "S01"), store: store)
        XCTAssertEqual(r.title, "Put S02 in the film"); XCTAssertEqual(file.film.map { $0.id }, ["S02", "S01", "S03"])
        XCTAssertEqual(store.undoLog.undoCount, 1, "switching on and placing is one step")
        try store.undo()
        XCTAssertEqual(file.film.map { $0.id }, ["S01", "S03"]); XCTAssertEqual(file.storyboards[0].items.first { $0.scene == "S02" }?.enabled, false)
        try store.apply(.scene(id: "S03", SceneEdit(archived: true)))
        XCTAssertTrue(Drops.verdict(.scene("S03"), on: .reelSlot(before: nil), store: store).text.contains("archived"))
    }

    func testItemsAreReorderedInTheirOwnSceneOnly() throws {
        for t in ["Two", "Three"] { try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: t), after: nil))) }
        var ids: [String] { scene("S01").content.map { $0.id } }
        try Drops.drop(.content(scene: "S01", item: "c3"), on: .contentSlot(scene: "S01", before: "c1"), store: store)
        XCTAssertEqual(ids, ["c3", "c1", "c2"])
        try Drops.drop(.content(scene: "S01", item: "c3"), on: .contentSlot(scene: "S01", before: nil), store: store)
        XCTAssertEqual(ids, ["c1", "c2", "c3"])
        XCTAssertEqual(scene("S01").text, "One", "the first text item holds the scene's text")
        try Drops.drop(.content(scene: "S01", item: "c2"), on: .contentSlot(scene: "S01", before: "c1"), store: store)
        XCTAssertEqual(scene("S01").text, "Two", "the new first text is the scene's text")
        XCTAssertFalse(Drops.verdict(.content(scene: "S01", item: "c2"), on: .contentSlot(scene: "S01", before: "c1"), store: store).isValid, "already first")
        XCTAssertFalse(Drops.verdict(.content(scene: "S01", item: "c2"), on: .contentSlot(scene: "S01", before: "c2"), store: store).isValid, "on itself")
        XCTAssertEqual(Drops.verdict(.content(scene: "S01", item: "c2"), on: .contentSlot(scene: "S02", before: nil), store: store).text, "an item stays in its scene: duplicate it to put a copy elsewhere")
    }

    func testResourcesAreReorderedInTheirList() throws {
        try addAssets(["Acme Logo.svg", "theme.mp3", "Other logo.svg"])
        var ids: [String] { Assets.load(store).map { $0.id } }
        XCTAssertEqual(ids, ["logo-01", "audio-01", "logo-02"])
        try Drops.drop(.resource("logo-02"), on: .assetSlot(before: "logo-01"), store: store)
        XCTAssertEqual(ids, ["logo-02", "logo-01", "audio-01"])
        try Drops.drop(.resource("logo-02"), on: .assetSlot(before: nil), store: store)
        XCTAssertEqual(ids, ["logo-01", "audio-01", "logo-02"])
        XCTAssertFalse(Drops.verdict(.resource("audio-01"), on: .assetSlot(before: "logo-02"), store: store).isValid, "already there")
        XCTAssertFalse(Drops.verdict(.resource("audio-01"), on: .assetSlot(before: "audio-01"), store: store).isValid)
    }

    func testAFileFromTheFinderIsAddedWithTheAutomaticChecksAndLinked() throws {
        let r = try Drops.drop(.files([make("Acme Logo.svg"), make("client-photo.jpg"), make("brand-notes.pdf")]), on: .scene("S02"), store: store)
        let rows = Assets.load(store)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.first { $0.id == "logo-01" }?.sceneIDs, ["S02"], "the logo is linked")
        let held = try XCTUnwrap(rows.first { $0.type == "photo" })
        XCTAssertEqual(held.status, "hold", "the existing automatic checks ran"); XCTAssertEqual(held.sceneIDs, [], "a file that needs attention is not linked")
        let n = try XCTUnwrap(r.notice)
        XCTAssertTrue(n.contains("client-photo.jpg needs attention") && n.contains("not used in S02"), n)
        XCTAssertTrue(n.contains("brand-notes.pdf is a doc file"), n)
        XCTAssertEqual(rows.first { $0.type == "doc" }?.sceneIDs, [])
        XCTAssertEqual(store.undoLog.undoCount, 1)
        // on the resources list: added, not linked
        try Drops.drop(.files([make("theme.mp3")]), on: .resourceList, store: store)
        XCTAssertEqual(Assets.load(store).first { $0.id == "audio-01" }?.sceneIDs, [])
        // in the content list: becomes an item at that place
        try Drops.drop(.files([make("Third logo.svg")]), on: .contentSlot(scene: "S01", before: "c1"), store: store)
        XCTAssertEqual(scene("S01").content.first?.type, "image"); XCTAssertEqual(scene("S01").content.first?.resource, "logo-02")
        XCTAssertEqual(Drops.verdict(.files([]), on: .scene("S01"), store: store).isValid, true)
        XCTAssertEqual(Drops.verdict(.files([]), on: .marker(from: "S01"), store: store).text, "Files go on a scene, in a scene's content list or in the resources list")
        XCTAssertThrowsError(try Drops.drop(.files([]), on: .scene("S01"), store: store))
    }

    func testAVerdictAgreesWithTheDropForEveryPairAndNeverChangesAThing() throws {
        try addAssets(["Acme Logo.svg", "theme.mp3", "client-photo.jpg"])
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Two"), after: nil)))
        try store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil)); store.undoLog.clear()
        let bg = Look.backgroundIDs()[0], eff = Look.effects().first { !Look.transitions().map { $0.name }.contains($0) }!
        let items: [DragItem] = [.resource("logo-01"), .resource("audio-01"), .resource("photo-01"), .resource("nope"), .background(bg), .look(LookPackages.all()[0].id), .effect(eff), .pack("Kinetic"),
                                 .transition(Look.transitions().first { !Look.isPreviewOnly($0.name) }!.name), .transition(Look.transitionsPreviewOnly().first!),
                                 .scene("S01"), .scene("S02"), .content(scene: "S01", item: "c2"), .content(scene: "S02", item: "c1")]
        let targets: [DropTarget] = [.scene("S01"), .scene("S09"), .sceneNode(scene: "S02", group: .composition, node: "item.c1"), .contentItem(scene: "S01", item: "c1"), .contentSlot(scene: "S01", before: nil),
                                     .contentSlot(scene: "S01", before: "c1"), .reelSlot(before: nil), .reelSlot(before: "S01"), .librarySlot(before: "S02"), .assetSlot(before: "logo-01"), .marker(from: "S01"), .resourceList]
        var valid = 0, refused = 0
        for item in items { for target in targets {
            let snapshot = (texts(), store.undoLog.undoCount)
            let v = Drops.verdict(item, on: target, store: store)
            XCTAssertEqual(texts(), snapshot.0, "a verdict changes nothing: \(item) on \(target)"); XCTAssertEqual(store.undoLog.undoCount, snapshot.1)
            XCTAssertFalse(v.text.isEmpty)
            // run the drop on a copy of the project, so every pair starts from the same state
            let copy = makeTempDir("w5-copy"); defer { try? FileManager.default.removeItem(at: copy) }
            try FileManager.default.removeItem(at: copy); try FileManager.default.copyItem(at: dir, to: copy)
            let other = ProjectStore(root: copy)
            do { try Drops.drop(item, on: target, store: other); XCTAssertTrue(v.isValid, "dropped, but the verdict said \(v): \(item) on \(target)"); valid += 1 }
            catch { XCTAssertEqual(v, .refused(error.localizedDescription), "\(item) on \(target)"); refused += 1 }
        } }
        XCTAssertGreaterThan(valid, 12); XCTAssertGreaterThan(refused, 60)
    }
}
