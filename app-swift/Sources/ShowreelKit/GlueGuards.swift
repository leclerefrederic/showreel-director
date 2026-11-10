import Foundation

/// How a page load ended. Only `failed` says something about the page; a timeout or a superseded load says nothing, so the caller retries instead of remembering a failure (RF2).
public enum LoadOutcome: Equatable, Sendable {
    case loaded, failed, timedOut, superseded
    public var isTransient: Bool { self == .timedOut || self == .superseded }
}

/// Identity-tagged completion of one page load at a time: a deferred call (the timeout) holds the token of the load it was made for, and it finishes nothing once that load is over or a newer one began.
public struct LoadGate: Sendable {
    public private(set) var current = 0
    public private(set) var isPending = false
    public init() {}

    /// Starts a load; the token of the load before it, if still pending, is no longer valid.
    public mutating func begin() -> Int { current += 1; isPending = true; return current }
    /// True only for the pending load that owns the token; a stale or repeated finish is a no-op.
    public mutating func finish(_ token: Int) -> Bool {
        guard isPending, token == current else { return false }
        isPending = false; return true
    }
}

/// The identity of a font file: the same name over two different files is two fonts (RF2). Path, size and modification date stand for the file's content.
public enum FontIdentity {
    public static func key(name: String, path: String, size: Int, modified: Date?) -> String {
        [name.lowercased(), path, String(size), modified.map { String($0.timeIntervalSince1970) } ?? ""].joined(separator: "|")
    }

    public static func key(name: String, file: URL) -> String {
        let v = try? URL(fileURLWithPath: file.path).resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return key(name: name, path: file.standardizedFileURL.path, size: v?.fileSize ?? 0, modified: v?.contentModificationDate)
    }
}

/// A held button's repeat: one step at once is the caller's, then after `delay` a step every `interval` until `stop`. Stop is idempotent and runs on release; main run loop only.
public final class HoldRepeat: ObservableObject {
    public private(set) var isRunning = false
    private var timer: Timer?
    private let delay: TimeInterval, interval: TimeInterval
    public init(delay: TimeInterval = 0.4, interval: TimeInterval = 0.12) { self.delay = delay; self.interval = interval }

    public func start(_ tick: @escaping () -> Void) {
        stop(); isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: true) { [weak self] _ in
                if self?.isRunning == true { tick() }
            }
        }
    }

    public func stop() { timer?.invalidate(); timer = nil; isRunning = false }
    deinit { timer?.invalidate() }
}
