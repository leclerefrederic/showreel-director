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
        let need = weights.isEmpty ? [400] : Array(Set(weights.map { FontFiles.effectiveWeight($0, family: family) })).sorted()
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
            guard let hit = FontUse.serving(FontFiles.effectiveWeight(role.weight, family: family), in: rows) else { missing.append((role, family)); continue }
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

/// One file to download, as the manifest of the skill lists it. `list` is its name in Google Fonts' own download list, for when the repository does not hold it by `name`.
public struct RepoFile: Equatable, Sendable {
    public let name: String
    public let size: Int
    public let url: String
    public let list: String?
    /// The family it belongs to (the download list is asked by family).
    public let family: String
    public init(name: String, size: Int, url: String, list: String? = nil, family: String = "") { self.name = name; self.size = size; self.url = url; self.list = list; self.family = family }
}
public struct FontFile: Equatable, Sendable { public let name: String; public let data: Data
    public init(name: String, data: Data) { self.name = name; self.data = data } }

/// A failed download, with what the card needs to offer: say what happened and try again.
public struct FontLookupError: Error, LocalizedError, Equatable, Sendable {
    public let family: String
    public let text: String
    public let retryable: Bool
    public var errorDescription: String? { text }
}

/// Where the files come from. The real one is Google Fonts; a test gives its own. It is asked only after the card was accepted.
public protocol FontSource: Sendable {
    func download(_ file: RepoFile) async throws -> Data
}

/// Why a service did not give what was asked: the HTTP code and the address are kept, and a call limit is told apart, because the fix is different (wait, or do it by hand).
public struct FontRepositoryError: Error, LocalizedError, Equatable, Sendable {
    public let status: Int?
    public let url: String
    public let rateLimited: Bool
    public let detail: String
    public let service: String
    public init(status: Int?, url: String, rateLimited: Bool = false, detail: String = "", service: String = "GitHub") { self.status = status; self.url = url; self.rateLimited = rateLimited; self.detail = detail; self.service = service }

    public var errorDescription: String? {
        let at = (status.map { "HTTP \($0) from " } ?? "") + url
        if rateLimited { return "The anonymous request limit of \(service) was reached; try again later or download the font by hand (\(at))" }
        return (detail.isEmpty ? "the service answered with an error" : detail) + " (\(at))"
    }

    /// The answer, judged: a call limit is a 429, or a 403 that says it (the header of calls left, or the words of the message).
    static func judge(status: Int, headers: [AnyHashable: Any], body: Data, url: String) -> FontRepositoryError {
        let left = (headers["x-ratelimit-remaining"] ?? headers["X-RateLimit-Remaining"]) as? String
        let text = String(decoding: body.prefix(600), as: UTF8.self).lowercased()
        let limited = status == 429 || (status == 403 && (left == "0" || text.contains("rate limit")))
        let message = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["message"] as? String
        let service = URL(string: url)?.host.map { $0.contains("google") || $0.contains("gstatic") ? "Google Fonts" : "GitHub" } ?? "GitHub"
        return FontRepositoryError(status: status, url: url, rateLimited: limited, detail: limited ? "" : (status == 404 ? "the file is not there" : (message.map { "the service said: \($0)" } ?? "")), service: service)
    }

    /// The text of a failure of any kind (a refusal, or the network itself).
    static func text(_ error: Error) -> String { error.localizedDescription }
}

/// Google Fonts as the source. Primary: the files of the open repository by their known path (raw.githubusercontent.com/google/fonts, no API, no key). Fallback: Google Fonts' own
/// download list (fonts.google.com/download/list), which names the files that fonts.gstatic.com serves. Nothing is checked in as a key or a token; a file is accepted only when it is
/// not empty, looks like a font and, from the repository, has the size the manifest gives.
public struct GoogleFontsSource: FontSource {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    static func get(_ address: String, session: URLSession, timeout: TimeInterval) async throws -> Data {
        guard let u = URL(string: address) else { throw FontRepositoryError(status: nil, url: address, detail: "bad address") }
        var r = URLRequest(url: u); r.setValue("showreel-studio-font-fetch", forHTTPHeaderField: "User-Agent"); r.timeoutInterval = timeout
        let data: Data, resp: URLResponse
        do { (data, resp) = try await session.data(for: r) }
        catch { throw FontRepositoryError(status: nil, url: address, detail: "the network failed: \(error.localizedDescription)") }
        guard let http = resp as? HTTPURLResponse else { throw FontRepositoryError(status: nil, url: address, detail: "no answer") }
        guard http.statusCode == 200 else { throw FontRepositoryError.judge(status: http.statusCode, headers: http.allHeaderFields, body: data, url: address) }
        return data
    }

