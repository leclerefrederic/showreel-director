import XCTest
@testable import ShowreelKit

/// A minimal sfnt with a name table, an OS/2 table and, when asked, an fvar table.
func fakeSfnt(family: String, weight: Int, italic: Bool = false, variable: ClosedRange<Int>? = nil) -> Data {
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

/// A source that never touches the network: it serves a font file that reads as the right family, counts what is downloaded, and fails when told to.
final class FakeFontSource: FontSource, @unchecked Sendable {
    var error: Error?
    /// Fail on the nth download (1 is the first), after the earlier ones succeeded.
    var failOn: Int?
    var empty = false
    private(set) var downloaded: [String] = []
    private var count = 0
    func download(_ file: RepoFile) async throws -> Data {
        count += 1
        if let e = error { throw e }
        if let n = failOn, count == n { throw FontRepositoryError(status: 500, url: file.url, detail: "the service answered with an error") }
        if empty { return Data() }
        downloaded.append(file.name)
        if !FontPayload.isFont(file.name) { return Data("licence text".utf8) }
        return file.name.contains("[") ? fakeSfnt(family: file.family, weight: 400, variable: 300...700) : fakeSfnt(family: file.family, weight: file.name.contains("Bold") ? 700 : 400)
    }
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
    func add(_ family: String, _ src: FakeFontSource = FakeFontSource()) async throws -> FontOffer {
        let o = try FontFiles.offer(family, store: store)
        try store.apply(.addFontFiles(try await FontFiles.fetch(o, source: src)))
        return o
    }
    /// Poppins is a static family (400 and 700), Anton has a single weight, Fredoka and Nunito are variable: the skill's manifest says so.
    func look(titles: String, text: String) throws { try store.apply(.decisions([DecisionChange(.titleFont, titles), DecisionChange(.textFont, text)], title: nil)); store.activity.reset() }

    // MARK: reading a font file

    func sfnt(family: String, weight: Int, italic: Bool = false, variable: ClosedRange<Int>? = nil) -> Data { fakeSfnt(family: family, weight: weight, italic: italic, variable: variable) }

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
        XCTAssertThrowsError(try store.apply(.asset(id: row.id, status: .approved, note: nil, licence: nil, scenes: nil))) { XCTAssertTrue($0.localizedDescription.contains("licence note"), $0.localizedDescription) }
        XCTAssertNoThrow(try store.apply(.asset(id: row.id, status: .approved, note: nil, licence: "OFL 1.1, embedding allowed", scenes: nil)), "the licence given with the approval is enough")
        XCTAssertEqual(Assets.load(store).first?.status, "approved")
        // a titles font at 700 is covered by it; the text font is not
        if case .embedded = FontUse.state("Fredoka", store: store) {} else { XCTFail("Fredoka is embedded once its bold file is approved") }
        XCTAssertEqual(FontUse.state("Nunito", store: store), .needsFiles)
    }

    // MARK: the card: built from the manifest, no network

    func testTheCardNamesSourceLicenceFilesSizeAndNetworkAndUsesNoNetworkToBeBuilt() throws {
        let o = try FontFiles.offer("fredoka", store: store)             // no source at all: nothing to call
        XCTAssertEqual(o.card.title, "Add the font files of Fredoka"); XCTAssertEqual(o.dir, "fredoka")
        let by = Dictionary(uniqueKeysWithValues: o.card.changes.map { ($0.label, $0.after) })
        XCTAssertTrue(by["Source"]!.contains("Google Fonts") && by["Source"]!.contains("fixed list"), by["Source"]!)
        XCTAssertTrue(by["Licence"]!.contains("SIL Open Font License 1.1") && by["Licence"]!.contains("OFL.txt"))
        XCTAssertTrue(by["Files"]!.contains("Fredoka[wdth,wght].ttf") && by["Files"]!.contains("licence text"), "a variable file covers both weights: one font file and the licence")
        XCTAssertTrue(by["Files"]!.contains("assets/fonts/fredoka/") && by["Files"]!.contains("KB"))
        XCTAssertTrue(by["Network"]!.contains("needed once you accept"))
        XCTAssertTrue(by["Approval"]!.contains("approves these files") && by["Approval"]!.contains(FontFiles.approvalNote))
        XCTAssertEqual(Assets.load(store).count, 0)
        // the sizes come from the manifest
        let spec = try XCTUnwrap(Look.freeFonts().first { $0.name == "Fredoka" }?.files.first)
        XCTAssertEqual(o.files.first?.size, spec.size); XCTAssertGreaterThan(spec.size ?? 0, 1000)
    }

    func testThePlanForAFamilyWithOneWeightSeveralWeightsAndAVariableFile() throws {
        // Anton has a single weight: titles at 700 are served by its 400 file, and so is the text
        try look(titles: "Anton", text: "Anton")
        let anton = try FontFiles.offer("Anton", store: store)
        XCTAssertEqual(anton.files.map { $0.name }, ["Anton-Regular.ttf", "OFL.txt"])
        XCTAssertEqual(FontFiles.effectiveWeight(700, family: "Anton"), 400)
        // Poppins is static: the Look's titles (700) and text (400) take two files
        try look(titles: "Poppins", text: "Poppins")
        let poppins = try FontFiles.offer("Poppins", store: store)
        XCTAssertEqual(poppins.files.map { $0.name }, ["Poppins-Regular.ttf", "Poppins-Bold.ttf", "OFL.txt"])
        XCTAssertTrue(poppins.files[0].url.hasPrefix("https://raw.githubusercontent.com/google/fonts/main/ofl/poppins/"), "the path is the repository's, with no API")
        XCTAssertEqual(FontFiles.effectiveWeight(700, family: "Poppins"), 700)
        // only titles: only the bold file
        try look(titles: "Poppins", text: "Nunito")
        XCTAssertEqual(try FontFiles.offer("Poppins", store: store).files.map { $0.name }, ["Poppins-Bold.ttf", "OFL.txt"])
        // a variable family: one file
        XCTAssertEqual(try FontFiles.offer("Nunito", store: store).files.map { $0.name }, ["Nunito[wght].ttf", "OFL.txt"])
        // a family under apache/ keeps its own licence
        try look(titles: "Satisfy", text: "Satisfy")
        let satisfy = try FontFiles.offer("Satisfy", store: store)
        XCTAssertEqual(satisfy.license, "Apache License 2.0"); XCTAssertTrue(satisfy.files.last?.url.contains("/apache/satisfy/LICENSE.txt") == true, satisfy.files.last?.url ?? "")
    }

    func testEveryFontOfTheListHasWhatItNeedsToBeOffered() throws {
        let list = Look.freeFonts()
        XCTAssertEqual(list.count, 70)
        for f in list {
            XCTAssertFalse(f.files.isEmpty, "\(f.name) has no file in the manifest")
            for x in f.files { XCTAssertTrue(x.name.hasSuffix(".ttf") && (x.size ?? 0) > 1000, "\(f.name) \(x.name)") }
            XCTAssertTrue(f.files.contains { $0.variable || $0.weight == 400 || $0.weight == 700 }, f.name)
            XCTAssertTrue(["OFL.txt", "LICENSE.txt"].contains(f.licenseFile) && ["ofl", "apache", "ufl"].contains(f.tree), f.name)
        }
    }

    func testRefusals() async throws {
        do { _ = try FontFiles.offer("Comic Sans", store: store); XCTFail() }
        catch { XCTAssertTrue(error.localizedDescription.contains("not in the skill's list of free fonts") && error.localizedDescription.contains("Resources tab") && error.localizedDescription.contains("Fredoka"), error.localizedDescription) }
        do { _ = try FontFiles.offer("Poppins", store: store); XCTFail() } catch { XCTAssertTrue(error.localizedDescription.contains("not chosen in the Look")) }
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Comic Sans", dir: "comicsans", files: [FontFile(name: "a.ttf", data: Data("x".utf8))]))))
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "../evil.ttf", data: Data("x".utf8))]))))
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "run.sh", data: Data("x".utf8))]))))
        XCTAssertThrowsError(try store.plan(.addFontFiles(FontPayload(family: "Fredoka", dir: "elsewhere", files: [FontFile(name: "a.ttf", data: Data("x".utf8))]))), "the folder is the list's, never a free one")
    }

    // MARK: failures: nothing is added halfway

    func testAFailureOnTheWayLeavesNothing() async throws {
        try look(titles: "Poppins", text: "Poppins")
        let offer = try FontFiles.offer("Poppins", store: store)
        for n in 1...3 {
            let src = FakeFontSource(); src.failOn = n
            do { _ = try await FontFiles.fetch(offer, source: src); XCTFail("must fail on download \(n)") }
            catch let e as FontLookupError { XCTAssertTrue(e.retryable && e.text.contains("Nothing was added") && e.text.contains("https://fonts.google.com/specimen/Poppins") && e.text.contains("Resources tab"), e.text) }
        }
        XCTAssertEqual(Assets.load(store).count, 0); XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/fonts").path), "nothing written")
        let empty = FakeFontSource(); empty.empty = true
        do { _ = try await FontFiles.fetch(offer, source: empty); XCTFail("an empty file is refused") } catch { XCTAssertTrue(error.localizedDescription.contains("is empty"), error.localizedDescription) }
        // then it works with the same card
        let ok = FakeFontSource()
        try store.apply(.addFontFiles(try await FontFiles.fetch(offer, source: ok)))
        XCTAssertEqual(Assets.load(store).filter { $0.type == "font" }.count, 2)
    }

    func testAWriteThatFailsInTheOperationRemovesWhatWasWritten() async throws {
        let payload = try await FontFiles.fetch(try FontFiles.offer("Fredoka", store: store), source: FakeFontSource())
        // a file sits where the folder of the font must go: the operation cannot write
        let fonts = dir.appendingPathComponent("assets/fonts"); try FileManager.default.createDirectory(at: fonts, withIntermediateDirectories: true)
        try "x".write(to: fonts.appendingPathComponent("fredoka"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try store.apply(.addFontFiles(payload)))
        XCTAssertEqual(Assets.load(store).filter { $0.type == "font" }.count, 0, "no row")
        XCTAssertEqual(try String(contentsOf: fonts.appendingPathComponent("fredoka"), encoding: .utf8), "x", "what was there is untouched")
    }

    // MARK: the operation: files, licence, manifest, journal, undo

    func testAcceptingCreatesTheFilesTheLicenceAndApprovedRowsAndUndoRemovesEverything() async throws {
        let src = FakeFontSource()
        _ = try await add("Fredoka", src)
        let d = dir.appendingPathComponent("assets/fonts/fredoka")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: d.path).sorted(), ["Fredoka[wdth,wght].ttf", "OFL.txt"], "the variable file, and the licence text")
        XCTAssertEqual(try String(contentsOf: d.appendingPathComponent("OFL.txt"), encoding: .utf8), "licence text")
        let rows = Assets.load(store).filter { $0.type == "font" }
        XCTAssertEqual(rows.map { $0.file }, ["fonts/fredoka/Fredoka[wdth,wght].ttf"]); XCTAssertEqual(rows.first?.status, "approved"); XCTAssertEqual(rows.first?.notes, "approved by the owner through the Add font files card")
        XCTAssertTrue(rows.first?.licenceNote.contains("SIL Open Font License 1.1") == true); XCTAssertEqual(rows.first?.origin, "fonts"); XCTAssertEqual(rows.first?.id, "font-01")
        XCTAssertEqual(src.downloaded.sorted(), ["Fredoka[wdth,wght].ttf", "OFL.txt"])
        XCTAssertEqual(store.journal.entries().last?.op, "addFontFiles"); XCTAssertEqual(store.journal.entries().last?.state, "applied")
        guard case .embedded(let n, _, let lic) = FontUse.state("Fredoka", store: store) else { return XCTFail("embedded") }
        XCTAssertEqual(n, 1); XCTAssertTrue(lic.contains("SIL Open Font License"))
        XCTAssertThrowsError(try store.apply(.addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "Fredoka[wdth,wght].ttf", data: fakeSfnt(family: "Fredoka", weight: 400))]))), "no change when the files are already in")
        XCTAssertFalse(Checks.run(area: "resources", store: store).contains { $0.level == .fail }, "the new folder is not a stray one and its files are listed")
        try store.undo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: d.path), "the folder goes with its files")
        XCTAssertTrue(Assets.load(store).filter { $0.type == "font" }.isEmpty); XCTAssertEqual(FontUse.state("Fredoka", store: store), .needsFiles)
        try store.redo()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: d.path).sorted(), ["Fredoka[wdth,wght].ttf", "OFL.txt"]); XCTAssertEqual(Assets.load(store).filter { $0.type == "font" }.count, 1)
    }

    func testAFamilyWithOneWeightIsEmbeddedForTitlesAtBold() async throws {
        try look(titles: "Anton", text: "Nunito")
        XCTAssertEqual(FontUse.state("Anton", store: store), .needsFiles)
        _ = try await add("Anton")
        guard case .embedded = FontUse.state("Anton", store: store) else { return XCTFail("Anton's one file serves the titles asked at 700") }
        let p = FontEmbedding.plan(store)
        XCTAssertEqual(p.entries.map { "\($0.family) \($0.weight)" }, ["Anton 400"]); XCTAssertEqual(p.missing.map { $0.family }, ["Nunito"])
    }

    // MARK: Clap

    func testClapProposesTheSameCardAndNeverDownloadsBeforeTheYes() async throws {
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let src = FakeFontSource(); tools.fontSource = src
        ui.accept = false
        let no = await tools.run("add_font_files", ["font": "Fredoka"]).text
        XCTAssertTrue(no.hasPrefix("refused by the user"), no); XCTAssertTrue(src.downloaded.isEmpty); XCTAssertEqual(ui.cards.last?.title, "Add the font files of Fredoka")
        let off = await tools.run("add_font_files", ["font": "Comic Sans"]).text
        XCTAssertTrue(off.hasPrefix("refused:") && off.contains("skill's list"), off); XCTAssertEqual(ui.cards.count, 1, "no card for a font outside the list")
        ui.accept = true
        let yes = await tools.run("add_font_files", ["font": "Fredoka"]).text
        XCTAssertTrue(yes.hasPrefix("accepted and applied"), yes); XCTAssertEqual(src.downloaded.sorted(), ["Fredoka[wdth,wght].ttf", "OFL.txt"]); XCTAssertEqual(store.journal.entries().last?.author, "clap")
        XCTAssertTrue(Tools.definitions.contains { ($0["name"] as? String) == "add_font_files" })
        let again = await tools.run("add_font_files", ["font": "Fredoka"]).text
        XCTAssertTrue(again.contains("already is embedded"), again)
    }

    // MARK: frozen during a build and a generation

    func testFrozenDuringABuildAndAGeneration() async throws {
        let src = FakeFontSource(); let offer = try FontFiles.offer("Fredoka", store: store)
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
        try look(titles: "Poppins", text: "Nunito")
        let p0 = FontEmbedding.plan(store)
        XCTAssertTrue(p0.entries.isEmpty); XCTAssertEqual(p0.missing.map { $0.family }, ["Poppins", "Nunito"])
        let s0 = try XCTUnwrap(FontEmbedding.step(store, entries: []))
        XCTAssertFalse(s0.ok); XCTAssertTrue(s0.text.contains("Poppins (titles), Nunito (text) has no approved file") && s0.text.contains("system font") && s0.text.contains("can vary between computers"))
        _ = try await add("Poppins")
        let p = FontEmbedding.plan(store)
        XCTAssertEqual(p.entries.map { "\($0.family) \($0.weight) \($0.path)" }, ["Poppins 700 ../assets/fonts/poppins/Poppins-Bold.ttf"], "bold only: the regular file is not even downloaded")
        XCTAssertEqual(p.missing.map { $0.family }, ["Nunito"])
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("v1"), withIntermediateDirectories: true)
        let written = FontEmbedding.write(version: "v1", store: store)
        XCTAssertEqual(written.count, 1)
        let j = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("v1/fonts.json"))) as? [String: Any])
        XCTAssertEqual((j["fonts"] as? [[String: Any]])?.first?["family"] as? String, "Poppins")
        // a variable font is one entry for the range
        _ = try await add("Nunito")
        XCTAssertEqual(FontEmbedding.plan(store).entries.map { "\($0.family) \($0.weight)" }.sorted(), ["Nunito 300 700", "Poppins 700"])
        XCTAssertTrue(FontEmbedding.step(store, entries: [])!.ok)
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
        XCTAssertNil(r.steps.first { $0.id == "build.3d" }, "no 3D step for a film without 3D")
        let step = try XCTUnwrap(r.steps.first { $0.id == "build.fonts" })
        XCTAssertEqual(step.level, .tight); XCTAssertTrue(step.detail.contains("Fredoka (titles)") && step.detail.contains("system font instead"), step.detail)
        XCTAssertFalse(r.ok, "an orange step keeps the report from being all green")
        XCTAssertFalse(try String(contentsOf: Versions.distURL(store, "v1"), encoding: .utf8).contains("@font-face{font-family:\"Fredoka\""))
        // the film is assembled, recorded, then the files are added
        let a = await FilmAssembly.run(version: "v1", store: store, skill: skill)
        XCTAssertTrue(a.ok, a.message)
        let before = FilmBuild.status(store)
        XCTAssertEqual(before.state, .upToDate); XCTAssertTrue(before.scenes.values.allSatisfy { $0.state == .upToDate })
        _ = try await add("Fredoka")
        let after = FilmBuild.status(store)
        XCTAssertEqual(after.state, .stale); XCTAssertEqual(after.staleReasons, ["the embedded fonts changed"], "the film is stale because of the fonts")
        XCTAssertEqual(after.scenes, before.scenes, "no scene is stale: the code of the modules did not change")
        let b = await FilmAssembly.run(version: "v1", store: store, skill: skill)
        XCTAssertTrue(b.ok, b.message)
        let html = try String(contentsOf: Versions.distURL(store, "v1"), encoding: .utf8)
        XCTAssertTrue(html.contains("@font-face{font-family:\"Fredoka\";font-weight:"), "the font is in the film"); XCTAssertFalse(html.contains("font-family:\"Nunito\""), "Nunito has no file: not embedded")
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
        _ = try await add("Fredoka")
        XCTAssertEqual(SceneModules.statuses(version: "v1", store: store), before)
        XCTAssertEqual(["S01", "S02"].map { SceneModules.moduleHash(version: "v1", scene: $0, store: store) }, hashes, "the scene files are not touched")
    }

    // MARK: C1: what the failure says

    func testAnAnswerOfTheRepositoryKeepsItsCodeAndAddress() {
        let url = "https://api.github.com/repos/google/fonts/contents/ofl/poppins"
        let e = FontRepositoryError.judge(status: 404, headers: [:], body: Data(#"{"message":"Not Found"}"#.utf8), url: url)
        XCTAssertFalse(e.rateLimited); XCTAssertEqual(e.status, 404)
        XCTAssertTrue(e.localizedDescription.contains("HTTP 404") && e.localizedDescription.contains(url) && e.localizedDescription.contains("the file is not there"), e.localizedDescription)
    }

    func testACallLimitIsToldApartAndSaysWhatToDo() {
        let url = "https://api.github.com/repos/google/fonts/contents/ofl/poppins"
        for (status, headers, body) in [(403, ["x-ratelimit-remaining": "0"] as [AnyHashable: Any], "{}"), (403, [:], #"{"message":"API rate limit exceeded for 1.2.3.4"}"#), (429, [:], "")] {
            let e = FontRepositoryError.judge(status: status, headers: headers, body: Data(body.utf8), url: url)
            XCTAssertTrue(e.rateLimited)
            XCTAssertTrue(e.localizedDescription.hasPrefix("The anonymous request limit of GitHub was reached; try again later or download the font by hand"), e.localizedDescription)
            XCTAssertTrue(e.localizedDescription.contains("HTTP \(status)") && e.localizedDescription.contains(url))
        }
        XCTAssertFalse(FontRepositoryError.judge(status: 403, headers: ["x-ratelimit-remaining": "12"], body: Data("{}".utf8), url: url).rateLimited, "a refusal that is not about the limit")
    }

    func testTheDownloadErrorNamesTheCodeTheLimitAndTheManualWay() async throws {
        let offer = try FontFiles.offer("Fredoka", store: store)
        let src = FakeFontSource()
        src.error = FontRepositoryError(status: 403, url: "https://raw.githubusercontent.com/x", rateLimited: true)
        do { _ = try await FontFiles.fetch(offer, source: src); XCTFail("refused") }
        catch let e as FontLookupError {
            XCTAssertTrue(e.retryable && e.family == "Fredoka")
            XCTAssertTrue(e.text.contains("anonymous request limit") && e.text.contains("HTTP 403") && e.text.contains("https://fonts.google.com/specimen/Fredoka") && e.text.contains("Nothing was added"), e.text)
        } catch { XCTFail("\(error)") }
        XCTAssertTrue(src.downloaded.isEmpty)
    }

    // MARK: GoogleFontsSource, with the network stubbed

    final class Stub: URLProtocol {
        nonisolated(unsafe) static var routes: [(String, (Int, [String: String], Data))] = []
        nonisolated(unsafe) static var failAll = false
        nonisolated(unsafe) static var seen: [String] = []
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let url = request.url?.absoluteString ?? ""
            Stub.seen.append(url)
            if Stub.failAll { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
            let r = Stub.routes.first { url.contains($0.0) }?.1 ?? (404, [:], Data("not found".utf8))
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: r.0, httpVersion: nil, headerFields: r.1)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: r.2); client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }
    func stubbed() -> GoogleFontsSource {
        Stub.routes = []; Stub.failAll = false; Stub.seen = []
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [Stub.self]
        return GoogleFontsSource(session: URLSession(configuration: c))
    }
    func spec(_ name: String, size: Int, list: String? = nil) -> RepoFile {
        RepoFile(name: name, size: size, url: "https://raw.githubusercontent.com/google/fonts/main/ofl/anton/\(name)", list: list, family: "Anton")
    }

    func testTheRepositoryIsTheFirstSourceAndNeedsNoListCall() async throws {
        let src = stubbed(); let font = fakeSfnt(family: "Anton", weight: 400)
        Stub.routes = [("raw.githubusercontent.com", (200, [:], font))]
        let d = try await src.download(spec("Anton-Regular.ttf", size: font.count))
        XCTAssertEqual(d, font); XCTAssertEqual(Stub.seen.count, 1); XCTAssertFalse(Stub.seen.joined().contains("api.github.com"), "the GitHub API is never called")
        XCTAssertFalse(Stub.seen.joined().contains("fonts.google.com"), "and the list is not asked when the repository answers")
    }

    func testErrors403404429AndANetworkThatIsOffEachHaveTheirMessage() async throws {
        let src = stubbed(); let f = spec("Anton-Regular.ttf", size: 100)
        func message(_ file: RepoFile = f) async -> String { do { _ = try await src.download(file); return "no error" } catch { return error.localizedDescription } }
        Stub.routes = [("raw.githubusercontent.com", (403, ["x-ratelimit-remaining": "0"], Data("{}".utf8))), ("fonts.google.com", (429, [:], Data()))]
        var m = await message()
        XCTAssertTrue(m.contains("anonymous request limit") && m.contains("HTTP 429") && m.contains("fonts.google.com"), m)
        Stub.routes = [("raw.githubusercontent.com", (404, [:], Data("nope".utf8))), ("fonts.google.com", (404, [:], Data()))]
        m = await message()
        XCTAssertTrue(m.contains("HTTP 404") && m.contains("raw.githubusercontent.com") && m.contains("fonts.google.com"), m)
        Stub.routes = [("raw.githubusercontent.com", (500, [:], Data())), ("fonts.google.com", (503, [:], Data()))]
        m = await message()
        XCTAssertTrue(m.contains("HTTP 503"), m)
        Stub.failAll = true
        m = await message()
        XCTAssertTrue(m.contains("the network failed") && m.contains("raw.githubusercontent.com"), m)
        // the licence has no fallback: its message is the repository's own
        Stub.failAll = false; Stub.routes = [("raw.githubusercontent.com", (403, ["x-ratelimit-remaining": "0"], Data("{}".utf8)))]
        m = await message(RepoFile(name: "OFL.txt", size: 0, url: "https://raw.githubusercontent.com/google/fonts/main/ofl/anton/OFL.txt", family: "Anton"))
        XCTAssertTrue(m.contains("anonymous request limit") && m.contains("HTTP 403"), m)
    }

    func testTheFallbackServesFromGoogleFontsOwnListWhenTheRepositoryFailsOrDoesNotHoldTheFile() async throws {
        let src = stubbed(); let font = fakeSfnt(family: "Anton", weight: 400)
        let list = ")]}'\n" + #"{"manifest":{"files":[{"filename":"OFL.txt","contents":"x"}],"fileRefs":[{"filename":"static/Anton-Regular.ttf","url":"https://fonts.gstatic.com/s/anton/v27/a.ttf"}]}}"#
        Stub.routes = [("raw.githubusercontent.com", (404, [:], Data())), ("fonts.google.com/download/list", (200, [:], Data(list.utf8))), ("fonts.gstatic.com", (200, [:], font))]
        var d = try await src.download(spec("Anton-Regular.ttf", size: font.count))
        XCTAssertEqual(d, font)
        XCTAssertTrue(Stub.seen.contains { $0.contains("download/list?family=Anton") } && Stub.seen.contains { $0.contains("gstatic") })
        // a file the repository holds under another name goes straight to the list
        Stub.seen = []
        d = try await src.download(spec("Anton-Regular.ttf", size: font.count, list: "static/Anton-Regular.ttf"))
        XCTAssertEqual(d, font); XCTAssertFalse(Stub.seen.contains { $0.contains("raw.githubusercontent.com") })
        // the fallback does not insist on the size (the list may serve a newer version), but on a font
        d = try await src.download(spec("Anton-Regular.ttf", size: 5, list: "static/Anton-Regular.ttf"))
        XCTAssertEqual(d, font)
    }

    func testAFileThatIsEmptyTheWrongSizeOrNotAFontIsRefused() async throws {
        let src = stubbed(); let font = fakeSfnt(family: "Anton", weight: 400)
        func message(_ f: RepoFile) async -> String { do { _ = try await src.download(f); return "no error" } catch { return error.localizedDescription } }
        Stub.routes = [("raw.githubusercontent.com", (200, [:], Data()))]
        var m = await message(spec("Anton-Regular.ttf", size: 10))
        XCTAssertTrue(m.contains("is empty"), m)
        Stub.routes = [("raw.githubusercontent.com", (200, [:], font))]
        m = await message(spec("Anton-Regular.ttf", size: font.count + 7))
        XCTAssertTrue(m.contains("the list says"), m)
        Stub.routes = [("raw.githubusercontent.com", (200, [:], Data("<html>sign in to continue</html>".utf8)))]
        m = await message(spec("Anton-Regular.ttf", size: 32))
        XCTAssertTrue(m.contains("is not a font"), m)
        XCTAssertTrue(GoogleFontsSource.looksLikeFont(font) && !GoogleFontsSource.looksLikeFont(Data("OTT".utf8)))
        // a host that is not the repository's is refused before any request
        Stub.seen = []
        m = await message(RepoFile(name: "x.ttf", size: 1, url: "https://example.com/x.ttf", family: "Anton"))
        XCTAssertTrue(m.contains("refused"), m); XCTAssertTrue(Stub.seen.isEmpty)
    }

    /// Only with SHOWREEL_NETWORK_TESTS=1, and never the GitHub API: Anton and Poppins are downloaded through the chosen source (a handful of requests), with their files and licence.
    func testTheRealDownloadOfAntonAndPoppinsWhenAsked() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SHOWREEL_NETWORK_TESTS"] == "1", "set SHOWREEL_NETWORK_TESTS=1 to try the real service")
        for (family, expect) in [("Anton", ["Anton-Regular.ttf", "OFL.txt"]), ("Poppins", ["Poppins-Regular.ttf", "Poppins-Bold.ttf", "OFL.txt"])] {
            try look(titles: family, text: family)
            let offer = try FontFiles.offer(family, store: store)
            let p = try await FontFiles.fetch(offer, source: GoogleFontsSource())
            XCTAssertEqual(p.files.map { $0.name }, expect, family)
            for f in p.fontFiles { XCTAssertEqual(f.data.count, offer.files.first { $0.name == f.name }?.size, "\(f.name) has the size of the manifest"); XCTAssertNotNil(FontInfo.parse(f.data), f.name) }
            XCTAssertTrue(String(decoding: p.files.last?.data ?? Data(), as: UTF8.self).contains("SIL Open Font License"), "the licence text came with it")
            try store.apply(.addFontFiles(p))
            guard case .embedded = FontUse.state(family, store: store) else { return XCTFail("\(family) embedded") }
            try store.undo()
        }
    }
}
