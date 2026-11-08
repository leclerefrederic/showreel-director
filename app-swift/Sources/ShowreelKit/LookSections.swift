import Foundation

/// The six editors of the global look, as the list of the project settings shows them: an icon, a name and the current choice at a glance.
public enum LookSection: String, CaseIterable, Identifiable, Sendable {
    case looks, palette, fonts, background, moods, effects
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .looks: return "Looks"
        case .palette: return "Palette"
        case .fonts: return "Fonts"
        case .background: return "Background"
        case .moods: return "Moods"
        case .effects: return "Effects pack"
        }
    }

    public var symbol: String {
        switch self {
        case .looks: return "wand.and.stars"
        case .palette: return "paintpalette"
        case .fonts: return "textformat"
        case .background: return "rectangle.on.rectangle"
        case .moods: return "waveform.path"
        case .effects: return "sparkles"
        }
    }

    public struct Summary: Equatable, Sendable {
        public let text: String
        public let swatches: [String]
        public var isSet: Bool
        public init(text: String, swatches: [String], isSet: Bool) { self.text = text; self.swatches = swatches; self.isSet = isSet }
    }

    /// The current choice, in a few words or as colours; "not chosen yet" when there is none.
    public func summary(_ f: ShowreelFile) -> Summary {
        let d = f.decisions
        func plain(_ s: String) -> Summary { Summary(text: s, swatches: [], isSet: true) }
        let none = Summary(text: "not chosen yet", swatches: [], isSet: false)
        switch self {
        case .looks:
            if let id = LookChoices.currentLook(f), let p = LookPackages.all().first(where: { $0.id == id }) { return plain(p.name) }
            return (d.palette ?? []).isEmpty && (d.background?.id ?? "").isEmpty ? none : plain("your own mix")
        case .palette:
            let p = d.palette ?? []
            return p.isEmpty ? none : Summary(text: "", swatches: p, isSet: true)
        case .fonts:
            let t = d.fonts?.titles ?? "", x = d.fonts?.text ?? ""
            return t.isEmpty && x.isEmpty ? none : plain([t.isEmpty ? nil : t, x.isEmpty ? nil : x].compactMap { $0 }.joined(separator: " + "))
        case .background:
            guard let id = d.background?.id, !id.isEmpty else { return none }
            return plain(id + ((d.background?.mood ?? "").isEmpty ? "" : ", reacts like \(d.background!.mood!)"))
        case .moods:
            return (d.moods ?? []).isEmpty ? none : plain((d.moods ?? []).joined(separator: ", "))
        case .effects:
            return (d.effectsPack ?? "").isEmpty ? none : plain(d.effectsPack!)
        }
    }
}
