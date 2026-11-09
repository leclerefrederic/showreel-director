import Foundation

// MARK: the fonts of the Look, and the files that make them part of the film

/// A font of the Look and the weight the film uses it at: titles at 700, text at 400.
public enum LookFontRole: String, CaseIterable, Sendable {
    case titles, text
    public var key: DecisionKey { self == .titles ? .titleFont : .textFont }
    public var weight: Int { self == .titles ? 700 : 400 }
    public var title: String { self == .titles ? "Titles" : "Text" }
}

public enum FontUse {
    public enum State: Equatable, Sendable {
        /// Chosen in the Look, no approved file: the built reel uses a system font.
        case needsFiles
        /// The file is in Resources but not approved (on hold, proposed): only the app's reduced preview is real.
        case previewOnly
        /// Approved files cover every weight the Look uses.
        case embedded(files: Int, bytes: Int, license: String)
    }

    public static let fallbackSentence = "The built reel will use a system font instead. It looks different and can vary between computers."

    /// The roles of the Look that use this family.
    public static func roles(of family: String, in f: ShowreelFile) -> [LookFontRole] {
        LookFontRole.allCases.filter { role in role.key.current(f).caseInsensitiveCompare(family) == .orderedSame }
    }

    static func fileURL(_ r: AssetRow, _ store: ProjectStore) -> URL? {
        if !r.file.isEmpty { return store.root.appendingPathComponent("assets/" + r.file) }
        return r.original.isEmpty ? nil : store.root.appendingPathComponent("assets/source/" + r.original)
    }

    /// What the file of a font resource says (the file, or the original it was copied from).
    public static func info(_ r: AssetRow, _ store: ProjectStore) -> FontInfo? {
        guard r.type == "font" else { return nil }
        return [fileURL(r, store), r.original.isEmpty ? nil : store.root.appendingPathComponent("assets/source/" + r.original)].compactMap { $0 }.lazy.compactMap { FontInfo.read($0) }.first
    }

    /// The font resources that are this family: by what the file says, else by the folder the card put it in.
    public static func rows(of family: String, store: ProjectStore) -> [(row: AssetRow, info: FontInfo?)] {
        let dir = Look.freeFonts().first { $0.name.caseInsensitiveCompare(family) == .orderedSame }?.dir
        return Assets.load(store).filter { $0.type == "font" }.compactMap { r in
            let i = info(r, store)
            if let i = i { return i.family.caseInsensitiveCompare(family) == .orderedSame ? (r, i) : nil }
            return dir.map { r.file.hasPrefix("fonts/\($0)/") } == true ? (r, nil) : nil
        }
    }

    /// The weight a font file name says (Regular, Bold...), for a file that cannot be read (a .woff2) or when the file does not say.
    static func nameWeight(_ file: String) -> Int {
        let n = (file as NSString).lastPathComponent
        for (w, names) in FontFiles.weightNames.sorted(by: { $0.key > $1.key }) where names.contains(where: { n.contains("-" + $0) || n.contains($0 + ".") }) { return w }
        return 400
    }
    /// What an entry says about itself: its weight (or the range of a variable font) and whether it is italic, from the file, else from its name.
    static func facts(_ e: (row: AssetRow, info: FontInfo?)) -> (weight: Int, range: ClosedRange<Int>?, italic: Bool) {
        if let i = e.info { return (i.weight, i.weightRange, i.italic) }
        let n = e.row.file
        return (nameWeight(n), n.contains("[") && n.lowercased().contains("wght") ? 100...900 : nil, n.contains("Italic"))
    }

    /// The approved files that serve a family at a weight: a static file of that weight, else a variable file that covers it.
    static func serving(_ weight: Int, in rows: [(row: AssetRow, info: FontInfo?)]) -> (row: AssetRow, info: FontInfo?)? {
        let ok = rows.filter { $0.row.status == "approved" && !$0.row.file.isEmpty && !facts($0).italic }
        return ok.first { let f = facts($0); return f.range == nil && f.weight == weight } ?? ok.first { facts($0).range?.contains(weight) ?? false }
    }

