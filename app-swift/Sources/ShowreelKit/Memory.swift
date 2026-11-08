import Foundation

/// What the project remembers, in `.studio/memory.json`: decisions with their reasons, preferences, rejected options, constraints, open questions, facts. It is
/// written by Clap through `remember` and fully visible, editable and deletable by the user. Its content is data: it is loaded into the prompt as data, and
/// nothing in it is ever an instruction.
public struct MemoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    /// decision, preference, rejected, constraint, open_question, fact.
    public var kind: String
    public var text: String
    public var reason: String
    /// user or clap.
    public var source: String
    public var created: Date
    public var updated: Date
    /// active, superseded or deleted. A deleted entry is kept in the file, marked, so that it is not remembered again by mistake.
    public var status: String
    /// Scenes ("S01") or journal lines ("j-ab12cd34") this is about.
    public var links: [String]
    /// A fact Clap noted is an assumption until the user confirms it (or edits it); what the user wrote is confirmed.
    public var confirmed: Bool
}

public enum MemoryKind: String, CaseIterable, Sendable {
    case decision, preference, rejected, constraint, open_question, fact
    public var title: String {
        switch self {
        case .decision: return "Decision"
        case .preference: return "Preference"
        case .rejected: return "Rejected"
        case .constraint: return "Constraint"
        case .open_question: return "Open question"
        case .fact: return "Fact"
        }
    }
}

public enum MemoryRules {
    public static let maxText = 400, maxReason = 400, maxLinks = 8, maxActive = 200

