import Foundation

/// What a font file says about itself, read from its sfnt tables (.ttf and .otf; a .woff2 is compressed and is not read). No library needed.
public struct FontInfo: Equatable, Sendable {
    public let family: String
    public let style: String
    /// 400 for Regular, 700 for Bold: the file's own class; for a variable font the default.
    public let weight: Int
    public let italic: Bool
    /// The weights a variable font covers (wght axis), nil for a static file.
    public let weightRange: ClosedRange<Int>?

    public var isVariable: Bool { weightRange != nil }

    public static func read(_ url: URL) -> FontInfo? {
        guard let d = try? Data(contentsOf: url), d.count > 12 else { return nil }
        return parse(d)
    }

    static func u16(_ d: Data, _ o: Int) -> Int? { o >= 0 && o + 2 <= d.count ? Int(d[o]) << 8 | Int(d[o + 1]) : nil }
    static func u32(_ d: Data, _ o: Int) -> Int? { o >= 0 && o + 4 <= d.count ? Int(d[o]) << 24 | Int(d[o + 1]) << 16 | Int(d[o + 2]) << 8 | Int(d[o + 3]) : nil }

    public static func parse(_ d: Data) -> FontInfo? {
        guard let tag = u32(d, 0), [0x00010000, 0x4F54544F, 0x74727565].contains(tag), let n = u16(d, 4) else { return nil }
        var tables: [String: (Int, Int)] = [:]
        for i in 0..<n {
            let r = 12 + i * 16
            guard let off = u32(d, r + 8), let len = u32(d, r + 12), r + 16 <= d.count else { return nil }
            tables[String(decoding: d[r..<r + 4], as: UTF8.self)] = (off, len)
        }
        guard let (no, _) = tables["name"], let count = u16(d, no + 2), let so = u16(d, no + 4) else { return nil }
        var names: [Int: String] = [:]
        for i in 0..<count {
            let r = no + 6 + i * 12
            guard let plat = u16(d, r), let id = u16(d, r + 6), let len = u16(d, r + 8), let off = u16(d, r + 10) else { break }
            let s = no + so + off
            guard s + len <= d.count else { continue }
            let raw = d[s..<s + len]
            let text = plat == 3 || plat == 0 ? String(data: raw, encoding: .utf16BigEndian) : String(data: raw, encoding: .macOSRoman)
            if let t = text, names[id] == nil || plat == 3 { names[id] = t }
        }
        guard let family = names[16] ?? names[1], !family.isEmpty else { return nil }
        var weight = 400, italic = false
        if let (oo, _) = tables["OS/2"] {
            weight = u16(d, oo + 4) ?? 400
            italic = ((u16(d, oo + 62) ?? 0) & 1) == 1
        }
        var range: ClosedRange<Int>?
        if let (fo, _) = tables["fvar"], let axesAt = u16(d, fo + 4), let count = u16(d, fo + 8), let size = u16(d, fo + 10) {
            for i in 0..<count {
                let a = fo + axesAt + i * size
                guard a + 16 <= d.count else { break }
                if String(decoding: d[a..<a + 4], as: UTF8.self) == "wght", let lo = u32(d, a + 4), let hi = u32(d, a + 12) { range = (lo >> 16)...(hi >> 16) }
            }
        }
        return FontInfo(family: family, style: names[17] ?? names[2] ?? "", weight: weight, italic: italic, weightRange: range)
    }
}
