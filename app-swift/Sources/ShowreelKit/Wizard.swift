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
        case scenes
        case scene(String)
        case go
        case build
        case lookBoard
        case palette
        case font(DecisionKey)
        case background
        case moods
        case effectsPack
        case asset(String)
        case summary(area: String)
        case soon(area: String)
    }

    public let id: String
    public let area: String
    public let title: String
    public let help: String
    public let kind: Kind

    public var isBuilt: Bool { if case .soon = kind { return false }; return true }
}

public enum Wizard {
    /// The parts of the wizard, in the order of the process: what the outline lists. `area` is the key of the steps and of the checks.
    public static let sections: [(area: String, name: String, icon: String)] = [
        ("project", "Project", "doc.text"), ("resources", "Resources", "photo.on.rectangle.angled"), ("look", "Look and technique", "paintpalette"),
        ("storyboard", "Storyboard", "film.stack"), ("scene", "Scene review", "checkmark.rectangle"), ("build", "Build and preview", "play.rectangle"),
        ("deliver", "Deliver", "square.and.arrow.up"),
    ]

    static let languages = [
        WizardStep.Option("en", "English"), .init("fr", "French"), .init("de", "German"), .init("es", "Spanish"),
        .init("it", "Italian"), .init("pt", "Portuguese"), .init("nl", "Dutch"),
    ]

