import XCTest
@testable import ShowreelKit

/// PL1: each contrast check of the Palette card sits under the swatch it judges.
final class PL1Tests: XCTestCase {
    private func board(_ pal: [String]) -> DesignBoard {
        var f = ShowreelFile(name: "P"); f.decisions.palette = pal
        return DesignBoard.make(f)
    }
    private func titles(_ b: DesignBoard) -> [String?] { b.columns.map { $0.check?.title } }

    func testTheStandardPaletteHasItsChecksUnderText_Accent_Accent2AndNoneUnderBackground() {
        let b = board(["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2"])
        XCTAssertEqual(b.columns.map { $0.swatch.role }, ["Background", "Text", "Accent", "Accent 2"])
        XCTAssertEqual(titles(b), [nil, "Text on background", "Accent on background", "Accent 2 on background"])
        XCTAssertTrue(b.spanning.isEmpty)
    }

    func testAThreeColourPaletteHasTwoChecksAndAFiveColourOneNoCheckOnTheExtra() {
        XCTAssertEqual(titles(board(["#101820", "#FFFFFF", "#F2AA4C"])), [nil, "Text on background", "Accent on background"])
        XCTAssertEqual(titles(board(["#101820", "#FFFFFF"])), [nil, "Text on background"])
        let five = board(["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2", "#FF00AA"])
        XCTAssertEqual(titles(five), [nil, "Text on background", "Accent on background", "Accent 2 on background", nil])
        XCTAssertEqual(five.columns.last?.swatch.role, "Extra")
    }

    func testACheckSpanningTwoColoursLandsInTheExtraRow() {
        let s = (0..<2).map { DesignBoard.Swatch(role: "R\($0)", hex: "#000000", on: "#FFFFFF") }
        let span = DesignBoard.ContrastLine(title: "A on B", ratio: 2, level: .fail, detail: "x", swatch: nil)
        let own = DesignBoard.ContrastLine(title: "T", ratio: 5, level: .ok, detail: "y", swatch: 1)
        let b = DesignBoard(swatches: s, contrasts: [own, span], titleFont: nil, textFont: nil, background: nil, backgroundMood: nil, moods: [], pack: nil, sampleEffect: "Fade", sampleText: "")
        XCTAssertEqual(b.spanning, [span]); XCTAssertEqual(b.columns[1].check, own); XCTAssertNil(b.columns[0].check)
    }

    func testEveryCheckBelongsToTheSwatchItsRatioIsAbout() {
        let pal = ["#101820", "#FFFFFF", "#F2AA4C", "#4CC2F2"]
        let b = board(pal)
        for (i, col) in b.columns.enumerated() { if let c = col.check { XCTAssertEqual(c.ratio, Contrast.ratio(pal[i], pal[0]), accuracy: 0.001, col.swatch.role) } }
    }

    func testAFailingContrastKeepsItsLevelAndTextInItsOwnColumn() {
        let b = board(["#101820", "#202830", "#F2AA4C", "#4CC2F2"])
        let c = b.columns[1].check
        XCTAssertEqual(c?.level, .fail); XCTAssertTrue(c?.detail.contains("too low to read") == true); XCTAssertNil(b.columns[0].check)
        XCTAssertEqual(b.columns[2].check?.level, .ok, "the other columns keep their own result")
    }

    func testNothingIsPlacedForAnInvalidOrEmptyPalette() {
        XCTAssertTrue(board([]).columns.isEmpty && board(["#101820", "nope"]).contrasts.isEmpty)
    }

    func testTheViewDrawsTheColumnsAndOnlyTheLayoutChanged() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/ShowreelStudio")
        let v = try String(contentsOf: dir.appendingPathComponent("DesignBoardView.swift"), encoding: .utf8)
        XCTAssertTrue(v.contains("b.columns") && v.contains("b.spanning") && v.contains(".help(c.title"), "columns, the extra row and a tooltip for a wrapped text")
        XCTAssertFalse(v.contains("ForEach(Array(b.contrasts.enumerated())"), "the checks are no longer one row of their own")
    }
}
