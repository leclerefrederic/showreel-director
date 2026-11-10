import Foundation

/// The five buttons of the music lane's toolbar (MT1).
public enum MusicToolbarButton: String, CaseIterable, Sendable {
    case beat, bars, sections, drop, analyse
    public var title: String { switch self { case .beat: return "Beat"; case .bars: return "Bars"; case .sections: return "Sections"; case .drop: return "Drop"; case .analyse: return "Analyse" } }
    public var isToggle: Bool { self != .analyse }
}

/// Which marks of the music the strip shows: view state, kept with the other layout settings of the project's `.studio` folder and independent of the film's content.
/// Snapping follows it: a scene's edge snaps to the finest kind that is shown (see `MusicToolbar.snapLevel`).
public struct MusicToolbarState: Codable, Equatable, Sendable {
    public var beat = true, bars = true, sections = true, drop = true
    public init() {}

    /// A project that never had the toolbar: it starts showing what its stored snap level snapped to (Beat: everything; Off: nothing).
    public init(migrating snap: SnapLevel) {
        switch snap {
        case .beat: break
        case .bar: beat = false
        case .section: beat = false; bars = false
        case .drop: beat = false; bars = false; sections = false
        case .off: beat = false; bars = false; sections = false; drop = false
        }
    }

    public func isOn(_ b: MusicToolbarButton) -> Bool {
        switch b { case .beat: return beat; case .bars: return bars; case .sections: return sections; case .drop: return drop; case .analyse: return false }
    }

    public func toggled(_ b: MusicToolbarButton) -> MusicToolbarState {
        var s = self
        switch b { case .beat: s.beat.toggle(); case .bars: s.bars.toggle(); case .sections: s.sections.toggle(); case .drop: s.drop.toggle(); case .analyse: break }
        return s
    }

    /// The kinds of mark that are shown.
    public var kinds: Set<GridLine.Kind> {
        var k = Set<GridLine.Kind>()
        if beat { k.insert(.beat) }; if bars { k.insert(.bar) }; if sections { k.insert(.section) }; if drop { k.insert(.drop) }
        return k
    }
}

/// What the toolbar needs to know to say what is available.
public struct MusicToolbarContext: Equatable, Sendable {
    public var hasTrack: Bool
    public var music: MusicAnalysis?
    public var building: Bool
    public var analysing: Bool
    public init(hasTrack: Bool, music: MusicAnalysis?, building: Bool = false, analysing: Bool = false) {
        self.hasTrack = hasTrack; self.music = music; self.building = building; self.analysing = analysing
    }
}

/// A section of the music: from one section mark to the next (or the end), with the name the analysis gives it.
public struct MusicSection: Equatable, Sendable {
    public let start: Double, end: Double
    public let name: String
    public let index: Int
}

public enum MusicToolbar {
    /// Why a button cannot be used now and how to get it back; nil when it can. A toggle whose data does not exist says so, and so does every button without a track.
    public static func availability(_ b: MusicToolbarButton, _ c: MusicToolbarContext) -> Unavailable? {
        guard c.hasTrack else {
            return Unavailable(.notReady, reason: "No music is attached", way: "Drop an audio file on the music lane, then run Analyse")
        }
        if b == .analyse {
            if c.building { return Unavailable(.building, reason: "A Build is running", way: "Wait for the Build to end, then run Analyse") }
            if c.analysing { return Unavailable(.busy, reason: "The track is being analysed", way: "Wait for the analysis to end") }
            return nil
        }
        guard let m = c.music else { return Unavailable(.notReady, reason: "The track is not analysed yet", way: "Run Analyse to find its \(noun(b))") }
        switch b {
        case .beat: return m.beats.isEmpty ? Unavailable(.notReady, reason: "No beats were found in this track", way: "Run Analyse again, or set the tempo by hand") : nil
        case .bars: return m.bars.isEmpty ? Unavailable(.notReady, reason: "No bars were found in this track", way: "Run Analyse again, or set the tempo by hand") : nil
        case .sections: return sections(m).count < 2 ? Unavailable(.notReady, reason: "No sections were found in this track", way: "Run Analyse again: a track with one flat part has none") : nil
        case .drop: return m.dropTimes.isEmpty ? Unavailable(.notReady, reason: "No drops were found in this track", way: "Run Analyse again: a track without a sudden rise has none") : nil
        case .analyse: return nil
        }
    }

