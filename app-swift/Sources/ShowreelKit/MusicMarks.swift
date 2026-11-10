import Foundation

/// A line of the grid drawn over the frames, or a mark on the music lane.
public struct GridLine: Equatable, Sendable {
    public enum Kind: Int, Comparable, Sendable {
        case beat = 0, bar = 1, section = 2, drop = 3
        public static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }
    public let time: Double
    public let kind: Kind
    /// A bar's number, a section's name ("Break", "Return") or "Drop"; nil when there is nothing to say.
    public let label: String?
}

/// Where the music's grid is drawn, and how much of it, at a given zoom and snap level. The views only draw what these functions give.
public enum MusicGrid {
    /// No two lines of the grid are closer than this, in points.
    public static let minSpacing = 12.0
    /// Two numbers or names on the lane are never closer than this.
    public static let labelSpacing = 44.0

    /// The kinds the grid shows at a snap level: it follows what scenes will snap to, and anything stronger. Off shows nothing.
    public static func kinds(for level: SnapLevel) -> Set<GridLine.Kind> {
        switch level {
        case .beat: return [.beat, .bar, .section, .drop]
        case .bar: return [.bar, .section, .drop]
        case .section: return [.section, .drop]
        case .drop: return [.drop]
        case .off: return []
        }
    }

    /// The sections' names: a break and the return after it, as the analysis names them; the start of the track has none.
    static func sectionMarks(_ m: MusicAnalysis) -> [(time: Double, label: String?)] {
        var out: [(Double, String?)] = [(0, nil)]
        for b in m.breaks { out.append((b.start, "Break")) }
        for r in m.returns { out.append((r, "Return")) }
        return out.sorted { $0.0 < $1.0 }.map { (time: $0.0, label: $0.1) }
    }

    /// Every candidate line of a kind inside the window, with a number for bars.
    static func candidates(_ m: MusicAnalysis, kinds: Set<GridLine.Kind>) -> [GridLine] {
        var out: [GridLine] = []
        if kinds.contains(.beat) { out += m.beats.map { GridLine(time: $0, kind: .beat, label: nil) } }
        if kinds.contains(.bar) { out += m.bars.enumerated().map { GridLine(time: $0.element, kind: .bar, label: "\($0.offset + 1)") } }
        if kinds.contains(.section) { out += sectionMarks(m).map { GridLine(time: $0.time, kind: .section, label: $0.label) } }
        if kinds.contains(.drop) { out += m.dropTimes.map { GridLine(time: $0, kind: .drop, label: "Drop") } }
        return out
    }

    /// Keeps every `k`-th item (k a power of two) so that the kept ones are at least `minPoints` apart, whatever the zoom.
    static func thinned(_ times: [GridLine], pps: Double, minPoints: Double) -> [GridLine] {
        guard times.count > 1 else { return times }
        let avg = (times[times.count - 1].time - times[0].time) / Double(times.count - 1)
        var k = 1
        while avg * pps * Double(k) < minPoints, k < 4096 { k *= 2 }
        return k == 1 ? times : times.enumerated().filter { $0.offset % k == 0 }.map { $0.element }
    }

    /// The lines to draw over the frames between two times. Nothing without an analysed track, with the grid hidden or with snapping off. The weaker kind (beats before bars,
    /// bars before sections, sections before drops) gives way, so that no two lines are closer than `minSpacing` points.
    public static func lines(_ m: MusicAnalysis?, level: SnapLevel, visible: Bool, pps: Double, from a: Double, to b: Double, only shown: Set<GridLine.Kind>? = nil) -> [GridLine] {
        guard visible, let m = m, pps > 0, b >= a else { return [] }
        let kinds = shown.map { Self.kinds(for: level).intersection($0) } ?? Self.kinds(for: level)
        var all = candidates(m, kinds: kinds)
        // thin each of the two dense kinds on its own, so that a bar line stays when beats are dropped
        let beats = thinned(all.filter { $0.kind == .beat }, pps: pps, minPoints: minSpacing)
        let bars = thinned(all.filter { $0.kind == .bar }, pps: pps, minPoints: minSpacing)
        all = beats + bars + all.filter { $0.kind == .section || $0.kind == .drop }
        let window = all.filter { $0.time >= a - 1 && $0.time <= b + 1 }.sorted { $0.time == $1.time ? $0.kind > $1.kind : $0.time < $1.time }
        var kept: [GridLine] = []
        for l in window {
            while let last = kept.last, (l.time - last.time) * pps < minSpacing {
                if l.kind > last.kind || (l.kind == last.kind && l.time == last.time) { kept.removeLast() } else { break }
            }
            if let last = kept.last, (l.time - last.time) * pps < minSpacing { continue }
            kept.append(l)
        }
        return kept
    }

