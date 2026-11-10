import AppKit

/// The one close guard of a window. It stands in front of the window's own delegate (SwiftUI's), asks `shouldClose` before the window closes and leaves everything else to that delegate.
/// AppKit registers a window's delegate for every `windowDid…` notification it responds to when it is set, so the guard must always be able to answer what it claims:
/// it holds the original delegate strongly (a window does not retain its delegate: no cycle), never wraps another guard, and gives the common notifications an explicit, safe path.
public final class WindowGuard: NSObject, NSWindowDelegate {
    public private(set) var original: NSWindowDelegate?
    public var shouldClose: () -> Bool
    private weak var window: NSWindow?

    init(shouldClose: @escaping () -> Bool) { self.shouldClose = shouldClose }

    /// Puts the guard on the window, or updates the one already there (never a chain).
    @discardableResult
    public static func install(on w: NSWindow, shouldClose: @escaping () -> Bool) -> WindowGuard {
        if let g = w.delegate as? WindowGuard { g.shouldClose = shouldClose; return g }
        let g = WindowGuard(shouldClose: shouldClose)
        g.original = w.delegate; g.window = w
        w.delegate = g
        return g
    }

    /// Gives the original delegate back (only when the guard is still the window's delegate), so that AppKit registers the right observer again.
    public func detach() {
        guard let w = window, w.delegate === self else { return }
        w.delegate = original
        window = nil
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard shouldClose() else { return false }
        return original?.windowShouldClose?(sender) ?? true
    }

    public override func responds(to s: Selector!) -> Bool { super.responds(to: s) || (original?.responds(to: s) ?? false) }
    public override func forwardingTarget(for s: Selector!) -> Any? { (original?.responds(to: s) ?? false) ? original : super.forwardingTarget(for: s) }

    // Explicit paths: whatever happens to `original`, these never reach an unrecognized selector.
    public func windowDidResize(_ n: Notification) { original?.windowDidResize?(n) }
    public func windowDidMove(_ n: Notification) { original?.windowDidMove?(n) }
    public func windowDidChangeScreen(_ n: Notification) { original?.windowDidChangeScreen?(n) }
    public func windowDidEndLiveResize(_ n: Notification) { original?.windowDidEndLiveResize?(n) }
    public func windowWillStartLiveResize(_ n: Notification) { original?.windowWillStartLiveResize?(n) }
    public func windowDidEnterFullScreen(_ n: Notification) { original?.windowDidEnterFullScreen?(n) }
    public func windowDidExitFullScreen(_ n: Notification) { original?.windowDidExitFullScreen?(n) }
    public func windowDidBecomeKey(_ n: Notification) { original?.windowDidBecomeKey?(n) }
    public func windowDidResignKey(_ n: Notification) { original?.windowDidResignKey?(n) }
    public func windowDidMiniaturize(_ n: Notification) { original?.windowDidMiniaturize?(n) }
    public func windowDidDeminiaturize(_ n: Notification) { original?.windowDidDeminiaturize?(n) }
    public func windowDidChangeBackingProperties(_ n: Notification) { original?.windowDidChangeBackingProperties?(n) }
    public func windowWillClose(_ n: Notification) { original?.windowWillClose?(n) }
}