    public static func state(_ family: String, store: ProjectStore) -> State {
        let weights = store.loadShowreel().map { roles(of: family, in: $0).map { $0.weight } } ?? []
        let need = weights.isEmpty ? [400] : Array(Set(weights)).sorted()
        let rows = rows(of: family, store: store)
        let used = need.compactMap { serving($0, in: rows) }
        if used.count == need.count {
            let files = Set(used.map { $0.row.file })
            let bytes = files.reduce(0) { $0 + ((try? FileManager.default.attributesOfItem(atPath: store.root.appendingPathComponent("assets/" + $1).path)[.size] as? Int) ?? 0) }
            let lic = used.first.map { $0.row.licenceNote.isEmpty ? "licence not recorded" : $0.row.licenceNote } ?? ""
            return .embedded(files: files.count, bytes: bytes, license: lic)
        }
        return rows.contains { $0.row.status != "excluded" } ? .previewOnly : .needsFiles
    }

    /// The words under a font in the Look and in the design board.
    public static func line(_ s: State) -> String {
        switch s {
        case .needsFiles: return "Needs files. " + fallbackSentence
        case .previewOnly: return "Preview only: the file is in Resources but not approved, so the built reel uses a system font."
        case .embedded(let n, let b, let l): return "Embedded: \(n) file\(n == 1 ? "" : "s"), \(kb(b)), \(l)"
        }
    }
    public static func label(_ s: State) -> String { switch s { case .needsFiles: return "Needs files"; case .previewOnly: return "Preview only"; case .embedded: return "Embedded" } }
    static func kb(_ b: Int) -> String { b >= 1_000_000 ? String(format: "%.1f MB", Double(b) / 1e6) : "\(max(1, b / 1000)) KB" }

    /// "Fredoka, 700. Used by Look: Titles" for a font resource.
    public static func describe(_ r: AssetRow, store: ProjectStore) -> String? {
        guard let i = info(r, store) else { return nil }
        var s = "\(i.family), " + (i.weightRange.map { "\($0.lowerBound) to \($0.upperBound)" } ?? "\(i.weight)") + (i.italic ? ", italic" : "")
        if let f = store.loadShowreel() { let u = roles(of: i.family, in: f); if !u.isEmpty { s += ". Used by Look: " + u.map { $0.title }.joined(separator: ", ") } }
        return s
    }
}

// MARK: fonts.json: what the film embeds

public struct FontEntry: Equatable, Sendable {
    public let family: String
    public let weight: String
    public let style: String
    /// Relative to the version folder, like every path of project.json.
    public let path: String
    public let bytes: Int
}

public enum FontEmbedding {
    public static let fileName = "fonts.json"

    /// The approved files the Look references, only for the weights it uses, and the Look fonts that have none (the film falls back on a system font for those).
    public static func plan(_ store: ProjectStore) -> (entries: [FontEntry], missing: [(role: LookFontRole, family: String)], chosen: [(role: LookFontRole, family: String)]) {
        guard let f = store.loadShowreel() else { return ([], [], []) }
        var entries: [FontEntry] = [], missing: [(LookFontRole, String)] = [], chosen: [(LookFontRole, String)] = []
        for role in LookFontRole.allCases {
            let family = role.key.current(f)
            guard !family.isEmpty else { continue }
            chosen.append((role, family))
            let rows = FontUse.rows(of: family, store: store)
            guard let hit = FontUse.serving(role.weight, in: rows) else { missing.append((role, family)); continue }
            let fx = FontUse.facts(hit)
            let weight = fx.range.map { "\($0.lowerBound) \($0.upperBound)" } ?? "\(fx.weight)"
            let bytes = (try? FileManager.default.attributesOfItem(atPath: store.root.appendingPathComponent("assets/" + hit.row.file).path)[.size] as? Int) ?? 0
            let e = FontEntry(family: family, weight: weight, style: "normal", path: "../assets/" + hit.row.file, bytes: bytes ?? 0)
            if !entries.contains(where: { $0.family == e.family && $0.weight == e.weight && $0.path == e.path }) { entries.append(e) }
        }
        return (entries, missing, chosen)
    }

