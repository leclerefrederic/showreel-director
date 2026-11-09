import Foundation

/// What a new project must have before the editing workspace opens: the languages, the formats, the target duration and a look. Everything else depends on
/// these. The audience, the message and the tone stay optional.
public struct SetupItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    /// Where it is set: "project" (the parameters) or the look editor's name.
    public let section: String
}

public enum ProjectSetup {
    /// The durations offered, in seconds: the Wizard's question and the presets of the Manual form read this one list. The form also takes any other number typed.
    public static let durationChoices = [30, 45, 60, 75, 90]

    public static let optional = ["audience", "message", "tone"]

    /// What is still missing, in the order a person fills it in. Empty: the base configuration is complete.
    public static func missing(_ f: ShowreelFile) -> [SetupItem] {
        var out: [SetupItem] = []
        func need(_ id: String, _ title: String, _ detail: String, _ section: String = "project") { out.append(SetupItem(id: id, title: title, detail: detail, section: section)) }
        if (f.conversationLanguage ?? "").isEmpty { need("conversationLanguage", "Conversation language", "the language you and the copilot talk in") }
        if f.reelLanguages.isEmpty { need("reelLanguages", "Reel language", "at least one language for the words in the film") }
        if (f.decisions.formats ?? []).isEmpty { need("formats", "Formats", "desktop 16:9, mobile 9:16, or both") }
        if (f.decisions.duration ?? 0) <= 0 { need("duration", "Target duration", "how long the film should be, in seconds") }
        let pal = f.decisions.palette ?? []
        if pal.count < 2 || !pal.allSatisfy({ EnginePalette.isHex($0) }) { need("palette", "Palette", "at least a background and a text colour", "palette") }
        if (f.decisions.fonts?.titles ?? "").isEmpty || (f.decisions.fonts?.text ?? "").isEmpty { need("fonts", "Fonts", "one for the titles and one for the text", "fonts") }
        if (f.decisions.background?.id ?? "").isEmpty { need("background", "Default background", "what the film starts on", "background") }
        return out
    }

    public static func isComplete(_ f: ShowreelFile) -> Bool { missing(f).isEmpty }

    /// The five things the base configuration is made of, as the user counts them: the look is one of them (palette, fonts and background).
    public struct Requirement: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let isSet: Bool
    }

    public static func requirements(_ f: ShowreelFile) -> [Requirement] {
        let gone = Set(missing(f).map { $0.id })
        func r(_ id: String, _ title: String, _ keys: [String]) -> Requirement { Requirement(id: id, title: title, isSet: keys.allSatisfy { !gone.contains($0) }) }
        return [r("conversationLanguage", "Conversation language", ["conversationLanguage"]), r("reelLanguages", "Film language", ["reelLanguages"]), r("formats", "Formats", ["formats"]),
                r("duration", "Target duration", ["duration"]), r("look", "Look", ["palette", "fonts", "background"])]
    }

    /// "4 of 5 set".
    public static func progress(_ f: ShowreelFile) -> (set: Int, total: Int, line: String) {
        let r = requirements(f), n = r.filter { $0.isSet }.count
        return (n, r.count, "\(n) of \(r.count) set")
    }

    /// What the form says about the duration while it is typed: the rules of the feasibility check, on what the project holds.
    public static func durationHint(_ f: ShowreelFile) -> (level: CheckLevel, text: String)? {
        guard (f.decisions.duration ?? 0) > 0 else { return nil }
        let rows = Checks.feasibility(f)
        guard !rows.isEmpty else { return nil }
        let worst = rows.first { $0.level == .fail } ?? rows.first { $0.level == .tight } ?? rows[0]
        return (worst.level, worst.level == .ok ? "Feasible: " + worst.detail : worst.detail)
    }
}

/// The languages the form offers, by code.
public enum ProjectLanguages {
    public static let all: [(code: String, name: String)] = [("en", "English"), ("fr", "French"), ("de", "German"), ("es", "Spanish"), ("it", "Italian"), ("pt", "Portuguese"), ("nl", "Dutch")]
    public static func name(_ code: String) -> String { all.first { $0.code == code }?.name ?? code }
    public static func code(forName n: String) -> String? { all.first { $0.name.caseInsensitiveCompare(n.trimmingCharacters(in: .whitespaces)) == .orderedSame || $0.code == n.lowercased() }?.code }
}

public extension Availability {
    /// The Wizard card of the New project screen: Clap leads it, so it needs an API key.
    static func wizard(hasKey: Bool) -> Availability {
        hasKey ? .available : .unavailable(Unavailable(.noKey, reason: "Wizard needs an API key", way: "Open Settings to connect one (Command-,), or choose Manual", link: .key))
    }
}

public extension ShowreelFile {
    /// The state of a gate. The interview's is derived from the project: it is passed when the base configuration is complete, and the style sheet's when the look is
    /// chosen (palette, fonts and background); a value stored earlier still counts, so that nothing a project had is taken away. No button sets them any more.
    func gateState(_ key: String) -> String {
        if key == "style" {
            let lookSet = ProjectSetup.requirements(self).first { $0.id == "look" }?.isSet == true
            return lookSet || gates[key] == "passed" ? "passed" : (gates[key] ?? "open")
        }
        if key == "interview" { return ProjectSetup.isComplete(self) || gates[key] == "passed" ? "passed" : (gates[key] ?? "open") }
        return gates[key] ?? "open"
    }
}

extension ProjectStore {
    /// True while the workspace must stay closed: the project asked for its setup (a project made by the app) and the user has not yet opened the workspace.
    public var needsSetup: Bool { settings.setupRequired }

    /// The workspace may open: only when the base configuration is complete. Clears the flag, for good.
    public func finishSetup() throws {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        let m = ProjectSetup.missing(f)
        guard m.isEmpty else { throw AgentError.msg("the project still needs: " + m.map { $0.title.lowercased() }.joined(separator: ", ")) }
        var s = settings; s.setupRequired = false; settings = s
    }
}
