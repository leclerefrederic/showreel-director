import Foundation

/// The design tokens of the app: hex colours and numbers, no SwiftUI. One set decides every colour, radius, space and text size; the theme of the app (ShowreelStudio/Theme.swift)
/// maps it to SwiftUI, and a view never picks its own. A later phase can swap the tokens at run time (a skin): nothing here is read at draw time except through the theme.
public struct DesignTokens: Equatable, Sendable {
    public struct Surfaces: Equatable, Sendable { public var canvas, panel, raised, selected: String }
    public struct Borders: Equatable, Sendable { public var hairline, strong: String }
    public struct Text: Equatable, Sendable {
        public var primary, secondary: String
        /// For decoration and disabled things only, never for information that has no tooltip.
        public var faint: String
    }
    public struct Roles: Equatable, Sendable { public var warning, danger, success, review, outOfDate: String }
    public struct Lanes: Equatable, Sendable { public var scene, sceneBorder, music: String }
    public struct Radii: Equatable, Sendable { public var small, medium, large: Double }
    public struct Spacing: Equatable, Sendable { public var xs, s, m, l, xl: Double }
    public struct TypeSizes: Equatable, Sendable { public var small, body, title, large: Double }

    /// The Film strip: the lane stack, the frames and the lines on them. The values the strip had before the tokens existed, one for one.
    public struct Strip: Equatable, Sendable {
        public var bg, lane, ruler, frame, wave, playhead, white, black, section, cutFill: String
        /// How much of white or black a line, a text and a chip carry (0 to 1).
        public var line = 0.24, text = 0.94, dim = 0.66, chip = 0.6, chipHeavy = 0.7, gradientTop = 0.55, gradientBottom = 0.5
        public var gridBeat = 0.16, gridBar = 0.34, gridSection = 0.75, gridCut = 0.26
    }

    public var surfaces: Surfaces
    public var borders: Borders
    public var text: Text
    public var accent: String
    public var onAccent: String
    public var roles: Roles
    public var lanes: Lanes
    public var radii: Radii
    public var spacing: Spacing
    public var sizes: TypeSizes
    public var strip: Strip
    /// The orange of a note that needs a look (a transition's mark, a count), and the colour of a lock that is on: the values the list had.
    public var mark: String
    public var lockOn: String
    /// Regular and medium only.
    public static let weights = ["regular", "medium"]
    /// The least text size, in points.
    public static let minimumTextSize = 11.0

    /// Graphite canvas, rounded panels, one teal accent.
    public static let graphite = DesignTokens(
        surfaces: Surfaces(canvas: "#0F1115", panel: "#161A20", raised: "#1F232A", selected: "#1D2A2C"),
        borders: Borders(hairline: "#262B34", strong: "#2F3642"),
        text: Text(primary: "#E8EAEE", secondary: "#8B93A1", faint: "#4A515E"),
        accent: "#2DD4BF", onAccent: "#0F1115",
        roles: Roles(warning: "#F5C453", danger: "#F87171", success: "#4ADE80", review: "#F59E0B", outOfDate: "#60A5FA"),
        lanes: Lanes(scene: "#2A3550", sceneBorder: "#3B4A6A", music: "#D9A441"),
        radii: Radii(small: 6, medium: 8, large: 12),
        spacing: Spacing(xs: 4, s: 8, m: 12, l: 16, xl: 24),
        sizes: TypeSizes(small: 11, body: 13, title: 15, large: 22),
        strip: Strip(bg: "#131418", lane: "#1E1F25", ruler: "#191A20", frame: "#2B2D36", wave: "#61A8FF", playhead: "#FF544D", white: "#FFFFFF", black: "#000000", section: "#FF9500", cutFill: "#333333"),
        mark: "#FF9F0A", lockOn: "#40C8E0")

    /// Every colour with its name, for the tests and for the theme (a colour that is not here does not exist).
    public var colors: [(name: String, hex: String)] {
        [("canvas", surfaces.canvas), ("panel", surfaces.panel), ("raised", surfaces.raised), ("selected", surfaces.selected),
         ("hairline", borders.hairline), ("strong", borders.strong),
         ("textPrimary", text.primary), ("textSecondary", text.secondary), ("textFaint", text.faint),
         ("accent", accent), ("onAccent", onAccent),
         ("warning", roles.warning), ("danger", roles.danger), ("success", roles.success), ("review", roles.review), ("outOfDate", roles.outOfDate),
         ("laneScene", lanes.scene), ("laneSceneBorder", lanes.sceneBorder), ("laneMusic", lanes.music)]
    }
    /// The colours added in DS2 (the strip's own and two of the list's), each with the value it had.
    public var extras: [(name: String, hex: String)] {
        [("stripBg", strip.bg), ("stripLane", strip.lane), ("stripRuler", strip.ruler), ("stripFrame", strip.frame), ("stripWave", strip.wave), ("stripPlayhead", strip.playhead),
         ("stripWhite", strip.white), ("stripBlack", strip.black), ("stripSection", strip.section), ("stripCutFill", strip.cutFill), ("mark", mark), ("lockOn", lockOn)]
    }
    public var radiiScale: [Double] { [radii.small, radii.medium, radii.large] }
    public var spacingScale: [Double] { [spacing.xs, spacing.s, spacing.m, spacing.l, spacing.xl] }
    public var sizeScale: [Double] { [sizes.small, sizes.body, sizes.title, sizes.large] }

    /// The colour of each Status state of a scene (UI2), from the roles: the meaning stays, the palette is the theme's.
    public func status(_ k: SceneStatusKind) -> String {
        switch k {
        case .needsAttention: return roles.danger
        case .notWritten: return text.secondary
        case .outOfDate: return roles.outOfDate
        case .layoutWarning: return roles.warning
        case .toReview: return roles.review
        case .ready: return roles.success
        }
    }

    // MARK: contrast (WCAG 2)

    /// The red, green and blue of "#RRGGBB" as 0 to 1; nil when it is not one.
    public static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var h = hex.trimmingCharacters(in: .whitespaces); if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    /// The relative luminance of a colour.
    public static func luminance(_ hex: String) -> Double {
        guard let c = rgb(hex) else { return 0 }
        func lin(_ x: Double) -> Double { x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// A colour at some opacity over another, as the colour that results (to check a text that is drawn with an alpha).
    public static func blend(_ fg: String, alpha: Double, over bg: String) -> String {
        guard let f = rgb(fg), let b = rgb(bg) else { return bg }
        func mix(_ x: Double, _ y: Double) -> Int { Int(((x * alpha + y * (1 - alpha)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", mix(f.r, b.r), mix(f.g, b.g), mix(f.b, b.b))
    }

    /// The WCAG contrast ratio of two colours, from 1 to 21.
    public static func contrast(_ a: String, _ b: String) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