    static func looksLikeFont(_ d: Data) -> Bool {
        guard d.count >= 4 else { return false }
        let h = [UInt8](d.prefix(4))
        return h == [0, 1, 0, 0] || h == Array("OTTO".utf8) || h == Array("true".utf8) || h == Array("wOF2".utf8) || h == Array("wOFF".utf8) || h == Array("ttcf".utf8)
    }

    func check(_ d: Data, _ file: RepoFile, size exact: Bool, url: String) throws {
        let isLicence = !FontPayload.isFont(file.name)
        if d.isEmpty { throw FontRepositoryError(status: 200, url: url, detail: "the file is empty") }
        if !isLicence, !Self.looksLikeFont(d) { throw FontRepositoryError(status: 200, url: url, detail: "the file is not a font") }
        if exact, file.size > 0, d.count != file.size { throw FontRepositoryError(status: 200, url: url, detail: "the file is \(d.count) bytes, the list says \(file.size)") }
    }

    public func download(_ file: RepoFile) async throws -> Data {
        guard let u = URL(string: file.url), u.host == "raw.githubusercontent.com" else { throw AgentError.msg("refused: a font only comes from the open font repository") }
        var primary: Error?
        if file.list == nil || !FontPayload.isFont(file.name) {          // a file the repository holds under another name goes straight to the download list
            do { let d = try await Self.get(file.url, session: session, timeout: 60); try check(d, file, size: true, url: file.url); return d }
            catch { primary = error }
        }
        guard !file.family.isEmpty, FontPayload.isFont(file.name) else { throw primary ?? FontRepositoryError(status: nil, url: file.url, detail: "no source") }
        do { return try await fromList(file) }
        catch {
            let a = primary.map { $0.localizedDescription }
            throw FontRepositoryError(status: (error as? FontRepositoryError)?.status, url: (error as? FontRepositoryError)?.url ?? file.url,
                                      rateLimited: ((error as? FontRepositoryError)?.rateLimited ?? false) && (primary as? FontRepositoryError)?.rateLimited != false,
                                      detail: (a.map { "\($0); then the Google Fonts list: " } ?? "") + Self.detail(error), service: "Google Fonts")
        }
    }

    static func detail(_ e: Error) -> String { (e as? FontRepositoryError)?.detail ?? e.localizedDescription }

    /// Google Fonts' own list for the family: the files with the address each is served from.
    func fromList(_ file: RepoFile) async throws -> Data {
        let listURL = "https://fonts.google.com/download/list?family=" + (file.family.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? file.family)
        var text = String(decoding: try await Self.get(listURL, session: session, timeout: 30), as: UTF8.self)
        if text.hasPrefix(")]}'") { text = String(text.dropFirst(4)) }
        guard let j = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any], let m = j["manifest"] as? [String: Any] else {
            throw FontRepositoryError(status: 200, url: listURL, detail: "the download list could not be read")
        }
        let wanted = file.list ?? file.name
        guard let ref = (m["fileRefs"] as? [[String: Any]])?.first(where: { ($0["filename"] as? String) == wanted || ($0["filename"] as? String)?.hasSuffix("/" + wanted) == true }),
              let address = ref["url"] as? String, URL(string: address)?.host == "fonts.gstatic.com" else {
            throw FontRepositoryError(status: 200, url: listURL, detail: "\(wanted) is not in the download list")
        }
        let d = try await Self.get(address, session: session, timeout: 60)
        try check(d, file, size: false, url: address)
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
    /// The licence texts that are kept next to the files.
    static let licenceNames: Set<String> = ["OFL.txt", "LICENSE.txt", "UFL.txt"]
}

