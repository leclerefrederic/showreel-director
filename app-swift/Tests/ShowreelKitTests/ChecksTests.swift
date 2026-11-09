import XCTest
@testable import ShowreelKit

final class ChecksTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("checks"); store = ProjectStore(root: dir) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    // MARK: feasibility, against the script it is ported from

    struct Case { var name: String; var duration: Double; var scenes: Int?; var textScenes: Int?; var words: Int?; var langs = 1
                  var bpm: Double?; var portrait = false; var perLang: [String: Int] = [:] }

    func pythonVerdicts(_ c: Case) throws -> [String: String] {
        let script = try XCTUnwrap(Skill.root()).appendingPathComponent("scripts/feasibility.py").path
        var args = ["python3", script, "--duration", String(c.duration)]
        if let s = c.scenes { args += ["--scenes", String(s)] }
        if let t = c.textScenes { args += ["--text-scenes", String(t)] }
        if let w = c.words { args += ["--words", String(w)] }
        if c.langs > 1 { args += ["--langs", String(c.langs)] }
        if let b = c.bpm { args += ["--bpm", String(b)] }
        if c.portrait { args.append("--portrait") }
        if !c.perLang.isEmpty { args += ["--words-per-lang", c.perLang.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env"); p.arguments = args
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        try p.run()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        var m: [String: String] = [:]
        for l in text.split(separator: "\n") where l.hasPrefix("[") {
            guard let close = l.firstIndex(of: "]") else { continue }
            let verdict = l[l.index(after: l.startIndex)..<close].trimmingCharacters(in: .whitespaces)
            let rest = l[l.index(after: close)...].trimmingCharacters(in: .whitespaces)
            if let colon = rest.firstIndex(of: ":") { m[String(rest[..<colon])] = verdict }
        }
        return m
    }

    func swiftVerdicts(_ c: Case) -> [String: String] {
        var b = Checks.Brief()
        b.duration = c.duration; b.scenes = c.scenes; b.textScenes = c.textScenes; b.words = c.words; b.langs = c.langs
        b.bpm = c.bpm; b.portrait = c.portrait; b.wordsPerLang = c.perLang
        var m: [String: String] = [:]
        for r in Checks.feasibility(b) where r.id != "feasibility.capacity" {
            m[String(r.id.dropFirst("feasibility.".count)).replacingOccurrences(of: "-", with: " ")] =
                r.level == .ok ? "OK" : r.level == .tight ? "TIGHT" : "NOT FEASIBLE"
        }
        return m
    }

    func testFeasibilityAgreesWithTheScript() throws {
        let cases = [
            Case(name: "balanced", duration: 60, scenes: 12, textScenes: 10, words: 80, langs: 2, bpm: 124),
            Case(name: "flashes", duration: 10, scenes: 40),
            Case(name: "portrait text", duration: 30, scenes: 14, textScenes: 14, words: 100, portrait: true),
            Case(name: "too many text scenes", duration: 30, scenes: 14, textScenes: 14, words: 40),
            Case(name: "per language", duration: 45, scenes: 9, textScenes: 6, bpm: 120, perLang: ["en": 30, "fr": 33]),
            Case(name: "montage", duration: 60, scenes: 40, textScenes: 8, words: 30),
            Case(name: "no text scenes, many words", duration: 30, scenes: 6, textScenes: 0, words: 300),
            Case(name: "long transitions", duration: 20, scenes: 30, textScenes: 2, words: 10),
            Case(name: "duration only", duration: 45),
            Case(name: "off the bar", duration: 47, scenes: 8, textScenes: 5, words: 40, bpm: 128),
        ]
        var compared = 0, kinds = Set<String>()
        for c in cases {
            let py = try pythonVerdicts(c)
            if c.name != "duration only" { XCTAssertFalse(py.isEmpty, "the script printed no verdict for \(c.name)") }
            XCTAssertEqual(swiftVerdicts(c), py, "verdicts differ for case \"\(c.name)\"")
            compared += py.count; kinds.formUnion(py.values)
        }
        XCTAssertGreaterThanOrEqual(compared, 20, "the comparison covers many verdicts, not an empty set")
        XCTAssertEqual(kinds, ["OK", "TIGHT", "NOT FEASIBLE"], "all three verdicts are exercised")
    }

    func testFeasibilityFromTheProject() throws {
        try store.create(name: "F", conversationLanguage: nil, reelLanguages: [])
        XCTAssertEqual(Checks.run(area: "project", store: store).first { $0.id.hasPrefix("feasibility") }?.level, .pending, "no duration, nothing to judge yet")
        try store.apply(.parameter(.duration, "30"))
        var f = try XCTUnwrap(store.loadShowreel())
        f.scenes = (1...14).map { .init(id: String(format: "S%02d", $0), duration: 2, text: "Some words here") }
        f.storyboards = [.init(items: f.scenes.map { .init(scene: $0.id) })]
        try store.save(f)
        let r = Checks.run(area: "project", store: store)
        XCTAssertEqual(r.first { $0.id == "feasibility.text-scenes" }?.level, .fail)
        XCTAssertEqual(Checks.worst(r), .fail)
        f.scenes = Array(f.scenes.prefix(5))
        try store.save(f)
        XCTAssertEqual(Checks.run(area: "project", store: store).first { $0.id == "feasibility.text-scenes" }?.level, .ok)
    }

    // MARK: reading budget per scene

    func testSecondsNeeded() {
        XCTAssertEqual(Checks.secondsNeeded(text: "", portrait: false), 0)
        XCTAssertEqual(Checks.secondsNeeded(text: "Hello you", portrait: false), 1.5, "floor for one to three words")
        XCTAssertEqual(Checks.secondsNeeded(text: "Notes that stay calm and clear", portrait: false), 3.0, accuracy: 0.01, "about 3 s from six words")
        let long = String(repeating: "word ", count: 20)
        XCTAssertGreaterThan(Checks.secondsNeeded(text: long, portrait: true), Checks.secondsNeeded(text: long, portrait: false), "portrait reads slower")
    }

    func testReadingBudgetPerScene() throws {
        try store.create(name: "R", conversationLanguage: nil, reelLanguages: [])
        var f = try XCTUnwrap(store.loadShowreel())
        f.scenes = [
            .init(id: "S01", duration: 4, text: "Notes that stay calm and clear"),                               // fits
            .init(id: "S02", duration: 1, text: "Capture anything you think of, anywhere, at any time of day"),  // far too short
            .init(id: "S03", text: "No duration yet"),
            .init(id: "S04", duration: 4, text: "Skipped", status: "ditched", archived: true),
            .init(id: "S05", duration: 2, text: "Un texte", texts: ["fr": "Un texte français nettement plus long que l'original"]),
        ]
        f.storyboards = [.init(items: f.scenes.map { .init(scene: $0.id, enabled: !$0.archived) })]
        try store.save(f)
        let r = Dictionary(uniqueKeysWithValues: Checks.run(area: "storyboard", store: store).map { ($0.id, $0.level) })
        XCTAssertEqual(r["reading.S01"], .ok)
        XCTAssertEqual(r["reading.S02"], .fail)
        XCTAssertEqual(r["reading.S03"], .pending)
        XCTAssertNil(r["reading.S04"], "a ditched scene is not judged")
        XCTAssertEqual(r["reading.S05"], .fail, "the longest translation counts")
    }

    // MARK: asset rules, against organize_assets.py --check

    func pythonAssetsCheck() throws -> Int32 {
        let script = try XCTUnwrap(Skill.root()).appendingPathComponent("scripts/organize_assets.py").path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env"); p.arguments = ["python3", script, dir.path, "--check"]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try p.run(); p.waitUntilExit()
        return p.terminationStatus
    }

    func testAssetRulesAgreeWithTheOrganiser() throws {
        try store.create(name: "A", conversationLanguage: nil, reelLanguages: [])
        let inbox = makeTempDir("inbox-checks"); defer { try? FileManager.default.removeItem(at: inbox) }
        let logo = inbox.appendingPathComponent("Acme Logo.svg"); try "<svg/>".write(to: logo, atomically: true, encoding: .utf8)
        let secret = inbox.appendingPathComponent("customers-real-data.csv"); try "a,b\n".write(to: secret, atomically: true, encoding: .utf8)
        XCTAssertEqual(Checks.run(area: "resources", store: store).first?.level, .pending, "no assets yet")
        try Assets.add([logo, secret], to: store)
        // a held file: red here, and the organiser fails too
        var r = Checks.run(area: "resources", store: store)
        XCTAssertEqual(r.first { $0.id == "assets.hold" }?.level, .fail)
        XCTAssertNotEqual(try pythonAssetsCheck(), 0)
        // decide it: green here, and the organiser passes
        _ = try? store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil))
        try store.apply(.asset(id: "data-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        r = Checks.run(area: "resources", store: store)
        XCTAssertEqual(r.first { $0.id == "assets.hold" }?.level, .ok)
        XCTAssertEqual(Checks.worst(r.filter { $0.id.hasPrefix("assets.") }), .ok)
        XCTAssertEqual(try pythonAssetsCheck(), 0)
        // a stray file in assets/ and an unlisted prepared file: red, and the organiser fails too
        try "x".write(to: dir.appendingPathComponent("assets/loose.png"), atomically: true, encoding: .utf8)
        try "x".write(to: dir.appendingPathComponent("assets/prepared/logo-09-unlisted.svg"), atomically: true, encoding: .utf8)
        r = Checks.run(area: "resources", store: store)
        XCTAssertEqual(r.first { $0.id == "assets.stray" }?.level, .fail)
        XCTAssertEqual(r.first { $0.id == "assets.names" }?.level, .fail)
        XCTAssertNotEqual(try pythonAssetsCheck(), 0)
    }

    func testPlaceholderAndNothingApproved() throws {
        try store.create(name: "P", conversationLanguage: nil, reelLanguages: [])
        try Assets.save([AssetRow(id: "logo-01", type: "logo", status: "placeholder")], store)
        let r = Checks.run(area: "resources", store: store)
        XCTAssertEqual(r.first { $0.id == "assets.placeholder" }?.level, .tight)
        XCTAssertEqual(r.first { $0.id == "assets.approved" }?.level, .pending)
    }

    func testBadStatusAndDuplicateIDsAreRed() throws {
        try store.create(name: "B", conversationLanguage: nil, reelLanguages: [])
        try Assets.save([AssetRow(id: "logo-01", type: "logo", status: "great"), AssetRow(id: "logo-01", type: "logo")], store)
        let r = Checks.run(area: "resources", store: store)
        XCTAssertEqual(r.first { $0.id == "assets.ids" }?.level, .fail)
        XCTAssertEqual(r.first { $0.id == "assets.status" }?.level, .fail)
    }

    // MARK: gate state

    func testGateStateOfEachBlock() throws {
        try store.create(name: "G", conversationLanguage: nil, reelLanguages: [])
        XCTAssertEqual(Checks.run(area: "project", store: store).first { $0.id == "gate.interview" }?.level, .pending)
        try store.apply(.gate("interview", passed: true))
        XCTAssertEqual(Checks.run(area: "project", store: store).first { $0.id == "gate.interview" }?.level, .ok)
        XCTAssertEqual(Checks.run(area: "resources", store: store).first { $0.id == "gate.assets" }?.level, .pending)
        let build = Checks.run(area: "build", store: store).map { $0.id }
        XCTAssertEqual(build.filter { $0.hasPrefix("gate.") }, ["gate.build", "gate.verify"], "a block with two gates reports both")
        XCTAssertTrue(build.contains("build.go"), "and the build block reports whether the Go was given")
    }
}
