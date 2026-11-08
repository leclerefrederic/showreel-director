import AVFoundation
import Foundation

/// The levels scenes snap to when they are stretched.
public enum SnapLevel: String, CaseIterable, Sendable {
    case beat, bar, section, drop, off
    public var title: String { switch self { case .beat: return "Beat"; case .bar: return "Bar"; case .section: return "Section"; case .drop: return "Drop"; case .off: return "Off" } }
}

/// What `scripts/analyze_audio.py` found in the project's track (analysis/beats.json and env.json). The script assumes a constant tempo.
public struct MusicAnalysis: Equatable, Sendable {
    public struct Breakdown: Equatable, Sendable { public let start: Double; public let end: Double; public let beats: Int; public let returnAt: Double?; public let intro: Bool }

    public var duration: Double
    public var bpm: Double
    public var firstBeat: Double
    public var beats: [Double]
    public var bars: [Double]
    public var barEnergy: [Double]
    public var dropBars: [Int]
    public var breakdowns: [Breakdown]
    /// The 50 fps energy envelope (0 to 255) of env.json, for the waveform when the audio file cannot be read.
    public var envelope: [Int]

    public static let tolerance = 0.06

    public static let beatsPath = "analysis/beats.json", envPath = "analysis/env.json"

    public static func load(root: URL) -> MusicAnalysis? {
        guard let d = try? Data(contentsOf: root.appendingPathComponent(beatsPath)), let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let bpm = (j["bpm"] as? NSNumber)?.doubleValue, let beats = j["beats"] as? [NSNumber], let bars = j["bars"] as? [NSNumber] else { return nil }
        func nums(_ k: String) -> [Double] { (j[k] as? [NSNumber])?.map { $0.doubleValue } ?? [] }
        let bds = (j["breakdowns"] as? [[String: Any]] ?? []).compactMap { b -> Breakdown? in
            guard let s = (b["start"] as? NSNumber)?.doubleValue, let e = (b["end"] as? NSNumber)?.doubleValue else { return nil }
            return Breakdown(start: s, end: e, beats: (b["beats"] as? NSNumber)?.intValue ?? 0, returnAt: ((b["return"] as? [String: Any])?["t"] as? NSNumber)?.doubleValue, intro: b["intro"] as? Bool ?? false)
        }
        var env: [Int] = []
        if let ed = try? Data(contentsOf: root.appendingPathComponent(envPath)), let ej = (try? JSONSerialization.jsonObject(with: ed)) as? [String: Any] {
            env = (ej["energy"] as? [NSNumber])?.map { $0.intValue } ?? []
        }
        return MusicAnalysis(duration: (j["duration"] as? NSNumber)?.doubleValue ?? 0, bpm: bpm, firstBeat: (j["first_beat"] as? NSNumber)?.doubleValue ?? beats.first?.doubleValue ?? 0,
                             beats: beats.map { $0.doubleValue }, bars: bars.map { $0.doubleValue }, barEnergy: nums("bar_energy"),
                             dropBars: (j["drops_bar_index"] as? [NSNumber])?.map { $0.intValue } ?? [], breakdowns: bds, envelope: env)
    }

    /// The times of the drops (a bar where the energy jumps) and of the returns (the bass comes back after a break).
    public var dropTimes: [Double] { dropBars.compactMap { bars.indices.contains($0) ? bars[$0] : nil } }
    public var returns: [Double] { breakdowns.compactMap { $0.returnAt } }

    /// The strongest drop: the bar with the biggest rise in energy; without any drop, the return after the longest break.
    public var strongestDrop: Double? {
        let ranked = dropBars.filter { bars.indices.contains($0) && barEnergy.indices.contains($0) && $0 > 0 }
            .map { ($0, barEnergy[$0] - barEnergy[$0 - 1]) }.max { $0.1 < $1.1 }
        if let r = ranked { return bars[r.0] }
        return breakdowns.filter { $0.returnAt != nil }.max { $0.beats < $1.beats }?.returnAt
    }

    /// The breaks worth marking: not the intro, where the bass is simply not in yet.
    public var breaks: [Breakdown] { breakdowns.filter { !$0.intro } }

    /// Section starts: the start, the drops, the breaks and their returns.
    public var sections: [Double] {
        Array(Set([0] + dropTimes + breaks.map { $0.start } + returns)).sorted()
    }

    public func points(_ level: SnapLevel) -> [Double] {
        switch level {
        case .beat: return beats
        case .bar: return bars
        case .section: return sections
        case .drop: return Array(Set(dropTimes + returns)).sorted()
        case .off: return []
        }
    }

