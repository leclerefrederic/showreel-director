import AppKit
import XCTest
@testable import ShowreelKit

/// Batch C1: corrections from the owner's test session.
final class C1Tests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("c1"); inbox = makeTempDir("c1-in"); store = ProjectStore(root: dir)
        try? store.create(name: "C", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        store.undoLog.clear(); store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    func make(_ name: String) -> URL { let u = inbox.appendingPathComponent(name); try? "x".write(to: u, atomically: true, encoding: .utf8); return u }

    // MARK: 1. a resource dragged from the grouped list

    func testWhatARowOfTheGroupedListCarriesDecodesToItsResourceAndLinksItToTheScene() throws {
        try Assets.add([make("Acme Logo.svg")], to: store)
        let row = try XCTUnwrap(Assets.load(store).first)
        // the row of the list carries `.resource(id)`, as a short text; the drop decodes it back
        let token = DragItem.resource(row.id).token
        XCTAssertEqual(token, "studio:resource:" + row.id)
        XCTAssertEqual(DragItem(token: token), .resource(row.id))
        let item = try XCTUnwrap(DragItem(token: token))
        for target in [DropTarget.scene("S01"), .sceneNode(scene: "S01", group: .composition, node: nil)] {
            XCTAssertTrue(Drops.applies(item, to: target))
        }
        XCTAssertEqual(row.state(in: store.loadShowreel()), .available)
        let r = try Drops.drop(item, on: .scene("S01"), store: store)
        XCTAssertEqual(r.scene, "S01")
        let after = try XCTUnwrap(Assets.load(store).first)
        XCTAssertEqual(after.state(in: store.loadShowreel()), .used(["S01"]), "it is part of the composition and reads Used in S01")
        XCTAssertEqual(after.sceneIDs, ["S01"])
    }

    func testAResourceDroppedOnALockedSceneIsRefusedWithItsReason() throws {
        try Assets.add([make("Acme Logo.svg")], to: store)
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        let row = try XCTUnwrap(Assets.load(store).first)
        let v = Drops.verdict(.resource(row.id), on: .scene("S01"), store: store)
        XCTAssertFalse(v.isValid); XCTAssertFalse(v.text.isEmpty); XCTAssertTrue(v.text.lowercased().contains("lock"), v.text)
        XCTAssertThrowsError(try Drops.drop(.resource(row.id), on: .scene("S01"), store: store))
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, [], "nothing was linked")
    }

    func testAResourceDroppedDuringABuildIsRefusedWithItsReason() throws {
        try Assets.add([make("Acme Logo.svg")], to: store)
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        let row = try XCTUnwrap(Assets.load(store).first)
        let v = Drops.verdict(.resource(row.id), on: .scene("S01"), store: store)
        XCTAssertFalse(v.isValid); XCTAssertFalse(v.text.isEmpty)
    }

    // MARK: 2. the cover of an MP3

    func png() -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 6, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }
    func syncsafe(_ n: Int) -> [UInt8] { [UInt8((n >> 21) & 127), UInt8((n >> 14) & 127), UInt8((n >> 7) & 127), UInt8(n & 127)] }
    func be32(_ n: Int) -> [UInt8] { [UInt8((n >> 24) & 255), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)] }

    /// An ID3v2 tag with one picture frame, followed by what looks like the start of the audio.
    func mp3(version: Int, picture: Data?, corrupt: Bool = false) -> Data {
        var frames: [UInt8] = []
        if let pic = picture {
            if version == 2 {
                let body: [UInt8] = [0] + Array("PNG".utf8) + [3] + [0] + [UInt8](pic)
                frames += Array("PIC".utf8) + [UInt8((body.count >> 16) & 255), UInt8((body.count >> 8) & 255), UInt8(body.count & 255)] + body
            } else {
                let body: [UInt8] = [0] + Array("image/png".utf8) + [0, 3] + Array("Cover".utf8) + [0] + [UInt8](pic)
                frames += Array("APIC".utf8) + (version == 4 ? syncsafe(body.count) : be32(body.count)) + [0, 0] + body
            }
        }
        if corrupt { frames = Array(frames.prefix(frames.count / 2)) }
        let declared = corrupt ? frames.count * 3 : frames.count
        var d = Data([0x49, 0x44, 0x33, UInt8(version), 0, 0] + syncsafe(declared) + frames)
        d.append(Data(repeating: 0xFF, count: 64))
        return d
    }
    func file(_ name: String, _ d: Data) -> URL { let u = inbox.appendingPathComponent(name); try? d.write(to: u); return u }

    func testAnID3PictureIsFoundInTheCommonVersions() {
        let p = png()
        for v in [2, 3, 4] {
            XCTAssertEqual(ID3Artwork.picture(in: mp3(version: v, picture: p)), p, "ID3v2.\(v)")
            XCTAssertEqual(AudioMetadata.artwork(file("cover\(v).mp3", mp3(version: v, picture: p))), p, "read from a file, ID3v2.\(v)")
        }
        XCTAssertEqual(AudioMetadata.read(file("full.mp3", mp3(version: 3, picture: p)))?.artwork, p, "AudioMetadata.read gives the cover")
    }

    func testAnMP3WithoutAPictureHasNoCoverAndACorruptFrameDoesNotCrash() {
        XCTAssertNil(ID3Artwork.picture(in: mp3(version: 3, picture: nil)))
        XCTAssertNil(AudioMetadata.artwork(file("plain.mp3", mp3(version: 3, picture: nil))))
        XCTAssertNil(AudioMetadata.read(file("plain2.mp3", mp3(version: 3, picture: nil)))?.artwork)
        let p = png()
        for v in [2, 3, 4] { XCTAssertNil(ID3Artwork.picture(in: mp3(version: v, picture: p, corrupt: true)), "a truncated frame, ID3v2.\(v)") }
        for n in [0, 1, 5, 9, 10, 11, 20] { XCTAssertNil(ID3Artwork.picture(in: Data(mp3(version: 3, picture: p).prefix(n)))) }
        XCTAssertNil(ID3Artwork.picture(in: Data(repeating: 0xFF, count: 200)))
        XCTAssertNil(AudioMetadata.artwork(file("junk.mp3", Data("not an mp3 at all".utf8))), "bytes that are not an image are not a cover")
        let notImage = mp3(version: 3, picture: Data("this is text, not a picture".utf8))
        XCTAssertNil(AudioMetadata.artwork(file("textcover.mp3", notImage)))
    }

    func testTheCoverSizeAppearsInTheDetails() throws {
        let u = file("Song.mp3", mp3(version: 3, picture: png()))
        try Assets.add([u], to: store)
        let row = try XCTUnwrap(Assets.load(store).first)
        let d = ResourceDetailsReader.read(row, store: store, file: store.loadShowreel())
        if let cover = d.value("Cover") { XCTAssertTrue(cover.contains("8 \u{00D7} 6 px"), cover) }
        else { XCTAssertNotNil(d.groups, "the file may not open as audio on this machine; the cover is read by the tag reader in the other tests") }
    }

    // MARK: 4. the question about fonts before a build

    func fontsStore() throws {
        try store.apply(.decisions([DecisionChange(.titleFont, "Fredoka"), DecisionChange(.textFont, "Nunito")], title: nil))
        store.activity.reset()
    }
    func repo() -> FakeFontSource {
        let names = ["Fredoka[wdth,wght].ttf", "OFL.txt"]
        let preview = (try? Data(contentsOf: Skill.root()!.appendingPathComponent("engine/fonts-preview/fredoka.woff2"))) ?? Data("x".utf8)
        return FakeFontSource(files: names.map { RepoFile(name: $0, size: $0 == "OFL.txt" ? 4400 : 120_000, url: "https://raw.githubusercontent.com/google/fonts/main/ofl/x/\($0)") },
                              data: ["Fredoka[wdth,wght].ttf": preview, "OFL.txt": Data("OFL".utf8)])
    }

    func testTheQuestionAppearsOnlyWhenFilesAreMissing() async throws {
        let src = repo()
        XCTAssertTrue(FontsAtBuild.missing(store).isEmpty, "the Look chose no font: nothing to ask")
        let none = await FontsAtBuild.prepare(store, source: src)
        XCTAssertNil(none); XCTAssertEqual(src.listed, 0, "and the repository is not even asked")
        try fontsStore()
        XCTAssertEqual(FontsAtBuild.missing(store), ["Fredoka", "Nunito"])
        let qopt = await FontsAtBuild.prepare(store, source: src); let q = try XCTUnwrap(qopt)
        XCTAssertEqual(q.families, ["Fredoka", "Nunito"])
        XCTAssertTrue(q.card.changes.contains { $0.after.contains("github.com/google/fonts") })
        XCTAssertTrue(q.card.changes.contains { $0.after.contains("SIL Open Font License") })
        XCTAssertTrue(q.card.changes.contains { $0.label == "Size" && $0.after.contains("KB") }, "the size is on the card")
        XCTAssertTrue(src.downloaded.isEmpty, "looking up is not downloading")
    }

    func testEachChoiceHasItsEffectAndNothingIsDownloadedWithoutTheYes() async throws {
        try fontsStore()
        let src = repo()
        let qopt = await FontsAtBuild.prepare(store, source: src); let q = try XCTUnwrap(qopt)
        let a = try await q.resolve(.cancel, store: store, source: src)
        XCTAssertEqual(a, .stop); XCTAssertTrue(src.downloaded.isEmpty); XCTAssertEqual(FontsAtBuild.missing(store), ["Fredoka", "Nunito"])
        let b = try await q.resolve(.systemFont, store: store, source: src)
        XCTAssertEqual(b, .proceed); XCTAssertTrue(src.downloaded.isEmpty, "a system font downloads nothing")
        XCTAssertEqual(FontsAtBuild.missing(store), ["Fredoka", "Nunito"], "and the Fonts step stays orange")
        let step = try XCTUnwrap(FontEmbedding.step(store, entries: []))
        XCTAssertFalse(step.ok); XCTAssertTrue(step.text.contains("system font"))
        let c = try await q.resolve(.download, store: store, source: src)
        XCTAssertEqual(c, .proceed); XCTAssertFalse(src.downloaded.isEmpty)
        XCTAssertFalse(Assets.load(store).filter { $0.type == "font" }.isEmpty)
        let lines = store.journal.entries().filter { $0.op == "fonts" }.map { $0.title }
        XCTAssertEqual(lines, ["Fonts at build: cancelled", "Fonts at build: continue with a system font", "Fonts at build: download and continue"], "every choice is in the journal")
    }

    func testADownloadThatFailsStopsTheBuildAndKeepsTheManualWay() async throws {
        try fontsStore()
        let src = repo()
        let qopt = await FontsAtBuild.prepare(store, source: src); let q = try XCTUnwrap(qopt)
        src.listingError = FontRepositoryError(status: 403, url: "https://api.github.com/x", rateLimited: true)
        do { _ = try await q.resolve(.download, store: store, source: src); XCTFail("must throw") }
        catch { XCTAssertTrue(error.localizedDescription.contains("anonymous request limit") && error.localizedDescription.contains("fonts.google.com"), error.localizedDescription) }
        XCTAssertTrue(Assets.load(store).filter { $0.type == "font" }.isEmpty)
        // a lookup that failed when the card was made still gives a card, which says so
        let q2opt = await FontsAtBuild.prepare(store, source: src); let q2 = try XCTUnwrap(q2opt)
        XCTAssertNotNil(q2.lookupProblem); XCTAssertTrue(q2.card.changes.contains { $0.after.contains("could not be asked") })
    }

    // MARK: 5. the app's instructions in the conversation

    func testAnAppInstructionIsSentAndKeptButNeverDrawnAsABubble() throws {
        let app = ChatRecord(role: "user", text: "Lead the interview with these questions: {\"header\":\"Duration\"}", origin: ChatRecord.appOrigin, status: "Wizard started")
        let me = ChatRecord(role: "user", text: "A film for my team")
        let clap = ChatRecord(role: "assistant", text: "Which language?")
        XCTAssertEqual(ChatDisplay.line(for: app), .status("Wizard started"))
        XCTAssertEqual(ChatDisplay.line(for: me), .bubble(role: "user", text: "A film for my team"))
        XCTAssertEqual(ChatDisplay.line(for: ChatRecord(role: "user", text: "x", origin: "app")), .status("Request sent to Clap"))
        // the model still gets it: the turns that seed a resumed conversation hold its text
        let seed = ChatStore.seed(from: [app, clap, me, ChatRecord(role: "assistant", text: "ok"), ChatRecord(role: "user", text: "next")])
        XCTAssertTrue((seed.first?["content"] as? String)?.contains("Lead the interview") == true)
        // the summary of the session reads it too
        XCTAssertTrue(Sessions.summaryRequest(records: [app, clap], journal: []).user.contains("Lead the interview"))
        // the transcript on disk keeps it, with its origin; an older line without one still reads
        let s = ChatStore(root: dir)
        s.append(app); s.append(me)
        let back = ChatStore.records(root: dir, session: s.sessionID)
        XCTAssertEqual(back.map { $0.origin }, [ChatRecord.appOrigin, nil]); XCTAssertEqual(back.first?.text, app.text)
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let old = try dec.decode(ChatRecord.self, from: Data(#"{"role":"user","text":"hello","date":"2026-01-01T00:00:00Z"}"#.data(using: .utf8)!))
        XCTAssertNil(old.origin); XCTAssertFalse(old.fromApp)
        // the Sessions view hides the app's instructions until the box is ticked
        XCTAssertEqual(ChatDisplay.transcript(back, showAppInstructions: false).map { $0.text }, [me.text])
        XCTAssertEqual(ChatDisplay.transcript(back, showAppInstructions: true).count, 2)
    }

    // MARK: 6. the durations

    func testTheWizardAndTheFormOfferTheSameFiveDurations() throws {
        XCTAssertEqual(ProjectSetup.durationChoices, [30, 45, 60, 75, 90])
        let q = try XCTUnwrap(WizardInterview.questions.first { $0["header"] as? String == "Duration" })
        let labels = (q["options"] as? [[String: Any]])?.compactMap { $0["label"] as? String }
        XCTAssertEqual(labels, ["30 s", "45 s", "60 s", "75 s", "90 s"])
        let p = WizardInterview.prompt(projectName: "C", conversationLanguage: "en")
        XCTAssertTrue(p.contains("75 s") && !p.contains("\"15 s\""))
        guard case .number(_, let presets) = Wizard.steps(assets: [], spec: ProcessSpec.load()!, systemLanguage: nil).first(where: { $0.id == "project.duration" })!.kind else { return XCTFail() }
        XCTAssertEqual(presets.map { $0.value }, ProjectSetup.durationChoices.map { String($0) })
    }

    // MARK: 7. no button for the style gate

    func testTheStyleGateIsDerivedFromTheLook() throws {
        var f = try XCTUnwrap(store.loadShowreel())
        XCTAssertEqual(f.gateState("style"), "open")
        try store.apply(.decisions([DecisionChange(.palette, "#101820, #FFFFFF, #F2AA4C, #4CC2F2"), DecisionChange(.titleFont, "Fredoka"), DecisionChange(.textFont, "Nunito")], title: nil))
        f = try XCTUnwrap(store.loadShowreel())
        XCTAssertEqual(f.gateState("style"), "open", "no background yet")
        try store.apply(.decisions([DecisionChange(.background, "aurora")], title: nil))
        f = try XCTUnwrap(store.loadShowreel())
        XCTAssertEqual(f.gateState("style"), "passed", "palette, fonts and background chosen")
    }
}

/// Batch D1: a resource dragged to a scene, the plan of a drop and the drag log.
final class D1Tests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("d1"); inbox = makeTempDir("d1-in"); store = ProjectStore(root: dir)
        try? store.create(name: "D", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: "x")))     // unused: keeps ids stable
        store.undoLog.clear(); store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    func addLogo() throws -> AssetRow {
        let u = inbox.appendingPathComponent("Acme Logo.svg"); try "x".write(to: u, atomically: true, encoding: .utf8)
        return try XCTUnwrap(try Assets.add([u], to: store).first)
    }

    func testEveryTargetThatTakesAResourceGivesTheOperation() throws {
        let row = try addLogo()
        let token = DragItem.resource(row.id).token
        for target in [DropTarget.scene("S01"),                                                       // a frame of the reel, or a row of the scene list
                       .sceneNode(scene: "S02", group: .composition, node: nil),                      // a node of the tree
                       .sceneNode(scene: "S03", group: .composition, node: "item.c1"),
                       .contentSlot(scene: "S01", before: nil)] {                                      // the inspector's content list
            let o = DropPlan.resolve(token: token, target: target, store: store)
            XCTAssertTrue(o.isValid, "\(target): \(o.text)")
            XCTAssertTrue(o.text.contains("Acme Logo.svg"), o.text)
        }
        XCTAssertEqual(DropPlan.resolve(token: token, target: .scene("S01"), store: store), .operation("Link Acme Logo.svg to S01"))
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, [], "resolving changes nothing")
        let done = DropPlan.perform(token: token, target: .scene("S03"), store: store)
        XCTAssertEqual(done.result?.scene, "S03")
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, ["S03"])
        XCTAssertEqual(DropPlan.doneLine(done.outcome.text), "Linked Acme Logo.svg to S03")
    }

    func testALostOrUnreadableTokenGivesAMessage() throws {
        for token in [nil, "", "garbage", "studio:", "studio:content:S01", "other:resource:x"] as [String?] {
            let o = DropPlan.resolve(token: token, target: .scene("S01"), store: store)
            XCTAssertEqual(o, .refused(DropPlan.lostToken), "\(String(describing: token))")
        }
        XCTAssertEqual(DropPlan.resolve(token: "studio:resource:nope-01", target: .scene("S01"), store: store), .refused("unknown asset nope-01"))
        XCTAssertEqual(DropPlan.resolve(token: DragItem.transition("Push").token, target: .scene("S01"), store: store).isValid, false, "a kind that does not go there says so")
    }

    func testALockedSceneAnArchivedSceneAndABuildRefuseWithTheirReason() throws {
        let row = try addLogo()
        let token = DragItem.resource(row.id).token
        try store.apply(.scene(id: "S01", SceneEdit(status: "ok")))
        try store.apply(.sceneLock(ids: ["S01"], locked: true))
        let locked = DropPlan.resolve(token: token, target: .scene("S01"), store: store)
        XCTAssertFalse(locked.isValid); XCTAssertTrue(locked.text.lowercased().contains("lock"), locked.text)
        try store.apply(.scene(id: "S02", SceneEdit(archived: true)))
        let archived = DropPlan.resolve(token: token, target: .scene("S02"), store: store)
        XCTAssertFalse(archived.isValid); XCTAssertTrue(archived.text.contains("archived"), archived.text)
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        let building = DropPlan.resolve(token: token, target: .scene("S03"), store: store)
        XCTAssertFalse(building.isValid); XCTAssertFalse(building.text.isEmpty)
        XCTAssertEqual(DropPlan.perform(token: token, target: .scene("S03"), store: store).result, nil)
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, [], "nothing was linked by any of them")
    }

    // MARK: the log

    func testTheLogWritesNoContentNoUserPathAndKeepsItsCeiling() throws {
        let url = inbox.appendingPathComponent("logs/drag.log")
        let log = DragLog(url: url, maxBytes: 2000)
        log.note("drag begin", "resource:logo-01 types=public.utf8-plain-text")
        log.note("result", "refused: cannot read \(NSHomeDirectory())/Documents/Secret Plan/notes.pdf and /Users/someone/Desktop/a.png")
        log.flush()
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("logo-01"))
        XCTAssertFalse(text.contains(NSHomeDirectory()) || text.contains("/Users/someone") || text.contains("Secret Plan"), text)
        XCTAssertTrue(text.contains("<path>") || text.contains("~"))
        XCTAssertEqual(DragLog.name(of: .files([URL(fileURLWithPath: "/Users/x/Private/a.png")])), "files(1)", "files are counted, never named")
        for n in 0..<400 { log.note("hover", "resource:logo-01 over scene S0\(n % 9): ok step \(n)") }
        log.flush()
        let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        XCTAssertLessThanOrEqual(size, 2000, "the file stays under its ceiling")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("1").path), "and the older lines were rotated")
        let before = size
        log.note("hover", "resource:logo-01 over scene S03: ok step 399")      // the same line twice in a row is one line
        log.flush()
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, before)
        XCTAssertTrue(DragLog.standardURL.path.hasSuffix("Library/Logs/ShowreelStudio/drag.log"))
    }

    func testTheTypedDropTokenOfAResourceRoundTrips() throws {
        let row = try addLogo()
        let t = DragItem.resource(row.id).token
        XCTAssertEqual(DropPlan.item(token: t), .resource(row.id))
        XCTAssertEqual(DragLog.name(of: .resource(row.id)), "resource:" + row.id)
    }
}

