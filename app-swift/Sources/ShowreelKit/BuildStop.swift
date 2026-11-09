import Foundation

/// Why the agent's turn ended. Only `finished` is a normal end; the others are said to the user in plain words.
public enum AgentStop: Equatable, Sendable {
    /// The model ended its answer with something to say.
    case finished
    /// The answer reached the model's maximum output (in tokens) before it was complete: a tool call cut in the middle is never run.
    case tokenLimit(Int)
    /// The loop guard (the count of steps) was reached without the model ending.
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
        case .tokenLimit(let n): return "Clap's answer reached the maximum output of the model (\(n) tokens) before it was complete, so its last step was not run."
        case .turnLimit(let n): return "Clap reached the loop guard (\(n) steps) without finishing."
        case .refused: return "The model declined to answer."
        case .emptyReply: return "Clap ended its turn without writing anything or saying why."
        case .other(let r): return "The API ended the answer with the reason \u{201C}\(r)\u{201D}."
        }
    }
}

/// The two numbers that bound the agent. Neither is a product limit: the first is the model's own, the second only stops a loop nobody sees.
public enum AgentLimits {
    /// The most output tokens one answer may have: the limit of the model, not a choice of the product (the API requires a max_tokens, so "no limit" is this value).
    /// 128 000 is the documented maximum output of claude-sonnet-5-5, the default model (the Models API reports it as `max_tokens`). A model that allows less refuses it
    /// with a 400 that names its own maximum: the transport then asks again once with that value (`OutputCap`).
    public static let modelMaxOutput = 128_000
    /// A guard against a loop, not a product limit: how many steps (answers) one request may take. The user sees the count rise and can Cancel long before it.
    public static let loopGuardSteps = 1000
    /// Seconds without a single byte from the stream (headers, events, even the API's pings) after which a request is cut and said so. The default of the advanced setting.
    public static let idleTimeout: TimeInterval = 90
    /// Seconds without any text or tool argument (the API's keep-alive pings do not count) after which a request is cut. The default of the rule; not a setting.
    public static let contentTimeout: TimeInterval = 120
    /// The longest one request may take, in seconds (8 minutes). The default of the advanced setting.
    public static let requestTimeout: TimeInterval = 480
    /// How many times a step is asked again after a cut (a lost connection, a closed stream, one of the two rules above): the first try, then this many more.
    public static let stepRetries = 2
    /// Seconds to wait before asking again (tests set it to 0).
    nonisolated(unsafe) public static var retryDelay: TimeInterval = 3
}

/// The request was cut because the stream said nothing for `seconds`.
public struct IdleTimeout: Error, LocalizedError, Equatable, Sendable {
    public let seconds: Int
    public var errorDescription: String? { "No answer from the API for \(seconds) s" }
}

/// No text and no tool argument came for `seconds`, whatever else the stream said (`pingsOnly`: only keep-alive pings came).
public struct ContentTimeout: Error, LocalizedError, Equatable, Sendable {
    public let seconds: Int
    public let pingsOnly: Bool
    public var step: String?
    public var errorDescription: String? { "No content from the API for \(seconds) s" + (step.map { " on \($0)" } ?? "") + (pingsOnly ? ", only keep-alive pings" : "") }
}

/// One request took longer than the maximum.
public struct RequestTooLong: Error, LocalizedError, Equatable, Sendable {
    public let seconds: Int
    public var step: String?
    public var errorDescription: String? {
        let t = seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds) s"
        return "Request exceeded \(t)" + (step.map { " on \($0)" } ?? "")
    }
}

/// The connection dropped, or the stream closed before the API said the answer was complete.
public struct ConnectionLost: Error, LocalizedError, Equatable, Sendable {
    public let detail: String
    public var step: String?
    public var errorDescription: String? { "Connection lost" + (step.map { " on \($0)" } ?? "") + (detail.isEmpty ? "" : " (\(detail))") }
}

/// What the Build asks again by itself: a cut, never an answer of the API (a 4xx, a refusal) or the user's stop.
public func isCut(_ e: Error) -> Bool { e is IdleTimeout || e is ContentTimeout || e is RequestTooLong || e is ConnectionLost }

/// What one request did, for the journal and the log.
public struct RequestStats: Equatable, Sendable {
    public var seconds: Double = 0
    public var bytes = 0
    public var pings = 0
    public var contentTokens = 0
    public var stopReason: String?
    /// "ok", "idle", "no-content", "too-long", "connection-lost", "http <status>", "cancelled" or "error".
    public var cause = "ok"
    public var line: String { "\(String(format: "%.0f", seconds)) s, \(bytes) bytes, \(contentTokens) content tokens, \(pings) ping\(pings == 1 ? "" : "s"), stop_reason \(stopReason ?? "none"), \(cause)" }
}

/// A transport with the two time rules and a record of its last request (the real one).
public protocol RequestWatched: AnyObject {
    var contentTimeout: TimeInterval { get set }
    var requestTimeout: TimeInterval { get set }
    var lastRequest: RequestStats? { get }
}

/// What the API says when `max_tokens` is more than the model accepts, and what to do about it.
public enum OutputCap {
    /// The maximum the error names ("max_tokens: 128000 > 64000, which is the maximum allowed number of output tokens for ..."), when it is below what was asked.
    public static func limit(fromError body: String, requested: Int) -> Int? {
        guard body.contains("max_tokens") else { return nil }
        let patterns = [#"max_tokens:\s*\d+\s*>\s*(\d+)"#, #"maximum[^0-9]{0,60}(\d[\d,_]*)"#]
        for p in patterns {
            guard let r = body.range(of: p, options: .regularExpression), let n = Int(body[r].split(whereSeparator: { !$0.isNumber && $0 != "," && $0 != "_" }).last.map { $0.filter { $0.isNumber } } ?? "") else { continue }
            if n > 0, n < requested { return n }
        }
        return nil
    }
}

/// A transport whose output cap can be read and set, and that reports the output tokens of an answer while it is written (the real one; a test's may follow).
public protocol OutputBudgeted: AnyObject {
    var maxTokens: Int { get set }
    /// Called while an answer is written with the output tokens so far (an estimate between the exact figures the API gives).
    var onOutput: ((Int) -> Void)? { get set }
    /// Seconds without any byte from the stream before the request is cut with an `IdleTimeout`.
    var idleTimeout: TimeInterval { get set }
}
