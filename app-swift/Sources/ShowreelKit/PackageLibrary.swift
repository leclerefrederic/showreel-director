import Foundation

/// The rights confirmation of one version of a package: the user ticked "I confirm I hold the rights to use these resources" for this hash. `by` is a display name, never an e-mail.
public struct PackageConfirmation: Codable, Equatable, Sendable {
    public var confirmed: Bool
    public var date: String
    public var hash: String
    public var by: String?
    public init(confirmed: Bool = true, date: String, hash: String, by: String?) { self.confirmed = confirmed; self.date = date; self.hash = hash; self.by = by }
}

/// One version of a package kept in the library.
public struct LibraryPackage: Identifiable, Equatable, Sendable {
    public var id: String { manifest.id + "@" + manifest.version }
    public let manifest: PackageManifest
    public let archive: URL
    public let confirmation: PackageConfirmation?
    public var isConfirmed: Bool { confirmation?.confirmed == true && confirmation?.hash == manifest.hash }
}

/// The packages the user keeps: `~/Library/Application Support/ShowreelStudio/Packages/<id>/<version>/`, with the archive and the rights confirmation of that version.
/// Never inside the app bundle.
public struct PackageLibrary: Sendable {
    public let root: URL
    public static let archiveName = "package." + PackageType.fileExtension
    static let confirmationName = "confirmation.json"

    public init(root: URL) { self.root = root }

    public static var standard: PackageLibrary {
        PackageLibrary(root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ShowreelStudio/Packages"))
    }

    func folder(_ id: String, _ version: String) -> URL { root.appendingPathComponent(id, isDirectory: true).appendingPathComponent(version, isDirectory: true) }

    static func timestamp(_ d: Date = Date()) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }

    // MARK: reading

    /// Every version of every package, newest version first within a package, packages by name.
    public func list() -> [LibraryPackage] {
        let fm = FileManager.default
        var out: [LibraryPackage] = []
        for id in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] where UUID(uuidString: id) != nil {
            for v in (try? fm.contentsOfDirectory(atPath: root.appendingPathComponent(id).path)) ?? [] where PackageVersion.isValid(v) {
                if let p = entry(id, v) { out.append(p) }
            }
        }
        return out.sorted { a, b in
            if a.manifest.name.lowercased() != b.manifest.name.lowercased() { return a.manifest.name.lowercased() < b.manifest.name.lowercased() }
            return PackageVersion.compare(a.manifest.version, b.manifest.version) > 0
        }
    }

    public func entry(_ id: String, _ version: String) -> LibraryPackage? {
        let dir = folder(id, version), archive = dir.appendingPathComponent(Self.archiveName)
        guard let r = try? PackageReader.read(archive), r.package.manifest.id == id, r.package.manifest.version == version else { return nil }
        let c = (try? Data(contentsOf: dir.appendingPathComponent(Self.confirmationName))).flatMap { try? JSONDecoder().decode(PackageConfirmation.self, from: $0) }
        return LibraryPackage(manifest: r.package.manifest, archive: archive, confirmation: c)
    }

    /// The newest version kept of a package id.
    public func latest(_ id: String) -> LibraryPackage? { list().filter { $0.manifest.id == id }.max { PackageVersion.compare($0.manifest.version, $1.manifest.version) < 0 } }

    /// The package a library entry holds, read and checked again (a file changed on disk since is noticed).
    public func load(_ p: LibraryPackage) throws -> PackageRead { try PackageReader.read(p.archive) }

    // MARK: adding

    /// Keeps a package: one folder per id and version. The same id and version with other content is refused (change the version number); the same content again changes nothing.
    @discardableResult
    public func add(_ pkg: DesignPackage) throws -> LibraryPackage {
        var sealed = pkg
        try sealed.seal()
        let m = sealed.manifest
        guard UUID(uuidString: m.id) != nil, PackageVersion.isValid(m.version) else { throw PackageError.invalid("the package has no valid id or version") }
        if let old = entry(m.id, m.version), old.manifest.hash != m.hash {
            throw PackageError.invalid("version \(m.version) of \u{201C}\(old.manifest.name)\u{201D} is already in the library with other content: give this one a new version number")
        }
        let dir = folder(m.id, m.version)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try sealed.write(to: dir.appendingPathComponent(Self.archiveName))
        guard let e = entry(m.id, m.version) else { throw PackageError.invalid("the package could not be kept") }
        return e
    }

    /// Records the rights confirmation for this version and this hash.
    public func confirm(_ p: LibraryPackage, by: String?, now: Date = Date()) throws {
        let c = PackageConfirmation(date: Self.timestamp(now), hash: p.manifest.hash, by: by.flatMap { try? PackageAuthor.validate($0) })
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try e.encode(c).write(to: folder(p.manifest.id, p.manifest.version).appendingPathComponent(Self.confirmationName), options: .atomic)
    }

    /// What the import card says about an id that is already here: "update 1.2 to 1.3", "already installed", "older than 1.3 which is installed", or nil for a new package.
    public func relation(of m: PackageManifest) -> String? {
        let mine = list().filter { $0.manifest.id == m.id }
        guard let newest = mine.max(by: { PackageVersion.compare($0.manifest.version, $1.manifest.version) < 0 }) else { return nil }
        if mine.contains(where: { $0.manifest.version == m.version }) { return "version \(m.version) is already installed" }
        let c = PackageVersion.compare(m.version, newest.manifest.version)
        return c > 0 ? "update \(newest.manifest.version) to \(m.version)" : "older than \(newest.manifest.version), which is installed"
    }
}
