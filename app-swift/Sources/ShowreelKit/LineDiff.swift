import Foundation

public struct DiffLine: Equatable {
    public enum Kind { case same, added, removed }
    public let kind: Kind
    public let text: String
    public init(_ kind: Kind, _ text: String) { self.kind = kind; self.text = text }
}

/// Line diff for the proposal cards and the history: common head and tail are trimmed, the middle uses a longest common subsequence.
public enum LineDiff {
    public static func diff(_ a: String, _ b: String) -> [DiffLine] {
        let x = a.isEmpty ? [] : a.components(separatedBy: "\n")
        let y = b.isEmpty ? [] : b.components(separatedBy: "\n")
        var head = 0
        while head < x.count, head < y.count, x[head] == y[head] { head += 1 }
        var tail = 0
        while tail < x.count - head, tail < y.count - head, x[x.count - 1 - tail] == y[y.count - 1 - tail] { tail += 1 }
        let mx = Array(x[head..<(x.count - tail)]), my = Array(y[head..<(y.count - tail)])
        var out = x[..<head].map { DiffLine(.same, $0) }
        out += middle(mx, my)
        out += x[(x.count - tail)...].map { DiffLine(.same, $0) }
        return out
    }

    private static func middle(_ x: [String], _ y: [String]) -> [DiffLine] {
        if x.isEmpty { return y.map { DiffLine(.added, $0) } }
        if y.isEmpty { return x.map { DiffLine(.removed, $0) } }
        if x.count * y.count > 4_000_000 { return x.map { DiffLine(.removed, $0) } + y.map { DiffLine(.added, $0) } }
        var t = [[Int]](repeating: [Int](repeating: 0, count: y.count + 1), count: x.count + 1)
        for i in stride(from: x.count - 1, through: 0, by: -1) {
            for j in stride(from: y.count - 1, through: 0, by: -1) {
                t[i][j] = x[i] == y[j] ? t[i + 1][j + 1] + 1 : max(t[i + 1][j], t[i][j + 1])
            }
        }
        var out: [DiffLine] = []
        var i = 0, j = 0
        while i < x.count, j < y.count {
            if x[i] == y[j] { out.append(DiffLine(.same, x[i])); i += 1; j += 1 }
            else if t[i + 1][j] >= t[i][j + 1] { out.append(DiffLine(.removed, x[i])); i += 1 }
            else { out.append(DiffLine(.added, y[j])); j += 1 }
        }
        while i < x.count { out.append(DiffLine(.removed, x[i])); i += 1 }
        while j < y.count { out.append(DiffLine(.added, y[j])); j += 1 }
        return out
    }

    public enum Row: Equatable {
        case line(DiffLine)
        case gap(Int)      // that many unchanged lines left out
    }

    /// Keeps the changed lines and `context` unchanged lines around them; the rest becomes gaps.
    public static func collapse(_ lines: [DiffLine], context: Int = 2) -> [Row] {
        var keep = [Bool](repeating: false, count: lines.count)
        for (i, l) in lines.enumerated() where l.kind != .same {
            for j in max(0, i - context)...min(lines.count - 1, i + context) { keep[j] = true }
        }
        var rows: [Row] = [], skipped = 0
        for (i, l) in lines.enumerated() {
            if keep[i] {
                if skipped > 0 { rows.append(.gap(skipped)); skipped = 0 }
                rows.append(.line(l))
            } else { skipped += 1 }
        }
        if skipped > 0 { rows.append(.gap(skipped)) }
        return rows
    }
}
