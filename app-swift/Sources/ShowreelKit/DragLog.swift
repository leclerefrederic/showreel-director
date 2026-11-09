import Foundation

/// What the app writes about a drag, so that a drag that does nothing can be read afterwards: where it started, what it passed over and what the release did. Bounded
/// (about 100 KB, then the file is rotated to `drag.log.1`), outside the project and the app bundle, and with no file content and no user path in it.
public final class DragLog: @unchecked Sendable {
    public let url: URL
    public let maxBytes: Int
    private let lock = NSLock()
    private var lastLine = ""

    public static let shared = DragLog(url: standardURL)
    public static var standardURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/ShowreelStudio/drag.log")
    }

    public init(url: URL, maxBytes: Int = 100_000) { self.url = url; self.maxBytes = maxBytes }

    /// One line: the time, the event and a short detail. The same line twice in a row (a hover that did not change) is written once.
    public func note(_ event: String, _ detail: String = "") {
        let line = Self.sanitize(detail.isEmpty ? event : event + " " + detail)
        lock.lock(); defer { lock.unlock() }
        guard line != lastLine else { return }
        lastLine = line
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let text = f.string(from: Date()) + " " + String(line.prefix(600)) + "\n"
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if size + text.utf8.count > maxBytes {
            let old = url.appendingPathExtension("1")
            try? fm.removeItem(at: old)
            try? fm.moveItem(at: url, to: old)
        }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd(); try? h.write(contentsOf: Data(text.utf8))
        } else { try? Data(text.utf8).write(to: url, options: .atomic) }
    }

    /// Takes the user's folders out of a text: the home folder becomes "~", any other path of two or more parts becomes "<path>".
    public static func sanitize(_ s: String) -> String {
        var t = s.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        t = t.replacingOccurrences(of: #"/Users/[^/\s"']+"#, with: "~", options: .regularExpression)
        t = t.replacingOccurrences(of: #"~(/[^\s"']+)+"#, with: "<path>", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<![\w:.])(/[^/\s"']+){2,}"#, with: "<path>", options: .regularExpression)
        return t.replacingOccurrences(of: "\n", with: " ")
    }

    public static func name(of target: DropTarget) -> String {
        switch target {
        case .scene(let s): return "scene \(s)"
        case .sceneNode(let s, let g, let n): return "node \(s)/\(g)" + (n.map { "/" + $0 } ?? "")
        case .contentItem(let s, let i): return "item \(s)/\(i)"
        case .contentSlot(let s, let b): return "contentSlot \(s) before \(b ?? "end")"
        case .reelSlot(let b): return "reelSlot before \(b ?? "end")"
        case .librarySlot(let b): return "librarySlot before \(b ?? "end")"
        case .assetSlot(let b): return "assetSlot before \(b ?? "end")"
        case .marker(let f): return "marker after \(f)"
        case .resourceList: return "resourceList"
        case .musicLane: return "musicLane"
        }
    }

    /// The item by its kind and identifier only; files by their number, never their names.
    public static func name(of item: DragItem) -> String {
        if case .files(let u) = item { return "files(\(u.count))" }
        return item.token.replacingOccurrences(of: "studio:", with: "")
    }
}

/// What dropping a dragged token on a target does, as one pure function: the views relay, this decides. A token that was lost or cannot be read is a refusal with its own
/// message, never a silent nothing.
public enum DropPlan {
    public enum Outcome: Equatable, Sendable {
        case operation(String)
        case refused(String)
        public var isValid: Bool { if case .operation = self { return true }; return false }
        public var text: String { switch self { case .operation(let s), .refused(let s): return s } }
    }

    public static let lostToken = "The dragged item was lost on the way (its identifier could not be read). Drag it again from the list."

    public static func item(token: String?) -> DragItem? { token.flatMap { DragItem(token: $0) } }

    public static func resolve(token: String?, target: DropTarget, store: ProjectStore) -> Outcome {
        guard let item = item(token: token) else { return .refused(lostToken) }
        if let why = Drops.kindRefusal(item, target) { return .refused(why) }
        switch Drops.verdict(item, on: target, store: store) {
        case .ok(let t): return .operation(t)
        case .refused(let why): return .refused(why)
        }
    }

    /// Does it. The result is the typed operation's own title ("Link Acme Logo.svg to S03") or the refusal.
    @discardableResult
    public static func perform(token: String?, target: DropTarget, store: ProjectStore) -> (outcome: Outcome, result: DropResult?) {
        let o = resolve(token: token, target: target, store: store)
        guard o.isValid, let item = item(token: token) else { return (o, nil) }
        do { let r = try Drops.drop(item, on: target, store: store); return (.operation(r.title), r) }
        catch { return (.refused(error.localizedDescription), nil) }
    }

    /// The words of the bottom line after a release.
    public static func doneLine(_ title: String) -> String {
        title.hasPrefix("Link ") ? "Linked " + title.dropFirst(5) : title
    }
}