    /// The marks of the music lane: beat ticks, bar numbers, section limits with their names, and the drops. Nothing without an analysed track.
    public struct LaneMarks: Equatable, Sendable {
        public var beats: [Double] = []
        public var bars: [GridLine] = []
        public var sections: [GridLine] = []
        public var drops: [GridLine] = []
        public var isEmpty: Bool { beats.isEmpty && bars.isEmpty && sections.isEmpty && drops.isEmpty }
    }

    public static func laneMarks(_ m: MusicAnalysis?, pps: Double, from a: Double, to b: Double) -> LaneMarks {
        guard let m = m, pps > 0, b >= a else { return LaneMarks() }
        func inside(_ t: Double) -> Bool { t >= a - 1 && t <= b + 1 }
        var out = LaneMarks()
        out.beats = thinned(m.beats.map { GridLine(time: $0, kind: .beat, label: nil) }, pps: pps, minPoints: 8).map { $0.time }.filter(inside)
        out.bars = thinned(m.bars.enumerated().map { GridLine(time: $0.element, kind: .bar, label: "\($0.offset + 1)") }, pps: pps, minPoints: labelSpacing).filter { inside($0.time) }
        out.sections = sectionMarks(m).filter { inside($0.time) && $0.time > 0 }.map { GridLine(time: $0.time, kind: .section, label: $0.label) }
        out.drops = m.dropTimes.filter(inside).map { GridLine(time: $0, kind: .drop, label: "Drop") }
        return out
    }

    /// The tooltip of a drop on the lane.
    public static func dropHelp(_ t: Double) -> String { "Drop at " + TimelineNav.timecode(t) }

    /// What the cut will land on, said as the strip says it while an edge is dragged with snapping: "Bar 5, beat 1, 0:12.4", "Drop, 0:48.0", "Break, 0:30.2" or the plain time.
    public static func snapText(_ t: Double, music m: MusicAnalysis?, level: SnapLevel) -> String {
        let time = TimelineNav.timecode(t)
        guard let m = m, level != .off else { return time }
        let tol = MusicAnalysis.tolerance
        if level == .drop || level == .section || level == .bar || level == .beat {
            if m.dropTimes.contains(where: { abs($0 - t) <= tol }) { return "Drop, \(time)" }
            if level != .drop, let s = sectionMarks(m).first(where: { abs($0.time - t) <= tol && $0.label != nil }) { return "\(s.label ?? "Section"), \(time)" }
            if m.returns.contains(where: { abs($0 - t) <= tol }), level == .drop { return "Return, \(time)" }
        }
        if level == .beat || level == .bar, let i = m.bars.firstIndex(where: { abs($0 - t) <= tol }) { return "Bar \(i + 1), beat 1, \(time)" }
        if level == .beat, let bi = m.barIndex(at: t), m.beats.contains(where: { abs($0 - t) <= tol }) {
            let beat = m.beats.filter { $0 >= m.bars[bi] - tol && $0 <= t + tol }.count
            return "Bar \(bi + 1), beat \(max(1, beat)), \(time)"
        }
        if level == .section, abs(m.snap(t, level: .section) - t) <= tol { return "Section start, \(time)" }
        return time
    }

    // MARK: what a grid line may not cover

    /// The parts of a vertical line at `x`, from 0 to `height`, that do not touch any of the rectangles (a scene's label, its duration, its review state, a transition
    /// marker): the line is drawn only there.
    public static func segments(x: Double, height: Double, avoiding rects: [CGRect]) -> [ClosedRange<Double>] {
        var blocked = rects.filter { $0.minX - 1 <= x && x <= $0.maxX + 1 }.map { max(0, Double($0.minY) - 1)...min(height, Double($0.maxY) + 1) }
        blocked.sort { $0.lowerBound < $1.lowerBound }
        var out: [ClosedRange<Double>] = []
        var y = 0.0
        for r in blocked { if r.lowerBound > y { out.append(y...r.lowerBound) }; y = max(y, r.upperBound) }
        if y < height { out.append(y...height) }
        return out
    }
}
