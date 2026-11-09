import Foundation

/// What is said about a transition. Every field is optional: nil leaves it as it is.
public struct TransitionEdit: Equatable, Sendable {
    /// "cut" (or "Cut on beat", the default) or the name of a scene transition of the library.
    public var type: String?
    public var duration: Double?
    /// "key=value, key=value"
    public var params: String?
    public var instruction: String?
    public init(type: String? = nil, duration: Double? = nil, params: String? = nil, instruction: String? = nil) {
        self.type = type; self.duration = duration; self.params = params; self.instruction = instruction
    }
}

extension ShowreelFile.Transition {
    public var isCut: Bool { type == "cut" }
    public var text: String {
        if isCut { return "Cut on beat" }
        var s = type
        if let d = duration { s += " \(ProjectDocs.seconds(d)) s" }
        if case .object(let o)? = params, !o.isEmpty { s += " (" + o.sorted { $0.key < $1.key }.map { k, v in if case .number(let n) = v { return "\(k)=\(ProjectDocs.seconds(n))" }; if case .string(let t) = v { return "\(k)=\(t)" }; return k }.joined(separator: ", ") + ")" }
        if let i = instruction, !i.isEmpty { s += " \u{201C}\(i)\u{201D}" }
        return s
    }
}

extension ShowreelFile {
    /// The transition leaving scene `id` toward the next scene that is on, with that scene; nil for the last scene on.
    public func transition(after id: String, montage: Int = 0) -> (item: Transition, next: Scene)? {
        let tl = timeline(montage)
        guard let i = tl.firstIndex(where: { $0.scene.id == id }), i + 1 < tl.count else { return nil }
        return (tl[i].item.transition, tl[i + 1].scene)
    }

    /// The length a transition gets when none is given: the library's, but at most half of the shorter scene.
    public func defaultTransitionDuration(_ name: String, between a: Scene, and b: Scene) -> Double {
        let lib = Look.transitions().first { $0.name == name }?.duration ?? 1
        let shorter = [a.duration, b.duration].compactMap { $0 }.min()
        let d = shorter.map { min(lib, $0 / 2) } ?? lib
        return (d * 10).rounded() / 10
    }
}

extension ProjectStore {
    private func needFile() throws -> ShowreelFile {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        return f
    }

    private func r3(_ x: Double) -> Double { (x * 1000).rounded() / 1000 }

    // MARK: durations