    /// Every step of the wizard, in the order of the process. The asset steps follow the manifest; blocks that are not built
    /// appear as "coming soon" steps, so later blocks plug in here.
    public static func steps(assets: [AssetRow], spec: ProcessSpec?, systemLanguage: String? = nil, file: ShowreelFile? = nil) -> [WizardStep] {
        func p(_ k: ParameterKey, _ title: String, _ kind: WizardStep.Kind) -> WizardStep {
            WizardStep(id: "project." + k.rawValue, area: "project", title: title, help: k.help, kind: kind)
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
            WizardStep(id: "project.summary", area: "project", title: "Is the project description complete?",
                       help: "Here is what you decided, with the checks that need no AI. Validate it when you are happy, or come back later.", kind: .summary(area: "project")),
            WizardStep(id: "resources.files", area: "resources", title: "Which files should the film be made from?",
                       help: "Logos, screenshots, photos, fonts, music. Drop them in. Nothing is used in the film until you approve it.", kind: .files),
        ]
        for a in assets where !(a.file.isEmpty && a.status == "proposed" && a.notes == "not embedded") {
            out.append(WizardStep(id: "resources.asset." + a.id, area: "resources", title: "Use \(a.name) in the film?",
                                  help: a.notes.isEmpty ? "Approve it to let the build use it, exclude it to keep it out, or hold it until you know." : a.notes,
                                  kind: .asset(a.id)))
        }
        out.append(WizardStep(id: "resources.summary", area: "resources", title: "Are your files ready?",
                              help: "The asset rules, checked without AI. Validate when every file is decided.", kind: .summary(area: "resources")))
        if spec?.isBuilt(area: "look") == true {
            func l(_ id: String, _ title: String, _ help: String, _ kind: WizardStep.Kind) -> WizardStep { WizardStep(id: "look." + id, area: "look", title: title, help: help, kind: kind) }
            out += [
                l("board", "Which of these looks feels right?", "Three complete looks to compare, each a palette, a background, a font pair and a motion mood. Pick one to start from, or decide later and choose each part yourself.", .lookBoard),
                l("palette", "Which colours should the film use?", "A background, a text colour and an accent, in that order. The contrast check runs as you choose.", .palette),
                l("titleFont", "Which font for the titles?", "Real samples of free fonts. Titles carry the message, so they can be bolder than the text.", .font(.titleFont)),
                l("textFont", "Which font for the text?", "The font for lines and details. It should stay readable small.", .font(.textFont)),
                l("background", "Which background should sit behind the scenes?", "Animated thumbnails from the engine, in your palette. Calm ones keep the text readable.", .background),
                l("moods", "Which mood should the motion have?", "Pick one or two. The mood decides which effects you see next.", .moods),
                l("effectsPack", "Which effects pack fits?", "The pack gives the film a consistent set of text and transition effects.", .effectsPack),
                WizardStep(id: "look.summary", area: "look", title: "Is the look settled?", help: "Here is what you decided, with the checks that need no AI. Validate it when you are happy, or come back later.", kind: .summary(area: "look")),
            ]
        }
        if spec?.isBuilt(area: "storyboard") == true {
            out.append(WizardStep(id: "storyboard.scenes", area: "storyboard", title: "What happens, scene by scene?",
                                  help: "Write the scenes in order: how long each lasts, what is said, what is seen. Scene IDs stay the same for good. The reading budget is checked as you go.", kind: .scenes))
            out.append(WizardStep(id: "storyboard.summary", area: "storyboard", title: "Is the storyboard complete?",
                                  help: "Here is the film as you wrote it, with the checks that need no AI. Validate it when you are happy.", kind: .summary(area: "storyboard")))
        }
        if spec?.isBuilt(area: "scene") == true {
            for s in file.map({ SceneRules.live($0) }) ?? [] {
                out.append(WizardStep(id: "scene." + s.id, area: "scene", title: "Is \(s.id) right as it is?",
                                      help: s.text.isEmpty ? "Validate it, send it back with a note, or ditch it. A ditched scene keeps its ID." : "\"\(s.text)\"", kind: .scene(s.id)))
            }
            out.append(WizardStep(id: "scene.go", area: "scene", title: "Ready to give the Go?",
                                  help: "The build never starts without it, and the app never gives it for you. Every scene must be Validated or ditched.", kind: .go))
        }
        if spec?.isBuilt(area: "build") == true {
            out.append(WizardStep(id: "build.run", area: "build", title: "Build the film",
                                  help: "The copilot writes the version from your storyboard and your decisions, then the app builds it, tests it and plays it. This is the one step that needs an AI.", kind: .build))
        }
        for b in spec?.blocks ?? [] where !b.built {
            out.append(WizardStep(id: "soon." + b.id, area: b.id, title: b.name, help: "Coming soon (phase \(b.phase ?? "later")). Until then the copilot carries this step in the chat.", kind: .soon(area: b.id)))
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
        case .scenes: return !(file?.scenes.isEmpty ?? true)
        case .scene(let id): return file?.scenes.first { $0.id == id }.map { $0.state.isReviewed || $0.state == .ditched } ?? false
        case .go: return file?.gates["review"] == "passed"
        case .build: return file?.gates["build"] == "passed"
        case .lookBoard:
            guard let d = file?.decisions else { return false }
            return d.palette != nil && !(d.fonts?.titles ?? "").isEmpty && !(d.background?.id ?? "").isEmpty && !(d.effectsPack ?? "").isEmpty
        case .palette: return (file?.decisions.palette?.count ?? 0) >= 2
        case .font(let k): return file.map { !k.current($0).isEmpty } ?? false
        case .background: return file.map { !DecisionKey.background.current($0).isEmpty } ?? false
        case .moods: return file.map { !DecisionKey.moods.current($0).isEmpty } ?? false
        case .effectsPack: return file.map { !DecisionKey.effectsPack.current($0).isEmpty } ?? false
        case .asset(let id): return ["approved", "excluded", "placeholder"].contains(assets.first { $0.id == id }?.status ?? "")
        case .summary(let b):
            let keys = spec?.gateKeys(area: b) ?? []
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

    /// The message behind "Draft with AI" in the scene library: the copilot proposes scenes as cards to accept or refuse.
    public static var draftScenesPrompt: String {
        suggestionPrompt(WizardStep(id: "storyboard.scenes", area: "storyboard", title: "", help: "", kind: .scenes))
    }

    /// What the optional "Suggest with AI" button asks the copilot. The copilot answers with a card the user accepts or refuses,
    /// so nothing is recorded without the user's choice.
    public static func suggestionPrompt(_ s: WizardStep) -> String {
        switch s.kind {
        case .single(let k, _, _, _), .multi(let k, _, _), .text(let k, _, _), .number(let k, _):
            return "I am answering the question \"\(s.title)\" in the wizard. Look at what the project already holds (get_state) and suggest a value for \(k.title.lowercased()). Propose it with update_parameter (key \(k.rawValue)) so I can accept or refuse it, and say in one line why."
        case .asset(let id):
            return "I am deciding whether to use the asset \(id) in the film. Look at the project (get_state) and tell me in two lines whether you would approve, exclude or hold it, and why. Do not change it; I will decide."
        case .lookBoard:
            return "I am choosing the look of the film in the wizard. From what the project holds (get_state: audience, message, tone), suggest one complete look and propose it with update_decision calls for palette (background, text, accent, accent 2), titleFont, textFont, background, moods and effectsPack, so I can accept or refuse each card. Say in two lines why it fits."
        case .palette:
            return "I am choosing the colours. From the project (get_state), suggest a palette of background, text, accent and accent 2 with a good contrast, and propose it with update_decision (key palette) so I can accept or refuse it."
        case .font(let k):
            return "I am choosing the \(k == .titleFont ? "title" : "text") font. From the project (get_state), suggest one from the free list that fits the tone, and propose it with update_decision (key \(k.rawValue)) so I can accept or refuse it."
        case .background:
            return "I am choosing the background. From the project (get_state), suggest one background id of the engine that keeps text readable, and propose it with update_decision (key background)."
        case .moods:
            return "I am choosing the motion mood. From the project (get_state), suggest one or two of the mood packs and propose them with update_decision (key moods)."
        case .effectsPack:
            return "I am choosing the effects pack. From the chosen moods and the project (get_state), suggest one pack and propose it with update_decision (key effectsPack)."
        case .scenes:
            return "I am writing the storyboard in the wizard. From the project (get_state: audience, message, tone, duration, look, assets), draft the scenes in order and propose each one with add_scene so I can accept or refuse each card. Keep to the duration, give every scene a duration in seconds, keep lines short enough for the reading budget, and link only approved assets."
        case .scene(let id):
            return "I am reviewing scene \(id). Look at it (get_state) and tell me in two lines what you would improve. Do not change it and do not mark it OK: I decide."
        case .go:
            return "Tell me in two lines what is still missing before the Go. Never give the Go yourself: only I can, with the button."
        case .build:
            return "Tell me in two lines what the build will do with my storyboard and decisions. Do not start it: I press the button."
        case .files:
            return "I am choosing the files the film is made from. From what the project says (get_state), list in a few lines which kinds of files would help (logos, screenshots, music...). Do not change anything."
        case .summary(let b):
            return "Review the \(b) part of the project (get_state) and tell me in a few lines what looks incomplete or inconsistent. Do not change anything."
        case .soon:
            return "Tell me in two lines what this step will involve."
        }
    }
}