    /// A fingerprint of what the film embeds: the files and the weights. Part of the film's state (the scene files do not depend on it).
    public static func fingerprint(_ store: ProjectStore) -> String {
        let p = plan(store)
        return p.entries.map { "\($0.family)|\($0.weight)|\($0.path)|\($0.bytes)" }.joined(separator: ";") + "#" + p.missing.map { $0.family }.joined(separator: ",")
    }

    /// Writes `fonts.json` in the version folder for build.py (it merges it with project.json's own list), or takes a stale one away.
    @discardableResult
    public static func write(version: String, store: ProjectStore) -> [FontEntry] {
        let url = store.root.appendingPathComponent("\(version)/\(fileName)")
        let p = plan(store)
        if p.entries.isEmpty { try? FileManager.default.removeItem(at: url); return [] }
        let rows: [[String: Any]] = p.entries.map { ["family": $0.family, "weight": $0.weight, "style": $0.style, "path": $0.path] }
        if let d = try? JSONSerialization.data(withJSONObject: ["schema": 1, "fonts": rows], options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) { try? (String(decoding: d, as: UTF8.self) + "\n").write(to: url, atomically: true, encoding: .utf8) }
        return p.entries
    }

    /// The build's "Fonts" line: what is embedded and what falls back, or nil when the Look chose no font.
    public static func step(_ store: ProjectStore, entries: [FontEntry]) -> (ok: Bool, text: String)? {
        let p = plan(store)
        if p.chosen.isEmpty { return nil }
        let emb = Array(Set(p.entries.map { $0.family })).sorted()
        if p.missing.isEmpty { return (true, "embedded: " + emb.joined(separator: ", ") + " (only the weights the Look uses)") }
        let list = p.missing.map { "\($0.family) (\($0.role.title.lowercased()))" }.joined(separator: ", ")
        return (false, "\(list) has no approved file: the reel uses a system font instead (it looks different and can vary between computers). Use Add font files in the Look, or drop the font in Resources." + (emb.isEmpty ? "" : " Embedded: " + emb.joined(separator: ", ") + "."))
    }
}

// MARK: adding the files of a free font

public struct RepoFile: Equatable, Sendable { public let name: String; public let size: Int; public let url: String
    public init(name: String, size: Int, url: String) { self.name = name; self.size = size; self.url = url } }
public struct FontFile: Equatable, Sendable { public let name: String; public let data: Data
    public init(name: String, data: Data) { self.name = name; self.data = data } }

/// Where the files come from. The real one is the open Google Fonts repository; a test gives its own.
public protocol FontSource: Sendable {
    func listing(dir: String) async throws -> [RepoFile]
    func download(_ file: RepoFile) async throws -> Data
}

