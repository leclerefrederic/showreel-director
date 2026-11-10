import Foundation

// MARK: a scene's look: one switch per group

/// The three groups of a scene's own look. Each is locked to the project's values until the user asks for an override with a switch.
public enum SceneLookGroup: String, CaseIterable, Sendable {
    case background, palette, fonts

    public var title: String { rawValue.capitalized }
    public var keys: [DecisionKey] {
        switch self { case .background: return [.background, .backgroundMood]; case .palette: return [.palette]; case .fonts: return [.titleFont, .textFont] }
    }
}

public enum LookOverrides {
    /// What a group shows for a scene: the project's values locked, or the scene's own (editable), and the project's values for the way back.
    public struct State: Equatable, Sendable {
        public let group: SceneLookGroup
        public let overridden: Bool
        /// The values the scene uses now, by key (an inherited value is the project's).
        public let values: [DecisionKey: String]
        /// The project's values: shown beside an override, and what the switch off returns to.
        public let project: [DecisionKey: String]
        public var locked: Bool { !overridden }
    }

    public static func state(_ group: SceneLookGroup, scene: ShowreelFile.Scene, in f: ShowreelFile) -> State {
        State(group: group, overridden: group.keys.contains { f.isOverridden($0, for: scene) },
              values: Dictionary(uniqueKeysWithValues: group.keys.map { ($0, f.effective($0, for: scene)) }),
              project: Dictionary(uniqueKeysWithValues: group.keys.map { ($0, $0.current(f)) }))
    }

    /// Switch on: the scene takes the project's current values as its own, so they can then be changed for this scene only. nil when the project has no value
    /// to take yet (nothing to copy): the editor then unlocks and the first choice creates the override.
    public static func enable(_ group: SceneLookGroup, scene: ShowreelFile.Scene, in f: ShowreelFile) -> ProjectOperation? {
        let changes = group.keys.compactMap { k -> DecisionChange? in let v = f.effective(k, for: scene); return v.isEmpty ? nil : DecisionChange(k, v) }
        return changes.isEmpty ? nil : .sceneLook(id: scene.id, changes)
    }

    /// Switch off: the override goes away, the project's values apply again. The very operation of "Revert to project".
    public static func disable(_ group: SceneLookGroup, scene: String) -> ProjectOperation {
        .sceneLook(id: scene, group.keys.map { DecisionChange($0, "") })
    }

    /// The groups a scene overrides, in the order of the tab: the badge shows when this is not empty.
    public static func groups(of scene: ShowreelFile.Scene, in f: ShowreelFile) -> [SceneLookGroup] {
        SceneLookGroup.allCases.filter { g in g.keys.contains { f.isOverridden($0, for: scene) } }
    }
}

extension Drops {
    /// The short question asked before a drop that would override the look of a scene; nil for every other drop. A refusal of the question changes nothing.
    public static func confirmation(_ item: DragItem, on target: DropTarget) -> String? {
        guard Drops.applies(item, to: target), case .scene = normalized(item, target) else { return nil }
        switch item { case .background, .palette, .look: return "Replace for this scene only?"; default: return nil }
    }
}

// MARK: a choice pinned above the options

/// The current choice of a look editor and the other options, which never repeat it.
public struct Partition<T>: Sendable where T: Sendable {
    public let current: T?
    public let others: [T]
}

public enum LookChoices {
    /// Splits the options around the current one (nil: there is none yet, every option is "other"). Order is kept, nothing is lost or repeated.
    public static func split<T: Sendable>(_ options: [T], id: (T) -> String, current: String?) -> Partition<T> {
        guard let c = current, let i = options.firstIndex(where: { id($0) == c }) else { return Partition(current: nil, others: options) }
        var rest = options; rest.remove(at: i)
        return Partition(current: options[i], others: rest)
    }

    /// Several current choices (the moods: one or two) pinned together.
    public static func split<T: Sendable>(_ options: [T], id: (T) -> String, currents: [String]) -> (current: [T], others: [T]) {
        (currents.compactMap { c in options.first { id($0) == c } }, options.filter { !currents.contains(id($0)) })
    }

    /// The look package the project's decisions match exactly (palette, title font, background and effects pack), if any.
    public static func currentLook(_ f: ShowreelFile) -> String? {
        let d = f.decisions
        return LookPackages.all().first { p in
            d.palette == p.palette.map { $0.uppercased() } && d.background?.id == p.background && d.fonts?.titles == p.fonts.titles && d.effectsPack == p.pack
        }?.id
    }

