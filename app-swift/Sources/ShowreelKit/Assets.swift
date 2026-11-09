import Foundation
import ImageIO

public enum AssetStatus: String, CaseIterable, Sendable {
    case proposed, approved, excluded, placeholder, hold
}

/// One row of `assets/MANIFEST.csv`, in the columns `scripts/organize_assets.py` writes.
public struct AssetRow: Equatable, Identifiable, Sendable {
    public var id: String
    public var file: String          // "prepared/..." or "generated/...", empty when not embedded or held
    public var original: String      // path inside assets/source
    public var origin: String        // source, prepared, generated, not copied
    public var type: String
    public var status: String
    public var licenceNote: String
    public var scene: String         // "S01,S07"
    public var notes: String

    public init(id: String, file: String = "", original: String = "", origin: String = "source", type: String, status: String = "proposed",
                licenceNote: String = "", scene: String = "", notes: String = "") {
        self.id = id; self.file = file; self.original = original; self.origin = origin; self.type = type; self.status = status
        self.licenceNote = licenceNote; self.scene = scene; self.notes = notes
    }

    /// What the user knows the file as: the name it came with.
    public var name: String { ((original.isEmpty ? file : original) as NSString).lastPathComponent }
    public var sceneIDs: [String] { scene.split(whereSeparator: { ", ;".contains($0) }).map(String.init) }
}

/// The asset manifest and the rules of the skill's organiser, for the Resources block.
public enum Assets {
    public static let manifestPath = "assets/MANIFEST.csv"
    public static let columns = ["id", "file", "original", "origin", "type", "status", "licence_note", "scene", "notes"]
    static let embed: Set<String> = ["logo", "icon", "shot", "photo", "illus", "img", "font", "audio", "voice", "sfx", "video", "frames"]

    public static func load(_ store: ProjectStore) -> [AssetRow] {
        guard let text = store.read(manifestPath) else { return [] }
        let rows = CSV.parse(text)
        guard let head = rows.first else { return [] }
        func col(_ n: String) -> Int? { head.firstIndex(of: n) }
        return rows.dropFirst().compactMap { r in
            func v(_ n: String) -> String { col(n).flatMap { $0 < r.count ? r[$0] : nil } ?? "" }
            guard !v("id").isEmpty else { return nil }
            return AssetRow(id: v("id"), file: v("file"), original: v("original"), origin: v("origin"), type: v("type"), status: v("status"),
                            licenceNote: v("licence_note"), scene: v("scene"), notes: v("notes"))
        }
    }

    public static func save(_ rows: [AssetRow], _ store: ProjectStore) throws {
        let body = rows.map { [$0.id, $0.file, $0.original, $0.origin, $0.type, $0.status, $0.licenceNote, $0.scene, $0.notes] }
        try store.write(manifestPath, CSV.write([columns] + body), source: .user)
    }

    // MARK: classification (the same rules as organize_assets.py)