    func planResize(_ id: String, _ duration: Double, ripple: Bool) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try needFile()
        var g = f
        let tl = f.timeline()
        guard let i = tl.firstIndex(where: { $0.scene.id == id }), let si = g.scenes.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("\(id) is not in the film: switch it on first") }
        guard duration >= 0.1 else { throw AgentError.msg("a scene lasts at least 0.1 s") }
        let d = r3(duration)
        let old = tl[i].length ?? f.scenes[si].duration
        guard old != d else { throw AgentError.msg("no change: \(id) already lasts \(ProjectDocs.seconds(d)) s") }
        g.scenes[si].duration = d
        var lines = [Change("\(id) duration", old.map { ProjectDocs.seconds($0) + " s" } ?? "(none)", ProjectDocs.seconds(d) + " s")]
        if !ripple, i + 1 < tl.count, let k = g.storyboards[0].items.firstIndex(where: { $0.scene == tl[i + 1].scene.id }), let at = tl[i + 1].start {
            g.storyboards[0].items[k].start = at
            lines.append(Change("\(tl[i + 1].scene.id) start", "follows \(id)", "stays at \(ProjectDocs.seconds(at)) s"))
        }
        if g.scenes[si].state == .validated { g.scenes[si].status = SceneState.wip.rawValue; lines.append(Change("State", SceneState.validated.title, SceneState.wip.title)) }
        return try finish(title: "Set the duration of \(id)", changes: lines, from: f, to: g)
    }

    func planCut(_ before: String, _ after: String, at: Double) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try needFile()
        var g = f
        let tl = f.timeline()
        guard let i = tl.firstIndex(where: { $0.scene.id == before }), i + 1 < tl.count, tl[i + 1].scene.id == after else { throw AgentError.msg("\(before) and \(after) are not consecutive scenes of the film") }
        guard let start = tl[i].start, let a = tl[i].length, let b = tl[i + 1].length else { throw AgentError.msg("both scenes need a duration first") }
        let t = r3(at)
        let newA = r3(t - start), newB = r3(b + (a - newA))
        guard newA >= 0.1, newB >= 0.1 else { throw AgentError.msg("a scene lasts at least 0.1 s: the cut cannot go there") }
        guard newA != a else { throw AgentError.msg("no change: the cut already is there") }
        let ia = g.scenes.firstIndex { $0.id == before }!, ib = g.scenes.firstIndex { $0.id == after }!
        g.scenes[ia].duration = newA; g.scenes[ib].duration = newB
        if let k = g.storyboards[0].items.firstIndex(where: { $0.scene == after }), g.storyboards[0].items[k].start != nil { g.storyboards[0].items[k].start = t }
        var lines = [Change("\(before) duration", ProjectDocs.seconds(a) + " s", ProjectDocs.seconds(newA) + " s"), Change("\(after) duration", ProjectDocs.seconds(b) + " s", ProjectDocs.seconds(newB) + " s")]
        for k in [ia, ib] where g.scenes[k].state == .validated { g.scenes[k].status = SceneState.wip.rawValue; lines.append(Change("\(g.scenes[k].id) state", SceneState.validated.title, SceneState.wip.title)) }
        return try finish(title: "Move the cut between \(before) and \(after)", changes: lines, from: f, to: g)
    }

    // MARK: transitions

    func planTransition(_ id: String, _ edit: TransitionEdit?) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try needFile()
        var g = f
        guard let k = g.storyboards.first?.items.firstIndex(where: { $0.scene == id && $0.enabled }) else { throw AgentError.msg("\(id) is not in the film: a transition leaves a scene that is on") }
        guard let pair = f.transition(after: id) else { throw AgentError.msg("\(id) is the last scene on: a transition sits between two scenes") }
        guard let outgoing = f.scenes.first(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
        let old = g.storyboards[0].items[k].transition
        var t = old
        if let e = edit {
            if let ty = e.type?.trimmingCharacters(in: .whitespaces) {
                if ty.isEmpty || ty.lowercased() == "cut" || ty.lowercased() == "cut on beat" { t = ShowreelFile.Transition(instruction: old.instruction) ; t.type = "cut" }
                else {
                    guard let lib = Look.transitions().first(where: { $0.name.caseInsensitiveCompare(ty) == .orderedSame }) else {
                        throw AgentError.msg("unknown transition \"\(ty)\": it is not among the scene transitions of the library")
                    }
                    guard !Look.isPreviewOnly(lib.name) else {
                        throw AgentError.msg("\(lib.name) is a preview only: it does not run between two real scenes, so it cannot be chosen for a montage")
                    }
                    if lib.name != old.type { t = ShowreelFile.Transition(type: lib.name, duration: f.defaultTransitionDuration(lib.name, between: outgoing, and: pair.next), instruction: old.instruction) }
                }
            }
            if let d = e.duration {
                guard !t.isCut else { throw AgentError.msg("a cut has no duration: choose a transition first") }
                guard d > 0 else { throw AgentError.msg("a transition lasts more than 0 s") }
                t.duration = r3(d)
            }
            if let p = e.params {
                guard !t.isCut else { throw AgentError.msg("a cut has no parameters: choose a transition first") }
                t.params = try Self.parseParams(p)
            }
            if let i = e.instruction { let v = i.trimmingCharacters(in: .whitespacesAndNewlines); t.instruction = v.isEmpty ? nil : v }
        } else {
            t = ShowreelFile.Transition()
        }
        guard t != old else { throw AgentError.msg("no change: \(id) already goes to \(pair.next.id) with \(old.text)") }
        g.storyboards[0].items[k].transition = t
        let line = Change("\(id) \u{2192} \(pair.next.id) transition", old.text, t.text)
        return try finish(title: edit == nil || t.isCut && t.instruction == nil ? "Cut from \(id) to \(pair.next.id)" : "Set the transition from \(id) to \(pair.next.id)", changes: [line], from: f, to: g)
    }

    // MARK: music and grid

    func planTrack(_ asset: String?) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try needFile()
        var g = f
        let old = f.decisions.track?.file
        if let id = asset, !id.isEmpty {
            guard let a = Assets.load(self).first(where: { $0.id == id }) else { throw AgentError.msg("unknown asset \(id)") }
            guard a.type == "audio" else { throw AgentError.msg("\(id) is a \(a.type): the music is an audio file") }
            guard a.status == "approved" else { throw AgentError.msg("\(a.name) is \(a.status): approve it before using it as the music") }
            guard !a.file.isEmpty else { throw AgentError.msg("\(a.name) is not in the project's prepared files yet") }
            let file = "assets/" + a.file
            guard file != old else { throw AgentError.msg("no change: \(a.name) already is the music") }
            g.decisions.track = ShowreelFile.Track(file: file)
            return try finish(title: "Use \(a.name) as the music", changes: [Change("Music", old.map { ($0 as NSString).lastPathComponent } ?? "(none)", a.name)], from: f, to: g)
        }
        guard old != nil else { throw AgentError.msg("no change: there is no music") }
        g.decisions.track = nil
        return try finish(title: "Remove the music", changes: [Change("Music", (old! as NSString).lastPathComponent, "(none)")], from: f, to: g)
    }

    func planGrid(bpm: Double?, firstBeat: Double?) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try needFile()
        var g = f
        guard var t = g.decisions.track, t.file != nil else { throw AgentError.msg("attach the music first") }
        var lines: [Change] = []
        if let b = bpm {
            guard b >= 40, b <= 240 else { throw AgentError.msg("the tempo is between 40 and 240 BPM") }
            if t.bpm != b { lines.append(Change("Tempo", t.bpm.map { ProjectDocs.seconds($0) + " BPM" } ?? "(not analysed)", ProjectDocs.seconds(b) + " BPM")); t.bpm = b }
        }
        if let s = firstBeat {
            guard s >= 0 else { throw AgentError.msg("the first beat is a time in seconds, 0 or more") }
            if t.firstBeat != s { lines.append(Change("First beat", t.firstBeat.map { ProjectDocs.seconds($0) + " s" } ?? "(analysed)", ProjectDocs.seconds(s) + " s")); t.firstBeat = s }
        }
        guard !lines.isEmpty else { throw AgentError.msg("no change to the tempo or the first beat") }
        t.manual = true
        g.decisions.track = t
        return try finish(title: "Correct the music grid", changes: lines, from: f, to: g)
    }

    func planGridSettings(snap: String?, ripple: Bool?) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try needFile()
        var g = f
        guard !g.storyboards.isEmpty else { throw AgentError.msg("no storyboard") }
        var lines: [Change] = []
        if let s = snap {
            guard let lv = SnapLevel(rawValue: s) else { throw AgentError.msg("snap is beat, bar, section, drop or off") }
            if lv != f.snapLevel() { lines.append(Change("Snap to", f.snapLevel().title, lv.title)); g.storyboards[0].snap = lv.rawValue }
        }
        if let r = ripple, r != f.ripple() { lines.append(Change("Ripple", f.ripple() ? "on" : "off", r ? "on" : "off")); g.storyboards[0].ripple = r }
        guard !lines.isEmpty else { throw AgentError.msg("no change") }
        return try finish(title: "Set the reel's grid", changes: lines, from: f, to: g)
    }
}

