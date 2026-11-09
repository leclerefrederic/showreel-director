import AppKit
import XCTest
@testable import ShowreelKit

/// PK1: design packages. The `.studiopack` format (round trip, hash, integrity, the security of the archive), the library, saving a package from a project, starting a project
/// from one (rights confirmed or not, the automatic checks of the Resources block still applying), and the Wizard asking only what a package leaves open.
final class PackageTests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var libDir: URL!
    var store: ProjectStore!
    var lib: PackageLibrary!
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        dir = makeTempDir("pk-project"); inbox = makeTempDir("pk-in"); libDir = makeTempDir("pk-lib")
        store = ProjectStore(root: dir); lib = PackageLibrary(root: libDir)
        try? store.create(name: "Brand", conversationLanguage: "en", reelLanguages: ["en", "fr"])
        var f = store.loadShowreel()!
        f.decisions.palette = ["#101820", "#F2AA4C", "#FFFFFF"]
        f.decisions.fonts = .init(titles: "Fredoka", text: "Inter")
        f.decisions.background = .init(id: "aurora", mood: "calm")
        f.decisions.moods = ["calm"]; f.decisions.effectsPack = "glass"; f.decisions.formats = ["16:9"]; f.decisions.duration = 30
        f.parameters.tone = "warm and direct"; f.parameters.controlLevel = "guided"
        try? store.save(f)
        store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); for u in [dir!, inbox!, libDir!] { try? FileManager.default.removeItem(at: u) } }

    // MARK: fixtures

    func png(_ name: String, _ w: Int = 400, _ h: Int = 300, copyright: String? = nil) -> URL {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let u = inbox.appendingPathComponent(name)
        if let c = copyright, let cg = rep.cgImage, let d = CGImageDestinationCreateWithURL(u as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(d, cg, [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCopyright: c]] as CFDictionary); CGImageDestinationFinalize(d)
        } else { try? rep.representation(using: .png, properties: [:])!.write(to: u) }
        return u
    }

    func sfnt(family: String, licence: String?) -> Data {
        func b16(_ v: Int) -> [UInt8] { [UInt8(v >> 8 & 255), UInt8(v & 255)] }
        func b32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)] }
        func u16(_ s: String) -> [UInt8] { Array(s.utf16).flatMap { b16(Int($0)) } }
        var recs: [(Int, [UInt8])] = [(1, u16(family)), (2, u16("Regular"))]
        if let l = licence { recs.append((13, u16(l))) }
        var name: [UInt8] = b16(0) + b16(recs.count) + b16(6 + 12 * recs.count)
        var strings: [UInt8] = []
        for (id, s) in recs { name += b16(3) + b16(1) + b16(0x409) + b16(id) + b16(s.count) + b16(strings.count); strings += s }
        name += strings
        var os2 = [UInt8](repeating: 0, count: 64); os2[4] = 1; os2[5] = 0x90
        var tables: [(String, [UInt8])] = [("OS/2", os2), ("name", name)]
        tables.sort { $0.0 < $1.0 }
        var out: [UInt8] = b32(0x00010000) + b16(tables.count) + b16(0) + b16(0) + b16(0)
        var off = 12 + 16 * tables.count
        for (tag, d) in tables { out += Array(tag.utf8) + b32(0) + b32(off) + b32(d.count); off += d.count }
        for (_, d) in tables { out += d }
        return Data(out)
    }

    /// The project with a logo (rights: supplied by the client, tagged), and an open font added through the card (with its OFL text).
    func fill(_ s: ProjectStore) throws {
        try Assets.add([png("logo.png")], to: s)
        try s.apply(RightsAnswer.client.operation(id: "logo-01", detail: "Acme supplied it"))
        try s.apply(.resource(.addTag(id: "logo-01", tag: "brand")))
        try s.apply(.addFontFiles(FontPayload(family: "Fredoka", dir: "fredoka", files: [FontFile(name: "Fredoka-Regular.ttf", data: sfnt(family: "Fredoka", licence: "SIL Open Font License 1.1")),
                                                                                      FontFile(name: "OFL.txt", data: Data("Copyright 2024 The Fredoka Project Authors. SIL OPEN FONT LICENSE".utf8))])))
    }

    func build(note: String = "", continuing: Bool = false, author: String = "Studio Team", now: Date? = nil, selection: PackageSelection? = nil) throws -> DesignPackage {
        try PackageSave.build(store: store, selection: selection ?? PackageSelection(all: PackageSave.offer(store)), name: "Acme brand", author: author, note: note, continuing: continuing, library: lib, now: now ?? t0)
    }

    func entries(_ p: DesignPackage) throws -> [(name: String, data: Data)] { try PackageZip.read(try p.archiveData()).map { ($0.name, $0.data) } }

    /// A package with one entry changed or removed, rewritten with correct checksums.
    func tampered(_ p: DesignPackage, _ edit: (inout [(name: String, data: Data)]) -> Void) throws -> Data {
        var e = try entries(p)
        edit(&e)
        return try PackageZip.write(e, checkNames: false)
    }

    func put(_ e: inout [(name: String, data: Data)], _ name: String, _ f: (Data) -> Data) { if let i = e.firstIndex(where: { $0.name == name }) { e[i].data = f(e[i].data) } }

    // MARK: the zip itself

    func testCRCOfTheStandardCheckString() { XCTAssertEqual(PackageZip.crc32(Data("123456789".utf8)), 0xCBF43926) }

    func testZipRoundTripAndNames() throws {
        let z = try PackageZip.write([("package.json", Data("{}".utf8)), ("assets/a/b.png", Data([1, 2, 3]))])
        let r = try PackageZip.read(z)
        XCTAssertEqual(r.map { $0.name }, ["package.json", "assets/a/b.png"])
        XCTAssertEqual(r[1].data, Data([1, 2, 3])); XCTAssertTrue(r.allSatisfy { $0.crcOK })
        XCTAssertEqual(try PackageZip.write([("package.json", Data("{}".utf8)), ("assets/a/b.png", Data([1, 2, 3]))]), z, "the same entries give the same bytes")
        for bad in ["../x", "a/../b", "/abs", "C:evil", "a\\b", "a//b", "~root/x", "./x"] { XCTAssertNotNil(PackageZip.nameProblem(bad), bad); XCTAssertThrowsError(try PackageZip.write([(bad, Data())])) }
        XCTAssertNil(PackageZip.nameProblem("assets/logo-01/logo.png"))
    }

    func testAnEntryThatIsNotAZipIsRefused() {
        XCTAssertThrowsError(try PackageReader.read(Data("hello".utf8))) { XCTAssertTrue("\($0)".contains("notAnArchive")) }
        XCTAssertThrowsError(try PackageReader.read(Data(repeating: 0, count: 100)))
    }

    // MARK: the format

    func testARoundTripKeepsTheDesignTheResourcesTheirRightsAndTheFontLicence() throws {
        try fill(store)
        let p = try build(note: "first")
        let url = inbox.appendingPathComponent("brand.studiopack")
        try p.write(to: url)
        let r = try PackageReader.read(url)
        XCTAssertEqual(r.integrity, .matches); XCTAssertEqual(r.package.manifest.hash, r.computedHash)
        XCTAssertEqual(try PackageZip.read(Data(contentsOf: url)).first?.name, "package.json", "the manifest is the first entry")
        let m = r.package.manifest
        XCTAssertEqual(m.name, "Acme brand"); XCTAssertEqual(m.version, "1.0"); XCTAssertEqual(m.author, "Studio Team"); XCTAssertEqual(m.note, "first")
        XCTAssertEqual(m.format, 1); XCTAssertNotNil(UUID(uuidString: m.id)); XCTAssertEqual(m.shortHash.count, 8)
        XCTAssertEqual(r.package.design.look?.palette, ["#101820", "#F2AA4C", "#FFFFFF"]); XCTAssertEqual(r.package.design.look?.titleFont, "Fredoka")
        XCTAssertEqual(r.package.design.look?.background, "aurora"); XCTAssertEqual(r.package.design.tone, "warm and direct")
        XCTAssertEqual(r.package.design.defaults?.formats, ["16:9"]); XCTAssertEqual(r.package.design.defaults?.duration, 30); XCTAssertEqual(r.package.design.defaults?.reelLanguages, ["en", "fr"])
        XCTAssertEqual(r.package.design.defaults?.controlLevel, "guided")
        XCTAssertEqual(r.package.resources.count, 2)
        let logo = try XCTUnwrap(r.package.resources.first { $0.type == "logo" })
        XCTAssertEqual(logo.rightsAnswer, .client); XCTAssertEqual(logo.rightsDetail, "Acme supplied it"); XCTAssertEqual(logo.tags, ["brand"])
        XCTAssertEqual(logo.originalName, "logo.png"); XCTAssertEqual(logo.approvedBy, "Studio Team"); XCTAssertNotNil(logo.approvedAt)
        XCTAssertEqual(logo.fileHash, PackageHash.sha256(r.package.files[logo.file]!))
        let font = try XCTUnwrap(r.package.resources.first { $0.type == "font" })
        XCTAssertTrue(font.openFont, "an open font")
        let lic = try XCTUnwrap(font.licenceFile); XCTAssertTrue(String(decoding: r.package.files[lic]!, as: UTF8.self).contains("OPEN FONT LICENSE"), "the licence text goes with the font")
        XCTAssertFalse(String(decoding: try Data(contentsOf: url), as: UTF8.self).contains(NSHomeDirectory()), "no absolute path of this Mac")
    }

    func testOnlyApprovedResourcesAreOfferedAndAHeldOneIsNot() throws {
        try fill(store)
        try Assets.add([png("copyrighted.png", copyright: "Somebody")], to: store)
        XCTAssertEqual(Assets.load(store).first { $0.original == "copyrighted.png" }?.status, "hold")
        let ids = PackageSave.offer(store).resources.map { $0.row.original.isEmpty ? $0.row.file : $0.row.original }
        XCTAssertFalse(ids.contains("copyrighted.png")); XCTAssertEqual(PackageSave.offer(store).resources.count, 2)
    }

    func testTheChoiceDecidesWhatGoesIn() throws {
        try fill(store)
        var sel = PackageSelection(all: PackageSave.offer(store)); sel.look = false; sel.tone = false; sel.resources = ["logo-01"]
        let p = try build(selection: sel)
        XCTAssertNil(p.design.look); XCTAssertNil(p.design.tone); XCTAssertNotNil(p.design.defaults); XCTAssertEqual(p.resources.map { $0.id }, ["logo-01"])
        XCTAssertThrowsError(try build(selection: PackageSelection(look: false, motion: false, tone: false, defaults: false, resources: [])), "nothing chosen")
    }

    func testTheMotionComesFromTheMasterMontageWhenThereIsOne() throws {
        XCTAssertNil(PackageSave.offer(store).motion, "a project without transitions has none to offer")
        var f = store.loadShowreel()!
        f.storyboards[0].items = [.init(scene: "S01", transition: .init(type: "fade", duration: 0.6)), .init(scene: "S02", transition: .init(type: "fade", duration: 0.6)), .init(scene: "S03", transition: .init(type: "wipe", duration: 1))]
        try store.save(f)
        XCTAssertEqual(PackageSave.offer(store).motion, PackageDesign.Motion(defaultTransition: "fade", duration: 0.6))
    }

    // MARK: the hash

    func testTheHashIgnoresDatesAndKeyOrderAndFollowsContent() throws {
        try fill(store)
        let a = try build(now: t0), b = try build(now: t0.addingTimeInterval(86_400 * 40))
        XCTAssertNotEqual(a.manifest.modified, b.manifest.modified)
        XCTAssertEqual(a.manifest.hash, a.manifest.hash.lowercased()); XCTAssertEqual(a.manifest.hash.count, 64)
        // ids differ between the two (a new package each time), but the hash covers the content only
        XCTAssertEqual(a.manifest.hash, b.manifest.hash, "a save without a change gives the same hash, whatever the dates")
        // the same design with its keys in another order and another layout
        let r = try PackageReader.read(try tampered(a) { e in put(&e, "design.json") { d in
            let o = try! JSONSerialization.jsonObject(with: d) as! [String: Any]
            let parts = o.keys.sorted(by: >).map { "\"\($0)\":" + String(decoding: try! JSONSerialization.data(withJSONObject: o[$0]!, options: [.fragmentsAllowed]), as: UTF8.self) }
            return Data(("{" + parts.joined(separator: ",") + "}").utf8) } })
        XCTAssertEqual(r.integrity, .matches, "the order of the keys does not matter")
        // a changed value in design.json
        let m = try PackageReader.read(try tampered(a) { e in put(&e, "design.json") { Data(String(decoding: $0, as: UTF8.self).replacingOccurrences(of: "warm and direct", with: "warm and direcT").utf8) } })
        XCTAssertEqual(m.integrity, .modified); XCTAssertNotEqual(m.computedHash, a.manifest.hash)
        var changedTone = try build(); changedTone.design.tone = "cold"; XCTAssertNotEqual(try changedTone.computeHash(), a.manifest.hash)
    }

    func testOneChangedByteInAFileIsDetectedAsDamage() throws {
        try fill(store)
        let a = try build()
        let r = try PackageReader.read(try tampered(a) { e in put(&e, a.resources.first { $0.type == "logo" }!.file) { var d = $0; d[d.count / 2] ^= 0x01; return d } })
        XCTAssertEqual(r.integrity, .damaged); XCTAssertNotEqual(r.computedHash, a.manifest.hash); XCTAssertFalse(r.problems.isEmpty)
    }

    func testAByteFlippedInTheArchiveFailsItsChecksum() throws {
        try fill(store)
        var raw = try build().archiveData()
        let needle = Data("warm and direct".utf8)
        let at = try XCTUnwrap(raw.range(of: needle)?.lowerBound)
        raw[at] ^= 0x01
        let r = try PackageReader.read(raw)
        XCTAssertEqual(r.integrity, .damaged); XCTAssertTrue(r.problems.contains { $0.contains("checksum") })
    }

    func testAHashEditedInThePackageIsNotBelieved() throws {
        try fill(store)
        let a = try build()
        var m = a.manifest; m.hash = String(repeating: "0", count: 64)
        let r = try PackageReader.read(try tampered(a) { e in put(&e, "package.json") { _ in try! DesignPackage.encoder().encode(m) } })
        XCTAssertEqual(r.integrity, .modified); XCTAssertEqual(r.computedHash, a.manifest.hash)
        XCTAssertTrue(r.integrity.needsDecision); XCTAssertFalse(PackageIntegrity.matches.needsDecision)
    }

    // MARK: the security of the archive

    func entry(_ name: String, _ data: Data = Data("x".utf8)) -> (name: String, data: Data) { (name, data) }

    /// A valid package's entries plus extra ones, as an archive (names unchecked: it is how a hostile file is made).
    func hostile(_ extra: [(name: String, data: Data)], limits: PackageLimits? = nil) throws -> Data {
        var p = try build(); try p.seal()
        return try PackageZip.write(try entries(p) + extra, checkNames: false)
    }

    func testNamesThatLeaveTheFolderAreRefusedBeforeAnythingIsRead() throws {
        try fill(store)
        for bad in ["../evil.txt", "assets/../../evil.txt", "/etc/passwd", "assets/a\\b.txt", "C:/x.txt", "assets//a.txt"] {
            XCTAssertThrowsError(try PackageReader.read(try hostile([entry(bad)])), bad) { XCTAssertTrue("\($0)".contains("unsafe"), "\(bad): \($0)") }
        }
    }

    func testASymbolicLinkIsRefused() throws {
        try fill(store)
        var z = try hostile([entry("assets/link.png", Data("target".utf8))])
        // mark the last entry as a symbolic link (Unix mode 0120777 in the high bits of the external attributes)
        var at = -1
        for i in 0..<(z.count - 4) where z[i] == 0x50 && z[i + 1] == 0x4B && z[i + 2] == 0x01 && z[i + 3] == 0x02 { at = i }
        XCTAssertGreaterThan(at, 0)
        let mode: UInt32 = 0o120777 << 16
        for k in 0..<4 { z[at + 38 + k] = UInt8((mode >> (8 * UInt32(k))) & 0xFF) }
        XCTAssertThrowsError(try PackageReader.read(z)) { XCTAssertTrue("\($0)".contains("symbolic link"), "\($0)") }
    }

    func testLimitsOnEntriesTotalAndFileSize() throws {
        try fill(store)
        let p = try build()
        let z = try p.archiveData()
        XCTAssertThrowsError(try PackageReader.read(z, limits: PackageLimits(maxEntries: 3, maxFileSize: 40_000_000, maxTotalSize: 150_000_000))) { XCTAssertTrue("\($0)".contains("entries"), "\($0)") }
        XCTAssertThrowsError(try PackageReader.read(z, limits: PackageLimits(maxEntries: 400, maxFileSize: 200, maxTotalSize: 150_000_000))) { XCTAssertTrue("\($0)".contains("one file"), "\($0)") }
        let total = p.files.values.reduce(0) { $0 + $1.count } + 2000
        XCTAssertThrowsError(try PackageReader.read(z, limits: PackageLimits(maxEntries: 400, maxFileSize: 40_000_000, maxTotalSize: total / 2))) { XCTAssertTrue("\($0)".contains("larger than"), "\($0)") }
        XCTAssertNoThrow(try PackageReader.read(z))
    }

    func testOnlyExpectedFileTypesAndNoNestedArchive() throws {
        try fill(store)
        func hostilePackage(_ name: String, _ bytes: Data) throws -> Data {
            var p = try build()
            let id = "logo-extra"
            p.resources.append(PackageResource(id: id, type: "misc", originalName: (name as NSString).lastPathComponent, file: name, fileHash: PackageHash.sha256(bytes)))
            p.files[name] = bytes
            try p.seal()
            return try PackageZip.write(try entries(p), checkNames: false)
        }
        for bad in ["assets/x/run.sh", "assets/x/tool.app", "assets/x/code.js", "assets/x/macro.py", "assets/x/inner.zip", "assets/x/noext"] {
            XCTAssertThrowsError(try PackageReader.read(try hostilePackage(bad, Data("echo".utf8))), bad) { XCTAssertTrue("\($0)".contains("not a kind of file"), "\(bad): \($0)") }
        }
        let inner = try PackageZip.write([("a.txt", Data("a".utf8))])
        XCTAssertThrowsError(try PackageReader.read(try hostilePackage("assets/x/photo.png", inner))) { XCTAssertTrue("\($0)".contains("nested archives"), "\($0)") }
        XCTAssertThrowsError(try PackageReader.read(try hostilePackage("assets/x/photo.png", Data([0x1F, 0x8B, 8, 0, 0, 0])))) { XCTAssertTrue("\($0)".contains("nested archives"), "\($0)") }
        XCTAssertThrowsError(try PackageReader.read(try hostile([entry("notes.txt")])), "an entry outside the package's layout") { XCTAssertTrue("\($0)".contains("not part of a package"), "\($0)") }
        XCTAssertThrowsError(try PackageReader.read(try hostile([entry("assets/orphan/a.txt")])), "a file resources.json does not describe") { XCTAssertTrue("\($0)".contains("not described"), "\($0)") }
    }

    func testThePackageJSONMustBeFirstAndTheFormatNotNewer() throws {
        try fill(store)
        let p = try build()
        var e = try entries(p); e.swapAt(0, 1)
        XCTAssertThrowsError(try PackageReader.read(try PackageZip.write(e))) { XCTAssertTrue("\($0)".contains("first entry"), "\($0)") }
        var m = p.manifest; m.format = 99
        XCTAssertThrowsError(try PackageReader.read(try tampered(p) { e in put(&e, "package.json") { _ in try! DesignPackage.encoder().encode(m) } })) { XCTAssertTrue("\($0)".contains("newer version"), "\($0)") }
        var n = p.manifest; n.appMinVersion = "99.0"
        XCTAssertTrue(try PackageReader.read(try tampered(p) { e in put(&e, "package.json") { _ in try! DesignPackage.encoder().encode(n) } }).needsNewerApp || AppInfo.version == "unknown")
    }

    func testAnArchiveMadeByTheSystemZipToolWithDeflateIsRead() throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/zip") else { throw XCTSkip("no zip tool") }
        try fill(store)
        let p = try build(note: "deflated")
        let work = makeTempDir("pk-zip"); defer { try? FileManager.default.removeItem(at: work) }
        for e in try entries(p) {
            let u = work.appendingPathComponent(e.name)
            try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try e.data.write(to: u)
        }
        let out = inbox.appendingPathComponent("system.studiopack")
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/zip"); task.currentDirectoryURL = work
        task.arguments = ["-q", "-X", out.path] + (try entries(p)).map { $0.name }
        try task.run(); task.waitUntilExit()
        let r = try PackageReader.read(out)
        XCTAssertEqual(r.integrity, .matches); XCTAssertEqual(r.package.manifest.note, "deflated"); XCTAssertEqual(r.package.files, p.files)
    }

    // MARK: the author

    func testAnEmailLikeAuthorIsRefusedEverywhere() throws {
        for bad in ["jane@acme.com", "Jane <jane@acme.com>", "mailto:jane", "j@a", " x@y "] { XCTAssertThrowsError(try PackageAuthor.validate(bad), bad) }
        XCTAssertEqual(try PackageAuthor.validate("  Studio Team "), "Studio Team"); XCTAssertEqual(try PackageAuthor.validate("@jane"), "@jane")
        XCTAssertThrowsError(try PackageAuthor.validate("   ")); XCTAssertThrowsError(try PackageAuthor.validate(String(repeating: "a", count: 81)))
        try fill(store)
        XCTAssertThrowsError(try build(author: "jane@acme.com")) { XCTAssertTrue("\($0)".contains("not an e-mail"), "\($0)") }
        let p = try build()
        var m = p.manifest; m.author = "jane@acme.com"
        XCTAssertThrowsError(try PackageReader.read(try tampered(p) { e in put(&e, "package.json") { _ in try! DesignPackage.encoder().encode(m) } }), "a received package with an e-mail as author")
        XCTAssertFalse(String(decoding: try p.archiveData(), as: UTF8.self).contains(NSUserName() + "@"), "nothing is filled from the system account")
    }

    // MARK: the library

    func testTheLibraryKeepsOneFolderPerIdAndVersionWithItsConfirmation() throws {
        try fill(store)
        let p = try build(note: "a")
        let e = try lib.add(p)
        XCTAssertTrue(e.archive.path.hasPrefix(libDir.path)); XCTAssertTrue(e.archive.path.contains("/\(p.manifest.id)/1.0/"))
        XCTAssertEqual(lib.list().count, 1); XCTAssertFalse(e.isConfirmed)
        XCTAssertEqual(try lib.add(p).manifest.hash, e.manifest.hash, "the same content again changes nothing")
        var other = p; other.design.tone = "cold"
        XCTAssertThrowsError(try lib.add(other)) { XCTAssertTrue("\($0)".contains("new version number"), "\($0)") }
        try lib.confirm(e, by: "Studio Team", now: t0)
        let c = try XCTUnwrap(lib.entry(p.manifest.id, "1.0")?.confirmation)
        XCTAssertEqual(c.by, "Studio Team"); XCTAssertEqual(c.hash, p.manifest.hash); XCTAssertTrue(lib.entry(p.manifest.id, "1.0")!.isConfirmed)
        var v2 = p; v2.manifest.version = "1.1"; v2.design.tone = "cold"
        let e2 = try lib.add(v2)
        XCTAssertFalse(e2.isConfirmed, "the confirmation belongs to a version")
        XCTAssertEqual(lib.latest(p.manifest.id)?.manifest.version, "1.1"); XCTAssertEqual(lib.list().map { $0.manifest.version }, ["1.1", "1.0"])
        XCTAssertEqual(lib.relation(of: p.manifest), "version 1.0 is already installed")
        var v3 = p.manifest; v3.version = "1.2"; XCTAssertEqual(lib.relation(of: v3), "update 1.1 to 1.2")
        var v0 = p.manifest; v0.version = "0.9"; XCTAssertEqual(lib.relation(of: v0), "older than 1.1, which is installed")
        var fresh = p.manifest; fresh.id = UUID().uuidString.lowercased(); XCTAssertNil(lib.relation(of: fresh))
        XCTAssertEqual(lib.entry(p.manifest.id, "1.0")?.manifest.version, "1.0")
    }

    func testVersionNumbers() {
        XCTAssertEqual(PackageVersion.next(after: "1.0"), "1.1"); XCTAssertEqual(PackageVersion.next(after: "1.9"), "1.10"); XCTAssertEqual(PackageVersion.next(after: "2"), "2.1")
        XCTAssertEqual(PackageVersion.compare("1.10", "1.9"), 1); XCTAssertEqual(PackageVersion.compare("1.0", "1"), 0); XCTAssertEqual(PackageVersion.compare("a", "1.0"), -1)
        XCTAssertFalse(PackageVersion.isValid("1.x")); XCTAssertFalse(PackageVersion.isValid("../1"))
    }

    // MARK: a new version of the same package

    func testAProjectFromAPackageSavesANewVersionOfTheSameIdWithAMandatoryNote() throws {
        try fill(store)
        let p = try build(note: "first"); let e = try lib.add(p); try lib.confirm(e, by: nil)
        let dest = ProjectStore(root: makeTempDir("pk-dest")); defer { try? FileManager.default.removeItem(at: dest.root) }
        try dest.create(name: "Film", conversationLanguage: nil, reelLanguages: [])
        try PackageStart.start(e, library: lib, into: dest)
        let f = dest.loadShowreel()!
        XCTAssertEqual(PackageSave.continuation(of: f, library: lib)?.version, "1.1"); XCTAssertEqual(PackageSave.continuation(of: f, library: lib)?.id, p.manifest.id)
        func again(note: String, continuing: Bool = true) throws -> DesignPackage {
            try PackageSave.build(store: dest, selection: PackageSelection(all: PackageSave.offer(dest)), name: "Acme brand", author: "Studio Team", note: note, continuing: continuing, library: lib, now: t0.addingTimeInterval(100))
        }
        XCTAssertThrowsError(try again(note: "  ")) { XCTAssertTrue("\($0)".contains("needs a note"), "\($0)") }
        let v2 = try again(note: "new green")
        XCTAssertEqual(v2.manifest.id, p.manifest.id); XCTAssertEqual(v2.manifest.version, "1.1"); XCTAssertEqual(v2.manifest.created, p.manifest.created)
        try lib.add(v2)
        XCTAssertEqual(PackageSave.continuation(of: f, library: lib)?.version, "1.2", "the number goes up past anything kept")
        let fresh = try again(note: "", continuing: false)
        XCTAssertNotEqual(fresh.manifest.id, p.manifest.id, "a new package when the user chooses so"); XCTAssertEqual(fresh.manifest.version, "1.0")
        XCTAssertThrowsError(try PackageSave.build(store: store, selection: PackageSelection(all: PackageSave.offer(store)), name: "x", author: "A", note: "n", continuing: true, library: lib), "a project that did not start from a package has nothing to continue")
    }

    // MARK: starting a project from a package

    func newProject(_ name: String = "Film", conversation: String? = nil) throws -> ProjectStore {
        let s = ProjectStore(root: makeTempDir("pk-new"))
        try s.create(name: name, conversationLanguage: conversation, reelLanguages: [])
        return s
    }

    func testStartingWithTheRightsConfirmedAppliesTheDesignAndApprovesTheResources() throws {
        try fill(store)
        let e = try lib.add(try build(note: "v1")); try lib.confirm(e, by: "Studio Team", now: t0)
        let dest = try newProject(); defer { try? FileManager.default.removeItem(at: dest.root) }
        var seed = dest.loadShowreel()!; seed.unknown["futureKey"] = .string("kept"); try dest.save(seed)
        let report = try PackageStart.start(lib.entry(e.manifest.id, "1.0")!, library: lib, into: dest, now: t0)
        let f = dest.loadShowreel()!
        XCTAssertEqual(f.decisions.palette, ["#101820", "#F2AA4C", "#FFFFFF"]); XCTAssertEqual(f.decisions.fonts, .init(titles: "Fredoka", text: "Inter"))
        XCTAssertEqual(f.decisions.background, .init(id: "aurora", mood: "calm")); XCTAssertEqual(f.decisions.moods, ["calm"]); XCTAssertEqual(f.decisions.effectsPack, "glass")
        XCTAssertEqual(f.decisions.formats, ["16:9"]); XCTAssertEqual(f.decisions.duration, 30); XCTAssertEqual(f.reelLanguages, ["en", "fr"])
        XCTAssertEqual(f.parameters.tone, "warm and direct"); XCTAssertEqual(f.parameters.controlLevel, "guided")
        XCTAssertNil(f.conversationLanguage, "the conversation language is the user's, not the package's")
        XCTAssertEqual(f.package, ShowreelFile.PackageOrigin(id: e.manifest.id, version: "1.0", hash: e.manifest.hash, appliedAt: PackageLibrary.timestamp(t0)))
        XCTAssertEqual(f.unknown["futureKey"], .string("kept"), "keys the app does not know are preserved")
        XCTAssertTrue(try String(contentsOf: dest.root.appendingPathComponent("showreel.json")).contains("\"package\""))
        let rows = Assets.load(dest)
        let logo = try XCTUnwrap(rows.first { $0.type == "logo" })
        XCTAssertEqual(logo.status, "approved"); XCTAssertEqual(logo.licenceNote, "supplied by the client: Acme supplied it"); XCTAssertFalse(logo.file.isEmpty)
        XCTAssertEqual(Resources.tags(of: logo, in: f), ["brand"])
        XCTAssertEqual(rows.first { $0.type == "font" }?.status, "approved")
        XCTAssertTrue(rows.contains { $0.original.hasSuffix("OFL.txt") && $0.status == "approved" }, "the licence text of the font came along")
        XCTAssertEqual(report.approved, 2); XCTAssertEqual(report.rightsHeld, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.root.appendingPathComponent("assets/" + logo.file).path), "the project holds its own copy")
        let j = try XCTUnwrap(dest.journal.entries().first { $0.op == "package" })
        XCTAssertEqual(j.author, "app"); XCTAssertTrue(j.after.contains("version 1.0") && j.after.contains(e.manifest.shortHash), j.after)
        XCTAssertTrue((j.note ?? "").contains("rights confirmed by Studio Team"), j.note ?? "")
        XCTAssertFalse(dest.undoLog.canUndo, "starting from a package is not an undoable change of an existing project")
    }

    func testStartingWithoutTheConfirmationPutsTheResourcesOnNeedsAttention() throws {
        try fill(store)
        let e = try lib.add(try build())
        let dest = try newProject(); defer { try? FileManager.default.removeItem(at: dest.root) }
        let report = try PackageStart.start(e, library: lib, into: dest)
        let rows = Assets.load(dest)
        let logo = try XCTUnwrap(rows.first { $0.type == "logo" })
        XCTAssertEqual(logo.status, "hold"); XCTAssertTrue(logo.notes.hasPrefix("Rights not confirmed by you"), logo.notes); XCTAssertTrue(logo.notes.contains("supplied by the client"))
        XCTAssertEqual(logo.state(in: dest.loadShowreel()), .needsAttention); XCTAssertTrue(logo.hiddenFromClap); XCTAssertTrue(logo.file.isEmpty, "no prepared copy before it is settled")
        let a = ResourceAttention.of(logo, store: dest)
        XCTAssertEqual(a.reasons.first?.hasPrefix("Rights not confirmed by you"), true); XCTAssertTrue(a.asksRights)
        let font = try XCTUnwrap(rows.first { $0.type == "font" })
        XCTAssertEqual(font.status, "approved", "an open font asks no rights question")
        XCTAssertEqual(report.rightsHeld, 1); XCTAssertEqual(report.approved, 1)
        XCTAssertTrue((dest.journal.entries().first { $0.op == "package" }?.note ?? "").contains("rights not confirmed"))
        // the user settles it with the ordinary rights answer, and the file becomes available
        try dest.apply(RightsAnswer.client.operation(id: logo.id, detail: "Acme"))
        let settled = Assets.load(dest).first { $0.id == logo.id }!
        XCTAssertEqual(settled.status, "approved"); XCTAssertEqual(settled.notes, "", "the reason goes once it is settled"); XCTAssertFalse(settled.file.isEmpty)
    }

    func testAPackageNeverBypassesTheAutomaticChecks() throws {
        // a package that claims rights for a file whose own metadata and name say otherwise
        let copyrighted = try Data(contentsOf: png("claimed.png", copyright: "Somebody Else"))
        let sensitive = try Data(contentsOf: png("customer-list.png"))
        var files: [String: Data] = [:]
        var res: [PackageResource] = []
        for (id, name, data) in [("img-01", "claimed.png", copyrighted), ("img-02", "customer-list.png", sensitive)] {
            let path = "assets/\(id)/\(name)"; files[path] = data
            res.append(PackageResource(id: id, type: "img", originalName: name, file: path, fileHash: PackageHash.sha256(data), rights: "own work", approvedBy: "Author", approvedAt: "2026-01-01T00:00:00Z"))
        }
        var pkg = DesignPackage(manifest: PackageManifest(name: "Claims", author: "Author", created: "2026-01-01T00:00:00Z", modified: "2026-01-01T00:00:00Z"), design: PackageDesign(tone: "calm"), resources: res, files: files)
        try pkg.seal()
        let e = try lib.add(pkg); try lib.confirm(e, by: nil)
        let dest = try newProject(); defer { try? FileManager.default.removeItem(at: dest.root) }
        let report = try PackageStart.start(lib.entry(e.manifest.id, "1.0")!, library: lib, into: dest)
        let rows = Assets.load(dest)
        XCTAssertTrue(rows.allSatisfy { $0.status == "hold" }, "flagged whatever the package says: \(rows.map { $0.status })")
        XCTAssertEqual(report.flagged, 2); XCTAssertEqual(report.approved, 0)
        XCTAssertTrue(ResourceAttention.of(rows.first { $0.original.contains("claimed") }!, store: dest).asksRights)
        XCTAssertTrue(ResourceAttention.of(rows.first { $0.original.contains("customer") }!, store: dest).mustReplace)
    }

    func testAModifiedPackageStillStartsOnlyWhenItWasKeptAndANewerAppIsRequired() throws {
        try fill(store)
        let p = try build()
        var n = p; n.manifest.appMinVersion = "99.0"
        guard AppInfo.version != "unknown" else { return }
        let e = try lib.add(n)
        let dest = try newProject(); defer { try? FileManager.default.removeItem(at: dest.root) }
        XCTAssertThrowsError(try PackageStart.start(e, library: lib, into: dest)) { XCTAssertTrue("\($0)".contains("newer version"), "\($0)") }
    }

    // MARK: the Wizard and the Manual form

    func testTheWizardAsksOnlyWhatThePackageLeavesOpen() throws {
        try fill(store)
        let e = try lib.add(try build()); try lib.confirm(e, by: nil)
        let plain = try newProject(); defer { try? FileManager.default.removeItem(at: plain.root) }
        XCTAssertEqual(WizardInterview.questions(for: plain.loadShowreel()).count, WizardInterview.questions.count, "a project without a package is asked everything")
        XCTAssertEqual(WizardInterview.prompt(projectName: "x", conversationLanguage: nil, file: plain.loadShowreel()), WizardInterview.prompt(projectName: "x", conversationLanguage: nil))
        let dest = try newProject(); defer { try? FileManager.default.removeItem(at: dest.root) }
        try PackageStart.start(e, library: lib, into: dest)
        let f = dest.loadShowreel()!
        let headers = WizardInterview.questions(for: f).compactMap { $0["header"] as? String }
        XCTAssertEqual(headers, ["Conversation language", "About the film"])
        let about = WizardInterview.questions(for: f).last?["question"] as? String
        XCTAssertTrue(about?.contains("tone comes from the design package") == true)
        let prompt = WizardInterview.prompt(projectName: "Film", conversationLanguage: nil, file: f)
        XCTAssertTrue(prompt.contains("started from a design package")); XCTAssertTrue(prompt.contains("(no `look`)")); XCTAssertTrue(prompt.contains("formats")); XCTAssertFalse(prompt.contains("\"Which formats?\""))
        XCTAssertTrue(WizardInterview.alreadySet(f).contains("look") && WizardInterview.alreadySet(f).contains("tone"))
    }

    func testTheManualFormArrivesPrefilledAndCountsWhatIsSet() throws {
        try fill(store)
        let e = try lib.add(try build()); try lib.confirm(e, by: nil)
        let dest = try newProject(); defer { try? FileManager.default.removeItem(at: dest.root) }
        XCTAssertEqual(ProjectSetup.progress(dest.loadShowreel()!).line, "0 of 5 set")
        try PackageStart.start(e, library: lib, into: dest)
        XCTAssertEqual(ProjectSetup.progress(dest.loadShowreel()!).line, "4 of 5 set", "only the conversation language is left")
        try dest.apply(.parameter(.conversationLanguage, "en"))
        XCTAssertTrue(ProjectSetup.isComplete(dest.loadShowreel()!))
    }

    func testAProjectWithoutAPackageIsWrittenAndReadAsBefore() throws {
        let f = store.loadShowreel()!
        XCTAssertNil(f.package)
        let text = try f.encoded()
        XCTAssertFalse(text.contains("\"package\""))
        XCTAssertEqual(try ShowreelFile.decode(text), f)
        let withKey = text.replacingOccurrences(of: "\"formatRevision\"", with: "\"package\" : { \"id\": \"p\", \"version\": \"1.0\", \"hash\": \"h\", \"appliedAt\": \"d\", \"later\": 1 },\n  \"formatRevision\"")
        let g = try ShowreelFile.decode(withKey)
        XCTAssertEqual(g.package?.id, "p"); XCTAssertEqual(g.package?.unknown["later"], .number(1))
        XCTAssertTrue(try g.encoded().contains("\"later\""), "unknown keys inside the origin are preserved")
        XCTAssertEqual(ShowreelFile.currentRevision, 2, "adding the key needs no format revision")
    }

    // MARK: availability and the limits at save

    func testSavingIsRefusedWhileBuildingAndWhenThereIsNothingToSave() throws {
        try fill(store)
        let offer = PackageSave.offer(store)
        XCTAssertTrue(Availability.savePackage(in: ProjectActivity.Snapshot(), offer: offer).isAvailable)
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        XCTAssertEqual(Availability.savePackage(in: store.activity.snapshot, offer: offer).why?.cause, .building)
        store.activity.update { $0.build = nil }
        let empty = PackageOffer(look: nil, motion: nil, tone: nil, defaults: nil, resources: [])
        let u = Availability.savePackage(in: ProjectActivity.Snapshot(), offer: empty).why
        XCTAssertEqual(u?.reason, "There is nothing to save yet"); XCTAssertFalse(u?.way.isEmpty ?? true)
        XCTAssertFalse(StatusLine.packageSaved(name: "A", version: "1.0", exported: false).undoable, "saving a package is not a change of the project")
    }

    func testAFileOverTheLimitIsRefusedAtSave() throws {
        try fill(store)
        XCTAssertThrowsError(try PackageSave.build(store: store, selection: PackageSelection(all: PackageSave.offer(store)), name: "n", author: "A", note: "", continuing: false, library: lib,
                                                    limits: PackageLimits(maxEntries: 400, maxFileSize: 100, maxTotalSize: 1000))) { XCTAssertTrue("\($0)".contains("larger than"), "\($0)") }
    }

    // MARK: the registered type

    func testTheAppRegistersTheStudiopackTypeInItsInfoPlist() throws {
        let script = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("make-app.sh"), encoding: .utf8)
        for needle in [PackageType.identifier, "UTExportedTypeDeclarations", "public.zip-archive", "CFBundleDocumentTypes", PackageType.fileExtension] { XCTAssertTrue(script.contains(needle), needle) }
    }
}
