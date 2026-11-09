import CoreGraphics
import Foundation

// The storyboard strip as an editing timeline: every number that the views draw from comes from here (time and pixels, zoom and its anchor, the ruler's ticks,
// the sizes of the lanes, what a frame shows at its width, where a transition marker sits). The views only draw.

/// The time scale: pixels per second, and the part of the film in view.
public enum TimelineScale {
    public static let minPPS = 2.0, maxPPS = 800.0
    /// Room before the first frame and after the last, in pixels.
    public static let pad = 16.0
    /// One press of a zoom button or key.
    public static let stepFactor = 1.25

    /// What is in view: the scale and how far the content is scrolled.
    public struct Viewport: Equatable, Sendable {
        public var pps: Double
        public var scroll: Double
        public init(pps: Double, scroll: Double) { self.pps = pps; self.scroll = scroll }
    }

    public static func clamp(_ pps: Double) -> Double { min(max(pps.isFinite ? pps : 60, minPPS), maxPPS) }

    /// The scale at which the whole film (`duration`, the film or the music, whichever is longer) fits the width, with its padding.
    public static func fit(duration: Double, viewport: Double) -> Double {
        guard duration > 0, viewport > 2 * pad else { return clamp(60) }
        return clamp((viewport - 2 * pad) / duration)
    }

    public static func x(_ t: Double, pps: Double) -> Double { pad + t * pps }
    public static func time(atX x: Double, pps: Double) -> Double { (x - pad) / pps }

    /// The width of the content: the film at this scale, never less than the view (so a short film does not leave a gap in the dark).
    public static func contentWidth(duration: Double, pps: Double, viewport: Double) -> Double { max(viewport, 2 * pad + max(duration, 0) * pps) }

    public static func maxScroll(duration: Double, pps: Double, viewport: Double) -> Double { max(0, contentWidth(duration: duration, pps: pps, viewport: viewport) - viewport) }

    public static func clampScroll(_ s: Double, duration: Double, pps: Double, viewport: Double) -> Double { min(max(s.isFinite ? s : 0, 0), maxScroll(duration: duration, pps: pps, viewport: viewport)) }

    /// Zooms by `factor` keeping the time under `anchorX` (a position in the view) where it is.
    public static func zoom(_ v: Viewport, factor: Double, anchorX: Double, duration: Double, viewport: Double) -> Viewport {
        let pps = clamp(v.pps * factor)
        let t = time(atX: anchorX + v.scroll, pps: v.pps)
        return Viewport(pps: pps, scroll: clampScroll(x(t, pps: pps) - anchorX, duration: duration, pps: pps, viewport: viewport))
    }

    /// The whole film in the width: no scroll.
    public static func fitAll(duration: Double, viewport: Double) -> Viewport { Viewport(pps: fit(duration: duration, viewport: viewport), scroll: 0) }

    /// The span `start` to `end` fills the view.
    public static func fitSelection(start: Double, end: Double, duration: Double, viewport: Double) -> Viewport {
        let span = max(end - start, 0.5)
        let pps = clamp((viewport - 2 * pad) / span)
        return Viewport(pps: pps, scroll: clampScroll(x(start, pps: pps) - pad, duration: duration, pps: pps, viewport: viewport))
    }

    /// Where a zoom is anchored: the pointer when it is over the strip, else the playhead when it is in view, else the middle.
    public static func anchorX(pointerX: Double?, playheadX: Double, viewport: Double) -> Double {
        if let p = pointerX, p >= 0, p <= viewport { return p }
        if playheadX >= 0, playheadX <= viewport { return playheadX }
        return viewport / 2
    }

    /// Keeps the playhead in view while it moves: when it leaves the middle four fifths, the view jumps to put it a quarter in.
    public static func follow(_ v: Viewport, playhead t: Double, duration: Double, viewport: Double) -> Viewport {
        let px = x(t, pps: v.pps) - v.scroll
        if px >= 0.1 * viewport, px <= 0.9 * viewport { return v }
        return Viewport(pps: v.pps, scroll: clampScroll(x(t, pps: v.pps) - 0.25 * viewport, duration: duration, pps: v.pps, viewport: viewport))
    }

    /// The zoom slider is logarithmic: equal steps are equal factors.
    public static func sliderPosition(_ pps: Double) -> Double { log(clamp(pps) / minPPS) / log(maxPPS / minPPS) }
    public static func pps(sliderPosition p: Double) -> Double { clamp(minPPS * pow(maxPPS / minPPS, min(max(p, 0), 1))) }
}

public struct TimelineSizes: Equatable, Sendable {
    public let toolbar: Double
    public let ruler: Double
    /// A row above the frames for the transition markers, only when the frames are too low to hold them without covering a label.
    public let markerRow: Double
    public let frame: Double
    public let music: Double
    public let gap: Double
    public let padding: Double
    public var total: Double { toolbar + ruler + markerRow + frame + gap + music + 2 * padding }
}

