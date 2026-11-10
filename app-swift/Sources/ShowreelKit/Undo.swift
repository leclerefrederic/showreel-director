import Foundation

/// One step of the undo stack: what a typed operation (or a group of them) changed, with the values from before and after.
/// The two data files an operation writes are kept whole (`showreel.json` and the manifest); files it adds to or removes from the
/// resources folders are kept by name, with their bytes when they are removed.
struct UndoEntry {
    let title: String
    let before: [String: String?]
    let after: [String: String?]
    /// Files the operation added (relative to the project); undoing deletes them, redoing writes them back from `kept`.
    let created: [String]
    /// Files the operation deleted, with their bytes; undoing writes them back.
    let removed: [String: Data]
    var kept: [String: Data] = [:]
    /// The journal lines of the operations this step holds: an undo or a redo of the step is journalled against each of them.
    var journal: [JournalEntry] = []
    /// What the step edited and when (AS1): two steps of the same key closer than `EditSession.undoWindow` are one.
    var key: String? = nil
    var at = Date.distantPast
}

/// The undo and redo stacks of one project. In memory only: closing the project forgets them.
public final class UndoLog {
    public static let limit = 100
    /// The copilot applies operations off the main thread while the window reads the stack: every access takes this lock, and an operation
    /// holds it from start to end, so two never interleave.
    let lock = NSRecursiveLock()
    private var _undos: [UndoEntry] = []
    private var _redos: [UndoEntry] = []
    var undos: [UndoEntry] { get { lock.lock(); defer { lock.unlock() }; return _undos } set { lock.lock(); _undos = newValue; lock.unlock() } }
    var redos: [UndoEntry] { get { lock.lock(); defer { lock.unlock() }; return _redos } set { lock.lock(); _redos = newValue; lock.unlock() } }
    /// Greater than 0 while a transaction runs: the operations inside belong to its single entry.
    var depth = 0
    private var pending: [JournalEntry] = []
    func note(_ e: JournalEntry) { lock.lock(); pending.append(e); lock.unlock() }
    func resetPending() { lock.lock(); pending = []; lock.unlock() }
    func takePending() -> [JournalEntry] { lock.lock(); defer { lock.unlock() }; let p = pending; pending = []; return p }

    public var undoTitle: String? { undos.last?.title }
    public var redoTitle: String? { redos.last?.title }
    public var canUndo: Bool { !undos.isEmpty }
    public var canRedo: Bool { !redos.isEmpty }
    public var undoCount: Int { undos.count }

    public func clear() { lock.lock(); _undos = []; _redos = []; lock.unlock() }

    func popUndo() -> UndoEntry { lock.lock(); defer { lock.unlock() }; return _undos.removeLast() }
    func popRedo() -> UndoEntry { lock.lock(); defer { lock.unlock() }; return _redos.removeLast() }
    func pushUndo(_ e: UndoEntry) { lock.lock(); _undos.append(e); lock.unlock() }
    func pushRedo(_ e: UndoEntry) { lock.lock(); _redos.append(e); lock.unlock() }

    func push(_ e: UndoEntry) {
        lock.lock(); defer { lock.unlock() }
        _undos.append(e); _redos = []
        if _undos.count > Self.limit { _undos.removeFirst(_undos.count - Self.limit) }
    }
}

private struct Capture {
    var texts: [String: String?] = [:]
    var listing: [String: Set<String>] = [:]
    var blobs: [String: Data] = [:]
}

extension ProjectStore {
    static let undoTexts = [ShowreelFile.fileName, Assets.manifestPath]
    static let undoDirs = ["assets/source", "assets/prepared", "assets/fonts"]

