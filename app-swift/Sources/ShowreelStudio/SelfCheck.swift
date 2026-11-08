import Foundation
import ShowreelKit

/// A UI with no window: answers proposals with a fixed choice and records what it was shown.
private final class NullUI: AgentUI {
    var accept = false
    var proposals: [Proposal] = []
    func propose(_ p: Proposal) async -> Bool { proposals.append(p); return accept }
    func foregroundFile() async -> String? { "storyboard.md" }
    func text(_ t: String) {}
    func endText() {}
    func tool(_ name: String, _ input: [String: Any]) {}
    func show(_ url: String, _ title: String) {}
    func screenshot(javascript: String?, waitMs: Int) async -> Data? { nil }
    func ask(_ questions: [[String: Any]]) async -> [String] { [] }
}

private final class Box<T> {
    var value: T
    init(_ v: T) { value = v }
}

/// `ShowreelStudio --selftest`: checks, without any window or network, that the app finds everything it needs
/// (inside its own bundle when packaged), builds its prompt and runs its tools safely. Exit code 0 when all pass.
enum SelfCheck {
    static func run() -> Int32 {
        var failures = 0
        func check(_ ok: Bool, _ label: String) { print((ok ? "PASS " : "FAIL ") + label); if !ok { failures += 1 } }
        let fm = FileManager.default
        let bundled = Bundle.main.bundlePath.hasSuffix(".app")
        let bundlePath = Bundle.main.bundlePath
        func inside(_ u: URL?) -> Bool { guard let u = u else { return false }; return !bundled || u.path.hasPrefix(bundlePath + "/") }

        let root = Skill.root()
        check(root != nil && inside(root), "skill folder found" + (bundled ? " inside the app" : ""))
        let shared = resource("shared", dev: "app-swift/shared")
        for f in ["tools.json", "addendum.md", "capabilities.json"] {
            let u = shared?.appendingPathComponent(f)
            check(u != nil && fm.fileExists(atPath: u!.path) && inside(u), "shared/\(f)")
        }
        check(!Tools.definitions.isEmpty, "tool definitions load (\(Tools.definitions.count))")
        let script = ShellRunner.scriptURL()
        check(script != nil && inside(script), "setup script found")
        if bundled {
            check(Skill.fingerprint().count == 12, "skill fingerprint present (\(Skill.fingerprint()))")
            check(fm.fileExists(atPath: bundlePath + "/Contents/Resources/AppIcon.icns"), "app icon in the bundle")
        }

        let tmp = fm.temporaryDirectory.appendingPathComponent("showreel-selftest-\(UUID().uuidString)")
        try? fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        if let sp = try? Skill.systemPrompt(project: tmp, lang: nil) {
            check(sp.text.contains("Showreel director") && sp.text.contains("Running inside Showreel Studio") && !sp.text.contains("{{"),
                  "system prompt builds, no placeholder left")
        } else {
            check(false, "system prompt builds")
        }

        if let r = root {
            let ui = NullUI()
            let tools = Tools(project: tmp, skill: r, ui: ui)
            func call(_ name: String, _ input: [String: Any]) -> String {
                let sem = DispatchSemaphore(value: 0)
                let out = Box("")
                Task { out.value = await tools.run(name, input).text; sem.signal() }
                sem.wait()
                return out.value
            }
            check(call("write_file", ["path": "a/b.txt", "content": "hello"]).hasPrefix("wrote") && fm.fileExists(atPath: tmp.appendingPathComponent("a/b.txt").path), "write_file writes inside the project")
            check(call("write_file", ["path": "../escape.txt", "content": "no"]).hasPrefix("refused"), "write_file refuses to leave the project")
            check(call("read_file", ["path": "/etc/hosts"]).hasPrefix("refused"), "read_file refuses outside project and skill")
            check(call("read_file", ["path": "SKILL.md", "limit": 3]).contains("\t"), "read_file falls back to the skill folder")
            check(call("bash", ["command": "echo selftest-ok"]).contains("selftest-ok"), "bash runs in a login shell")
            check(call("bash", ["command": "pwd"]).contains(tmp.lastPathComponent), "bash starts in the project folder")
            check(call("no_such_tool", [:]).hasPrefix("unknown tool"), "unknown tool is reported")

            // project model: showreel.json, the copilot's edits as proposals, history
            let store = ProjectStore(root: tmp)
            check((try? store.create(name: "Selftest", conversationLanguage: "en", reelLanguages: ["en"])) != nil
                  && store.loadShowreel()?.name == "Selftest", "showreel.json is created and read back")
            check(call("get_state", [:]).contains("\"name\" : \"Selftest\"") && call("get_state", [:]).contains("storyboard.md"),
                  "get_state returns the showreel and the file in front of the user")
            _ = call("write_file", ["path": "notes.md", "content": "one\n"])
            ui.accept = false
            check(call("propose_edit", ["file": "notes.md", "content": "two\n"]).hasPrefix("refused by the user")
                  && store.read("notes.md") == "one\n", "a refused proposal leaves the file alone")
            ui.accept = true
            check(call("propose_edit", ["file": "notes.md", "content": "two\n"]).hasPrefix("accepted")
                  && store.read("notes.md") == "two\n", "an accepted proposal is written")
            check(call("write_file", ["path": "notes.md", "content": "three\n"]).hasPrefix("accepted")
                  && ui.proposals.count == 3, "write_file on an existing markdown file becomes a proposal")
            check(store.snapshots("notes.md").count == 2, "each write keeps the previous version in the history")
            check(call("write_file", ["path": ".studio/x.txt", "content": "no"]).hasPrefix("refused"), ".studio stays private to the app")
        }
        print(failures == 0 ? "SELFTEST OK" : "SELFTEST FAILED (\(failures))")
        return failures == 0 ? 0 : 1
    }
}