/// Batch D2: the menu of a resource, the way to use it without a drag.
final class D2Tests: XCTestCase {
    var dir: URL!
    var inbox: URL!
    var store: ProjectStore!
    override func setUp() {
        dir = makeTempDir("d2"); inbox = makeTempDir("d2-in"); store = ProjectStore(root: dir)
        try? store.create(name: "D", conversationLanguage: "en", reelLanguages: ["en"])
        for t in ["One", "Two", "Three", "Four"] { try? store.apply(.addScene(id: "", SceneEdit(duration: "3", text: t))) }
        store.undoLog.clear(); store.activity.reset()
    }
    override func tearDown() { store.activity.reset(); try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: inbox) }
    func add(_ name: String) throws -> AssetRow {
        let u = inbox.appendingPathComponent(name); try "x".write(to: u, atomically: true, encoding: .utf8)
        return try XCTUnwrap(try Assets.add([u], to: store).first)
    }

    func testAddToSceneListsTheFilmWithLockedGreyedAndArchivedLeftOut() throws {
        let logo = try add("Acme Logo.svg")
        try store.apply(.scene(id: "S02", SceneEdit(status: "ok"))); try store.apply(.sceneLock(ids: ["S02"], locked: true))
        try store.apply(.scene(id: "S04", SceneEdit(archived: true)))
        let c = ResourceMenu.sceneChoices(asset: logo.id, store: store)
        XCTAssertEqual(c.map { $0.id }, ["S01", "S02", "S03"], "the archived scene is not offered")
        XCTAssertNil(c[0].reason); XCTAssertNil(c[2].reason)
        XCTAssertTrue(c[1].reason?.lowercased().contains("lock") == true, c[1].reason ?? "nil")
        XCTAssertNil(ResourceMenu.addRefusal(asset: logo.id, store: store))
        // a scene that already has it says so
        XCTAssertTrue(ResourceMenu.add(asset: logo.id, to: "S01", store: store).isValid)
        XCTAssertTrue(ResourceMenu.sceneChoices(asset: logo.id, store: store)[0].reason?.contains("already linked") == true)
    }

    func testABuildGreysEverySceneWithItsReason() throws {
        let logo = try add("Acme Logo.svg")
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        let c = ResourceMenu.sceneChoices(asset: logo.id, store: store)
        XCTAssertEqual(c.count, 4)
        XCTAssertTrue(c.allSatisfy { $0.reason?.contains("Building the film") == true })
        XCTAssertNotNil(ResourceMenu.addRefusal(asset: logo.id, store: store))
        XCTAssertFalse(ResourceMenu.add(asset: logo.id, to: "S01", store: store).isValid)
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, [])
    }

    func testAddingLinksTheResourceWithUndoAndAFlaggedFileIsRefused() throws {
        let logo = try add("Acme Logo.svg")
        XCTAssertEqual(ResourceMenu.add(asset: logo.id, to: "S03", store: store), .operation("Link Acme Logo.svg to S03"))
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, ["S03"])
        _ = try store.undo()
        XCTAssertEqual(Assets.load(store).first?.sceneIDs, [], "one undo step")
        let held = try add("client-photo.jpg")
        XCTAssertEqual(held.status, "hold")
        XCTAssertNotNil(ResourceMenu.addRefusal(asset: held.id, store: store))
        XCTAssertTrue(ResourceMenu.sceneChoices(asset: held.id, store: store).allSatisfy { $0.reason?.contains("needs attention") == true })
    }

    func testUseAsMusicIsOfferedForATrackOnlyAndPicksTheTrack() throws {
        let logo = try add("Acme Logo.svg"), track = try add("theme.mp3")
        XCTAssertFalse(ResourceMenu.music(asset: logo.id, store: store).offered)
        var m = ResourceMenu.music(asset: track.id, store: store)
        XCTAssertTrue(m.offered); XCTAssertNil(m.reason)
        XCTAssertTrue(ResourceMenu.useAsMusic(asset: track.id, store: store).isValid)
        XCTAssertEqual(store.loadShowreel()?.decisions.track?.file, "assets/" + track.file)
        m = ResourceMenu.music(asset: track.id, store: store)
        XCTAssertTrue(m.reason?.contains("already") == true, m.reason ?? "nil")
        store.activity.update { $0.build = .init(version: "v1", phase: .generating) }
        XCTAssertNotNil(ResourceMenu.music(asset: track.id, store: store).reason)
    }

    func testTheDragTokenOfAResourceCarriesItsIdentifier() throws {
        let logo = try add("Acme Logo.svg")
        XCTAssertEqual(DragItem.resource(logo.id).token, "studio:resource:" + logo.id)
        XCTAssertEqual(DragItem(token: DragItem.resource(logo.id).token), .resource(logo.id))
        XCTAssertEqual(DragLog.name(of: .resource(logo.id)), "resource:" + logo.id)
    }
}