    /// The grid point nearest to `t` at that level, or `t` itself when snapping is off or nothing is near enough (`within` seconds).
    public func snap(_ t: Double, level: SnapLevel, within: Double = .infinity) -> Double {
        guard let p = points(level).min(by: { abs($0 - t) < abs($1 - t) }), abs(p - t) <= within else { return t }
        return p
    }

    /// Whether `t` sits on a bar line or a beat (within the tolerance): "bar", "beat" or nil.
    public func gridKind(_ t: Double) -> String? {
        if bars.contains(where: { abs($0 - t) <= Self.tolerance }) { return "bar" }
        if beats.contains(where: { abs($0 - t) <= Self.tolerance }) { return "beat" }
        return nil
    }

    /// The bar that contains `t` (an index into `bars`).
    public func barIndex(at t: Double) -> Int? { bars.lastIndex { $0 <= t + 0.001 } }
}

extension ShowreelFile {
    public func snapLevel(_ montage: Int = 0) -> SnapLevel { storyboards.indices.contains(montage) ? SnapLevel(rawValue: storyboards[montage].snap ?? "") ?? .beat : .beat }
    public func ripple(_ montage: Int = 0) -> Bool { storyboards.indices.contains(montage) ? storyboards[montage].ripple ?? true : true }
}

/// Running `scripts/analyze_audio.py` and drawing a waveform. Nothing here needs an AI; the analysis needs numpy and ffmpeg.
public enum Audio {
    public enum Outcome: Equatable, Sendable { case analysed(MusicAnalysis), unavailable(String), failed(String) }

    /// Runs the skill's analysis on the project's track, writing analysis/beats.json and env.json inside the project. `bpm` and `firstBeat` are
    /// the user's corrections (--bpm and --first-beat). Without numpy or ffmpeg the answer says what to install, and nothing is written.
    public static func analyse(store: ProjectStore, skill: URL, bpm: Double? = nil, firstBeat: Double? = nil) async -> Outcome {
        guard let f = store.loadShowreel(), let file = f.decisions.track?.file, !file.isEmpty else { return .unavailable("No track is attached.") }
        let track = store.root.appendingPathComponent(file)
        guard FileManager.default.fileExists(atPath: track.path) else { return .failed("The track file \(file) is missing.") }
        let probe = await Shell.run("command -v ffmpeg >/dev/null && python3 -c 'import numpy'", in: store.root, timeout: 30)
        guard probe?.status == 0 else { return .unavailable("The music grid needs ffmpeg and numpy: run the app's setup check to install them. Until then the grid is a plain time ruler.") }
        var cmd = "python3 \(BuildRunner.q(skill.appendingPathComponent("scripts/analyze_audio.py"))) \(BuildRunner.q(track)) --out \(BuildRunner.q(store.root.appendingPathComponent("analysis")))"
        if let b = bpm { cmd += " --bpm \(b)" }
        if let s = firstBeat { cmd += " --first-beat \(s)" }
        guard let r = await Shell.run(cmd, in: store.root, timeout: 240) else { return .failed("Could not start python3.") }
        guard r.status == 0, let a = MusicAnalysis.load(root: store.root) else { return .failed(String((r.err.isEmpty ? r.out : r.err).suffix(400))) }
        return .analysed(a)
    }

    /// The length of an audio file in seconds.
    public static func duration(_ url: URL) -> Double? {
        guard let f = try? AVAudioFile(forReading: url), f.processingFormat.sampleRate > 0 else { return nil }
        return Double(f.length) / f.processingFormat.sampleRate
    }

    /// Peaks of an audio file, `buckets` values between 0 and 1, read with AVFoundation. nil when the file cannot be read.
    public static func peaks(_ url: URL, buckets: Int) -> [Float]? {
        guard buckets > 0, let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }
        let frames = AVAudioFrameCount(file.length)
        guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames), (try? file.read(into: buf)) != nil, let ch = buf.floatChannelData else { return nil }
        let n = Int(buf.frameLength), per = max(1, n / buckets), channels = Int(buf.format.channelCount)
        var out = [Float](repeating: 0, count: buckets)
        for b in 0..<buckets {
            var m: Float = 0
            let a = b * per, z = min(n, a + per)
            if a >= z { break }
            for c in 0..<channels { for i in a..<z { m = max(m, abs(ch[c][i])) } }
            out[b] = m
        }
        let top = out.max() ?? 0
        return top > 0 ? out.map { $0 / top } : out
    }
}

extension ProjectStore {
    /// The analysis writes the tempo it found into the project (the feasibility check reads it). A bookkeeping save, not a decision.
    public func recordAnalysis(_ a: MusicAnalysis) throws {
        guard var f = loadShowreel(), f.decisions.track?.file != nil else { return }
        f.decisions.track?.bpm = a.bpm
        try save(f)
    }
}
