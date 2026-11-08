import Foundation
import ShowreelKit

struct EnvItem: Identifiable {
    let id: String
    let label: String
    let detail: String
    var ok: Bool?
}

/// Runs tools/setup-env.sh (bundled in the app) in a login shell and streams its output.
enum ShellRunner {
    static func scriptURL() -> URL? { resource("setup-env.sh", dev: "tools/setup-env.sh") }

    static func run(args: [String], onChunk: ((String) -> Void)? = nil) async -> String {
        guard let script = scriptURL() else { return "" }
        return await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-l", "-c",
                           "[ -f \"$HOME/.zshrc\" ] && source \"$HOME/.zshrc\" >/dev/null 2>&1; bash \"\(script.path)\" "
                               + args.joined(separator: " ")]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            let buf = OutputBuffer()
            pipe.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { h.readabilityHandler = nil; return }
                buf.add(d, isErr: false)
                if let cb = onChunk { cb(String(decoding: d, as: UTF8.self)) }
            }
            p.terminationHandler = { _ in
                pipe.fileHandleForReading.readabilityHandler = nil
                buf.add(pipe.fileHandleForReading.readDataToEndOfFile(), isErr: false)
                cont.resume(returning: buf.text().0)
            }
            do { try p.run() } catch { cont.resume(returning: "") }
        }
    }
}

/// What the app needs to run the skill's full mode, checked at launch.
final class EnvModel: ObservableObject {
    @Published var items: [EnvItem] = [
        EnvItem(id: "python3", label: "Python 3", detail: "Audio analysis and asset tools (comes with the Command Line Tools)", ok: nil),
        EnvItem(id: "pypackages", label: "Python packages", detail: "numpy and fonttools, in the app's own environment", ok: nil),
        EnvItem(id: "node", label: "Node.js", detail: "Player test and MP4 export", ok: nil),
        EnvItem(id: "npm", label: "npm", detail: "Installs the Node modules", ok: nil),
        EnvItem(id: "jsdom", label: "jsdom", detail: "Tests the player without a browser", ok: nil),
        EnvItem(id: "canvas", label: "canvas", detail: "Real text measurement and MP4 frames", ok: nil),
        EnvItem(id: "ffmpeg", label: "ffmpeg", detail: "Reads the music track and encodes MP4", ok: nil),
    ]
    @Published var checking = true
    @Published var installing = false
    @Published var skipped = false
    @Published var brewAvailable = false
    @Published var scriptFound = true
    @Published var log = ""

    var passed: Bool { !checking && items.allSatisfy { $0.ok == true } }
    var ready: Bool { passed || skipped }
    func isMissing(_ id: String) -> Bool { items.first { $0.id == id }?.ok == false }

    init() { check() }

    func check() {
        checking = true
        Task { [weak self] in
            let out = await ShellRunner.run(args: ["--check"])
            DispatchQueue.main.async { self?.apply(Self.parse(out), found: ShellRunner.scriptURL() != nil) }
        }
    }

    func install() {
        installing = true
        log = ""
        Task { [weak self] in
            _ = await ShellRunner.run(args: ["--install"]) { chunk in
                DispatchQueue.main.async { self?.log += chunk }
            }
            DispatchQueue.main.async {
                self?.installing = false
                self?.check()
            }
        }
    }

    private static func parse(_ out: String) -> [String: Bool] {
        var m: [String: Bool] = [:]
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[1] == "ok" || parts[1] == "missing" { m[parts[0]] = (parts[1] == "ok") }
        }
        return m
    }

    private func apply(_ map: [String: Bool], found: Bool) {
        scriptFound = found
        for i in items.indices { items[i].ok = map[items[i].id] ?? false }
        brewAvailable = map["brew"] == true
        checking = false
    }
}
