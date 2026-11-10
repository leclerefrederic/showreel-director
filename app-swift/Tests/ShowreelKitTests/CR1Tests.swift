import AppKit
import XCTest
@testable import ShowreelKit

/// CR1: the close guard must never claim a selector it cannot answer ("unrecognized selector windowDidResize:" during a window animation).
final class CR1Tests: XCTestCase {
    final class Inner: NSObject, NSWindowDelegate {
        var resized = 0, moved = 0, closeAsked = 0, allowClose = true
        func windowDidResize(_ n: Notification) { resized += 1 }
        func windowDidMove(_ n: Notification) { moved += 1 }
        func windowShouldClose(_ s: NSWindow) -> Bool { closeAsked += 1; return allowClose }
    }

    /// The code before CR1: weak original, forwarding only while it lives.
    final class Legacy: NSObject, NSWindowDelegate {
        weak var original: NSWindowDelegate?
        override func responds(to s: Selector!) -> Bool { super.responds(to: s) || (original?.responds(to: s) ?? false) }
        override func forwardingTarget(for s: Selector!) -> Any? { (original?.responds(to: s) ?? false) ? original : super.forwardingTarget(for: s) }
    }

    private func window() -> NSWindow { NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled, .resizable, .closable], backing: .buffered, defer: true) }

    func testTheOldGuardClaimedASelectorItCouldNotAnswer() {
        let legacy = Legacy(); var inner: Inner? = Inner(); legacy.original = inner
        let sel = #selector(NSWindowDelegate.windowDidResize(_:))
        XCTAssertTrue(legacy.responds(to: sel))              // AppKit registers it for the notification here
        inner = nil
        XCTAssertNil(legacy.forwardingTarget(for: sel))      // the notification now ends in doesNotRecognizeSelector
        XCTAssertFalse(legacy.responds(to: sel))
    }

    func testTheGuardHoldsTheOriginalAndSurvivesItsRelease() {
        let w = window(); var inner: Inner? = Inner(); w.delegate = inner
        let g = WindowGuard.install(on: w) { true }
        weak var weakInner = inner; inner = nil
        XCTAssertNotNil(weakInner)                           // the guard keeps it alive
        NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: w)
        XCTAssertEqual(weakInner?.resized, 1)
        XCTAssertTrue(g.responds(to: #selector(NSWindowDelegate.windowDidResize(_:))))
    }

    func testNoChainWhateverTheNumberOfInstalls() {
        let w = window(); let inner = Inner(); w.delegate = inner
        let a = WindowGuard.install(on: w) { true }
        let b = WindowGuard.install(on: w) { false }
        XCTAssertTrue(a === b); XCTAssertTrue(a.original === inner)
        XCTAssertFalse(w.delegate!.windowShouldClose!(w))     // the latest closure wins
        XCTAssertEqual(inner.closeAsked, 0)
    }

    func testEveryWindowNotificationIsSafeWithAndWithoutAnOriginal() {
        for withOriginal in [true, false] {
            let w = window(); let inner = Inner(); if withOriginal { w.delegate = inner }
            _ = WindowGuard.install(on: w) { true }
            for n in [NSWindow.didResizeNotification, NSWindow.didMoveNotification, NSWindow.didChangeScreenNotification, NSWindow.didEndLiveResizeNotification,
                      NSWindow.willStartLiveResizeNotification, NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification,
                      NSWindow.didResignKeyNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification, NSWindow.didChangeBackingPropertiesNotification] {
                NotificationCenter.default.post(name: n, object: w)
            }
            w.setFrame(NSRect(x: 10, y: 10, width: 300, height: 260), display: false, animate: false)
            if withOriginal { XCTAssertGreaterThanOrEqual(inner.resized, 1); XCTAssertGreaterThanOrEqual(inner.moved, 1) }
        }
    }

    func testCloseStillAsksAndHonoursTheOriginal() {
        let w = window(); let inner = Inner(); w.delegate = inner
        var asked = 0, answer = true
        WindowGuard.install(on: w) { asked += 1; return answer }
        XCTAssertTrue(w.delegate!.windowShouldClose!(w)); XCTAssertEqual(asked, 1); XCTAssertEqual(inner.closeAsked, 1)
        inner.allowClose = false; XCTAssertFalse(w.delegate!.windowShouldClose!(w))
        answer = false; XCTAssertFalse(w.delegate!.windowShouldClose!(w)); XCTAssertEqual(inner.closeAsked, 2)   // refused by the guard: the original is not asked
    }

    func testDetachRestoresTheOriginalOnlyWhileTheGuardIsTheDelegate() {
        let w = window(); let inner = Inner(); w.delegate = inner
        let g = WindowGuard.install(on: w) { true }
        g.detach(); XCTAssertTrue(w.delegate === inner)
        let other = Inner(); let g2 = WindowGuard.install(on: w) { true }
        w.delegate = other; g2.detach(); XCTAssertTrue(w.delegate === other)   // someone else took over: left alone
    }

    func testNoOriginalMeansCloseIsAllowedByDefault() {
        let w = window(); let g = WindowGuard.install(on: w) { true }
        XCTAssertNil(g.original); XCTAssertTrue(g.windowShouldClose(w))
    }
}
