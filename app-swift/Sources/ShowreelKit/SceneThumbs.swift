import CryptoKit
import Foundation

/// The thumbnail of a scene (W4b): a PNG captured from the real rendering of the scene, that is the built film at one instant of that scene. The files are a cache in the project's
/// hidden `.studio/scene-thumbs/`; they never change the film. This is the pure part (keys, states, storage, queue); the capture itself is the app's web view.
public enum SceneThumbs {
    public static let folder = ".studio/scene-thumbs"
    /// Seconds of quiet after a change before a capture starts: edits are coalesced.
    public static let quietDelay = 1.5

    /// What a capture records: which scene file it shows (its hash) and what that file was generated from, so that the state is derived and never guessed.
    public struct Entry: Codable, Equatable, Sendable {
        public var file: String
        public var module: String
        public var inputs: String
        public var instant: Double
        public var version: String
    }
    public struct Failure: Codable, Equatable, Sendable { public var module: String; public var reason: String }
    struct Book: Codable { var entries: [String: Entry] = [:]; var failed: [String: Failure] = [:] }

    public enum State: Equatable, Sendable {
        /// No picture: why, and how to get one.
        case placeholder(reason: String)
        /// The picture shows the scene as it is built now.
        case fresh(URL)
        /// A picture of an older state of the scene: what changed, and the way to update it.
        case stale(URL, why: String, needsBuild: Bool)
        /// The last capture failed, with its reason.
        case failed(reason: String)

        public var url: URL? { switch self { case .fresh(let u), .stale(let u, _, _): return u; default: return nil } }
    }

    /// One capture to make: the scene's own instant, placed in the film.
    public struct Job: Equatable, Sendable {
        public let scene: String
        public let version: String
        /// Seconds from the start of the film.
        public let time: Double
        public let instant: Double
        public let module: String
        public let inputs: String
    }

    // MARK: files

    static func dir(_ store: ProjectStore) -> URL { store.root.appendingPathComponent(folder) }
    static func bookURL(_ store: ProjectStore) -> URL { dir(store).appendingPathComponent("index.json") }
    static func loadBook(_ store: ProjectStore) -> Book { (try? Data(contentsOf: bookURL(store))).flatMap { try? JSONDecoder().decode(Book.self, from: $0) } ?? Book() }