    /// The look whose palette is the project's, if any (a palette the user mixed is not any look's).
    public static func currentPalette(_ f: ShowreelFile) -> String? {
        guard let p = f.decisions.palette, !p.isEmpty else { return nil }
        return LookPackages.all().first { $0.palette.map { $0.uppercased() } == p }?.id
    }
}

// MARK: the design system board

/// What the viewer draws while the project settings are open on the look: read-only, from the project's decisions. Everything is plain data here; the
/// views draw it (the engine draws the live background and the animation sample).
public struct DesignBoard: Equatable, Sendable {
    public struct Swatch: Equatable, Sendable {
        public let role: String
        public let hex: String
        /// A readable colour to write on the swatch (the better of the palette's text colour, black and white).
        public let on: String
    }
    public struct ContrastLine: Equatable, Sendable {
        public let title: String
        public let ratio: Double
        public let level: CheckLevel
        public let detail: String
        /// The swatch (index into `swatches`) the check judges: nil for a check that spans colours, which the view puts in a row of its own (PL1).
        public let swatch: Int?
    }
    /// A swatch and the check that sits under it (the Background judges nothing: its column has no check).
    public struct Column: Equatable, Sendable {
        public let swatch: Swatch
        public let check: ContrastLine?
    }
    public let swatches: [Swatch]
    public let contrasts: [ContrastLine]
    public let titleFont: String?
    public let textFont: String?
    public let background: String?
    public let backgroundMood: String?
    public let moods: [String]
    public let pack: String?
    /// The effect the sample plays: the first of the chosen pack (or of the first mood) that the library has.
    public let sampleEffect: String
    public let sampleText: String
    public var hasPalette: Bool { swatches.count >= 2 }
    /// One column per swatch, each with the check that judges it; the grouping is expressed here once, so a palette with more or fewer colours places its checks right.
    public var columns: [Column] { swatches.indices.map { i in Column(swatch: swatches[i], check: contrasts.first { $0.swatch == i }) } }
    /// The checks that belong to no single swatch: a row below the columns.
    public var spanning: [ContrastLine] { contrasts.filter { $0.swatch == nil } }

    public static let placeholderText = "Simple. Fast. Yours."

    public static func make(_ f: ShowreelFile) -> DesignBoard {
        let d = f.decisions
        let pal = d.palette ?? []
        let valid = pal.allSatisfy { EnginePalette.isHex($0) }
        func readable(_ hex: String) -> String { !EnginePalette.isHex(hex) || Contrast.ratio(hex, "#000000") >= Contrast.ratio(hex, "#FFFFFF") ? "#000000" : "#FFFFFF" }
        let swatches = pal.enumerated().map { i, hex in Swatch(role: i < PaletteRole.allCases.count ? PaletteRole.allCases[i].title : "Extra", hex: hex, on: readable(hex)) }
        // the key contrasts: text, accent and accent 2, each against the background, as the palette check words them
        let checks = valid && pal.count >= 2 ? Contrast.checks(pal) : []
        let lines = checks.enumerated().map { n, r in ContrastLine(title: r.title, ratio: Contrast.ratio(pal[n + 1], pal[0]), level: r.level, detail: r.detail, swatch: n + 1 < pal.count ? n + 1 : nil) }
        let packName = (d.effectsPack?.isEmpty == false ? d.effectsPack : d.moods?.first) ?? ""
        let known = Set(Look.effects())
        let effect = Look.packs().first { $0.name == packName }?.effects.first { known.contains($0) } ?? "Fade"
        let m = (f.parameters.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return DesignBoard(swatches: swatches, contrasts: lines, titleFont: nonEmpty(d.fonts?.titles), textFont: nonEmpty(d.fonts?.text), background: nonEmpty(d.background?.id),
                           backgroundMood: nonEmpty(d.background?.mood), moods: d.moods ?? [], pack: nonEmpty(d.effectsPack), sampleEffect: effect,
                           sampleText: m.isEmpty ? placeholderText : String(m.prefix(40)))
    }

    private static func nonEmpty(_ s: String?) -> String? { (s ?? "").isEmpty ? nil : s }
}