/// The lanes of the strip, from the height of its panel.
public enum TimelineLayout {
    public static let toolbar = 44.0, ruler = 28.0, padding = 10.0, gap = 6.0
    public static let minFrame = 44.0, minMusic = 36.0, absoluteMinFrame = 36.0
    public static let markerRowHeight = 24.0
    /// Below this frame height a marker in the middle of the cut would touch the label or the duration of a frame.
    public static let markerMiddleThreshold = 72.0

    /// The toolbar has one row when the strip is wide, two when it is the width of the centre column (the zoom, the snap and the actions go on the second row).
    public static let wideToolbar = 860.0
    public static func toolbarRows(width: Double) -> Int { width >= wideToolbar ? 1 : 2 }

    public static func sizes(panelHeight: Double, hasMusic: Bool, toolbarRows: Int = 1) -> TimelineSizes {
        let avail = max(0, panelHeight - toolbar * Double(toolbarRows) - ruler - 2 * padding - gap)
        let floorMusic = hasMusic ? 56.0 : 72.0           // an empty lane holds a text and a button
        var music = min(max(avail * (hasMusic ? 0.30 : 0.24), floorMusic), 170)
        var frame = avail - music
        if frame < minFrame { music = max(minMusic, avail - minFrame); frame = avail - music }
        var row = 0.0
        if frame < markerMiddleThreshold {
            row = markerRowHeight
            music = max(minMusic, music - row)
            frame = max(absoluteMinFrame, avail - music - row)
        }
        return TimelineSizes(toolbar: toolbar * Double(toolbarRows), ruler: ruler, markerRow: row, frame: frame, music: music, gap: gap, padding: padding)
    }
}

/// What a frame shows at the width it has. The scene's ID is kept at every zoom; its name only when there is room.
public enum LabelMode: Equatable, Sendable { case none, shortID, id, idAndName }

public struct FrameElements: Equatable, Sendable {
    public let mode: LabelMode
    public let label: CGRect?
    public let pill: CGRect?              // the duration
    public let status: CGRect?            // the review state
    /// How many thumbnails are laid side by side, each at the 16:9 shape of the lane's height. Always 1 while a scene has a single still: real frames at different times (phase W4) will make more.
    public let thumbTiles: Int
    public let thumbWidth: Double
}

public enum FrameLayout {
    public static let fontSize = 11.0                     // nothing is drawn under 11 pt
    static let glyph = 7.2                                // the width of a character of the 11 pt label, bold monospace

    public static func mode(width: Double, hasName: Bool) -> LabelMode {
        if width < 22 { return .none }
        if width < 44 { return .shortID }
        return hasName && width >= 120 ? .idAndName : .id
    }

    public static func elements(width: Double, height: Double, hasName: Bool, idLength: Int = 3, nameLength: Int = 0) -> FrameElements {
        let m = mode(width: width, hasName: hasName)
        var label: CGRect?
        switch m {
        case .none: label = nil
        case .shortID: label = CGRect(x: 4, y: 4, width: 2 * glyph + 10, height: 18)
        case .id: label = CGRect(x: 4, y: 4, width: Double(idLength) * glyph + 10, height: 18)
        case .idAndName: label = CGRect(x: 4, y: 4, width: min(Double(idLength + 3 + nameLength) * glyph + 10, width * 0.7), height: 18)
        }
        let pill = width >= 54 && height >= 50 ? CGRect(x: 4, y: height - 22, width: 46, height: 18) : nil
        let status = width >= 70 ? CGRect(x: width - 22, y: 4, width: 18, height: 18) : nil
        // a scene has one still: one thumbnail, never repeated, until real frames at different times exist (phase W4)
        let tw = max(height, 1) * 16 / 9
        return FrameElements(mode: m, label: label, pill: pill, status: status, thumbTiles: 1, thumbWidth: tw)
    }
}

/// Where the diamond of a transition sits: centred on the cut, in the middle of the frames' height, or in the row above them when they are too low.
public struct MarkerPlacement: Equatable, Sendable {
    public let visible: Bool
    public let size: Double
    public let above: Bool
    /// In the lane's own coordinates: x along the time, y from the top of the frames.
    public let rect: CGRect
    /// A generous area to click.
    public var hit: CGRect { rect.insetBy(dx: -8, dy: -8) }
}

public enum MarkerLayout {
    public static func place(cutX: Double, prevWidth: Double, nextWidth: Double, sizes: TimelineSizes) -> MarkerPlacement {
        let room = min(prevWidth, nextWidth)
        let above = sizes.markerRow > 0
        let size = min(min(max(room * 0.7, 16), 26), above ? sizes.markerRow - 2 : 26)       // in its row, the diamond fits the row
        let y = above ? -sizes.markerRow + (sizes.markerRow - size) / 2 : (sizes.frame - size) / 2
        return MarkerPlacement(visible: room >= 14, size: size, above: above, rect: CGRect(x: cutX - size / 2, y: y, width: size, height: size))
    }
}

// MARK: the ruler

public struct RulerTick: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case time, bar, beat }
    public let time: Double
    public let kind: Kind
    public let major: Bool
    public let label: String?
}

public enum TimelineRuler {
    /// The distance between two labels, at least, in pixels.
    public static let labelSpacing = 64.0
    static let steps = [0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600]