    static func saveBook(_ b: Book, _ store: ProjectStore) throws {
        try FileManager.default.createDirectory(at: dir(store), withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        try enc.encode(b).write(to: bookURL(store), options: .atomic)
    }

    /// The file of an entry, only ever inside the folder (a name with a path in it is refused).
    static func url(_ e: Entry, _ store: ProjectStore) -> URL? {
        guard !e.file.isEmpty, e.file == (e.file as NSString).lastPathComponent, e.file.hasSuffix(".png") else { return nil }
        return dir(store).appendingPathComponent(e.file)
    }

    // MARK: the instant and the job

    /// The representative instant of a scene, in seconds from its start: the one the content gives (`ContentTiming.stillTime`), kept inside the scene.
    public static func instant(of scene: ShowreelFile.Scene) -> Double {
        let t = ContentTiming.stillTime(of: scene)
        guard let d = scene.duration, d > 0 else { return max(0, t) }
        return min(max(0, t), max(0, d - 0.1))
    }

    /// The capture to make for a scene of the film, or nil when there is nothing to capture (not in the film, no file).
    public static func job(for id: String, in f: ShowreelFile, version: String, store: ProjectStore) -> Job? {
        guard let t = f.timeline().first(where: { $0.scene.id == id }), let start = t.start,
              let module = SceneModules.moduleHash(version: version, scene: id, store: store) else { return nil }
        let inst = instant(of: t.scene)
        return Job(scene: id, version: version, time: start + inst, instant: inst, module: module, inputs: SceneModules.inputs(of: t.scene, in: f))
    }

    // MARK: states

    /// The state of every scene of the film, from the data (one read of the index).
    public static func states(in f: ShowreelFile, version: String?, store: ProjectStore) -> [String: State] {
        let book = loadBook(store)
        return Dictionary(uniqueKeysWithValues: f.film.map { ($0.id, state(of: $0, in: f, version: version, store: store, book: book)) })
    }

    public static func state(of scene: ShowreelFile.Scene, in f: ShowreelFile, version: String?, store: ProjectStore) -> State {
        state(of: scene, in: f, version: version, store: store, book: loadBook(store))
    }

    static func state(of scene: ShowreelFile.Scene, in f: ShowreelFile, version: String?, store: ProjectStore, book: Book) -> State {
        guard let v = version else { return .placeholder(reason: "No film is built yet. Build the film to get the real picture of this scene.") }
        guard let module = SceneModules.moduleHash(version: v, scene: scene.id, store: store) else {
            return .placeholder(reason: "This scene is not written yet. Build the film to write it and get its picture.")
        }
        if let fail = book.failed[scene.id], fail.module == module { return .failed(reason: fail.reason) }
        guard let e = book.entries[scene.id], let u = url(e, store), FileManager.default.fileExists(atPath: u.path) else {
            return .placeholder(reason: "The picture of this scene has not been captured yet. Use Refresh thumbnail.")
        }
        if e.module != module { return .stale(u, why: "The film was built again since this picture was taken.", needsBuild: false) }
        if SceneModules.status(of: scene, version: v, in: f, store: store).state != .upToDate {
            return .stale(u, why: "The scene changed after the last build. Build the film to update its picture.", needsBuild: true)
        }
        return .fresh(u)
    }

    /// The scenes whose picture a capture can bring up to date: no picture, or the film was built again since (a scene changed after the build cannot be captured as it is now).
    public static func capturable(in f: ShowreelFile, version: String?, store: ProjectStore) -> [String] {
        guard let v = version else { return [] }
        let book = loadBook(store)
        return f.film.compactMap { s in
            guard let module = SceneModules.moduleHash(version: v, scene: s.id, store: store) else { return nil }
            if let fail = book.failed[s.id], fail.module == module { return nil }
            guard let e = book.entries[s.id], let u = url(e, store), FileManager.default.fileExists(atPath: u.path) else { return s.id }
            return e.module == module && e.instant == instant(of: s) ? nil : s.id
        }
    }

    // MARK: refreshing

    /// Whether "Refresh thumbnail" can do something now, and if not, why and how to get it back.
    public static func refreshAvailability(_ state: State?, activity: ProjectActivity.Snapshot) -> Availability {
        if activity.build != nil {
            return .unavailable(Unavailable(.building, reason: "A build is running", way: "The thumbnails refresh when it ends", link: .build))
        }
        switch state {
        case .placeholder(let r)? where r.hasPrefix("No film") || r.hasPrefix("This scene is not written"):
            return .unavailable(Unavailable(.notAssembled, reason: "There is no film of this scene to capture", way: "Build the film first", link: .build))
        case .stale(_, let why, true)?:
            return .unavailable(Unavailable(.notAssembled, reason: "The picture can only change after a build: " + why.lowercased().prefix(1) + why.dropFirst(), way: "Build the film", link: .build))
        case .fresh?:
            return .unavailable(Unavailable(.busy, reason: "The picture is up to date", way: "It refreshes by itself when the scene or the film changes"))
        default: return .available
        }
    }

    // MARK: recording

    /// Stores the PNG of a capture and forgets the file it replaces. The name carries a hash of what the picture shows.
    @discardableResult
    public static func record(_ job: Job, png: Data, store: ProjectStore) throws -> URL {
        var book = loadBook(store)
        let key = SHA256.hash(data: Data([job.scene, job.module, job.inputs, String(format: "%.3f", job.instant)].joined(separator: "\u{1}").utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
        let e = Entry(file: "\(job.scene)-\(key).png", module: job.module, inputs: job.inputs, instant: job.instant, version: job.version)
        guard let u = url(e, store) else { throw NSError(domain: "SceneThumbs", code: 1, userInfo: [NSLocalizedDescriptionKey: "A thumbnail path must stay inside \(folder)."]) }
        try FileManager.default.createDirectory(at: dir(store), withIntermediateDirectories: true)
        try png.write(to: u, options: .atomic)
        if let old = book.entries[job.scene], old.file != e.file, let ou = url(old, store) { try? FileManager.default.removeItem(at: ou) }
        book.entries[job.scene] = e; book.failed[job.scene] = nil
        try saveBook(book, store)
        return u
    }

    /// A capture that failed: the placeholder shows the reason until the scene file changes.
    public static func recordFailure(_ job: Job, reason: String, store: ProjectStore) {
        var book = loadBook(store)
        book.failed[job.scene] = Failure(module: job.module, reason: reason)
        try? saveBook(book, store)
    }

    /// Deletes the files of scenes that no longer exist in the project and any PNG that no entry points to. Returns how many files went.
    @discardableResult
    public static func cleanOrphans(in f: ShowreelFile, store: ProjectStore) -> Int {
        var book = loadBook(store); let before = book.entries.count + book.failed.count
        let ids = Set(f.scenes.map { $0.id })
        for k in book.entries.keys where !ids.contains(k) { book.entries[k] = nil }
        for k in book.failed.keys where !ids.contains(k) { book.failed[k] = nil }
        let kept = Set(book.entries.values.map { $0.file })
        var n = 0
        for name in (try? FileManager.default.contentsOfDirectory(atPath: dir(store).path)) ?? [] where name.hasSuffix(".png") && !kept.contains(name) {
            if (try? FileManager.default.removeItem(at: dir(store).appendingPathComponent(name))) != nil { n += 1 }
        }
        if book.entries.count + book.failed.count != before { try? saveBook(book, store) }
        return n
    }

    /// The disk the pictures take, in bytes.
    public static func size(_ store: ProjectStore) -> Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir(store).path)) ?? []).reduce(0) {
            $0 + ((try? FileManager.default.attributesOfItem(atPath: dir(store).appendingPathComponent($1).path)[.size] as? Int) ?? 0)
        }
    }

    /// The journal line of a refresh: it changes no scene, only the pictures.
    public static func note(_ store: ProjectStore, scenes: [String], by: String) {
        store.noteEvent(author: "app", op: "thumbnails", target: scenes.count == 1 ? scenes[0] : "\(scenes.count) scenes", title: scenes.count == 1 ? "Refresh the thumbnail of \(scenes[0])" : "Refresh \(scenes.count) thumbnails",
                        before: "the pictures of the last build", after: "the pictures of the film as built now", note: "asked by \(by)")
    }
}

/// The captures waiting to be made: one at a time, in order, each scene at most once, cancellable. Pure; the app runs it.
public struct SceneThumbQueue: Equatable, Sendable {
    public private(set) var pending: [String] = []
    public private(set) var running: String?
    public init() {}

    public mutating func enqueue(_ ids: [String]) { for id in ids where id != running && !pending.contains(id) { pending.append(id) } }
    /// The next scene to capture, or nil while one runs or nothing waits.
    public mutating func next() -> String? {
        guard running == nil, !pending.isEmpty else { return nil }
        running = pending.removeFirst(); return running
    }
    public mutating func finish() { running = nil }
    /// Takes one scene (or all, nil) out of the queue; a running capture is left to finish and its result is dropped by the caller.
    public mutating func cancel(_ id: String? = nil) { if let id = id { pending.removeAll { $0 == id } } else { pending = [] } }
    public var isIdle: Bool { running == nil && pending.isEmpty }
}
