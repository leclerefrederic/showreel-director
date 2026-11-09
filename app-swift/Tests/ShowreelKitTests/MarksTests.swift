import XCTest
@testable import ShowreelKit

/// Q6: which elements carry which mark on which surface, the one layout rule, the menu items that say why, and what the player offers to generate.
final class MarksTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    let v = "v1"
    override func setUp() {
        dir = makeTempDir("marks"); store = ProjectStore(root: dir)
        try? store.create(name: "Mk", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three", "Four"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t, status: "validated"))) }
        try? store.apply(.content(scene: "S02", .add(ContentEdit(type: "text", text: "Item"), after: nil)))
        try? store.apply(.sceneEnabled(id: "S04", enabled: false, montage: nil))      // in the library, not in the film
        store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    var assets: [AssetRow] { [AssetRow(id: "logo-01", type: "logo"), AssetRow(id: "font-01", type: "font")] }
    func module(_ w: String) -> String { "return function render(g, lt, c) { g.fillText('\(w)', 10, 10); };\n" }
    func folder(scenes: [String]) throws {
        let d = dir.appendingPathComponent(v); try FileManager.default.createDirectory(at: d.appendingPathComponent("scenes"), withIntermediateDirectories: true)
        try "{\"title\": \"M\", \"main\": \"main.js\", \"duration\": 12, \"fonts\": [], \"tokens\": {}}".write(to: d.appendingPathComponent("project.json"), atomically: true, encoding: .utf8)
        try Film.text(file).write(to: d.appendingPathComponent("film.json"), atomically: true, encoding: .utf8)
        for id in scenes { try module(id).write(to: d.appendingPathComponent("scenes/\(id).js"), atomically: true, encoding: .utf8) }
        try "<html></html>".write(to: { try? FileManager.default.createDirectory(at: d.appendingPathComponent("dist"), withIntermediateDirectories: true); return d.appendingPathComponent("dist/index.html") }(), atomically: true, encoding: .utf8)
        try SceneModules.recordResult(version: v, ok: true, store: store)
    }

    // MARK: which elements carry which mark on which surface

    func testTheElementsOfEachSurface() {
        let f = file
        XCTAssertEqual(Marks.elements(on: .list, file: f, assets: assets), [.scene("S01"), .scene("S02"), .scene("S03"), .scene("S04")], "the list shows the library, switched-off scenes included")
        XCTAssertEqual(Marks.elements(on: .reel, file: f, assets: assets), [.scene("S01"), .scene("S02"), .scene("S03")], "the reel shows the film")
        let tree = Marks.elements(on: .tree, file: f, assets: assets)
        XCTAssertTrue(tree.contains(.scene("S02")) && tree.contains { if case .item(let s, _) = $0 { return s == "S02" } else { return false } }); XCTAssertEqual(tree.filter { if case .item = $0 { return true } else { return false } }.count, f.scenes.reduce(0) { $0 + $1.content.count })
        XCTAssertEqual(Marks.elements(on: .resources, file: f, assets: assets), [.asset("logo-01"), .asset("font-01")])
        XCTAssertTrue(Marks.elements(on: .inspector, file: f, assets: assets).contains(.asset("font-01")))
        XCTAssertTrue(Marks.elements(on: .list, file: nil, assets: []).isEmpty)
    }

    func testAProposalABuildAndClapWorkingMarkTheSameElementsOnEverySurface() throws {
        let f = file
        let item = try XCTUnwrap(f.scenes.first { $0.id == "S02" }?.content.first?.id)
        var s = ProjectActivity.Snapshot()
        func marked(_ x: Surface) -> [ElementRef: Unavailable] { Marks.marked(on: x, file: f, assets: assets, in: s) }
        // nothing going on: nothing marked
        for x in Surface.allCases { XCTAssertTrue(marked(x).isEmpty, "\(x)") }
        // a proposal waiting on S02's duration
        s.proposals = [.init(id: "p1", title: "Set S02 duration", targets: [.scene("S02")])]
        for x in [Surface.list, .reel, .inspector] { XCTAssertEqual(Set(marked(x).keys).intersection([.scene("S01"), .scene("S02"), .scene("S03")]), [.scene("S02")], "\(x)") }
        XCTAssertEqual(Set(marked(.tree).keys), Set([.scene("S02")] + f.scenes.first { $0.id == "S02" }!.content.map { ElementRef.item(scene: "S02", item: $0.id) }), "the tree marks the scene and all its items")
        XCTAssertTrue(marked(.resources).isEmpty)
        for x in Surface.allCases { for (_, u) in marked(x) { XCTAssertEqual(u.cause, .proposal); XCTAssertEqual(u.link, .proposal("p1")); XCTAssertTrue(u.message.hasPrefix("Waiting for your answer on a proposal from Clap")) } }
        // a proposal on one item
        s.proposals = [.init(id: "p2", title: "Edit text", targets: [.item(scene: "S02", item: item)])]
        XCTAssertEqual(Set(marked(.tree).keys), [.scene("S02"), .item(scene: "S02", item: item)], "the item and the scene that holds it, not the scene's other items")
        XCTAssertEqual(Set(marked(.reel).keys), [.scene("S02")])
        // a proposal on a resource
        s.proposals = [.init(id: "p3", title: "Approve the logo", targets: [.asset("logo-01")])]
        XCTAssertEqual(Set(marked(.resources).keys), [.asset("logo-01")]); XCTAssertEqual(Set(marked(.inspector).keys), [.asset("logo-01")]); XCTAssertTrue(marked(.list).isEmpty)
        // a build: everything, the same reason, on every surface
        s = ProjectActivity.Snapshot(); s.build = .init(version: "v1", phase: .generating)
        for x in Surface.allCases {
            let m = marked(x); XCTAssertEqual(m.count, Marks.elements(on: x, file: f, assets: assets).count, "\(x): everything is marked"); XCTAssertTrue(m.values.allSatisfy { $0 == Reasons.building })
        }
        // Clap applying changes to S01
        s = ProjectActivity.Snapshot(); s.clap = .applying([.scene("S01")])
        XCTAssertEqual(Set(marked(.list).keys), [.scene("S01")]); XCTAssertEqual(Set(marked(.reel).keys), [.scene("S01")]); XCTAssertEqual(marked(.list).values.first?.cause, .clapWorking)
        s.clap = .thinking; for x in Surface.allCases { XCTAssertTrue(marked(x).isEmpty, "thinking marks nothing") }
        // an element marked on one surface is marked on every surface that shows it
        s = ProjectActivity.Snapshot(); s.proposals = [.init(id: "p", title: "t", targets: [.scene("S03")])]
        for e in Marks.elements(on: .list, file: f, assets: assets) {
            let on = Surface.allCases.filter { Marks.elements(on: $0, file: f, assets: assets).contains(e) }
            XCTAssertEqual(Set(on.map { Marks.marked(on: $0, file: f, assets: assets, in: s)[e] != nil }).count, 1, "\(e) is marked on all of \(on) or on none")
        }
        // a lock is not a temporary mark: it is the review badge
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        XCTAssertNil(Marks.temporary(.scene("S01"), in: ProjectActivity.Snapshot()))
    }

    func testTheMarkIsTheSameAsTheOneTheInspectorSays() {
        var s = ProjectActivity.Snapshot(); s.proposals = [.init(id: "p", title: "t", targets: [.scene("S02")])]
        XCTAssertEqual(Marks.temporary(.scene("S02"), in: s), Availability.edit(.scene("S02"), in: s, file: file).why, "one reason for the mark, the tooltip and the read-only form")
        s = ProjectActivity.Snapshot(); s.build = .init(version: "v1", phase: .testing)
        XCTAssertEqual(Marks.temporary(.item(scene: "S02", item: "i1"), in: s), Availability.edit(.item(scene: "S02", item: "i1"), in: s, file: file).why)
    }

    // MARK: the layout rule

    func testTheLayoutRulePersistentBadgesSideBySideAndNeverTheTemporaryMark() throws {
        try folder(scenes: ["S01", "S02"])
        let st = FilmBuild.status(store)
        for s in file.film { XCTAssertEqual(MarkLayout.badges(for: s, film: st), [.review, .build], "review first, then build, on every surface") }
        XCTAssertEqual(MarkLayout.badges(for: file.scenes.first { $0.id == "S04" }!, film: st), [.review], "a scene that is switched off is not in the film: no build state")
        XCTAssertEqual(MarkLayout.Badge.allCases, [.review, .build]); XCTAssertFalse(MarkLayout.temporaryIsABadge)
        var arch = file.scenes[0]; arch.archived = true
        XCTAssertEqual(MarkLayout.badges(for: arch, film: st), [.review], "an archived scene has no build")
        // the old format has no build badge
        try FileManager.default.removeItem(at: dir.appendingPathComponent("v1/scenes")); try "// old\n".write(to: dir.appendingPathComponent("v1/main.js"), atomically: true, encoding: .utf8)
        let legacy = FilmBuild.status(store); XCTAssertEqual(legacy.state, .legacy)
        for s in file.film { XCTAssertEqual(MarkLayout.badges(for: s, film: legacy), [.review]) }
        XCTAssertEqual(MarkLayout.badges(for: file.scenes[0], film: .empty), [.review], "before any version: only the review")
    }

    // MARK: the menu items

    func testUndoAndRedoSayWhyTheyAreOff() {
        XCTAssertEqual(Availability.undo(ProjectActivity.Snapshot(), can: true), .available)
        XCTAssertEqual(Availability.undo(ProjectActivity.Snapshot(), can: false).why?.reason, "Nothing to undo")
        XCTAssertEqual(Availability.undo(ProjectActivity.Snapshot(), can: false, redo: true).why?.reason, "Nothing to redo")
        var b = ProjectActivity.Snapshot(); b.build = .init(version: "v1", phase: .generating)
        XCTAssertEqual(Availability.undo(b, can: true).why, Reasons.building, "undo is a change: frozen during a build")
    }

    // MARK: what the player offers to generate

    func testTheOfferCountsMissingAndStaleScenesNeverLockedOnesAndAsksForHandEdits() throws {
        try folder(scenes: ["S01", "S02"])            // S03 has no file
        try SceneModules.recordGeneration(version: v, store: store)
        var o = SceneGeneration.offer(version: v, store: store, file: file)
        XCTAssertEqual(o.ids, ["S03"]); XCTAssertEqual(o.bannerLine, "S03 is not generated: shown as empty frames"); XCTAssertNil(o.staleLine); XCTAssertTrue(o.handEdited.isEmpty)
        XCTAssertEqual(FilmBuild.status(store).counter, "1 scene to generate")
        // S02's content changes: stale, and counted
        try store.apply(.scene(id: "S02", SceneEdit(text: "Two, changed")))
        o = SceneGeneration.offer(version: v, store: store, file: file)
        XCTAssertEqual(o.ids, ["S02", "S03"]); XCTAssertEqual(o.staleLine, "S02 is stale: its content, length or look changed since the file was generated"); XCTAssertEqual(o.missing, ["S03"])
        XCTAssertEqual(FilmBuild.status(store).counter, "2 scenes to generate"); XCTAssertEqual(FilmBuild.status(store).toGenerate, ["S03", "S02"])
        // a locked stale scene is left out with its reason, still counted
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        try store.apply(.decisions([DecisionChange(.palette, "#000009, #FFFFFF, #FF0000, #00FF00")], title: nil))
        o = SceneGeneration.offer(version: v, store: store, file: file)
        XCTAssertEqual(o.ids, ["S02", "S03"]); XCTAssertEqual(o.excluded.map { $0.id }, ["S01"]); XCTAssertEqual(o.excluded.first?.reason, SceneLock.reason("S01"))
        XCTAssertEqual(FilmBuild.status(store).counter, "3 scenes to generate")
        // a file edited by hand: asked about separately, never overwritten without the confirmation
        try module("by hand").write(to: SceneModules.url(version: v, scene: "S02", store: store), atomically: true, encoding: .utf8)
        o = SceneGeneration.offer(version: v, store: store, file: file)
        XCTAssertEqual(o.handEdited, ["S02"]); XCTAssertEqual(o.overwriteLine, "S02 was edited by hand: generating again overwrites the edit.")
        let card = try SceneGeneration.plan(["S02", "S03"], version: v, store: store)
        XCTAssertTrue(card.changes.contains { $0.label == "Your edits" && $0.before.contains("edited by hand") && $0.after == "overwritten by the new file" }, "the card says it")
        XCTAssertEqual(card.title, "Generate 2 scenes in v1: S02, S03", "still one card"); XCTAssertEqual(card.changes.first { $0.label == "Cost" }?.after.hasPrefix("2 model calls"), true)
        XCTAssertFalse(try SceneGeneration.plan(["S03"], version: v, store: store).changes.contains { $0.label == "Your edits" })
    }

    func testGeneratingAHandEditedFileNeedsTheConfirmationAndToolsAcceptTheCardAsIt() async throws {
        try folder(scenes: ["S01", "S02", "S03"]); try SceneModules.recordGeneration(version: v, store: store)
        let mine = module("mine")
        try mine.write(to: SceneModules.url(version: v, scene: "S02", store: store), atomically: true, encoding: .utf8)
        try store.apply(.scene(id: "S02", SceneEdit(text: "Two, changed")))
        let m = SceneWriterModel { _ in "```js\nreturn function () { /* generated */ };\n```" }
        let skill = try XCTUnwrap(Skill.root())
        do { _ = try await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: m); XCTFail("refused") }
        catch { XCTAssertTrue(error.localizedDescription.contains("S02 was edited by hand") && error.localizedDescription.contains("Nothing was written"), error.localizedDescription) }
        XCTAssertTrue(m.prompts.isEmpty, "the model was not asked"); XCTAssertEqual(try String(contentsOf: SceneModules.url(version: v, scene: "S02", store: store), encoding: .utf8), mine)
        // another scene is not blocked by it
        try store.apply(.scene(id: "S03", SceneEdit(text: "Three, changed")))
        _ = try await SceneGeneration.generate(["S03"], version: v, store: store, skill: skill, transport: m)
        // confirmed
        _ = try await SceneGeneration.generate(["S02"], version: v, store: store, skill: skill, transport: m, overwriting: ["S02"])
        XCTAssertTrue(try String(contentsOf: SceneModules.url(version: v, scene: "S02", store: store), encoding: .utf8).contains("generated"))
        // Clap: the card carries the line, accepting it is the confirmation
        try module("mine again").write(to: SceneModules.url(version: v, scene: "S02", store: store), atomically: true, encoding: .utf8)
        try store.apply(.scene(id: "S02", SceneEdit(text: "Two, changed again")))
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: skill, ui: ui); tools.sceneTransport = m
        let out = await tools.run("generate_scenes", ["scenes": ["S02"]]).text
        XCTAssertTrue(out.hasPrefix("generated S02"), out); XCTAssertTrue(ui.cards.last?.changes.contains { $0.label == "Your edits" } == true)
    }
}
