import Foundation

/// One screen of the Beginner wizard: the interview's question, a short help, and the way to answer.
/// The wizard has no data model of its own: an answer is a typed operation on showreel.json or the manifest, the same as in the blocks.
public struct WizardStep: Identifiable, Equatable, Sendable {
    public struct Option: Equatable, Sendable, Identifiable {
        public let value: String
        public let label: String
        public let detail: String
        public var id: String { value }
        public init(_ value: String, _ label: String, _ detail: String = "") { self.value = value; self.label = label; self.detail = detail }
    }

    public enum Kind: Equatable, Sendable {
        case single(ParameterKey, options: [Option], recommended: String?, custom: Bool)
        case multi(ParameterKey, options: [Option], recommended: [String])
        case text(ParameterKey, examples: [String], optional: Bool)
        case number(ParameterKey, presets: [Option])
        case files
        case asset(String)
        case summary(block: String)
        case soon(block: String)
    }

    public let id: String
    public let block: String
    public let title: String
    public let help: String
    public let kind: Kind

    public var isBuilt: Bool { if case .soon = kind { return false }; return true }
}

public enum Wizard {
    static let languages = [
        WizardStep.Option("en", "English"), .init("fr", "French"), .init("de", "German"), .init("es", "Spanish"),
        .init("it", "Italian"), .init("pt", "Portuguese"), .init("nl", "Dutch"),
    ]

    /// Every step of the wizard, in the order of the process. The asset steps follow the manifest; blocks that are not built
    /// appear as "coming soon" steps, so later blocks plug in here.
    public static func steps(assets: [AssetRow], spec: ProcessSpec?, systemLanguage: String? = nil) -> [WizardStep] {
        func p(_ k: ParameterKey, _ title: String, _ kind: WizardStep.Kind) -> WizardStep {
            WizardStep(id: "project." + k.rawValue, block: "project", title: title, help: k.help, kind: kind)
        }
        let sys = systemLanguage.flatMap { l in languages.contains { $0.value == l } ? l : nil }
        var out: [WizardStep] = [
            p(.conversationLanguage, "Which language should we use together for this project?",
              .single(.conversationLanguage, options: languages, recommended: sys, custom: false)),
            p(.reelLanguages, "Which language(s) should the reel speak?", .multi(.reelLanguages, options: languages, recommended: ["en"])),
            p(.audience, "Who will watch this film, and in what setting?",
              .text(.audience, examples: ["Customers or prospects, on a big screen with sound", "My own team, on laptops, often muted", "The public, in a phone feed"], optional: false)),
            p(.message, "What is the one sentence the viewer should remember?", .text(.message, examples: [], optional: false)),
            p(.tone, "How should the film feel and sound?",
              .single(.tone, options: ["warm", "sober", "playful", "premium", "bold", "human"].map { .init($0, $0.capitalized) }, recommended: nil, custom: true)),
            p(.duration, "How long should the film be?",
              .number(.duration, presets: [.init("30", "Short teaser", "about 30 s"), .init("60", "Mid-length", "about 60 s"), .init("90", "Long", "about 90 s")])),
            p(.formats, "Which formats do you need?",
              .multi(.formats, options: [.init("16:9", "Desktop 16:9", "big screen, laptop"), .init("9:16", "Mobile 9:16", "phone feed; changes the layout"),
                                         .init("1:1", "Square 1:1"), .init("4:5", "Portrait 4:5")], recommended: ["16:9"])),
            p(.constraints, "Is there anything that must or must not appear?", .text(.constraints, examples: [], optional: true)),
            WizardStep(id: "project.summary", block: "project", title: "Is the project description complete?",
                       help: "Here is what you decided, with the checks that need no AI. Validate it when you are happy, or come back later.", kind: .summary(block: "project")),
            WizardStep(id: "resources.files", block: "resources", title: "Which files should the film be made from?",
                       help: "Logos, screenshots, photos, fonts, music. Drop them in. Nothing is used in the film until you approve it.", kind: .files),
        ]
        for a in assets where !(a.file.isEmpty && a.status == "proposed" && a.notes == "not embedded") {
            out.append(WizardStep(id: "resources.asset." + a.id, block: "resources", title: "Use \(a.name) in the film?",
                                  help: a.notes.isEmpty ? "Approve it to let the build use it, exclude it to keep it out, or hold it until you know." : a.notes,
                                  kind: .asset(a.id)))
        }
        out.append(WizardStep(id: "resources.summary", block: "resources", title: "Are your files ready?",
                              help: "The asset rules, checked without AI. Validate when every file is decided.", kind: .summary(block: "resources")))
        for b in spec?.blocks ?? [] where !b.built {
            out.append(WizardStep(id: "soon." + b.id, block: b.id, title: b.name, help: "Coming soon (phase \(b.phase ?? "later")). Until then the copilot carries this step in the chat.", kind: .soon(block: b.id)))
        }
        return out
    }

