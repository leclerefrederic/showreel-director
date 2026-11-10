import CryptoKit
import Foundation

/// A design package (docs/Claude/studio-spec.md, section 5.6): a saved design system that pre-configures a new reel. One archive, `.studiopack`: `package.json` first, then
/// `design.json`, `resources.json` and `assets/`. It is user data and every text in it is data, never an instruction.
public enum PackageType {
    /// The type the app registers (exported type declaration, conforming to a zip archive) so that a double-click opens the import card.
    public static let identifier = "com.showreelstudio.studiopack"
    public static let fileExtension = "studiopack"
    public static let manifestName = "package.json", designName = "design.json", resourcesName = "resources.json", assetsFolder = "assets/"
}

/// A package version is a readable number: 1.0, 1.1, 1.2...
public enum PackageVersion {
    public static func parse(_ v: String) -> [Int]? {
        guard v.range(of: #"^\d{1,6}(\.\d{1,6}){0,3}$"#, options: .regularExpression) != nil else { return nil }
        return v.split(separator: ".").compactMap { Int($0) }
    }
    public static func isValid(_ v: String) -> Bool { parse(v) != nil }

    /// -1, 0 or 1; a version that is not a number is older than any that is.
    public static func compare(_ a: String, _ b: String) -> Int {
        guard let x = parse(a) else { return parse(b) == nil ? 0 : -1 }
        guard let y = parse(b) else { return 1 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p < q ? -1 : 1 }
        }
        return 0
    }

    /// The version that follows: the last number goes up ("1.2" gives "1.3", "2" gives "2.1").
    public static func next(after v: String) -> String {
        guard var p = parse(v) else { return "1.0" }
        if p.count == 1 { p.append(1) } else { p[p.count - 1] += 1 }
        return p.map(String.init).joined(separator: ".")
    }
}

/// The author is a display name the user chooses, never an e-mail address and never read from the system account.
public enum PackageAuthor {
    public static let limit = 80

    public static func looksLikeEmail(_ s: String) -> Bool {
        s.range(of: #"\S+@\S+"#, options: .regularExpression) != nil || s.lowercased().contains("mailto:")
    }

    /// The name, cleaned, or the reason it is refused.
    public static func validate(_ raw: String) throws -> String {
        let n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { throw PackageError.invalid("Give the author a display name") }
        if looksLikeEmail(n) { throw PackageError.invalid("The author is a display name, not an e-mail address: use a name or a team name") }
        if n.count > limit { throw PackageError.invalid("The author name is too long (\(limit) characters at most)") }
        if n.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) { throw PackageError.invalid("The author name has a character that is not allowed") }
        return n
    }
}

// MARK: the files of a package

public struct PackageManifest: Codable, Equatable, Sendable {
    public static let currentFormat = 1
    /// The version of the app that writes a package: an older app may not understand it.
    public static var currentAppVersion: String { PackageVersion.isValid(AppInfo.version) ? AppInfo.version : "0" }
    public var format: Int
    /// A UUID made once and kept through every version.
    public var id: String
    public var name: String
    public var version: String
    public var author: String
    public var created: String
    public var modified: String
    public var hash: String
    public var note: String
    public var appMinVersion: String

    public init(format: Int = PackageManifest.currentFormat, id: String = UUID().uuidString.lowercased(), name: String, version: String = "1.0", author: String, created: String, modified: String,
                hash: String = "", note: String = "", appMinVersion: String = PackageManifest.currentAppVersion) {
        self.format = format; self.id = id; self.name = name; self.version = version; self.author = author; self.created = created; self.modified = modified
        self.hash = hash; self.note = note; self.appMinVersion = appMinVersion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(Int.self, forKey: .format)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        version = try c.decode(String.self, forKey: .version)
        author = try c.decode(String.self, forKey: .author)
        created = try c.decode(String.self, forKey: .created)
        modified = try c.decode(String.self, forKey: .modified)
        hash = try c.decode(String.self, forKey: .hash)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        appMinVersion = try c.decodeIfPresent(String.self, forKey: .appMinVersion) ?? "0"
    }

    /// The first 8 characters, as the cards show it.
    public var shortHash: String { String(hash.prefix(8)) }
}

