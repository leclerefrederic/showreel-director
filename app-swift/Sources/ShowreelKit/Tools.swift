import Foundation

/// Thread-safe output buffer for a child process.
/// @unchecked Sendable: every stored property is only touched under `lock`.
public final class OutputBuffer: @unchecked Sendable {
    public init() {}
    private let lock = NSLock()
    private var out = Data(), err = Data()
    private var _timedOut = false
    public var timedOut: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _timedOut }
        set { lock.lock(); _timedOut = newValue; lock.unlock() }
    }
    public func add(_ d: Data, isErr: Bool) { lock.lock(); if isErr { err.append(d) } else { out.append(d) }; lock.unlock() }
    public func text() -> (String, String) {
        lock.lock(); defer { lock.unlock() }
        return (String(decoding: out, as: UTF8.self), String(decoding: err, as: UTF8.self))
    }
}

/// What a tool hands back to the model: text, and optionally an image (a screenshot).
public struct ToolResult {
    public var text: String
    public var image: Data? = nil
    public init(text: String, image: Data? = nil) { self.text = text; self.image = image }
}

public final class Tools {
    public let project: URL
    public let skill: URL
    public let ui: AgentUI
    public let store: ProjectStore

    public init(project: URL, skill: URL, ui: AgentUI) {
        self.project = project; self.skill = skill; self.ui = ui
        self.store = ProjectStore(root: project)
    }

    /// Tool definitions shared with the Electron app (app-swift/shared/tools.json).
    public static let definitions: [[String: Any]] = {
        guard let u = resource("shared", dev: "app-swift/shared")?.appendingPathComponent("tools.json"),
              let d = try? Data(contentsOf: u),
              let a = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return a
    }()

    /// Keeps Python from writing .pyc files into the (signed, read-only) skill folder, then puts the app's own Python venv and node modules (made by tools/setup-env.sh) first, when they exist.
    public static let envSetup = "export PYTHONDONTWRITEBYTECODE=1; ENVDIR=\"$HOME/Library/Application Support/ShowreelStudio/env\"; [ -d \"$ENVDIR/venv/bin\" ] && export PATH=\"$ENVDIR/venv/bin:$PATH\"; [ -d \"$ENVDIR/node/node_modules\" ] && export NODE_PATH=\"$ENVDIR/node/node_modules${NODE_PATH:+:$NODE_PATH}\"; "

    private func abs(_ p: String) -> URL {
        if p.hasPrefix("/") { return URL(fileURLWithPath: p).standardizedFileURL }
        let a = project.appendingPathComponent(p).standardizedFileURL
        let b = skill.appendingPathComponent(p).standardizedFileURL
        let fm = FileManager.default
        // relative reads fall back to the skill folder
        return (!fm.fileExists(atPath: a.path) && fm.fileExists(atPath: b.path)) ? b : a
    }
    private func readable(_ u: URL) -> Bool { u.isInside(project) || u.isInside(skill) }

    /// The reason Clap gave for the change it is proposing (the `reason` of a typed tool): it goes in the journal with the operation.
    private var reason: String?

