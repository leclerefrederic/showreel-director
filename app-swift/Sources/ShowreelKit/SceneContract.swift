import Foundation

/// What Clap is given to write ONE scene: the contract of the file, the engine's API that matters, what the other scenes already say, the music under this scene. Everything
/// that describes the engine is read from the skill's own files (the copy inside the app), never written again by hand, so it cannot say anything the skill does not.
public enum SceneContract {
    /// The `## <title>` section of a markdown file, with its heading; empty when there is none.
    static func section(_ title: String, in text: String) -> String {
        guard let a = text.range(of: "## \(title)") else { return "" }
        let rest = text[a.lowerBound...]
        let end = rest.dropFirst(3).range(of: "\n## ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first block comment of a script: its documentation of the API.
    static func header(of js: String) -> String {
        guard let a = js.range(of: "/*"), let b = js.range(of: "*/", range: a.upperBound..<js.endIndex) else { return "" }
        return String(js[a.lowerBound..<b.upperBound])
    }

    static func read(_ skill: URL, _ path: String) -> String { (try? String(contentsOf: skill.appendingPathComponent(path), encoding: .utf8)) ?? "" }

    /// The parts of the contract, in the order they are given: (title, text). Each comes from one file of the skill.
    public static func parts(skill: URL) -> [(title: String, text: String)] {
        let engine = read(skill, "references/engine.md")
        return [("The scene file (references/engine.md, Scene files)", section("Scene files", in: engine)),
                ("What the engine provides (references/engine.md)", section("What the engine provides", in: engine)),
                ("Drawing helpers SRK (header of engine/kit.js)", header(of: read(skill, "engine/kit.js"))),
                ("Backgrounds SRB (header of engine/backgrounds.js)", header(of: read(skill, "engine/backgrounds.js"))),
                ("Starting point (engine/scene.template.js)", read(skill, "engine/scene.template.js").trimmingCharacters(in: .whitespacesAndNewlines))]
            .filter { !$0.1.isEmpty }
    }

    public static func text(skill: URL) -> String { parts(skill: skill).map { "### \($0.title)\n\($0.text)" }.joined(separator: "\n\n") }

    // MARK: what the other scenes already say

    /// The engine names a written file uses (`SRK.slam`, `SRB.draw`, `SR3D.scene`...), the most used first, at most `limit`: computed from the file, not asked of the model.
    static func uses(_ js: String, limit: Int = 6) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"\b(SRK|SRB|SR3D)\.([A-Za-z_]\w*)"#) else { return [] }
        var count: [String: Int] = [:]
        for m in re.matches(in: js, range: NSRange(js.startIndex..., in: js)) { if let r = Range(m.range, in: js) { count[String(js[r]), default: 0] += 1 } }
        return count.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(limit).map { $0.key }
    }

    /// A few lines on the scenes already written in this version (not the one being written): id, words, feeling, animations. Empty while there are none.
    public static func summary(version: String, store: ProjectStore, excluding id: String) -> String {
        guard let f = store.loadShowreel() else { return "" }
        let lines: [String] = f.film.compactMap { s in
            guard s.id != id, let js = try? String(contentsOf: SceneModules.url(version: version, scene: s.id, store: store), encoding: .utf8) else { return nil }
            let words = s.text.isEmpty ? "no words" : "\u{201C}" + clip(s.text, limit: 60) + "\u{201D}"
            let fixed = s.content.compactMap { $0.animation.isFixed ? $0.animation.text : nil }.prefix(2)
            let u = uses(js) + fixed.map { "animation \u{201C}\($0)\u{201D}" }
            return "- \(s.id): \(words); feeling: \(s.feeling.isEmpty ? "(none)" : clip(s.feeling, limit: 50)); uses: \(u.isEmpty ? "(plain 2D drawing)" : u.joined(separator: ", "))"
        }
        return lines.joined(separator: "\n")
    }

    // MARK: the music under the scene

    /// The grid under this scene: tempo, the bars and beats it covers, a drop or a break inside it. Nil without an analysed track.
    public static func music(scene id: String, store: ProjectStore) -> String? {
        guard let f = store.loadShowreel(), f.decisions.track?.file != nil, let a = MusicAnalysis.load(root: store.root),
              let t = f.timeline().first(where: { $0.scene.id == id }), let s = t.start, let e = t.end else { return nil }
        let bars = a.bars.enumerated().filter { $0.element >= s - MusicAnalysis.tolerance && $0.element < e - MusicAnalysis.tolerance }
        var out = "Music: \(ProjectDocs.seconds(a.bpm)) BPM, constant tempo. This scene covers \(ProjectDocs.seconds(s)) s to \(ProjectDocs.seconds(e)) s (\(a.gridKind(s).map { "it starts on a \($0)" } ?? "it starts off the grid"))."
        if !bars.isEmpty { out += " Bars starting inside it, in seconds of the film: " + bars.map { "\($0.offset + 1): \(ProjectDocs.seconds($0.element))" }.joined(separator: ", ") + " (local time lt = film time minus \(ProjectDocs.seconds(s)))." }
        let drops = a.dropBars.filter { $0 < a.bars.count && a.bars[$0] >= s && a.bars[$0] < e }.map { ProjectDocs.seconds(a.bars[$0]) }
        if !drops.isEmpty { out += " A drop lands inside it at \(drops.joined(separator: ", ")) s." }
        let breaks = a.breakdowns.filter { $0.start < e && $0.end > s }.map { "\(ProjectDocs.seconds($0.start))-\(ProjectDocs.seconds($0.end)) s" }
        if !breaks.isEmpty { out += " A break (bass out) overlaps it: \(breaks.joined(separator: ", "))." }
        return out
    }
}
