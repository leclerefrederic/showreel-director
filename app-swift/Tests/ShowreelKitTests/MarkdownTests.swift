import XCTest
@testable import ShowreelKit

final class MarkdownTests: XCTestCase {
    // Golden file: a storyboard as the skill writes it, with prose around the table and an escaped pipe.
    static let golden = """
    # Storyboard v2

    Intro line kept as it is.

    | Time | Scene | On-screen text | Feeling |
    |---|---|---|---|
    | 0-4 s | S01 | Hello \\| world | calm |
    | 4-9 s | S02 | Second | rising |
    | 9-12 s | S02b | Ditched: cut | none |

    Closing note.
    """

    func testParseFindsProseAndTable() {
        let blocks = MarkdownTable.parse(Self.golden)
        XCTAssertEqual(blocks.count, 3)
        guard case .table(let t) = blocks[1] else { return XCTFail("no table") }
        XCTAssertEqual(t.header, ["Time", "Scene", "On-screen text", "Feeling"])
        XCTAssertEqual(t.rows.count, 3)
        XCTAssertEqual(t.rows[0][2], "Hello | world", "escaped pipe is one cell")
        XCTAssertEqual(t.sceneIDs, ["S01", "S02", "S02b"])
        XCTAssertEqual(t.nextSceneID, "S03", "next ID follows the highest number, ditched scenes included")
    }

    func testWriteIsNormalisedAndStable() {
        let once = MarkdownTable.write(MarkdownTable.parse(Self.golden))
        let twice = MarkdownTable.write(MarkdownTable.parse(once))
        XCTAssertEqual(once, twice, "write(parse(x)) is a fixed point")
        let expected = """
        # Storyboard v2

        Intro line kept as it is.

        | Time   | Scene | On-screen text | Feeling |
        | ------ | ----- | -------------- | ------- |
        | 0-4 s  | S01   | Hello \\| world | calm    |
        | 4-9 s  | S02   | Second         | rising  |
        | 9-12 s | S02b  | Ditched: cut   | none    |

        Closing note.
        """
        XCTAssertEqual(once, expected)
    }

    func testEditingACellKeepsEverythingElse() {
        var blocks = MarkdownTable.parse(Self.golden)
        guard case .table(var t) = blocks[1] else { return XCTFail() }
        t.rows[1][2] = "Second, shorter"
        blocks[1] = .table(t)
        let out = MarkdownTable.write(blocks)
        XCTAssertTrue(out.contains("Second, shorter"))
        XCTAssertTrue(out.contains("Intro line kept as it is.") && out.contains("Closing note."))
        XCTAssertEqual(MarkdownTable.parse(out).count, 3)
    }

    func testRaggedRowsArePadded() {
        let blocks = MarkdownTable.parse("| A | B | C |\n|---|---|---|\n| 1 | 2 |\n")
        guard case .table(let t) = blocks[0] else { return XCTFail() }
        XCTAssertEqual(t.rows, [["1", "2", ""]])
    }

    func testTextWithoutTableIsUntouched() {
        let s = "just text\n\nwith | a pipe but no table\n"
        XCTAssertEqual(MarkdownTable.write(MarkdownTable.parse(s)), s)
    }

    func testCSVRoundTrip() {
        let rows = [["file", "status", "note"], ["a.png", "ok", "has, comma"], ["b.png", "held", "says \"hi\"\nsecond line"], ["c.png", "", ""]]
        let text = CSV.write(rows)
        XCTAssertEqual(CSV.parse(text), rows)
        XCTAssertEqual(CSV.parse("a,b\r\n1,2\r\n"), [["a", "b"], ["1", "2"]], "CRLF is read")
        XCTAssertEqual(CSV.write(CSV.parse(text)), text)
    }

    func testLineDiff() {
        let d = LineDiff.diff("a\nb\nc", "a\nB\nc\nd")
        XCTAssertEqual(d, [DiffLine(.same, "a"), DiffLine(.removed, "b"), DiffLine(.added, "B"), DiffLine(.same, "c"), DiffLine(.added, "d")])
        XCTAssertEqual(LineDiff.diff("", "x"), [DiffLine(.added, "x")])
        XCTAssertTrue(LineDiff.diff("same", "same").allSatisfy { $0.kind == .same })
        let long = (1...30).map(String.init).joined(separator: "\n")
        let changed = long.replacingOccurrences(of: "\n15\n", with: "\nfifteen\n")
        let rows = LineDiff.collapse(LineDiff.diff(long, changed), context: 2)
        XCTAssertEqual(rows.first, .gap(12))
        XCTAssertEqual(rows.last, .gap(13))
    }
}
