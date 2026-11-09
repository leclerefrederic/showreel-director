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

    // MARK: the exact form of the engine's objects

    /// What each name exported by a script is, read from the script itself: a function (with its parameters), an object (with its functions) or a plain value. `export` is the
    /// assignment that exposes them (`G.SR = {`), `prefix` how a scene reaches them (`SR`).
    static func shapes(of js: String, export: String, prefix: String) -> String {
        guard let a = js.range(of: export), let b = js.range(of: "}", range: a.upperBound..<js.endIndex) else { return "" }
        // an entry is `name` or `name: other` (exposed under another name)
        let entries = js[a.upperBound..<b.lowerBound].split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let names = entries.map { $0.split(separator: ":").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? $0 }
        let local = Dictionary(uniqueKeysWithValues: entries.map { e -> (String, String) in
            let p = e.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            return (p[0], p.count > 1 ? p[1] : p[0])
        })
        func regex(_ p: String) -> NSRegularExpression? { try? NSRegularExpression(pattern: p) }
        func first(_ re: NSRegularExpression?, _ n: String) -> NSTextCheckingResult? { re?.firstMatch(in: js, range: NSRange(js.startIndex..., in: js)) }
        func group(_ m: NSTextCheckingResult, _ i: Int) -> String { Range(m.range(at: i), in: js).map { String(js[$0]) } ?? "" }
        var lines: [String] = []
        for n in names {
            let q = NSRegularExpression.escapedPattern(for: local[n] ?? n)
            if let m = first(regex(#"(?:const|let|var)\s+"# + q + #"\s*=\s*\{"#), n), let open = Range(m.range, in: js)?.upperBound {
                // an object: its functions are the keys whose value is an arrow function; the block ends at the matching brace
                var depth = 1, i = open
                while i < js.endIndex, depth > 0 { if js[i] == "{" { depth += 1 } else if js[i] == "}" { depth -= 1 }; i = js.index(after: i) }
                let body = String(js[open..<i])
                let keys = regex(#"(?:^|[,{\s])([A-Za-z_]\w*)\s*:\s*(?:\(?([\w\s,=]*)\)?\s*=>|function)"#)?.matches(in: body, range: NSRange(body.startIndex..., in: body)) ?? []
                let fns = keys.compactMap { k -> (String, String)? in
                    guard let r = Range(k.range(at: 1), in: body) else { return nil }
                    return (String(body[r]), Range(k.range(at: 2), in: body).map { String(body[$0]).trimmingCharacters(in: .whitespaces) } ?? "")
                }
                if fns.isEmpty { lines.append("\(prefix).\(n): an object (data), not a function") }
                else {
                    let ex = ([fns.first, fns.last].compactMap { $0 }.map { "\(prefix).\(n).\($0.0)(\($0.1))" }).joined(separator: ", ")
                    lines.append("\(prefix).\(n): an object, never a function. Its functions: \(fns.map { $0.0 }.joined(separator: ", ")). Call them as \(ex), never \(prefix).\(n)(...)")
                }
            } else if let m = first(regex(#"(?:const|let|var)\s+"# + q + #"\s*=\s*(?:\(([^)]*)\)|([A-Za-z_]\w*))\s*=>"#), n) {
                let params = group(m, 1).isEmpty ? group(m, 2) : group(m, 1)
                lines.append("\(prefix).\(n)(\(params)): a function")
            } else if let m = first(regex(#"function\s+"# + q + #"\s*\(([^)]*)\)"#), n) {
                lines.append("\(prefix).\(n)(\(group(m, 1))): a function")
            } else if let m = first(regex(#"(?:const|let|var)\s+"# + q + #"\s*=\s*([A-Za-z_][\w]*(?:\.[A-Za-z_]\w*)+)\s*;"#), n) {
                lines.append("\(prefix).\(n)(...): a function (the same as \(group(m, 1)))")          // an alias of another function, such as `const ex = SR.ease.outExpo`
            } else { lines.append("\(prefix).\(n): a value (data)") }
        }
        return lines.joined(separator: "\n")
    }

    /// The form of `SR` (engine/core.js) and `SRK` (engine/kit.js), read from the two scripts.
    static func engineShapes(skill: URL) -> String {
        let sr = shapes(of: read(skill, "engine/core.js"), export: "G.SR = {", prefix: "SR")
        let kit = shapes(of: read(skill, "engine/kit.js"), export: "G.SRK = {", prefix: "SRK")
        let note = "A scene file takes what it needs with `const { clamp, ease } = SR;` and then writes `ease.out3(t)`: an object's function is always called through the object."
        return [sr.isEmpty ? "" : "window.SR:\n" + sr, kit.isEmpty ? "" : "window.SRK:\n" + kit, note].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// The parts of the contract, in the order they are given: (title, text). Each comes from one file of the skill.
    public static func parts(skill: URL) -> [(title: String, text: String)] {
        let engine = read(skill, "references/engine.md")
        return [("The scene file (references/engine.md, Scene files)", section("Scene files", in: engine)),
                ("What the engine provides (references/engine.md)", section("What the engine provides", in: engine)),
                ("Exact form of the engine's names (read from engine/core.js and engine/kit.js)", engineShapes(skill: skill)),
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