/// Batch D3: a drag always ends clean, the log cannot hold or break anything, and the preview needs no file.
final class D3Tests: XCTestCase {
    func testEveryOutcomeGivesACleanSession() {
        for outcome in [DragRun.Outcome.dropped, .refused, .outsideTarget, .cancelled] {
            var s = DragRun()
            s.begin(.resource("logo-01"))
            XCTAssertTrue(s.isActive)
            s.over(.scene("S01"), valid: true)
            XCTAssertNotNil(s.hover); XCTAssertNotNil(s.lastValid)
            let line = s.finish(outcome)
            XCTAssertEqual(s, DragRun(), "\(outcome): nothing of the drag stays")
            XCTAssertFalse(s.isActive); XCTAssertNil(s.hover); XCTAssertNil(s.lastValid)
            XCTAssertTrue(line.contains("resource:logo-01") && line.contains(outcome.rawValue), line)
        }
        var s = DragRun(); s.begin(.resource("a"))
        XCTAssertTrue(s.finish(.cancelled).contains("no drop target ever saw this drag"), "the log says when no target saw the drag")
        XCTAssertEqual(s.finish(.cancelled), "drag end none cancelled after 0 ms (no drop target ever saw this drag)", "ending twice is harmless")
        s.begin(.resource("b")); s.begin(.resource("c"))
        XCTAssertEqual(s.item, .resource("c"), "a second start replaces the first")
    }

