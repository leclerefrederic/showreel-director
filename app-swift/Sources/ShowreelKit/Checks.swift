import Foundation

/// The result of a deterministic check: no AI, same answer every time. Shown as a coloured dot next to its text.
public enum CheckLevel: String, Sendable, Comparable {
    case pending   // not enough data to say yet (grey)
    case ok        // green
    case tight     // amber: possible, but near the limit
    case fail      // red

    var rank: Int { switch self { case .pending: return 0; case .ok: return 1; case .tight: return 2; case .fail: return 3 } }
    public static func < (a: CheckLevel, b: CheckLevel) -> Bool { a.rank < b.rank }
}

public struct CheckResult: Equatable, Sendable, Identifiable {
    public let id: String
    public let block: String
    public let title: String
    public let level: CheckLevel
    public let detail: String
    public init(id: String, block: String, title: String, level: CheckLevel, detail: String) {
        self.id = id; self.block = block; self.title = title; self.level = level; self.detail = detail
    }
}

/// The checks of each area (project, resources, look, storyboard, scene, build), native and deterministic: feasibility numbers, readability budget per scene, asset rules, gate state.
public enum Checks {
    /// The checks of an area. Every result has its own id, even when a hand-edited file repeats a scene ID.
    public static func run(area: String, store: ProjectStore) -> [CheckResult] {
        var seen: [String: Int] = [:]
        return results(area: area, store: store).map { r in
            seen[r.id, default: 0] += 1
            guard seen[r.id]! > 1 else { return r }
            return CheckResult(id: r.id + "#\(seen[r.id]!)", block: r.block, title: r.title, level: r.level, detail: r.detail)
        }
    }

    static func results(area: String, store: ProjectStore) -> [CheckResult] {
        let f = store.loadShowreel()
        let assets = Assets.load(store)
        switch area {
        case "project": return setupChecks(f) + feasibility(f) + gates(area: area, f)
        case "resources": return assetRules(assets, store: store) + gates(area: area, f)
        case "look": return lookChecks(f, assets, store) + gates(area: area, f)
        case "storyboard": return storyboardRules(f, assets) + readingBudget(f) + reelRules(f, store) + feasibility(f) + gates(area: area, f)
        case "scene": return reviewRules(f) + contentRules(f, assets, store) + gates(area: area, f)
        case "build": return BuildRunner.readiness(store) + gates(area: area, f)
        default: return gates(area: area, f)
        }
    }

    /// What the base configuration still lacks, as orange checks: an existing project is never blocked by it, only told.
    static func setupChecks(_ f: ShowreelFile?) -> [CheckResult] {
        guard let f = f else { return [] }
        return ProjectSetup.missing(f).map { CheckResult(id: "setup." + $0.id, block: "project", title: "Missing: \($0.title.lowercased())", level: .tight, detail: $0.detail.prefix(1).uppercased() + $0.detail.dropFirst() + ". Everything else depends on it.") }
    }

    public static func worst(_ r: [CheckResult]) -> CheckLevel { r.map { $0.level }.max() ?? .pending }

    // MARK: feasibility (the rules of scripts/feasibility.py, from references/feasibility.md)

    /// Inputs of the feasibility rules, read from the project.
    public struct Brief: Equatable, Sendable {
        public var duration: Double?
        public var scenes: Int?
        public var textScenes: Int?
        public var words: Int?
        public var wordsPerLang: [String: Int] = [:]
        public var langs = 1
        public var expansion = 1.3
        public var bpm: Double?
        public var portrait = false
        public var transition = 0.4
        public init() {}
    }

    static func wordCount(_ s: String) -> Int { s.split(whereSeparator: { $0.isWhitespace }).count }

