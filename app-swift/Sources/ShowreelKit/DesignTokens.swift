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
        sizes: TypeSizes(small: 11, body: 13, title: 15, large: 22))

    /// Every colour with its name, for the tests and for the theme (a colour that is not here does not exist).
    public var colors: [(name: String, hex: String)] {
        [("canvas", surfaces.canvas), ("panel", surfaces.panel), ("raised", surfaces.raised), ("selected", surfaces.selected),
         ("hairline", borders.hairline), ("strong", borders.strong),
         ("textPrimary", text.primary), ("textSecondary", text.secondary), ("textFaint", text.faint),
         ("accent", accent), ("onAccent", onAccent),
         ("warning", roles.warning), ("danger", roles.danger), ("success", roles.success), ("review", roles.review), ("outOfDate", roles.outOfDate),
         ("laneScene", lanes.scene), ("laneSceneBorder", lanes.sceneBorder), ("laneMusic", lanes.music)]
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

    /// The WCAG contrast ratio of two colours, from 1 to 21.
    public static func contrast(_ a: String, _ b: String) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