public struct GoogleFontsSource: FontSource {
    public init() {}
    public func listing(dir: String) async throws -> [RepoFile] {
        guard let u = URL(string: "https://api.github.com/repos/google/fonts/contents/ofl/" + dir) else { throw AgentError.msg("bad font folder") }
        var r = URLRequest(url: u); r.setValue("showreel-studio-font-fetch", forHTTPHeaderField: "User-Agent"); r.timeoutInterval = 20
        let (d, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200, let a = try JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { throw AgentError.msg("the repository answered with an error") }
        return a.compactMap { o in (o["name"] as? String).flatMap { n in (o["download_url"] as? String).map { RepoFile(name: n, size: o["size"] as? Int ?? 0, url: $0) } } }
    }
    public func download(_ file: RepoFile) async throws -> Data {
        guard let u = URL(string: file.url), u.host == "raw.githubusercontent.com" else { throw AgentError.msg("refused: a font only comes from the open font repository") }
        var r = URLRequest(url: u); r.setValue("showreel-studio-font-fetch", forHTTPHeaderField: "User-Agent"); r.timeoutInterval = 60
        let (d, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw AgentError.msg("the repository answered with an error") }
        return d
    }
}

public struct FontPayload: Equatable, Sendable {
    public let family: String
    public let dir: String
    public let files: [FontFile]
    public init(family: String, dir: String, files: [FontFile]) { self.family = family; self.dir = dir; self.files = files }
    public var fontFiles: [FontFile] { files.filter { Self.isFont($0.name) } }
    static func isFont(_ n: String) -> Bool { ["ttf", "otf", "woff2"].contains((n as NSString).pathExtension.lowercased()) }
}

public struct FontOffer: Sendable {
    public let family: String
    public let dir: String
    public let files: [RepoFile]
    public let card: OperationCard
}

public enum FontFiles {
    public static let licence = "SIL Open Font License 1.1"
    public static let approvalNote = "approved by the owner through the Add font files card"
    static let weightNames: [Int: [String]] = [100: ["Thin"], 200: ["ExtraLight"], 300: ["Light"], 400: ["Regular"], 500: ["Medium"], 600: ["SemiBold"], 700: ["Bold"], 800: ["ExtraBold"], 900: ["Black"]]

    public static func manualWay(_ f: Look.Font) -> String {
        "Download \(f.name) from https://fonts.google.com/specimen/\(f.name.replacingOccurrences(of: " ", with: "+")) and drop the files in the Resources tab."
    }

    /// The font of the skill's fixed list; nothing else is ever looked up.
    public static func listed(_ name: String) throws -> Look.Font {
        let list = Look.freeFonts()
        guard let f = list.first(where: { $0.name.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespaces)) == .orderedSame }) else {
            throw AgentError.msg("\"\(name)\" is not in the skill's list of free fonts, so its files cannot be added here. Download it from its own page and drop the files in the Resources tab. The list: " + list.map { $0.name }.joined(separator: ", "))
        }
        return f
    }

    /// The files to take from the repository's folder: the ones for the weights the Look uses (a variable file covers them all), and the licence.
    static func choose(_ listing: [RepoFile], weights: [Int]) -> [RepoFile] {
        let fonts = listing.filter { FontPayload.isFont($0.name) && !$0.name.contains("Italic") }
        var chosen: [RepoFile] = []
        if let v = fonts.first(where: { $0.name.contains("[") && $0.name.lowercased().contains("wght") }) { chosen = [v] }
        else {
            for w in weights {
                if let s = fonts.first(where: { f in !f.name.contains("[") && (weightNames[w] ?? []).contains { f.name.contains("-" + $0 + ".") } }), !chosen.contains(s) { chosen.append(s) }
            }
        }
        if let lic = listing.first(where: { $0.name == "OFL.txt" }) { chosen.append(lic) }
        return chosen
    }

    static func card(_ f: Look.Font, files: [(name: String, size: Int)], need: Bool = true) -> OperationCard {
        let total = files.reduce(0) { $0 + $1.size }
        let names = files.filter { FontPayload.isFont($0.name) || $0.name == "OFL.txt" }.map { "\($0.name) (\(FontUse.kb($0.size)))" }.joined(separator: ", ")
        return OperationCard(title: "Add the font files of \(f.name)", changes: [
            Change("Font", "no file: the reel would use a system font", f.name),
            Change("Source", "none", "the open Google Fonts repository (github.com/google/fonts, ofl/\(f.dir)), from the skill's fixed list"),
            Change("Licence", "not recorded", "\(licence); the licence text (OFL.txt) is kept next to the files"),
            Change("Files", "none", names + "; \(FontUse.kb(total)) in all, in assets/fonts/\(f.dir)/"),
            Change("Network", "not needed to look at", need ? "needed now to download \(FontUse.kb(total))" : "not needed"),
            Change("Approval", "not approved", "accepting this card approves these files for the reel: they are added to the manifest as approved, with the note \"\(approvalNote)\""),
        ])
    }

    /// What adding the files of a font would do, from the repository's listing (a lookup of names and sizes; nothing is downloaded). Throws a readable message,
    /// with the way to do it by hand, when the name is not in the list, the Look does not use the font, or the repository cannot be reached.
    public static func offer(_ name: String, store: ProjectStore, source: FontSource) async throws -> FontOffer {
        let f = try listed(name)
        guard let file = store.loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        let roles = FontUse.roles(of: f.name, in: file)
        guard !roles.isEmpty else { throw AgentError.msg("\(f.name) is not chosen in the Look: choose it for the titles or the text first, then add its files") }
        if case .embedded = FontUse.state(f.name, store: store) { throw AgentError.msg("no change: \(f.name) already is embedded") }
        let listing: [RepoFile]
        do { listing = try await source.listing(dir: f.dir) } catch { throw AgentError.msg("Could not reach the font repository (\(error.localizedDescription)). Nothing was added. " + manualWay(f)) }
        let chosen = choose(listing, weights: Array(Set(roles.map { $0.weight })).sorted())
        guard chosen.contains(where: { FontPayload.isFont($0.name) }) else { throw AgentError.msg("The repository has no file for the weights the Look uses (\(roles.map { "\($0.title.lowercased()) \($0.weight)" }.joined(separator: ", "))). " + manualWay(f)) }
        return FontOffer(family: f.name, dir: f.dir, files: chosen, card: card(f, files: chosen.map { ($0.name, $0.size) }))
    }

    /// The download, after the card was accepted: the payload of the typed operation.
    public static func fetch(_ offer: FontOffer, source: FontSource) async throws -> FontPayload {
        var out: [FontFile] = []
        do { for r in offer.files { out.append(FontFile(name: r.name, data: try await source.download(r))) } }
        catch { throw AgentError.msg("The download failed (\(error.localizedDescription)). Nothing was added. " + ((try? listed(offer.family)).map { manualWay($0) } ?? "")) }
        return FontPayload(family: offer.family, dir: offer.dir, files: out)
    }
}

