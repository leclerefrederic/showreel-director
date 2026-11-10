import Foundation

/// The three tabs of the project settings panel (PT1): the Brief, the Format (formats, target duration, on-screen languages) and the Look. The Project name and the base configuration
/// sit above the tabs. Pure: the panel draws it, the model stores the selection apart from the project's content.
public enum ProjectTab: String, CaseIterable, Identifiable, Sendable {
    case brief, format, look
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The tab where an item of the base configuration (`ProjectSetup.requirements`) is set: the look is the Look tab, the rest (film language, formats, target duration) is Format.
    public static func tab(forRequirement id: String) -> ProjectTab { id == "look" ? .look : .format }

    /// A stored tab: nothing, an older "project" (the one tab the panel had) or anything unknown is the Brief; "format" and "look" stay.
    public static func stored(_ s: String?) -> ProjectTab { s.flatMap { ProjectTab(rawValue: $0) } ?? .brief }
    /// What is written: nothing for the Brief (the default), the name otherwise.
    public var storedValue: String? { self == .brief ? nil : rawValue }

    /// The tab the panel opens on when it is opened without one asked for: the first with something unset in the base configuration, otherwise the one used last.
    public static func opening(_ f: ShowreelFile?, last: ProjectTab) -> ProjectTab {
        guard let f = f else { return last }
        for r in ProjectSetup.requirements(f) where !r.isSet { return tab(forRequirement: r.id) }
        return last
    }

    /// The model of the tab bar (arrow keys and wrap), with this tab selected.
    public func model() -> TabBarModel<ProjectTab> { TabBarModel(tabs: ProjectTab.allCases, selected: self)! }
}

/// The fields of the old Project form and the tab that holds each now, so that nothing is lost between the two layouts.
public enum ProjectFormMap {
    public enum Place: Equatable, Sendable { case aboveTabs, tab(ProjectTab) }
    public static let fields: [(name: String, place: Place)] = [
        ("Project name", .aboveTabs), ("Base configuration", .aboveTabs),
        ("Audience", .tab(.brief)), ("Message", .tab(.brief)), ("Tone", .tab(.brief)), ("Constraints", .tab(.brief)), ("Control level", .tab(.brief)),
        ("Formats", .tab(.format)), ("Target duration", .tab(.format)), ("Film languages", .tab(.format)),
    ]
}
