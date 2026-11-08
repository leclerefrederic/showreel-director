import Foundation

/// One line of the chat history of a project.
public struct ChatRecord: Codable, Equatable {
    public var role: String   // "user" or "assistant"
    public var text: String
    public var date: Date
    public init(role: String, text: String, date: Date = Date()) { self.role = role; self.text = text; self.date = date }
}

/// Chat history of a project: `.studio/chat/<session>.jsonl`, one session per file, one record per line.
public final class ChatStore {
    private let dir: URL
    public private(set) var session: URL

    public init(root: URL) {
        dir = root.appendingPathComponent(ProjectStore.studioDir).appendingPathComponent("chat")
        session = ChatStore.latest(in: dir) ?? ChatStore.newURL(in: dir)
    }

    /// A session file name made from the time, always after `after` (the latest session, on disk or not yet written),
    /// so sessions sort by name even when two start within the same millisecond.
    private static func newURL(in dir: URL, after: String = "") -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let last = max(latest(in: dir)?.lastPathComponent ?? "", after)
        var d = Date()
        var name: String
        repeat { name = f.string(from: d) + ".jsonl"; d = d.addingTimeInterval(0.001) } while name <= last
        return dir.appendingPathComponent(name)
    }

    private static func latest(in dir: URL) -> URL? {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".jsonl") }
        return names.sorted().last.map { dir.appendingPathComponent($0) }
    }

    /// Starts a new session. The file appears with the first record.
    public func startNewSession() { session = ChatStore.newURL(in: dir, after: session.lastPathComponent) }

    public var sessions: [URL] {
        (((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".jsonl") }).sorted()
            .map { dir.appendingPathComponent($0) }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()

    public func append(_ r: ChatRecord) {
        guard var line = try? Self.encoder.encode(r) else { return }
        line.append(0x0A)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: session) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: line)
        } else {
            try? line.write(to: session, options: .atomic)
        }
    }

    /// The records of any session of a project (the transcripts stay consultable), by the session's name.
    public static func records(root: URL, session id: String) -> [ChatRecord] {
        let u = root.appendingPathComponent(ProjectStore.studioDir).appendingPathComponent("chat").appendingPathComponent(id + ".jsonl")
        guard let t = try? String(contentsOf: u, encoding: .utf8) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return t.split(separator: "\n").compactMap { try? dec.decode(ChatRecord.self, from: Data($0.utf8)) }
    }

    /// The name of every session that has a transcript, oldest first.
    public static func sessionIDs(root: URL) -> [String] {
        let dir = root.appendingPathComponent(ProjectStore.studioDir).appendingPathComponent("chat")
        return (((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".jsonl") }).sorted().map { String($0.dropLast(6)) }
    }

    public var sessionID: String { session.deletingPathExtension().lastPathComponent }

    public func load() -> [ChatRecord] {
        guard let t = try? String(contentsOf: session, encoding: .utf8) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return t.split(separator: "\n").compactMap { try? dec.decode(ChatRecord.self, from: Data($0.utf8)) }
    }

    /// The previous conversation as plain text turns for the model, so a reopened project continues where it stopped.
    /// Roles alternate (the API requires it) and the history is cut to the last `limit` characters per turn.
    public static func seed(from records: [ChatRecord], limit: Int = 4000) -> [[String: Any]] {
        var out: [[String: Any]] = []
        for r in records where r.role == "user" || r.role == "assistant" {
            let text = String(r.text.prefix(limit))
            if let last = out.last, last["role"] as? String == r.role {
                out[out.count - 1]["content"] = (last["content"] as? String ?? "") + "\n\n" + text
            } else {
                out.append(["role": r.role, "content": text])
            }
        }
        while let f = out.first, f["role"] as? String != "user" { out.removeFirst() }
        if let l = out.last, l["role"] as? String == "user" { out.removeLast() } // the new message will be the next user turn
        return out
    }
}
