import XCTest
@testable import ShowreelKit

func fixtureURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures").appendingPathComponent(path)
}

/// The contract of docs/studio-spec.md section 5.1b, from both sides.
final class StudioFileTests: XCTestCase {
    var dir: URL!
    override func setUp() { dir = makeTempDir("a2") }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testDecodesTheOutputOfExportStudio() throws {
        // the fixture is the real output of scripts/export_studio.py; tools/check.py regenerates it and compares
        let text = try String(contentsOf: fixtureURL("studio-export/showreel.json"), encoding: .utf8)
        let f = try ShowreelFile.decode(text)
        XCTAssertEqual(f.name, "export-sample")
        XCTAssertEqual(f.conversationLanguage, "fr")
        XCTAssertEqual(f.reelLanguages, ["en", "fr"])
        XCTAssertEqual(f.parameters.audience, "Product teams at mid-size companies")
        XCTAssertEqual(f.parameters.tone, "warm, confident")
        XCTAssertEqual(f.decisions.palette, ["#101820", "#F2AA4C", "#FFFFFF"])
        XCTAssertEqual(f.decisions.fonts, .init(titles: "Anton", text: "Inter"))
        XCTAssertEqual(f.decisions.duration, 45)
        XCTAssertEqual(f.decisions.background, .init(id: "aurora", mood: "cinematic"))
        XCTAssertEqual(f.gates["interview"], "passed")
        XCTAssertEqual(f.origin?.tool, "skill")
        XCTAssertEqual(f.origin?.files, ["brief.md", "style-sheet.md", "storyboard.md"])
        XCTAssertEqual(f.scenes.map { $0.id }, ["S01", "S02", "S03"], "an ordered array")
        let s1 = f.scenes[0]
        XCTAssertEqual(s1.duration, 4)
        XCTAssertEqual(s1.text, "Notes, finally calm")
        XCTAssertEqual(s1.texts, ["Text FR": "Des notes enfin sereines"])
        XCTAssertEqual(s1.extra, ["Sound": "soft pad"])
        XCTAssertEqual(s1.inCuts, "15s, 45s")
        XCTAssertEqual(f.scenes[2].status, "ditched", "a ditched scene stays in the list, marked")
        XCTAssertEqual(f.unknown["futureKey"], .object(["kept": .bool(true)]), "keys from a newer skill are kept")
    }

    func testUnknownKeysSurviveLoadAndSaveAtEveryLevel() throws {
        let src = """
        {"schema":1,"name":"K","topNew":[1,2],
         "parameters":{"audience":"a","paramNew":"p"},
         "decisions":{"palette":["#000000"],"decNew":{"x":1},"fonts":{"titles":"T","fontNew":true},"track":{"bpm":120,"trackNew":"t"},"background":{"id":"b","bgNew":2}},
         "origin":{"tool":"skill","exportedAt":"2026-11-09","originNew":"o"},
         "scenes":[{"id":"S01","text":"x","sceneNew":"s"}]}
        """
        let f = try ShowreelFile.decode(src)
        let again = try ShowreelFile.decode(try f.encoded())
        XCTAssertEqual(again, f)
        let out = try f.encoded()
        for k in ["topNew", "paramNew", "decNew", "fontNew", "trackNew", "bgNew", "originNew", "sceneNew"] { XCTAssertTrue(out.contains(k), k) }
        // and through the store, which marks the file as the app's
        let store = ProjectStore(root: dir)
        try store.write(ShowreelFile.fileName, src)
        var loaded = try XCTUnwrap(store.loadShowreel())
        loaded.parameters.audience = "changed"
        try store.save(loaded)
        let disk = try XCTUnwrap(store.read(ShowreelFile.fileName))
        for k in ["topNew", "paramNew", "decNew", "fontNew", "trackNew", "bgNew", "originNew", "sceneNew", "\"exportedAt\" : \"2026-11-09\""] { XCTAssertTrue(disk.contains(k), k) }
        XCTAssertTrue(disk.contains("\"tool\" : \"studio\""), "the first save marks the app as the owner")
    }

    func testOldSceneDictionaryIsRead() throws {
        let f = try ShowreelFile.decode("{\"schema\":1,\"name\":\"Old\",\"scenes\":{\"S02\":{\"status\":\"modify\",\"note\":\"shorter\"},\"S01\":{\"status\":\"ok\",\"note\":\"\"}}}")
        XCTAssertEqual(f.scenes.map { $0.id }, ["S01", "S02"])
        XCTAssertEqual(f.scenes[1].status, "modify")
        XCTAssertEqual(f.scenes[1].note, "shorter")
        // saving writes the array form
        let out = try f.encoded()
        XCTAssertTrue(out.contains("\"scenes\" : [") && !out.contains("\"scenes\" : {"))
    }

    func testAnExportedProjectOpensInTheAppAndItsFilesAreNotOverwritten() throws {
        // copy the sample project and its export into a temp folder, as the owner would open it
        let proj = dir.appendingPathComponent("p")
        try FileManager.default.copyItem(at: fixtureURL("studio-export/export-sample"), to: proj)
        try FileManager.default.copyItem(at: fixtureURL("studio-export/showreel.json"), to: proj.appendingPathComponent("showreel.json"))
        let store = ProjectStore(root: proj)
        XCTAssertNil(store.showreelProblem)
        let f = try XCTUnwrap(store.loadShowreel())
        XCTAssertFalse(f.isStudioOwned)
        let before = try XCTUnwrap(store.read("brief.md"))
        var g = f; g.parameters.audience = "Someone else"
        try store.save(g)
        XCTAssertTrue(store.loadShowreel()?.isStudioOwned == true)
        XCTAssertEqual(store.read("brief.md"), before, "the chat's brief is not overwritten by the first save")
        XCTAssertEqual(DocSync.sync(store).first { $0.file == "brief.md" }?.state, .foreign)
    }

    func testAnUnreadableShowreelIsReportedNotReplaced() throws {
        let store = ProjectStore(root: dir)
        try store.write(ShowreelFile.fileName, "{ not json")
        XCTAssertNotNil(store.showreelProblem)
        XCTAssertNil(store.loadShowreel())
        XCTAssertTrue(store.hasShowreel)
    }

    // MARK: the python organiser's format

    func testManifestKeepsTheOrganisersColumns() throws {
        let store = ProjectStore(root: dir)
        try Assets.save([AssetRow(id: "logo-01", file: "prepared/logo-01-x.svg", original: "x.svg", origin: "prepared", type: "logo", status: "approved", scene: "S01")], store)
        XCTAssertEqual(store.read(Assets.manifestPath)?.components(separatedBy: "\n").first, "id,file,original,origin,type,status,licence_note,scene,notes")
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, ["S01"])
    }
}
