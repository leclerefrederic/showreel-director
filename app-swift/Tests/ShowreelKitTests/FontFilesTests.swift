import XCTest
@testable import ShowreelKit

/// A source that never touches the network: it lists what it is told and counts what is downloaded.
final class FakeFontSource: FontSource, @unchecked Sendable {
    var files: [RepoFile]
    var data: [String: Data]
    var failListing = false, failDownload = false
    private(set) var listed = 0, downloaded: [String] = []
    init(files: [RepoFile], data: [String: Data]) { self.files = files; self.data = data }
    func listing(dir: String) async throws -> [RepoFile] { listed += 1; if failListing { throw URLError(.notConnectedToInternet) }; return files }
    func download(_ file: RepoFile) async throws -> Data { if failDownload { throw URLError(.timedOut) }; downloaded.append(file.name); return data[file.name] ?? Data("x".utf8) }
}

/// Fonts in the film: the state of each Look font, the Add font files card and operation, the embedding in the build and the assembly, what it does to the film's state.
final class FontFilesTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("fonts"); store = ProjectStore(root: dir)
        try? store.create(name: "Fo", conversationLanguage: "en", reelLanguages: ["en"])
        try? store.apply(.decisions([DecisionChange(.titleFont, "Fredoka"), DecisionChange(.textFont, "Nunito")], title: nil))
        for t in ["One", "Two"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "4", text: t, status: "validated"))) }
        store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir) }
    var preview: Data { try! Data(contentsOf: Skill.root()!.appendingPathComponent("engine/fonts-preview/fredoka.woff2")) }
    func repo(_ names: [String]) -> FakeFontSource {
        FakeFontSource(files: names.map { RepoFile(name: $0, size: $0 == "OFL.txt" ? 4400 : 120_000, url: "https://raw.githubusercontent.com/google/fonts/main/ofl/x/\($0)") }, data: Dictionary(uniqueKeysWithValues: names.map { ($0, $0.hasSuffix(".txt") ? Data("OFL text".utf8) : preview) }))
    }
    var statics: [String] { ["Fredoka-Regular.woff2", "Fredoka-Bold.woff2", "Fredoka-Light.woff2", "OFL.txt"] }
    func add(_ family: String, _ src: FakeFontSource) async throws -> FontOffer {
        let o = try await FontFiles.offer(family, store: store, source: src)
        try store.apply(.addFontFiles(try await FontFiles.fetch(o, source: src)))
        return o
    }

    // MARK: reading a font file

    /// A minimal sfnt with a name table, an OS/2 table and, when asked, an fvar table.
    func sfnt(family: String, weight: Int, italic: Bool = false, variable: ClosedRange<Int>? = nil) -> Data {
        func b16(_ v: Int) -> [UInt8] { [UInt8(v >> 8 & 255), UInt8(v & 255)] }
        func b32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)] }
        let fam = Array(family.utf16).flatMap { b16(Int($0)) }
        var name: [UInt8] = b16(0) + b16(2) + b16(6 + 2 * 12)
        name += b16(3) + b16(1) + b16(0x409) + b16(1) + b16(fam.count) + b16(0)
        name += b16(3) + b16(1) + b16(0x409) + b16(2) + b16(14) + b16(fam.count)
        name += fam + Array("Regular".utf16).flatMap { b16(Int($0)) }
        var os2 = [UInt8](repeating: 0, count: 64); os2[4] = UInt8(weight >> 8); os2[5] = UInt8(weight & 255); os2[63] = italic ? 1 : 0
        var tables: [(String, [UInt8])] = [("OS/2", os2), ("name", name)]
        if let r = variable { tables.append(("fvar", b16(1) + b16(0) + b16(16) + b16(0) + b16(1) + b16(20) + b16(0) + b16(0) + Array("wght".utf8) + b32(r.lowerBound << 16) + b32(400 << 16) + b32(r.upperBound << 16) + b16(0) + b16(256))) }
        tables.sort { $0.0 < $1.0 }
        var out: [UInt8] = b32(0x00010000) + b16(tables.count) + b16(0) + b16(0) + b16(0)
        var off = 12 + 16 * tables.count
        for (tag, d) in tables { out += Array(tag.utf8) + b32(0) + b32(off) + b32(d.count); off += d.count }
        for (_, d) in tables { out += d }
        return Data(out)
    }

    func testAFontFileSaysItsFamilyWeightAndAxes() throws {
        let r = try XCTUnwrap(FontInfo.parse(sfnt(family: "Fredoka", weight: 700)))
        XCTAssertEqual([r.family, "\(r.weight)"], ["Fredoka", "700"]); XCTAssertFalse(r.italic); XCTAssertFalse(r.isVariable)
        XCTAssertEqual(FontInfo.parse(sfnt(family: "Nunito", weight: 400, italic: true))?.italic, true)
        let v = try XCTUnwrap(FontInfo.parse(sfnt(family: "Nunito", weight: 400, variable: 200...1000)))
        XCTAssertEqual(v.weightRange, 200...1000); XCTAssertNil(FontInfo.parse(Data("not a font at all".utf8)))
        XCTAssertNil(FontInfo.read(dir.appendingPathComponent("missing.ttf")))
    }

    func testADroppedFontFileIsAFontResourceThatNeedsItsLicenceBeforeApproval() throws {
        let inbox = makeTempDir("fonts-inbox"); defer { try? FileManager.default.removeItem(at: inbox) }
        let f = inbox.appendingPathComponent("Fredoka-Bold.ttf"); try sfnt(family: "Fredoka", weight: 700).write(to: f)
        let row = try XCTUnwrap(try Assets.add([f], to: store).first)
        XCTAssertEqual(row.type, "font"); XCTAssertEqual(FontUse.describe(row, store: store), "Fredoka, 700. Used by Look: Titles")
        XCTAssertEqual(FontUse.state("Fredoka", store: store), .previewOnly, "a file that is not approved is not embedded")
        XCTAssertThrowsError(try store.apply(.asset(id: row.id, status: .approved, note: nil, licence: nil, scenes: nil))) { XCTAssertTrue($0.localizedDescription.contains("needs its licence note")) }
        XCTAssertNoThrow(try store.apply(.asset(id: row.id, status: .approved, note: nil, licence: "OFL 1.1, embedding allowed", scenes: nil)), "the licence given with the approval is enough")
        XCTAssertEqual(Assets.load(store).first?.status, "approved")
        // a titles font at 700 is covered by it; the text font is not
        if case .embedded = FontUse.state("Fredoka", store: store) {} else { XCTFail("Fredoka is embedded once its bold file is approved") }
        XCTAssertEqual(FontUse.state("Nunito", store: store), .needsFiles)
    }

    // MARK: the card

    func testTheCardForAFontOfTheListNamesSourceLicenceFilesSizeAndNetworkAndDownloadsNothing() async throws {
        let src = repo(statics)
        let o = try await FontFiles.offer("fredoka", store: store, source: src)
        XCTAssertEqual(o.card.title, "Add the font files of Fredoka"); XCTAssertEqual(o.dir, "fredoka")
        let by = Dictionary(uniqueKeysWithValues: o.card.changes.map { ($0.label, $0.after) })
        XCTAssertTrue(by["Source"]!.contains("open Google Fonts repository") && by["Source"]!.contains("ofl/fredoka") && by["Source"]!.contains("fixed list"))
        XCTAssertTrue(by["Licence"]!.contains("SIL Open Font License 1.1") && by["Licence"]!.contains("OFL.txt"))
        XCTAssertTrue(by["Files"]!.contains("Fredoka-Bold.woff2") && by["Files"]!.contains("OFL.txt") && !by["Files"]!.contains("Light"), "only the weights the Look uses (titles 700) and the licence")
        XCTAssertTrue(by["Files"]!.contains("assets/fonts/fredoka/")); XCTAssertTrue(by["Network"]!.hasPrefix("needed now"))
        XCTAssertTrue(by["Approval"]!.contains("approves these files") && by["Approval"]!.contains(FontFiles.approvalNote))
        XCTAssertEqual(src.listed, 1); XCTAssertTrue(src.downloaded.isEmpty, "no download before the card is accepted")
        XCTAssertEqual(Assets.load(store).count, 0)
        // the text font uses 400
        let n = try await FontFiles.offer("Nunito", store: store, source: repo(["Nunito-Regular.woff2", "Nunito-Bold.woff2", "OFL.txt"]))
        XCTAssertEqual(n.files.map { $0.name }, ["Nunito-Regular.woff2", "OFL.txt"])
        // a family that is both titles and text takes both weights; a variable file covers all in one
        try store.apply(.decisions([DecisionChange(.textFont, "Fredoka")], title: nil))
        let both = try await FontFiles.offer("Fredoka", store: store, source: repo(statics))
        XCTAssertEqual(both.files.map { $0.name }, ["Fredoka-Regular.woff2", "Fredoka-Bold.woff2", "OFL.txt"])
        let variable = try await FontFiles.offer("Fredoka", store: store, source: repo(["Fredoka[wdth,wght].ttf", "Fredoka-Regular.ttf", "OFL.txt"]))
        XCTAssertEqual(variable.files.map { $0.name }, ["Fredoka[wdth,wght].ttf", "OFL.txt"])
    }

    func testRefusals() async throws {
        do { _ = try await FontFiles.offer("Comic Sans", store: store, source: repo(statics)); XCTFail() }
        catch { XCTAssertTrue(error.localizedDescription.contains("not in the skill's list of free fonts") && error.localizedDescription.contains("Resources tab") && error.localizedDescription.contains("Fredoka"), error.localizedDescription) }
        do { _ = try await FontFiles.offer("Poppins", store: store, source: repo(statics)); XCTFail() } catch { XCTAssertTrue(error.localizedDescription.contains("not chosen in the Look")) }
        do { _ = try await FontFiles.offer("Fredoka", store: store, source: repo(["Fredoka-Regular.woff2", "OFL.txt"])); XCTFail("no bold") } catch { XCTAssertTrue(error.localizedDescription.contains("no file for the weights")) }
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Comic Sans", dir: "comicsans", files: [FontFile(name: "a.ttf", data: Data("x".utf8))]))))
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "../evil.ttf", data: Data("x".utf8))]))))
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "run.sh", data: Data("x".utf8))]))))
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Fredoka", dir: "elsewhere", files: [FontFile(name: "a.ttf", data: Data("x".utf8))]))), "the folder is the list's, never a free one")
    }

    func testTheNetworkFailsReadablyWithTheManualWay() async throws {
        let src = repo(statics); src.failListing = true
        do { _ = try await FontFiles.offer("Fredoka", store: store, source: src); XCTFail() }
        catch { XCTAssertTrue(error.localizedDescription.contains("Could not reach the font repository") && error.localizedDescription.contains("https://fonts.google.com/specimen/Fredoka") && error.localizedDescription.contains("Resources tab"), error.localizedDescription) }
        let ok = repo(statics); let offer = try await FontFiles.offer("Fredoka", store: store, source: ok); ok.failDownload = true
        do { _ = try await FontFiles.fetch(offer, source: ok); XCTFail() } catch { XCTAssertTrue(error.localizedDescription.contains("Nothing was added") && error.localizedDescription.contains("Resources tab")) }
        XCTAssertEqual(Assets.load(store).count, 0); XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/fonts").path), "nothing written")
    }

    // MARK: the operation: files, licence, manifest, journal, undo

    func testAcceptingCreatesTheFilesTheLicenceAndApprovedRowsAndUndoRemovesEverything() async throws {
        let src = repo(statics)
        _ = try await add("Fredoka", src)
        let d = dir.appendingPathComponent("assets/fonts/fredoka")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: d.path).sorted(), ["Fredoka-Bold.woff2", "OFL.txt"], "the weights the Look uses, and the licence text")
        XCTAssertEqual(try String(contentsOf: d.appendingPathComponent("OFL.txt"), encoding: .utf8), "OFL text")
        let rows = Assets.load(store).filter { $0.type == "font" }
        XCTAssertEqual(rows.map { $0.file }, ["fonts/fredoka/Fredoka-Bold.woff2"]); XCTAssertEqual(rows.first?.status, "approved"); XCTAssertEqual(rows.first?.notes, "approved by the owner through the Add font files card")
        XCTAssertTrue(rows.first?.licenceNote.contains("SIL Open Font License 1.1") == true); XCTAssertEqual(rows.first?.origin, "fonts"); XCTAssertEqual(rows.first?.id, "font-01")
        XCTAssertEqual(src.downloaded.sorted(), ["Fredoka-Bold.woff2", "OFL.txt"])
        XCTAssertEqual(store.journal.entries().last?.op, "addFontFiles"); XCTAssertEqual(store.journal.entries().last?.state, "applied")
        guard case .embedded(let n, _, let lic) = FontUse.state("Fredoka", store: store) else { return XCTFail("embedded") }
        XCTAssertEqual(n, 1); XCTAssertTrue(lic.contains("SIL Open Font License"))
        XCTAssertThrowsError(try store.apply(.addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "Fredoka-Bold.woff2", data: preview)]))), "no change when the files are already in")
        // the checks know the folder
        XCTAssertFalse(Checks.run(area: "resources", store: store).contains { $0.level == .fail }, "the new folder is not a stray one and its files are listed")
        // undo: the files, the licence, the folder and the rows go; redo brings them back
        try store.undo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: d.path), "the folder goes with its files"); XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/fonts/fredoka").path))
        XCTAssertTrue(Assets.load(store).filter { $0.type == "font" }.isEmpty); XCTAssertEqual(FontUse.state("Fredoka", store: store), .needsFiles)
        try store.redo()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: d.path).sorted(), ["Fredoka-Bold.woff2", "OFL.txt"]); XCTAssertEqual(Assets.load(store).filter { $0.type == "font" }.count, 1)
    }

    // MARK: Clap

    func testClapProposesTheSameCardAndNeverDownloadsBeforeTheYes() async throws {
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let src = repo(statics); tools.fontSource = src
        ui.accept = false
        let no = await tools.run("add_font_files", ["font": "Fredoka"]).text
        XCTAssertTrue(no.hasPrefix("refused by the user"), no); XCTAssertTrue(src.downloaded.isEmpty); XCTAssertEqual(ui.cards.last?.title, "Add the font files of Fredoka")
        let off = await tools.run("add_font_files", ["font": "Comic Sans"]).text
        XCTAssertTrue(off.hasPrefix("refused:") && off.contains("skill's list"), off); XCTAssertEqual(ui.cards.count, 1, "no card for a font outside the list")
        ui.accept = true
        let yes = await tools.run("add_font_files", ["font": "Fredoka"]).text
        XCTAssertTrue(yes.hasPrefix("accepted and applied"), yes); XCTAssertEqual(src.downloaded.sorted(), ["Fredoka-Bold.woff2", "OFL.txt"]); XCTAssertEqual(store.journal.entries().last?.author, "clap")
        XCTAssertTrue(Tools.definitions.contains { ($0["name"] as? String) == "add_font_files" })
        let again = await tools.run("add_font_files", ["font": "Fredoka"]).text
        XCTAssertTrue(again.contains("already is embedded"), again)
    }

    // MARK: frozen during a build and a generation

    func testFrozenDuringABuildAndAGeneration() async throws {
        let src = repo(statics); let offer = try await FontFiles.offer("Fredoka", store: store, source: src)
        let payload = try await FontFiles.fetch(offer, source: src)
        for phase in [ProjectActivity.Build.Phase.generating, .testing] {
            store.activity.update { $0.build = .init(version: "v1", phase: phase) }
            XCTAssertThrowsError(try store.apply(.addFontFiles(payload))) { XCTAssertEqual($0.localizedDescription, Reasons.building.message) }
            XCTAssertEqual(Availability.addFontFiles("Fredoka", in: store.activity.snapshot, store: store).why, Reasons.building)
            let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ScriptedUI()); tools.fontSource = src
            let t = await tools.run("add_font_files", ["font": "Fredoka"]).text
            XCTAssertTrue(t.hasPrefix("refused:") && t.contains("Building the film"), t)
        }
        XCTAssertEqual(Assets.load(store).count, 0); store.activity.reset()
        XCTAssertNoThrow(try store.apply(.addFontFiles(payload)))
        let a = Availability.addFontFiles("Comic Sans", in: ProjectActivity.Snapshot(), store: store).why
        XCTAssertEqual(a?.reason, "Comic Sans is not in the skill's list of free fonts")
    }

    // MARK: embedding

    func testOnlyTheWeightsTheLookUsesAreEmbeddedAndAMissingFontIsSaid() async throws {
        let p0 = FontEmbedding.plan(store)
        XCTAssertTrue(p0.entries.isEmpty); XCTAssertEqual(p0.missing.map { $0.family }, ["Fredoka", "Nunito"])
        let s0 = try XCTUnwrap(FontEmbedding.step(store, entries: []))
        XCTAssertFalse(s0.ok); XCTAssertTrue(s0.text.contains("Fredoka (titles), Nunito (text) has no approved file") && s0.text.contains("system font") && s0.text.contains("can vary between computers"))
        _ = try await add("Fredoka", repo(statics))
        let p = FontEmbedding.plan(store)
        XCTAssertEqual(p.entries.map { "\($0.family) \($0.weight) \($0.path)" }, ["Fredoka 700 ../assets/fonts/fredoka/Fredoka-Bold.woff2"], "bold only: the light and regular files are not even downloaded")
        XCTAssertEqual(p.missing.map { $0.family }, ["Nunito"])
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v1"), withIntermediateDirectories: true)
        let written = FontEmbedding.write(version: "v1", store: store)
        XCTAssertEqual(written.count, 1)
        let j = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("v1/fonts.json"))) as? [String: Any])
        XCTAssertEqual((j["fonts"] as? [[String: Any]])?.first?["family"] as? String, "Fredoka")
        // a variable font is one entry for the range
        _ = try await add("Nunito", repo(["Nunito[wght].ttf", "OFL.txt"]))
        XCTAssertEqual(FontEmbedding.plan(store).entries.map { "\($0.family) \($0.weight)" }.sorted(), ["Fredoka 700", "Nunito 100 900"])
        XCTAssertTrue(FontEmbedding.step(store, entries: [])!.ok)
        // nothing chosen in the Look: no step at all
        try store.apply(.decisions([DecisionChange(.titleFont, ""), DecisionChange(.textFont, "")], title: nil))
        XCTAssertNil(FontEmbedding.step(store, entries: [])); XCTAssertTrue(FontEmbedding.write(version: "v1", store: store).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("v1/fonts.json").path), "a stale fonts.json is taken away")
    }

    // MARK: the assembled film

    func engineThere() async throws {
        let probe = await Shell.run("command -v python3 && command -v node && node -e \"require('jsdom')\"", in: dir, timeout: 30)
        try XCTSkipUnless(probe?.status == 0, "python3, node and jsdom are needed (run the app's setup check)")
    }
    func sceneVersion() throws {
        let d = dir.appendingPathComponent("v1"); try FileManager.default.createDirectory(at: d.appendingPathComponent("scenes"), withIntermediateDirectories: true)
        try "{\"title\": \"F\", \"main\": \"main.js\", \"duration\": 8, \"fonts\": [], \"tokens\": {}, \"weight_budget_mb\": 5}".write(to: d.appendingPathComponent("project.json"), atomically: true, encoding: .utf8)
        for id in ["S01", "S02"] { try "return function render(g, lt, c) { g.fillStyle = '#223'; g.fillRect(0, 0, c.SW, c.SH); g.font = '700 60px Fredoka'; g.fillStyle = '#fff'; g.fillText('\(id)', 40, 80); };\n".write(to: d.appendingPathComponent("scenes/\(id).js"), atomically: true, encoding: .utf8) }
        try Film.text(store.loadShowreel()!).write(to: d.appendingPathComponent("film.json"), atomically: true, encoding: .utf8)
        try SceneModules.recordGeneration(version: "v1", store: store)
    }

    func testTheAssembledFilmEmbedsTheFontsAndSaysWhenItCannot() async throws {
        try await engineThere()
        let skill = try XCTUnwrap(Skill.root())
        try sceneVersion()
        // without files: assembled, passes the engine's checks, and the orange step says the fallback
        let r = await BuildRunner.run(version: "v1", store: store, skill: skill)
        XCTAssertTrue(r.built && r.harnessClean && r.smokeClean, r.steps.map { "\($0.title): \($0.level) \($0.detail)" }.joined(separator: "\n"))
        let step = try XCTUnwrap(r.steps.first { $0.id == "build.fonts" })
        XCTAssertEqual(step.level, .tight); XCTAssertTrue(step.detail.contains("Fredoka (titles)") && step.detail.contains("system font instead"), step.detail)
        XCTAssertFalse(r.ok, "an orange step keeps the report from being all green")
        XCTAssertFalse(try String(contentsOf: Versions.distURL(store, "v1"), encoding: .utf8).contains("@font-face{font-family:\"Fredoka\""))
        // the film is assembled, recorded, then the files are added
        let a = await FilmAssembly.run(version: "v1", store: store, skill: skill)
        XCTAssertTrue(a.ok, a.message)
        let before = FilmBuild.status(store)
        XCTAssertEqual(before.state, .upToDate); XCTAssertTrue(before.scenes.values.allSatisfy { $0.state == .upToDate })
        _ = try await add("Fredoka", repo(statics))
        let after = FilmBuild.status(store)
        XCTAssertEqual(after.state, .stale); XCTAssertEqual(after.staleReasons, ["the embedded fonts changed"], "the film is stale because of the fonts")
        XCTAssertEqual(after.scenes, before.scenes, "no scene is stale: the code of the modules did not change")
        let b = await FilmAssembly.run(version: "v1", store: store, skill: skill)
        XCTAssertTrue(b.ok, b.message)
        let html = try String(contentsOf: Versions.distURL(store, "v1"), encoding: .utf8)
        XCTAssertTrue(html.contains("@font-face{font-family:\"Fredoka\";font-weight:700;"), "the font is in the film"); XCTAssertFalse(html.contains("font-family:\"Nunito\""), "Nunito has no file: not embedded")
        XCTAssertEqual(FilmBuild.status(store).state, .upToDate)
        // taking the files out makes it stale again
        try store.undo()
        XCTAssertEqual(FilmBuild.status(store).state, .stale)
        // the older format embeds them too: a version with a hand-written main.js
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v2"), withIntermediateDirectories: true)
        try store.redo()
        for n in ["project.json", "film.json"] { try FileManager.default.copyItem(at: dir.appendingPathComponent("v1/\(n)"), to: dir.appendingPathComponent("v2/\(n)")) }
        try "(function () { const film = window.SRF.fromData({ S01: (g, lt, c) => { g.fillStyle = '#334'; g.fillRect(0, 0, c.SW, c.SH); }, S02: (g, lt, c) => { g.fillStyle = '#433'; g.fillRect(0, 0, c.SW, c.SH); } }, { palette: { bg: '#111111', fg: '#ffffff', accent: '#ffffff', accent2: '#888888' } }); window.SHOWREEL = { title: { en: 'Old' }, slug: 'old', footnote: { en: '' }, languages: [{ id: 'en', label: 'EN' }], formats: { d: [1600, 900] }, formatLabels: { d: 'Desktop' }, controls: { pause: true, seek: true, mute: true, volume: true, loop: false, replay: true, lang: true, format: true, notes: false }, ui: { en: { reduced: 'Reduced motion', reducedOn: 'Reduced motion: on', play: 'Play', pause: 'Pause', muted: 'Sound off', sound: 'Sound on', rp: 'Replay', lp: 'Loop', fm: 'Format', lg: 'Language', startSound: 'Start with sound', startSilent: 'Start without sound' } }, pageColor: '#000', setup() {}, render: film.render }; })();".write(to: dir.appendingPathComponent("v2/main.js"), atomically: true, encoding: .utf8)
        let old = await BuildRunner.run(version: "v2", store: store, skill: skill)
        XCTAssertTrue(old.built && old.harnessClean && old.smokeClean, old.steps.map { "\($0.title): \($0.detail)" }.joined(separator: "\n"))
        XCTAssertTrue(try String(contentsOf: Versions.distURL(store, "v2"), encoding: .utf8).contains("@font-face{font-family:\"Fredoka\""), "the older format embeds the fonts too")
    }

    func testTheFontsAreNotInTheSceneModulesNorInTheirFingerprints() async throws {
        try sceneVersion()
        let before = SceneModules.statuses(version: "v1", store: store)
        let hashes = ["S01", "S02"].map { SceneModules.moduleHash(version: "v1", scene: $0, store: store) }
        _ = try await add("Fredoka", repo(statics))
        XCTAssertEqual(SceneModules.statuses(version: "v1", store: store), before)
        XCTAssertEqual(["S01", "S02"].map { SceneModules.moduleHash(version: "v1", scene: $0, store: store) }, hashes, "the scene files are not touched")
    }

    /// Only with SHOWREEL_NETWORK_TESTS=1: the real repository, the real listing and one real download of a small font, read back by `FontInfo`.
    func testTheRealRepositoryWhenAsked() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SHOWREEL_NETWORK_TESTS"] == "1", "set SHOWREEL_NETWORK_TESTS=1 to try the real repository")
        let src = GoogleFontsSource()
        let o = try await FontFiles.offer("Fredoka", store: store, source: src)
        XCTAssertTrue(o.files.contains { $0.name.hasSuffix(".ttf") } && o.files.contains { $0.name == "OFL.txt" }, "\(o.files.map { $0.name })")
        let p = try await FontFiles.fetch(o, source: src)
        try store.apply(.addFontFiles(p))
        let row = try XCTUnwrap(Assets.load(store).first { $0.type == "font" })
        let info = try XCTUnwrap(FontUse.info(row, store))
        XCTAssertEqual(info.family, "Fredoka"); XCTAssertNotNil(info.weightRange, "a variable font")
        guard case .embedded = FontUse.state("Fredoka", store: store) else { return XCTFail("embedded") }
    }
}
