import AppKit
import XCTest
@testable import ShowreelKit

final class AssetTests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("assets"); inbox = makeTempDir("inbox"); store = ProjectStore(root: dir)
        try? store.create(name: "A", conversationLanguage: nil, reelLanguages: [])
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }

    func file(_ name: String, _ content: String = "x") -> URL {
        let u = inbox.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? content.write(to: u, atomically: true, encoding: .utf8)
        return u
    }

    func png(_ name: String, _ w: Int, _ h: Int) -> URL {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let u = inbox.appendingPathComponent(name)
        try? rep.representation(using: .png, properties: [:])!.write(to: u)
        return u
    }

    func testClassificationFollowsTheOrganiser() {
        XCTAssertEqual(Assets.classify("Company Logo.svg"), "logo")
        XCTAssertEqual(Assets.classify("app-home.png"), "shot")
        XCTAssertEqual(Assets.classify("beach.JPG"), "photo")
        XCTAssertEqual(Assets.classify("theme.mp3"), "audio")
        XCTAssertEqual(Assets.classify("narration.wav"), "voice")
        XCTAssertEqual(Assets.classify("Poppins-Bold.ttf"), "font")
        XCTAssertEqual(Assets.classify("licence.txt"), "note")
        XCTAssertEqual(Assets.classify("figures.csv"), "data")
        XCTAssertEqual(Assets.slug("Company Logo (final).svg", type: "logo"), "company-final")
    }

    func testDroppedFilesAreCopiedAndListed() throws {
        let rows = try Assets.add([file("Acme Logo.svg", "<svg/>"), file("theme.mp3"), file("brand-notes.pdf")], to: store)
        XCTAssertEqual(rows.map { $0.id }, ["logo-01", "audio-01", "doc-01"])
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("assets/source/Acme Logo.svg").path), "the original goes to source with its name")
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("assets/prepared/logo-01-acme.svg").path), "an embeddable file also gets its typed copy")
        XCTAssertEqual(rows[0].file, "prepared/logo-01-acme.svg")
        XCTAssertEqual(rows[0].origin, "prepared")
        XCTAssertEqual(rows[0].status, "approved", "a file the user adds is theirs to use: available at once")
        XCTAssertEqual(rows[2].file, "", "a document is only listed")
        XCTAssertEqual(rows[2].notes, "not embedded")
        // the second logo gets the next number; ids are never reused after a removal from the list
        let more = try Assets.add([file("Other-logo.svg")], to: store)
        XCTAssertEqual(more.first?.id, "logo-02")
        XCTAssertEqual(Assets.load(store).count, 4)
        // a name that is already taken in source is not overwritten
        let again = try Assets.add([file("theme.mp3", "different")], to: store)
        XCTAssertEqual(again.first?.id, "audio-02")
        XCTAssertEqual(again.first?.original, "theme-2.mp3")
    }

    func testManifestIsAcceptedByTheSkillsOrganiser() throws {
        _ = try Assets.add([file("Acme Logo.svg"), file("theme.mp3"), file("brand-notes.pdf"), png("app-home.png", 64, 32)], to: store)
        let skill = try XCTUnwrap(Skill.root())
        let script = skill.appendingPathComponent("scripts/organize_assets.py").path
        let out = try runPython("import subprocess,sys; r=subprocess.run(['python3',sys.argv[1],sys.argv[2],'--check','--allow-hold'],capture_output=True,text=True); print(r.returncode); print(r.stdout)",
                                args: [script, dir.path])
        XCTAssertTrue(out.hasPrefix("0\n"), "organize_assets.py --check must accept what the app writes: \(out)")
        let planOut = try runPython("import subprocess,sys; r=subprocess.run(['python3',sys.argv[1],sys.argv[2]],capture_output=True,text=True); print(r.stdout)", args: [script, dir.path])
        XCTAssertTrue(planOut.contains("nothing new to organise"), "the organiser sees nothing left to do: \(planOut)")
    }

    func testRiskyFilesAreHeldAndNotApprovableFromHere() throws {
        let rows = try Assets.add([file("customers-real-data.csv", "name,email\nA,a@example.com\n"), file("keys.txt", "api_key = abc"), png("app-home.png", 64, 32), file("plain.txt")], to: store)
        XCTAssertEqual(rows[0].status, "hold"); XCTAssertEqual(rows[0].origin, "not copied")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/source/customers-real-data.csv").path), "sensitive files are not copied into the project")
        XCTAssertEqual(rows[1].status, "hold", "content that looks like credentials")
        XCTAssertEqual(rows[2].status, "hold"); XCTAssertTrue(rows[2].notes.contains("resolution is low"), rows[2].notes)
        XCTAssertEqual(rows[2].file, "", "a held image is not copied to prepared")
        XCTAssertEqual(rows[3].status, "approved")
        XCTAssertThrowsError(try store.plan(.asset(id: "data-01", status: .approved, note: nil, licence: nil, scenes: nil)))
        // the user can accept a low-resolution image knowingly: its prepared copy is made then
        XCTAssertThrowsError(try store.apply(.asset(id: "shot-01", status: .approved, note: nil, licence: nil, scenes: nil))) { XCTAssertTrue($0.localizedDescription.contains("accept the risk")) }
        try store.apply(.asset(id: "shot-01", status: .approved, note: "accepted: it is only a stand-in", licence: nil, scenes: nil))
        let r = try XCTUnwrap(Assets.load(store).first { $0.id == "shot-01" })
        XCTAssertEqual(r.status, "approved"); XCTAssertEqual(r.file, "prepared/shot-01-app-home.png"); XCTAssertEqual(r.notes, "accepted: it is only a stand-in")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/prepared/shot-01-app-home.png").path))
    }

    func testStatusNoteScenesAndExclusion() throws {
        _ = try Assets.add([file("Acme Logo.svg")], to: store)
        XCTAssertThrowsError(try store.plan(.asset(id: "logo-01", status: .hold, note: nil, licence: nil, scenes: nil)), "a hold needs a note")
        try store.apply(.asset(id: "logo-01", status: .hold, note: "waiting for the vector file", licence: nil, scenes: nil))
        XCTAssertEqual(Assets.load(store)[0].notes, "waiting for the vector file")
        try store.apply(.asset(id: "logo-01", status: .approved, note: "", licence: "brand licence 2026", scenes: "S01, S07"))
        let r = Assets.load(store)[0]
        XCTAssertEqual(r.status, "approved"); XCTAssertEqual(r.licenceNote, "brand licence 2026"); XCTAssertEqual(r.sceneIDs, ["S01", "S07"])
        try store.apply(.asset(id: "logo-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(Assets.load(store)[0].file, "", "our prepared copy is removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/prepared/logo-01-acme.svg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/source/Acme Logo.svg").path), "the original stays")
        XCTAssertThrowsError(try store.plan(.asset(id: "nope-09", status: .approved, note: nil, licence: nil, scenes: nil)))
    }

    func testTheBriefListsTheAssets() throws {
        var f = try XCTUnwrap(store.loadShowreel()); f.parameters.audience = "Teams"; try store.save(f)
        _ = try Assets.add([file("Acme Logo.svg")], to: store)
        let brief = try XCTUnwrap(store.read("brief.md"))
        XCTAssertTrue(brief.contains("## Assets manifest") && brief.contains("prepared/logo-01-acme.svg"))
    }
}