    static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: [.caseInsensitive]) }
    static let sensitiveName = re(#"real[-_ ]?data|customer|client|personal|confidential|internal|secret|password|api[-_]?key|token(?!s)"#)
    static let secretText = re(#"api[-_ ]?key|secret|passw(or)?d|BEGIN [A-Z ]*PRIVATE KEY|\bsk_(live|test)_|bearer [a-z0-9._-]{12,}"#)
    static let noteFile = re(#"licen|consent|info|readme|rights|notice"#)

    static func matches(_ r: NSRegularExpression, _ s: String) -> Bool {
        r.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    public static func classify(_ rel: String) -> String {
        let f = (rel as NSString).lastPathComponent.lowercased()
        let ext = (f as NSString).pathExtension
        switch ext {
        case "ttf", "otf", "woff", "woff2": return "font"
        case "mp3", "wav", "m4a", "ogg", "flac":
            return matches(re(#"voice|narrat|\bvo\b"#), f) ? "voice" : f.contains("sfx") ? "sfx" : "audio"
        case "mp4", "mov", "webm": return "video"
        case "png", "jpg", "jpeg", "webp", "gif", "svg":
            if f.contains("logo") { return "logo" }
            if f.contains("icon") { return "icon" }
            if matches(re(#"screen|shot|\bui\b|app[-_]"#), f) || matches(re(#"(^|/)(product|screens?|ui)/"#), rel.lowercased()) { return "shot" }
            if ext == "jpg" || ext == "jpeg" || matches(re(#"(^|/)photos?/"#), rel.lowercased()) { return "photo" }
            return ext == "svg" ? "illus" : "img"
        case "md", "txt", "pdf", "docx": return matches(noteFile, f) ? "note" : "doc"
        case "csv", "json", "xlsx": return "data"
        default: return "misc"
        }
    }

    public static func slug(_ rel: String, type: String) -> String {
        var base = ((rel as NSString).lastPathComponent as NSString).deletingPathExtension
        base = base.applyingTransform(.stripDiacritics, reverse: false) ?? base
        base = base.lowercased().replacingOccurrences(of: #"real[-_ ]?data"#, with: "", options: .regularExpression)
        let words = base.split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) }).map(String.init)
            .filter { $0 != type && !($0.count <= 2 && Int($0) != nil) }
        let s = String(words.joined(separator: "-").prefix(40)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return s.isEmpty ? "untitled" : s
    }

    /// The reason a non-embedded file must be held (name or content looks like secrets or personal data), or nil.
    static func sensitiveFile(_ url: URL, rel: String) -> String? {
        if matches(sensitiveName, (rel as NSString).lastPathComponent) { return "name suggests real or confidential data: decide first" }
        let ext = url.pathExtension.lowercased()
        if ["env", "pem", "key", "p12", "pfx"].contains(ext) { return "name suggests real or confidential data: decide first (credentials file)" }
        if ["txt", "csv", "json", "md", "tsv", "yaml", "yml", "ini", "cfg"].contains(ext),
           let h = try? FileHandle(forReadingFrom: url) {
            defer { try? h.close() }
            let d = (try? h.read(upToCount: 20000)) ?? Data()
            if matches(secretText, String(decoding: d, as: UTF8.self)) {
                return "name suggests real or confidential data: decide first (content looks like credentials or personal data)"
            }
        }
        return nil
    }

    static func pixelSize(_ url: URL) -> (Int, Int)? {
        guard let s = CGImageSourceCreateWithURL(url as CFURL, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    /// First check that puts an embeddable file on hold, with the reason. Fonts are not checked here (see the note on the row).
    static func holdReason(_ url: URL, rel: String, type: String) -> String? {
        if matches(sensitiveName, (rel as NSString).lastPathComponent) { return "name suggests real or confidential data: decide first" }
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "webp"].contains(ext), let (w, h) = pixelSize(url) {
            if type == "logo" { if w < 200 { return "logo bitmap is small: use a vector version, or accept or exclude" } }
            else if ["shot", "photo", "img"].contains(type), w < 800 || h < 450 { return "low resolution (under 800x450): replace, accept or exclude" }
        }
        return heavyReason(url, type: type)
    }

    /// The weight rules: a video over 5 MB or a sound over 8 MB.
    static func heavyReason(_ url: URL, type: String) -> String? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if type == "video", size > 5_000_000 { return "heavy video: the canvas cannot seek video exactly; stills or frames are better" }
        if ["audio", "voice", "sfx"].contains(type), size > 8_000_000 { return "heavy audio file: check the weight budget" }
        return nil
    }

    static func nextNumber(_ rows: [AssetRow], type: String) -> Int {
        let n = rows.compactMap { r -> Int? in
            let p = r.id.split(separator: "-")
            return p.count == 2 && String(p[0]) == type ? Int(p[1]) : nil
        }.max() ?? 0
        return n + 1
    }

    // MARK: adding files

    /// Copies dropped files into `assets/source` and adds their rows, as the organiser's `--apply` does. Originals are never changed.
    /// Embeddable files that are not held also get their typed copy in `assets/prepared`. Sensitive non-embedded files are not copied.
    @discardableResult
    public static func add(_ urls: [URL], to store: ProjectStore) throws -> [AssetRow] {
        let fm = FileManager.default
        var rows = load(store)
        var added: [AssetRow] = []
        let source = store.root.appendingPathComponent("assets/source")
        let prepared = store.root.appendingPathComponent("assets/prepared")
        for url in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue, !url.lastPathComponent.hasPrefix(".") else { continue }
            let rel = url.lastPathComponent
            let type = classify(rel)
            let n = nextNumber(rows + added, type: type)
            let id = String(format: "%@-%02d", type, n)
            var row = AssetRow(id: id, original: rel, type: type)
            if embed.contains(type) {
                try fm.createDirectory(at: source, withIntermediateDirectories: true)
                let dst = uniqueURL(source, rel)
                try fm.copyItem(at: url, to: dst)
                row.original = dst.lastPathComponent
                // the automatic checks, at once, with no AI and no key: a flagged file stays in source/ (no prepared copy) and needs attention
                var flags = ResourceChecks.flags(dst, rel: rel, type: type)
                if type == "font", let info = FontInfo.read(dst), info.isOpenLicence, !info.forbidsEmbedding { row.licenceNote = "the font states its own open licence: \(info.licence ?? "")"; flags = [] }
                if !flags.isEmpty {
                    row.status = "hold"; row.notes = holdNote(flags, type: type)
                } else {
                    row.status = "approved"                    // added by the user: it is theirs to use
                    try fm.createDirectory(at: prepared, withIntermediateDirectories: true)
                    let name = "\(id)-\(slug(rel, type: type)).\(url.pathExtension.lowercased())"
                    try fm.copyItem(at: dst, to: prepared.appendingPathComponent(name))
                    row.file = "prepared/" + name; row.origin = "prepared"
                }
            } else if let why = sensitiveFile(url, rel: rel) {
                row.origin = "not copied"; row.status = "hold"
                row.notes = why + " (left where it is, not copied into the project)"
            } else {
                try fm.createDirectory(at: source, withIntermediateDirectories: true)
                let dst = uniqueURL(source, rel)
                try fm.copyItem(at: url, to: dst)
                row.original = dst.lastPathComponent
                row.status = "approved"
                row.notes = "not embedded"
            }
            added.append(row)
        }
        if !added.isEmpty { try save(rows + added, store) }
        rows += added
        return added
    }

    static func uniqueURL(_ dir: URL, _ name: String) -> URL {
        let fm = FileManager.default
        var u = dir.appendingPathComponent(name)
        var i = 1
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        while fm.fileExists(atPath: u.path) { i += 1; u = dir.appendingPathComponent(ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)") }
        return u
    }

    /// The note of a flagged row. The skill's wording is kept where it has one (a name that suggests real data, a font licence), so that its manifest checks still read it.
    static func holdNote(_ flags: [ResourceChecks.Flag], type: String) -> String {
        if flags.contains(where: { $0.kind == .sensitive }) { return "name suggests real or confidential data: decide first (" + ResourceChecks.note(flags) + ")" }
        return (type == "font" ? "font licence: " : "") + ResourceChecks.note(flags)
    }

    /// The corrected file takes the place of the one that was flagged: copied into source/, checked again; a clean one is prepared and available, a flagged one still needs attention.
    public static func replace(_ id: String, with url: URL, in store: ProjectStore) throws {
        var rows = load(store)
        guard let i = rows.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("unknown asset \(id)") }
        let fm = FileManager.default
        let assets = store.root.appendingPathComponent("assets"), source = assets.appendingPathComponent("source"), prepared = assets.appendingPathComponent("prepared")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        let dst = uniqueURL(source, url.lastPathComponent)
        try fm.copyItem(at: url, to: dst)
        if !rows[i].file.isEmpty, rows[i].file.hasPrefix("prepared/") { try? fm.removeItem(at: assets.appendingPathComponent(rows[i].file)) }
        rows[i].original = dst.lastPathComponent; rows[i].file = ""; rows[i].origin = "source"; rows[i].licenceNote = ""
        let flags = ResourceChecks.flags(dst, rel: url.lastPathComponent, type: rows[i].type)
        if flags.isEmpty {
            let name = "\(rows[i].type)-\(rows[i].id.split(separator: "-").last.map(String.init) ?? "01")-\(slug(url.lastPathComponent, type: rows[i].type)).\(dst.pathExtension.lowercased())"
            try fm.createDirectory(at: prepared, withIntermediateDirectories: true)
            try? fm.removeItem(at: prepared.appendingPathComponent(name))
            try fm.copyItem(at: dst, to: prepared.appendingPathComponent(name))
            rows[i].file = "prepared/" + name; rows[i].origin = "prepared"; rows[i].status = "approved"; rows[i].notes = ""
        } else { rows[i].status = "hold"; rows[i].notes = holdNote(flags, type: rows[i].type) }
        try save(rows, store)
    }

    // MARK: changing a row

    static let holdReasons = ["name suggests", "font licence", "rights or consent", "low resolution", "logo bitmap", "heavy"]

    /// The refusal for a change, or nil when it is allowed (the organiser's guards: a note for a hold, no approval of sensitive or
    /// licence-blocked files from here).
    public static func refusal(for row: AssetRow, status: AssetStatus?, note: String?, licence: String? = nil) -> String? {
        guard let st = status else { return nil }
        if st == .approved, row.type == "font", row.status != "approved", (licence ?? row.licenceNote).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(row.name) needs its licence note before it can be approved: say what the licence allows (embedding in a film, web or app use)"
        }
        if st == .hold {
            let n = (note ?? row.notes).trimmingCharacters(in: .whitespacesAndNewlines)
            if n.isEmpty { return "a held asset needs a note that says why" }
        }
        if st == .approved && row.status == "hold" {
            if row.notes.hasPrefix("name suggests") {
                return "\(row.id) looks like real or confidential data: paint over the sensitive parts in a copy and add it through the skill, or exclude it"
            }
            if (licence ?? row.licenceNote).trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("unknown") {
                return "\(row.name): with unknown rights the file stays on Needs attention. Say what you are allowed to do with it, or replace it"
            }
        }
        return nil
    }

    /// Applies a change to one row, with the file work the organiser does on `--set`: approving a held, uncopied file makes its prepared
    /// copy; excluding removes our prepared copy (the original stays).
    public static func update(_ id: String, status: AssetStatus?, note: String?, licence: String?, scenes: String?, in store: ProjectStore) throws {
        var rows = load(store)
        guard let i = rows.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("unknown asset \(id)") }
        if let why = refusal(for: rows[i], status: status, note: note, licence: licence) { throw AgentError.msg(why) }
        let fm = FileManager.default
        let assets = store.root.appendingPathComponent("assets")
        if status == .approved, rows[i].status == "hold", !rows[i].original.isEmpty, rows[i].origin != "not copied" {
            // a flagged file is used only once each flag is settled: the rights answered, the risk accepted with a reason, or the file replaced (a name that suggests real data is never accepted here)
            let src = assets.appendingPathComponent("source").appendingPathComponent(rows[i].original)
            let lic = (licence ?? rows[i].licenceNote).trimmingCharacters(in: .whitespacesAndNewlines), why = (note ?? rows[i].notes)
            for f in ResourceChecks.flags(src, rel: rows[i].original, type: rows[i].type) {
                switch f.kind {
                case .sensitive: throw AgentError.msg("\(rows[i].name): \(f.reason). Replace the file with a copy without it, or leave it out")
                case .quality where !why.hasPrefix("accepted:"): throw AgentError.msg("\(rows[i].name): \(f.reason). Replace the file, or accept the risk and say why")
                case .rights where lic.isEmpty: throw AgentError.msg("\(rows[i].name): \(f.reason)")
                default: break
                }
            }
        }
        if let st = status {
            if st == .approved, rows[i].status == "hold", rows[i].file.isEmpty, embed.contains(rows[i].type), rows[i].origin != "not copied" {
                let src = assets.appendingPathComponent("source").appendingPathComponent(rows[i].original)
                let num = rows[i].id.split(separator: "-").last.map(String.init) ?? "01"
                let name = "\(rows[i].type)-\(num)-\(slug(rows[i].original, type: rows[i].type)).\((rows[i].original as NSString).pathExtension.lowercased())"
                try fm.createDirectory(at: assets.appendingPathComponent("prepared"), withIntermediateDirectories: true)
                try fm.copyItem(at: src, to: assets.appendingPathComponent("prepared").appendingPathComponent(name))
                rows[i].file = "prepared/" + name; rows[i].origin = "prepared"
            }
            if st == .excluded, rows[i].file.hasPrefix("prepared/") {
                try? fm.removeItem(at: assets.appendingPathComponent(rows[i].file))
                rows[i].file = ""; rows[i].origin = "source"
            }
            let wasHeld = rows[i].status == "hold"
            rows[i].status = st.rawValue
            if st != .hold, wasHeld, holdReasons.contains(where: { rows[i].notes.hasPrefix($0) }) || rows[i].notes.contains("decide first") { rows[i].notes = "" }
        }
        if let n = note { rows[i].notes = n }
        if let l = licence { rows[i].licenceNote = l }
        if let s = scenes { rows[i].scene = s }
        try save(rows, store)
    }
}