public struct FontOffer: Sendable {
    public let family: String
    public let dir: String
    public let files: [RepoFile]
    public let license: String
    public let card: OperationCard
}

public enum FontFiles {
    /// The default licence wording (a font of the list says its own: SIL Open Font License for most, Apache for a few).
    public static let licence = "SIL Open Font License 1.1"
    public static let approvalNote = "approved by the owner through the Add font files card"
    static let weightNames: [Int: [String]] = [100: ["Thin"], 200: ["ExtraLight"], 300: ["Light"], 400: ["Regular"], 500: ["Medium"], 600: ["SemiBold"], 700: ["Bold"], 800: ["ExtraBold"], 900: ["Black"]]
    public static let sourceName = "Google Fonts"

    public static func manualWay(_ f: Look.Font) -> String {
        "Download \(f.name) from \(f.specimen) and drop the files in the Resources tab."
    }

    /// The font of the skill's fixed list; nothing else is ever looked up.
    public static func listed(_ name: String) throws -> Look.Font {
        let list = Look.freeFonts()
        guard let f = list.first(where: { $0.name.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespaces)) == .orderedSame }) else {
            throw AgentError.msg("\"\(name)\" is not in the skill's list of free fonts, so its files cannot be added here. Download it from its own page and drop the files in the Resources tab. The list: " + list.map { $0.name }.joined(separator: ", "))
        }
        return f
    }

    /// The weight of the family that serves a weight the Look asks for: the same one when the family has it (or a variable file covers it), else the nearest it has (a display face with a
    /// single weight serves every request with it).
    public static func effectiveWeight(_ wanted: Int, family: String) -> Int {
        guard let f = Look.freeFonts().first(where: { $0.name.caseInsensitiveCompare(family) == .orderedSame }), !f.files.contains(where: { $0.variable }) else { return wanted }
        let have = f.files.compactMap { $0.weight }
        if have.isEmpty || have.contains(wanted) { return wanted }
        return have.min { abs($0 - wanted) < abs($1 - wanted) } ?? wanted
    }

    static func rawURL(_ f: Look.Font, _ name: String) -> String {
        "https://raw.githubusercontent.com/google/fonts/main/\(f.tree)/\(f.dir)/" + (name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)
    }

    /// The files to take, from the manifest alone: the ones for the weights the Look uses (a variable file covers them all), and the licence text.
    static func plan(_ f: Look.Font, weights: [Int]) -> [RepoFile] {
        var chosen: [RepoFile] = []
        func add(_ s: Look.Font.FileSpec) { if !chosen.contains(where: { $0.name == s.name }) { chosen.append(RepoFile(name: s.name, size: s.size ?? 0, url: rawURL(f, s.name), list: s.list, family: f.name)) } }
        if let v = f.files.first(where: { $0.variable }) { add(v) }
        else { for w in Set(weights.map { effectiveWeight($0, family: f.name) }).sorted() { if let s = f.files.first(where: { $0.weight == w }) { add(s) } } }
        if !chosen.isEmpty { chosen.append(RepoFile(name: f.licenseFile, size: 0, url: rawURL(f, f.licenseFile), family: f.name)) }
        return chosen
    }

    static func card(_ f: Look.Font, files: [(name: String, size: Int)]) -> OperationCard {
        let fonts = files.filter { FontPayload.isFont($0.name) }
        let total = fonts.reduce(0) { $0 + $1.size }
        let names = fonts.map { "\($0.name) (\(FontUse.kb($0.size)))" }.joined(separator: ", ") + (files.count > fonts.count ? ", and the licence text (\(f.licenseFile))" : "")
        return OperationCard(title: "Add the font files of \(f.name)", changes: [
            Change("Font", "no file: the reel would use a system font", f.name),
            Change("Source", "none", "\(sourceName) (the open google/fonts repository), from the skill's fixed list"),
            Change("Licence", "not recorded", "\(f.license); the licence text (\(f.licenseFile)) is kept next to the files"),
            Change("Files", "none", names + "; \(FontUse.kb(total)) in all, in assets/fonts/\(f.dir)/"),
            Change("Network", "not used to build this card", "needed once you accept, to download \(FontUse.kb(total))"),
            Change("Approval", "not approved", "accepting this card approves these files for the reel: they are added to the manifest as approved, with the note \"\(approvalNote)\""),
        ])
    }

    /// What adding the files of a font would do, built from the skill's manifest: no network call. Throws a readable message, with the way to do it by hand, when the name is
    /// not in the list, the Look does not use the font, or the manifest has no file for it.
    public static func offer(_ name: String, store: ProjectStore) throws -> FontOffer {
        let f = try listed(name)
        guard let file = store.loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        let roles = FontUse.roles(of: f.name, in: file)
        guard !roles.isEmpty else { throw AgentError.msg("\(f.name) is not chosen in the Look: choose it for the titles or the text first, then add its files") }
        if case .embedded = FontUse.state(f.name, store: store) { throw AgentError.msg("no change: \(f.name) already is embedded") }
        let chosen = plan(f, weights: Array(Set(roles.map { $0.weight })).sorted())
        guard chosen.contains(where: { FontPayload.isFont($0.name) }) else { throw AgentError.msg("The skill's list has no file for \(f.name) at the weights the Look uses. " + manualWay(f)) }
        return FontOffer(family: f.name, dir: f.dir, files: chosen, license: f.license, card: card(f, files: chosen.map { ($0.name, $0.size) }))
    }

    /// The download, after the card was accepted: every file is fetched and checked (present, not empty) before anything is written, so a failure leaves nothing.
    public static func fetch(_ offer: FontOffer, source: FontSource) async throws -> FontPayload {
        var out: [FontFile] = []
        do {
            for r in offer.files {
                let d = try await source.download(r)
                guard !d.isEmpty else { throw FontRepositoryError(status: 200, url: r.url, detail: "the file \(r.name) is empty") }
                out.append(FontFile(name: r.name, data: d))
            }
        } catch { throw FontLookupError(family: offer.family, text: "The download failed (\(error.localizedDescription)). Nothing was added. " + ((try? listed(offer.family)).map { manualWay($0) } ?? ""), retryable: true) }
        return FontPayload(family: offer.family, dir: offer.dir, files: out)
    }
}

