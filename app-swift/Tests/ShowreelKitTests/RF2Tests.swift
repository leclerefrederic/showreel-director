import XCTest
@testable import ShowreelKit

/// RF2: a deferred call must not act on a thing that is no longer the one it was made for.
final class RF2Tests: XCTestCase {
    func testStaleTimeoutAfterANewerLoadIsANoOp() {
        var g = LoadGate()
        let first = g.begin()
        XCTAssertTrue(g.finish(first))
        let second = g.begin()
        XCTAssertFalse(g.finish(first), "the timeout of load 1 must not end load 2")
        XCTAssertTrue(g.isPending)
        XCTAssertTrue(g.finish(second))
    }

    func testDoubleFinishIsANoOp() {
        var g = LoadGate()
        let t = g.begin()
        XCTAssertTrue(g.finish(t))
        XCTAssertFalse(g.finish(t))
    }

    func testTimeoutOfTheCurrentLoadFinishesIt() {
        var g = LoadGate()
        let t = g.begin()
        XCTAssertTrue(g.finish(t))
        XCTAssertFalse(g.isPending)
    }

    func testSupersededLoadCannotFinish() {
        var g = LoadGate()
        let old = g.begin(); _ = g.begin()
        XCTAssertFalse(g.finish(old))
    }

    func testOnlyRealFailuresAreRemembered() {
        XCTAssertTrue(LoadOutcome.timedOut.isTransient)
        XCTAssertTrue(LoadOutcome.superseded.isTransient)
        XCTAssertFalse(LoadOutcome.failed.isTransient)
        XCTAssertFalse(LoadOutcome.loaded.isTransient)
    }

    func testSameNameDifferentFileIsTwoKeys() {
        let d = Date(timeIntervalSince1970: 100)
        let a = FontIdentity.key(name: "Inter", path: "/p1/inter.ttf", size: 10, modified: d)
        let b = FontIdentity.key(name: "Inter", path: "/p2/inter.ttf", size: 10, modified: d)
        let c = FontIdentity.key(name: "Inter", path: "/p1/inter.ttf", size: 11, modified: d)
        XCTAssertEqual(Set([a, b, c]).count, 3)
    }

    func testSameFileIsOneKey() {
        let d = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(FontIdentity.key(name: "Inter", path: "/p/i.ttf", size: 10, modified: d), FontIdentity.key(name: "inter", path: "/p/i.ttf", size: 10, modified: d))
    }

    func testFileKeyFollowsTheFile() throws {
        let f = FileManager.default.temporaryDirectory.appendingPathComponent("rf2-\(UUID().uuidString).ttf")
        try Data([1, 2, 3]).write(to: f); defer { try? FileManager.default.removeItem(at: f) }
        let k1 = FontIdentity.key(name: "X", file: f)
        XCTAssertEqual(k1, FontIdentity.key(name: "X", file: f))
        try Data([1, 2, 3, 4]).write(to: f)
        XCTAssertNotEqual(k1, FontIdentity.key(name: "X", file: f))
    }

    func testHoldRepeatTicksThenStopsAndStopIsIdempotent() {
        let h = HoldRepeat(delay: 0.02, interval: 0.01)
        var n = 0
        h.start { n += 1 }
        XCTAssertTrue(h.isRunning)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertGreaterThan(n, 2)
        h.stop(); h.stop()
        XCTAssertFalse(h.isRunning)
        let seen = n
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(n, seen, "no tick after stop")
    }

    func testHoldRepeatStopsWhenReleased() {
        var n = 0
        var h: HoldRepeat? = HoldRepeat(delay: 0.01, interval: 0.01)
        h?.start { n += 1 }
        h = nil
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(n, 0)
    }

    func testRestartReplacesTheRunningRepeat() {
        let h = HoldRepeat(delay: 0.01, interval: 0.01)
        var a = 0, b = 0
        h.start { a += 1 }; h.start { b += 1 }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        h.stop()
        XCTAssertEqual(a, 0); XCTAssertGreaterThan(b, 0)
    }
}
