import Foundation

/// The versions the app shows: its own (one source, `shared/app-version.json`, which make-app.sh also writes into the bundle) and the skill it carries.
public enum AppInfo {
    public static var version: String {
        guard let u = resource("shared", dev: "app-swift/shared")?.appendingPathComponent("app-version.json"), let d = try? Data(contentsOf: u),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let v = o["version"] as? String else { return "unknown" }
        return v
    }

    /// `metadata.version` of the embedded skill's SKILL.md.
    public static var skillVersion: String {
        guard let root = Skill.root(), let t = try? String(contentsOf: root.appendingPathComponent("SKILL.md"), encoding: .utf8),
              let r = t.range(of: #"version: "\d+\.\d+\.\d+""#, options: .regularExpression) else { return "unknown" }
        return String(t[r]).replacingOccurrences(of: "version: \"", with: "").replacingOccurrences(of: "\"", with: "")
    }

    public static var line: String { "Showreel Studio \(version), skill \(skillVersion)" }
}
