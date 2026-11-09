import Foundation

/// How many scenes may be written at once, and the lowering of that number when the API limits requests: by one, never below 1, and not again for a few seconds (the scenes in flight
/// all meet the same limit at the same moment).
final class WidthGate: @unchecked Sendable {
    nonisolated(unsafe) static var debounce: TimeInterval = 15
    private let lock = NSLock(); private var width: Int; private var last = Date.distantPast
    init(_ w: Int) { width = max(AgentLimits.minSceneWidth, w) }
    var current: Int { lock.lock(); defer { lock.unlock() }; return width }
    /// The new width when it was lowered, nil when it was not (already 1, or lowered a moment ago).
    func lower() -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard width > AgentLimits.minSceneWidth, Date().timeIntervalSince(last) >= Self.debounce else { return nil }
        width -= 1; last = Date(); return width
    }
}

/// What a Build measured: the speed of the model (output tokens a second), the size of a scene, the real duration and the cumulated generation time. Kept as one line of the
/// journal (its `after` holds the figures), so that the next card can estimate from them.
public enum BuildStats {
    public struct Measure: Equatable, Sendable {
        public var tokensPerSecond: Double
        public var sceneTokens: Int
        public var width: Int
        public var real: TimeInterval
        public var generation: TimeInterval
        public var scenes: Int
    }

    static let title = "Build measured"

    /// Records the figures of the Build that just ended, from its activity: only when scenes were written (a Build that only copied measured nothing).
    static func record(version: String, store: ProjectStore, real: TimeInterval) {
        guard let b = store.activity.snapshot.build, b.version == version else { return }
        let written = b.order.compactMap { b.runs[$0] }.filter { !$0.kept && $0.requestSeconds > 0 && $0.tokens > 0 }
        let secs = written.reduce(0) { $0 + $1.requestSeconds }, tokens = written.reduce(0) { $0 + $1.tokens }
        guard !written.isEmpty, secs >= 1 else { return }
        let scenes = b.order.filter { $0 != BuildJob.frameStep }.compactMap { b.runs[$0] }.filter { !$0.kept && $0.requestSeconds > 0 && $0.tokens > 0 }
        let m = Measure(tokensPerSecond: Double(tokens) / secs, sceneTokens: scenes.isEmpty ? tokens / written.count : scenes.reduce(0) { $0 + $1.tokens } / scenes.count,
                        width: b.width, real: real, generation: b.generationSeconds, scenes: scenes.count)
        write(m, version: version, store: store)
    }

    public static func write(_ m: Measure, version: String, store: ProjectStore) {
        let after = "tps=\(String(format: "%.1f", m.tokensPerSecond)) tokens=\(m.sceneTokens) width=\(m.width) real=\(Int(m.real)) generation=\(Int(m.generation)) scenes=\(m.scenes)"
        store.noteEvent(author: "app", op: "build", target: version, title: title, after: after,
                        note: "\(Int(m.tokensPerSecond.rounded())) tokens a second, about \(m.sceneTokens) tokens a scene, \(m.scenes) scene\(m.scenes == 1 ? "" : "s") at \(m.width) at once: \(Int(m.real / 60)) min real, \(Int(m.generation / 60)) min of generation")
        BuildLog.log?.note("\(store.root.lastPathComponent) \(version)", title + " | " + after)
    }

    /// The figures of the project's last Build that measured some.
    public static func last(_ store: ProjectStore) -> Measure? {
        guard let e = store.journal.entries().last(where: { $0.op == "build" && $0.title == title }) else { return nil }
        var kv: [String: Double] = [:]
        for part in e.after.split(separator: " ") { let p = part.split(separator: "="); if p.count == 2, let d = Double(p[1]) { kv[String(p[0])] = d } }
        guard let tps = kv["tps"], tps > 0 else { return nil }
        return Measure(tokensPerSecond: tps, sceneTokens: Int(kv["tokens"] ?? 0), width: Int(kv["width"] ?? 1), real: kv["real"] ?? 0, generation: kv["generation"] ?? 0, scenes: Int(kv["scenes"] ?? 0))
    }

    /// The time a Build of `calls` requests would take at `width` at once, in seconds: the frame alone first, then the scenes in a window. An estimate, never a promise.
    public static func estimate(scenes: Int, frame: Bool, width: Int, store: ProjectStore) -> (seconds: TimeInterval, tps: Double, measured: Bool) {
        let m = last(store)
        let tps = m?.tokensPerSecond ?? AgentLimits.defaultTokensPerSecond
        let tokens = Double((m?.sceneTokens ?? 0) > 0 ? m!.sceneTokens : AgentLimits.defaultSceneTokens)
        let one = tokens / tps
        let w = Double(max(1, min(width, scenes)))
        return ((frame ? one : 0) + (scenes == 0 ? 0 : max(one, Double(scenes) * one / w)), tps, m != nil)
    }
}