public struct PackageDesign: Codable, Equatable, Sendable {
    public struct Look: Codable, Equatable, Sendable {
        public var palette: [String]?
        public var titleFont: String?
        public var textFont: String?
        public var background: String?
        public var backgroundMood: String?
        public var moods: [String]?
        public var effectsPack: String?
        public init(palette: [String]? = nil, titleFont: String? = nil, textFont: String? = nil, background: String? = nil, backgroundMood: String? = nil, moods: [String]? = nil, effectsPack: String? = nil) {
            self.palette = palette; self.titleFont = titleFont; self.textFont = textFont; self.background = background; self.backgroundMood = backgroundMood; self.moods = moods; self.effectsPack = effectsPack
        }
    }
    /// The way scenes follow one another, when the project has one.
    public struct Motion: Codable, Equatable, Sendable {
        public var defaultTransition: String
        public var duration: Double?
        public init(defaultTransition: String, duration: Double? = nil) { self.defaultTransition = defaultTransition; self.duration = duration }
    }
    public struct Defaults: Codable, Equatable, Sendable {
        public var formats: [String]?
        public var duration: Double?
        public var reelLanguages: [String]?
        public var controlLevel: String?
        public init(formats: [String]? = nil, duration: Double? = nil, reelLanguages: [String]? = nil, controlLevel: String? = nil) {
            self.formats = formats; self.duration = duration; self.reelLanguages = reelLanguages; self.controlLevel = controlLevel
        }
        public var isEmpty: Bool { (formats ?? []).isEmpty && duration == nil && (reelLanguages ?? []).isEmpty && controlLevel == nil }
    }

    public var look: Look?
    public var motion: Motion?
    public var tone: String?
    public var defaults: Defaults?
    public init(look: Look? = nil, motion: Motion? = nil, tone: String? = nil, defaults: Defaults? = nil) { self.look = look; self.motion = motion; self.tone = tone; self.defaults = defaults }
    public var isEmpty: Bool { look == nil && motion == nil && (tone ?? "").isEmpty && (defaults?.isEmpty ?? true) }
}

/// One resource a package carries, with what the package's author said about the rights to use it. The assertion is the author's, not the importer's.
public struct PackageResource: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var type: String
    public var tags: [String]
    public var originalName: String
    /// The file inside the archive (`assets/<id>/<name>`), and its SHA-256.
    public var file: String
    public var fileHash: String
    /// A licence text kept with a font (the OFL text of the "Add font files" card).
    public var licenceFile: String?
    public var licenceFileHash: String?
    /// A `RightsAnswer` word, and its detail.
    public var rights: String?
    public var rightsDetail: String
    /// An open font (its own licence says so): no rights question is asked for it.
    public var openFont: Bool
    public var approvedBy: String?
    public var approvedAt: String?

    public init(id: String, type: String, tags: [String] = [], originalName: String, file: String, fileHash: String, licenceFile: String? = nil, licenceFileHash: String? = nil,
                rights: String? = nil, rightsDetail: String = "", openFont: Bool = false, approvedBy: String? = nil, approvedAt: String? = nil) {
        self.id = id; self.type = type; self.tags = tags; self.originalName = originalName; self.file = file; self.fileHash = fileHash; self.licenceFile = licenceFile; self.licenceFileHash = licenceFileHash
        self.rights = rights; self.rightsDetail = rightsDetail; self.openFont = openFont; self.approvedBy = approvedBy; self.approvedAt = approvedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        originalName = try c.decode(String.self, forKey: .originalName)
        file = try c.decode(String.self, forKey: .file)
        fileHash = try c.decode(String.self, forKey: .fileHash)
        licenceFile = try c.decodeIfPresent(String.self, forKey: .licenceFile)
        licenceFileHash = try c.decodeIfPresent(String.self, forKey: .licenceFileHash)
        rights = try c.decodeIfPresent(String.self, forKey: .rights)
        rightsDetail = try c.decodeIfPresent(String.self, forKey: .rightsDetail) ?? ""
        openFont = try c.decodeIfPresent(Bool.self, forKey: .openFont) ?? false
        approvedBy = try c.decodeIfPresent(String.self, forKey: .approvedBy)
        approvedAt = try c.decodeIfPresent(String.self, forKey: .approvedAt)
    }

    public var rightsAnswer: RightsAnswer? { rights.flatMap { RightsAnswer(rawValue: $0) } }
    /// What the card says of the declared rights.
    public var rightsLine: String {
        if openFont { return "open font licence" }
        guard let a = rightsAnswer else { return "no rights stated" }
        return rightsDetail.isEmpty ? a.rawValue : a.rawValue + ": " + rightsDetail
    }
}

