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

    /// Version folders that hold only what the app wrote before anything of value (film.json, an empty scenes/ folder, notes of the assembler): a Build that stopped before its first
    /// file. They are removed, except `keep` (the version a Build could continue). Returns what was removed.
    @discardableResult
    public static func pruneHusks(_ store: ProjectStore, keep: String? = nil) -> [String] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: store.root.path)) ?? []
        var gone: [String] = []
        for n in names.filter({ $0.range(of: #"^v\d+$"#, options: .regularExpression) != nil && $0 != keep }).sorted(by: { Int($0.dropFirst())! < Int($1.dropFirst())! }) {
            let dir = store.root.appendingPathComponent(n)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue, let items = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            let mine: Set<String> = [Film.fileName, "assembly.json", "fonts.json", ".DS_Store", SceneModules.folder]
            guard items.allSatisfy({ mine.contains($0) }) else { continue }
            if items.contains(SceneModules.folder), !((try? fm.contentsOfDirectory(atPath: dir.appendingPathComponent(SceneModules.folder).path)) ?? ["x"]).isEmpty { continue }
            do { try fm.removeItem(at: dir); try? SceneModules.forget(version: n, store: store); gone.append(n) } catch { continue }
        }
        if !gone.isEmpty { store.logBuild(gone.joined(separator: ", "), "Removed empty version folder\(gone.count == 1 ? "" : "s") \(gone.joined(separator: ", "))", note: "a Build had stopped before writing anything but film.json") }
        return gone
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
        let notOK = live.filter { !$0.state.isReviewed }
        if !live.isEmpty { out.append(notOK.isEmpty ? r("reviewed", "Scene review", .ok, "every visible scene is Ready (a locked scene is Ready, a hidden one is ignored)") : r("reviewed", "Scene review", .pending, "\(notOK.map { $0.id }.joined(separator: ", ")) not Ready yet: switch Ready on in the scene's inspector")) }
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

    /// The whole-film brief is no longer one message: the frame's request (`BuildJob.frame`) and each scene's (`SceneGeneration.prompt`) take their parts from the three helpers below.
    /// The content items of every scene that is on, in priority order, with each attribute marked fixed or auto and the instructions.
    static func contentBrief(_ f: ShowreelFile?) -> String {
        guard let f = f else { return "" }
        return f.film.filter { !$0.content.isEmpty }.map { s -> String in
            let head = "\(s.id) (control level \(f.controlLevel(for: s).rawValue)):"
            let items = s.content.enumerated().map { n, i -> String in
                let subject = i.type == "text" ? "text \u{201C}\(i.text ?? "")\u{201D}" : "\(i.type) \(i.resource ?? "?")"
                let color = i.type == "text" ? "; colour: " + (i.color.isFixed ? "FIXED \(i.color.text)" + (i.color.mode == "role" ? " (\(f.paletteHex(i.color.role, for: s) ?? "role not in the palette"))" : "") : "AUTO") : ""
                let anim = i.type == "audio" ? "" : "; animation: " + (i.animation.isFixed ? "FIXED \(i.animation.text)" : "AUTO")
                let ins = i.hasInstruction ? "; instruction: \u{201C}\(i.instruction!)\u{201D}" : ""
                let when = "; timing in the scene: " + (i.timing.isFixed ? "FIXED \(i.timing.text) (seconds from the scene's start)" : "AUTO")
                return "   \(n + 1). \(subject)\(color)\(anim)\(when)\(ins)"
            }
            return ([head] + items).joined(separator: "\n")
        }.joined(separator: "\n")
    }

    /// film.json as quoted in the build message, indented to sit under the step.
    static func filmBrief(_ f: ShowreelFile?) -> String {
        guard let f = f else { return "" }
        return Film.text(f).split(separator: "\n").map { "   " + $0 }.joined(separator: "\n")
    }

    /// The passages between scenes and the music grid, for the build message.
    static func reelBrief(_ f: ShowreelFile?, store: ProjectStore) -> String {
        guard let f = f else { return "" }
        var lines: [String] = []
        let tl = f.timeline()
        let named = tl.enumerated().filter { $0.offset + 1 < tl.count && !$0.element.item.transition.isCut }
        if named.isEmpty { lines.append("Every scene change is a cut on the beat (the default).") }
        else {
            lines.append("Transitions belong to a pair of scenes: each overlaps the end of the outgoing scene and the start of the incoming one over its duration, and the film's length does not change; SRF.film draws both scene modules and mixes them with the transition of the catalogue, so do not draw transitions yourself. While one runs the outgoing module keeps drawing past its end and the incoming one starts at lt 0. Other scene changes are cuts on the beat. A transition marked with an instruction (for a match cut: which element becomes which) tells both neighbouring modules what to draw.")
            for (i, t) in named { lines.append("   \(t.scene.id) -> \(tl[i + 1].scene.id): \(t.item.transition.text)" + (Look.isPreviewOnly(t.item.transition.type) ? " (a preview-only transition: it does not run between real scenes, use a cut and say so)" : "")) }
        }
        if f.decisions.track?.file != nil, let a = MusicAnalysis.load(root: store.root) {
            let manual = f.decisions.track?.manual == true ? " (corrected by the user)" : ""
            var g = "Music grid\(manual), constant tempo: \(ProjectDocs.seconds(a.bpm)) BPM, first beat \(ProjectDocs.seconds(a.firstBeat)) s, \(a.bars.count) bars."
            if let d = a.strongestDrop { g += " Strongest drop at \(ProjectDocs.seconds(d)) s: land the film's biggest moment there." }
            if !a.breaks.isEmpty { g += " Breaks (bass out): " + a.breaks.map { "\(ProjectDocs.seconds($0.start))-\(ProjectDocs.seconds($0.end)) s" }.joined(separator: ", ") + "." }
            g += " Scene starts: " + tl.map { "\($0.scene.id) \($0.start.map { ProjectDocs.seconds($0) } ?? "?") s (\($0.start.flatMap { a.gridKind($0) } ?? "off the grid"))" }.joined(separator: ", ") + "."
            lines.append(g)
        } else if let t = f.decisions.track?.file { lines.append("Music: \((t as NSString).lastPathComponent), not analysed (no grid): use the times of the storyboard.") }
        return lines.joined(separator: "\n")
    }

    /// What the step "3D scenes" says. The words are the skill's own promise: the logic test cannot draw WebGL, the film is judged in the player, and there is no MP4 for it here.
    public static let threeDNote = "This film has 3D scenes. The logic test cannot draw them: play the film to look at them. No MP4 export for this film."

    /// Whether the harness said that the film's 3D scenes were not rendered (its line "3D layer: no WebGL in this host, ..."). A film without 3D never prints it.
    public static func hasThreeD(harnessOutput lines: [String]) -> Bool { lines.contains { $0.hasPrefix("3D layer: no WebGL") } }

    static func q(_ u: URL) -> String { "'" + u.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Builds the version with the skill's build.py, then runs harness.js and smoke_player.js on the result. Outputs go to
    /// `<project>/<version>/dist`, never into the app bundle. Nothing here needs an AI.
    public static func run(version: String, store: ProjectStore, skill: URL) async -> BuildReport {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "build." + id, block: "build", title: title, level: level, detail: detail) }
        let vdir = store.root.appendingPathComponent(version)
        let scripts = skill.appendingPathComponent("scripts")
        guard FileManager.default.fileExists(atPath: vdir.appendingPathComponent("project.json").path),
              FileManager.default.fileExists(atPath: vdir.appendingPathComponent("main.js").path) || SceneModules.usesSceneFiles(version: version, store: store) else {
            return BuildReport(version: version, steps: [r("make", "Build \(version)", .fail, "\(version) has no project.json, and neither main.js nor a scenes/ folder, yet.")])
        }
        var steps: [CheckResult] = []
        var threeD = false
        var layoutWarnings = 0, layoutLines: [String] = []
        let embeddedFonts = FontEmbedding.write(version: version, store: store)         // the Look's approved font files, for build.py to embed (only the weights used)
        func tail(_ s: String, _ n: Int = 700) -> String { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.count > n ? "..." + t.suffix(n) : t }

        guard let b = await Shell.run("python3 \(q(scripts.appendingPathComponent("build.py"))) \(q(vdir))", in: store.root, timeout: 180) else {
            return BuildReport(version: version, steps: [r("make", "Build \(version)", .fail, "could not start python3")])
        }
        if b.status != 0 {
            return BuildReport(version: version, steps: [r("make", "Build \(version)", .fail, tail(b.err.isEmpty ? b.out : b.err))])
        }
        let weight = b.out.split(separator: "\n").last.map(String.init) ?? "built"
        steps.append(r("make", "Build \(version)", .ok, tail(weight, 200)))
        // a Look font with no approved file is said, never silently replaced by a system font
        if let fs = FontEmbedding.step(store, entries: embeddedFonts) { steps.append(r("fonts", "Fonts", fs.ok ? .ok : .tight, fs.text)) }
        // scene-file format: a scene with no usable file is a placeholder frame in the film, said here instead of hidden (the older format has no such step)
        if SceneModules.usesSceneFiles(version: version, store: store) {
            let gone = SceneModules.ungenerated(version: version, store: store)
            if !gone.isEmpty { steps.append(r("scenes", "Scene files", .tight, "\(gone.joined(separator: ", ")) not generated: shown as an empty frame with its ID until its file is written")) }
        }

        let html = vdir.appendingPathComponent("dist/index.html")
        if let h = await Shell.run("node \(q(scripts.appendingPathComponent("harness.js"))) \(q(html))", in: store.root, timeout: 240) {
            let lines = h.out.split(separator: "\n").map(String.init)
            threeD = hasThreeD(harnessOutput: lines)
            let issues = lines.first { $0.hasPrefix("issues:") }.flatMap { Int($0.dropFirst(7).trimmingCharacters(in: .whitespaces)) }
            let sorted = SceneTest.parse(h.out)             // the harness sorts what it finds: code errors (they fail the test) and layout warnings (a matter of taste)
            if h.status == 127 || issues == nil && h.status != 0 && h.err.contains("not found") {
                steps.append(r("harness", "Logic test", .fail, "node is not available: run the setup check. " + tail(h.err, 200)))
            } else if let t = sorted {
                let counts = "\(t.codeCount) code error\(t.codeCount == 1 ? "" : "s"), \(t.warningCount) layout warning\(t.warningCount == 1 ? "" : "s")"
                if t.ok { steps.append(r("harness", "Logic test", .ok, counts + ": no exception, no value that is not a number")) }
                else { steps.append(r("harness", "Logic test", .fail, counts + ": " + tail(t.codeErrors.joined(separator: "\n")))) }
                // layout warnings (text outside the stage, text over text) are said apart: they are for the user to judge, they do not fail the test
                if t.warningCount > 0 { layoutWarnings = t.warningCount; layoutLines = t.warnings }
            } else if issues == 0 {
                steps.append(r("harness", "Logic test", .ok, "0 issues: no exception, no text outside the stage, no collision"))
            } else {
                let detail = lines.filter { $0.hasPrefix("-") || $0.contains("ISSUE") || $0.lowercased().contains("issue") }.prefix(6).joined(separator: "\n")
                steps.append(r("harness", "Logic test", .fail, "\(issues.map { "\($0) issue(s)" } ?? "failed"): " + tail(detail.isEmpty ? h.out + h.err : detail)))
            }
        } else { steps.append(r("harness", "Logic test", .fail, "could not start node")) }
        // A film with 3D scenes: the Node host has no WebGL, so the logic test could not draw them and says so in one line. The logic test stays green for what it checks (0 issues);
        // this separate step says what it could not see. It is a warning: it blocks neither the build gate nor the verify gate.
        if threeD { steps.append(r("3d", "3D scenes", .tight, threeDNote)) }
        if layoutWarnings > 0 { steps.append(r("layout", "Layout warnings", .tight, "\(layoutWarnings) layout warning\(layoutWarnings == 1 ? "" : "s"): " + tail(layoutLines.prefix(4).joined(separator: "\n"), 400))) }

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
        // what this version was tested to, kept per version: the version that is read is the last one whose result is green (see Versions.working)
        let green = report.built && report.harnessClean && report.smokeClean
        try? SceneModules.recordResult(version: report.version, ok: green, store: self)
        if green, SceneModules.usesSceneFiles(version: report.version, store: self) { try? SceneModules.recordAssembly(version: report.version, store: self) }
    }
}
