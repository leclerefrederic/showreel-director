import XCTest
@testable import ShowreelKit

final class BlocksTests: XCTestCase {
    var dir: URL!
    var store: ProjectStore!
    override func setUp() { dir = makeTempDir("blocks"); store = ProjectStore(root: dir) }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testProcessJSONMatchesTheApp() throws {
        let spec = try XCTUnwrap(ProcessSpec.load())
        XCTAssertEqual(spec.blocks.map { $0.id }, Blocks.ids)
        XCTAssertTrue(spec.steps.allSatisfy { s in spec.block(s.block) != nil })
        XCTAssertEqual(Set(spec.steps.compactMap { $0.gateKey }), Set(ShowreelFile.gateKeys))
        XCTAssertEqual(spec.blocks.filter { $0.built }.map { $0.id }, ["project", "resources"])
    }

    func testStatusesFollowTheProject() throws {
        let spec = try XCTUnwrap(ProcessSpec.load())
        func st(_ id: String) -> BlockStatus { Blocks.status(id, spec: spec, showreel: store.loadShowreel(), assets: Assets.load(store)) }
        XCTAssertEqual(st("project"), .todo, "no showreel.json yet")
        XCTAssertEqual(st("look"), .soon)
        XCTAssertEqual(st("build"), .soon)
        var f = try store.create(name: "S", conversationLanguage: nil, reelLanguages: [])
        XCTAssertEqual(st("project"), .todo)
        XCTAssertEqual(st("resources"), .todo)
        try store.apply(.parameter(.audience, "Teams"))
        XCTAssertEqual(st("project"), .inProgress)
        try store.apply(.gate("interview", passed: true))
        XCTAssertEqual(st("project"), .validated)
        f = try XCTUnwrap(store.loadShowreel())
        XCTAssertEqual(f.gates["interview"], "passed")
        try Assets.save([AssetRow(id: "logo-01", type: "logo")], store)
        XCTAssertEqual(st("resources"), .inProgress)
        try store.apply(.gate("assets", passed: true))
        XCTAssertEqual(st("resources"), .validated)
        XCTAssertEqual(st("storyboard"), .soon, "an unbuilt block stays coming soon whatever the data says")
    }

    func testOperationsAreTypedAndChecked() throws {
        try store.create(name: "Ops", conversationLanguage: "en", reelLanguages: ["en"])
        let card = try store.plan(.parameter(.audience, "  Product teams  "))
        XCTAssertEqual(card.title, "Set audience")
        XCTAssertEqual(card.changes, [Change("Audience", "(empty)", "Product teams")])
        try store.apply(.parameter(.audience, "Product teams"), expecting: card)
        XCTAssertEqual(store.loadShowreel()?.parameters.audience, "Product teams")
        XCTAssertThrowsError(try store.plan(.parameter(.audience, "Product teams")), "no change is an error")
        // a card made before someone else changed the value is stale
        let stale = try store.plan(.parameter(.tone, "calm"))
        try store.apply(.parameter(.tone, "bold"))
        XCTAssertThrowsError(try store.apply(.parameter(.tone, "calm"), expecting: stale))
        XCTAssertEqual(store.loadShowreel()?.parameters.tone, "bold")
        // lists, numbers, clearing
        try store.apply(.parameter(.reelLanguages, "EN, fr ; fr, de"))
        XCTAssertEqual(store.loadShowreel()?.reelLanguages, ["en", "fr", "de"])
        try store.apply(.parameter(.formats, "16:9, 9:16"))
        XCTAssertEqual(store.loadShowreel()?.decisions.formats, ["16:9", "9:16"])
        try store.apply(.parameter(.duration, "45 s"))
        XCTAssertEqual(store.loadShowreel()?.decisions.duration, 45)
        XCTAssertThrowsError(try store.plan(.parameter(.duration, "soon")))
        XCTAssertThrowsError(try store.plan(.parameter(.duration, "-3")))
        try store.apply(.parameter(.tone, ""))
        XCTAssertNil(store.loadShowreel()?.parameters.tone)
        XCTAssertThrowsError(try store.plan(.parameter(.name, "  ")))
        XCTAssertThrowsError(try store.plan(.gate("nonsense", passed: true)))
    }

    func testEveryChangeKeepsTheHistory() throws {
        try store.create(name: "H", conversationLanguage: nil, reelLanguages: [])
        try store.apply(.parameter(.audience, "one"))
        try store.apply(.parameter(.audience, "two"))
        XCTAssertGreaterThanOrEqual(store.snapshots(ShowreelFile.fileName).count, 2)
    }
}
