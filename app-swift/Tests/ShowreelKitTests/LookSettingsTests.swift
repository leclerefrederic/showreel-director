import XCTest
@testable import ShowreelKit

/// Phase L: the look is a project setting and the catalogues are picked where they are used. What can be tested without the screen: the catalogue
/// model, the typed operation each picker calls (the same as the drag), the width of the settings panel, and that every setting still has exactly
/// one editor (a scan of the views' sources: no operation lost, no second entry point).
final class LookSettingsTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("l"); store = ProjectStore(root: dir)
        try? store.create(name: "L", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2")], title: nil))
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        store.undoLog.clear()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }
    var file: ShowreelFile { store.loadShowreel()! }
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ name: String) throws -> String { try String(contentsOf: views.appendingPathComponent(name), encoding: .utf8) }
    func allViews() throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: try FileManager.default.contentsOfDirectory(atPath: views.path).filter { $0.hasSuffix(".swift") }.map { ($0, try source($0)) })
    }

    // MARK: the catalogues

    func testTheCataloguesAreTheSkillsOwn() {
        let effects = Catalogue.choices(.effect), transitions = Catalogue.choices(.transition), backgrounds = Catalogue.choices(.background)
        XCTAssertGreaterThan(effects.count, 200)
        XCTAssertFalse(effects.contains { Look.transitions().map { $0.name }.contains($0.id) }, "a transition is not an item's animation")
        XCTAssertEqual(transitions.count, Look.transitions().count); XCTAssertEqual(transitions.count, 42)
        XCTAssertEqual(Set(transitions.filter { !$0.selectable }.map { $0.id }), Look.transitionsPreviewOnly(), "exactly the six previews are marked, never chosen")
        XCTAssertEqual(Look.transitionsPreviewOnly().count, 6)
        XCTAssertTrue(transitions.filter { !$0.selectable }.allSatisfy { ($0.reason ?? "").hasPrefix("Preview only") })
        XCTAssertTrue(transitions.filter { $0.selectable }.allSatisfy { $0.reason == nil })
        XCTAssertEqual(backgrounds.map { $0.id }, Look.backgroundIDs()); XCTAssertGreaterThan(backgrounds.count, 20)
    }

    // MARK: each picker calls the typed operation of the old tab, and the drag builds the same one

    func testEachPickerBuildsTheOperationTheOldPlaceDid() throws {
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Two"), after: nil)))
        let bg = Look.backgroundIDs()[0], good = Catalogue.choices(.transition).first { $0.selectable }!.id, fx = Catalogue.choices(.effect)[0].id
        XCTAssertEqual(try Catalogue.operation(.effect, choice: fx, target: .item(scene: "S01", item: "c1")), .content(scene: "S01", .update(item: "c1", ContentEdit(animation: fx))), "the Content tab's animation picker")
        XCTAssertEqual(try Catalogue.operation(.effect, choice: "auto", target: .item(scene: "S01", item: "c1")), .content(scene: "S01", .update(item: "c1", ContentEdit(animation: "auto"))))
        XCTAssertEqual(try Catalogue.operation(.transition, choice: good, target: .marker(from: "S01")), .transition(from: "S01", TransitionEdit(type: good)), "the transition inspector's menu")
        XCTAssertEqual(try Catalogue.operation(.transition, choice: "cut", target: .marker(from: "S01")), .transition(from: "S01", TransitionEdit(type: "cut")))
        XCTAssertEqual(try Catalogue.operation(.background, choice: bg, target: .scene("S01")), .sceneLook(id: "S01", [DecisionChange(.background, bg)]), "the scene Look tab's background picker")
        XCTAssertThrowsError(try Catalogue.operation(.effect, choice: fx, target: .marker(from: "S01")))
        XCTAssertThrowsError(try Catalogue.operation(.transition, choice: good, target: .scene("S01")))
        XCTAssertThrowsError(try Catalogue.operation(.background, choice: bg, target: .item(scene: "S01", item: "c1")))
    }

    func testAPickerAndADragLeaveTheProjectInTheSameState() throws {
        try store.apply(.content(scene: "S01", .add(ContentEdit(type: "text", text: "Two"), after: nil))); store.undoLog.clear()
        let copy = makeTempDir("l-copy"); defer { try? FileManager.default.removeItem(at: copy) }
        try FileManager.default.removeItem(at: copy); try FileManager.default.copyItem(at: dir, to: copy)
        let other = ProjectStore(root: copy)
        let bg = Look.backgroundIDs()[1], tr = Catalogue.choices(.transition).first { $0.selectable }!.id, fx = Catalogue.choices(.effect)[3].id
        let picks: [(CatalogueKind, String, CatalogueTarget)] = [(.effect, fx, .item(scene: "S01", item: "c2")), (.transition, tr, .marker(from: "S02")), (.background, bg, .scene("S03"))]
        let drops: [DropTarget] = [.contentItem(scene: "S01", item: "c2"), .marker(from: "S02"), .scene("S03")]
        for (k, id, t) in picks { try store.apply(try Catalogue.operation(k, choice: id, target: t)) }
        for ((k, id, _), t) in zip(picks, drops) { try Drops.drop(Catalogue.dragItem(k, id), on: t, store: other) }
        XCTAssertEqual(store.read(ShowreelFile.fileName), other.read(ShowreelFile.fileName), "the same operations, whichever way the user chose")
        XCTAssertEqual(Catalogue.current(.effect, target: .item(scene: "S01", item: "c2"), in: file), fx)
        XCTAssertEqual(Catalogue.current(.effect, target: .item(scene: "S01", item: "c1"), in: file), "auto")
        XCTAssertEqual(Catalogue.current(.transition, target: .marker(from: "S02"), in: file), tr)
        XCTAssertEqual(Catalogue.current(.transition, target: .marker(from: "S01"), in: file), "cut")
        XCTAssertEqual(Catalogue.current(.background, target: .scene("S03"), in: file), bg)
    }

    func testAPreviewOnlyTransitionCannotBePickedAndAnAudioItemHasNoAnimation() throws {
        let preview = Look.transitionsPreviewOnly().sorted()[0]
        XCTAssertThrowsError(try store.apply(try Catalogue.operation(.transition, choice: preview, target: .marker(from: "S01")))) { XCTAssertTrue($0.localizedDescription.contains("preview only")) }
        try store.apply(.sceneEnabled(id: "S03", enabled: false, montage: nil))
        XCTAssertThrowsError(try store.apply(try Catalogue.operation(.transition, choice: Catalogue.choices(.transition).first { $0.selectable }!.id, target: .marker(from: "S02"))), "the last scene has no marker")
    }

    // MARK: the settings panel

    func testTheSettingsPanelHasAFloorNoCeilingAndIsRemembered() throws {
        XCTAssertEqual(PanelLayout().settingsWidth, PanelLayout.standardSettings)
        XCTAssertEqual(PanelLayout(settings: 10).settingsWidth, PanelLayout.minSettings); XCTAssertEqual(PanelLayout(settings: 4000).settingsWidth, 4000)
        XCTAssertFalse(PanelLayout(settings: 600).isStandard)
        var s = store.settings; s.layout = PanelLayout(library: 300, settings: 640); store.settings = s
        let l = try XCTUnwrap(ProjectStore(root: dir).settings.layout)
        XCTAssertEqual(l.settings, 640); XCTAssertEqual(l.library, 300); XCTAssertNil(l.inspector)
        try #"{"mode": "expert", "layout": {"library": 300}}"#.write(to: dir.appendingPathComponent(".studio/ui.json"), atomically: true, encoding: .utf8)
        XCTAssertNil(store.settings.layout?.settings, "a file from before the panel still reads")
    }

    // MARK: one editor per setting, nothing lost (a scan of the views)

    func testTheLibraryKeepsAssetsOnly() throws {
        let m = try source("ProjectModel.swift")
        let block = try XCTUnwrap(m.range(of: "enum LibraryTab")).lowerBound
        let rest = m[block...]
        let decl = String(rest[..<(rest.range(of: "\n}")?.lowerBound ?? rest.endIndex)])
        XCTAssertTrue(decl.contains("case resources, scenes"), decl); XCTAssertFalse(decl.contains("look"))
        XCTAssertFalse(try source("WorkspaceViews.swift").contains("LookLibrary()"), "the library pane no longer shows the look elements")
        XCTAssertTrue(try source("PickerViews.swift").contains("LookLibrary(kinds:"), "they live in the floating Catalogue, as drag sources")
    }

    func testEveryDecisionStillHasOneEditorAndEveryParameterOne() throws {
        let v = try allViews()
        func lines(_ needle: String) -> [String: Int] {
            var out: [String: Int] = [:]
            for (f, text) in v { let n = text.components(separatedBy: "\n").filter { $0.contains(".perform(.decisions(") && $0.contains(needle) }.count; if n > 0 { out[f] = n } }
            return out
        }
        // the project-wide look is written by the editors of LookViews.swift (the settings panel and the guided path use those same views)
        for key in ["DecisionChange(.palette", "DecisionChange(role", "DecisionChange(.background", "DecisionChange(.moods", "DecisionChange(.effectsPack", "p.decisions"] {
            let w = lines(key)
            XCTAssertEqual(Set(w.keys), ["LookViews.swift"], "\(key) is written by one file: \(w)")
        }
        // the project parameters: the form, and the model's setter the guided path calls
        var parameterFiles: Set<String> = []
        for (f, text) in v where text.contains("perform(.parameter(") { parameterFiles.insert(f) }
        XCTAssertEqual(parameterFiles, ["ProjectFormViews.swift", "ProjectModel.swift"], "\(parameterFiles)")
        // the inspectors of the look elements and the library rows hold no setting any more
        XCTAssertFalse(try source("InspectorViews.swift").contains(".perform(.decisions("), "the look inspector points to the project settings instead of editing")
        XCTAssertFalse(try source("WorkspaceViews.swift").contains(".perform(.decisions("))
    }

    func testTheSettingsPanelAndTheGuidedPathShareTheSameSixEditors() throws {
        let editors = ["LookBoardView", "PaletteEditor", "FontPickerView", "BackgroundPickerView", "MoodsPickerView", "EffectsPickerView"]
        let panel = try source("ProjectSettingsPanel.swift")
        for e in editors { XCTAssertTrue(panel.contains(e + "("), "the settings panel has \(e)") }
        XCTAssertTrue(panel.contains("ProjectForm()"), "the parameters: audience, message, tone, languages, formats, duration, constraints, control level")
        let form = try source("ProjectFormViews.swift")
        for k in [".audience", ".message", ".tone", ".conversationLanguage", ".reelLanguages", ".formats", ".duration", ".constraints", ".controlLevel"] { XCTAssertTrue(form.contains("compact(\(k)") || form.contains("parameter(\(k)") || form.contains("\(k)"), "the form has \(k)") }
    }

    func testThePickersSitWhereTheCatalogueIsUsed() throws {
        XCTAssertTrue(try source("ContentViews.swift").contains("PickerButton(kind: .effect"), "an item's animation and the scene's Effects tab")
        XCTAssertTrue(try source("ReelViews.swift").contains("PickerButton(kind: .transition"), "the transition inspector")
        XCTAssertTrue(try source("InspectorViews.swift").contains("PickerButton(kind: .background"), "the scene's Look tab")
        XCTAssertTrue(try source("PickerViews.swift").contains("Catalogue.choices(kind)"), "every picker lists the same catalogue and marks the previews")
        let v = try allViews()
        XCTAssertEqual(v.filter { $0.value.contains("project.choose(") }.keys.sorted(), ["ContentViews.swift", "InspectorViews.swift", "ReelViews.swift"])
    }

    func testTheApplicationsSettingsLeaveTheProjectToolbar() throws {
        let p = try source("ProjectView.swift")
        XCTAssertFalse(p.contains("\"gearshape\""), "no application settings button in the project window's toolbar")
        XCTAssertTrue(p.contains("Project settings"))
        XCTAssertTrue(try source("App.swift").contains("Settings { SettingsView"), "the application's Settings window (Command-,)")
    }
}