extension ProjectStore {
    func planAddFontFiles(_ p: FontPayload) throws -> (card: OperationCard, run: () throws -> Void) {
        let f = try FontFiles.listed(p.family)
        guard f.dir == p.dir, !p.fontFiles.isEmpty else { throw AgentError.msg("no font file to add") }
        for x in p.files {
            guard !x.name.contains("/"), FontPayload.isFont(x.name) || FontPayload.licenceNames.contains(x.name) else { throw AgentError.msg("\(x.name) is not a font file or a licence text") }
        }
        let rows = Assets.load(self)
        let fresh = p.fontFiles.filter { n in !rows.contains { $0.file == "fonts/\(p.dir)/\(n.name)" } }
        guard !fresh.isEmpty else { throw AgentError.msg("no change: the files of \(p.family) are already in the project") }
        let card = FontFiles.card(f, files: p.files.map { ($0.name, $0.data.count) })
        return (card, { try self.performAddFontFiles(p, fresh: fresh, license: f.license, licenceFile: f.licenseFile) })
    }

    /// Writes the files and the manifest rows; if anything fails on the way, what was written is taken away again (nothing is left half added).
    private func performAddFontFiles(_ p: FontPayload, fresh: [FontFile], license: String, licenceFile: String) throws {
        let fm = FileManager.default
        let dir = root.appendingPathComponent("assets/fonts/\(p.dir)")
        let existed = fm.fileExists(atPath: dir.path)
        var written: [URL] = []
        let before = Assets.load(self)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for x in p.files {
                let u = dir.appendingPathComponent(x.name)
                if !fm.fileExists(atPath: u.path) { written.append(u) }
                try x.data.write(to: u, options: .atomic)
            }
            var rows = before
            for x in fresh {
                let n = Assets.nextNumber(rows, type: "font")
                rows.append(AssetRow(id: String(format: "font-%02d", n), file: "fonts/\(p.dir)/\(x.name)", original: "", origin: "fonts", type: "font", status: "approved",
                                     licenceNote: "\(license) (\(licenceFile) kept next to the files)", scene: "", notes: FontFiles.approvalNote))
            }
            try Assets.save(rows, self)
        } catch {
            for u in written { try? fm.removeItem(at: u) }
            if !existed { try? fm.removeItem(at: dir) }
            try? Assets.save(before, self)
            throw error
        }
    }
}

