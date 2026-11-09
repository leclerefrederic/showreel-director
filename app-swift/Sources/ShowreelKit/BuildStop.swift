import Foundation

/// Why the agent's turn ended. Only `finished` is a normal end; the others are said to the user in plain words.
public enum AgentStop: Equatable, Sendable {
    /// The model ended its answer with something to say.
    case finished
    /// The answer reached the output cap (in tokens) before it was complete: a tool call cut in the middle is never run.
    case tokenLimit(Int)
    /// The loop used its steps (the count) without the model ending.
    case turnLimit(Int)
    /// The model declined to answer.
    case refused
    /// The model ended its turn with no text and no tool call.
    case emptyReply
    /// The user stopped it.
    case cancelled
    /// Any other reason the API reports.
    case other(String)

    /// One plain sentence, for the chat and the journal. Nil for a normal end and for the user's own stop.
    public var line: String? {
        switch self {
        case .finished, .cancelled: return nil
        case .tokenLimit(let n): return "Clap's answer reached the output limit (\(n) tokens) before it was complete, so its last step was not run."
        case .turnLimit(let n): return "Clap used its \(n) steps without finishing."
        case .refused: return "The model declined to answer."
        case .emptyReply: return "Clap ended its turn without writing anything or saying why."
        case .other(let r): return "The API ended the answer with the reason \u{201C}\(r)\u{201D}."
        }
    }
}

/// How much one request of the agent may use. Never unlimited: a ceiling that is stated, so that a stop by the limit can say which one.
public struct AgentBudget: Equatable, Sendable {
    public var maxTurns: Int
    public var maxTokens: Int

    public static let standard = AgentBudget(maxTurns: 60, maxTokens: 8000)
    public static let ceilingTurns = 120
    public static let ceilingTokens = 32000

    /// A Build writes project.json, reel.js and one file per scene, and a model may put several in one answer: the room grows with the scenes, up to the ceiling.
    public static func build(scenes n: Int) -> AgentBudget {
        let k = max(n, 0)
        return AgentBudget(maxTurns: min(ceilingTurns, max(standard.maxTurns, 40 + 4 * k)), maxTokens: min(ceilingTokens, max(standard.maxTokens, 8000 + 1600 * k)))
    }
}

/// A transport whose output cap can be set per request (the real one; a test's may follow).
public protocol OutputBudgeted: AnyObject {
    var maxTokens: Int { get set }
}

/// What the Build says when the agent ended without writing the version.
public struct BuildFailure: Equatable, Sendable {
    public enum Remedy: Equatable, Sendable { case tryAgain, oneByOne }
    /// A short key for the journal: "token-limit", "turn-limit", "refused", "empty-reply", "api-error", "no-files".
    public let cause: String
    public let message: String
    public let remedy: Remedy
    /// The files Clap did write in the version folder (kept, not built).
    public let kept: [String]
}

public enum BuildStop {
    /// Files the app itself puts in a version folder before Clap writes: a folder with only these holds nothing of Clap's.
    static let appFiles: Set<String> = [Film.fileName, "fonts.json"]

    /// Removes the version folder when it holds only what the app wrote (so the next Build reuses the name and no empty `vN` piles up). Returns what Clap wrote, which stays.
    @discardableResult
    public static func discardStub(version: String, store: ProjectStore) -> [String] {
        let dir = store.root.appendingPathComponent(version)
        let fm = FileManager.default
        let base = dir.resolvingSymlinksInPath().path          // the enumerator reports resolved paths (/private/var for /var)
        guard let e = fm.enumerator(at: dir.resolvingSymlinksInPath(), includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var wrote: [String] = []
        for case let u as URL in e {
            guard (try? u.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let rel = String(u.resolvingSymlinksInPath().path.dropFirst(base.count + 1))
            if !appFiles.contains(rel) { wrote.append(rel) }
        }
        if wrote.isEmpty { try? fm.removeItem(at: dir) }
        return wrote.sorted()
    }

    /// The agent ended and `version` has no project.json: nothing is frozen any more, an empty stub is removed, one journal line says why, and the message names the cause and a way on.
    /// `failure` is the error the API (or the network) returned, when the request failed instead of ending.
    @discardableResult
    public static func conclude(version: String, store: ProjectStore, stop: AgentStop, failure: String?) -> BuildFailure {
        store.activity.update { $0.build = nil }
        let kept = discardStub(version: version, store: store)
        let cause: String, why: String, remedy: BuildFailure.Remedy
        if let f = failure {
            cause = "api-error"; remedy = .tryAgain
            why = "The request to the model failed: \(f)."
        } else {
            switch stop {
            case .tokenLimit: cause = "token-limit"; remedy = .oneByOne
            case .turnLimit: cause = "turn-limit"; remedy = .oneByOne
            case .refused: cause = "refused"; remedy = .tryAgain
            case .emptyReply: cause = "empty-reply"; remedy = .tryAgain
            case .other: cause = "other"; remedy = .tryAgain
            case .finished, .cancelled: cause = "no-files"; remedy = .tryAgain
            }
            why = stop.line ?? "Clap answered without writing the version; its answer is in the chat."
        }
        let tail = kept.isEmpty ? "Nothing was written in \(version)." : "\(kept.count) file\(kept.count == 1 ? "" : "s") Clap wrote stay in \(version), not built."
        let way = remedy == .oneByOne ? "Generate the scenes one by one, or try again." : "Try again."
        let message = "Clap did not write \(version). \(why) \(tail) \(way)"
        store.noteEvent(author: "app", op: "build", target: version, title: "Build \(version) stopped: \(cause)", note: message)
        return BuildFailure(cause: cause, message: message, remedy: remedy, kept: kept)
    }
}
