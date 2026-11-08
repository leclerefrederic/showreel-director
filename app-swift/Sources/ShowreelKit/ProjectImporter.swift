import Foundation

/// What could be read from the markdown of a project made without the app (in a chat). The user confirms before anything is saved.
public struct ImportResult: Equatable {
    public var file: ShowreelFile
    /// Human-readable list of what was found, for the confirmation banner.
    public var found: [String]
    public var sources: [String]
}

public enum ProjectImporter {
    static let languageNames: [String: String] = [
        "english": "en", "french": "fr", "german": "de", "spanish": "es", "italian": "it", "portuguese": "pt",
        "dutch": "nl", "swedish": "sv", "polish": "pl", "japanese": "ja", "chinese": "zh", "korean": "ko",
    ]

    public static func hexColours(in text: String) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for m in matches(#"#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})\b"#, in: text) {
            let c = m.uppercased()
            if seen.insert(c).inserted { out.append(c) }
        }
        return out
    }

    static func matches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    static func capture(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1,
              m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: CharacterSet(charactersIn: " *_`\"'"))
    }

    /// The part of a markdown file under the first heading that contains `title` (up to the next heading of the same or higher level).
    static func section(_ text: String, titled title: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("#") && $0.lowercased().contains(title.lowercased()) }) else { return nil }
        let level = lines[start].prefix { $0 == "#" }.count
        var end = lines.count
        for i in (start + 1)..<lines.count where lines[i].hasPrefix("#") && lines[i].prefix(while: { $0 == "#" }).count <= level { end = i; break }
        return lines[(start + 1)..<end].joined(separator: "\n")
    }

    static func languages(in text: String) -> [String] {
        guard let line = capture(#"(?:reel\s+)?languages?\s*[:=]\s*([^\n]+)"#, in: text) else { return [] }
        var out: [String] = []
        for part in line.split(whereSeparator: { ",;/&".contains($0) }) {
            let w = part.trimmingCharacters(in: .whitespaces).lowercased()
            let code = languageNames[w] ?? (w.count == 2 && w.allSatisfy(\.isLetter) ? w : nil)
            if let c = code, !out.contains(c) { out.append(c) }
        }
        return out
    }

    static func fonts(in text: String) -> ShowreelFile.Fonts? {
        let name = #"([A-Z][A-Za-z0-9]*(?: [A-Z][A-Za-z0-9]*){0,3})"#
        var f = ShowreelFile.Fonts()
        f.titles = capture(#"(?:titles?|headings?|headlines?|display)(?:\s+(?:font|type|face))?\s*[:=]\s*"# + name, in: text)
            ?? capture(name + #"\s+for\s+(?:the\s+)?(?:titles?|headings?|headlines?)"#, in: text)
        f.text = capture(#"(?:body|text|copy)(?:\s+(?:font|type|face))?\s*[:=]\s*"# + name, in: text)
            ?? capture(name + #"\s+for\s+(?:the\s+)?(?:body|text|copy)"#, in: text)
        return f.titles == nil && f.text == nil ? nil : f
    }

    /// Reads brief.md, style-sheet.md and the folder name. Never writes.
    public static func importMarkdown(from root: URL) -> ImportResult {
        let store = ProjectStore(root: root)
        let brief = store.read("brief.md") ?? ""
        let style = store.read("style-sheet.md") ?? ""
        var file = ShowreelFile(name: root.lastPathComponent)
        var found: [String] = [], sources: [String] = []
        if !brief.isEmpty { sources.append("brief.md") }
        if !style.isEmpty { sources.append("style-sheet.md") }

        // Colours: the Look and motion section of the brief first, then the style sheet.
        let look = section(brief, titled: "look") ?? ""
        let palette = hexColours(in: look).isEmpty ? hexColours(in: style) : hexColours(in: look)
        if !palette.isEmpty { file.decisions.palette = palette; found.append("palette (\(palette.count) colours)") }

        let fontText = look + "\n" + style
        if let f = fonts(in: fontText) {
            file.decisions.fonts = f
            found.append("fonts (" + [f.titles.map { "titles: \($0)" }, f.text.map { "text: \($0)" }].compactMap { $0 }.joined(separator: ", ") + ")")
        }
        let langs = languages(in: brief + "\n" + style)
        if !langs.isEmpty { file.reelLanguages = langs; found.append("languages (" + langs.joined(separator: ", ") + ")") }
        if let c = capture(#"conversation\s+language\s*[:=]\s*([A-Za-z]+)"#, in: brief) {
            let w = c.lowercased()
            file.conversationLanguage = languageNames[w] ?? (w.count == 2 ? w : nil)
            if file.conversationLanguage != nil { found.append("conversation language") }
        }
        if let b = capture(#"(?:duration|length)\s*[:=]\s*(\d+)\s*(?:s|sec|seconds)"#, in: brief), let d = Double(b) {
            file.decisions.duration = d; found.append("duration (\(b) s)")
        }
        return ImportResult(file: file, found: found, sources: sources)
    }

    /// Saves a confirmed import: showreel.json, and through it the Decisions section of brief.md.
    public static func confirm(_ r: ImportResult, in root: URL) throws {
        try ProjectStore(root: root).save(r.file)
    }
}
