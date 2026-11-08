import Foundation

/// The version folders of a project (`v1`, `v2`...), what the build needs, and the run of the skill's own build and test scripts.
public enum Versions {
    /// `vN` folders that hold a project.json, in numeric order.
    public static func list(_ store: ProjectStore) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: store.root.path)) ?? []
        return names.filter { $0.range(of: #"^v\d+$"#, options: .regularExpression) != nil
                && FileManager.default.fileExists(atPath: store.root.appendingPathComponent($0 + "/project.json").path) }
            .sorted { Int($0.dropFirst())! < Int($1.dropFirst())! }
    }

    /// The next version name: one past the highest `vN` folder, even an empty one (a version is never overwritten).
    public static func next(_ store: ProjectStore) -> String {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: store.root.path)) ?? []
        let n = names.compactMap { $0.range(of: #"^v\d+$"#, options: .regularExpression) != nil ? Int($0.dropFirst()) : nil }.max() ?? 0
        return "v\(n + 1)"
    }

    public static func distURL(_ store: ProjectStore, _ version: String) -> URL { store.root.appendingPathComponent(version + "/dist/index.html") }
    public static func hasDist(_ store: ProjectStore, _ version: String) -> Bool { FileManager.default.fileExists(atPath: distURL(store, version).path) }
}

public struct BuildReport: Equatable, Sendable {
    public let version: String
    public let steps: [CheckResult]
    public var ok: Bool { !steps.isEmpty && steps.allSatisfy { $0.level == .ok } }
    public var built: Bool { steps.first { $0.id == "build.make" }?.level == .ok }
    public var harnessClean: Bool { steps.first { $0.id == "build.harness" }?.level == .ok }
    public var smokeClean: Bool { steps.first { $0.id == "build.smoke" }?.level == .ok }
}

