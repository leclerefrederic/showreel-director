import Foundation

/// What "Update project" will do, listed before it does anything.
public struct UpdatePlan: Equatable, Sendable {
    public let from: Int
    public let to: Int
    public let changes: [String]
    /// The files the backup keeps (the ones that exist now).
    public let backupFiles: [String]
}

/// A copy of the project's data files, made before an update or a restore.
public struct ProjectBackup: Identifiable, Equatable, Sendable {
    public let id: String                 // the folder's name: <date>-rev<N>
    public let url: URL
    public let date: Date?
    public let revision: Int
    public let files: [String]            // kept, relative to the project
    public let absent: [String]           // tracked files that did not exist then (a restore removes them again)
}

/// The revisions of showreel.json and the way a project is brought to the current one: nothing is written when a project opens; "Update project" lists the
/// changes, backs the data up, migrates, rebuilds what is derived and writes the new revision. "Restore backup" puts a copy back, byte for byte.
public enum ProjectFormat {
    public static var current: Int { ShowreelFile.currentRevision }

    /// The data files an update touches or may touch, and a backup keeps: showreel.json, the generated documents, the manifest and the record of what
    /// the app last generated.
    public static let tracked: [String] = [ShowreelFile.fileName] + ProjectDocs.files + [Assets.manifestPath, DocSync.recordPath]

    public static func revision(of store: ProjectStore) -> Int? { store.loadShowreel()?.revision }

    /// An older revision than the app's. A project with no readable showreel.json is not outdated: it is something else (to import, or broken).
    public static func isOutdated(_ store: ProjectStore) -> Bool { store.loadShowreel().map { $0.isOutdated } ?? false }

    private static func ids(_ a: [String]) -> String { a.count > 4 ? a.prefix(4).joined(separator: ", ") + " and \(a.count - 4) more" : a.joined(separator: ", ") }

