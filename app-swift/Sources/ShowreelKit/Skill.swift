import Foundation

public enum Skill {
    public static func root() -> URL? {
        let fm = FileManager.default
        if let e = ProcessInfo.processInfo.environment["SHOWREEL_SKILL_DIR"], fm.fileExists(atPath: e + "/SKILL.md") {
            return URL(fileURLWithPath: e)
        }
        if let r = resource("skill", dev: "showreel-director"),
           fm.fileExists(atPath: r.appendingPathComponent("SKILL.md").path) {
            return r
        }
        return nil
    }

    /// Fingerprint of the skill folder written at build time (tools/skill_hash.py); shown in Settings.
    public static func fingerprint() -> String {
        guard let r = Bundle.main.resourceURL?.appendingPathComponent("skill.hash"),
              let t = try? String(contentsOf: r, encoding: .utf8) else { return "dev build (skill read from the repository)" }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The capabilities of this app against the skill's portability table (app-swift/shared/capabilities.json).
    public static func capabilitiesText() -> String {
        guard let u = resource("shared", dev: "app-swift/shared")?.appendingPathComponent("capabilities.json"),
              let d = try? Data(contentsOf: u),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let caps = o["capabilities"] as? [[String: Any]] else { return "" }
        var yes: [String] = [], no: [String] = []
        for c in caps {
            let need = c["need"] as? String ?? ""
            if c["provided"] as? Bool == true {
                yes.append("  - \(need): \(c["via"] as? String ?? "available")")
            } else {
                no.append("  - \(need): \(c["fallback"] as? String ?? "not available")")
            }
        }
        return yes.joined(separator: "\n")
            + "\n  Not available here (use the skill's fallback for that step and say so once, in plain words):\n"
            + no.joined(separator: "\n")
    }

    /// SKILL.md without its frontmatter, plus the shared addendum (app/shared/addendum.md).
    public static func systemPrompt(project: URL, lang: String?) throws -> (root: URL, text: String) {
        guard let root = root() else { throw AgentError.msg("Skill folder not found") }
        var skill = try String(contentsOf: root.appendingPathComponent("SKILL.md"), encoding: .utf8)
        if skill.hasPrefix("---") {
            let from = skill.index(skill.startIndex, offsetBy: 3)
            if let r = skill.range(of: "\n---\n", range: from..<skill.endIndex) {
                skill = String(skill[r.upperBound...])
            }
        }
        guard let addURL = resource("shared", dev: "app-swift/shared")?.appendingPathComponent("addendum.md"),
              let template = try? String(contentsOf: addURL, encoding: .utf8) else {
            throw AgentError.msg("shared/addendum.md not found")
        }
        let addendum = template
            .replacingOccurrences(of: "{{root}}", with: root.path)
            .replacingOccurrences(of: "{{project}}", with: project.path)
            .replacingOccurrences(of: "{{capabilities}}", with: capabilitiesText())
            .replacingOccurrences(of: "{{lang}}", with: lang ?? "the language of the user's first message")
        return (root, skill + "\n" + addendum)
    }
}