    private func capture(keeping files: [String]) -> Capture {
        var c = Capture()
        for rel in Self.undoTexts { c.texts[rel] = read(rel) }
        for d in Self.undoDirs {
            // every file under the folder, by its path inside it (a font goes in assets/fonts/<family>/<file>)
            var names: [String] = []
            if let en = FileManager.default.enumerator(atPath: root.appendingPathComponent(d).path) {
                for case let n as String in en where !n.split(separator: "/").contains(where: { $0.hasPrefix(".") }) {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: root.appendingPathComponent(d).appendingPathComponent(n).path, isDirectory: &isDir), !isDir.boolValue { names.append(n) }
                }
            }
            c.listing[d] = Set(names)
        }
        for rel in files { if let u = try? resolve(rel), let d = try? Data(contentsOf: u) { c.blobs[rel] = d } }
        return c
    }

    /// Runs `body` and, when it changed the project, records one undo step called `title`. Inside a transaction nothing is recorded
    /// on its own. A body that fails half way still leaves a step for what it did change, so the user can take it back.
    func recording<T>(_ title: String, backup: [String] = [], _ body: () throws -> T) throws -> T {
        undoLog.lock.lock(); defer { undoLog.lock.unlock() }
        if undoLog.depth > 0 { return try body() }
        undoLog.resetPending()
        let start = capture(keeping: backup)
        undoLog.depth += 1
        var result: T?, failure: Error?
        do { result = try body() } catch { failure = error }
        undoLog.depth -= 1
        let end = capture(keeping: [])
        var created: [String] = [], removed: [String: Data] = [:]
        for d in Self.undoDirs {
            for n in (end.listing[d] ?? []).subtracting(start.listing[d] ?? []) { created.append(d + "/" + n) }
            for n in (start.listing[d] ?? []).subtracting(end.listing[d] ?? []) { if let data = start.blobs[d + "/" + n] { removed[d + "/" + n] = data } }
        }
        let changed = start.texts.contains { end.texts[$0.key] ?? nil != $0.value } || !created.isEmpty || !removed.isEmpty
        let notes = undoLog.takePending()
        if changed { var u = UndoEntry(title: title, before: start.texts, after: end.texts, created: created.sorted(), removed: removed); u.journal = notes; undoLog.push(u) }
        if let e = failure { throw e }
        return result!
    }

    /// Several operations that the user sees as one action (duplicating a scene, dropping a file on a scene): one undo step.
    public func transaction<T>(_ title: String, _ body: () throws -> T) throws -> T { if let e = buildRefusal() { throw e }; return try recording(title, body) }

    /// After a form field committed: marks the step just recorded as an edit of `key`, and folds it into the step before when that one edited the same key a moment ago, so Undo takes
    /// back what was typed in the field and not each commit. Nothing happens when the commit recorded no step.
    public func coalesceLast(key: String, now: Date = Date(), window: TimeInterval = EditSession.undoWindow) {
        undoLog.lock.lock(); defer { undoLog.lock.unlock() }
        var u = undoLog.undos
        guard var last = u.last else { return }
        guard last.key == nil else { return }            // already marked: the same step, not a new one
        last.key = key; last.at = now
        if u.count >= 2, let prev = Optional(u[u.count - 2]), prev.key == key, now.timeIntervalSince(prev.at) <= window {
            var merged = UndoEntry(title: prev.title, before: prev.before, after: last.after, created: prev.created, removed: prev.removed)
            merged.kept = prev.kept; merged.journal = prev.journal + last.journal; merged.key = key; merged.at = now
            u.removeLast(2); u.append(merged)
        } else { u[u.count - 1] = last }
        undoLog.undos = u
    }

    // MARK: undo and redo

    private func current() -> [String: String?] { Dictionary(uniqueKeysWithValues: Self.undoTexts.map { ($0, read($0)) }) }

    private func same(_ a: [String: String?], _ b: [String: String?]) -> Bool {
        Self.undoTexts.allSatisfy { (a[$0] ?? nil) == (b[$0] ?? nil) }
    }

    /// False when the data files are not what the last undo or redo step expects: something outside the app changed them.
    public func undoIsValid() -> Bool {
        guard let expected = undoLog.redos.last?.before ?? undoLog.undos.last?.after else { return true }
        return same(current(), expected)
    }

    /// Forgets the stacks when a file was changed outside the app (an editor, the copilot's file tools, a script). Returns whether it did.
    @discardableResult
    public func dropUndoIfStale() -> Bool {
        undoLog.lock.lock(); defer { undoLog.lock.unlock() }
        guard !undoIsValid() else { return false }
        undoLog.clear()
        return true
    }

    private func writeTexts(_ t: [String: String?]) throws {
        for rel in Self.undoTexts {
            let v = t[rel] ?? nil
            if let text = v { try write(rel, text, source: .restore) }
            else if let u = try? resolve(rel), FileManager.default.fileExists(atPath: u.path) {
                try FileManager.default.removeItem(at: u)
                if rel == ShowreelFile.fileName || rel == Assets.manifestPath { DocSync.sync(self) }
            }
        }
    }

    /// Puts back what the last step changed. Returns its title.
    @discardableResult
    public func undo() throws -> String {
        if let e = buildRefusal() { throw e }
        undoLog.lock.lock(); defer { undoLog.lock.unlock() }
        guard !undoLog.undos.isEmpty else { throw AgentError.msg("nothing to undo") }
        if dropUndoIfStale() { throw AgentError.msg("undo is not available: the project's data was changed outside the app") }
        var e = undoLog.popUndo()
        let fm = FileManager.default
        for rel in e.created { if let u = try? resolve(rel) { if let d = try? Data(contentsOf: u) { e.kept[rel] = d }; try? fm.removeItem(at: u); Self.removeEmptyParents(of: u, below: root, fm) } }
        for (rel, data) in e.removed { let u = try resolve(rel); try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true); try data.write(to: u) }
        try writeTexts(e.before)
        undoLog.pushRedo(e)
        for j in e.journal { journal.append(j.derived("undone", author: "user", session: sessionID, swap: true)) }
        return e.title
    }

    /// Does again what the last undo took back. Returns its title.
    @discardableResult
    public func redo() throws -> String {
        if let e = buildRefusal() { throw e }
        undoLog.lock.lock(); defer { undoLog.lock.unlock() }
        guard !undoLog.redos.isEmpty else { throw AgentError.msg("nothing to redo") }
        if dropUndoIfStale() { throw AgentError.msg("redo is not available: the project's data was changed outside the app") }
        let e = undoLog.popRedo()
        let fm = FileManager.default
        for (rel, data) in e.kept { let u = try resolve(rel); try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true); try data.write(to: u) }
        for rel in e.removed.keys { if let u = try? resolve(rel) { try? fm.removeItem(at: u) } }
        try writeTexts(e.after)
        undoLog.pushUndo(e)
        for j in e.journal { journal.append(j.derived("redone", author: "user", session: sessionID, swap: false)) }
        return e.title
    }
}

extension ProjectStore {
    /// After a file was taken away, the folders it leaves empty go too, up to the assets folder.
    static func removeEmptyParents(of file: URL, below root: URL, _ fm: FileManager) {
        var dir = file.deletingLastPathComponent()
        let stop = root.appendingPathComponent("assets").standardizedFileURL.path
        while dir.standardizedFileURL.path.hasPrefix(stop + "/"), dir.standardizedFileURL.path != stop {
            let left = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0 != ".DS_Store" }
            guard left.isEmpty, (try? fm.removeItem(at: dir)) != nil else { break }
            let parent = dir.deletingLastPathComponent()
            if parent.lastPathComponent == "assets" { break }
            dir = parent
        }
    }
}