public enum BuildRunner {
    /// What must be true before the AI writes a version. Deterministic, no AI. The Go is never inferred: it is the user's action.
    public static func readiness(_ store: ProjectStore) -> [CheckResult] {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "build." + id, block: "build", title: title, level: level, detail: detail) }
        guard let f = store.loadShowreel() else { return [r("project", "Project", .pending, "No project data yet.")] }
        var out: [CheckResult] = []
        let live = SceneRules.live(f)
        out.append(live.isEmpty ? r("scenes", "Scenes", .pending, "No scene yet: write the storyboard first.") : r("scenes", "Scenes", .ok, "\(live.count) scene\(live.count == 1 ? "" : "s")"))
        let notOK = live.filter { $0.status != "ok" }
        if !live.isEmpty { out.append(notOK.isEmpty ? r("reviewed", "Scene review", .ok, "every scene is OK") : r("reviewed", "Scene review", .pending, "\(notOK.map { $0.id }.joined(separator: ", ")) still to review")) }
        let go = f.gates["review"] == "passed"
        out.append(go ? r("go", "The Go", .ok, "given by you") : r("go", "The Go", .pending, "not given: the build never starts without it. Give it in the Scene editor."))
        let held = Assets.load(store).filter { $0.status == "hold" }
        if !held.isEmpty { out.append(r("held", "Held files", .tight, held.map { $0.name }.joined(separator: ", ") + ": on hold, so not used in the film")) }
        return out
    }

    public static func canBuild(_ store: ProjectStore) -> Bool {
        guard let f = store.loadShowreel() else { return false }
        return f.gates["review"] == "passed" && !SceneRules.live(f).isEmpty
    }

    /// The message that asks the existing agent to write the version folder. The app runs the build and the tests itself afterwards.
    public static func prompt(version: String, store: ProjectStore) -> String {
        let f = store.loadShowreel()
        let dur = f?.decisions.duration.map { ProjectDocs.seconds($0) + " s" } ?? "the end of the last scene"
        let langs = (f?.reelLanguages ?? []).joined(separator: ", ")
        return """
        The user pressed Go in the app: the storyboard is validated and every scene is OK. Write the new version folder \(version)/ now.

        Do this:
        1. Read the state with get_state, read storyboard.md, style-sheet.md and brief.md of the project, and read the skill's references/build-guide.md, references/steps-3-to-6.md (Step 3) and references/engine.md.
        2. Write \(version)/project.json starting from engine/project.template.json, and \(version)/main.js starting from engine/main.template.js, with write_file. Paths in project.json are relative to \(version)/.
        3. main.js implements the storyboard scene by scene with the stable IDs as scene names, the Time column of storyboard.md as scene starts (t in seconds, there is no beat map; scenes marked off or archived are not in the film), the on-screen text in each reel language (\(langs.isEmpty ? "the language of the brief" : langs)), the palette, the fonts, the background and the effects pack or moods the user chose, and the linked approved assets. The film lasts \(dur). Every scene honours ctx.reduced.
        4. Use only approved assets listed in assets/MANIFEST.csv, from assets/prepared or assets/generated. Do not embed a font file that is not an approved asset: set the family in tokens and let the reel fall back to a system font, and say so in your answer. Add the formats of the brief (16:9 as d, 9:16 as m).
        5. Do not change any decision, scene or asset, do not run build.py, the harness or the smoke test (the app runs them next and shows the user the result), and do not give or assume any Go beyond this one. Do not write outside \(version)/.
        Answer in two short lines: what you built, and anything you could not do.
        """
    }

    static func q(_ u: URL) -> String { "'" + u.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Builds the version with the skill's build.py, then runs harness.js and smoke_player.js on the result. Outputs go to
    /// `<project>/<version>/dist`, never into the app bundle. Nothing here needs an AI.
    public static func run(version: String, store: ProjectStore, skill: URL) async -> BuildReport {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "build." + id, block: "build", title: title, level: level, detail: detail) }
        let vdir = store.root.appendingPathComponent(version)
        let scripts = skill.appendingPathComponent("scripts")
        guard FileManager.default.fileExists(atPath: vdir.appendingPathComponent("project.json").path),
              FileManager.default.fileExists(atPath: vdir.appendingPathComponent("main.js").path) else {
            return BuildReport(version: version, steps: [r("make", "Build \(version)", .fail, "\(version) has no project.json or main.js yet.")])
        }
        var steps: [CheckResult] = []
        func tail(_ s: String, _ n: Int = 700) -> String { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.count > n ? "..." + t.suffix(n) : t }

        guard let b = await Shell.run("python3 \(q(scripts.appendingPathComponent("build.py"))) \(q(vdir))", in: store.root, timeout: 180) else {
            return BuildReport(version: version, steps: [r("make", "Build \(version)", .fail, "could not start python3")])
        }
        if b.status != 0 {
            return BuildReport(version: version, steps: [r("make", "Build \(version)", .fail, tail(b.err.isEmpty ? b.out : b.err))])
        }
        let weight = b.out.split(separator: "\n").last.map(String.init) ?? "built"
        steps.append(r("make", "Build \(version)", .ok, tail(weight, 200)))

        let html = vdir.appendingPathComponent("dist/index.html")
        if let h = await Shell.run("node \(q(scripts.appendingPathComponent("harness.js"))) \(q(html))", in: store.root, timeout: 240) {
            let lines = h.out.split(separator: "\n").map(String.init)
            let issues = lines.first { $0.hasPrefix("issues:") }.flatMap { Int($0.dropFirst(7).trimmingCharacters(in: .whitespaces)) }
            if h.status == 127 || issues == nil && h.status != 0 && h.err.contains("not found") {
                steps.append(r("harness", "Logic test", .fail, "node is not available: run the setup check. " + tail(h.err, 200)))
            } else if issues == 0 {
                steps.append(r("harness", "Logic test", .ok, "0 issues: no exception, no text outside the stage, no collision"))
            } else {
                let detail = lines.filter { $0.hasPrefix("-") || $0.contains("ISSUE") || $0.lowercased().contains("issue") }.prefix(6).joined(separator: "\n")
                steps.append(r("harness", "Logic test", .fail, "\(issues.map { "\($0) issue(s)" } ?? "failed"): " + tail(detail.isEmpty ? h.out + h.err : detail)))
            }
        } else { steps.append(r("harness", "Logic test", .fail, "could not start node")) }

        if let s = await Shell.run("node \(q(scripts.appendingPathComponent("smoke_player.js"))) \(q(html))", in: store.root, timeout: 120) {
            let lines = s.out.split(separator: "\n").map(String.init)
            let fails = lines.filter { $0.hasPrefix("FAIL") }
            let passes = lines.filter { $0.hasPrefix("PASS") }.count
            if s.err.contains("Cannot find module") && s.err.contains("jsdom") {
                steps.append(r("smoke", "Player test", .fail, "jsdom is missing: run the setup check to install it"))
            } else if fails.isEmpty && passes > 0 && s.status == 0 {
                steps.append(r("smoke", "Player test", .ok, "\(passes) checks passed: start, pause, seek, replay, switches"))
            } else {
                steps.append(r("smoke", "Player test", .fail, tail(fails.isEmpty ? s.out + s.err : fails.joined(separator: "\n"))))
            }
        } else { steps.append(r("smoke", "Player test", .fail, "could not start node")) }
        return BuildReport(version: version, steps: steps)
    }
}

extension ProjectStore {
    /// After a run: the build gate follows the build and the logic test, the verify gate follows the player test too.
    /// These are results of deterministic checks, not decisions; the user can still reopen them.
    public func record(_ report: BuildReport) throws {
        guard var f = loadShowreel() else { return }
        f.gates["build"] = report.built && report.harnessClean ? "passed" : "open"
        f.gates["verify"] = report.built && report.harnessClean && report.smokeClean ? "passed" : "open"
        try save(f)
    }
}
