import Foundation

/// The left panel of the workspace: the Storyboard on top and the Resources below, with a divider between them. Where the divider is, and whether the Resources are open,
/// collapsed to their header or opened to the whole height, is remembered per project (`PanelLayout`).
public enum LibrarySplit {
    public enum ResourcesState: String, Codable, Sendable { case open, collapsed, expanded }

    /// The Storyboard takes about two thirds of the height.
    public static let standard = 2.0 / 3.0
    public static let minFraction = 0.25, maxFraction = 0.85
    /// The header of a section, which stays when the section is collapsed, and the least height a section keeps.
    public static let header = 34.0
    public static let minStoryboard = 140.0, minResources = 90.0

    public static func clamp(_ f: Double) -> Double { min(max(f, minFraction), maxFraction) }

    /// The heights of the two sections for a panel of `total` points (the divider's own thickness is not counted). Collapsed: the Resources are only their header, the Storyboard
    /// has the rest. Expanded: the Storyboard is only its header (the toolbar stays), the Resources have the rest. Open: the fraction, with a floor for each.
    public static func heights(total: Double, fraction: Double, state: ResourcesState) -> (storyboard: Double, resources: Double) {
        let t = max(total, header * 2)
        switch state {
        case .collapsed: return (t - header, header)
        case .expanded: return (header, t - header)
        case .open:
            let floorS = min(minStoryboard, t - minResources), floorR = min(minResources, t - floorS)
            let s = min(max(t * clamp(fraction), floorS), t - floorR)
            return (s, t - s)
        }
    }

    /// The fraction a drag of the divider leaves: from the Storyboard's height at the start of the drag and the move, never out of the range.
    public static func fraction(total: Double, storyboardHeight: Double, moved: Double) -> Double {
        guard total > 0 else { return standard }
        return clamp((storyboardHeight + moved) / total)
    }
}

/// The badge of the top bar that replaces the Checks tab: how many items are red or orange (what the tab counted), and what to say when none is.
public enum CheckBadge {
    public enum Tone: Sendable { case clear, attention, problem }
    public struct Value: Equatable, Sendable {
        public let count: Int
        public let tone: Tone
        /// What the badge says and what its tooltip says.
        public let label: String
        public let help: String
    }

    public static func value(_ entries: [CheckEntry]) -> Value {
        let n = CheckPanel.attention(entries)
        guard n > 0 else { return Value(count: 0, tone: .clear, label: "Checks", help: "Nothing needs attention. Click to see every check.") }
        let red = entries.filter { $0.result.level == .fail }.count
        return Value(count: n, tone: red > 0 ? .problem : .attention, label: "Checks \(n)", help: "\(red) red and \(n - red) orange: click to see them, grouped, and to go to what each is about")
    }
}
