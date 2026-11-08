import Foundation

enum Skill {
    static func root() -> URL? {
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

    /// SKILL.md without its frontmatter, plus the shared addendum (app/shared/addendum.md).
    static func systemPrompt(project: URL, lang: String?) throws -> (root: URL, text: String) {
        guard let root = root() else { throw AgentError.msg("Skill folder not found") }
        var skill = try String(contentsOf: root.appendingPathComponent("SKILL.md"), encoding: .utf8)
        if skill.hasPrefix("---") {
            let from = skill.index(skill.startIndex, offsetBy: 3)
            if let r = skill.range(of: "\n---\n", range: from..<skill.endIndex) {
                skill = String(skill[r.upperBound...])
            }
        }
        guard let addURL = resource("shared", dev: "app/shared")?.appendingPathComponent("addendum.md"),
              let template = try? String(contentsOf: addURL, encoding: .utf8) else {
            throw AgentError.msg("shared/addendum.md not found")
        }
        let addendum = template
            .replacingOccurrences(of: "{{root}}", with: root.path)
            .replacingOccurrences(of: "{{project}}", with: project.path)
            .replacingOccurrences(of: "{{lang}}", with: lang ?? "the language of the user's first message")
        return (root, skill + "\n" + addendum)
    }
}