// MARK: the question before a build

/// What happens when a Build or an Assemble starts and a font of the Look has no file: the app asks first. Nothing is downloaded without the yes, and the card is built from the
/// skill's manifest: asking the question uses no network.
public struct FontsAtBuild: Sendable {
    public enum Choice: String, Sendable { case download, systemFont, cancel }
    public enum Action: Equatable, Sendable { case proceed, stop }

    /// The fonts of the Look that have no file and can be fetched (they are in the skill's fixed list).
    public let families: [String]
    public let offers: [FontOffer]
    public let card: OperationCard

    public var totalBytes: Int { offers.reduce(0) { $0 + $1.files.reduce(0) { $0 + $1.size } } }

    /// The Look fonts that need files and that the app can fetch. Empty when every font has its files (no question is asked).
    public static func missing(_ store: ProjectStore) -> [String] {
        guard let f = store.loadShowreel() else { return [] }
        var out: [String] = []
        for role in LookFontRole.allCases {
            let family = role.key.current(f)
            guard !family.isEmpty, !out.contains(family), (try? FontFiles.listed(family)) != nil else { continue }
            if case .needsFiles = FontUse.state(family, store: store) { out.append(family) }
        }
        return out
    }

    /// The question, or nil when nothing is missing. No network.
    public static func prepare(_ store: ProjectStore) -> FontsAtBuild? {
        let families = missing(store)
        guard !families.isEmpty else { return nil }
        let offers = families.compactMap { try? FontFiles.offer($0, store: store) }
        let size = offers.reduce(0) { $0 + $1.files.reduce(0) { $0 + $1.size } }
        let licences = Array(Set(offers.map { $0.license })).sorted().joined(separator: ", ")
        let card = OperationCard(title: "Fonts without files: " + families.joined(separator: ", "), changes: [
            Change("Fonts", "no file: the built reel would use a system font", families.joined(separator: ", ")),
            Change("Source", "none", "\(FontFiles.sourceName) (the open google/fonts repository), from the skill's fixed list"),
            Change("Licence", "not recorded", (licences.isEmpty ? FontFiles.licence : licences) + "; the licence text is kept next to the files"),
            Change("Size", "unknown", offers.count == families.count ? FontUse.kb(size) + " in all" : "not known for every font"),
            Change("Download and continue", "nothing is downloaded", "the files are downloaded and approved for the reel, then the build starts"),
            Change("Continue with a system font", "the Fonts step stays orange", "the build starts now with a system font, and the Fonts step says so"),
        ])
        return FontsAtBuild(families: families, offers: offers, card: card)
    }

    /// Carries out the choice: the journal records it; the download is the existing typed operation (one per font, undoable). Returns whether the build goes on.
    /// A download that fails throws a `FontLookupError`: nothing was added and the build does not start.
    public func resolve(_ choice: Choice, store: ProjectStore, source: FontSource) async throws -> Action {
        let names = families.joined(separator: ", ")
        switch choice {
        case .cancel:
            store.noteEvent(author: "user", op: "fonts", target: names, title: "Fonts at build: cancelled", before: "no file", after: "no file", note: "the build was not started")
            return .stop
        case .systemFont:
            store.noteEvent(author: "user", op: "fonts", target: names, title: "Fonts at build: continue with a system font", before: "no file", after: "no file", note: "nothing was downloaded; the Fonts step says the reel uses a system font")
            return .proceed
        case .download:
            var payloads: [FontPayload] = []
            for fam in families { payloads.append(try await FontFiles.fetch(try FontFiles.offer(fam, store: store), source: source)) }       // all fetched before any is added
            try store.transaction("Add the font files of \(names)") {
                for p in payloads { try store.apply(.addFontFiles(p), author: "user", reason: "approved through the fonts card at the start of a build") }
            }
            store.noteEvent(author: "user", op: "fonts", target: names, title: "Fonts at build: download and continue", before: "no file", after: "files added: " + names, note: "approved through the card")
            return .proceed
        }
    }
}
