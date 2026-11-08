import Foundation

/// The catalogues behind the Look block, read from the skill (single source of truth: nothing is copied into the app).
public enum Look {
    static var engineDir: URL? { Skill.root()?.appendingPathComponent("engine") }

    /// Background ids, in the order of engine/backgrounds.js (add('id', ...)).
    public static func backgroundIDs() -> [String] {
        guard let u = engineDir?.appendingPathComponent("backgrounds.js"), let js = try? String(contentsOf: u, encoding: .utf8) else { return [] }
        return ProjectImporter.matches(#"add\('([a-z0-9-]+)',"#, in: js).map { $0.replacingOccurrences(of: "add('", with: "").replacingOccurrences(of: "',", with: "") }
    }

    /// The reaction moods of the backgrounds: punch, playful, tech, clean, cinematic, deadpan (SRB.moods).
    public static func backgroundMoods() -> [String] {
        guard let u = engineDir?.appendingPathComponent("backgrounds.js"), let js = try? String(contentsOf: u, encoding: .utf8),
              let line = js.components(separatedBy: "\n").first(where: { $0.contains("const MOODS =") }) else { return [] }
        return ProjectImporter.matches(#"(\w+): ?[\d.]+"#, in: line).map { String($0.split(separator: ":")[0]) }
    }

    public struct Pack: Equatable, Sendable, Identifiable {
        public let name: String
        public let feel: String
        public let effects: [String]
        public var id: String { name }
    }

    /// The mood packs of references/effects-catalogue.md (the Packs table). A name in parentheses after an effect is dropped.
    public static func packs() -> [Pack] {
        guard let u = Skill.root()?.appendingPathComponent("references/effects-catalogue.md"), let cat = try? String(contentsOf: u, encoding: .utf8),
              let a = cat.range(of: "## Packs") else { return [] }
        var out: [Pack] = []
        let table = cat[a.lowerBound...].components(separatedBy: "\n")
        for line in table.dropFirst(3) {
            guard line.hasPrefix("|") else { break }
            let c = MarkdownTable.cells(line)
            guard c.count >= 3 else { continue }
            let effects = c[2].replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            out.append(Pack(name: c[0], feel: c[1], effects: effects))
        }
        return out
    }

    /// Every effect of the library with its category, read from references/effects-index.md (the tables under "## Category (n)").
    public static func effectList() -> [(cat: String, name: String)] { effectCache }
    public static func effects() -> [String] { effectCache.map { $0.name } }
    public static func effectCategory(_ name: String) -> String? { effectCache.first { $0.name == name }?.cat }

    private static let effectCache: [(cat: String, name: String)] = {
        guard let u = Skill.root()?.appendingPathComponent("references/effects-index.md"), let md = try? String(contentsOf: u, encoding: .utf8) else { return [] }
        var cat = "", out: [(String, String)] = []
        for line in md.components(separatedBy: "\n") {
            if line.hasPrefix("## ") { cat = line.dropFirst(3).replacingOccurrences(of: #"\s*\(\d+\)\s*$"#, with: "", options: .regularExpression); continue }
            guard line.hasPrefix("|"), !cat.isEmpty else { continue }
            let c = MarkdownTable.cells(line)
            guard let n = c.first, !n.isEmpty, n != "Effect", !n.hasPrefix("---"), !n.hasPrefix(":-") else { continue }
            out.append((cat, n))
        }
        return out
    }()

    public struct Font: Decodable, Equatable, Sendable, Identifiable {
        public let name: String
        public let dir: String
        public let cat: String
        public let moods: [String]
        public let note: String
        public var id: String { name }
    }

    /// The curated free fonts (engine/fonts-free.json, all under open licences).
    public static func freeFonts() -> [Font] {
        guard let u = engineDir?.appendingPathComponent("fonts-free.json"), let d = try? Data(contentsOf: u) else { return [] }
        return (try? JSONDecoder().decode([Font].self, from: d)) ?? []
    }

    /// The bundled preview file of a free font (woff2), for real samples.
    public static func previewURL(for f: Font) -> URL? {
        let u = engineDir?.appendingPathComponent("fonts-preview/\(f.dir).woff2")
        return u.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }
}

/// WCAG contrast between two colours, for the palette check. Deterministic and AI-free.
public enum Contrast {
    static func channel(_ v: Double) -> Double { let c = v / 255; return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }

    public static func luminance(_ hex: String) -> Double {
        let c = EnginePalette.rgb(hex)
        return 0.2126 * channel(c[0]) + 0.7152 * channel(c[1]) + 0.0722 * channel(c[2])
    }

    /// 1 to 21. 4.5 is the AA level for normal text, 3 for large text and graphics.
    public static func ratio(_ a: String, _ b: String) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// The palette's contrast checks: text on background (AA 4.5), accents on background (3, they carry shapes and large words).
    public static func checks(_ p: [String]?) -> [CheckResult] {
        func r(_ id: String, _ title: String, _ level: CheckLevel, _ detail: String) -> CheckResult { CheckResult(id: "palette." + id, block: "look", title: title, level: level, detail: detail) }
        guard let p = p, !p.isEmpty else { return [r("any", "Palette", .pending, "No palette yet.")] }
        let bad = p.filter { !EnginePalette.isHex($0) }
        if !bad.isEmpty { return [r("hex", "Palette colours", .fail, bad.joined(separator: ", ") + ": not a #RRGGBB colour")] }
        guard p.count >= 2 else { return [r("pair", "Text on background", .pending, "Add the text colour to check the contrast.")] }
        let pal = EnginePalette(stored: p)
        func level(_ ratio: Double, ok: Double, tight: Double) -> CheckLevel { ratio >= ok ? .ok : ratio >= tight ? .tight : .fail }
        func fmt(_ x: Double) -> String { String(format: "%.1f:1", x) }
        var out: [CheckResult] = []
        let t = ratio(pal.fg, pal.bg)
        let tl = level(t, ok: 4.5, tight: 3)
        out.append(r("text", "Text on background", tl, "\(fmt(t)) (needs 4.5:1)" + (tl == .tight ? ": fine for large text only" : tl == .fail ? ": too low to read" : "")))
        if p.count > 2 {
            let a = ratio(pal.accent, pal.bg), al = level(a, ok: 3, tight: 2)
            out.append(r("accent", "Accent on background", al, "\(fmt(a)) (needs 3:1)" + (al == .fail ? ": the accent will not stand out" : "")))
        }
        if p.count > 3 {
            let a = ratio(pal.accent2, pal.bg), al = level(a, ok: 3, tight: 2)
            out.append(r("accent2", "Accent 2 on background", al, "\(fmt(a)) (needs 3:1)" + (al == .fail ? ": it will not stand out" : "")))
        }
        return out
    }
}

/// The licence of a font the film would embed. The curated free list is open-licensed; a supplied font is checked on its
/// embedding flag (OS/2 fsType) and on what the asset rows say.
public enum FontLicense {
    /// fsType of a TrueType or OpenType file, or nil (woff2 and other files are not read here).
    public static func fsType(of data: Data) -> UInt16? {
        func u16(_ o: Int) -> Int? { o + 2 <= data.count ? Int(data[o]) << 8 | Int(data[o + 1]) : nil }
        func u32(_ o: Int) -> Int? { o + 4 <= data.count ? Int(data[o]) << 24 | Int(data[o + 1]) << 16 | Int(data[o + 2]) << 8 | Int(data[o + 3]) : nil }
        guard data.count > 12, let tag = u32(0), [0x00010000, 0x4F54544F, 0x74727565].contains(tag), let n = u16(4) else { return nil }
        for i in 0..<n {
            let rec = 12 + i * 16
            guard let t = u32(rec), let off = u32(rec + 8) else { return nil }
            if t == 0x4F532F32 { return u16(off + 8).map { UInt16($0) } }   // "OS/2"
        }
        return nil
    }

    public static func restricted(_ fsType: UInt16) -> Bool { fsType & 0x2 != 0 || fsType & 0x4 != 0 }

    public struct Assessment: Equatable, Sendable {
        public let level: CheckLevel
        public let message: String
    }

    /// Whether a font name can be embedded in the film. Never silent about what is not known.
    public static func assess(name: String, assets: [AssetRow], store: ProjectStore) -> Assessment {
        if Look.freeFonts().contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return Assessment(level: .ok, message: "Open licence (from the free list): it can be embedded.")
        }
        let slug = name.lowercased().filter { $0.isLetter || $0.isNumber }
        let mine = assets.first { $0.type == "font" && ($0.original + " " + $0.file).lowercased().filter { $0.isLetter || $0.isNumber }.contains(slug) }
        guard let a = mine else {
            return Assessment(level: .tight, message: "\(name) is not in the free list and no font file was added: its licence is unknown. Add the file in Resources, or check that the licence allows embedding in a web page or app.")
        }
        if a.notes.hasPrefix("font licence") || a.status == "hold" && a.notes.lowercased().contains("licen") {
            return Assessment(level: .fail, message: "The licence of \(a.name) forbids embedding: \(a.notes). Exclude it or record what the licence really covers.")
        }
        let file = store.root.appendingPathComponent("assets/source/" + a.original)
        if let d = try? Data(contentsOf: file), let t = fsType(of: d), restricted(t) {
            return Assessment(level: .fail, message: "\(a.name) carries a flag that forbids embedding (installable embedding is not allowed). Pick another font or get a web or app licence.")
        }
        if a.licenceNote.isEmpty {
            return Assessment(level: .tight, message: "\(a.name): no licence note recorded. Note what the licence allows (web and app embedding) before approving it.")
        }
        return Assessment(level: .ok, message: "Licence noted: \(a.licenceNote)")
    }
}

/// A complete look offered on the look board: palette, background, font pair, effects mood. An option, never a default.
public struct LookPackage: Decodable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let why: String
    public let tags: [String]
    public let palette: [String]
    public let background: String
    public let fonts: ShowreelFile.Fonts
    public let pack: String

    /// The changes that choosing this package makes, as the decisions of the Look block.
    public var decisions: [DecisionChange] {
        [DecisionChange(.palette, palette.joined(separator: ", ")), DecisionChange(.titleFont, fonts.titles ?? ""), DecisionChange(.textFont, fonts.text ?? ""),
         DecisionChange(.background, background), DecisionChange(.backgroundMood, Look.mood(forPack: pack) ?? ""),
         DecisionChange(.moods, pack), DecisionChange(.effectsPack, pack)]
    }
}

public enum LookPackages {
    public static func all() -> [LookPackage] {
        guard let u = resource("shared", dev: "app-swift/shared")?.appendingPathComponent("look-packages.json"), let d = try? Data(contentsOf: u),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let a = o["packages"],
              let pd = try? JSONSerialization.data(withJSONObject: a) else { return [] }
        return (try? JSONDecoder().decode([LookPackage].self, from: pd)) ?? []
    }

    /// Three packages to compare. Those whose tags match words of the tone come first (a recommendation, never a pre-selection);
    /// `offset` moves on to the next three. Always three distinct effects moods when the data allows it.
    public static func three(tone: String?, offset: Int = 0) -> [LookPackage] {
        let words = (tone ?? "").lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        let all = all()
        let scored = all.enumerated().map { (i, p) in (p, p.tags.filter { t in words.contains { $0.hasPrefix(t.prefix(4)) || t.hasPrefix($0.prefix(4)) } }.count, i) }
        let ordered = scored.sorted { ($0.1, -$0.2) > ($1.1, -$1.2) }.map { $0.0 }
        guard !ordered.isEmpty else { return [] }
        let n = ordered.count
        return (0..<min(3, n)).map { ordered[(offset * 3 + $0) % n] }
    }

    /// Whether a package matches words of the tone (to say "recommended for your tone").
    public static func matches(_ p: LookPackage, tone: String?) -> Bool {
        let words = (tone ?? "").lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        return p.tags.contains { t in words.contains { $0.hasPrefix(t.prefix(4)) || t.hasPrefix($0.prefix(4)) } }
    }
}

extension Look {
    /// The reaction mood of the backgrounds that goes with an effects pack (SRB.moodFor in backgrounds.js).
    public static func mood(forPack pack: String) -> String? {
        guard let u = engineDir?.appendingPathComponent("backgrounds.js"), let js = try? String(contentsOf: u, encoding: .utf8),
              let line = js.components(separatedBy: "\n").first(where: { $0.contains("SRB.moodFor =") }) else { return nil }
        for m in ProjectImporter.matches(#"'([^']+)': '(\w+)'"#, in: line) {
            let parts = m.components(separatedBy: "'")
            if parts.count >= 4, parts[1] == pack { return parts[3] }
        }
        return nil
    }
}
