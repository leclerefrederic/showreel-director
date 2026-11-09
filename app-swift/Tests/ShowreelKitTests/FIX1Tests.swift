import XCTest
@testable import ShowreelKit

/// FIX1: the "Design package" footer sits under the project settings form (a layout fix, checked by reading the sources).
final class FIX1Tests: XCTestCase {
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }

    func testNoScrollViewHoldsSeveralViewsWithoutAStack() throws {
        for f in try FileManager.default.contentsOfDirectory(atPath: views.path).filter({ $0.hasSuffix(".swift") }).sorted() {
            let text = try String(contentsOf: views.appendingPathComponent(f), encoding: .utf8)
            XCTAssertEqual(scrollViewsWithSiblingViews(in: text), [], "\(f): a ScrollView with several views and no stack overlays them")
        }
    }

    func testTheScanSeesTheBug() {
        let bad = "ScrollView {\n    VStack {\n        Text(\"a\")\n    }\n    Footer()\n}\n"
        XCTAssertEqual(scrollViewsWithSiblingViews(in: bad), [1])
        XCTAssertEqual(scrollViewsWithSiblingViews(in: "ScrollView {\n    VStack {\n        Text(\"a\")\n        Footer()\n    }\n}\n"), [])
    }

    func testTheFooterIsInTheSameStackAsTheForm() throws {
        let t = try String(contentsOf: views.appendingPathComponent("ProjectSettingsPanel.swift"), encoding: .utf8)
        let a = try XCTUnwrap(t.range(of: "ScrollView {")), f = try XCTUnwrap(t.range(of: "PackageSettingsFooter()"))
        XCTAssertLessThan(a.lowerBound, f.lowerBound)
        let between = t[a.upperBound..<f.lowerBound]
        XCTAssertTrue(between.contains("VStack(alignment: .leading, spacing: 0) {"), "the form and the footer share one stack")
    }
}
