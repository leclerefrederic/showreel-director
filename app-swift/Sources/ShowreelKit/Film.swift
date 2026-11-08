import Foundation

/// The montage as the build reads it: `film.json` in the version folder (scenes with name, start, duration and the transition to the next one).
/// The app writes it from the montage and the build message quotes it, so the agent never copies starts, durations or transitions by hand;
/// `build.py` inlines it as `SR.data.film` and `SRF.fromData` (engine/film.js) reads it.
public enum Film {
    public static let fileName = "film.json"

    /// The film as plain data: one entry per scene that is on, named by its ID, in order. A transition is listed for a scene that has a successor
    /// and a transition other than the default cut, with the duration it will really have.
    public static func data(_ f: ShowreelFile) -> [String: Any] {
        let tl = f.timeline()
        var scenes: [[String: Any]] = []
        for (i, t) in tl.enumerated() {
            var s: [String: Any] = ["name": t.scene.id, "t": ((t.start ?? 0) * 1000).rounded() / 1000]
            if let l = t.length { s["duration"] = (l * 1000).rounded() / 1000 }
            let tr = t.item.transition
            if i + 1 < tl.count, !tr.isCut {
                var o: [String: Any] = ["type": tr.type, "duration": tr.duration ?? f.defaultTransitionDuration(tr.type, between: t.scene, and: tl[i + 1].scene)]
                if let p = tr.params { o["params"] = p.any }
                if let ins = tr.instruction, !ins.isEmpty { o["instruction"] = ins }
                s["transition"] = o
            }
            scenes.append(s)
        }
        var out: [String: Any] = ["schema": 1, "scenes": scenes]
        if let d = f.decisions.duration { out["duration"] = d }
        return out
    }

    public static func text(_ f: ShowreelFile) -> String {
        let d = (try? JSONSerialization.data(withJSONObject: data(f), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: d, as: UTF8.self) + "\n"
    }

    /// Creates the version folder and writes film.json in it from the montage. Called before the build message is sent.
    @discardableResult
    public static func write(version: String, store: ProjectStore) throws -> URL {
        guard let f = store.loadShowreel() else { throw AgentError.msg("there is no showreel.json") }
        let dir = store.root.appendingPathComponent(version)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try text(f).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Whether a built version still matches the montage: nil when the version has no film.json (built before, or in the older format).
    public static func isCurrent(version: String, store: ProjectStore) -> Bool? {
        guard let f = store.loadShowreel(), let mine = try? String(contentsOf: store.root.appendingPathComponent(version).appendingPathComponent(fileName), encoding: .utf8) else { return nil }
        return mine == text(f)
    }
}