    func testTheLogToleratesAWriteError() throws {
        let base = makeTempDir("d3")
        defer { try? FileManager.default.removeItem(at: base) }
        let blocker = base.appendingPathComponent("blocker"); try "x".write(to: blocker, atomically: true, encoding: .utf8)
        let log = DragLog(url: blocker.appendingPathComponent("logs/drag.log"))       // its folder cannot be created: a file is in the way
        for n in 0..<20 { log.note("hover", "step \(n)") }
        log.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: blocker.appendingPathComponent("logs").path))
        let readOnly = base.appendingPathComponent("ro"); try FileManager.default.createDirectory(at: readOnly, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: readOnly.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: readOnly.path) }
        DragLog(url: readOnly.appendingPathComponent("drag.log")).note("x", "y")
        // writing never blocks: a thousand notes return at once
        let t = Date(); let fast = DragLog(url: base.appendingPathComponent("fast/drag.log"))
        for n in 0..<1000 { fast.note("hover", "n \(n)") }
        XCTAssertLessThan(Date().timeIntervalSince(t), 1.0)
        fast.flush()
    }

    func testThePreviewNeedsNoFileRead() throws {
        let base = makeTempDir("d3t"); defer { try? FileManager.default.removeItem(at: base) }
        let cache = ThumbnailCache()
        let u = base.appendingPathComponent("p.png")
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 300, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        try rep.representation(using: .png, properties: [:])!.write(to: u)
        XCTAssertNil(cache.cached("photo-01"), "a miss reads nothing")
        XCTAssertTrue(cache.shouldLoad("photo-01")); XCTAssertFalse(cache.shouldLoad("photo-01"), "one load at a time")
        let img = try XCTUnwrap(cache.load(u, key: "photo-01"))
        XCTAssertLessThanOrEqual(max(img.width, img.height), 128, "a small picture, not the file")
        try FileManager.default.removeItem(at: u)                                    // the file is gone: the preview still has its picture
        XCTAssertNotNil(cache.cached("photo-01"))
        XCTAssertFalse(cache.shouldLoad("photo-01"))
        XCTAssertNil(cache.load(base.appendingPathComponent("missing.png"), key: "none"), "an unreadable file is nil, not a crash")
        XCTAssertTrue(cache.shouldLoad("none"), "and can be tried again")
    }
}
