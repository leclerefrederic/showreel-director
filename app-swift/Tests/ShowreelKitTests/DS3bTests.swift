import XCTest
@testable import ShowreelKit

/// DS3b: one text field style, growing multi-line fields, the stepper's keys, buttons by role.
final class DS3bTests: XCTestCase {
    var views: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio") }
    func source(_ n: String) throws -> String { try String(contentsOf: views.appendingPathComponent(n), encoding: .utf8) }

    func testEveryTextFieldKindTakesItsHeightAndRadiusFromTheFormSystem() throws {
        let theme = try source("Theme.swift")
        XCTAssertTrue(theme.contains("minHeight: FormLayout.fieldHeight") && theme.contains("FormLayout.fieldRadius"), "the text field style")
        let form = try source("FormViews.swift")
        XCTAssertTrue(form.contains("FormLayout.fieldHeight") && form.contains("FormLayout.fieldRadius"), "the stepper field")
        XCTAssertEqual(FormLayout.fieldRadius, DesignTokens.graphite.radii.small)
    }

    func testNoTextFieldInTheseAreasSetsItsOwnHeightRadiusOrColour() throws {
        let files = ["InspectorViews", "ContentViews", "ReelViews", "StoryboardViews", "ProjectFormViews", "LookViews", "HistoryViews", "ResourceViews", "PickerViews", "WorkspaceViews", "EditorViews", "DragDropViews"]
        for f in files {
            let t = try source(f + ".swift")
            XCTAssertFalse(t.contains(".textFieldStyle(.roundedBorder)"), "\(f): the native field style")
            for line in t.split(separator: "\n") where line.contains("ThemedTextFieldStyle()") {
                XCTAssertFalse(line.contains(".frame(height:") || line.contains("cornerRadius"), "\(f): a field sets its own height or radius: \(line.prefix(90))")
            }
        }
    }

    func testTheMultiLineFieldsUseTheGrowthRule() throws {
        XCTAssertTrue(try source("Theme.swift").contains("FormLayout.areaLines(for: text"), "the editor reads the rule")
        XCTAssertTrue(try source("Theme.swift").contains(".scrollIndicators(g.scrolls ? .automatic : .hidden)"), "overlay scrollbar only when something scrolls")
        XCTAssertTrue(try source("StoryboardViews.swift").contains("GrowingTextEditor(text: binding(key)"), "the scene's multi-line fields")
        XCTAssertFalse(try source("StoryboardViews.swift").contains("TextEditor(text: binding(key))"))
        XCTAssertEqual(FormLayout.areaLines(for: "a\nb", width: 300).lines, FormLayout.minLines)
        XCTAssertEqual(FormLayout.areaLines(for: String(repeating: "x", count: 5000), width: 300).lines, FormLayout.maxLines)
    }

    func testTheStepperKeyMapping() {
        XCTAssertEqual(NumericField.keyStep(keyCode: 126, option: false, shift: false)?.up, true)
        XCTAssertEqual(NumericField.keyStep(keyCode: 125, option: false, shift: false)?.up, false)
        XCTAssertEqual(NumericField.keyStep(keyCode: 126, option: true, shift: false)?.modifier, .fine)
        XCTAssertEqual(NumericField.keyStep(keyCode: 125, option: false, shift: true)?.modifier, .coarse)
        XCTAssertEqual(NumericField.keyStep(keyCode: 126, option: true, shift: true)?.modifier, .fine, "Option wins")
        XCTAssertNil(NumericField.keyStep(keyCode: 36, option: false, shift: false), "Return is not ours")
        XCTAssertTrue(try source("FormViews.swift").contains("NumericField.keyStep"))
    }

    func testNoButtonStaysOnTheNativeBorderedStyle() throws {
        for f in ["LookViews", "BlockViews", "PickerViews", "InspectorViews"] { XCTAssertFalse(try source(f + ".swift").contains(".buttonStyle(.bordered)"), f) }
    }
}