struct PackageResourcesFile: Codable, Equatable { var resources: [PackageResource] }

// MARK: integrity

public enum PackageIntegrity: String, Equatable, Sendable {
    /// The recomputed hash is the one in the manifest.
    case matches
    /// The content reads well but is not what was exported: the hash differs.
    case modified
    /// A file does not match its record or its checksum: the archive was damaged.
    case damaged

    public var title: String {
        switch self { case .matches: return "Matches its hash"; case .modified: return "Modified after export"; case .damaged: return "Damaged" }
    }
    public var detail: String {
        switch self {
        case .matches: return "The content is the one that was exported. A hash proves integrity, not who made it."
        case .modified: return "The content is not what was exported: someone changed it after the export."
        case .damaged: return "A file does not match its checksum: the archive was damaged in transit or on disk."
        }
    }
    /// The user must decide explicitly before the package is kept.
    public var needsDecision: Bool { self != .matches }
}

/// The hash of a package: SHA-256 of the canonical content (the canonical JSON of design.json and resources.json, and the hashes of the files, sorted), with the dates and
/// the hash itself left out, so that a save without a change gives the same hash and the order of keys does not matter.
public enum PackageHash {
    static let dateKeys: Set<String> = ["approvedAt"]

    static func strip(_ v: Any) -> Any {
        if let d = v as? [String: Any] { return d.filter { !dateKeys.contains($0.key) }.mapValues { strip($0) } }
        if let a = v as? [Any] { return a.map { strip($0) } }
        return v
    }

    public static func canonical(_ json: Data) throws -> String {
        let o = try JSONSerialization.jsonObject(with: json, options: [.fragmentsAllowed])
        return String(decoding: try JSONSerialization.data(withJSONObject: strip(o), options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]), as: UTF8.self)
    }

    public static func sha256(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

    /// `files` are the files of `assets/`, by archive path.
    public static func compute(designJSON: Data, resourcesJSON: Data, files: [String: Data]) throws -> String {
        let lines = files.keys.sorted().map { $0 + "=" + sha256(files[$0]!) }
        let text = "design:" + (try canonical(designJSON)) + "\nresources:" + (try canonical(resourcesJSON)) + "\nfiles:\n" + lines.joined(separator: "\n")
        return sha256(Data(text.utf8))
    }
}

// MARK: the package in memory

public struct DesignPackage: Equatable, Sendable {
    public var manifest: PackageManifest
    public var design: PackageDesign
    public var resources: [PackageResource]
    /// The files of `assets/`, by archive path.
    public var files: [String: Data]

    public init(manifest: PackageManifest, design: PackageDesign, resources: [PackageResource], files: [String: Data]) {
        self.manifest = manifest; self.design = design; self.resources = resources; self.files = files
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    public func designJSON() throws -> Data { try Self.encoder().encode(design) }
    public func resourcesJSON() throws -> Data { try Self.encoder().encode(PackageResourcesFile(resources: resources)) }

    /// The hash of what this package holds now.
    public func computeHash() throws -> String { try PackageHash.compute(designJSON: designJSON(), resourcesJSON: resourcesJSON(), files: files) }

    /// Sets the manifest's hash from the content.
    public mutating func seal() throws { manifest.hash = try computeHash() }

    /// The archive: `package.json` first, then `design.json`, `resources.json`, and the files in order. The hash is computed here, so a package is never written with a wrong one.
    public func archiveData() throws -> Data {
        var m = manifest
        m.hash = try computeHash()
        var entries: [(name: String, data: Data)] = [(PackageType.manifestName, try Self.encoder().encode(m)), (PackageType.designName, try designJSON()), (PackageType.resourcesName, try resourcesJSON())]
        for k in files.keys.sorted() { entries.append((k, files[k]!)) }
        return try PackageZip.write(entries)
    }

    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try archiveData().write(to: url, options: .atomic)
    }
}

