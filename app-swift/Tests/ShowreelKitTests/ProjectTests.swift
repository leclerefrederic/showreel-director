import XCTest
@testable import ShowreelKit

func makeTempDir(_ name: String = "kit") -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("showreel-\(name)-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

final class ProjectTests: XCTestCase {
    var dir: URL!
    override func setUp() { dir = makeTempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func fullFile() -> ShowreelFile {
        var f = ShowreelFile(name: "Demo", created: "2026-11-08", conversationLanguage: "fr", reelLanguages: ["en", "fr"], step: "style")
        f.decisions.palette = ["#101820", "#F2AA4C", "#FFFFFF"]
        f.decisions.fonts = .init(titles: "Anton", text: "Inter")
        f.decisions.background = .init(id: "aurora", mood: "cinematic")
        f.decisions.moods = ["Kinetic punch"]
        f.decisions.effectsPack = "Kinetic punch"
        f.decisions.formats = ["16:9", "9:16"]
        f.decisions.duration = 45
        f.decisions.track = .init(file: "assets/prepared/audio-01-theme.mp3", bpm: 120)
        f.gates = ["interview": "passed", "assets": "open", "release": "open"]
        f.parameters.audience = "Product teams"
        f.scenes = [.init(id: "S01", start: 0, end: 4, text: "Hello", status: "ok"), .init(id: "S02", start: 4, end: 9, text: "Next", status: "modify", note: "shorter")]
        return f
    }

    func testShowreelRoundTrip() throws {
        let f = fullFile()
        let text = try f.encoded()
        XCTAssertEqual(try ShowreelFile.decode(text), f)
        XCTAssertTrue(text.contains("\"schema\" : 1"))
        XCTAssertEqual(f.origin?.tool, nil, "a file in memory has no origin until the app saves it")
        XCTAssertTrue(text.contains("\"duration\" : 45"), "whole durations stay whole numbers")
        let store = ProjectStore(root: dir)
        try store.save(f)
        var saved = f; saved.origin = .init(tool: "studio")
        XCTAssertEqual(store.loadShowreel(), saved, "the first save marks the app as the owner of the file")
        XCTAssertTrue(store.loadShowreel()?.isStudioOwned == true)
    }

    func testHandWrittenFileWithMissingKeysLoads() throws {
        let f = try ShowreelFile.decode("{\"schema\":1,\"name\":\"Hand\"}")
        XCTAssertEqual(f.name, "Hand")
        XCTAssertEqual(f.step, "start")
        XCTAssertTrue(f.reelLanguages.isEmpty && f.gates.isEmpty && f.scenes.isEmpty)
        XCTAssertNil(f.parameters.audience)
    }

    func testImportOfAMarkdownOnlyProject() throws {
        let store = ProjectStore(root: dir)
        try store.write("brief.md", """
        # Brief
        Conversation language: French
        Reel languages: English, French

        ## Look and motion
        Palette: #101820 ink, #f2aa4c amber, #FFFFFF white, #101820 again.
        Titles font: Anton
        Body font: Inter

        ## Sound
        A track at #1 priority, not a colour.
        """)
        try store.write("style-sheet.md", "Palette: #00FF00\n")
        let r = ProjectImporter.importMarkdown(from: dir)
        XCTAssertEqual(r.sources, ["brief.md", "style-sheet.md"])
        XCTAssertEqual(r.file.decisions.palette, ["#101820", "#F2AA4C", "#FFFFFF"], "from the Look section, upper case, no duplicates")
        XCTAssertEqual(r.file.decisions.fonts, .init(titles: "Anton", text: "Inter"))
        XCTAssertEqual(r.file.reelLanguages, ["en", "fr"])
        XCTAssertEqual(r.file.conversationLanguage, "fr")
        XCTAssertFalse(r.found.isEmpty)
        XCTAssertNil(store.loadShowreel(), "reading never writes")
        let before = try XCTUnwrap(store.read("brief.md"))
        try ProjectImporter.confirm(r, in: dir)
        XCTAssertEqual(store.loadShowreel()?.decisions.palette, r.file.decisions.palette)
        XCTAssertEqual(store.read("brief.md"), before, "the chat's brief is foreign: confirming the import never rewrites it")
        XCTAssertEqual(DocSync.sync(store).first { $0.file == "brief.md" }?.state, .foreign)
    }

    func testImportOfAnEmptyFolderFindsNothing() {
        let r = ProjectImporter.importMarkdown(from: dir)
        XCTAssertTrue(r.found.isEmpty && r.sources.isEmpty)
        XCTAssertEqual(r.file.name, dir.lastPathComponent)
    }

    func testHistoryDiffAndRestore() throws {
        let store = ProjectStore(root: dir)
        try store.write("notes.md", "v1")
        XCTAssertTrue(store.snapshots("notes.md").isEmpty, "the first write has nothing to keep")
        try store.write("notes.md", "v2")
        try store.write("notes.md", "v2")  // no change: no snapshot
        try store.write("notes.md", "v3")
        let snaps = store.snapshots("notes.md")
        XCTAssertEqual(snaps.count, 2)
        XCTAssertEqual(store.content(of: snaps[0]), "v2", "newest first")
        XCTAssertEqual(store.content(of: snaps[1]), "v1")
        try store.restore("notes.md", snaps[1])
        XCTAssertEqual(store.read("notes.md"), "v1")
        XCTAssertEqual(store.snapshots("notes.md").count, 3, "a restore keeps the version it replaced")
    }

    func testHistoryKeepsTheLast50() throws {
        let store = ProjectStore(root: dir)
        for i in 0..<56 { try store.write("n.md", "v\(i)") }
        let snaps = store.snapshots("n.md")
        XCTAssertEqual(snaps.count, ProjectStore.historyLimit)
        XCTAssertEqual(store.content(of: snaps[0]), "v54", "the newest kept version is the one before the last write")
        XCTAssertEqual(store.content(of: snaps[49]), "v5")
    }

    func testWritesStayInsideTheProject() {
        let store = ProjectStore(root: dir)
        XCTAssertThrowsError(try store.write("../escape.txt", "no"))
        XCTAssertThrowsError(try store.write("/etc/hosts", "no"))
        XCTAssertThrowsError(try store.write(".studio/ui.json", "no"), ".studio is private")
        XCTAssertNoThrow(try store.write("deep/er/file.txt", "ok"))
    }

    func testStudioSettings() {
        let store = ProjectStore(root: dir)
        XCTAssertFalse(store.settings.applyDirectly)
        store.settings = StudioSettings(applyDirectly: true)
        XCTAssertTrue(ProjectStore(root: dir).settings.applyDirectly)
    }

    func testTreeHidesPrivateFilesAndSortsFoldersFirst() throws {
        let store = ProjectStore(root: dir)
        try store.write("b.md", "x"); try store.write("assets/a.png", "x"); try store.write(".hidden", "x")
        try store.write("brief.md", "x"); try store.write("brief.md", "y") // creates .studio/history
        let tree = ProjectTree.scan(dir)
        XCTAssertEqual(tree.map { $0.name }, ["assets", "b.md", "brief.md"])
        XCTAssertEqual(tree[0].children?.map { $0.id }, ["assets/a.png"])
        XCTAssertEqual(ProjectTree.kind(of: "a/b.MD"), .markdown)
        XCTAssertEqual(ProjectTree.kind(of: "x.csv"), .csv)
        XCTAssertEqual(ProjectTree.kind(of: "x.json"), .json)
        XCTAssertEqual(ProjectTree.kind(of: "x.mp4"), .binary)
        XCTAssertEqual(ProjectTree.kind(of: "main.js"), .text)
    }

    func testLibraryRoundTripPinArchive() throws {
        let url = dir.appendingPathComponent("projects.json")
        let lib = ProjectLibrary(url: url)
        let a = lib.add(path: dir.appendingPathComponent("a").path, now: Date(timeIntervalSince1970: 100))
        let b = lib.add(path: dir.appendingPathComponent("b").path, now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(lib.visible.map { $0.id }, [b.id, a.id], "most recent first")
        lib.setPinned(a.id, true)
        XCTAssertEqual(lib.visible.first?.id, a.id, "pinned first")
        XCTAssertEqual(lib.add(path: dir.appendingPathComponent("a/../a").path).id, a.id, "same folder, same entry")
        lib.setArchived(b.id, true)
        let again = ProjectLibrary(url: url)
        XCTAssertEqual(again.visible.map { $0.id }, [a.id])
        XCTAssertEqual(again.archived.map { $0.id }, [b.id])
        XCTAssertEqual(again.entries.count, 2)
        again.remove(b.id)
        XCTAssertEqual(ProjectLibrary(url: url).entries.count, 1)
    }

    func testLibraryReadsNameAndStepFromShowreel() throws {
        let p = dir.appendingPathComponent("proj")
        try ProjectStore(root: p).create(name: "Named", conversationLanguage: "en", reelLanguages: [])
        let lib = ProjectLibrary(url: dir.appendingPathComponent("projects.json"))
        lib.add(path: p.path)
        lib.refreshMetadata()
        XCTAssertEqual(lib.entries.first?.name, "Named")
        XCTAssertEqual(lib.entries.first?.step, "start")
    }

    func testChatHistoryPerProject() throws {
        let a = ChatStore(root: dir)
        a.append(ChatRecord(role: "user", text: "hello"))
        a.append(ChatRecord(role: "assistant", text: "hi"))
        let reopened = ChatStore(root: dir)
        XCTAssertEqual(reopened.load().map { $0.text }, ["hello", "hi"], "history survives a reopen")
        XCTAssertTrue(reopened.session.path.contains("/.studio/chat/"))
        reopened.startNewSession()
        XCTAssertTrue(reopened.load().isEmpty, "a new session starts empty")
        reopened.append(ChatRecord(role: "user", text: "again"))
        XCTAssertEqual(reopened.sessions.count, 2)
        XCTAssertEqual(ChatStore(root: dir).load().map { $0.text }, ["again"], "the latest session opens")
        let other = makeTempDir("other"); defer { try? FileManager.default.removeItem(at: other) }
        XCTAssertTrue(ChatStore(root: other).load().isEmpty, "projects never share a history")
    }

    func testManySessionsInARowGetDistinctOrderedNames() {
        let c = ChatStore(root: dir)
        for i in 0..<25 { c.append(ChatRecord(role: "user", text: "q\(i)")); c.startNewSession() }
        c.append(ChatRecord(role: "user", text: "last"))
        XCTAssertEqual(c.sessions.count, 26, "no two sessions share a file, even within one millisecond")
        XCTAssertEqual(ChatStore(root: dir).load().map { $0.text }, ["last"])
    }

    func testSeedAlternatesRolesAndDropsTheLastUserTurn() {
        let r = [ChatRecord(role: "assistant", text: "stray"), ChatRecord(role: "user", text: "q1"), ChatRecord(role: "user", text: "q1b"),
                 ChatRecord(role: "assistant", text: "a1"), ChatRecord(role: "user", text: "new")]
        let seed = ChatStore.seed(from: r)
        XCTAssertEqual(seed.count, 2)
        XCTAssertEqual(seed[0]["role"] as? String, "user")
        XCTAssertEqual(seed[0]["content"] as? String, "q1\n\nq1b")
        XCTAssertEqual(seed[1]["role"] as? String, "assistant")
    }

    func testWatcherReportsAnExternalWrite() throws {
        let exp = expectation(description: "change seen")
        var seen: [String] = []
        let w = FileWatcher(root: dir) { paths in seen += paths; if seen.contains("watched.md") { exp.fulfill() } }
        XCTAssertNotNil(w)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            try? "x".write(to: self.dir.appendingPathComponent("watched.md"), atomically: true, encoding: .utf8)
            try? FileManager.default.createDirectory(at: self.dir.appendingPathComponent(".studio"), withIntermediateDirectories: true)
            try? "x".write(to: self.dir.appendingPathComponent(".studio/private.txt"), atomically: true, encoding: .utf8)
        }
        wait(for: [exp], timeout: 8)
        XCTAssertFalse(seen.contains { $0.hasPrefix(".studio") }, ".studio changes are not reported")
        w?.stop()
    }
}
