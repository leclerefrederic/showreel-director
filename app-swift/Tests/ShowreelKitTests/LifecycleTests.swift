import XCTest
@testable import ShowreelKit

/// Phases P2 and P3: the base configuration a new project needs, the Checks tab's model, the format revision, "Update project" and "Restore backup", and what
/// the Library window may do (states, locate, remove, move to the Trash). Real temporary folders throughout.
final class LifecycleTests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("p23"); inbox = makeTempDir("p23-inbox"); store = ProjectStore(root: dir) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    var file: ShowreelFile { store.loadShowreel()! }
    func bytes(_ rel: String, in s: ProjectStore? = nil) -> Data? { try? Data(contentsOf: (s ?? store).root.appendingPathComponent(rel)) }
    func writeRaw(_ json: String) throws { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true); try json.write(to: dir.appendingPathComponent("showreel.json"), atomically: true, encoding: .utf8) }
    func newProject() throws { try store.create(name: "N", conversationLanguage: "en", reelLanguages: ["en"]) }
    func asset(_ name: String) throws -> AssetRow { let u = inbox.appendingPathComponent(name); try "x".write(to: u, atomically: true, encoding: .utf8); return try Assets.add([u], to: store)[0] }
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    // MARK: the base configuration

    func testANewProjectNeedsItsBaseConfigurationAndNothingElse() throws {
        try newProject()
        XCTAssertTrue(store.needsSetup, "the app asks a new project for its setup")
        XCTAssertEqual(ProjectSetup.missing(file).map { $0.id }, ["formats", "duration", "palette", "fonts", "background"], "the languages came with the creation sheet")
        XCTAssertThrowsError(try store.finishSetup()) { XCTAssertTrue($0.localizedDescription.contains("formats")) }
        XCTAssertTrue(store.needsSetup, "still closed")
        try store.apply(.parameter(.formats, "16:9")); try store.apply(.parameter(.duration, "45"))
        XCTAssertEqual(ProjectSetup.missing(file).map { $0.id }, ["palette", "fonts", "background"])
        try store.apply(.decisions([DecisionChange(.palette, "#101820")], title: nil))
        XCTAssertEqual(ProjectSetup.missing(file).first?.id, "palette", "a palette needs at least two colours")
        let p = LookPackages.all()[0]
        try store.apply(.decisions(p.decisions, title: "Choose the look: \(p.name)"))
        XCTAssertTrue(ProjectSetup.isComplete(file), "audience, message and tone are optional")
        XCTAssertNil(file.parameters.audience); XCTAssertNil(file.parameters.tone)
        try store.finishSetup()
        XCTAssertFalse(store.needsSetup, "open for good")
        XCTAssertFalse(ProjectStore(root: dir).needsSetup, "kept in .studio/ui.json")
        try store.apply(.decisions([DecisionChange(.background, "")], title: nil))
        XCTAssertFalse(ProjectSetup.isComplete(file)); XCTAssertFalse(store.needsSetup, "later gaps are told by the checks, never a block")
    }

    func testConversationAndReelLanguagesAreRequiredToo() throws {
        try writeRaw(#"{"schema": 1, "name": "X"}"#)
        XCTAssertEqual(ProjectSetup.missing(file).map { $0.id }, ["conversationLanguage", "reelLanguages", "formats", "duration", "palette", "fonts", "background"])
        XCTAssertEqual(ProjectSetup.missing(file).map { $0.section }, ["project", "project", "project", "project", "palette", "fonts", "background"])
    }

    func testAnExistingIncompleteProjectIsNotBlockedButToldInTheChecks() throws {
        try writeRaw(#"{"schema": 1, "name": "Old", "scenes": [{"id": "S01", "duration": 3, "text": "Hi"}]}"#)
        XCTAssertFalse(store.needsSetup, "no flag: never blocked")
        XCTAssertThrowsError(try store.finishSetup(), "and nothing to finish")
        let r = Checks.run(area: "project", store: store).filter { $0.id.hasPrefix("setup.") }
        XCTAssertEqual(r.count, ProjectSetup.missing(file).count); XCTAssertTrue(r.allSatisfy { $0.level == .tight && $0.title.hasPrefix("Missing: ") })
        let s = StudioSettings(); XCTAssertFalse(s.setupRequired)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".studio"), withIntermediateDirectories: true)
        try #"{"mode": "expert"}"#.write(to: dir.appendingPathComponent(".studio/ui.json"), atomically: true, encoding: .utf8)
        XCTAssertFalse(store.settings.setupRequired, "a settings file from before has no such flag")
    }

    // MARK: the Checks tab

    func entry(_ id: String, _ block: String, _ level: CheckLevel = .tight, detail: String = "") -> CheckResult { CheckResult(id: id, block: block, title: id, level: level, detail: detail) }

    func testEveryCheckHasAGroupAndAnElementToOpen() throws {
        try newProject()
        for t in ["One", "Two"] { try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        let held = try asset("client-photo.jpg")
        let f = file, rows = Assets.load(store)
        func target(_ r: CheckResult) -> CheckTarget { CheckPanel.target(of: r, file: f, assets: rows, status: [held.id: .missing]) }
        func group(_ r: CheckResult) -> CheckGroup { CheckPanel.group(of: r) }
        XCTAssertEqual(group(entry("setup.formats", "project")), .project); XCTAssertEqual(target(entry("setup.formats", "project")), .project)
        XCTAssertEqual(target(entry("setup.palette", "project")), .look(.palette)); XCTAssertEqual(target(entry("setup.fonts", "project")), .look(.fonts)); XCTAssertEqual(target(entry("setup.background", "project")), .look(.background))
        XCTAssertEqual(group(entry("font.titles", "look")), .project); XCTAssertEqual(target(entry("font.titles", "look")), .look(.fonts))
        XCTAssertEqual(target(entry("palette.text", "look")), .look(.palette)); XCTAssertEqual(target(entry("look.effects", "look")), .look(.effects))
        XCTAssertEqual(target(entry("feasibility.capacity", "project")), .project)
        XCTAssertEqual(group(entry("assets.hold", "resources")), .resources); XCTAssertEqual(target(entry("assets.hold", "resources")), .resource(held.id), "the held file itself")
        XCTAssertEqual(target(entry("assets.files", "resources")), .resource(held.id), "the first file that is missing")
        XCTAssertEqual(target(entry("assets.names", "resources")), .resources)
        XCTAssertEqual(group(entry("content.S01", "scene")), .scenes); XCTAssertEqual(target(entry("content.S01", "scene")), .scene("S01", tab: "composition"))
        XCTAssertEqual(target(entry("review.S02", "scene")), .scene("S02", tab: "settings")); XCTAssertEqual(target(entry("review.all", "scene")), .scene("S01", tab: "settings"), "the first scene not OK")
        XCTAssertEqual(group(entry("reading.S01", "storyboard")), .storyboard); XCTAssertEqual(target(entry("reading.S01", "storyboard")), .scene("S01", tab: "composition"))
        XCTAssertEqual(target(entry("storyboard.times", "storyboard")), .storyboard, "every scene has a duration here: it falls back to the storyboard")
        XCTAssertEqual(group(entry("reel.transition-length", "storyboard")), .storyboard)
        XCTAssertEqual(target(entry("reel.transition-length", "storyboard", detail: "S02 \u{2192} S03: Morph is a preview only")), .transition(from: "S02"))
        XCTAssertEqual(target(entry("reel.transition-text", "storyboard", detail: "S01 \u{2192} S02: words are on screen")), .transition(from: "S01"))
        for m in ["reel.music", "reel.starts", "reel.drop", "reel.calm", "reel.length"] { XCTAssertEqual(group(entry(m, "storyboard")), .music, m) }
        XCTAssertEqual(target(entry("reel.starts", "storyboard", detail: "S02 starts at 3 s, off the beat")), .scene("S02", tab: "settings")); XCTAssertEqual(target(entry("reel.music", "storyboard")), .music)
        XCTAssertEqual(group(entry("build.go", "build")), .build); XCTAssertEqual(target(entry("build.go", "build")), .build)
        XCTAssertEqual(target(entry("gate.assets", "resources")), .resources); XCTAssertEqual(target(entry("gate.interview", "project")), .project); XCTAssertEqual(target(entry("gate.style", "look")), .look(.looks))
        XCTAssertEqual(target(entry("reel.flashes", "storyboard#2")), .storyboard, "a repeated id keeps its target")
        XCTAssertEqual(target(entry("something.new", "scene")), .storyboard, "an unknown check falls back to its group's place")
    }

    func testTheBadgeCountsRedAndOrangeAndTheGroupsAreInTheTabsOrder() throws {
        let byArea: [String: [CheckResult]] = [
            "project": [entry("setup.formats", "project", .tight), entry("feasibility", "project", .pending)],
            "look": [entry("font.titles", "look", .fail), entry("look.background", "look", .ok)],
            "resources": [entry("assets.hold", "resources", .fail)],
            "scene": [entry("review.S01", "scene", .ok)],
            "storyboard": [entry("reel.music", "storyboard", .pending), entry("reel.starts", "storyboard", .tight), entry("storyboard.ids", "storyboard", .ok)],
            "build": [entry("build.go", "build", .pending)]]
        let e = CheckPanel.entries(byArea, file: nil, assets: [], status: [:])
        XCTAssertEqual(CheckPanel.attention(e), 4, "two orange and two red; grey and green do not count")
        let g = CheckPanel.grouped(e)
        XCTAssertEqual(g.map { $0.group }, [.project, .resources, .scenes, .storyboard, .music, .build])
        XCTAssertEqual(g[0].entries.map { $0.result.id }, ["font.titles", "setup.formats", "look.background", "feasibility"], "red, then orange, then fine, then waiting")
        XCTAssertEqual(g[4].entries.map { $0.result.id }, ["reel.starts", "reel.music"])
        XCTAssertEqual(CheckPanel.grouped(CheckPanel.entries([:], file: nil, assets: [], status: [:])).count, 0)
    }

    func testAnEntryIsListedOnceEvenWhenTwoAreasReturnIt() {
        let d = entry("gate.x", "project")
        XCTAssertEqual(CheckPanel.entries(["project": [d], "look": [d]], file: nil, assets: [], status: [:]).count, 1)
    }

    func testTheLookListSummarisesEachEditorsCurrentChoice() throws {
        try newProject()
        for s in LookSection.allCases { XCTAssertFalse(s.summary(file).isSet, s.rawValue); XCTAssertEqual(s.summary(file).text, "not chosen yet") }
        XCTAssertEqual(LookSection.allCases.map { $0.title }, ["Looks", "Palette", "Fonts", "Background", "Moods", "Effects pack"])
        XCTAssertEqual(Set(LookSection.allCases.map { $0.symbol }).count, 6, "an icon each")
        let p = LookPackages.all()[0]
        try store.apply(.decisions(p.decisions, title: nil))
        XCTAssertEqual(LookSection.looks.summary(file).text, p.name)
        XCTAssertEqual(LookSection.palette.summary(file).swatches, p.palette.map { $0.uppercased() })
        XCTAssertEqual(LookSection.fonts.summary(file).text, "\(p.fonts.titles ?? "") + \(p.fonts.text ?? "")")
        XCTAssertTrue(LookSection.background.summary(file).text.hasPrefix(p.background)); XCTAssertEqual(LookSection.effects.summary(file).text, p.pack)
        try store.apply(.decisions([DecisionChange(.palette, "#000000, #FFFFFF")], title: nil))
        XCTAssertEqual(LookSection.looks.summary(file).text, "your own mix")
    }

    // MARK: the format revision

    func testANewFileCarriesTheCurrentRevisionAndAnOldOneIsRevisionZero() throws {
        try newProject()
        XCTAssertEqual(file.revision, ShowreelFile.currentRevision); XCTAssertFalse(file.isOutdated)
        XCTAssertTrue(store.read("showreel.json")!.contains("\"formatRevision\" : \(ShowreelFile.currentRevision)"))
        let old = try ShowreelFile.decode(#"{"schema": 1, "name": "O", "futureKey": {"a": 1}}"#)
        XCTAssertNil(old.formatRevision); XCTAssertEqual(old.revision, 0); XCTAssertTrue(old.isOutdated)
        XCTAssertFalse(try old.encoded().contains("formatRevision"), "absent stays absent: nothing is invented")
        XCTAssertEqual(try ShowreelFile.decode(try old.encoded()).unknown["futureKey"], .object(["a": .number(1)]))
    }

    func testOpeningAnOldProjectWritesNothing() throws {
        try writeRaw(#"{"schema": 1, "name": "Old", "scenes": [{"id": "S01", "start": 0, "end": 4, "text": "Hi"}], "origin": {"tool": "skill"}}"#)
        let before = bytes("showreel.json")
        _ = store.loadShowreel(); _ = ProjectFormat.plan(store); _ = ProjectFormat.isOutdated(store); _ = LibraryRules.state(path: dir.path)
        _ = Checks.run(area: "project", store: store); _ = Checks.run(area: "scene", store: store); _ = Assets.load(store); _ = DocSync.pending(store)
        XCTAssertEqual(bytes("showreel.json"), before, "readable as it is, and not modified")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(".studio/backups").path)); XCTAssertNil(bytes("brief.md"))
        XCTAssertEqual(file.scenes[0].duration, 4, "it reads in the current shape without being rewritten")
        XCTAssertEqual(file.revision, 0)
    }

    func testASaveByTheUserDoesNotPassForAnUpdate() throws {
        try writeRaw(#"{"schema": 1, "name": "Old", "scenes": [{"id": "S01", "duration": 3, "text": "Hi"}]}"#)
        try store.apply(.parameter(.audience, "Developers"))
        XCTAssertNil(file.formatRevision, "only Update project raises the revision")
        XCTAssertTrue(ProjectFormat.isOutdated(store))
    }

    // MARK: update, backup, restore: a file of each old form

    func shapes() -> [(String, String, [String])] {
        [("phase A (review states by ID)", #"{"schema": 1, "name": "A", "scenes": {"S01": {"status": "ok", "note": "fine"}}, "x": 1}"#, ["review states of phase A"]),
         ("phase T (starts and ends, a ditched scene)", #"{"schema": 1, "name": "T", "scenes": [{"id": "S01", "start": 0, "end": 4, "text": "A"}, {"id": "S02", "start": 4, "end": 6, "status": "ditched"}], "x": 1}"#, ["move into a scene library", "taken from the old start and end"]),
         ("before the content list", #"{"schema": 1, "name": "C", "scenes": [{"id": "S01", "duration": 3, "text": "Hello", "visual": "Logo rises"}], "storyboards": [{"id": "main", "name": "Master", "items": [{"scene": "S01"}]}], "x": 1}"#, ["become the first element"]),
         ("a studio file of before the revisions", #"{"schema": 1, "name": "S", "origin": {"tool": "studio"}, "scenes": [{"id": "S01", "duration": 3, "content": []}], "storyboards": [{"id": "main", "name": "Master", "items": [{"scene": "S01"}]}], "x": 1}"#, ["Format revision 0"]),
         ("the skill's export", #"{"schema": 1, "name": "E", "origin": {"tool": "skill"}, "scenes": [{"id": "S01", "duration": 3, "text": "Hi"}], "x": 1}"#, ["owner of showreel.json"])]
    }

    func testEachOldFormIsListedBackedUpMigratedAndLosesNothing() throws {
        for (name, json, expected) in shapes() {
            let d = makeTempDir("p3-shape"); defer { try? FileManager.default.removeItem(at: d) }
            let s = ProjectStore(root: d)
            try json.write(to: d.appendingPathComponent("showreel.json"), atomically: true, encoding: .utf8)
            let original = try Data(contentsOf: d.appendingPathComponent("showreel.json"))
            let plan = try XCTUnwrap(ProjectFormat.plan(s), name)
            XCTAssertEqual(plan.from, 0, name); XCTAssertEqual(plan.to, ShowreelFile.currentRevision)
            for e in expected { XCTAssertTrue(plan.changes.contains { $0.contains(e) }, "\(name): lists \"\(e)\" in \(plan.changes)") }
            XCTAssertTrue(plan.changes.last!.hasPrefix("Format revision 0"), name)
            XCTAssertEqual(plan.backupFiles, ["showreel.json"])
            let before = try ShowreelFile.decode(json)
            let (b, _) = try ProjectFormat.update(s)
            XCTAssertEqual(try Data(contentsOf: b.url.appendingPathComponent("showreel.json")), original, "\(name): the backup is the file as it was, byte for byte")
            let after = try XCTUnwrap(s.loadShowreel(), name)
            XCTAssertEqual(after.revision, ShowreelFile.currentRevision, name); XCTAssertFalse(after.isOutdated)
            XCTAssertEqual(after.unknown["x"], .number(1), "\(name): keys the app does not know are kept")
            XCTAssertEqual(after.scenes.map { $0.id }, before.scenes.map { $0.id }, "\(name): every scene still there, with its ID")
            XCTAssertEqual(after.scenes.map { $0.text }, before.scenes.map { $0.text }, name)
            XCTAssertEqual(after.scenes.map { $0.visual }, before.scenes.map { $0.visual }, name)
            XCTAssertEqual(after.scenes.map { $0.status }, before.scenes.map { $0.status }, name)
            XCTAssertEqual(after.scenes.map { $0.duration }, before.scenes.map { $0.duration }, name)
            XCTAssertEqual(after.origin?.tool, "studio", name)
            if before.scenes.contains(where: { !$0.text.isEmpty }) { XCTAssertTrue(after.scenes.contains { $0.content.contains { $0.type == "text" } }, "\(name): the words are an element") }
            XCTAssertNil(ProjectFormat.plan(s), "\(name): nothing left to update")
            XCTAssertThrowsError(try ProjectFormat.update(s)) { XCTAssertTrue($0.localizedDescription.contains("already")) }
            XCTAssertEqual(ProjectFormat.backups(s).map { $0.id }, [b.id])
            XCTAssertEqual(ProjectFormat.backups(s)[0].revision, 0)
        }
    }

    func testUpdateLinksEveryLinkedResourceToAnElement() throws {
        try newProject()
        try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Hi")))
        let a = try asset("Acme Logo.svg")
        var rows = Assets.load(store); rows[0].scene = "S01"; try Assets.save(rows, store)         // linked without an element, as an older version left it
        var f = file; f.formatRevision = nil; f.gates["review"] = "passed"; try store.write("showreel.json", try f.encoded())
        let plan = try XCTUnwrap(ProjectFormat.plan(store))
        XCTAssertTrue(plan.changes.contains("\(a.name) becomes an element of S01"), "\(plan.changes)")
        XCTAssertTrue(plan.backupFiles.contains("showreel.json") && plan.backupFiles.contains("assets/MANIFEST.csv"), "the data and the manifest are backed up")
        try ProjectFormat.update(store)
        XCTAssertEqual(file.scenes[0].content.compactMap { $0.resource }, [a.id]); XCTAssertEqual(file.gates["review"], "passed", "an update does not take the Go back")
        XCTAssertEqual(Assets.load(store)[0].scene, "S01", "the link is untouched")
    }

    func testRestoreBringsBackEveryTrackedFileByteForByteAndRemovesWhatDidNotExist() throws {
        try newProject()
        try store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "Hi")))
        var f = file; f.formatRevision = nil; try store.write("showreel.json", try f.encoded())
        XCTAssertNil(bytes("assets/MANIFEST.csv"), "no manifest yet")
        let tracked = ProjectFormat.tracked
        let before = Dictionary(uniqueKeysWithValues: tracked.map { ($0, bytes($0)) })
        let (b, _) = try ProjectFormat.update(store)
        XCTAssertNotEqual(bytes("showreel.json"), before["showreel.json"]!)
        _ = try asset("Acme Logo.svg")                                                                 // the manifest now exists
        try store.apply(.scene(id: "S01", SceneEdit(note: "later")))
        XCTAssertNotNil(bytes("assets/MANIFEST.csv"))
        try ProjectFormat.restore(store, b, now: Date().addingTimeInterval(5))
        for rel in tracked where rel != Journal.path { XCTAssertEqual(bytes(rel), before[rel] ?? nil, "restored byte for byte: \(rel)") }
        XCTAssertTrue(bytes(Journal.path)!.starts(with: (before[Journal.path] ?? nil) ?? Data()), "the journal came back as it was, and the restore is its last line (the journal only grows)")
        XCTAssertNil(bytes("assets/MANIFEST.csv"), "a file that did not exist then does not exist now")
        XCTAssertEqual(file.revision, 0)
        let ids = ProjectFormat.backups(store)
        XCTAssertEqual(ids.count, 2, "the state the restore replaced was backed up first, so the restore can be undone")
        try ProjectFormat.restore(store, ids[0], now: Date().addingTimeInterval(10))                    // back to the updated one
        XCTAssertEqual(file.revision, ShowreelFile.currentRevision)
        XCTAssertNotNil(bytes("assets/MANIFEST.csv"))
    }

    func testAFailedBackupChangesNothingAndAnUnreadableFileIsNeverReplaced() throws {
        try writeRaw(#"{"schema": 1, "name": "Old", "scenes": [{"id": "S01", "duration": 3, "text": "Hi"}]}"#)
        let before = bytes("showreel.json")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".studio"), withIntermediateDirectories: true)
        try "in the way".write(to: dir.appendingPathComponent(".studio/backups"), atomically: true, encoding: .utf8)     // a file where the folder must go
        XCTAssertThrowsError(try ProjectFormat.update(store))
        XCTAssertEqual(bytes("showreel.json"), before, "no backup, so no migration")
        try FileManager.default.removeItem(at: dir.appendingPathComponent(".studio/backups"))
        try "{ not json".write(to: dir.appendingPathComponent("showreel.json"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ProjectFormat.update(store)) { XCTAssertTrue($0.localizedDescription.contains("cannot be read")) }
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("showreel.json")), "{ not json")
        XCTAssertNil(ProjectFormat.plan(store)); XCTAssertFalse(ProjectFormat.isOutdated(store), "an unreadable file is not outdated, it is broken")
    }

    func testARestoreWithAnIncompleteBackupChangesNothing() throws {
        try writeRaw(#"{"schema": 1, "name": "Old", "scenes": []}"#)
        let (b, _) = try ProjectFormat.update(store)
        let after = bytes("showreel.json")
        try FileManager.default.removeItem(at: b.url.appendingPathComponent("showreel.json"))
        XCTAssertThrowsError(try ProjectFormat.restore(store, b)) { XCTAssertTrue($0.localizedDescription.contains("incomplete")) }
        XCTAssertEqual(bytes("showreel.json"), after)
    }

    // MARK: the Library window

    func testTheLibraryStatesAreOneWordEach() throws {
        let missing = dir.appendingPathComponent("gone").path
        XCTAssertEqual(LibraryRules.state(path: missing), .missing)
        XCTAssertEqual(LibraryRules.state(path: dir.path), .setup, "a folder with no showreel.json yet")
        try writeRaw(#"{"schema": 1, "name": "Old"}"#)
        XCTAssertEqual(LibraryRules.state(path: dir.path), .outdated)
        try FileManager.default.removeItem(at: dir.appendingPathComponent("showreel.json"))
        try newProject()
        XCTAssertEqual(LibraryRules.state(path: dir.path), .setup, "the base configuration is not done")
        try store.apply(.parameter(.formats, "16:9")); try store.apply(.parameter(.duration, "30")); try store.apply(.decisions(LookPackages.all()[0].decisions, title: nil))
        XCTAssertEqual(LibraryRules.state(path: dir.path), .storyboard)
        let v = dir.appendingPathComponent("v1/dist"); try FileManager.default.createDirectory(at: v, withIntermediateDirectories: true)
        try "<html></html>".write(to: v.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        for f in ["project.json", "main.js"] { try "{}".write(to: dir.appendingPathComponent("v1/" + f), atomically: true, encoding: .utf8) }
        XCTAssertEqual(LibraryRules.state(path: dir.path), .built)
        XCTAssertEqual(Set([LibraryState.setup, .storyboard, .built, .outdated, .missing].map { $0.rawValue }), ["Setup", "Storyboard", "Built", "Outdated", "Missing"])
    }

    func testAMissingProjectCanBeLocatedOrRemovedAndRemovingKeepsTheFiles() throws {
        let lib = ProjectLibrary(url: dir.appendingPathComponent("projects.json"))
        let home = makeTempDir("p3-home"); defer { try? FileManager.default.removeItem(at: home) }
        let a = home.appendingPathComponent("Alpha"), b = home.appendingPathComponent("Beta")
        for u in [a, b] { try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); try "keep".write(to: u.appendingPathComponent("showreel.json"), atomically: true, encoding: .utf8) }
        let e = lib.add(path: a.path, name: "Alpha"), other = lib.add(path: b.path, name: "Beta")
        try FileManager.default.moveItem(at: a, to: home.appendingPathComponent("Moved"))
        XCTAssertEqual(LibraryRules.state(path: e.path), .missing)
        XCTAssertThrowsError(try lib.locate(e.id, to: b.path)) { XCTAssertTrue($0.localizedDescription.contains("already in the Library")) }
        XCTAssertThrowsError(try lib.locate(e.id, to: home.appendingPathComponent("nowhere").path))
        try lib.locate(e.id, to: home.appendingPathComponent("Moved").path)
        XCTAssertEqual(LibraryRules.state(path: lib.entry(forPath: home.appendingPathComponent("Moved").path)!.path), .setup)
        XCTAssertEqual(ProjectLibrary(url: lib.url).entries.first { $0.id == e.id }?.path, URL(fileURLWithPath: home.appendingPathComponent("Moved").path).standardizedFileURL.path, "kept")
        lib.remove(other.id)
        XCTAssertNil(lib.entries.first { $0.id == other.id }); XCTAssertTrue(FileManager.default.fileExists(atPath: b.appendingPathComponent("showreel.json").path), "Remove keeps the files")
    }

    func testMovingToTheTrashNamesTheFolderAndItsSizeAndNeverDeletesForGood() throws {
        let lib = ProjectLibrary(url: dir.appendingPathComponent("projects.json"))
        let home = makeTempDir("p3-trash"); defer { try? FileManager.default.removeItem(at: home) }
        let p = home.appendingPathComponent("Reels/My Film")
        try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        try Data(count: 120_000).write(to: p.appendingPathComponent("big.bin")); try "{}".write(to: p.appendingPathComponent("showreel.json"), atomically: true, encoding: .utf8)
        let e = lib.add(path: p.path, name: "My Film")
        let prompt = LibraryRules.trashPrompt(name: "My Film", path: p.path)
        XCTAssertGreaterThanOrEqual(prompt.bytes, 120_000)
        for needle in ["My Film", ByteCountFormatter.string(fromByteCount: prompt.bytes, countStyle: .file), "Trash", "until you empty it"] { XCTAssertTrue(prompt.message.contains(needle), "\(needle) in: \(prompt.message)") }
        let trash = home.appendingPathComponent("FakeTrash"); try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let open: Set<String> = [p.path]
        XCTAssertThrowsError(try LibraryRules.moveToTrash(e, in: lib, openPaths: open, using: { _ in XCTFail("must not be called") })) { XCTAssertTrue($0.localizedDescription.contains("open in a window")) }
        XCTAssertNotNil(lib.entries.first { $0.id == e.id }); XCTAssertTrue(FileManager.default.fileExists(atPath: p.path))
        XCTAssertNotNil(LibraryRules.trashRefusal(path: p.path, openPaths: [p.path + "/"]), "the same folder spelt another way is still open")
        // the Trash fails: nothing is lost
        struct Boom: Error {}
        XCTAssertThrowsError(try LibraryRules.moveToTrash(e, in: lib, openPaths: [], using: { _ in throw Boom() }))
        XCTAssertNotNil(lib.entries.first { $0.id == e.id }, "the entry stays when the Trash refused"); XCTAssertTrue(FileManager.default.fileExists(atPath: p.path))
        var moved: URL?
        try LibraryRules.moveToTrash(e, in: lib, openPaths: [], using: { u in moved = u; try FileManager.default.moveItem(at: u, to: trash.appendingPathComponent(u.lastPathComponent)) })
        XCTAssertEqual(moved?.path, URL(fileURLWithPath: p.path).path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: p.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("My Film/big.bin").path), "in the Trash, not deleted")
        XCTAssertNil(lib.entries.first { $0.id == e.id })
        XCTAssertNotNil(LibraryRules.trashRefusal(path: p.path, openPaths: []), "a folder that is gone cannot be moved")
        XCTAssertNotNil(LibraryRules.trashRefusal(path: NSHomeDirectory(), openPaths: [])); XCTAssertNotNil(LibraryRules.trashRefusal(path: "/", openPaths: []))
    }

    func testAnOpenProjectCannotBeUpdatedOrRestoredFromTheLibrary() {
        XCTAssertNotNil(LibraryRules.refusal(forChangingDataOf: dir.path, openPaths: [dir.path]))
        XCTAssertNotNil(LibraryRules.refusal(forChangingDataOf: dir.path + "/", openPaths: [dir.path]))
        XCTAssertNil(LibraryRules.refusal(forChangingDataOf: dir.path, openPaths: ["/somewhere/else"]))
    }

    // MARK: the views

    func testThereIsOnePathToTheApplicationsSettings() throws {
        var constructed: [String] = []
        for f in try FileManager.default.contentsOfDirectory(atPath: views.path).filter({ $0.hasSuffix(".swift") }) where f != "SettingsView.swift" {
            let t = try source(f)
            if t.contains("SettingsView(") { constructed.append(f) }
            XCTAssertNil(t.range(of: #"\bshowSettings\b"#, options: .regularExpression), "\(f): no sheet flag for the settings")
            XCTAssertFalse(t.contains("\"gearshape\""), "\(f): no settings button")
        }
        XCTAssertEqual(constructed, ["App.swift"], "the Settings window of the app menu is the only place the settings view exists")
        XCTAssertTrue(try source("App.swift").contains("Settings { SettingsView()"))
        for f in ["BuildViews.swift", "ChatView.swift"] { XCTAssertTrue(try source(f).contains("AppSettingsWindow.open()"), "\(f): Connect AI opens that same window") }
        XCTAssertFalse(try source("LibraryView.swift").contains("Settings"), "no Settings button in the Library window")
    }

    func testTheLibraryWindowShowsStatusAsTextAndTheChecksLiveInTheLeftPanel() throws {
        let lib = try source("LibraryView.swift")
        let row = String(lib[lib.range(of: "struct ProjectRow")!.lowerBound...])
        XCTAssertFalse(row.contains("Capsule"), "the state is plain text, not a pill"); XCTAssertTrue(row.contains(".onHover")); XCTAssertTrue(row.contains(".onTapGesture { if state != .missing { actions.open(entry) } }"), "one click opens")
        XCTAssertFalse(row.contains("count: 2"), "no double click"); XCTAssertTrue(row.contains("Locate...")); XCTAssertTrue(row.contains("Move to Trash..."))
        let m = try source("ProjectModel.swift")
        XCTAssertTrue(m.contains("case resources, scenes, checks"))
        XCTAssertFalse(try source("ProjectView.swift").contains("ChecksPopover"), "no second place for the checks")
        XCTAssertFalse(try source("InspectorViews.swift").contains("ChecksList") || (try source("ProjectSettingsPanel.swift")).contains("ChecksList"))
        XCTAssertTrue(try source("ProjectSettingsPanel.swift").contains("LookRow(section: s)")); XCTAssertFalse(try source("ProjectSettingsPanel.swift").contains("Picker(\"\", selection: $project.lookSection)"), "the dropdown is gone")
        XCTAssertTrue(try source("ProjectView.swift").contains("SetupFormView()"))
    }
}
