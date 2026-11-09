import XCTest
@testable import ShowreelKit

final class LookTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("look"); store = ProjectStore(root: dir); try? store.create(name: "L", conversationLanguage: nil, reelLanguages: []) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    // MARK: catalogues read from the skill

    func testCataloguesComeFromTheSkill() {
        let bg = Look.backgroundIDs()
        XCTAssertGreaterThanOrEqual(bg.count, 20); XCTAssertTrue(bg.contains("aurora") && bg.contains("solid") && bg.contains("waves-flow"))
        XCTAssertEqual(Set(Look.backgroundMoods()), ["punch", "playful", "tech", "clean", "cinematic", "deadpan"])
        let packs = Look.packs()
        XCTAssertEqual(packs.map { $0.name }, ["Deadpan", "Kinetic punch", "Clean product", "Playful toy", "Cinematic", "Tech decode"])
        XCTAssertTrue(packs.allSatisfy { !$0.effects.isEmpty && !$0.feel.isEmpty })
        XCTAssertTrue(packs.first { $0.name == "Tech decode" }?.effects.contains("Scramble decode") == true)
        XCTAssertFalse(packs.flatMap { $0.effects }.contains { $0.contains("(") }, "notes in parentheses are dropped")
        XCTAssertEqual(Look.mood(forPack: "Kinetic punch"), "punch"); XCTAssertEqual(Look.mood(forPack: "Cinematic"), "cinematic"); XCTAssertNil(Look.mood(forPack: "Nope"))
        let fonts = Look.freeFonts()
        XCTAssertEqual(fonts.count, 70)
        XCTAssertTrue(fonts.allSatisfy { Look.previewURL(for: $0) != nil }, "every free font has its bundled preview, for real samples")
    }

    // MARK: palette contrast

    func testContrastRatio() {
        XCTAssertEqual(Contrast.ratio("#000000", "#FFFFFF"), 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio("#FFFFFF", "#FFFFFF"), 1, accuracy: 0.001)
        XCTAssertEqual(Contrast.ratio("#767676", "#FFFFFF"), 4.54, accuracy: 0.02, "the known AA boundary grey")
        XCTAssertEqual(Contrast.ratio("#101820", "#F2AA4C"), Contrast.ratio("#F2AA4C", "#101820"), "symmetric")
    }

    func testPaletteChecksAreGreenOrRed() {
        func by(_ p: [String]?) -> [String: CheckLevel] { Dictionary(uniqueKeysWithValues: Contrast.checks(p).map { ($0.id, $0.level) }) }
        XCTAssertEqual(by(nil)["palette.any"], .pending)
        XCTAssertEqual(by(["#101820"])["palette.pair"], .pending)
        XCTAssertEqual(by(["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2"]), ["palette.text": .ok, "palette.accent": .ok, "palette.accent2": .ok])
        XCTAssertEqual(by(["#101820", "#202830"])["palette.text"], .fail, "text barely lighter than the background")
        XCTAssertEqual(by(["#FFFFFF", "#8A8A8A"])["palette.text"], .tight, "readable only when large")
        XCTAssertEqual(by(["#101820", "#FFFFFF", "#18202A"])["palette.accent"], .fail, "an accent that disappears")
        XCTAssertEqual(by(["#101820", "red"])["palette.hex"], .fail)
    }

    func testPaletteIsStoredInTheRolesTheEngineUses() {
        let p = EnginePalette(stored: ["#101820", "#FFFFFF", "#F2AA4C"])
        XCTAssertEqual([p.bg, p.fg, p.accent, p.accent2], ["#101820", "#FFFFFF", "#F2AA4C", "#F2AA4C"], "a missing accent 2 reuses the accent")
        XCTAssertEqual(EnginePalette(stored: ["#000000", "#FFFFFF"]).mute, "#808080", "the muted tone sits halfway between background and text")
        XCTAssertEqual(EnginePalette(stored: nil).bg, "#101820")
    }

    // MARK: decisions as typed operations

    func testDecisionKeysValidateAgainstTheEngine() throws {
        var f = ShowreelFile(name: "k")
        try DecisionKey.palette.set(" #101820 , #ffffff,#f2aa4c ", in: &f)
        XCTAssertEqual(f.decisions.palette, ["#101820", "#FFFFFF", "#F2AA4C"], "normalised to upper case")
        XCTAssertThrowsError(try DecisionKey.palette.set("#12345", in: &f)); XCTAssertThrowsError(try DecisionKey.palette.set("#000000,#111111,#222222,#333333,#444444,#555555,#666666", in: &f))
        try DecisionKey.background.set("aurora", in: &f); try DecisionKey.backgroundMood.set("cinematic", in: &f)
        XCTAssertEqual(f.decisions.background, .init(id: "aurora", mood: "cinematic"))
        XCTAssertThrowsError(try DecisionKey.background.set("sparkles", in: &f), "an id the engine does not know")
        XCTAssertThrowsError(try DecisionKey.backgroundMood.set("loud", in: &f))
        try DecisionKey.moods.set("Cinematic, Deadpan", in: &f)
        XCTAssertEqual(f.decisions.moods, ["Cinematic", "Deadpan"])
        XCTAssertThrowsError(try DecisionKey.moods.set("Cinematic, Deadpan, Clean product", in: &f), "one or two moods")
        XCTAssertThrowsError(try DecisionKey.effectsPack.set("Loud", in: &f))
        try DecisionKey.effectsPack.set("Cinematic", in: &f)
        try DecisionKey.titleFont.set("Anton", in: &f); try DecisionKey.textFont.set("Inter", in: &f)
        XCTAssertEqual(f.decisions.fonts, .init(titles: "Anton", text: "Inter"))
        // clearing removes the key, and leaves unknown nested keys alone
        f.decisions.fonts?.unknown["future"] = .bool(true)
        try DecisionKey.titleFont.set("", in: &f); try DecisionKey.textFont.set("", in: &f)
        XCTAssertNotNil(f.decisions.fonts, "a font block with a key we do not know is kept")
        try DecisionKey.background.set("", in: &f); try DecisionKey.backgroundMood.set("", in: &f)
        XCTAssertNil(f.decisions.background)
    }

    func testDecisionCardShowsBeforeAndAfterAndAppliesOnce() throws {
        let card = try store.plan(.decisions([DecisionChange(.palette, "#101820, #FFFFFF"), DecisionChange(.titleFont, "Anton")], title: nil))
        XCTAssertEqual(card.title, "Change the look")
        XCTAssertEqual(card.changes, [Change("Palette", "(empty)", "#101820, #FFFFFF"), Change("Title font", "(empty)", "Anton")])
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF"), DecisionChange(.titleFont, "Anton")], title: nil), expecting: card)
        XCTAssertEqual(store.loadShowreel()?.decisions.palette, ["#101820", "#FFFFFF"])
        XCTAssertEqual(try store.plan(.decisions([DecisionChange(.titleFont, "Poppins")], title: nil)).title, "Set title font")
        XCTAssertThrowsError(try store.plan(.decisions([DecisionChange(.titleFont, "Anton")], title: nil)), "no change is an error")
        XCTAssertThrowsError(try store.plan(.decisions([DecisionChange(.background, "nope")], title: nil)))
        // the style sheet is regenerated with the roles named
        let sheet = try XCTUnwrap(store.read("style-sheet.md"))
        XCTAssertTrue(sheet.contains("2. Palette (background, text, accent, accent 2): #101820, #FFFFFF") && sheet.contains("titles Anton"))
    }

    // MARK: look packages

    func testEveryLookPackageIsValidAndReadable() throws {
        let all = LookPackages.all()
        XCTAssertGreaterThanOrEqual(all.count, 6)
        let bgs = Look.backgroundIDs(), fonts = Look.freeFonts().map { $0.name }, packs = Look.packs().map { $0.name }
        XCTAssertEqual(Set(all.map { $0.id }).count, all.count)
        for p in all {
            XCTAssertTrue(bgs.contains(p.background), "\(p.id): background")
            XCTAssertTrue(fonts.contains(p.fonts.titles ?? "") && fonts.contains(p.fonts.text ?? ""), "\(p.id): fonts")
            XCTAssertTrue(packs.contains(p.pack), "\(p.id): pack")
            XCTAssertNotNil(Look.mood(forPack: p.pack), "\(p.id): mood")
            XCTAssertTrue(p.palette.count == 4 && p.palette.allSatisfy { EnginePalette.isHex($0) }, "\(p.id): palette")
            XCTAssertEqual(Checks.worst(Contrast.checks(p.palette)), .ok, "\(p.id): a starting point must pass its own contrast check")
            var f = ShowreelFile(name: "t")
            for d in p.decisions { XCTAssertNoThrow(try d.key.set(d.value, in: &f), "\(p.id) \(d.key)") }
        }
    }

    func testThreeDistinctPackagesNothingChosenForYou() throws {
        let three = LookPackages.three(tone: nil)
        XCTAssertEqual(three.count, 3); XCTAssertEqual(Set(three.map { $0.pack }).count, 3, "three different moods")
        XCTAssertNil(store.loadShowreel()?.decisions.palette, "showing them records nothing")
        XCTAssertEqual(LookPackages.three(tone: "playful and friendly").first?.id, "toy-box", "a tone that fits comes first")
        XCTAssertEqual(LookPackages.three(tone: "serious, premium").first?.id, "slow-film")
        XCTAssertTrue(LookPackages.matches(try XCTUnwrap(LookPackages.all().first { $0.id == "decode" }), tone: "a techy, digital voice"))
        let a = LookPackages.three(tone: nil, offset: 0), b = LookPackages.three(tone: nil, offset: 1)
        XCTAssertTrue(Set(a.map { $0.id }).isDisjoint(with: Set(b.map { $0.id })), "'other looks' shows the next three")
        // choosing one is one card that sets everything
        let p = a[0]
        let op = ProjectOperation.decisions(p.decisions, title: "Choose the look: \(p.name)")
        let card = try store.plan(op)
        XCTAssertEqual(card.title, "Choose the look: \(p.name)"); XCTAssertGreaterThanOrEqual(card.changes.count, 6)
        try store.apply(op)
        let d = try XCTUnwrap(store.loadShowreel()?.decisions)
        XCTAssertEqual(d.palette, p.palette); XCTAssertEqual(d.fonts?.titles, p.fonts.titles); XCTAssertEqual(d.background?.id, p.background); XCTAssertEqual(d.effectsPack, p.pack)
    }

    // MARK: font licences

    func sfnt(fsType: UInt16) -> Data {
        var d = Data([0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0])      // header: one table
        d += Data([0x4F, 0x53, 0x2F, 0x32, 0, 0, 0, 0, 0, 0, 0, 28, 0, 0, 0, 10])  // 'OS/2' record: offset 28
        var t = Data(count: 10); t[8] = UInt8(fsType >> 8); t[9] = UInt8(fsType & 0xFF)
        return d + t
    }

    func testFsTypeIsReadFromTheFontFile() {
        XCTAssertEqual(FontLicense.fsType(of: sfnt(fsType: 0)), 0)
        XCTAssertEqual(FontLicense.fsType(of: sfnt(fsType: 2)), 2)
        XCTAssertFalse(FontLicense.restricted(0)); XCTAssertFalse(FontLicense.restricted(8))
        XCTAssertTrue(FontLicense.restricted(2)); XCTAssertTrue(FontLicense.restricted(4))
        XCTAssertNil(FontLicense.fsType(of: Data("not a font".utf8)))
    }

    func testFontLicenceWarnings() throws {
        let rows = { Assets.load(self.store) }
        XCTAssertEqual(FontLicense.assess(name: "Poppins", assets: rows(), store: store).level, .ok, "the free list is open-licensed")
        XCTAssertEqual(FontLicense.assess(name: "Brand Sans", assets: rows(), store: store).level, .tight, "unknown: said, never assumed")
        let inbox = makeTempDir("fonts"); defer { try? FileManager.default.removeItem(at: inbox) }
        let bad = inbox.appendingPathComponent("Locked Sans.ttf"); try sfnt(fsType: 2).write(to: bad)
        let good = inbox.appendingPathComponent("Open Serif.ttf"); try sfnt(fsType: 0).write(to: good)
        try Assets.add([bad, good], to: store)
        XCTAssertEqual(FontLicense.assess(name: "Locked Sans", assets: rows(), store: store).level, .fail, "the file's own flag forbids embedding")
        XCTAssertTrue(FontLicense.assess(name: "Locked Sans", assets: rows(), store: store).message.contains("forbids embedding"))
        XCTAssertEqual(FontLicense.assess(name: "Open Serif", assets: rows(), store: store).level, .tight, "allowed by the flag, but no licence note yet")
        try store.apply(.asset(id: "font-02", status: .approved, note: nil, licence: "web and app embedding included (invoice 12)", scenes: nil))
        XCTAssertEqual(FontLicense.assess(name: "Open Serif", assets: rows(), store: store).level, .ok)
        // the look checks carry the warning to the block
        try store.apply(.decisions([DecisionChange(.titleFont, "Locked Sans"), DecisionChange(.textFont, "Poppins")], title: nil))
        let r = Dictionary(uniqueKeysWithValues: Checks.run(area: "look", store: store).map { ($0.id, $0.level) })
        XCTAssertEqual(r["font.titles"], .fail); XCTAssertEqual(r["font.text"], .ok)
    }

    func testLookChecksStartPendingAndTrackTheGate() throws {
        var r = Dictionary(uniqueKeysWithValues: Checks.run(area: "look", store: store).map { ($0.id, $0.level) })
        XCTAssertEqual(r["palette.any"], .pending); XCTAssertEqual(r["font.any"], .pending); XCTAssertEqual(r["look.background"], .pending)
        XCTAssertEqual(r["gate.style"], .pending)
        try store.apply(.decisions(LookPackages.three(tone: nil)[0].decisions, title: nil))
        try store.apply(.gate("style", passed: true))
        r = Dictionary(uniqueKeysWithValues: Checks.run(area: "look", store: store).map { ($0.id, $0.level) })
        XCTAssertEqual(r["palette.text"], .ok); XCTAssertEqual(r["look.background"], .ok); XCTAssertEqual(r["look.effects"], .ok); XCTAssertEqual(r["gate.style"], .ok)
    }

    // MARK: block status and wizard

    func testLookHasARealProgressionInTheInspector() throws {
        let spec = try XCTUnwrap(ProcessSpec.load())
        func st() -> BlockStatus { Blocks.status("inspector", spec: spec, showreel: store.loadShowreel(), assets: Assets.load(store)) }
        XCTAssertEqual(st(), .todo)
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF")], title: nil))
        XCTAssertEqual(st(), .inProgress)
        try store.apply(.gate("style", passed: true)); try store.apply(.gate("interview", passed: true))
        XCTAssertEqual(st(), .validated)
    }

    func testWizardLookSteps() throws {
        let spec = ProcessSpec.load()
        func steps() -> [WizardStep] { Wizard.steps(assets: Assets.load(store), spec: spec) }
        func decided(_ s: WizardStep) -> Bool { Wizard.isDecided(s, file: store.loadShowreel(), assets: Assets.load(store), settings: store.settings, spec: spec) }
        let ids = steps().map { $0.id }
        let look = ids.filter { $0.hasPrefix("look.") }
        XCTAssertEqual(look, ["look.board", "look.palette", "look.titleFont", "look.textFont", "look.background", "look.moods", "look.effectsPack", "look.summary"])
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: "resources.summary")), try XCTUnwrap(ids.firstIndex(of: "look.board")), "the look follows the assets, as the process does")
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: "look.summary")), try XCTUnwrap(ids.firstIndex(of: "storyboard.scenes")))
        XCTAssertTrue(steps().filter { $0.area == "look" }.allSatisfy { $0.isBuilt && !$0.title.isEmpty && !$0.help.isEmpty })
        XCTAssertTrue(steps().filter { $0.area == "look" }.allSatisfy { !decided($0) }, "nothing is decided until the user acts")
        // answers are the same typed operations as the block's pickers
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C")], title: nil))
        XCTAssertTrue(decided(try XCTUnwrap(steps().first { $0.id == "look.palette" })))
        XCTAssertFalse(decided(try XCTUnwrap(steps().first { $0.id == "look.board" })), "a palette alone does not settle the whole look")
        try store.apply(.decisions([DecisionChange(.titleFont, "Anton")], title: nil))
        XCTAssertTrue(decided(try XCTUnwrap(steps().first { $0.id == "look.titleFont" })))
        XCTAssertFalse(decided(try XCTUnwrap(steps().first { $0.id == "look.textFont" })))
        try store.apply(.decisions(LookPackages.three(tone: nil)[0].decisions, title: nil))
        XCTAssertTrue(decided(try XCTUnwrap(steps().first { $0.id == "look.board" })), "choosing a package settles it")
        for id in ["look.moods", "look.effectsPack", "look.background"] { XCTAssertTrue(decided(try XCTUnwrap(steps().first { $0.id == id })), id) }
        // Decide later writes nothing: resume stays on the first step with no value
        let first = Wizard.firstUndecided(steps(), file: store.loadShowreel(), assets: Assets.load(store), settings: store.settings, spec: spec).map { steps()[$0].id }
        XCTAssertNotNil(first)
        XCTAssertFalse(first?.hasPrefix("look.") == true && first != "look.summary" && first != nil && ids.firstIndex(of: first!)! < ids.firstIndex(of: "look.board")!)
    }

    func testSuggestWithAIForLookStepsAsksForCards() throws {
        for s in Wizard.steps(assets: [], spec: ProcessSpec.load()).filter({ $0.area == "look" && $0.id != "look.summary" }) {
            let p = Wizard.suggestionPrompt(s)
            XCTAssertTrue(p.contains("update_decision"), "\(s.id): \(p)")
            XCTAssertTrue(p.contains("accept or refuse") || p.contains("(key"), s.id)
        }
    }
}