    /// The step between two labelled ticks: the smallest of a short list of round values that keeps the labels apart.
    public static func majorStep(pps: Double) -> Double { steps.first { $0 * pps >= labelSpacing } ?? steps.last! }

    public static func label(_ t: Double, step: Double) -> String {
        let m = Int(t / 60), s = t - Double(m * 60)
        if step >= 1 { return String(format: "%d:%02d", m, Int(s.rounded())) }
        return String(format: step < 0.1 ? "%d:%05.2f" : "%d:%04.1f", m, s)
    }

    /// The ticks between two times: round times (labelled), their subdivisions, and, when the music is analysed, its bars (numbered, thinned so the numbers stay
    /// apart) and, close in, its beats.
    public static func ticks(pps: Double, from a: Double, to b: Double, bars: [Double] = [], beats: [Double] = []) -> [RulerTick] {
        guard pps > 0, b >= a else { return [] }
        let step = majorStep(pps: pps)
        let subs: Int = [0.1, 0.5, 1, 5, 10, 30, 60, 300].contains(step) ? 5 : step == 0.05 ? 5 : 4
        let sub = step / Double(subs)
        var out: [RulerTick] = []
        var i = max(0, Int((a / sub).rounded(.down)) - 1)
        while Double(i) * sub <= b + sub {
            let t = (Double(i) * sub * 1000).rounded() / 1000
            let major = i % subs == 0
            if t >= 0, sub * pps >= 6 || major { out.append(RulerTick(time: t, kind: .time, major: major, label: major ? label(t, step: step) : nil)) }
            i += 1
        }
        if bars.count > 1 {
            let spacing = (bars[1] - bars[0]) * pps
            var every = 1
            while spacing * Double(every) < 56, every < 64 { every *= 2 }
            for (n, t) in bars.enumerated() where t >= a - 1 && t <= b + 1 && n % every == 0 { out.append(RulerTick(time: t, kind: .bar, major: true, label: "\(n + 1)")) }
        }
        if beats.count > 1, (beats[1] - beats[0]) * pps >= 14 {
            for t in beats where t >= a - 1 && t <= b + 1 { out.append(RulerTick(time: t, kind: .beat, major: false, label: nil)) }
        }
        return out
    }
}

// MARK: moving around the film

public enum TimelineNav {
    /// The scene on screen at a time of the film: the first whose span holds it; the last scene also holds the very end.
    public static func scene(at t: Double, in f: ShowreelFile) -> ShowreelFile.Scene? {
        let tl = f.timeline()
        for (i, s) in tl.enumerated() {
            guard let a = s.start, let b = s.end else { continue }
            if t >= a && (t < b || (i == tl.count - 1 && t <= b)) { return s.scene }
        }
        return nil
    }

    /// The scene `delta` places from this one among the scenes that are on, with its start. nil past either end. With no scene given, the one under the playhead.
    public static func step(from id: String?, by delta: Int, playhead: Double, in f: ShowreelFile) -> (id: String, start: Double)? {
        let tl = f.timeline()
        guard !tl.isEmpty else { return nil }
        let here = id.flatMap { i in tl.firstIndex { $0.scene.id == i } } ?? scene(at: playhead, in: f).flatMap { s in tl.firstIndex { $0.scene.id == s.id } }
        let at = here ?? (delta > 0 ? -1 : tl.count)
        let i = at + delta
        guard tl.indices.contains(i), let start = tl[i].start else { return nil }
        return (tl[i].scene.id, start)
    }

    /// The span a "fit selection" shows: a scene, or the two scenes a transition joins; nil when nothing in the film is selected.
    public static func span(of id: String, transition: Bool, in f: ShowreelFile) -> (start: Double, end: Double)? {
        let tl = f.timeline()
        guard let i = tl.firstIndex(where: { $0.scene.id == id }), let a = tl[i].start else { return nil }
        if transition, i + 1 < tl.count, let e = tl[i + 1].end { return (a, e) }
        guard let e = tl[i].end else { return nil }
        return (a, e)
    }

    /// How long the film is, for fitting it to the width: where the last scene on ends (a scene with no duration counts for 3 s), at least a second.
    public static func filmLength(_ f: ShowreelFile) -> Double {
        let ends = f.timeline().compactMap { $0.end ?? $0.start.map { $0 + 3 } }
        return max(ends.max() ?? 0, 1)
    }

    /// How far the timeline extends: the film, the music if it is longer, and the target duration.
    public static func contentLength(_ f: ShowreelFile, music: Double) -> Double { max(filmLength(f), music, f.decisions.duration ?? 0) }

    /// The playhead after `dt` seconds of playing, and whether the film ended.
    public static func advance(_ t: Double, by dt: Double, end: Double) -> (time: Double, ended: Bool) {
        let n = t + dt
        return n >= end ? (end, true) : (n, false)
    }

    public static func timecode(_ t: Double) -> String {
        let m = Int(t / 60), s = t - Double(m * 60)
        return String(format: "%d:%04.1f", m, max(0, s))
    }
}
