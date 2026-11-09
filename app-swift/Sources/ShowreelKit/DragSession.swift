import Foundation
import ImageIO

/// The state of one drag, and the one way it ends. Whatever the outcome (dropped, refused, outside any target, cancelled), `finish` gives back a clean session: nothing of the
/// drag stays behind to hold the lists or the targets.
public struct DragRun: Equatable, Sendable {
    public enum Outcome: String, Sendable { case dropped, refused, outsideTarget, cancelled }

    public private(set) var item: DragItem?
    public private(set) var hover: DropTarget?
    public private(set) var lastValid: (item: DragItem, target: DropTarget)?
    /// Whether any drop target ever reported this drag (the log says so when none did).
    public private(set) var seenByATarget = false
    public private(set) var startedAt: Date?

    public init() {}
    public static func == (a: DragRun, b: DragRun) -> Bool { a.item == b.item && a.hover == b.hover && a.seenByATarget == b.seenByATarget && a.startedAt == b.startedAt && a.lastValid?.item == b.lastValid?.item && a.lastValid?.target == b.lastValid?.target }

    public var isActive: Bool { item != nil }

    public mutating func begin(_ i: DragItem, at t: Date = Date()) { self = DragRun(); item = i; startedAt = t }
    public mutating func over(_ t: DropTarget?, valid: Bool) {
        seenByATarget = true; hover = t
        if valid, let i = item, let t = t { lastValid = (i, t) }
    }
    public mutating func reported() { seenByATarget = true }

    /// Ends the drag: back to zero. The returned line is what the log keeps.
    @discardableResult
    public mutating func finish(_ outcome: Outcome, at t: Date = Date()) -> String {
        let what = item.map { DragLog.name(of: $0) } ?? "none"
        let ms = startedAt.map { Int(t.timeIntervalSince($0) * 1000) } ?? 0
        let seen = seenByATarget
        self = DragRun()
        return "drag end \(what) \(outcome.rawValue) after \(ms) ms" + (seen ? "" : " (no drop target ever saw this drag)")
    }
}

/// Small pictures kept in memory, so that drawing a row or building the preview of a drag never reads a file on the main thread. `cached` only looks in memory;
/// `load` reads the file and is called off the main thread.
public final class ThumbnailCache: @unchecked Sendable {
    public static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, CGImage>()
    private let lock = NSLock()
    private var loading: Set<String> = []
    public init() { cache.countLimit = 300 }

    public func cached(_ key: String) -> CGImage? { cache.object(forKey: key as NSString) }
    public func store(_ image: CGImage, key: String) { cache.setObject(image, forKey: key as NSString) }

    /// True the first time it is asked for a key that is not cached nor being loaded: the caller then loads it.
    public func shouldLoad(_ key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if cache.object(forKey: key as NSString) != nil || loading.contains(key) { return false }
        loading.insert(key); return true
    }
    public func done(_ key: String) { lock.lock(); loading.remove(key); lock.unlock() }

    /// Reads the file as a small picture (a bitmap format the system reads; nil for anything else) and keeps it.
    @discardableResult
    public func load(_ url: URL, key: String, maxPixel: Int = 128) -> CGImage? {
        defer { done(key) }
        guard let s = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel]
        guard let img = CGImageSourceCreateThumbnailAtIndex(s, 0, opts as CFDictionary) else { return nil }
        store(img, key: key)
        return img
    }
}