    private static func noun(_ b: MusicToolbarButton) -> String {
        switch b { case .beat: return "beats"; case .bars: return "bars"; case .sections: return "sections"; case .drop: return "drops"; case .analyse: return "" }
    }

    /// What scenes snap to: the finest kind that is shown and exists in the track (stronger kinds included, as before); Off when none is.
    public static func snapLevel(_ s: MusicToolbarState, music m: MusicAnalysis?) -> SnapLevel {
        guard let m = m else { return .off }
        if s.beat, !m.beats.isEmpty { return .beat }
        if s.bars, !m.bars.isEmpty { return .bar }
        if s.sections, sections(m).count > 1 { return .section }
        if s.drop, !m.dropTimes.isEmpty { return .drop }
        return .off
    }

    /// The sections of the track, with the names of the analysis ("Break", "Return"); the first, from the start, is the "Intro" and a drop starts a "Drop".
    public static func sections(_ m: MusicAnalysis) -> [MusicSection] {
        var marks: [(Double, String)] = [(0, "Intro")]
        for b in m.breaks { marks.append((b.start, "Break")) }
        for r in m.returns { marks.append((r, "Return")) }
        for d in m.dropTimes where d > 0 { marks.append((d, "Drop")) }
        marks.sort { $0.0 < $1.0 }
        var out: [MusicSection] = []
        for (i, mk) in marks.enumerated() where out.last.map({ mk.0 > $0.start + 0.001 }) ?? true {
            out.append(MusicSection(start: mk.0, end: 0, name: mk.1, index: out.count))
            _ = i
        }
        let end = max(m.duration, out.last?.start ?? 0)
        return out.enumerated().map { MusicSection(start: $0.element.start, end: $0.offset + 1 < out.count ? out[$0.offset + 1].start : end, name: $0.element.name, index: $0.offset) }
    }

    /// The lane's marks without the kinds that are hidden.
    public static func filtered(_ marks: MusicGrid.LaneMarks, _ s: MusicToolbarState) -> MusicGrid.LaneMarks {
        MusicGrid.LaneMarks(beats: s.beat ? marks.beats : [], bars: s.bars ? marks.bars : [], sections: s.sections ? marks.sections : [], drops: s.drop ? marks.drops : [])
    }

    /// The end of the bar: the track's name (the tooltip gives it whole) and its tempo. Nothing about the tempo until the track is analysed.
    public static func trackSummary(file: String?, music m: MusicAnalysis?) -> (name: String, bpm: String?)? {
        guard let f = file, !f.isEmpty else { return nil }
        return ((f as NSString).lastPathComponent, m.map { String(format: "%g", ($0.bpm * 10).rounded() / 10) + " BPM" })
    }

    public static func shortName(_ n: String, limit: Int = 28) -> String {
        guard n.count > limit else { return n }
        let ext = (n as NSString).pathExtension, stem = (n as NSString).deletingPathExtension
        let keep = max(4, limit - 1 - (ext.isEmpty ? 0 : ext.count + 1))
        return String(stem.prefix(keep)) + "\u{2026}" + (ext.isEmpty ? "" : "." + ext)
    }

    /// What the analysis leaves in place: the earlier result stays until a new one was written, whatever happens to the run.
    public static func music(after outcome: Audio.Outcome, previous: MusicAnalysis?) -> MusicAnalysis? {
        if case .analysed(let a) = outcome { return a }
        return previous
    }

    /// What the Analyse button shows: nothing to say, running, or the reason of the last failure (the track is kept).
    public enum AnalyseStatus: Equatable, Sendable { case idle, running, failed(String) }
    public static func analyseStatus(analysing: Bool, notice: String?) -> AnalyseStatus {
        if analysing { return .running }
        if let n = notice, !n.isEmpty { return .failed(n) }
        return .idle
    }
}
