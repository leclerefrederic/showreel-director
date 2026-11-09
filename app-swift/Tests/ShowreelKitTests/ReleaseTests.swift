import XCTest
@testable import ShowreelKit

/// The versions the app shows: one source for the app, the embedded skill's own.
final class ReleaseTests: XCTestCase {
    func testTheAppVersionComesFromTheSingleSourceAndTheSkillVersionFromItsFrontmatter() throws {
        let src = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("shared/app-version.json")
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: src)) as? [String: Any])
        XCTAssertEqual(AppInfo.version, o["version"] as? String)
        XCTAssertNotNil(AppInfo.version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression))
        let skill = try String(contentsOf: try XCTUnwrap(Skill.root()).appendingPathComponent("SKILL.md"), encoding: .utf8)
        XCTAssertTrue(skill.contains("version: \"\(AppInfo.skillVersion)\""))
        XCTAssertEqual(AppInfo.line, "Showreel Studio \(AppInfo.version), skill \(AppInfo.skillVersion)")
    }
}
