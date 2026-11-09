import AppKit
import AudioToolbox
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ShowreelKit

/// R1: the Resources tab. The groups and the four states derived from the manifest, the tags, the automatic checks and what settles them, the rights question, a flagged file out of
/// Clap's sight and out of the build, the fonts, the centre of the viewer, the freeze.
final class ResourceFlowTests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("resflow"); inbox = makeTempDir("resflow-in"); store = ProjectStore(root: dir)
        try? store.create(name: "R", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t, status: "validated"))) }
        store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    var file: ShowreelFile { store.loadShowreel()! }
    func rows() -> [AssetRow] { Assets.load(store) }
    func row(_ id: String) -> AssetRow { rows().first { $0.id == id } ?? { XCTFail("no row \(id): \(rows().map { $0.id })"); return AssetRow(id: id, type: "none") }() }

    func png(_ name: String, _ w: Int, _ h: Int, copyright: String? = nil) -> URL {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let u = inbox.appendingPathComponent(name)
        if let c = copyright, let cg = rep.cgImage, let d = CGImageDestinationCreateWithURL(u as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(d, cg, [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCopyright: c]] as CFDictionary); CGImageDestinationFinalize(d)
        } else { try? rep.representation(using: .png, properties: [:])!.write(to: u) }
        return u
    }
    func plain(_ name: String, _ text: String = "x") -> URL { let u = inbox.appendingPathComponent(name); try? text.write(to: u, atomically: true, encoding: .utf8); return u }

    /// A small sfnt with a name table (family, optional licence text) and an OS/2 table with the given fsType.
    func sfnt(family: String, fsType: Int, licence: String? = nil) -> Data {
        func b16(_ v: Int) -> [UInt8] { [UInt8(v >> 8 & 255), UInt8(v & 255)] }
        func b32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)] }
        func u16(_ s: String) -> [UInt8] { Array(s.utf16).flatMap { b16(Int($0)) } }
        var recs: [(Int, [UInt8])] = [(1, u16(family)), (2, u16("Regular"))]
        if let l = licence { recs.append((13, u16(l))) }
        var name: [UInt8] = b16(0) + b16(recs.count) + b16(6 + 12 * recs.count)
        var strings: [UInt8] = []
        for (id, s) in recs { name += b16(3) + b16(1) + b16(0x409) + b16(id) + b16(s.count) + b16(strings.count); strings += s }
        name += strings
        var os2 = [UInt8](repeating: 0, count: 64); os2[4] = 1; os2[5] = 0x90; os2[8] = UInt8(fsType >> 8); os2[9] = UInt8(fsType & 255)
        var tables: [(String, [UInt8])] = [("OS/2", os2), ("name", name)]
        tables.sort { $0.0 < $1.0 }
        var out: [UInt8] = b32(0x00010000) + b16(tables.count) + b16(0) + b16(0) + b16(0)
        var off = 12 + 16 * tables.count
        for (tag, d) in tables { out += Array(tag.utf8) + b32(0) + b32(off) + b32(d.count); off += d.count }
        for (_, d) in tables { out += d }
        return Data(out)
    }
    func font(_ name: String, family: String, fsType: Int = 0, licence: String? = nil) -> URL { let u = inbox.appendingPathComponent(name); try? sfnt(family: family, fsType: fsType, licence: licence).write(to: u); return u }

    // MARK: groups and states from the manifest

    func testAnExistingManifestReadsAsTheFourStatesAndNothingIsRewritten() throws {
        let manifest = """
        id,file,original,origin,type,status,licence_note,scene,notes
        logo-01,prepared/logo-01-a.svg,a.svg,prepared,logo,approved,,,
        logo-02,prepared/logo-02-b.svg,b.svg,prepared,logo,approved,,"S01",
        shot-01,prepared/shot-01-c.png,c.png,prepared,shot,proposed,,"S02",the AI suggests it for the second scene
        shot-02,,d.png,source,shot,excluded,,,
        shot-03,,e.png,source,shot,hold,,,low resolution (under 800x450): replace, accept or exclude
        logo-03,prepared/logo-03-f.svg,f.svg,prepared,logo,placeholder,,,
        audio-01,prepared/audio-01-t.mp3,t.mp3,prepared,audio,approved,,,
        sfx-01,prepared/sfx-01-s.wav,s.wav,prepared,sfx,approved,,,
        font-01,fonts/fredoka/Fredoka-Bold.ttf,,fonts,font,approved,SIL Open Font License 1.1,,
        doc-01,,notes.pdf,source,doc,approved,,,not embedded
        """
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try manifest.write(to: dir.appendingPathComponent("assets/MANIFEST.csv"), atomically: true, encoding: .utf8)
        let before = try Data(contentsOf: dir.appendingPathComponent("assets/MANIFEST.csv"))
        let f = file
        func s(_ id: String) -> ResourceState { row(id).state(in: f) }
        XCTAssertEqual(s("logo-01"), .available, "approved, in no scene")
        XCTAssertEqual(s("logo-02"), .used(["S01"]), "approved and linked: one tag per scene")
        XCTAssertEqual(s("shot-01"), .proposal); XCTAssertEqual(s("shot-02"), .declined); XCTAssertEqual(s("shot-03"), .needsAttention)
        XCTAssertEqual(s("logo-03"), .available, "a placeholder is approved under the hood"); XCTAssertEqual(Resources.tags(of: row("logo-03"), in: f), ["placeholder"], "and shows as the tag")
        XCTAssertEqual(row("logo-03").status, "placeholder", "the manifest stays faithful: the skill's release gate reads it as before")
        XCTAssertEqual(ResourceState.used(["S01", "S07"]).title, "Used in S01, S07")
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("assets/MANIFEST.csv")), before, "reading changes nothing")
        // the groups: by type, then by state; empty ones are not listed; Declined starts folded
        let sec = Resources.sections(rows(), file: f)
        XCTAssertEqual(sec.map { $0.group }, [.images, .sounds, .music, .fonts, .other])
        XCTAssertEqual(sec[0].subs.map { $0.key }, ["images.attention", "images.proposal", "images.used", "images.available", "images.declined"])
        XCTAssertTrue(sec[0].subs.first { $0.key == "images.declined" }!.folded); XCTAssertFalse(sec[0].subs.first { $0.key == "images.used" }!.folded)
        XCTAssertEqual(sec[1].subs.flatMap { $0.rows.map { $0.id } }, ["sfx-01"]); XCTAssertEqual(ResourceGroup.of("voice"), .sounds); XCTAssertEqual(ResourceGroup.of("audio"), .music); XCTAssertEqual(ResourceGroup.of("font"), .fonts)
        XCTAssertEqual(sec[3].subs.flatMap { $0.rows.map { $0.id } }, ["font-01"], "fonts are a group of their own")
        // used-in comes from the content as well
        try store.apply(.content(scene: "S02", .add(ContentEdit(type: "image", resource: "logo-01"), after: nil)))
        XCTAssertEqual(row("logo-01").state(in: file), .used(["S02"]))
    }

    func testFoldingIsRememberedPerProject() throws {
        XCTAssertTrue(Resources.isFolded("images.declined", memory: nil)); XCTAssertFalse(Resources.isFolded("images", memory: nil))
        var m = Resources.toggled("images", memory: nil); XCTAssertTrue(Resources.isFolded("images", memory: m))
        m = Resources.toggled("images.declined", memory: m); XCTAssertFalse(Resources.isFolded("images.declined", memory: m), "a folded-by-default group can be opened")
        var s = store.settings; s.collapsed = m; store.settings = s
        let again = ProjectStore(root: dir).settings.collapsed
        XCTAssertTrue(Resources.isFolded("images", memory: again)); XCTAssertFalse(Resources.isFolded("images.declined", memory: again))
        m = Resources.toggled("images", memory: m); XCTAssertFalse(Resources.isFolded("images", memory: m), "and closed again")
    }

    // MARK: tags

    func testTagsAreTypedUndoableAndFilterTheList() throws {
        try Assets.add([plain("Acme Logo.svg", "<svg/>"), plain("Wall.svg", "<svg/>")], to: store)
        try store.apply(.resource(.addTag(id: "logo-01", tag: "Logo")))
        try store.apply(.resource(.addTag(id: "logo-01", tag: "brand")))
        try store.apply(.resource(.addTag(id: "illus-01", tag: "wallpaper")))
        XCTAssertEqual(file.resourceTags?["logo-01"], ["logo", "brand"], "stored in showreel.json, lower case")
        XCTAssertEqual(Resources.allTags(rows(), in: file), ["brand", "logo", "wallpaper"])
        let only = Resources.sections(rows(), file: file, tag: "wallpaper").flatMap { $0.subs.flatMap { $0.rows.map { $0.id } } }
        XCTAssertEqual(only, ["illus-01"], "the list filters by tag")
        XCTAssertEqual(store.journal.entries().filter { $0.op == "resource" && $0.state == "applied" }.count, 3)
        XCTAssertThrowsError(try store.apply(.resource(.addTag(id: "logo-01", tag: "logo")))) { XCTAssertTrue($0.localizedDescription.contains("already has")) }
        XCTAssertThrowsError(try store.apply(.resource(.addTag(id: "logo-01", tag: "a,b")))); XCTAssertThrowsError(try store.apply(.resource(.addTag(id: "nope-09", tag: "x"))))
        XCTAssertThrowsError(try store.apply(.resource(.removeTag(id: "logo-01", tag: "wallpaper"))))
        try store.apply(.resource(.renameTag(from: "logo", to: "mark")))
        XCTAssertEqual(file.resourceTags?["logo-01"], ["mark", "brand"], "renamed where it stood")
        try store.apply(.resource(.removeTag(id: "logo-01", tag: "brand")))
        XCTAssertEqual(file.resourceTags?["logo-01"], ["mark"])
        // persistence and the unknown keys of the file
        var raw = try XCTUnwrap(store.read("showreel.json")); raw = raw.replacingOccurrences(of: "\"name\"", with: "\"someFutureKey\": {\"a\": 1},\n  \"name\"")
        try raw.write(to: dir.appendingPathComponent("showreel.json"), atomically: true, encoding: .utf8)
        try store.apply(.resource(.addTag(id: "illus-01", tag: "second")))
        let text = try XCTUnwrap(store.read("showreel.json"))
        XCTAssertTrue(text.contains("someFutureKey") && text.contains("resourceTags")); XCTAssertEqual(ProjectStore(root: dir).loadShowreel()?.resourceTags?["illus-01"], ["wallpaper", "second"])
        // undo and redo
        try store.undo(); XCTAssertEqual(file.resourceTags?["illus-01"], ["wallpaper"]); try store.redo(); XCTAssertEqual(file.resourceTags?["illus-01"], ["wallpaper", "second"])
        try store.undo(); XCTAssertEqual(file.resourceTags?["illus-01"], ["wallpaper"])
    }

    func testThePlaceholderTagIsTheManifestStatusAndTheGateStillSeesIt() throws {
        try Assets.add([plain("Acme Logo.svg", "<svg/>")], to: store)
        try store.apply(.resource(.addTag(id: "logo-01", tag: "placeholder")))
        XCTAssertEqual(row("logo-01").status, "placeholder", "the skill's manifest is faithful"); XCTAssertNil(file.resourceTags, "not duplicated in showreel.json")
        XCTAssertTrue(store.read("brief.md")?.contains("placeholder") == true || rows().contains { $0.status == "placeholder" })
        XCTAssertEqual(Resources.tags(of: row("logo-01"), in: file), ["placeholder"]); XCTAssertEqual(row("logo-01").state(in: file), .available)
        XCTAssertThrowsError(try store.apply(.resource(.renameTag(from: "placeholder", to: "stand-in"))))
        try store.apply(.resource(.removeTag(id: "logo-01", tag: "placeholder")))
        XCTAssertEqual(row("logo-01").status, "approved")
        try store.apply(.asset(id: "logo-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        XCTAssertThrowsError(try store.apply(.resource(.addTag(id: "logo-01", tag: "placeholder"))), "a declined resource is not a stand-in")
    }

    // MARK: the automatic checks

    func flags(_ url: URL, type: String) -> [ResourceChecks.Flag] { ResourceChecks.flags(url, rel: url.lastPathComponent, type: type) }

    func testEachAutomaticCheckAndItsReason() throws {
        XCTAssertEqual(flags(plain("customers-real-data.svg", "<svg/>"), type: "logo").map { $0.kind }, [.sensitive]); XCTAssertTrue(flags(plain("api-key-notes.svg"), type: "logo")[0].reason.contains("real or confidential"))
        XCTAssertEqual(flags(png("app-home.png", 64, 32), type: "shot").map { $0.reason }, ["its resolution is low (64x32, under 800x450)"])
        XCTAssertTrue(flags(png("logo.png", 100, 100), type: "logo")[0].reason.contains("logo is small"))
        XCTAssertTrue(flags(png("big.png", 1200, 700), type: "shot").isEmpty, "a large image with no metadata passes")
        let c = flags(png("photo.jpg", 1200, 700, copyright: "(c) Somebody"), type: "photo")
        XCTAssertEqual(c.map { $0.kind }, [.rights]); XCTAssertTrue(c[0].reason.contains("copyright notice (\"(c) Somebody\")"), c[0].reason)
        let heavy = inbox.appendingPathComponent("big.wav"); try Data(count: 9_000_000).write(to: heavy)
        XCTAssertTrue(flags(heavy, type: "audio")[0].reason.contains("heavy audio"))
        // fonts: the file's own flag, an unknown licence, and a licence the font states itself
        XCTAssertTrue(flags(font("Locked.ttf", family: "Locked", fsType: 2), type: "font")[0].reason.contains("forbids embedding"))
        XCTAssertTrue(flags(font("Mystery.ttf", family: "Mystery"), type: "font")[0].reason.contains("licence is not known"))
        XCTAssertTrue(flags(font("Open.ttf", family: "Open", licence: "This Font Software is licensed under the SIL Open Font License, Version 1.1"), type: "font").isEmpty, "a font that states an open licence itself is not flagged")
        XCTAssertEqual(FontInfo.read(font("Open2.ttf", family: "Open2", licence: "SIL Open Font License 1.1"))?.isOpenLicence, true)
    }

    func testAudioTagsAndTheCopyrightAreReadWithNoAI() throws {
        // a WAV with an info dictionary, written with the system's own API
        let u = inbox.appendingPathComponent("tagged.caf")
        var fmt = AudioStreamBasicDescription(mSampleRate: 8000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked, mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var af: AudioFileID?
        guard AudioFileCreateWithURL(u as CFURL, kAudioFileCAFType, &fmt, .eraseFile, &af) == noErr, let f = af else { throw XCTSkip("the system could not make a test sound file") }
        var n: UInt32 = 16000; var bytes = [UInt8](repeating: 0, count: 16000)
        AudioFileWriteBytes(f, false, 0, &n, &bytes)
        var info: CFDictionary = ["title": "Theme", "artist": "A. Artist", "copyright": "(c) A. Artist"] as CFDictionary
        let st = AudioFileSetProperty(f, kAudioFilePropertyInfoDictionary, UInt32(MemoryLayout<CFDictionary>.size), &info); AudioFileClose(f)
        guard st == noErr else { throw XCTSkip("the system would not write tags in a WAV") }
        let m = try XCTUnwrap(AudioMetadata.read(u))
        XCTAssertEqual(m.title, "Theme"); XCTAssertEqual(m.artist, "A. Artist"); XCTAssertEqual(m.copyright, "(c) A. Artist"); XCTAssertNotNil(m.duration)
        let wav = inbox.appendingPathComponent("tagged.wav"); try FileManager.default.copyItem(at: u, to: wav)       // the check reads what the system API reads, whatever the extension
        XCTAssertEqual(flags(wav, type: "audio").map { $0.kind }, [.rights], "a copyright field in the tags is flagged")
        XCTAssertNil(AudioMetadata.read(plain("not-audio.mp3")))
    }

    // MARK: adding, Needs attention, and what settles it

    func testAFlaggedFileStaysInSourceNeedsAttentionAndSaysWhy() throws {
        let added = try Assets.add([png("app-home.png", 64, 32), png("plain.png", 1200, 700), plain("Acme Logo.svg", "<svg/>")], to: store)
        XCTAssertEqual(added.map { $0.status }, ["hold", "approved", "approved"], "a clean file is available at once")
        let h = row("shot-01")
        XCTAssertEqual(h.file, "", "no prepared copy"); XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/source/app-home.png").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/prepared/shot-01-app-home.png").path))
        XCTAssertEqual(h.state(in: file), .needsAttention)
        let a = ResourceAttention.of(h, store: store)
        XCTAssertEqual(a.reasons, ["its resolution is low (64x32, under 800x450)"]); XCTAssertTrue(a.canAcceptRisk); XCTAssertFalse(a.asksRights); XCTAssertFalse(a.mustReplace)
        XCTAssertFalse(rows().contains { $0.status == "proposed" }, "nothing waits for an approval any more")
    }

    func testAcceptingARiskNeedsAReasonAndRightsNeedAnAnswerEachChoiceIncludingUnknown() throws {
        try Assets.add([png("app-home.png", 64, 32), png("photo.jpg", 1200, 700, copyright: "(c) X"), png("photo2.jpg", 1200, 700, copyright: "(c) Y")], to: store)
        // a risk: refused without a reason, accepted with one
        XCTAssertThrowsError(try store.apply(.asset(id: "shot-01", status: .approved, note: nil, licence: nil, scenes: nil))) { XCTAssertTrue($0.localizedDescription.contains("accept the risk")) }
        XCTAssertThrowsError(try store.apply(.asset(id: "shot-01", status: .approved, note: "ok", licence: nil, scenes: nil)), "the reason says accepted")
        try store.apply(.asset(id: "shot-01", status: .approved, note: "accepted: it is a stand-in", licence: nil, scenes: nil))
        XCTAssertEqual(row("shot-01").status, "approved"); XCTAssertTrue(row("shot-01").file.hasPrefix("prepared/")); XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/" + row("shot-01").file).path))
        // rights: the question is asked because of the copyright field
        XCTAssertTrue(ResourceAttention.of(row("photo-01"), store: store).asksRights); XCTAssertFalse(ResourceAttention.of(row("photo-01"), store: store).canAcceptRisk)
        XCTAssertThrowsError(try store.apply(.asset(id: "photo-01", status: .approved, note: nil, licence: nil, scenes: nil)), "no answer, no approval")
        try store.apply(RightsAnswer.unknown.operation(id: "photo-01", detail: "found it online"))
        XCTAssertEqual(row("photo-01").status, "hold", "unknown keeps it on Needs attention"); XCTAssertEqual(row("photo-01").licenceNote, "unknown: found it online")
        XCTAssertThrowsError(try store.apply(.asset(id: "photo-01", status: .approved, note: nil, licence: "unknown", scenes: nil)))
        XCTAssertEqual(RightsAnswer.allCases.map { $0.rawValue }, ["own work", "supplied by the client", "licensed", "free licence", "unknown"])
        try store.apply(RightsAnswer.licensed.operation(id: "photo-01", detail: "invoice 12"))
        XCTAssertEqual(row("photo-01").status, "approved"); XCTAssertEqual(row("photo-01").licenceNote, "licensed: invoice 12"); XCTAssertTrue(row("photo-01").file.hasPrefix("prepared/"))
        for (i, a) in [RightsAnswer.ownWork, .client, .free].enumerated() {
            let id = "photo-02"
            if i == 0 { XCTAssertEqual(row(id).status, "hold") }
            try store.apply(RightsAnswer.unknown.operation(id: id, detail: ""))
            try store.apply(a.operation(id: id, detail: ""))
            XCTAssertEqual(row(id).status, "approved", a.rawValue); XCTAssertEqual(row(id).licenceNote, a.rawValue)
            try store.apply(.asset(id: id, status: .hold, note: "back to attention for the next answer", licence: "", scenes: nil))
        }
    }

    func testANameThatSuggestsRealDataIsNeverAcceptedOnlyReplaced() throws {
        try Assets.add([plain("customer-real-data-logo.svg", "<svg/>")], to: store)
        let r = row("logo-01"); XCTAssertEqual(r.status, "hold")
        XCTAssertTrue(ResourceAttention.of(r, store: store).mustReplace)
        XCTAssertThrowsError(try store.apply(.asset(id: "logo-01", status: .approved, note: "accepted: yes", licence: "own work", scenes: nil)))
        // replacing the file runs the checks again: a clean one becomes available
        try store.apply(.resource(.replaceFile(id: "logo-01", url: plain("Acme Logo.svg", "<svg/>"))))
        let n = row("logo-01"); XCTAssertEqual(n.status, "approved"); XCTAssertEqual(n.original, "Acme Logo.svg"); XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("assets/" + n.file).path))
        try store.undo(); XCTAssertEqual(row("logo-01").status, "hold", "the replacement is one undo step"); XCTAssertEqual(row("logo-01").original, "customer-real-data-logo.svg")
        // a replacement that is itself flagged still needs attention, and a file of another kind is refused
        try store.apply(.resource(.replaceFile(id: "logo-01", url: plain("another-secret-logo.svg", "<svg/>"))))
        XCTAssertEqual(row("logo-01").status, "hold")
        XCTAssertThrowsError(try store.plan(.resource(.replaceFile(id: "logo-01", url: plain("theme.mp3")))))
    }

    // MARK: a flagged file is out of Clap's sight and out of the build

    func testAFlaggedFileIsNeverShownToClapNorReadNorChangedAndTheBuildRefusesIt() async throws {
        try Assets.add([png("app-home.png", 64, 32), png("fine.png", 1200, 700)], to: store)
        let ui = ScriptedUI(); let tools = Tools(project: dir, skill: try XCTUnwrap(Skill.root()), ui: ui)
        let state = await tools.run("get_state", [:]).text
        XCTAssertFalse(state.contains("app-home") || state.contains("shot-01"), "not in the state, not even by name"); XCTAssertTrue(state.contains("shot-02") || state.contains("fine.png"))
        XCTAssertTrue(state.contains("needing the user's attention") || state.contains("assetsNeedingTheUsersAttention"))
        let read = await tools.run("read_file", ["path": "assets/source/app-home.png"]).text
        XCTAssertTrue(read.hasPrefix("refused:") && read.contains("needs the user's attention"), read)
        for (name, input) in [("update_asset", ["id": "shot-01", "status": "approved"]), ("tag_resource", ["id": "shot-01", "add": ["logo"]])] as [(String, [String: Any])] {
            let r = await tools.run(name, input).text; XCTAssertTrue(r.hasPrefix("refused:") && r.contains("needs the user's attention"), "\(name): \(r)")
        }
        XCTAssertTrue(ui.cards.isEmpty); XCTAssertEqual(row("shot-01").status, "hold")
        XCTAssertFalse(try XCTUnwrap(store.read("brief.md")).contains("app-home"), "not in the brief Clap reads")
        // the build: held files are said, never in prepared, and build.py refuses one that a project.json points at
        XCTAssertTrue(BuildRunner.readiness(store).contains { $0.id == "build.held" })
        let v = dir.appendingPathComponent("v1"); try FileManager.default.createDirectory(at: v, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("assets/prepared"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: dir.appendingPathComponent("assets/source/app-home.png"), to: dir.appendingPathComponent("assets/prepared/shot-01-app-home.png"))   // someone put it there by hand
        var m = rows(); m[m.firstIndex { $0.id == "shot-01" }!].file = "prepared/shot-01-app-home.png"; try Assets.save(m, store)
        try "{\"title\": \"T\", \"main\": \"main.js\", \"duration\": 4, \"fonts\": [], \"tokens\": {}, \"images\": {\"shot\": \"../assets/prepared/shot-01-app-home.png\"}}".write(to: v.appendingPathComponent("project.json"), atomically: true, encoding: .utf8)
        try "window.SHOWREEL = {};".write(to: v.appendingPathComponent("main.js"), atomically: true, encoding: .utf8)
        let b = await Shell.run("python3 '\(try XCTUnwrap(Skill.root()).path)/scripts/build.py' '\(v.path)'", in: dir, timeout: 60)
        XCTAssertNotEqual(b?.status, 0); XCTAssertTrue((b?.err ?? "").contains("hold") || (b?.out ?? "").contains("hold"), (b?.err ?? "") + (b?.out ?? ""))
    }

    // MARK: fonts

    func testAFontFromTheCardIsKnownAndAHandDroppedOneIsAskedAbout() async throws {
        let src = FakeFontSource()
        try store.apply(.decisions([DecisionChange(.textFont, "Fredoka")], title: nil))
        let o = try FontFiles.offer("Fredoka", store: store)
        try store.apply(.addFontFiles(try await FontFiles.fetch(o, source: src)))
        let carded = rows().first { $0.type == "font" }!
        XCTAssertEqual(carded.status, "approved"); XCTAssertTrue(carded.licenceNote.contains("SIL Open Font License")); XCTAssertEqual(carded.state(in: file), .available, "no question: the card approved it")
        XCTAssertTrue(ResourceAttention.of(carded, store: store).isEmpty)
        // dropped by hand: unknown licence, restricted flag, and a licence the font states itself
        try Assets.add([font("Mystery.ttf", family: "Mystery"), font("Locked.ttf", family: "Locked", fsType: 2), font("Stated.ttf", family: "Stated", licence: "SIL Open Font License 1.1")], to: store)
        let mystery = row("font-02"), locked = row("font-03"), stated = row("font-04")
        XCTAssertEqual(mystery.status, "hold"); XCTAssertTrue(ResourceAttention.of(mystery, store: store).asksRights)
        XCTAssertEqual(locked.status, "hold"); XCTAssertTrue(ResourceAttention.of(locked, store: store).reasons[0].contains("forbids embedding"))
        XCTAssertEqual(stated.status, "approved", "the font says its own open licence: nothing to ask"); XCTAssertTrue(stated.licenceNote.contains("open licence"))
        // the answer to the rights question is the licence note the approval needed
        XCTAssertThrowsError(try store.apply(.asset(id: "font-02", status: .approved, note: nil, licence: nil, scenes: nil)))
        try store.apply(RightsAnswer.free.operation(id: "font-02", detail: "OFL"))
        XCTAssertEqual(row("font-02").status, "approved"); XCTAssertTrue(row("font-02").file.hasPrefix("prepared/"))
    }

    // MARK: the centre of the viewer, and the freeze

    func testWhatTheCentreShowsByOneRule() {
        typealias S = Resources.ViewerSubject
        XCTAssertEqual(Resources.viewerSubject(designBoardOpen: true, resourcesTab: true, selectedResource: "logo-01"), S.designBoard, "the design system while the look is edited, whatever is selected")
        XCTAssertEqual(Resources.viewerSubject(designBoardOpen: false, resourcesTab: true, selectedResource: "logo-01"), S.resource("logo-01"))
        XCTAssertEqual(Resources.viewerSubject(designBoardOpen: false, resourcesTab: false, selectedResource: "logo-01"), S.film, "a resource selected elsewhere does not take the centre")
        XCTAssertEqual(Resources.viewerSubject(designBoardOpen: false, resourcesTab: true, selectedResource: nil), S.film)
        XCTAssertEqual(Resources.viewerSubject(designBoardOpen: true, resourcesTab: false, selectedResource: nil), S.designBoard)
    }

    func testFrozenDuringABuildAndAGeneration() throws {
        try Assets.add([plain("Acme Logo.svg", "<svg/>")], to: store)
        for phase in [ProjectActivity.Build.Phase.generating, .testing] {
            store.activity.update { $0.build = .init(version: "v1", phase: phase) }
            XCTAssertThrowsError(try store.apply(.resource(.addTag(id: "logo-01", tag: "logo")))) { XCTAssertEqual($0.localizedDescription, Reasons.building.message) }
            XCTAssertThrowsError(try store.apply(.asset(id: "logo-01", status: .excluded, note: nil, licence: nil, scenes: nil)))
        }
        XCTAssertEqual(rows().count, 1)
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        XCTAssertThrowsError(try store.transaction("Add files") { _ = try Assets.add([plain("Third.svg", "<svg/>")], to: store) }); XCTAssertEqual(rows().count, 1)
        store.activity.reset()
        XCTAssertNoThrow(try store.apply(.resource(.addTag(id: "logo-01", tag: "logo"))))
    }

    // MARK: a declined proposal is not proposed again

    func testAProposalIsApprovedOrDeclinedAndADeclinedOneIsKeptAsDeclined() throws {
        try Assets.add([plain("Acme Logo.svg", "<svg/>"), plain("Other.svg", "<svg/>")], to: store)
        try store.apply(.asset(id: "logo-01", status: .proposed, note: "the AI suggests it for S02", licence: nil, scenes: "S02"))
        XCTAssertEqual(row("logo-01").state(in: file), .proposal)
        try store.apply(.asset(id: "logo-01", status: .approved, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(row("logo-01").state(in: file), .used(["S02"]), "approving linked it to the scene it was proposed for")
        try store.apply(.asset(id: "illus-01", status: .proposed, note: "maybe for S01", licence: nil, scenes: "S01"))
        try store.apply(.asset(id: "illus-01", status: .excluded, note: nil, licence: nil, scenes: nil))
        XCTAssertEqual(row("illus-01").state(in: file), .declined); XCTAssertTrue(Resources.isFolded("images.declined", memory: nil), "the Declined group is folded")
        XCTAssertEqual(row("illus-01").status, "excluded", "in the manifest: Clap's state still lists it, as declined, so that it is not proposed again")
    }
}