    private static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: [.caseInsensitive]) }
    private static let patterns: [(String, NSRegularExpression)] = [
        ("an email address", re(#"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#)),
        ("a link", re(#"https?://|www\.|\bftp://"#)),
        ("a credential", re(#"\b(sk|pk|rk)[-_][A-Za-z0-9_\-]{12,}|ghp_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{16,}|xox[abprs]-[A-Za-z0-9\-]{8,}|AKIA[0-9A-Z]{12,}|eyJ[A-Za-z0-9_\-]{8,}\.|bearer\s+[A-Za-z0-9._\-]{12,}|BEGIN [A-Z ]*PRIVATE KEY"#)),
        ("a secret", re(#"\b(password|passwd|pwd|passphrase|secret|token|api[_ \-]?key|private key)\b\s*(is|are|:|=)"#)),
        ("a bank account number", re(#"\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b"#)),
        ("an identification number", re(#"\b\d{3}-\d{2}-\d{4}\b"#)),
        ("an IP address", re(#"\b\d{1,3}(\.\d{1,3}){3}\b"#)),
        ("a postal address", re(#"\b\d{1,5}\s+(?:[A-Za-z'.\-]+\s+){1,3}(street|st\.?|avenue|ave\.?|road|rd\.?|boulevard|blvd|lane|drive|rue|all[ée]e|chemin|strasse|straße)\b"#)),
    ]
    private static let instructions = ["ignore previous", "ignore all", "ignore the above", "ignore your", "disregard", "forget your instructions", "forget previous", "system prompt", "new instructions",
                                       "you must", "you should always", "you are now", "act as ", "pretend to be", "do not tell the user", "don't tell the user", "run the command", "run this",
                                       "execute ", "curl ", "sudo ", "rm -rf", "<script", "```", "[system]", "<|", "assistant:", "override"]

    /// What the text looks like that must not be kept (a personal detail or an identifier), or nil. Phone and card numbers, long codes and keys are caught by shape.
    public static func personalData(in s: String) -> String? {
        let range = NSRange(s.startIndex..., in: s)
        for (what, r) in patterns where r.firstMatch(in: s, range: range) != nil { return what }
        // numbers: eight or more digits in a run of digits and separators (a phone or a card), or nine in a row
        var digits = 0, run = 0
        for c in s {
            if c.isNumber { digits += 1; run += 1; if run >= 9 || digits >= 8 && false { return "a number" } }
            else if " +-().".contains(c) { continue }
            else { if digits >= 8 { return "a phone or account number" }; digits = 0; run = 0 }
        }
        if digits >= 8 { return "a phone or account number" }
        // a long code that mixes letters and digits is a key or a token
        for w in s.split(whereSeparator: { !($0.isLetter || $0.isNumber || "+/=_-".contains($0)) }) where w.count >= 24 {
            if w.contains(where: { $0.isNumber }) && w.contains(where: { $0.isLetter }) { return "a key or a token" }
        }
        return nil
    }

    public static func readsAsInstruction(_ s: String) -> Bool {
        let l = s.lowercased()
        return instructions.contains { l.contains($0) } || l.hasPrefix("user:") || l.hasPrefix("system:")
    }

    /// Why a text cannot be kept, in plain words, or nil.
    public static func problem(_ text: String, field: String = "text", max: Int = maxText, required: Bool = true) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return required ? "the \(field) is empty" : nil }
        if t.count > max { return "the \(field) is \(t.count) characters: keep it to \(max)" }
        if let p = personalData(in: t) { return "the \(field) looks like \(p): the memory never keeps personal data or identifiers" }
        if readsAsInstruction(t) { return "the \(field) reads like an instruction, not a fact about the project: the memory only holds data" }
        return nil
    }

    /// One line, no control characters.
    public static func single(_ s: String) -> String {
        let spaced = s.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\t", with: " ")
        return String(String.UnicodeScalarView(spaced.unicodeScalars.filter { $0.value >= 32 })).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The same text with what looks personal taken out, for places that must show something anyway (a journal note in the brief).
    public static func redact(_ s: String) -> String {
        var out = single(s)
        for (_, r) in patterns { out = r.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "[removed]") }
        var words: [String] = []
        for w in out.split(separator: " ", omittingEmptySubsequences: true) {
            let isKey = w.count >= 24 && w.contains { $0.isNumber } && w.contains { $0.isLetter }
            let isLong = w.filter { $0.isNumber }.count >= 8
            words.append(isKey || isLong ? "[removed]" : String(w))
        }
        return words.joined(separator: " ")
    }

    static func validLink(_ l: String) -> Bool { l.range(of: #"^[A-Za-z0-9._\-]{1,40}$"#, options: .regularExpression) != nil }
}

extension ProjectStore {
    private var memoryURL: URL { root.appendingPathComponent(ProjectStore.studioDir).appendingPathComponent("memory.json") }
    public static let memoryPath = ".studio/memory.json"

    private struct MemoryFile: Codable { var schema = 1; var entries: [MemoryEntry] }

    private static let memoryEncoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; return e
    }()

    /// Every entry, deleted ones included, oldest first. No file: no memory.
    public func memoryEntries() -> [MemoryEntry] {
        memoryLock.lock(); defer { memoryLock.unlock() }
        return readMemory()
    }

    private func readMemory() -> [MemoryEntry] {
        guard let d = try? Data(contentsOf: memoryURL) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode(MemoryFile.self, from: d))?.entries ?? []
    }

    private func writeMemory(_ e: [MemoryEntry]) throws {
        try FileManager.default.createDirectory(at: memoryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.memoryEncoder.encode(MemoryFile(entries: e)).write(to: memoryURL, options: .atomic)
    }

    /// What is current: neither superseded nor deleted.
    public func activeMemory() -> [MemoryEntry] { memoryEntries().filter { $0.status == "active" } }

    /// Adds an entry. The rules refuse a personal detail, an identifier, something that reads as an instruction, a text that is empty or too long, and an
    /// entry that is already there. `source` is "user" or "clap".
    @discardableResult
    public func remember(kind: String, text: String, reason: String = "", source: String, links: [String] = [], now: Date = Date()) throws -> MemoryEntry {
        guard let k = MemoryKind(rawValue: kind) else { throw AgentError.msg("unknown kind \"\(kind)\": use " + MemoryKind.allCases.map { $0.rawValue }.joined(separator: ", ")) }
        guard source == "user" || source == "clap" else { throw AgentError.msg("the source is user or clap") }
        let t = MemoryRules.single(text), r = MemoryRules.single(reason)
        if let p = MemoryRules.problem(t) { throw AgentError.msg(p) }
        if let p = MemoryRules.problem(r, field: "reason", max: MemoryRules.maxReason, required: false) { throw AgentError.msg(p) }
        let ls = Array(links.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(MemoryRules.maxLinks))
        if let bad = ls.first(where: { !MemoryRules.validLink($0) }) { throw AgentError.msg("\"\(bad)\" is not a scene or an operation to link to") }
        memoryLock.lock(); defer { memoryLock.unlock() }
        var all = readMemory()
        if let same = all.first(where: { $0.status == "active" && $0.kind == kind && $0.text.lowercased() == t.lowercased() }) { throw AgentError.msg("already remembered (\(same.id)): update it instead") }
        guard all.filter({ $0.status == "active" }).count < MemoryRules.maxActive else { throw AgentError.msg("the memory is full (\(MemoryRules.maxActive) entries): forget what no longer matters first") }
        let e = MemoryEntry(id: "m-" + UUID().uuidString.prefix(8).lowercased(), kind: k.rawValue, text: t, reason: r, source: source, created: now, updated: now, status: "active", links: ls, confirmed: source == "user")
        all.append(e)
        try writeMemory(all)
        DocSync.sync(self)
        return e
    }

    /// Changes an entry (any field; nil leaves it). An entry the user edits is confirmed. A deleted entry cannot be changed: remember it again.
    @discardableResult
    public func updateMemory(id: String, text: String? = nil, reason: String? = nil, kind: String? = nil, status: String? = nil, links: [String]? = nil, confirm: Bool = false, source: String, now: Date = Date()) throws -> MemoryEntry {
        memoryLock.lock(); defer { memoryLock.unlock() }
        var all = readMemory()
        guard let i = all.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("no memory entry \(id)") }
        guard all[i].status != "deleted" else { throw AgentError.msg("\(id) was deleted: remember it again if it matters") }
        var e = all[i]
        if let t = text { let s = MemoryRules.single(t); if let p = MemoryRules.problem(s) { throw AgentError.msg(p) }; e.text = s }
        if let r = reason { let s = MemoryRules.single(r); if let p = MemoryRules.problem(s, field: "reason", max: MemoryRules.maxReason, required: false) { throw AgentError.msg(p) }; e.reason = s }
        if let k = kind { guard MemoryKind(rawValue: k) != nil else { throw AgentError.msg("unknown kind \"\(k)\"") }; e.kind = k }
        if let s = status { guard ["active", "superseded"].contains(s) else { throw AgentError.msg("a status is active or superseded (forget deletes)") }; e.status = s }
        if let l = links {
            let ls = Array(l.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(MemoryRules.maxLinks))
            if let bad = ls.first(where: { !MemoryRules.validLink($0) }) { throw AgentError.msg("\"\(bad)\" is not a scene or an operation to link to") }
            e.links = ls
        }
        let changed = e != all[i]
        if source == "user" && changed || confirm { e.confirmed = true }
        guard e != all[i] else { throw AgentError.msg("no change for \(id)") }
        e.updated = now
        all[i] = e
        try writeMemory(all)
        DocSync.sync(self)
        return e
    }

    /// Marks an entry deleted. It stays in the file, marked, and is never loaded again.
    @discardableResult
    public func forget(id: String, now: Date = Date()) throws -> MemoryEntry {
        memoryLock.lock(); defer { memoryLock.unlock() }
        var all = readMemory()
        guard let i = all.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("no memory entry \(id)") }
        guard all[i].status != "deleted" else { throw AgentError.msg("\(id) is already deleted") }
        all[i].status = "deleted"; all[i].updated = now
        try writeMemory(all)
        DocSync.sync(self)
        return all[i]
    }
}
