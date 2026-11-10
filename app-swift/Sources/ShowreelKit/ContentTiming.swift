import Foundation

/// When an item is on screen, inside its scene: from `start` to `end`, in seconds from the scene's first instant. A bound left nil is not fixed: the item is there from the start,
/// or to the end. Both nil is auto: the AI decides, and the item behaves as it always did.
public struct ContentTimes: Equatable, Sendable {
    public var start: Double?
    public var end: Double?
    public init(start: Double? = nil, end: Double? = nil) { self.start = start; self.end = end }
    public var isFixed: Bool { start != nil || end != nil }
    /// "auto", "in 1 s, out 3 s", "in 2 s, to the end", "from the start, out 3 s".
    public var text: String {
        guard isFixed else { return "auto" }
        return [start.map { "in \(ProjectDocs.seconds($0)) s" } ?? "from the start", end.map { "out \(ProjectDocs.seconds($0)) s" } ?? "to the end"].joined(separator: ", ")
    }
}

/// The rules of timing inside a scene. Pure: the app draws and edits with them, and the tests read them.
public enum ContentTiming {
    public static let minLength = 0.1
    static let eps = 1e-9
    public static func round3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
    private static func s(_ v: Double) -> String { ProjectDocs.seconds(v) }

    /// Why a timing cannot be set, in words that say the way out; nil when it can. Inside the scene, In before Out by at least 0.1 s; without a duration only the order is checked.
    public static func validate(_ t: ContentTimes, duration: Double?) -> String? {
        if let a = t.start, a < -eps { return "In cannot be before the start of the scene: use 0 s or more." }
        if let d = duration {
            if let b = t.end, b > d + eps { return "Out cannot be after the end of the scene (\(s(d)) s): use \(s(d)) s or less, or lengthen the scene first." }
            if let a = t.start, a > d - minLength + eps { return "In must leave at least 0.1 s before the end of the scene (\(s(d)) s)." }
        }
        if let a = t.start, let b = t.end, b - a < minLength - eps { return "Out must be at least 0.1 s after In (in \(s(a)) s, out \(s(b)) s)." }
        if t.start == nil, let b = t.end, b < minLength - eps { return "Out must be at least 0.1 s." }
        return nil
    }

    /// Whether an item is on screen at a time of its scene: from In (or the start) up to, not including, Out (or the end); an item that runs to the end is still there on the last instant.
    public static func isActive(_ i: ShowreelFile.ContentItem, at t: Double, duration: Double?) -> Bool {
        let a = i.timeIn ?? 0, b = i.timeOut ?? duration ?? .infinity
        if t < a - eps { return false }
        if t < b - eps { return true }
        if let d = duration, b >= d - eps, t <= d + eps { return true }
        return false
    }

    /// The items on screen at a time of the scene, in priority order (overlap is allowed).
    public static func active(in scene: ShowreelFile.Scene, at t: Double) -> [ShowreelFile.ContentItem] {
        scene.content.filter { isActive($0, at: t, duration: scene.duration) }
    }

    /// The scene's duration changed: a time beyond the new end is pulled back to it (and In keeps 0.1 s before it); a time that was the old end follows a longer scene; the rest stays.
    /// Returns the cards' lines: the item and what became of its timing.
    @discardableResult
    public static func follow(_ scene: inout ShowreelFile.Scene, from old: Double?, to new: Double) -> [Change] {
        var out: [Change] = []
        for k in scene.content.indices {
            let before = scene.content[k].timing
            var a = before.start, b = before.end
            if let o = old, new > o + eps, let e = b, abs(e - o) < eps { b = new }
            if let e = b, e > new + eps { b = new }
            if let x = a, x > new - minLength + eps { a = max(0, round3(new - minLength)) }
            if ContentTimes(start: a, end: b) != before {
                scene.content[k].timeIn = a; scene.content[k].timeOut = b
                out.append(Change("\(scene.id) \(scene.content[k].id) timing", before.text, ContentTimes(start: a, end: b).text))
            }
        }
        return out
    }

    /// The times at which what is on screen is not the same as before, in order, each with the items on screen from it: the scene's states. Nothing on screen is not a state.
    public static func states(of scene: ShowreelFile.Scene) -> [(time: Double, ids: [String])] {
        guard let d = scene.duration, d > 0 else { return scene.content.isEmpty ? [] : [(0, scene.content.map { $0.id })] }
        var cuts: Set<Double> = [0, d]
        for i in scene.content { for v in [i.timeIn, i.timeOut] { if let v = v, v > 0, v < d { cuts.insert(round3(v)) } } }
        let p = cuts.sorted(); var out: [(time: Double, ids: [String])] = []
        for k in 0..<(p.count - 1) {
            let mid = (p[k] + p[k + 1]) / 2, ids = active(in: scene, at: mid).map { $0.id }
            if ids.isEmpty || out.contains(where: { $0.ids == ids }) { continue }
            out.append((mid, ids))
        }
        return out
    }

    /// The time a single still of the scene is taken at: three quarters through when every item is there all along (as the strip always did), else the middle of the busiest state.
    public static func stillTime(of scene: ShowreelFile.Scene) -> Double {
        let d = scene.duration ?? 4
        guard scene.content.contains(where: { $0.timing.isFixed }) else { return d * 0.75 }
        return states(of: scene).max { $0.ids.count < $1.ids.count }?.time ?? d * 0.75
    }

    /// The times of the thumbnails of a scene: one, unless the scene has several states that differ (real frames at different times), and never more than `limit`.
    public static func stills(of scene: ShowreelFile.Scene, limit: Int) -> [Double] {
        let st = states(of: scene)
        if st.count < 2 || limit < 2 { return [stillTime(of: scene)] }
        return st.prefix(limit).map { $0.time }
    }
}