// MARK: reading and validating

public struct PackageRead: Equatable, Sendable {
    public let package: DesignPackage
    public let integrity: PackageIntegrity
    /// The hash recomputed from what the archive holds.
    public let computedHash: String
    /// What does not add up, in plain words (a file that does not match its record, a checksum that fails).
    public let problems: [String]
    /// The package needs a newer app than this one.
    public let needsNewerApp: Bool
}

public enum PackageReader {
    /// The only kinds of file a package may carry: images, fonts, sounds, video and a licence text. Nothing that runs, nothing nested.
    public static let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "svg", "tif", "tiff", "heic", "ttf", "otf", "woff", "woff2",
                                                        "mp3", "wav", "m4a", "ogg", "flac", "mp4", "mov", "webm", "txt", "md", "pdf"]

    /// The kind of archive a file is, from its first bytes (a disguised name does not hide it), or nil.
    static func archiveKind(_ d: Data) -> String? {
        let b = [UInt8](d.prefix(6))
        if b.count >= 4, b[0] == 0x50, b[1] == 0x4B, b[2] == 0x03 || b[2] == 0x05 || b[2] == 0x07 { return "zip" }
        if b.count >= 2, b[0] == 0x1F, b[1] == 0x8B { return "gzip" }
        if b.count >= 4, b[0] == 0x37, b[1] == 0x7A, b[2] == 0xBC, b[3] == 0xAF { return "7z" }
        if b.count >= 4, b[0] == 0x52, b[1] == 0x61, b[2] == 0x72, b[3] == 0x21 { return "rar" }
        if b.count >= 3, b[0] == 0x42, b[1] == 0x5A, b[2] == 0x68 { return "bzip2" }
        if b.count >= 6, b[0] == 0xFD, b[1] == 0x37, b[2] == 0x7A, b[3] == 0x58, b[4] == 0x5A { return "xz" }
        return nil
    }

    public static func read(_ url: URL, limits: PackageLimits = .standard) throws -> PackageRead {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= limits.maxTotalSize + 1_000_000 else { throw PackageError.tooLarge("the file is larger than a package may be") }
        guard let d = try? Data(contentsOf: url, options: .mappedIfSafe) else { throw PackageError.notAnArchive("the file cannot be read") }
        return try read(d, limits: limits)
    }

    public static func read(_ data: Data, limits: PackageLimits = .standard) throws -> PackageRead {
        let entries = try PackageZip.read(data, limits: limits)
        guard let first = entries.first, first.name == PackageType.manifestName else { throw PackageError.unexpected("this is not a package: its first entry is not package.json") }
        var seenKinds: [String: PackageZip.Entry] = [:]
        var assets: [String: PackageZip.Entry] = [:]
        for e in entries {
            if e.name.hasSuffix("/") { continue }
            if [PackageType.manifestName, PackageType.designName, PackageType.resourcesName].contains(e.name) { seenKinds[e.name] = e; continue }
            guard e.name.hasPrefix(PackageType.assetsFolder) else { throw PackageError.unexpected("the entry \u{201C}\(e.name)\u{201D} is not part of a package") }
            let ext = (e.name as NSString).pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { throw PackageError.unexpected("the file \u{201C}\(e.name)\u{201D} is not a kind of file a package may carry") }
            if let k = archiveKind(e.data) { throw PackageError.unexpected("the file \u{201C}\(e.name)\u{201D} is an archive (\(k)) inside the package: nested archives are refused") }
            assets[e.name] = e
        }
        guard let designE = seenKinds[PackageType.designName], let resourcesE = seenKinds[PackageType.resourcesName] else { throw PackageError.invalid("the package lacks design.json or resources.json") }
        guard let manifest = try? JSONDecoder().decode(PackageManifest.self, from: first.data) else { throw PackageError.invalid("package.json cannot be read") }
        guard manifest.format <= PackageManifest.currentFormat else { throw PackageError.newerFormat("this package was made by a newer version of the app (format \(manifest.format))") }
        guard let design = try? JSONDecoder().decode(PackageDesign.self, from: designE.data) else { throw PackageError.invalid("design.json cannot be read") }
        guard let list = try? JSONDecoder().decode(PackageResourcesFile.self, from: resourcesE.data) else { throw PackageError.invalid("resources.json cannot be read") }
        try validate(manifest, list.resources, assets: assets)

        var problems: [String] = []
        var damaged = false
        for e in entries where !e.crcOK { problems.append("\(e.name) does not match its checksum"); damaged = true }
        for r in list.resources {
            for (path, declared) in [(r.file, r.fileHash)] + (r.licenceFile.map { [($0, r.licenceFileHash ?? "")] } ?? []) {
                guard let e = assets[path] else { continue }
                if PackageHash.sha256(e.data) != declared { problems.append("\(path) is not the file the package describes"); damaged = true }
            }
        }
        let files = assets.mapValues { $0.data }
        let computed = try PackageHash.compute(designJSON: designE.data, resourcesJSON: resourcesE.data, files: files)
        let integrity: PackageIntegrity = damaged ? .damaged : (computed == manifest.hash ? .matches : .modified)
        if integrity == .modified { problems.append("the content hashes to \(String(computed.prefix(8))), not to \(manifest.shortHash)") }
        let pkg = DesignPackage(manifest: manifest, design: design, resources: list.resources, files: files)
        let tooOld = PackageVersion.parse(AppInfo.version) != nil && PackageVersion.compare(AppInfo.version, manifest.appMinVersion) < 0
        return PackageRead(package: pkg, integrity: integrity, computedHash: computed, problems: problems, needsNewerApp: tooOld)
    }

    /// The fields a package must have to be shown and used: nothing in it is trusted.
    static func validate(_ m: PackageManifest, _ resources: [PackageResource], assets: [String: PackageZip.Entry]) throws {
        guard UUID(uuidString: m.id) != nil else { throw PackageError.invalid("the package's id is not valid") }
        guard PackageVersion.isValid(m.version) else { throw PackageError.invalid("the package's version is not a number like 1.0") }
        guard !m.name.trimmingCharacters(in: .whitespaces).isEmpty, m.name.count <= 120 else { throw PackageError.invalid("the package has no usable name") }
        guard m.author.count <= PackageAuthor.limit, !PackageAuthor.looksLikeEmail(m.author) else { throw PackageError.invalid("the author of this package is not a display name") }
        guard m.note.count <= 4000, m.created.count <= 40, m.modified.count <= 40 else { throw PackageError.invalid("package.json holds a value that is too long") }
        var ids = Set<String>()
        var referenced = Set<String>()
        for r in resources {
            guard r.id.range(of: #"^[a-z0-9][a-z0-9-]{0,40}$"#, options: .regularExpression) != nil, ids.insert(r.id).inserted else { throw PackageError.invalid("a resource has an id that is not valid or is repeated") }
            guard r.type.range(of: #"^[a-z]{2,12}$"#, options: .regularExpression) != nil else { throw PackageError.invalid("the resource \(r.id) has a type that is not valid") }
            guard r.file.hasPrefix(PackageType.assetsFolder), assets[r.file] != nil else { throw PackageError.invalid("the file of the resource \(r.id) is not in the package") }
            referenced.insert(r.file)
            if let l = r.licenceFile {
                guard l.hasPrefix(PackageType.assetsFolder), assets[l] != nil else { throw PackageError.invalid("the licence text of the resource \(r.id) is not in the package") }
                referenced.insert(l)
            }
            if let w = r.rights, RightsAnswer(rawValue: w) == nil { throw PackageError.invalid("the resource \(r.id) states rights in words the app does not know") }
            guard r.tags.count <= 30, r.tags.allSatisfy({ $0.count <= 30 }), r.originalName.count <= 200, r.rightsDetail.count <= 2000 else { throw PackageError.invalid("the resource \(r.id) holds a value that is too long") }
        }
        if let stray = assets.keys.sorted().first(where: { !referenced.contains($0) }) { throw PackageError.unexpected("the file \u{201C}\(stray)\u{201D} is in the package but not described by resources.json") }
    }
}
