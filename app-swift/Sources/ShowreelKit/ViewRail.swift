import Foundation

/// The rail at the far left of the workspace: one entry per centre view that the top bar offered (Build, the project settings with its two parts), and the film. It replaces those
/// buttons and does what they did. The rules are here; the view only draws them.
public enum RailEntry: String, CaseIterable, Identifiable, Sendable {
    case film, look, build, project
    public var id: String { rawValue }
    public var title: String { switch self { case .film: return "Film"; case .look: return "Look"; case .build: return "Build"; case .project: return "Project" } }
    public var role: IconRole { switch self { case .film: return .railFilm; case .look: return .railLook; case .build: return .railBuild; case .project: return .railProject } }

    /// What the old top-bar button did, and so what the entry does.
    public enum Target: Equatable, Sendable {
        /// The viewer: the settings panel closes and the centre shows the film.
        case viewer
        /// The Build and preview view (the old Build button, which toggled it).
        case build
        /// The project settings panel on one of its two parts (the old Project settings button), the Look part showing the design board in the centre.
        case settings(look: Bool)
    }
    public var target: Target {
        switch self { case .film: return .viewer; case .build: return .build; case .look: return .settings(look: true); case .project: return .settings(look: false) }
    }

    /// The old Build button's help, and the entry's tooltip.
    public var help: String {
        switch self {
        case .film: return "The film: the viewer, with what you select"
        case .look: return "The project's global look: the design board in the centre, its settings on the right"
        case .build: return "Build the film, test it and play it"
        case .project: return "The project's parameters (audience, message, tone, languages, formats, duration, constraints)"
        }
    }

    /// Where the workspace is now: which entry is selected.
    public static func current(centreIsBuild: Bool, settingsOpen: Bool, settingsIsLook: Bool, centreIsChecks: Bool = false) -> RailEntry? {
        if settingsOpen { return settingsIsLook ? .look : .project }
        if centreIsBuild { return .build }
        return centreIsChecks ? nil : .film
    }

    /// Why an entry cannot be used now, and how to get out of it; nil when it can. The workspace is closed until the base configuration is complete (the rail is not shown then,
    /// and the one button that was there, "Workspace", says the same).
    public func unavailable(workspaceOpen: Bool, progressLine: String) -> Unavailable? {
        workspaceOpen ? nil : Unavailable(.notReady, reason: "The base configuration is not complete: " + progressLine, way: "Finish it, then open the workspace")
    }
}