    /// What the update would change, from the file as it is on disk. nil when there is nothing to update (already current, or nothing readable).
    public static func plan(_ store: ProjectStore) -> UpdatePlan? {
        guard let text = store.read(ShowreelFile.fileName), let f = try? ShowreelFile.decode(text), f.isOutdated else { return nil }
        let raw = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] ?? [:]
        var changes: [String] = []
        if raw["scenes"] is [String: Any] { changes.append("The review states of phase A become scenes of a scene library") }
        if raw["storyboards"] == nil, !f.scenes.isEmpty {
            changes.append("\(f.scenes.count) scene\(f.scenes.count == 1 ? "" : "s") move into a scene library with one montage (\(f.storyboards.first?.name ?? "Master")), in their order; a scene that was ditched is archived and off")
        }
        let rawScenes = raw["scenes"] as? [[String: Any]] ?? []
        let noContent = rawScenes.filter { $0["content"] == nil && !(($0["text"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.compactMap { $0["id"] as? String }
        if !noContent.isEmpty { changes.append("The words of \(ids(noContent)) become the first element of the scene (colour and animation stay auto)") }
        let legacy = rawScenes.filter { $0["duration"] == nil && ($0["start"] != nil && $0["end"] != nil) }.compactMap { $0["id"] as? String }
        if !legacy.isEmpty { changes.append("\(ids(legacy)): the length is taken from the old start and end (a start that differs from the order is kept)") }
        for (scene, asset, _) in Composition.gaps(f, Assets.load(store)) { changes.append("\(asset.name) becomes an element of \(f.scenes[scene].id)") }
        if f.origin?.tool != "studio" { changes.append("The app becomes the owner of showreel.json (the skill's export will no longer overwrite it)") }
        changes.append("Format revision \(f.revision) \u{2192} \(current)" + (changes.isEmpty ? " (nothing else changes)" : ""))
        return UpdatePlan(from: f.revision, to: current, changes: changes, backupFiles: tracked.filter { store.read($0) != nil })
    }

    // MARK: backups

    private static var backupsDir: String { ProjectStore.studioDir + "/backups" }

    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: d)
    }

    /// Copies the tracked files into `.studio/backups/<date>-rev<N>/` with a small record of what was kept and what did not exist. Verified byte for byte.
    @discardableResult
    static func backup(_ store: ProjectStore, revision: Int, now: Date) throws -> ProjectBackup {
        let fm = FileManager.default
        var name = "\(stamp(now))-rev\(revision)", n = 1
        let parent = store.root.appendingPathComponent(backupsDir)
        while fm.fileExists(atPath: parent.appendingPathComponent(name).path) { n += 1; name = "\(stamp(now))-rev\(revision)-\(n)" }
        let dir = parent.appendingPathComponent(name)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var kept: [String] = [], absent: [String] = []
        for rel in tracked {
            let src = store.root.appendingPathComponent(rel)
            guard fm.fileExists(atPath: src.path) else { absent.append(rel); continue }
            let dst = dir.appendingPathComponent(rel)
            try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: src, to: dst)
            guard try Data(contentsOf: src) == Data(contentsOf: dst) else { throw AgentError.msg("the backup of \(rel) does not match the file: nothing was changed") }
            kept.append(rel)
        }
        let record: [String: Any] = ["revision": revision, "files": kept, "absent": absent, "date": ISO8601DateFormatter().string(from: now)]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: dir.appendingPathComponent("backup.json"))
        return ProjectBackup(id: name, url: dir, date: now, revision: revision, files: kept, absent: absent)
    }

    /// The backups of a project, newest first.
    public static func backups(_ store: ProjectStore) -> [ProjectBackup] {
        let parent = store.root.appendingPathComponent(backupsDir)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
        return names.sorted(by: >).compactMap { n in
            let dir = parent.appendingPathComponent(n)
            guard let d = try? Data(contentsOf: dir.appendingPathComponent("backup.json")), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return nil }
            return ProjectBackup(id: n, url: dir, date: (o["date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }, revision: o["revision"] as? Int ?? 0,
                                 files: o["files"] as? [String] ?? [], absent: o["absent"] as? [String] ?? [])
        }
    }

    // MARK: update and restore

    /// Backs up, migrates and writes the current revision. Throws (and has changed nothing) when the file cannot be read, is current already, or the backup fails.
    @discardableResult
    public static func update(_ store: ProjectStore, now: Date = Date()) throws -> (backup: ProjectBackup, plan: UpdatePlan) {
        guard let text = store.read(ShowreelFile.fileName) else { throw AgentError.msg("there is no showreel.json to update") }
        guard var f = try? ShowreelFile.decode(text) else { throw AgentError.msg("showreel.json cannot be read: it was left as it is") }
        guard let plan = plan(store) else { throw AgentError.msg("this project is already at revision \(current)") }
        let b = try backup(store, revision: f.revision, now: now)          // first: nothing below runs if the copy fails
        Composition.complete(&f, Assets.load(store))
        f.formatRevision = current
        try store.save(f)                                                    // the generated documents and their record follow
        store.undoLog.clear()
        return (b, plan)
    }

    /// Puts a backup back, file by file, byte for byte; a file that did not exist then is removed. The state it replaces is backed up first.
    public static func restore(_ store: ProjectStore, _ b: ProjectBackup, now: Date = Date()) throws {
        let fm = FileManager.default
        for rel in b.files where !fm.fileExists(atPath: b.url.appendingPathComponent(rel).path) { throw AgentError.msg("the backup is incomplete (\(rel) is missing): nothing was changed") }
        try backup(store, revision: revision(of: store) ?? 0, now: now)    // the way back from the restore
        for rel in b.files {
            let dst = try store.resolve(rel)
            try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(contentsOf: b.url.appendingPathComponent(rel)).write(to: dst, options: .atomic)
        }
        for rel in b.absent { if let u = try? store.resolve(rel), fm.fileExists(atPath: u.path) { try fm.removeItem(at: u) } }
        store.undoLog.clear()
    }
}