    /// Whether the user has settled a step: the data has a value, the user said "none needed", or the gate is passed.
    public static func isDecided(_ s: WizardStep, file: ShowreelFile?, assets: [AssetRow], settings: StudioSettings, spec: ProcessSpec?) -> Bool {
        if settings.decided.contains(s.id) { return true }
        switch s.kind {
        case .single(let k, _, _, _), .multi(let k, _, _), .text(let k, _, _), .number(let k, _):
            guard let f = file else { return false }
            return !k.current(f).isEmpty
        case .files: return !assets.isEmpty
        case .asset(let id): return ["approved", "excluded", "placeholder"].contains(assets.first { $0.id == id }?.status ?? "")
        case .summary(let b):
            let keys = spec?.gateKeys(of: b) ?? []
            return !keys.isEmpty && keys.allSatisfy { file?.gates[$0] == "passed" }
        case .soon: return false
        }
    }

    /// Where the wizard resumes: the first built step that is not decided.
    public static func firstUndecided(_ steps: [WizardStep], file: ShowreelFile?, assets: [AssetRow], settings: StudioSettings, spec: ProcessSpec?) -> Int? {
        steps.firstIndex { $0.isBuilt && !isDecided($0, file: file, assets: assets, settings: settings, spec: spec) }
    }

    /// Decided and total counts over the built steps, for the progress bar.
    public static func progress(_ steps: [WizardStep], file: ShowreelFile?, assets: [AssetRow], settings: StudioSettings, spec: ProcessSpec?) -> (decided: Int, total: Int) {
        let built = steps.filter { $0.isBuilt }
        return (built.filter { isDecided($0, file: file, assets: assets, settings: settings, spec: spec) }.count, built.count)
    }

    /// What the optional "Suggest with AI" button asks the copilot. The copilot answers with a card the user accepts or refuses,
    /// so nothing is recorded without the user's choice.
    public static func suggestionPrompt(_ s: WizardStep) -> String {
        switch s.kind {
        case .single(let k, _, _, _), .multi(let k, _, _), .text(let k, _, _), .number(let k, _):
            return "I am answering the question \"\(s.title)\" in the wizard. Look at what the project already holds (get_state) and suggest a value for \(k.title.lowercased()). Propose it with update_parameter (key \(k.rawValue)) so I can accept or refuse it, and say in one line why."
        case .asset(let id):
            return "I am deciding whether to use the asset \(id) in the film. Look at the project (get_state) and tell me in two lines whether you would approve, exclude or hold it, and why. Do not change it; I will decide."
        case .files:
            return "I am choosing the files the film is made from. From what the project says (get_state), list in a few lines which kinds of files would help (logos, screenshots, music...). Do not change anything."
        case .summary(let b):
            return "Review the \(b) block of the project (get_state) and tell me in a few lines what looks incomplete or inconsistent. Do not change anything."
        case .soon:
            return "Tell me in two lines what this step will involve."
        }
    }
}
