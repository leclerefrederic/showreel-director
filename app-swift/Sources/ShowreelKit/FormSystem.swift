import Foundation

/// The one form system (DS3): the sizes every form field, icon row and chip uses, all on the spacing scale of the design tokens. Pure; the views draw it.
public enum FormLayout {
    /// The width of the icon slot of an icon and label row: every label in a column starts at the same x.
    public static let iconSlot = 24.0
    /// The width of the trailing slot that holds a switch: every switch ends at the same x.
    public static let trailingSlot = 40.0
    public static let labelGap = 8.0
    public static let fieldHeight = 28.0
    public static let fieldRadius = DesignTokens.graphite.radii.small
    public static let rhythm = 12.0
    public static let minFieldWidth = 96.0
    public static let chipHeight = 28.0
    /// A multi-line field grows with its text between these numbers of lines.
    public static let minLines = 2, maxLines = 8

    /// Every length of the form system, to check against the scale.
    public static var lengths: [Double] { [iconSlot, trailingSlot, labelGap, fieldHeight, rhythm, chipHeight] }

    /// The height of a multi-line field for a text: it grows with the lines up to `maxLines`; a scroll bar is only needed past that.
    public static func areaLines(for text: String, width: Double, charWidth: Double = 7) -> (lines: Int, scrolls: Bool) {
        let perLine = max(1, Int(width / charWidth))
        let count = text.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { $0 + max(1, ($1.count + perLine - 1) / perLine) }
        return (min(max(count, minLines), maxLines), count > maxLines)
    }
}

/// The rule of a numeric field with a stepper (the scene's Duration, the project's custom target): steps, fine and coarse steps, limits, rounding, clamping with a message.
public struct NumericField: Equatable, Sendable {
    public var step = 1.0, fine = 0.1, coarse = 5.0
    public var minimum = 0.1, maximum = 600.0
    /// Values are rounded to this precision (0.1 s) for display and storage.
    public var precision = 0.1

    public init(step: Double = 1, fine: Double = 0.1, coarse: Double = 5, minimum: Double = 0.1, maximum: Double = 600, precision: Double = 0.1) {
        self.step = step; self.fine = fine; self.coarse = coarse; self.minimum = minimum; self.maximum = maximum; self.precision = precision
    }

    public static let duration = NumericField()

    public enum Modifier: Sendable { case normal, fine, coarse }

    public func round(_ v: Double) -> Double { (v / precision).rounded() * precision }

    /// The text shown for a value: always rounded, no trailing zeros ("3", "2.5").
    public func display(_ v: Double) -> String { ProjectDocs.seconds(round(v)) }

    public struct Result: Equatable, Sendable {
        public let value: Double
        /// Said next to the field when a typed value had to be clamped; nil otherwise.
        public let message: String?
    }

    public func clamp(_ v: Double) -> Result {
        let r = round(v)
        if r < minimum { return Result(value: minimum, message: "The least is \(display(minimum)) s: it was set to that.") }
        if r > maximum { return Result(value: maximum, message: "The most is \(display(maximum)) s: it was set to that.") }
        return Result(value: r, message: nil)
    }

    /// One step from a value, up or down; Option is fine, Shift is coarse. At a limit it stays there (and says so).
    public func stepped(_ v: Double, up: Bool, _ m: Modifier = .normal) -> Result {
        let d: Double
        switch m { case .normal: d = step; case .fine: d = fine; case .coarse: d = coarse }
        return clamp(v + (up ? d : -d))
    }

    /// A typed text: a number (a comma is read), clamped with its message; nil value when it is not a number.
    public func typed(_ text: String) -> (result: Result?, error: String?) {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v.isFinite else { return (nil, "A duration is a number of seconds, such as 3 or 2.5.") }
        return (clamp(v), nil)
    }

    /// The key map of the stepper: Up and Down (key codes 126 and 125) step; Option makes the step fine and Shift coarse (Option wins if both are down). Anything else is not ours.
    public static func keyStep(keyCode: UInt16, option: Bool, shift: Bool) -> (up: Bool, modifier: Modifier)? {
        guard keyCode == 126 || keyCode == 125 else { return nil }
        return (keyCode == 126, option ? .fine : shift ? .coarse : .normal)
    }

    /// Whether a step in a direction is possible from a value (the chevron is disabled at a limit).
    public func canStep(_ v: Double, up: Bool) -> Bool { up ? round(v) < maximum : round(v) > minimum }
}

/// The model of a tab bar (DS3): the tabs, the selected one, the keyboard order. Exactly one tab is selected; the arrows move to the neighbour and wrap at the ends.
public struct TabBarModel<Tab: Hashable & Sendable>: Sendable {
    public let tabs: [Tab]
    public private(set) var selected: Tab

    public init?(tabs: [Tab], selected: Tab) {
        guard !tabs.isEmpty else { return nil }
        self.tabs = tabs
        self.selected = tabs.contains(selected) ? selected : tabs[0]
    }

    public var index: Int { tabs.firstIndex(of: selected) ?? 0 }
    public mutating func select(_ t: Tab) { if tabs.contains(t) { selected = t } }
    public mutating func next() { selected = tabs[(index + 1) % tabs.count] }
    public mutating func previous() { selected = tabs[(index + tabs.count - 1) % tabs.count] }
    public func isSelected(_ t: Tab) -> Bool { t == selected }
}

/// The widths of the right panels (DS3): wider by default, resizable between a least and a most. The stored width is clamped for drawing and never overwritten.
public enum PaneWidth {
    public static let inspectorMax = 720.0, settingsMax = 900.0
    public static func maximum(_ r: RightPanel?) -> Double { switch r { case nil: return 0; case .look?, .project?: return settingsMax; default: return inspectorMax } }
    public static func clamp(_ stored: Double, for r: RightPanel?) -> Double { r == nil ? 0 : max(ShellLayout.rightMin(r), min(stored, maximum(r))) }
}