    public static func brief(from f: ShowreelFile) -> Brief {
        var b = Brief()
        b.duration = f.decisions.duration
        let live = f.film
        if !live.isEmpty {
            b.scenes = live.count
            let withText = live.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            b.textScenes = withText.count
            b.words = withText.reduce(0) { $0 + wordCount($1.text) }
            let langs = Set(live.flatMap { $0.texts.keys })
            for l in langs { b.wordsPerLang[l] = live.reduce(0) { $0 + wordCount($1.texts[l] ?? "") } }
            if !b.wordsPerLang.isEmpty { b.wordsPerLang["master"] = b.words }
        }
        b.langs = max(1, f.reelLanguages.count)
        b.bpm = f.decisions.track?.bpm
        b.portrait = (f.decisions.formats ?? []).contains("9:16")
        return b
    }

    static func feasibility(_ f: ShowreelFile?) -> [CheckResult] {
        guard let f = f else { return [CheckResult(id: "feasibility", block: "project", title: "Feasibility", level: .pending, detail: "No project data yet.")] }
        let b = brief(from: f)
        guard b.duration != nil else {
            return [CheckResult(id: "feasibility", block: "project", title: "Feasibility", level: .pending, detail: "Set the duration to check what fits in it.")]
        }
        return feasibility(b)
    }

    /// Port of scripts/feasibility.py: the same checks, thresholds and wording. A test runs the script on the same inputs and compares verdicts.
    public static func feasibility(_ a: Brief) -> [CheckResult] {
        guard let D = a.duration, D > 0 else { return [] }
        var rows: [(String, CheckLevel, String)] = []
        func g(_ x: Double) -> String { x == x.rounded() ? String(Int(x)) : String(format: "%g", x) }
        func f1(_ x: Double) -> String { String(format: "%.1f", x) }
        let comf = D / 5, stretch = D / 3
        if let scenes = a.scenes {
            let ts = a.textScenes ?? scenes
            let vs = scenes - ts
            let per = D / Double(scenes)
            if per < 0.5 {
                rows.append(("scene count", .fail, "\(scenes) scenes in \(g(D)) s = \(String(format: "%.2f", per)) s each: below 0.5 s they are flashes, not scenes (and flashes must stay under 3 per second)"))
            } else if Double(ts) > stretch.rounded(.down), ts > 0 {
                rows.append(("text scenes", .fail, "\(ts) scenes carrying text in \(g(D)) s leave \(f1(per)) s per scene on average (\(scenes) scenes share the duration); text needs about 3 s (floor 1.5 s for 1-3 words)"))
            } else if Double(ts) > comf.rounded(.down) {
                rows.append(("text scenes", .tight, "\(ts) text scenes among \(scenes) = \(f1(per)) s per scene on average: above the comfortable count (\(Int(comf.rounded(.down)))); keep lines short (about 6-8 words max)"))
            } else {
                rows.append(("text scenes", .ok, "\(ts) text scenes among \(scenes) = \(f1(per)) s per scene on average"))
            }
            if vs > 0, (D - Double(ts) * 3) / Double(vs) < 0.5 {
                rows.append(("visual beats", .fail, "\(vs) visual-only beats do not fit in the \(f1(max(D - Double(ts) * 3, 0))) s left after text scenes"))
            }
            if a.transition * Double(scenes) > D * 0.4 {
                rows.append(("transitions", .tight, "\(scenes) transitions of \(g(a.transition)) s take \(f1(a.transition * Double(scenes))) s (\(Int((100 * a.transition * Double(scenes) / D).rounded()))% of the film): shorten them or cut scenes"))
            }
        }
        if a.words != nil || !a.wordsPerLang.isEmpty {
            var eff = Double(a.words ?? 0) * (a.langs > 1 ? a.expansion : 1)
            if !a.wordsPerLang.isEmpty { eff = Double(a.wordsPerLang.values.max() ?? 0) }
            let wps = eff / D
            let limit = a.portrait ? 1.6 : 2.0
            let lvl: CheckLevel = wps <= limit ? .ok : wps <= limit * 1.5 ? .tight : .fail
            rows.append(("words on screen", lvl, "\(String(format: "%.0f", eff)) words\(a.langs > 1 ? " (longest translation)" : "") in \(g(D)) s = \(f1(wps)) words/s; target <= \(g(limit))"))
            let chars = eff * 6
            let need = chars / 17 + 0.7 * Double((a.textScenes.flatMap { $0 == 0 ? nil : $0 }) ?? a.scenes ?? 1)   // python: (text_scenes or scenes or 1)
            if need > D {
                rows.append(("reading time", .fail, "~\(String(format: "%.0f", chars)) characters need ~\(String(format: "%.0f", chars / 17)) s of pure reading at 17 characters/s plus animation: more than \(g(D)) s"))
            }
        }
        if let bpm = a.bpm, bpm > 0 {
            let bar = 240 / bpm, bars = D / bar
            let onBar = abs(bars - bars.rounded()) < 0.15
            rows.append(("music", onBar ? .ok : .tight, "bar = \(String(format: "%.2f", bar)) s, \(f1(bars)) bars; " + (onBar ? "ends on a bar boundary" : "does not end on a bar boundary: use \(Int(bars.rounded(.down))) or \(Int(bars.rounded(.up))) bars")))
            if let scenes = a.scenes {
                let ok = D / Double(scenes) >= bar / 2
                rows.append(("scene length vs bars", ok ? .ok : .tight, "average scene \(String(format: "%.2f", D / Double(scenes))) s vs half-bar \(String(format: "%.2f", bar / 2)) s"))
            }
        }
        var out = [CheckResult(id: "feasibility.capacity", block: "project", title: "Capacity for \(g(D)) s",
                               level: .ok, detail: "Text-bearing scenes: comfortable up to \(Int(comf.rounded(.down))), stretch up to \(Int(stretch.rounded(.down))).")]
        out += rows.map { CheckResult(id: "feasibility." + $0.0.replacingOccurrences(of: " ", with: "-"), block: "project", title: $0.0.prefix(1).uppercased() + $0.0.dropFirst(), level: $0.1, detail: $0.2) }
        return out
    }

