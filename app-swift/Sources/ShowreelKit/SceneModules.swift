import CryptoKit
import Foundation

/// The scene files of a version (`vN/scenes/S01.js`, one per scene of film.json, assembled into main.js by the skill's `scripts/assemble.py`) and what the app
/// records about them: `.studio/build.json` keeps, per version and per scene, the fingerprint of the inputs the file was generated from and the fingerprint of
/// the file. From that a scene is not generated, up to date or stale. The state is computed here and shown by the interface in a later phase.
public enum SceneModules {
    public static let folder = "scenes"

    public static func url(version: String, scene: String, store: ProjectStore) -> URL {
        store.root.appendingPathComponent("\(version)/\(folder)/\(scene).js")
    }

    /// A version in the scene-file format has a scenes/ folder; one with a main.js only is the older format and is left as it is.
    public static func usesSceneFiles(version: String, store: ProjectStore) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: store.root.appendingPathComponent("\(version)/\(folder)").path, isDirectory: &isDir) && isDir.boolValue
    }

    static func hex(_ d: some Sequence<UInt8>) -> String { d.map { String(format: "%02x", $0) }.joined() }

    /// SHA-256 of the file's bytes (the same value assembly.json holds); nil when the file does not exist or holds only white space.
    public static func moduleHash(version: String, scene: String, store: ProjectStore) -> String? {
        guard let d = try? Data(contentsOf: url(version: version, scene: scene, store: store)),
              !String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return hex(SHA256.hash(data: d))
    }

    /// The fingerprint of what a scene file is generated from: the scene's content and words, its control level, its effective look (its own override or the
    /// project's, and the project's moods and effects pack, which every scene inherits) and its length. Not the review state, not the montage order or the
    /// start, not a transition: changing those never makes a scene stale.
    public static func inputs(of scene: ShowreelFile.Scene, in f: ShowreelFile) -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let content = (try? enc.encode(scene.content)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        let length = f.timeline().first { $0.scene.id == scene.id }?.length ?? scene.duration
        var parts = [scene.id, scene.text, scene.texts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "|"), scene.visual, scene.feeling, content,
                     f.controlLevel(for: scene).rawValue, length.map { String(format: "%.3f", $0) } ?? "-"]
        parts += DecisionKey.allCases.map { "\($0.rawValue)=\(f.effective($0, for: scene))" }
        return hex(SHA256.hash(data: Data(parts.joined(separator: "\u{1}").utf8)).prefix(16))
    }

    // MARK: .studio/build.json

    public struct Record: Codable, Equatable, Sendable {
        public var inputs: String
        public var module: String
    }

    struct Book: Codable {
        var schema = 1
        var versions: [String: [String: Record]] = [:]
    }

    static func bookURL(_ store: ProjectStore) -> URL { store.root.appendingPathComponent(".studio/build.json") }

    static func loadBook(_ store: ProjectStore) -> Book {
        (try? Data(contentsOf: bookURL(store))).flatMap { try? JSONDecoder().decode(Book.self, from: $0) } ?? Book()
    }

    /// What was recorded for a scene of a version at its last generation.
    public static func record(version: String, scene: String, store: ProjectStore) -> Record? { loadBook(store).versions[version]?[scene] }

    /// Records the scenes of a version as generated now, from the project's current inputs and the files as they are. A scene without a file is not recorded.
    public static func recordGeneration(version: String, scenes ids: [String]? = nil, store: ProjectStore) throws {
        guard let f = store.loadShowreel() else { throw AgentError.msg("there is no readable showreel.json") }
        var book = loadBook(store)
        var rows = book.versions[version] ?? [:]
        for s in f.film where ids?.contains(s.id) ?? true {
            guard let m = moduleHash(version: version, scene: s.id, store: store) else { rows[s.id] = nil; continue }
            rows[s.id] = Record(inputs: inputs(of: s, in: f), module: m)
        }
        book.versions[version] = rows
        try FileManager.default.createDirectory(at: bookURL(store).deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try (String(decoding: try enc.encode(book), as: UTF8.self) + "\n").write(to: bookURL(store), atomically: true, encoding: .utf8)
    }

    /// The scenes the assembler could not use (assembly.json, written by scripts/assemble.py at the last build), in film order.
    public static func ungenerated(version: String, store: ProjectStore) -> [String] {
        guard let d = try? Data(contentsOf: store.root.appendingPathComponent("\(version)/assembly.json")),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [] }
        return o["ungenerated"] as? [String] ?? []
    }

    // MARK: the state of a scene

    public enum State: String, Equatable, Sendable {
        /// No usable file for the scene (the assembled film shows a placeholder frame).
        case notGenerated
        /// The file was generated from the scene's present inputs.
        case upToDate
        /// The scene's inputs changed since the file was generated, or nothing records where the file came from.
        case stale
    }

    public struct Status: Equatable, Sendable {
        public let state: State
        /// The file differs from the one that was generated (edited by hand since): it does not make the scene stale, the owner decides.
        public let moduleEdited: Bool
    }

    public static func status(of scene: ShowreelFile.Scene, version: String, in f: ShowreelFile, store: ProjectStore) -> Status {
        guard let m = moduleHash(version: version, scene: scene.id, store: store) else { return Status(state: .notGenerated, moduleEdited: false) }
        guard let r = record(version: version, scene: scene.id, store: store) else { return Status(state: .stale, moduleEdited: false) }
        return Status(state: r.inputs == inputs(of: scene, in: f) ? .upToDate : .stale, moduleEdited: r.module != m)
    }

    /// The state of every scene that is in the film, by ID.
    public static func statuses(version: String, store: ProjectStore) -> [String: Status] {
        guard let f = store.loadShowreel() else { return [:] }
        return Dictionary(uniqueKeysWithValues: f.film.map { ($0.id, status(of: $0, version: version, in: f, store: store)) })
    }
}
