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

    public func run(_ name: String, _ input: [String: Any]) async -> ToolResult {
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

    private func getState() async -> String {
        var state: [String: Any] = ["project": project.path, "applyDirectly": store.settings.applyDirectly]
        if let t = store.read(ShowreelFile.fileName), let o = try? JSONSerialization.jsonObject(with: Data(t.utf8)) {
            state["showreel"] = o
        } else {
            state["showreel"] = NSNull()
            state["note"] = "no readable showreel.json yet: the project has only what is in its files"
        }
        if let fg = await ui.foregroundFile() { state["foregroundFile"] = fg }
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
        return await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // a login shell plus ~/.zshrc, so PATH and the corporate certificate settings match the user's terminal
            p.arguments = ["-l", "-c", "[ -f \"$HOME/.zshrc\" ] && source \"$HOME/.zshrc\" >/dev/null 2>&1; " + Tools.envSetup + cmd]
            p.currentDirectoryURL = project
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
                let extra = buf.timedOut ? "\n[timeout after \(Int(seconds)) s]" : ""
                cont.resume(returning: clip("exit \(proc.terminationStatus)\n--- stdout\n\(o)\n--- stderr\n\(e)\(extra)"))
            }
            do { try p.run() } catch {
                cont.resume(returning: "spawn error: \(error.localizedDescription)")
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                if p.isRunning { buf.timedOut = true; p.terminate() }
            }
        }
    }
}