// MARK: checks on the reel (no AI)

extension Checks {
    /// The tension of a scene from its feeling ("calm, 1/5"), nil when it says none.
    static func tension(_ s: ShowreelFile.Scene) -> Int? {
        guard let m = s.feeling.range(of: #"(\d)\s*/\s*5"#, options: .regularExpression) else { return nil }
        return Int(s.feeling[m].first.map(String.init) ?? "")
    }

    /// When an item is on screen inside its scene: its `in` and `out` (set by the layers of a later phase) or the whole scene.
    static func visible(_ i: ShowreelFile.ContentItem, length: Double) -> (Double, Double) {
        func num(_ k: String) -> Double? { if case .number(let n)? = i.unknown[k] { return n }; return nil }
        return (num("in") ?? 0, num("out") ?? length)
    }

    static func reelRules(_ f: ShowreelFile?, _ store: ProjectStore) -> [CheckResult] {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "reel." + id, block: "storyboard", title: title, level: level, detail: detail) }
        guard let f = f else { return [] }
        let tl = f.timeline()
        guard !tl.isEmpty else { return [] }
        var out: [CheckResult] = []
        func sec(_ x: Double) -> String { ProjectDocs.seconds(x) }

        // transitions: not longer than a scene, no essential text in the middle of one
        var long: [String] = [], texty: [String] = []
        var boundaries: [Double] = []
        for (i, t) in tl.enumerated() where i + 1 < tl.count {
            let n = tl[i + 1]
            if let at = n.start { boundaries.append(at) }
            let tr = t.item.transition
            guard !tr.isCut, let la = t.length, let lb = n.length else { continue }
            if Look.isPreviewOnly(tr.type) { long.append("\(t.scene.id) \u{2192} \(n.scene.id): \(tr.type) is a preview only and cannot be drawn between two real scenes: choose another transition or a cut") }
            let d = tr.duration ?? f.defaultTransitionDuration(tr.type, between: t.scene, and: n.scene)
            if d > min(la, lb) + 0.001 { long.append("\(t.scene.id) \u{2192} \(n.scene.id): \(tr.type) lasts \(sec(d)) s, a scene lasts \(sec(min(la, lb))) s") }
            let outTexts = t.scene.content.filter { $0.type == "text" && !($0.text ?? "").isEmpty }.filter { let v = visible($0, length: la); return v.1 > la - d && v.0 < la }
            let inTexts = n.scene.content.filter { $0.type == "text" && !($0.text ?? "").isEmpty }.filter { let v = visible($0, length: lb); return v.0 < d && v.1 > 0 }
            if !outTexts.isEmpty || !inTexts.isEmpty { texty.append("\(t.scene.id) \u{2192} \(n.scene.id): words are on screen during the \(sec(d)) s of \(tr.type)") }
        }
        if tl.contains(where: { !$0.item.transition.isCut }) {
            out.append(long.isEmpty ? r("transition-length", "Transitions fit their scenes", .ok, "no transition is longer than the scenes it joins")
                                    : r("transition-length", "Transitions fit their scenes", .fail, long.joined(separator: "; ")))
            out.append(texty.isEmpty ? r("transition-text", "No words mid-transition", .ok, "no text is on screen while a transition runs")
                                     : r("transition-text", "No words mid-transition", .tight, texty.joined(separator: "; ") + ". A transition overlaps the end of one scene and the start of the next: keep the words out of that time or choose a cut."))
        }
        // flashes: scene changes in any second
        if boundaries.count >= 2 {
            let sorted = boundaries.sorted()
            let worst = sorted.indices.map { i in sorted.filter { $0 >= sorted[i] - 0.0001 && $0 < sorted[i] + 1 }.count }.max() ?? 1
            out.append(worst >= 3 ? r("flashes", "Flashes per second", .fail, "\(worst) scene changes within one second: flashes must stay under 3 per second")
                                  : r("flashes", "Flashes per second", .ok, "at most \(worst) scene change\(worst == 1 ? "" : "s") in any second"))
        }
        // music
        guard let track = f.decisions.track?.file, !track.isEmpty else { return out + [r("music", "Music", .pending, "No music attached: attach an approved audio file to time the film against it.")] }
        guard let a = MusicAnalysis.load(root: store.root) else {
            return out + [r("music", "Music grid", .pending, "The analysis of \((track as NSString).lastPathComponent) is not available yet (it needs numpy and ffmpeg): the grid is a plain time ruler.")]
        }
        let starts = tl.dropFirst().compactMap { t in t.start.map { (t.scene.id, $0) } }
        let off = starts.filter { a.gridKind($0.1) == nil }
        out.append(starts.isEmpty ? r("starts", "Scenes start on the music", .pending, "Only one scene on.")
                   : off.isEmpty ? r("starts", "Scenes start on the music", .ok, "every scene starts on a bar or a beat")
                   : r("starts", "Scenes start on the music", .tight, off.map { "\($0.0) starts at \(sec($0.1)) s, off the beat" }.joined(separator: "; ")))
        if let drop = a.strongestDrop {
            let near = tl.first { ($0.start.map { abs($0 - drop) <= 0.12 }) ?? false }
            let hot = tl.compactMap { t in Self.tension(t.scene).map { (t, $0) } }.max { $0.1 < $1.1 }?.0
            if let h = hot, !(h.start.map { abs($0 - drop) <= 0.12 } ?? false) {
                out.append(r("drop", "Strongest moment on the strongest drop", .tight, "\(h.scene.id) is the most intense scene (\(h.scene.feeling)) but starts at \(sec(h.start ?? 0)) s; the strongest drop is at \(sec(drop)) s"))
            } else if let n = near {
                out.append(r("drop", "Strongest moment on the strongest drop", .ok, "\(n.scene.id) starts on the strongest drop at \(sec(drop)) s"))
            } else {
                out.append(r("drop", "Strongest moment on the strongest drop", .tight, "no scene starts on the strongest drop at \(sec(drop)) s"))
            }
            if let bi = a.barIndex(at: drop), bi > 0, a.barEnergy.indices.contains(bi), a.barEnergy[bi] > 0 {
                let calm = a.barEnergy[bi - 1] <= 0.6 * a.barEnergy[bi]
                out.append(r("calm", "A calm bar before the drop", calm ? .ok : .tight, calm ? "the bar before the drop is calm (\(String(format: "%.2f", a.barEnergy[bi - 1])) against \(String(format: "%.2f", a.barEnergy[bi])))" : "the bar before the drop is not calm (\(String(format: "%.2f", a.barEnergy[bi - 1])) against \(String(format: "%.2f", a.barEnergy[bi]))): the drop has little to rise from"))
            }
        } else {
            out.append(r("drop", "Strongest moment on the strongest drop", .pending, "No drop was found in the music."))
        }
        if let end = f.filmEnd {
            if end > a.duration + 0.3 { out.append(r("length", "Film and music length", .fail, "the film runs to \(sec(end)) s, past the end of the music (\(sec(a.duration)) s)")) }
            else if end < a.duration - 2 { out.append(r("length", "Film and music length", .tight, "the film ends at \(sec(end)) s, \(sec(a.duration - end)) s before the music ends")) }
            else { out.append(r("length", "Film and music length", .ok, "the film ends at \(sec(end)) s, the music at \(sec(a.duration)) s")) }
        }
        return out
    }
}
