import Foundation

/// The test of ONE scene file, right after it is written: the skill's own harness (`harness.js --scene`), with no AI and no cost, on a scratch copy of the version that holds the
/// frame, the montage and that one scene file (the others are the empty frames the assembler puts in place of a missing file). It sorts what it finds like the harness does:
/// code errors (an exception, a file that does not load or is not valid JavaScript, a non-finite value) and layout warnings (text outside the stage, collisions).
public struct SceneTestResult: Equatable, Sendable {
    public let codeErrors: [String]
    public let warnings: [String]
    public let codeCount: Int
    public let warningCount: Int
    public var ok: Bool { codeCount == 0 }
}

public enum SceneTest {
    /// How many times a scene that fails its test is repaired in one Build: once, never more.
    public static let repairsPerScene = 1

    /// Test hook: replaces the harness (a test scripts what the test finds without node).
    nonisolated(unsafe) static var override: ((String, String) async -> SceneTestResult?)?

    /// What the harness printed: the counts and the listed lines, each starting with its kind.
    static func parse(_ out: String) -> SceneTestResult? {
        let lines = out.split(separator: "\n").map(String.init)
        func count(_ p: String) -> Int? { lines.first { $0.hasPrefix(p) }.flatMap { Int($0.dropFirst(p.count).trimmingCharacters(in: .whitespaces)) } }
        guard let code = count("code errors:"), let layout = count("layout warnings:") else { return nil }
        let strip = { (l: String, k: String) in String(l.drop { $0 == " " }.dropFirst(k.count + 2)) }
        return SceneTestResult(codeErrors: lines.filter { $0.hasPrefix("  code: ") }.map { strip($0, "code") }, warnings: lines.filter { $0.hasPrefix("  layout: ") }.map { strip($0, "layout") },
                               codeCount: code, warningCount: layout)
    }

    /// Nil when the test could not run here (no node, no python): the scene is then not tested, and the film's own test at the end still runs.
    public static func run(scene id: String, version: String, store: ProjectStore, skill: URL) async -> SceneTestResult? {
        if let o = override { return await o(id, version) }
        let fm = FileManager.default
        let frame = id == BuildJob.frameStep          // the frame is tested with no scene in it (every scene is an empty frame), the whole film's checks
        let scratch = store.root.appendingPathComponent(".scenetest-\(version)-\(id)")          // next to the versions, so that ../assets and ../analysis resolve
        try? fm.removeItem(at: scratch)
        defer { try? fm.removeItem(at: scratch) }
        let src = store.root.appendingPathComponent(version)
        do {
            try fm.createDirectory(at: scratch.appendingPathComponent(SceneModules.folder), withIntermediateDirectories: true)
            for n in ["project.json", "reel.js", Film.fileName, "fonts.json"] where fm.fileExists(atPath: src.appendingPathComponent(n).path) { try fm.copyItem(at: src.appendingPathComponent(n), to: scratch.appendingPathComponent(n)) }
            if !frame { try fm.copyItem(at: SceneModules.url(version: version, scene: id, store: store), to: scratch.appendingPathComponent("\(SceneModules.folder)/\(id).js")) }
        } catch { return nil }
        let scripts = skill.appendingPathComponent("scripts")
        if Task.isCancelled { return nil }
        guard let b = await Shell.run("python3 \(BuildRunner.q(scripts.appendingPathComponent("build.py"))) \(BuildRunner.q(scratch))", in: store.root, timeout: 180) else { return nil }
        if b.status != 0 { let t = (b.err.isEmpty ? b.out : b.err).trimmingCharacters(in: .whitespacesAndNewlines); return SceneTestResult(codeErrors: ["build failed: " + clip(t, limit: 400)], warnings: [], codeCount: 1, warningCount: 0) }
        // the assembler says why a file could not be used (not valid JavaScript, no return): the page would only show an empty frame
        if !frame, let d = try? Data(contentsOf: scratch.appendingPathComponent("assembly.json")), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
           let rows = o["scenes"] as? [[String: Any]], let row = rows.first(where: { ($0["id"] as? String) == id }), (row["status"] as? String) != "module" {
            return SceneTestResult(codeErrors: ["the scene file cannot be used: \(row["message"] as? String ?? row["status"] as? String ?? "invalid")"], warnings: [], codeCount: 1, warningCount: 0)
        }
        guard let h = await Shell.run("node \(BuildRunner.q(scripts.appendingPathComponent("harness.js"))) \(BuildRunner.q(scratch.appendingPathComponent("dist/index.html")))" + (frame ? "" : " --scene \(id)"), in: store.root, timeout: 240) else { return nil }
        if h.status == 127 { return nil }
        return parse(h.out)
    }
}