    public func run(_ name: String, _ input: [String: Any]) async -> ToolResult {
        reason = (input["reason"] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        if name == "screenshot_preview" {
            let wait = min(max(input["wait_ms"] as? Int ?? 600, 0), 5000)
            guard let jpeg = await ui.screenshot(javascript: input["javascript"] as? String, waitMs: wait) else {
                return ToolResult(text: "no page is open in the preview pane: call show_page first")
            }
            return ToolResult(text: "screenshot of the preview pane", image: jpeg)
        }
        return ToolResult(text: await runText(name, input))
    }

    private func runText(_ name: String, _ input: [String: Any]) async -> String {
        switch name {
        case "bash":
            return await bash(input["command"] as? String ?? "", input["timeout_ms"] as? Int ?? 120000)
        case "read_file":
            return readFile(input["path"] as? String ?? "", input["offset"] as? Int ?? 0, input["limit"] as? Int ?? 2000)
        case "write_file":
            return await writeFile(input["path"] as? String ?? "", input["content"] as? String ?? "")
        case "get_state":
            return await getState()
        case "propose_edit":
            return await proposeEdit(input["file"] as? String ?? "", input["content"] as? String ?? "", input["note"] as? String ?? "")
        case "update_parameter":
            guard let key = ParameterKey(rawValue: input["key"] as? String ?? "") else {
                return "unknown parameter: use one of " + ParameterKey.allCases.map { $0.rawValue }.joined(separator: ", ")
            }
            return await operate(.parameter(key, input["value"] as? String ?? ""))
        case "update_decision":
            guard let key = DecisionKey(rawValue: input["key"] as? String ?? "") else {
                return "unknown decision: use one of " + DecisionKey.allCases.map { $0.rawValue }.joined(separator: ", ")
            }
            return await operate(.decisions([DecisionChange(key, input["value"] as? String ?? "")], title: nil))
        case "add_scene":
            return await operate(.addScene(id: (input["id"] as? String) ?? "", Self.sceneEdit(input)))
        case "update_scene":
            return await operate(.scene(id: input["id"] as? String ?? "", Self.sceneEdit(input)))
        case "add_content_item":
            return await operate(.content(scene: input["scene"] as? String ?? "", .add(Self.contentEdit(input), after: input["after"] as? String)))
        case "update_content_item":
            return await operate(.content(scene: input["scene"] as? String ?? "", .update(item: input["item"] as? String ?? "", Self.contentEdit(input))))
        case "remove_content_item":
            return await operate(.content(scene: input["scene"] as? String ?? "", .remove(item: input["item"] as? String ?? "")))
        case "move_content_item":
            return await operate(.content(scene: input["scene"] as? String ?? "", .move(item: input["item"] as? String ?? "", after: input["after"] as? String ?? "")))
        case "set_scene_duration":
            guard let d = (input["duration"] as? Double) ?? (input["duration"] as? Int).map(Double.init) else { return "duration must be a number of seconds" }
            return await operate(.resize(scene: input["scene"] as? String ?? "", duration: d, ripple: input["ripple"] as? Bool ?? true))
        case "set_transition":
            let d = (input["duration"] as? Double) ?? (input["duration"] as? Int).map(Double.init)
            return await operate(.transition(from: input["from"] as? String ?? "", TransitionEdit(type: input["type"] as? String, duration: d, params: input["params"] as? String, instruction: input["instruction"] as? String)))
        case "set_track":
            return await operate(.track(asset: input["asset"] as? String))
        case "set_grid":
            func num(_ k: String) -> Double? { (input[k] as? Double) ?? (input[k] as? Int).map(Double.init) }
            return await operate(.grid(bpm: num("bpm"), firstBeat: num("first_beat")))
        case "set_scene_override":
            guard let key = DecisionKey(rawValue: input["key"] as? String ?? ""), DecisionKey.sceneKeys.contains(key) else {
                return "unknown key: use one of " + DecisionKey.sceneKeys.map { $0.rawValue }.joined(separator: ", ")
            }
            return await operate(.sceneLook(id: input["id"] as? String ?? "", [DecisionChange(key, input["value"] as? String ?? "")]))
        case "enable_scene":
            guard let on = input["enabled"] as? Bool else { return "enabled must be true or false" }
            return await operate(.sceneEnabled(id: input["id"] as? String ?? "", enabled: on, montage: input["montage"] as? String))
        case "move_scene":
            return await operate(.moveScene(id: input["id"] as? String ?? "", after: input["after"] as? String ?? "", montage: input["montage"] as? String))
        case "update_asset":
            let st = (input["status"] as? String).flatMap { AssetStatus(rawValue: $0) }
            if input["status"] is String, st == nil { return "unknown status: use " + AssetStatus.allCases.map { $0.rawValue }.joined(separator: ", ") }
            return await operate(.asset(id: input["id"] as? String ?? "", status: st, note: input["note"] as? String,
                                        licence: input["licence_note"] as? String, scenes: input["scenes"] as? String))
        case "remember":
            return await remember(input)
        case "update_memory":
            return await updateMemory(input)
        case "forget":
            return await forgetMemory(input["id"] as? String ?? "")
        case "open_block":
            let id = input["block"] as? String ?? ""
            guard let spec = ProcessSpec.load(), let b = spec.block(id) else { return "unknown block: use one of " + Blocks.ids.joined(separator: ", ") }
            guard b.built else { return "the \(b.name) block is not built yet (coming in phase \(b.phase ?? "later")): say so to the user and carry on in the chat" }
            await ui.openBlock(id)
            return "opened the \(b.name) block"

        case "list_dir":
            return listDir(input["path"] as? String ?? "")
        case "ask_user":
            let qs = input["questions"] as? [[String: Any]] ?? []
            let answers = await ui.ask(qs)
            var lines: [String] = []
            for (i, q) in qs.enumerated() {
                let h = q["header"] as? String ?? "Q\(i + 1)"
                let a = (i < answers.count && !answers[i].isEmpty) ? answers[i] : "(no answer)"
                lines.append("\(h): \(a)")
            }
            return lines.joined(separator: "\n")
        case "show_page":
            let f = abs(input["path"] as? String ?? "")
            guard readable(f) else { return "refused: outside the project and skill folders" }
            guard FileManager.default.fileExists(atPath: f.path) else { return "not found: \(input["path"] as? String ?? "")" }
            ui.show(f.absoluteString, input["title"] as? String ?? f.lastPathComponent)
            return "opened in the preview pane"
        default:
            return "unknown tool \(name)"
        }
    }

    private func readFile(_ p: String, _ offset: Int, _ limit: Int) -> String {
        let f = abs(p)
        guard readable(f) else { return "refused: outside the project and skill folders" }
        guard let text = try? String(contentsOf: f, encoding: .utf8) else { return "not found or not text: \(p)" }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let slice = Array(lines.dropFirst(max(offset, 0)).prefix(max(limit, 0)))
        return clip(slice.enumerated().map { "\(offset + $0.offset + 1)\t\($0.element)" }.joined(separator: "\n"))
    }

    /// Prose and data files a person may be editing: the copilot's writes to them become proposals.
    private static let reviewedExtensions: Set<String> = ["md", "markdown", "json", "csv", "txt"]

    private func writeFile(_ p: String, _ content: String) async -> String {
        let f = abs(p)
        guard f.isInside(project), let rel = store.relativePath(of: f) else { return "refused: writes stay inside the project folder" }
        guard !store.isPrivate(rel) else { return "refused: .studio is private to the app" }
        if let why = modeledFile(rel) { return why }
        let exists = FileManager.default.fileExists(atPath: f.path)
        let reviewed = Tools.reviewedExtensions.contains((rel as NSString).pathExtension.lowercased())
        if exists && reviewed { return await proposeEdit(rel, content, "") }
        return commit(rel, content)
    }

    private func commit(_ rel: String, _ content: String) -> String {
        do {
            try store.write(rel, content, source: .copilot)
            return "wrote \(rel) (\(content.count) chars)"
        } catch { return "error: \(error.localizedDescription)" }
    }

    /// The edit goes to the user as a diff. It is written only if the user accepts and the file is still the one it was based on.
    private func proposeEdit(_ p: String, _ content: String, _ note: String) async -> String {
        let f = abs(p)
        guard f.isInside(project), let rel = store.relativePath(of: f), !rel.isEmpty else { return "refused: edits stay inside the project folder" }
        guard !store.isPrivate(rel) else { return "refused: .studio is private to the app" }
        if let why = modeledFile(rel) { return why }
        let original = store.read(rel)
        if original == content { return "no change: \(rel) already has this content" }
        if store.settings.applyDirectly { return commit(rel, content).replacingOccurrences(of: "wrote", with: "applied directly (the user chose this for the project):") }
        let accepted = await ui.propose(Proposal(file: rel, original: original, proposed: content, note: note))
        guard accepted else { return "refused by the user: \(rel) was not changed. Ask what they want instead." }
        guard store.read(rel) == original else {
            return "not applied: \(rel) changed since the proposal was made. Read it again and propose a new edit."
        }
        return commit(rel, content).replacingOccurrences(of: "wrote", with: "accepted and applied:")
    }

    /// The fields of a content-item tool call.
    static func contentEdit(_ i: [String: Any]) -> ContentEdit {
        ContentEdit(type: i["type"] as? String, text: i["text"] as? String, resource: i["resource"] as? String, color: i["color"] as? String,
                    animation: i["animation"] as? String, params: i["params"] as? String, instruction: i["instruction"] as? String)
    }

    /// The fields of a scene tool call. Numbers are accepted for the times.
    static func sceneEdit(_ i: [String: Any]) -> SceneEdit {
        func str(_ k: String) -> String? {
            if let s = i[k] as? String { return s }
            if let n = i[k] as? Double { return ProjectDocs.seconds(n) }
            if let n = i[k] as? Int { return String(n) }
            return nil
        }
        return SceneEdit(duration: str("duration"), text: str("text"), visual: str("visual"), feeling: str("feeling"), handoff: str("handoff"),
                         inCuts: str("in_cuts"), note: str("note"), status: str("status"), archived: i["archived"] as? Bool, assets: str("assets"), after: str("after"), controlLevel: str("control_level"), name: str("name"))
    }

    /// showreel.json and the manifest hold the project's data: they change through typed operations, which the user can read.
    private func modeledFile(_ rel: String) -> String? {
        if rel == ShowreelFile.fileName {
            return "refused: showreel.json changes through update_parameter (and the app's blocks), not through file writes"
        }
        if rel == Assets.manifestPath { return "refused: the asset manifest changes through update_asset, not through file writes" }
        return nil
    }

    /// A typed change: shown as a card, applied only if the user accepts (or chose apply-directly) and the project did not change meanwhile.
    private func operate(_ op: ProjectOperation) async -> String {
        let card: OperationCard
        do { card = try store.plan(op) } catch {
            store.noteRefused(op, card: nil, author: "clap", note: "not allowed: \(error.localizedDescription)")
            return "refused: \(error.localizedDescription)"
        }
        let summary = card.title + ": " + card.changes.map { "\($0.label) \($0.before) -> \($0.after)" }.joined(separator: "; ")
        if store.settings.applyDirectly {
            do { try store.apply(op, author: "clap", reason: reason); return "applied directly (the user chose this for the project): \(summary)" } catch { return "error: \(error.localizedDescription)" }
        }
        guard await ui.proposeOperation(card) else {
            store.noteRefused(op, card: card, author: "clap", note: "refused by the user" + (reason.map { " (Clap's reason: \($0))" } ?? ""))      // so that it is not proposed again
            return "refused by the user: \(card.title) was not applied. Ask what they want instead."
        }
        do { try store.apply(op, expecting: card, author: "clap", reason: reason); return "accepted and applied: \(summary)" } catch { return error.localizedDescription }
    }

    // MARK: the project's memory

    private func remember(_ input: [String: Any]) async -> String {
        let links = (input["links"] as? [String]) ?? []
        do {
            let e = try store.remember(kind: input["kind"] as? String ?? "", text: input["text"] as? String ?? "", reason: input["reason"] as? String ?? "", source: "clap", links: links)
            await ui.memoryNote("Clap remembered (\(e.kind)): \(e.text)")
            return "remembered as \(e.id) (\(e.kind)): \(e.text). The user can read, edit and delete it in What Clap knows."
        } catch { return "not remembered: \(error.localizedDescription)" }
    }

    private func updateMemory(_ input: [String: Any]) async -> String {
        do {
            let e = try store.updateMemory(id: input["id"] as? String ?? "", text: input["text"] as? String, reason: input["reason"] as? String, kind: input["kind"] as? String,
                                           status: input["status"] as? String, links: input["links"] as? [String], source: "clap")
            await ui.memoryNote("Clap updated a note (\(e.kind)): \(e.text)")
            return "updated \(e.id): \(e.text)"
        } catch { return "not updated: \(error.localizedDescription)" }
    }

    private func forgetMemory(_ id: String) async -> String {
        do {
            let e = try store.forget(id: id)
            await ui.memoryNote("Clap forgot a note: \(e.text)")
            return "forgotten: \(e.id) is marked deleted"
        } catch { return "not forgotten: \(error.localizedDescription)" }
    }

    private func getState() async -> String {
        var state: [String: Any] = ["project": project.path, "applyDirectly": store.settings.applyDirectly]
        if let t = store.read(ShowreelFile.fileName), let o = try? JSONSerialization.jsonObject(with: Data(t.utf8)) {
            state["showreel"] = o
        } else {
            state["showreel"] = NSNull()
            state["note"] = "no readable showreel.json yet: the project has only what is in its files"
        }
        if let fg = await ui.foregroundFile() { state["foregroundFile"] = fg }
        if let b = await ui.foregroundBlock() { state["foregroundBlock"] = b }
        state["versions"] = Versions.list(store)
        if let f = store.loadShowreel() {
            state["film"] = f.timeline().map { t -> [String: Any] in
                var d: [String: Any] = ["scene": t.scene.id, "status": t.scene.status]
                if let n = t.scene.name { d["name"] = n }
                if let a = t.start { d["start"] = a }
                if let b = t.end { d["end"] = b }
                return d
            }
        }
        if let a = MusicAnalysis.load(root: store.root) {
            var m: [String: Any] = ["bpm": a.bpm, "firstBeat": a.firstBeat, "duration": a.duration, "bars": a.bars.count, "tempo": "constant (the analysis assumes it)",
                                    "snap": (store.loadShowreel()?.snapLevel() ?? .beat).rawValue]
            if let d = a.strongestDrop { m["strongestDrop"] = d }
            m["breaks"] = a.breaks.map { ["start": $0.start, "end": $0.end] }
            state["music"] = m
        }
        state["go"] = (store.loadShowreel()?.gates["review"] == "passed") ? "given by the user" : "not given: only the user can give it, with the Go button"
        let assets = Assets.load(store)
        state["assets"] = assets.map { ["id": $0.id, "name": $0.name, "type": $0.type, "status": $0.status, "scenes": $0.scene, "note": $0.notes, "licenceNote": $0.licenceNote] }
        if let spec = ProcessSpec.load() {
            let f = store.loadShowreel()
            state["blocks"] = spec.blocks.map { ["id": $0.id, "name": $0.name, "status": Blocks.status($0.id, spec: spec, showreel: f, assets: assets).rawValue] }
        }
        let top = (try? FileManager.default.contentsOfDirectory(atPath: project.path)) ?? []
        state["files"] = top.filter { !$0.hasPrefix(".") }.sorted()
        let o = (try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data("{}".utf8)
        return String(decoding: o, as: UTF8.self)
    }

    private func listDir(_ p: String) -> String {
        let f = abs(p)
        guard readable(f) else { return "refused: outside the project and skill folders" }
        guard let items = try? FileManager.default.contentsOfDirectory(at: f, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return "not found: \(p)"
        }
        return items.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { u in
            let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return u.lastPathComponent + (isDir == true ? "/" : "")
        }.joined(separator: "\n")
    }

    private func bash(_ cmd: String, _ timeoutMs: Int) async -> String {
        let seconds = Double(min(timeoutMs, 600000)) / 1000
        guard let r = await Shell.run(cmd, in: project, timeout: seconds) else { return "spawn error" }
        let extra = r.timedOut ? "\n[timeout after \(Int(seconds)) s]" : ""
        return clip("exit \(r.status)\n--- stdout\n\(r.out)\n--- stderr\n\(r.err)\(extra)")
    }
}

/// Runs a command in a login zsh that also sources ~/.zshrc, so PATH and the corporate trust settings match the user's terminal,
/// with the app's own Python venv and node modules first when they exist. Used by the bash tool and by the build runner.
public enum Shell {
    public struct Result: Sendable { public let status: Int32; public let out: String; public let err: String; public let timedOut: Bool }

    public static func run(_ cmd: String, in dir: URL, timeout seconds: Double) async -> Result? {
        await withCheckedContinuation { (cont: CheckedContinuation<Result?, Never>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-l", "-c", "[ -f \"$HOME/.zshrc\" ] && source \"$HOME/.zshrc\" >/dev/null 2>&1; " + Tools.envSetup + cmd]
            p.currentDirectoryURL = dir
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
            p.environment = env
            let outPipe = Pipe(), errPipe = Pipe()
            p.standardOutput = outPipe; p.standardError = errPipe
            let buf = OutputBuffer()
            outPipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { h.readabilityHandler = nil } else { buf.add(d, isErr: false) }
            }
            errPipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { h.readabilityHandler = nil } else { buf.add(d, isErr: true) }
            }
            p.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                buf.add(outPipe.fileHandleForReading.readDataToEndOfFile(), isErr: false)
                buf.add(errPipe.fileHandleForReading.readDataToEndOfFile(), isErr: true)
                let (o, e) = buf.text()
                cont.resume(returning: Result(status: proc.terminationStatus, out: o, err: e, timedOut: buf.timedOut))
            }
            do { try p.run() } catch { cont.resume(returning: nil); return }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                if p.isRunning { buf.timedOut = true; p.terminate() }
            }
        }
    }
}