    // MARK: readability budget per scene (references/storyboard-review.md, 1b; feasibility.md)

    /// Seconds a line needs on screen: entrance 0.4 s + reading + hold 0.3 s, never less than the floor for its length
    /// (1.5 s for one to three words, about 3 s from six words). Reading speed 17 characters per second, 15 on portrait.
    public static func secondsNeeded(text: String, portrait: Bool) -> Double {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return 0 }
        let w = wordCount(t)
        let floor = w <= 3 ? 1.5 : w >= 6 ? 3.0 : 2.25
        return max(floor, 0.4 + Double(t.count) / (portrait ? 15 : 17) + 0.3)
    }

    static func readingBudget(_ f: ShowreelFile?) -> [CheckResult] {
        guard let f = f else { return [] }
        let portrait = (f.decisions.formats ?? []).contains("9:16")
        let live = f.timeline()
        if live.isEmpty { return [CheckResult(id: "reading", block: "storyboard", title: "Reading time per scene", level: .pending, detail: "No scene on in the storyboard yet.")] }
        var out: [CheckResult] = []
        for t in live {
            let s = t.scene
            let lines = ([s.text] + s.texts.keys.sorted().map { s.texts[$0] ?? "" }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !lines.isEmpty else { continue }
            guard let dur = t.length, dur > 0 else {
                out.append(CheckResult(id: "reading.\(s.id)", block: "storyboard", title: "\(s.id) reading time", level: .pending, detail: "Give \(s.id) a duration."))
                continue
            }
            // further text items are read one after the other: their time is added to the longest version of the first
            let extra = s.content.filter { $0.type == "text" }.dropFirst().reduce(0.0) { $0 + secondsNeeded(text: $1.text ?? "", portrait: portrait) }
            let need = (lines.map { secondsNeeded(text: $0, portrait: portrait) }.max() ?? 0) + extra
            let level: CheckLevel = dur >= need ? .ok : dur >= need * 0.8 ? .tight : .fail
            let longest = lines.max { $0.count < $1.count } ?? ""
            let detail = String(format: "%.1f s on screen for %d characters (about %.1f s needed)", dur, longest.count, need)
            out.append(CheckResult(id: "reading.\(s.id)", block: "storyboard", title: "\(s.id) reading time", level: level,
                                   detail: level == .ok ? detail : detail + ": more time, fewer words, or merge the scene"))
        }
        return out.isEmpty ? [CheckResult(id: "reading", block: "storyboard", title: "Reading time per scene", level: .pending, detail: "No scene carries text yet.")] : out
    }

    // MARK: asset rules (what scripts/organize_assets.py --check verifies)

    static let nameRule = try! NSRegularExpression(pattern: #"^(logo|icon|shot|photo|illus|img|font|audio|voice|sfx|video|frames)-(\d{2})-([a-z0-9]+(?:-[a-z0-9]+)*)(?:_([a-z0-9]+(?:-[a-z0-9]+)*))?(\.[a-z0-9]+)?$"#)

    static func assetRules(_ rows: [AssetRow], store: ProjectStore) -> [CheckResult] {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "assets." + id, block: "resources", title: title, level: level, detail: detail) }
        guard !rows.isEmpty else { return [r("any", "Assets", .pending, "No files yet.")] }
        let fm = FileManager.default
        var out: [CheckResult] = []
        let ids = rows.map { $0.id }
        out.append(Set(ids).count == ids.count ? r("ids", "Unique ids", .ok, "\(ids.count) assets, no id used twice")
                                               : r("ids", "Unique ids", .fail, "an id is used twice in the manifest"))
        let bad = rows.filter { !AssetStatus.allCases.map { $0.rawValue }.contains($0.status) }
        out.append(bad.isEmpty ? r("status", "Valid statuses", .ok, "every status is one of proposed, approved, excluded, placeholder, hold")
                               : r("status", "Valid statuses", .fail, bad.map { "\($0.id): bad status \"\($0.status)\"" }.joined(separator: "; ")))
        let held = rows.filter { $0.status == "hold" }
        out.append(held.isEmpty ? r("hold", "Held files decided", .ok, "no file on hold")
                                : r("hold", "Held files decided", .fail, held.map { "\($0.name) is on hold" + ($0.notes.isEmpty ? "" : " (\($0.notes))") }.joined(separator: "; ")))
        let missing = rows.filter { !$0.file.isEmpty && !fm.fileExists(atPath: store.root.appendingPathComponent("assets/" + $0.file).path) }
        out.append(missing.isEmpty ? r("files", "Listed files exist", .ok, "every listed file is in the project")
                                   : r("files", "Listed files exist", .fail, missing.map { "\($0.file) is listed but missing" }.joined(separator: "; ")))
        let kept = rows.filter { $0.status == "excluded" && !$0.file.isEmpty }
        out.append(kept.isEmpty ? r("excluded", "Excluded files removed", .ok, "no excluded file left in prepared")
                                : r("excluded", "Excluded files removed", .fail, kept.map { "\($0.id): excluded but still in \($0.file)" }.joined(separator: "; ")))
        // names and manifest coverage of prepared/ and generated/
        let listed = Set(rows.map { $0.file }.filter { !$0.isEmpty })
        var naming: [String] = []
        for d in ["prepared", "generated"] {
            for n in ((try? fm.contentsOfDirectory(atPath: store.root.appendingPathComponent("assets/" + d).path)) ?? []).sorted() where !n.hasPrefix(".") {
                if nameRule.firstMatch(in: n, range: NSRange(location: 0, length: (n as NSString).length)) == nil { naming.append("\(d)/\(n): name does not follow <type>-<nn>-<slug>") }
                if !listed.contains("\(d)/\(n)") { naming.append("\(d)/\(n): not in the manifest") }
            }
        }
        for fam in ((try? fm.contentsOfDirectory(atPath: store.root.appendingPathComponent("assets/fonts").path)) ?? []).sorted() where !fam.hasPrefix(".") {
            for n in ((try? fm.contentsOfDirectory(atPath: store.root.appendingPathComponent("assets/fonts/" + fam).path)) ?? []).sorted() where !n.hasPrefix(".") && ["ttf", "otf", "woff2"].contains((n as NSString).pathExtension.lowercased()) {
                if !listed.contains("fonts/\(fam)/\(n)") { naming.append("fonts/\(fam)/\(n): not in the manifest") }
            }
        }
        out.append(naming.isEmpty ? r("names", "Typed names, all listed", .ok, "prepared and generated files follow the naming convention and are in the manifest")
                                  : r("names", "Typed names, all listed", .fail, naming.joined(separator: "; ")))
        let stray = ((try? fm.contentsOfDirectory(atPath: store.root.appendingPathComponent("assets").path)) ?? [])
            .filter { !["source", "prepared", "generated", "fonts", "MANIFEST.csv"].contains($0) && !$0.hasPrefix(".") }
        out.append(stray.isEmpty ? r("stray", "No stray file", .ok, "nothing loose in assets/")
                                 : r("stray", "No stray file", .fail, stray.map { "assets/\($0): stray, run the organiser" }.joined(separator: "; ")))
        let ph = rows.filter { $0.status == "placeholder" }
        if !ph.isEmpty { out.append(r("placeholder", "Placeholders", .tight, ph.map { $0.name }.joined(separator: ", ") + ": each must be listed in the release gate")) }
        let approved = rows.filter { $0.status == "approved" }.count
        out.append(approved > 0 ? r("approved", "Approved assets", .ok, "\(approved) approved")
                                : r("approved", "Approved assets", .pending, "Nothing approved yet: the build only uses approved assets"))
        return out
    }

    // MARK: storyboard rules and scene review

    static func storyboardRules(_ f: ShowreelFile?, _ assets: [AssetRow]) -> [CheckResult] {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "storyboard." + id, block: "storyboard", title: title, level: level, detail: detail) }
        guard let f = f, !f.scenes.isEmpty else { return [r("any", "Scenes", .pending, "No scene yet.")] }
        var out: [CheckResult] = []
        let ids = f.scenes.map { $0.id }
        let badID = ids.filter { !SceneRules.isValidID($0) }
        out.append(Set(ids).count != ids.count ? r("ids", "Stable IDs", .fail, "an ID is used twice")
                   : !badID.isEmpty ? r("ids", "Stable IDs", .fail, badID.joined(separator: ", ") + ": not an ID like S01")
                   : r("ids", "Stable IDs", .ok, "\(ids.count) scenes, each ID used once (an archived scene keeps its ID)"))
        let tl = f.timeline()
        if tl.isEmpty { out.append(r("on", "Scenes on", .pending, "no scene is switched on in the storyboard")); return out }
        let untimed = tl.filter { $0.length == nil }
        out.append(untimed.isEmpty ? r("times", "Durations", .ok, "every scene on has a duration")
                                   : r("times", "Durations", .pending, untimed.map { $0.scene.id }.joined(separator: ", ") + ": no duration yet"))
        var overlaps: [String] = []
        for (a, b) in zip(tl, tl.dropFirst()) { if let e = a.end, let st = b.start, st < e - 0.001 { overlaps.append("\(b.scene.id) starts at \(ProjectDocs.seconds(st)) s, before \(a.scene.id) ends at \(ProjectDocs.seconds(e)) s") } }
        out.append(overlaps.isEmpty ? r("overlap", "Scenes in time order", .ok, "no overlap") : r("overlap", "Scenes in time order", .fail, overlaps.joined(separator: "; ")))
        let inMontage = Set(f.storyboards.flatMap { $0.items.map { $0.scene } })
        let loose = f.library.filter { !inMontage.contains($0.id) }
        if !loose.isEmpty { out.append(r("loose", "Library scenes placed", .tight, loose.map { $0.id }.joined(separator: ", ") + ": in the library but in no montage")) }
        if let d = f.decisions.duration, let last = tl.compactMap({ $0.end }).max() {
            let fmt = { ProjectDocs.seconds($0) }
            if last > d + 0.01 { out.append(r("duration", "Fits the duration", .fail, "the scenes run to \(fmt(last)) s, past the \(fmt(d)) s you chose")) }
            else if last < d - 0.5 { out.append(r("duration", "Fits the duration", .tight, "the scenes stop at \(fmt(last)) s, \(fmt(d - last)) s before the end of the \(fmt(d)) s film")) }
            else { out.append(r("duration", "Fits the duration", .ok, "the scenes end at \(fmt(last)) s of \(fmt(d)) s")) }
        }
        var unapproved: [String] = []
        for s in tl.map({ $0.scene }) { for a in assets where a.sceneIDs.contains(s.id) && a.status != "approved" { unapproved.append("\(s.id) uses \(a.name), which is \(a.status)") } }
        if assets.contains(where: { !$0.scene.isEmpty }) {
            out.append(unapproved.isEmpty ? r("assets", "Linked resources approved", .ok, "every linked resource is approved") : r("assets", "Linked resources approved", .tight, unapproved.joined(separator: "; ") + ": the build only uses approved files"))
        }
        return out
    }

    static func reviewRules(_ f: ShowreelFile?) -> [CheckResult] {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "review." + id, block: "scene", title: title, level: level, detail: detail) }
        guard let f = f else { return [r("any", "Scenes", .pending, "No project data yet.")] }
        let live = SceneRules.live(f)
        if live.isEmpty { return [r("any", "Scenes", .pending, "No scene to review yet.")] }
        var out = live.map { s -> CheckResult in
            switch s.state {
            case .validated: return r(s.id, "\(s.id) reviewed", .ok, "Ready" + (s.note.isEmpty ? "" : ": " + s.note))
            case .locked: return r(s.id, "\(s.id) reviewed", .ok, "Locked" + (s.note.isEmpty ? "" : ": " + s.note))
            case .wip where s.toModify: return r(s.id, "\(s.id) reviewed", .tight, "To review, a change was asked: " + s.note)
            default: return r(s.id, "\(s.id) reviewed", .pending, "To review: not Ready yet")
            }
        }
        let left = live.filter { !$0.state.isReviewed }
        out.insert(left.isEmpty ? r("all", "Every visible scene is Ready", .ok, "ready for the Go") : r("all", "Every visible scene is Ready", .pending, "\(left.map { $0.id }.joined(separator: ", ")) not Ready yet (\(left.count) of \(live.count))"), at: 0)
        return out
    }

    // MARK: scene content: what the user fixed must hold (no AI)

    /// For every scene that is on: a palette role exists, an effect exists in the library, a linked resource is usable and approved, and a fixed
    /// value is not contradicted (text in the background's colour, a colour that cannot be read on the background, a transition used as an animation).
    static func contentRules(_ f: ShowreelFile?, _ assets: [AssetRow], _ store: ProjectStore) -> [CheckResult] {
        guard let f = f else { return [] }
        let known = Set(Look.effects())
        var out: [CheckResult] = []
        for s in f.film where !s.content.isEmpty {
            var issues: [(CheckLevel, String)] = []
            let palette = f.effective(.palette, for: s).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let bgHex = palette.first
            for it in s.content {
                let name = "\(it.id) (\(it.type))"
                if it.type == "text", it.color.isFixed {
                    var hex: String?
                    if it.color.mode == "role" {
                        if let r = it.color.role.flatMap(PaletteRole.parse) {
                            if palette.isEmpty { issues.append((.pending, "\(name): colour \(r.title) needs a palette, none is chosen yet")) }
                            else if r.index >= palette.count { issues.append((.fail, "\(name): the palette has no \(r.title.lowercased()) colour (it has \(palette.count))")) }
                            else { hex = palette[r.index]; if r == .background { issues.append((.fail, "\(name): coloured as the background, it would not show")) } }
                        } else { issues.append((.fail, "\(name): \"\(it.color.role ?? "")\" is not a palette role")) }
                    } else if it.color.mode == "custom" {
                        if let h = it.color.hex, EnginePalette.isHex(h) { hex = h } else { issues.append((.fail, "\(name): \"\(it.color.hex ?? "")\" is not a #RRGGBB colour")) }
                    }
                    if let h = hex, let b = bgHex, EnginePalette.isHex(b), it.color.role.flatMap(PaletteRole.parse) != .background {
                        let r = Contrast.ratio(h, b)
                        if r < 3 { issues.append((.fail, "\(name): \(h) on the background \(b) has a contrast of \(String(format: "%.1f", r)):1, under 3:1")) }
                    }
                } else if it.type != "text", it.color.isFixed { issues.append((.tight, "\(name): a fixed colour has no effect on an \(it.type)")) }
                if it.animation.mode == "effect" {
                    let e = it.animation.effect ?? ""
                    if !known.contains(e) { issues.append((.fail, "\(name): the effect \"\(e)\" is not in the library")) }
                    else if Look.effectCategory(e) == EngineCatalogue.transitionCategory { issues.append((.tight, "\(name): \(e) is a scene transition, it belongs between scenes")) }
                    if it.type == "audio" { issues.append((.tight, "\(name): a sound has no animation")) }
                }
                if it.type != "text" {
                    if let r = it.resource, let a = assets.first(where: { $0.id == r }) {
                        if !ContentRules.accepts(it.type, asset: a.type) { issues.append((.fail, "\(name): \(r) is a \(a.type), not an \(it.type) file")) }
                        switch Assets.nodeStatus(a, store: store) {
                        case .approved: break
                        case .toApprove: issues.append((.tight, "\(name): \(a.name) is \(a.status): the build only uses approved files"))
                        case .excluded: issues.append((.fail, "\(name): \(a.name) is excluded"))
                        case .missing: issues.append((.fail, "\(name): the file of \(a.name) is missing"))
                        case .overBudget: issues.append((.tight, "\(name): \(a.name) is over the weight rules"))
                        }
                    } else { issues.append((.fail, "\(name): the resource \"\(it.resource ?? "")\" is not in the manifest")) }
                }
            }
            let level = issues.map { $0.0 }.max() ?? .ok
            out.append(CheckResult(id: "content.\(s.id)", block: "scene", title: "\(s.id) content", level: level,
                                   detail: issues.isEmpty ? "\(s.content.count) item\(s.content.count == 1 ? "" : "s"): what you fixed holds" : issues.map { $0.1 }.joined(separator: "; ")))
        }
        return out
    }

    // MARK: look: palette contrast, font licences

    static func lookChecks(_ f: ShowreelFile?, _ assets: [AssetRow], _ store: ProjectStore) -> [CheckResult] {
        var out = Contrast.checks(f?.decisions.palette)
        let fonts = [("Title font", f?.decisions.fonts?.titles), ("Text font", f?.decisions.fonts?.text)]
        if fonts.allSatisfy({ ($0.1 ?? "").isEmpty }) {
            out.append(CheckResult(id: "font.any", block: "look", title: "Fonts", level: .pending, detail: "No font chosen yet."))
        }
        for (i, (label, name)) in fonts.enumerated() {
            guard let n = name, !n.isEmpty else { continue }
            let a = FontLicense.assess(name: n, assets: assets, store: store)
            out.append(CheckResult(id: i == 0 ? "font.titles" : "font.text", block: "look", title: "\(label): \(n)", level: a.level, detail: a.message))
        }
        let d = f?.decisions
        out.append(CheckResult(id: "look.background", block: "look", title: "Background", level: (d?.background?.id ?? "").isEmpty ? .pending : .ok,
                               detail: (d?.background?.id).map { "\($0)" } ?? "No background chosen yet."))
        out.append(CheckResult(id: "look.effects", block: "look", title: "Effects mood", level: (d?.effectsPack ?? "").isEmpty ? .pending : .ok,
                               detail: d?.effectsPack ?? "No effects pack chosen yet."))
        return out
    }

    // MARK: gate state

    static func gates(area: String, _ f: ShowreelFile?) -> [CheckResult] {
        guard let spec = ProcessSpec.load() else { return [] }
        let keys = spec.gateKeys(area: area)
        return keys.map { k in
            let passed = f?.gateState(k) == "passed"
            let step = spec.steps.first { $0.gateKey == k }?.gate ?? k
            return CheckResult(id: "gate.\(k)", block: area, title: "Gate: \(step)", level: passed ? .ok : .pending,
                               detail: passed ? "validated" : "not validated yet")
        }
    }
}
