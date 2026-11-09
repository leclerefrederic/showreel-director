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
        /// What the scene's passages (the free instructions of the transitions into and out of it) said when it was generated.
        public var passage: String?
        /// What else the scene was written under: the brief and the music under it (relative to the scene's start). A change makes the scene out of date; a record without it does not.
        public var context: String?
        /// The scene contract (what Clap was told about the engine) at the time. A change is said on the card, never a reason by itself to rewrite.
        public var contract: String?
        /// The file passed its own test with no code error. Nil: not known (a file written before this was recorded).
        public var tested: Bool?
    }

    /// The result of the last build and test of a version: the page exists and the checks were green.
    public struct VersionResult: Codable, Equatable, Sendable { public var ok: Bool }

    /// What the film was assembled from, part by part, at the last assembly of a version.
    public struct FilmRecord: Codable, Equatable, Sendable {
        public var parts: [String: String]
        public var ungenerated: [String]
    }

    struct Book: Codable {
        var schema = 1
        var versions: [String: [String: Record]] = [:]
        var results: [String: VersionResult]?
        var films: [String: FilmRecord]?
        /// Per version: what its frame (project.json, reel.js) was written from.
        var frames: [String: String]?
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
            rows[s.id] = Record(inputs: inputs(of: s, in: f), module: m, passage: passage(of: s, in: f), context: context(of: s, in: f, store: store), contract: contractFingerprint(), tested: rows[s.id]?.module == m ? rows[s.id]?.tested : nil)
        }
        book.versions[version] = rows
        try save(book, store)
    }

    /// Forgets what was recorded about the scenes of a version (after a start over).
    public static func forget(version: String, store: ProjectStore) throws {
        var book = loadBook(store)
        book.versions[version] = nil; book.films?[version] = nil; book.results?[version] = nil
        try save(book, store)
    }

    /// The scene contract as the app gives it to Clap, as a short fingerprint (empty when the skill cannot be found).
    public static func contractFingerprint() -> String {
        guard let sk = Skill.root() else { return "" }
        return hex(SHA256.hash(data: Data((SceneContract.text(skill: sk) + SceneGeneration.system).utf8)).prefix(8))
    }

    /// The brief's free text and the music under the scene, as one fingerprint. The music is taken relative to the scene's start (the tempo, the bars, a drop or a break inside it,
    /// whether it starts on a bar), so that a scene that only moves by a whole bar is not out of date.
    public static func context(of scene: ShowreelFile.Scene, in f: ShowreelFile, store: ProjectStore) -> String {
        let p = f.parameters
        var parts = [p.audience ?? "", p.message ?? "", p.tone ?? "", f.reelLanguages.joined(separator: ",")]
        if f.decisions.track?.file != nil, let a = cachedAnalysis(store), let t = f.timeline().first(where: { $0.scene.id == scene.id }), let st = t.start, let en = t.end {
            func r(_ x: Double) -> String { String(format: "%.1f", x - st) }
            parts.append("bpm \(Int(a.bpm.rounded()))|\(a.gridKind(st) ?? "off")")
            parts.append(a.bars.filter { $0 >= st - MusicAnalysis.tolerance && $0 < en - MusicAnalysis.tolerance }.map(r).joined(separator: ","))
            parts.append(a.dropBars.filter { $0 < a.bars.count && a.bars[$0] >= st && a.bars[$0] < en }.map { r(a.bars[$0]) }.joined(separator: ","))
            parts.append(a.breakdowns.filter { $0.start < en && $0.end > st }.map { r($0.start) + "-" + r($0.end) }.joined(separator: ","))
        }
        return hex(SHA256.hash(data: Data(parts.joined(separator: "\u{1}").utf8)).prefix(8))
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: (stamp: Date, a: MusicAnalysis?)] = [:]
    /// The music analysis of the project, read again only when its file changed (the states of the scenes ask for it often).
    static func cachedAnalysis(_ store: ProjectStore) -> MusicAnalysis? {
        let u = store.root.appendingPathComponent(MusicAnalysis.beatsPath)
        let stamp = ((try? FileManager.default.attributesOfItem(atPath: u.path))?[.modificationDate] as? Date) ?? .distantPast
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let c = cache[u.path], c.stamp == stamp { return c.a }
        let a = MusicAnalysis.load(root: store.root); cache[u.path] = (stamp, a); return a
    }

    /// The file of a scene passed its test (or a version that was built and tested green holds it): it can be reused without being written again.
    public static func markTested(version: String, scene: String, ok: Bool, store: ProjectStore) {
        var book = loadBook(store)
        guard var r = book.versions[version]?[scene] else { return }
        r.tested = ok; book.versions[version]?[scene] = r
        try? save(book, store)
    }

    static func trusted(_ r: Record, version: String, store: ProjectStore) -> Bool { r.tested ?? (loadBook(store).results?[version]?.ok == true) }

    /// A scene file of `version` that a new version may take over: written from the scene's present inputs, not edited by hand, tested with no code error.
    public static func reusable(scene: ShowreelFile.Scene, version: String, in f: ShowreelFile, store: ProjectStore) -> Bool {
        guard let r = record(version: version, scene: scene.id, store: store) else { return false }
        let st = status(of: scene, version: version, in: f, store: store)
        return st.state == .upToDate && !st.moduleEdited && trusted(r, version: version, store: store)
    }

    /// Copies the file of a scene and its record from one version to another, as they are.
    public static func carryOver(scene id: String, from: String, to: String, store: ProjectStore) throws {
        let dst = url(version: to, scene: id, store: store)
        try FileManager.default.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.copyItem(at: url(version: from, scene: id, store: store), to: dst)
        var book = loadBook(store)
        if let r = book.versions[from]?[id] { var rows = book.versions[to] ?? [:]; rows[id] = r; book.versions[to] = rows; try save(book, store) }
    }

    /// What a version's frame (project.json, reel.js) is written from: the project's look, its name, languages, formats, duration, track and the list of scenes.
    public static func frameInputs(_ f: ShowreelFile) -> String {
        var parts = [f.name, f.reelLanguages.joined(separator: ","), (f.decisions.formats ?? []).joined(separator: ","), String(f.decisions.duration ?? 0), f.decisions.track?.file ?? "",
                     f.film.map { $0.id }.joined(separator: ",")]
        parts += DecisionKey.allCases.map { "\($0.rawValue)=\($0.current(f))" }
        return hex(SHA256.hash(data: Data(parts.joined(separator: "\u{1}").utf8)).prefix(8))
    }
    public static func recordFrame(version: String, store: ProjectStore) {
        guard let f = store.loadShowreel() else { return }
        var book = loadBook(store); var m = book.frames ?? [:]; m[version] = frameInputs(f); book.frames = m; try? save(book, store)
    }
    public static func frameRecord(version: String, store: ProjectStore) -> String? { loadBook(store).frames?[version] }
    public static func carryFrame(from: String, to: String, store: ProjectStore) throws {
        let fm = FileManager.default
        for n in ["project.json", "reel.js"] {
            let dst = store.root.appendingPathComponent("\(to)/\(n)"); try? fm.removeItem(at: dst)
            try fm.copyItem(at: store.root.appendingPathComponent("\(from)/\(n)"), to: dst)
        }
        recordFrame(version: to, store: store)
    }

    static func save(_ book: Book, _ store: ProjectStore) throws {
        try FileManager.default.createDirectory(at: bookURL(store).deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try (String(decoding: try enc.encode(book), as: UTF8.self) + "\n").write(to: bookURL(store), atomically: true, encoding: .utf8)
    }

    /// The free instructions of the transitions into and out of a scene, as one fingerprint: what a generation of the scene was told about its passages.
    public static func passage(of scene: ShowreelFile.Scene, in f: ShowreelFile) -> String {
        let tl = f.timeline()
        guard let i = tl.firstIndex(where: { $0.scene.id == scene.id }) else { return "" }
        let into = i > 0 ? (tl[i - 1].item.transition.instruction ?? "") : "", out = i + 1 < tl.count ? (tl[i].item.transition.instruction ?? "") : ""
        return hex(SHA256.hash(data: Data((into + "\u{1}" + out).utf8)).prefix(8))
    }

    // MARK: the film as a whole

    /// The parts the assembled film depends on: the montage (order, lengths, transitions), the music, and for each scene its inputs and its file.
    public static func filmParts(_ f: ShowreelFile, version: String, store: ProjectStore) -> [String: String] {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let music = (try? enc.encode(f.decisions.track)).map { String(decoding: $0, as: UTF8.self) } ?? "none"
        var parts = ["montage": hex(SHA256.hash(data: Data(Film.text(f).utf8)).prefix(8)), "music": hex(SHA256.hash(data: Data(music.utf8)).prefix(8)),
                     "fonts": hex(SHA256.hash(data: Data(FontEmbedding.fingerprint(store).utf8)).prefix(8))]
        for s in f.film { parts[s.id] = inputs(of: s, in: f) + "|" + (moduleHash(version: version, scene: s.id, store: store).map { String($0.prefix(16)) } ?? "-") }
        return parts
    }

    public static func recordAssembly(version: String, store: ProjectStore) throws {
        guard let f = store.loadShowreel() else { return }
        var book = loadBook(store)
        var films = book.films ?? [:]
        films[version] = FilmRecord(parts: filmParts(f, version: version, store: store), ungenerated: f.film.filter { moduleHash(version: version, scene: $0.id, store: store) == nil }.map { $0.id })
        book.films = films
        try save(book, store)
    }

    public static func recordResult(version: String, ok: Bool, store: ProjectStore) throws {
        var book = loadBook(store)
        var r = book.results ?? [:]; r[version] = VersionResult(ok: ok); book.results = r
        try save(book, store)
    }

    public static func result(version: String, store: ProjectStore) -> VersionResult? { loadBook(store).results?[version] }
    public static func filmRecord(version: String, store: ProjectStore) -> FilmRecord? { loadBook(store).films?[version] }

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
        let same = r.inputs == inputs(of: scene, in: f) && (r.context == nil || r.context == context(of: scene, in: f, store: store))
        return Status(state: same ? .upToDate : .stale, moduleEdited: r.module != m)
    }

    /// The state of every scene that is in the film, by ID.
    public static func statuses(version: String, store: ProjectStore) -> [String: Status] {
        guard let f = store.loadShowreel() else { return [:] }
        return Dictionary(uniqueKeysWithValues: f.film.map { ($0.id, status(of: $0, version: version, in: f, store: store)) })
    }
}
