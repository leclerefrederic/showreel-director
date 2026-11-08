import Foundation

/// A pipe table inside a markdown document (the storyboard, the asset notes).
public struct MarkdownTable: Equatable {
    public var header: [String]
    public var rows: [[String]]

    public init(header: [String], rows: [[String]]) { self.header = header; self.rows = rows }

    /// One block of a document: prose lines kept as they are, or a table.
    public enum Block: Equatable {
        case text([String])
        case table(MarkdownTable)
    }

    static func cells(_ line: String) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") && !s.hasSuffix("\\|") { s.removeLast() }
        var out: [String] = [], cur = ""
        var escaped = false
        for ch in s {
            if escaped { cur.append(ch == "|" ? "|" : "\\" + String(ch)); escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "|" { out.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""; continue }
            cur.append(ch)
        }
        if escaped { cur.append("\\") }
        out.append(cur.trimmingCharacters(in: .whitespaces))
        return out
    }

    static func isSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.contains("-"), t.contains("|") else { return false }
        return t.allSatisfy { "|-: ".contains($0) }
    }

    static func isRow(_ line: String) -> Bool { line.trimmingCharacters(in: .whitespaces).hasPrefix("|") }

    /// Splits a document into prose and tables. A table is a header row, a separator row and the rows after it.
    public static func parse(_ text: String) -> [Block] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = [], prose: [String] = []
        var i = 0
        while i < lines.count {
            if isRow(lines[i]), i + 1 < lines.count, isSeparator(lines[i + 1]) {
                if !prose.isEmpty { blocks.append(.text(prose)); prose = [] }
                let header = cells(lines[i])
                var rows: [[String]] = []
                i += 2
                while i < lines.count, isRow(lines[i]) {
                    var r = cells(lines[i])
                    while r.count < header.count { r.append("") } // ragged rows are padded, extra cells are kept
                    rows.append(r)
                    i += 1
                }
                blocks.append(.table(MarkdownTable(header: header, rows: rows)))
            } else {
                prose.append(lines[i]); i += 1
            }
        }
        if !prose.isEmpty { blocks.append(.text(prose)) }
        return blocks
    }

    static func escape(_ cell: String) -> String {
        cell.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }

    /// The table with padded columns, one row per line.
    public func render() -> String {
        let all = [header] + rows
        let n = all.map { $0.count }.max() ?? 0
        var widths = [Int](repeating: 3, count: n)
        for r in all { for (i, c) in r.enumerated() { widths[i] = max(widths[i], Self.escape(c).count) } }
        func line(_ r: [String]) -> String {
            "| " + (0..<n).map { i in
                let c = i < r.count ? Self.escape(r[i]) : ""
                return c + String(repeating: " ", count: widths[i] - c.count)
            }.joined(separator: " | ") + " |"
        }
        let sep = "| " + widths.map { String(repeating: "-", count: $0) }.joined(separator: " | ") + " |"
        return ([line(header), sep] + rows.map(line)).joined(separator: "\n")
    }

    public static func write(_ blocks: [Block]) -> String {
        blocks.map { b -> String in
            switch b {
            case .text(let l): return l.joined(separator: "\n")
            case .table(let t): return t.render()
            }
        }.joined(separator: "\n")
    }

    // MARK: storyboard helpers

    /// Index of the column that holds the scene IDs: a header that says "scene" or "id", else the column whose cells look like S01.
    public var sceneColumn: Int? {
        if let i = header.firstIndex(where: { let h = $0.lowercased(); return h == "id" || h.contains("scene") }) { return i }
        for c in header.indices where !rows.isEmpty && rows.allSatisfy({ c < $0.count && Self.isSceneID($0[c]) }) { return c }
        return nil
    }

    static func isSceneID(_ s: String) -> Bool {
        s.range(of: #"^S\d{2,}[a-z]?$"#, options: .regularExpression) != nil
    }

    /// Scene IDs in table order, ditched scenes included (an ID is never reused).
    public var sceneIDs: [String] {
        guard let c = sceneColumn else { return [] }
        return rows.compactMap { c < $0.count && Self.isSceneID($0[c]) ? $0[c] : nil }
    }

    /// The next free ID: one past the highest number ever used, never a renumbering.
    public var nextSceneID: String {
        let n = sceneIDs.compactMap { Int($0.dropFirst().prefix { $0.isNumber }) }.max() ?? 0
        return String(format: "S%02d", n + 1)
    }
}
