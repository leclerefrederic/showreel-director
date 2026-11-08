import Foundation

/// Thread-safe output buffer for a child process.
final class OutputBuffer {
    private let lock = NSLock()
    private var out = Data(), err = Data()
    var timedOut = false
    func add(_ d: Data, isErr: Bool) { lock.lock(); if isErr { err.append(d) } else { out.append(d) }; lock.unlock() }
    func text() -> (String, String) {
        lock.lock(); defer { lock.unlock() }
        return (String(decoding: out, as: UTF8.self), String(decoding: err, as: UTF8.self))
    }
}

final class Tools {
    let project: URL
    let skill: URL
    let ui: UIBridge

    init(project: URL, skill: URL, ui: UIBridge) {
        self.project = project; self.skill = skill; self.ui = ui
    }

    /// Tool definitions shared with the Electron app (app/shared/tools.json).
    static let definitions: [[String: Any]] = {
        guard let u = resource("shared", dev: "app/shared")?.appendingPathComponent("tools.json"),
              let d = try? Data(contentsOf: u),
              let a = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return a
    }()

    private func abs(_ p: String) -> URL {
        if p.hasPrefix("/") { return URL(fileURLWithPath: p).standardizedFileURL }
        let a = project.appendingPathComponent(p).standardizedFileURL
        let b = skill.appendingPathComponent(p).standardizedFileURL
        let fm = FileManager.default
        // relative reads fall back to the skill folder
        return (!fm.fileExists(atPath: a.path) && fm.fileExists(atPath: b.path)) ? b : a
    }
    private func readable(_ u: URL) -> Bool { u.isInside(project) || u.isInside(skill) }

    func run(_ name: String, _ input: [String: Any]) async -> String {
        switch name {
        case "bash":
            return await bash(input["command"] as? String ?? "", input["timeout_ms"] as? Int ?? 120000)
        case "read_file":
            return readFile(input["path"] as? String ?? "", input["offset"] as? Int ?? 0, input["limit"] as? Int ?? 2000)
        case "write_file":
            return writeFile(input["path"] as? String ?? "", input["content"] as? String ?? "")
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

    private func writeFile(_ p: String, _ content: String) -> String {
        let f = abs(p)
        guard f.isInside(project) else { return "refused: writes stay inside the project folder" }
        do {
            try FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: f, atomically: true, encoding: .utf8)
            return "wrote \(p) (\(content.count) chars)"
        } catch { return "error: \(error.localizedDescription)" }
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
            p.arguments = ["-l", "-c", "[ -f \"$HOME/.zshrc\" ] && source \"$HOME/.zshrc\" >/dev/null 2>&1; " + cmd]
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
