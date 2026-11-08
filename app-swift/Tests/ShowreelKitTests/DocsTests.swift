import XCTest
@testable import ShowreelKit

final class DocsTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("docs"); store = ProjectStore(root: dir) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func sample() -> ShowreelFile {
        var f = ShowreelFile(name: "Demo", created: "2026-11-09", conversationLanguage: "fr", reelLanguages: ["en", "fr"], step: "style")
        f.parameters.audience = "Product teams at mid-size companies"
        f.parameters.message = "Notes that stay calm"
        f.parameters.tone = "warm, confident"
        f.parameters.constraints = "No customer names on screen."
        f.decisions.palette = ["#101820", "#F2AA4C", "#FFFFFF"]
        f.decisions.fonts = .init(titles: "Anton", text: "Inter")
        f.decisions.background = .init(id: "aurora", mood: "cinematic")
        f.decisions.moods = ["Kinetic punch"]
        f.decisions.formats = ["16:9", "9:16"]
        f.decisions.duration = 45
        f.decisions.track = .init(file: "assets/prepared/audio-01-theme.mp3", bpm: 120)
        f.gates = ["interview": "passed", "assets": "open"]
        f.scenes = [
            .init(id: "S01", start: 0, end: 4, text: "Notes, finally calm", texts: ["fr": "Des notes enfin sereines"], visual: "Logo rises from ink",
                  feeling: "calm, 1/5", handoff: "wipe left", inCuts: "15s, 45s", extra: ["Sound": "soft pad"]),
            .init(id: "S02", start: 4, end: 9, text: "Capture anything | fast", texts: ["fr": "Tout capturer"], visual: "Cards fly in", feeling: "curious, 2/5",
                  handoff: "cut", inCuts: "45s", extra: ["Sound": "tick"], status: "modify", note: "shorter"),
            .init(id: "S03", status: "ditched"),
        ]
        return f
    }
    let assets = [AssetRow(id: "logo-01", file: "prepared/logo-01-notes.svg", original: "notes-logo.svg", origin: "prepared", type: "logo", status: "approved", scene: "S01")]

    /// Golden files: set SHOWREEL_RECORD_GOLDEN=1 to rewrite them, then read the diff before committing.
    func golden(_ name: String, _ actual: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let url = fixtureURL("generated/" + name)
        if ProcessInfo.processInfo.environment["SHOWREEL_RECORD_GOLDEN"] == "1" { try actual.write(to: url, atomically: true, encoding: .utf8) }
        let want = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(actual, want, "golden file \(name)", file: file, line: line)
    }

    func testGoldenBrief() throws { try golden("brief.md", try XCTUnwrap(ProjectDocs.content(of: "brief.md", from: sample(), assets: assets))) }
    func testGoldenStyleSheet() throws { try golden("style-sheet.md", try XCTUnwrap(ProjectDocs.content(of: "style-sheet.md", from: sample(), assets: assets))) }
    func testGoldenStoryboard() throws { try golden("storyboard.md", try XCTUnwrap(ProjectDocs.content(of: "storyboard.md", from: sample(), assets: assets))) }

    func testNothingToSayMeansNoFile() throws {
        let f = ShowreelFile(name: "Empty")
        XCTAssertNil(ProjectDocs.content(of: "brief.md", from: f, assets: []))
        XCTAssertNil(ProjectDocs.content(of: "style-sheet.md", from: f, assets: []))
        XCTAssertNil(ProjectDocs.content(of: "storyboard.md", from: f, assets: []))
    }

    func testGeneratedStoryboardIsReadByTheSkillsParser() throws {
        // the skill's own table reader (build_scene_cards.py) must find IDs, times and texts in what the app writes
        try store.save(sample())
        let sb = dir.appendingPathComponent("storyboard.md").path
        let py = """
        import sys, json; sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[1])
        from build_scene_cards import parse_table, find, seconds
        head, rows = parse_table(open(sys.argv[2], encoding="utf-8").read())
        cid = find(head, "id", "#", "scene"); ct = find(head, "time")
        print(json.dumps([[r[cid], bool(seconds(r[ct]))] for r in rows]))
        """
        let skill = try XCTUnwrap(Skill.root())
        let out = try runPython(py, args: [skill.appendingPathComponent("scripts").path, sb])
        XCTAssertEqual(out.trimmingCharacters(in: .whitespacesAndNewlines), "[[\"S01\", true], [\"S02\", true], [\"S03\", false]]")
    }

    // MARK: sync, hashes, never a silent overwrite

    func state(_ file: String) -> DocState? { DocSync.sync(store).first { $0.file == file }?.state }

    func testFirstSaveCreatesTheDocuments() throws {
        try store.save(sample())
        XCTAssertNotNil(store.read("brief.md")); XCTAssertNotNil(store.read("style-sheet.md")); XCTAssertNotNil(store.read("storyboard.md"))
        let recorded = DocSync.hashes(store)
        XCTAssertEqual(Set(recorded.keys), Set(ProjectDocs.files))
        XCTAssertEqual(recorded["brief.md"], ProjectDocs.sha256(try XCTUnwrap(store.read("brief.md"))))
        XCTAssertEqual(state("brief.md"), .inSync)
    }

    func testAppChangesRegenerateTheFilesItWrote() throws {
        try store.save(sample())
        try store.apply(.parameter(.audience, "Someone new"))
        XCTAssertTrue(try XCTUnwrap(store.read("brief.md")).contains("Someone new"))
        XCTAssertEqual(state("brief.md"), .inSync)
    }

    func testAnExternalEditIsNeverOverwritten() throws {
        try store.save(sample())
        let edited = try XCTUnwrap(store.read("brief.md")).replacingOccurrences(of: "Notes that stay calm", with: "Notes that never shout")
        try "\(edited)".write(to: dir.appendingPathComponent("brief.md"), atomically: true, encoding: .utf8)   // a chat session wrote it
        XCTAssertEqual(state("brief.md"), .edited)
        try store.apply(.parameter(.tone, "bold"))   // the app changes something else
        XCTAssertEqual(store.read("brief.md"), edited, "the externally edited file is left alone")
        XCTAssertEqual(state("brief.md"), .edited)
        XCTAssertTrue(try XCTUnwrap(store.read("style-sheet.md")).contains("bold"), "the other files still follow")
    }

    func testAForeignFileIsNeverOverwritten() throws {
        try store.write("brief.md", "# Written in a chat\n\nAudience: engineers\n")
        try store.save(sample())
        XCTAssertEqual(store.read("brief.md"), "# Written in a chat\n\nAudience: engineers\n")
        XCTAssertEqual(state("brief.md"), .foreign)
    }

    func testPendingReportsWithoutWriting() throws {
        try store.save(sample())
        XCTAssertTrue(DocSync.pending(store).isEmpty)
        let edited = try XCTUnwrap(store.read("brief.md")) + "\nA line added in a chat.\n"
        try edited.write(to: dir.appendingPathComponent("brief.md"), atomically: true, encoding: .utf8)
        try "# Chat style sheet\n".write(to: dir.appendingPathComponent("style-sheet.md"), atomically: true, encoding: .utf8)
        let p = DocSync.pending(store)
        XCTAssertEqual(p.map { $0.file }, ["brief.md", "style-sheet.md"])
        XCTAssertEqual(p.map { $0.state }, [.edited, .edited])
        XCTAssertEqual(store.read("brief.md"), edited, "looking at the state never writes")
    }

    func testOverwriteIsAnExplicitChoiceAndKeepsTheOldVersion() throws {
        try store.write("brief.md", "# Written in a chat\n")
        try store.save(sample())
        try DocSync.overwrite(store, "brief.md")
        XCTAssertTrue(try XCTUnwrap(store.read("brief.md")).hasPrefix(ProjectDocs.header))
        XCTAssertEqual(state("brief.md"), .inSync)
        XCTAssertEqual(store.snapshots("brief.md").compactMap { store.content(of: $0) }, ["# Written in a chat\n"])
    }

    func testReimportReadsTheEditedFilesBack() throws {
        try store.save(sample())
        var brief = try XCTUnwrap(store.read("brief.md"))
        brief = brief.replacingOccurrences(of: "Notes that stay calm", with: "Notes that never shout")
        try brief.write(to: dir.appendingPathComponent("brief.md"), atomically: true, encoding: .utf8)
        // edit the storyboard table the way a chat would: change a cell, drop S03, add S04
        var blocks = MarkdownTable.parse(try XCTUnwrap(store.read("storyboard.md")))
        let ti = try XCTUnwrap(blocks.firstIndex { if case .table = $0 { return true }; return false })
        guard case .table(var t) = blocks[ti] else { return XCTFail() }
        t.rows.removeAll { $0[0] == "S03" }
        t.rows[1][try XCTUnwrap(t.header.firstIndex(of: "fr"))] = "Tout noter"
        var fresh = [String](repeating: "", count: t.header.count)
        for (h, v) in ["ID": "S04", "Time": "9-12 s", "On-screen text": "Fresh", "Image and motion": "Pop", "Status": "open"] { fresh[try XCTUnwrap(t.header.firstIndex(of: h))] = v }
        t.rows.append(fresh)
        blocks[ti] = .table(t)
        try MarkdownTable.write(blocks).write(to: dir.appendingPathComponent("storyboard.md"), atomically: true, encoding: .utf8)

        XCTAssertEqual(state("brief.md"), .edited)
        XCTAssertEqual(state("storyboard.md"), .edited)
        let r = try XCTUnwrap(DocSync.reimport(store, files: ["brief.md", "storyboard.md"]))
        XCTAssertEqual(r.proposed.parameters.message, "Notes that never shout")
        XCTAssertEqual(r.proposed.scenes.map { $0.id }, ["S01", "S02", "S04", "S03"], "a scene that left the table is kept, marked ditched; IDs are never reused")
        XCTAssertEqual(r.proposed.scenes.first { $0.id == "S02" }?.note, "shorter", "the review note of a known scene survives")
        XCTAssertEqual(r.proposed.scenes.first { $0.id == "S03" }?.status, "ditched")
        XCTAssertTrue(r.changes.contains { $0.label == "Message" })
        XCTAssertEqual(store.loadShowreel()?.parameters.message, "Notes that stay calm", "nothing is saved before the user accepts")
        XCTAssertEqual(r.proposed.scenes.first { $0.id == "S02" }?.texts["fr"], "Tout noter")

        let edited = try XCTUnwrap(store.read("brief.md"))
        try DocSync.acceptReimport(store, files: ["brief.md", "storyboard.md"], proposed: r.proposed)
        XCTAssertEqual(store.loadShowreel()?.parameters.message, "Notes that never shout")
        XCTAssertEqual(state("brief.md"), .inSync)
        XCTAssertEqual(store.read("brief.md"), edited, "what the user wrote is what the app now generates, so nothing is lost")
        XCTAssertEqual(state("storyboard.md"), .inSync)
        XCTAssertTrue(try XCTUnwrap(store.read("storyboard.md")).contains("S04"))
    }

    func testReimportOfAChatsBriefReadsLabelledLines() throws {
        try store.save(ShowreelFile(name: "Chat"))
        try store.write("brief.md", "# Brief\n\nAudience: engineers at banks\nMessage: Safe by default\nTone: sober\n\n## Look and motion\nPalette: #000000, #FFFFFF\nTitles font: Anton\nReel languages: English, French\nDuration: 30 s\n")
        let r = try XCTUnwrap(DocSync.reimport(store, files: ["brief.md"]))
        XCTAssertEqual(r.proposed.parameters.audience, "engineers at banks")
        XCTAssertEqual(r.proposed.parameters.message, "Safe by default")
        XCTAssertEqual(r.proposed.decisions.palette, ["#000000", "#FFFFFF"])
        XCTAssertEqual(r.proposed.reelLanguages, ["en", "fr"])
        XCTAssertEqual(r.proposed.decisions.duration, 30)
    }
}

func runPython(_ code: String, args: [String]) throws -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = ["python3", "-c", code] + args
    let out = Pipe()
    p.standardOutput = out; p.standardError = Pipe()
    try p.run()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}