extension ProjectStore {
    func planAddFontFiles(_ p: FontPayload) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try FontFiles.listed(p.family)
        guard f.dir == p.dir, !p.fontFiles.isEmpty else { throw AgentError.msg("no font file to add") }
        for x in p.files {
            guard !x.name.contains("/"), FontPayload.isFont(x.name) || x.name == "OFL.txt" else { throw AgentError.msg("\(x.name) is not a font file or a licence text") }
        }
        let rows = Assets.load(self)
        let fresh = p.fontFiles.filter { n in !rows.contains { $0.file == "fonts/\(p.dir)/\(n.name)" } }
        guard !fresh.isEmpty else { throw AgentError.msg("no change: the files of \(p.family) are already in the project") }
        let card = FontFiles.card(f, files: p.files.map { ($0.name, $0.data.count) })
        return (card, { try self.performAddFontFiles(p, fresh: fresh) })
    }

    private func performAddFontFiles(_ p: FontPayload, fresh: [FontFile]) throws {
        let fm = FileManager.default
        let dir = root.appendingPathComponent("assets/fonts/\(p.dir)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for x in p.files { try x.data.write(to: dir.appendingPathComponent(x.name), options: .atomic) }
        var rows = Assets.load(self)
        for x in fresh {
            let n = Assets.nextNumber(rows, type: "font")
            rows.append(AssetRow(id: String(format: "font-%02d", n), file: "fonts/\(p.dir)/\(x.name)", original: "", origin: "fonts", type: "font", status: "approved",
                                 licenceNote: "\(FontFiles.licence) (OFL.txt kept next to the files)", scene: "", notes: FontFiles.approvalNote))
        }
        try Assets.save(rows, self)
    }
}
