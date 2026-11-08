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
