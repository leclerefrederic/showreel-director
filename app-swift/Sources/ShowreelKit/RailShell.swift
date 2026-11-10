import Foundation

/// Where the Film strip lives: under the preview, in the centre column (the rail, the left panels and the right panel keep the full height), or along the whole bottom
/// (from the left panels to the right panel, the rail keeps the full height).
public enum FilmPlacement: String, Codable, CaseIterable, Sendable {
    case underPreview, fullWidth

    public var other: FilmPlacement { self == .underPreview ? .fullWidth : .underPreview }
    public var name: String { self == .underPreview ? "Film under the preview" : "Film at full width" }
    /// The tooltip and the accessibility value of the button: the state and the action.
    public var tooltip: String { self == .underPreview ? "Film under the preview. Click for full width" : "Film at full width. Click for under the preview" }
    /// The pictogram of the layout in use.
    public var role: IconRole { self == .underPreview ? .layoutUnderPreview : .layoutFullWidth }
}

/// The panels of the right side: exactly one is open at a time, or none.
public enum RightPanel: String, CaseIterable, Sendable { case inspector, look, project, clap }

public enum RailGroup: Int, Sendable { case centre, right }

/// The rail at the far left of the workspace, in two groups separated by a thin line: the centre views (Film, Build) and the right panels (Inspector, Look, Project, Clap).
/// A centre view and a right panel are independent. The rules are here; the views only draw them.
public enum RailEntry: String, CaseIterable, Identifiable, Sendable {
    case film, build, inspector, look, project, clap
    public var id: String { rawValue }
    public var group: RailGroup { switch self { case .film, .build: return .centre; default: return .right } }
    public var title: String {
        switch self { case .film: return "Film"; case .build: return "Build"; case .inspector: return "Inspector"; case .look: return "Look"; case .project: return "Project"; case .clap: return "Clap" }
    }
    public var role: IconRole {
        switch self { case .film: return .railFilm; case .build: return .railBuild; case .inspector: return .railInspector; case .look: return .railLook; case .project: return .railProject; case .clap: return .railClap }
    }
    /// The right panel an entry opens; nil for a centre view.
    public var panel: RightPanel? {
        switch self { case .inspector: return .inspector; case .look: return .look; case .project: return .project; case .clap: return .clap; default: return nil }
    }
    public static func entry(for p: RightPanel) -> RailEntry { switch p { case .inspector: return .inspector; case .look: return .look; case .project: return .project; case .clap: return .clap } }
    public static func entries(in g: RailGroup) -> [RailEntry] { allCases.filter { $0.group == g } }

    public var help: String {
        switch self {
        case .film: return "The film: the viewer, with what you select"
        case .build: return "Build the film, test it and play it"
        case .inspector: return "The inspector: what the selected scene or transition is made of, and its settings"
        case .look: return "The project's global look: the design board in the centre, its settings on the right"
        case .project: return "The project's parameters (audience, message, tone, languages, formats, duration, constraints)"
        case .clap: return "Ask Clap: the conversation, with what Clap knows, the sessions and the journal"
        }
    }

    /// The shortcut of an entry that has one (shown in its tooltip).
    public var shortcut: String? { self == .clap ? AppShortcuts.clapDisplay : nil }

    /// The accessibility label (VoiceOver reads it before the selected state): the name, plus what the entry carries (Clap's state, the Inspector's waiting selection).
    public func label(clap: ClapIndicator = ClapIndicator(working: false, proposals: 0), marked: Bool = false) -> String {
        switch self {
        case .clap: return clap.label
        case .inspector where marked: return "Inspector, a new selection is waiting"
        default: return title
        }
    }

    /// The tooltip, the same standard delay for the six: the name, what it does and its shortcut; when the entry cannot be used, the name, the reason and the way back instead.
    public func tooltip(clap: ClapIndicator = ClapIndicator(working: false, proposals: 0), marked: Bool = false, unavailable: Unavailable? = nil) -> String {
        let name = label(clap: clap, marked: marked)
        if let u = unavailable { return name + ". " + u.message }
        return name + ". " + help + (shortcut.map { " (\($0))" } ?? "")
    }

    /// The entry an arrow key reaches: the arrows move inside the group and wrap (Tab is what goes from one group to the other).
    public func neighbour(_ step: Int) -> RailEntry {
        let g = RailEntry.entries(in: group); guard let i = g.firstIndex(of: self) else { return self }
        return g[((i + step) % g.count + g.count) % g.count]
    }

    /// Why an entry cannot be used now, and how to get out of it; nil when it can. The workspace is closed until the base configuration is complete (the rail is not shown then).
    public func unavailable(workspaceOpen: Bool, progressLine: String) -> Unavailable? {
        workspaceOpen ? nil : Unavailable(.notReady, reason: "The base configuration is not complete: " + progressLine, way: "Finish it, then open the workspace")
    }
}

/// What the rail shows and what a click does: the centre view and the right panel are chosen separately.
public struct RailState: Equatable, Sendable {
    public var build = false
    /// The list of the checks is the centre (opened from its badge): no centre entry is selected.
    public var checks = false
    /// The right panel that is open; nil: the right side is closed.
    public var right: RightPanel? = .inspector
    /// A selection happened while another panel was open: the Inspector entry carries a small mark.
    public var inspectorMark = false
    public init(build: Bool = false, checks: Bool = false, right: RightPanel? = .inspector, inspectorMark: Bool = false) { self.build = build; self.checks = checks; self.right = right; self.inspectorMark = inspectorMark }

    /// The mark shows only while the Inspector is not the open panel (a mark on a lit entry says nothing).
    public var inspectorMarked: Bool { inspectorMark && right != .inspector }

    public func isSelected(_ e: RailEntry) -> Bool {
        switch e {
        case .film: return !build && !checks
        case .build: return build
        default: return e.panel == right
        }
    }

    /// A click on an entry. Film and Build never touch the right side; a right panel never touches the centre. The centre views never toggle off (a click on the active one does
    /// nothing; the other one is the way back); a right panel that is open closes when clicked again.
    public mutating func choose(_ e: RailEntry) {
        switch e {
        case .film: build = false; checks = false
        case .build: checks = false; build = true
        default:
            guard let p = e.panel else { return }
            right = right == p ? nil : p
            if right == .inspector { inspectorMark = false }
        }
    }

    /// The owner selected a scene or a transition. The Inspector shows it when no other panel is open; otherwise the open panel stays and the Inspector entry gets a mark.
    public mutating func selectionHappened() {
        if right == nil || right == .inspector { right = .inspector; inspectorMark = false } else { inspectorMark = true }
    }

    /// A Build starts: its panel is the centre and Clap opens on the right to show the conversation, whatever was open (it is never toggled closed).
    public mutating func buildStarted() { checks = false; build = true; open(.clap) }

    /// A panel is opened by something other than a click on its entry (Clap's shortcut, a link): it opens, it is never toggled closed.
    public mutating func open(_ p: RightPanel) { right = p; if p == .inspector { inspectorMark = false } }
}

/// The right side as the model keeps it (a closed flag, the settings panel Look or Project, Clap's tab) and the one panel it shows. Writing a panel always makes that panel the
/// visible one, from any state: a request for Clap while a settings panel covers it, or while the side is closed, opens it.
public struct RightSide: Equatable, Sendable {
    public enum Settings: Sendable { case look, project }
    public var closed = false, clap = false
    public var settings: Settings?
    public init(closed: Bool = false, clap: Bool = false, settings: Settings? = nil) { self.closed = closed; self.clap = clap; self.settings = settings }

    public var panel: RightPanel? {
        if closed { return nil }
        if let s = settings { return s == .look ? .look : .project }
        return clap ? .clap : .inspector
    }

    public mutating func show(_ p: RightPanel?) {
        switch p {
        case nil: closed = true; settings = nil
        case .inspector?: closed = false; settings = nil; clap = false
        case .clap?: closed = false; settings = nil; clap = true
        case .look?: closed = false; settings = .look
        case .project?: closed = false; settings = .project
        }
    }
}

/// What Clap's entry shows: whether the agent works, and how many proposals wait for the owner.
public struct ClapIndicator: Equatable, Sendable {
    public var working: Bool
    public var proposals: Int
    public init(working: Bool, proposals: Int) { self.working = working; self.proposals = proposals }

    public enum Motion: Equatable, Sendable { case none, pulse, dot }
    public func motion(reduceMotion: Bool) -> Motion { working ? (reduceMotion ? .dot : .pulse) : .none }
    public var badge: Int? { proposals > 0 ? proposals : nil }

    /// "Clap", "Clap, working", "Clap, 2 proposals waiting", "Clap, working, 1 proposal waiting": the tooltip and the accessibility label.
    public var label: String {
        var parts = ["Clap"]
        if working { parts.append("working") }
        if proposals > 0 { parts.append("\(proposals) proposal\(proposals == 1 ? "" : "s") waiting") }
        return parts.joined(separator: ", ")
    }
}

/// The keyboard shortcuts of the app that the views and the menus declare: one list, so that two actions never share one.
public enum AppShortcuts {
    public struct Shortcut: Equatable, Sendable { public let keys: String; public let action: String }
    /// "cmd+shift+a": modifiers in the order cmd, shift, option, control, then the key.
    public static let used: [Shortcut] = [
        .init(keys: "cmd+shift+l", action: "Project Library"), .init(keys: "cmd+z", action: "Undo"), .init(keys: "cmd+shift+z", action: "Redo"), .init(keys: "cmd+s", action: "Save the file being edited"),
        .init(keys: "cmd+shift+k", action: "Catalogue"), .init(keys: "cmd+-", action: "Zoom out"), .init(keys: "cmd+=", action: "Zoom in"), .init(keys: "cmd++", action: "Zoom in"),
        .init(keys: "cmd+0", action: "Fit the whole film"), .init(keys: "space", action: "Play and pause (over the strip)"), .init(keys: "cmd+,", action: "Settings"),
        .init(keys: "cmd+q", action: "Quit"), .init(keys: "cmd+w", action: "Close the window"), .init(keys: "cmd+h", action: "Hide"), .init(keys: "cmd+m", action: "Minimise"),
        .init(keys: "cmd+c", action: "Copy"), .init(keys: "cmd+v", action: "Paste"), .init(keys: "cmd+x", action: "Cut"), .init(keys: "cmd+a", action: "Select all"),
        .init(keys: clap.keys, action: clap.action),
    ]
    /// Opens Clap and puts the cursor in its input, from anywhere in the project window.
    public static let clap = Shortcut(keys: "cmd+shift+a", action: "Ask Clap")
    public static var clapDisplay: String { "Shift-Command-A" }
}

/// The geometry of the workspace under the top bar, for a window size: the rail, the left panels and the right panel, the preview and the Film strip, in both placements. Pure,
/// so that it is tested without a screen. The sizes the owner dragged are stored as they are (never changed by a placement or by a small window); they are clamped here, for drawing.
public enum ShellLayout {
    public static let rail = 60.0, gap = 6.0
    public static let minLeft = PanelLayout.minLibrary, minInspector = PanelLayout.minInspector, minSettings = PanelLayout.minSettings, minFilm = PanelLayout.minStrip
    public static let minPreviewHeight = 200.0, minLeftHeight = 260.0
    /// The standard proportions: what the reset puts back (the placement is not one of them).
    public static var standardSizes: PanelLayout { PanelLayout() }

    public static func minCentre(_ p: FilmPlacement) -> Double { p == .underPreview ? 420 : 360 }
    public static func rightMin(_ r: RightPanel?) -> Double { switch r { case nil: return 0; case .look?, .project?: return minSettings; default: return minInspector } }
    public static func rightStored(_ r: RightPanel?, _ s: PanelLayout) -> Double { switch r { case nil: return 0; case .look?, .project?: return s.settingsWidth; default: return s.inspectorWidth } }

    public struct Frames: Equatable, Sendable {
        public var rail, left, preview, film: CGRect
        public var right: CGRect?
        /// The widths and heights used for drawing (the stored ones, clamped).
        public var leftWidth, rightWidth, filmHeight: Double
        public var centreWidth: Double { Double(preview.width) }
    }

    /// The least window (under the top bar) that holds the workspace in a placement, with a right panel open or not.
    public static func minimumWindow(_ p: FilmPlacement, right: RightPanel? = .inspector) -> CGSize {
        let w = rail + minLeft + gap + minCentre(p) + (right == nil ? 0 : gap + rightMin(right)) + gap
        let h = p == .underPreview ? 2 * gap + max(minPreviewHeight + gap + minFilm, minLeftHeight) : 2 * gap + max(minPreviewHeight, minLeftHeight) + gap + minFilm
        return CGSize(width: w, height: h)
    }

    /// Whether a window is big enough (it cannot be resized below that).
    public static func isAllowed(_ window: CGSize, _ p: FilmPlacement, right: RightPanel?) -> Bool {
        let m = minimumWindow(p, right: right); return window.width >= m.width && window.height >= m.height
    }

    /// The frames of every region. Under the preview: the rail, the left panels and the right panel span the full height; the centre column holds the preview and, under it, the
    /// Film strip, as wide as the column. At full width: the strip spans from the left panels to the right panel along the bottom, the rail stays full height.
    public static func frames(window: CGSize, placement p: FilmPlacement, sizes s: PanelLayout, right: RightPanel?) -> Frames {
        let W = Double(window.width), H = Double(window.height)
        let avail = W - rail - gap                                   // the gap at the right edge
        let rStored = rightStored(right, s), hasRight = right != nil
        let gaps = gap + (hasRight ? gap : 0)
        let cMin = minCentre(p)
        let lw = max(minLeft, min(s.libraryWidth, avail - gaps - (hasRight ? rStored : 0) - cMin))
        let rw = hasRight ? max(rightMin(right), min(PaneWidth.clamp(rStored, for: right), avail - gaps - lw - cMin)) : 0
        let cw = max(0, avail - gaps - lw - rw)
        let usable = H - 2 * gap
        let top: Double, filmH: Double
        switch p {
        case .underPreview:
            filmH = max(minFilm, min(s.stripHeight, usable - gap - minPreviewHeight)); top = gap
        case .fullWidth:
            filmH = max(minFilm, min(s.stripHeight, usable - gap - max(minPreviewHeight, minLeftHeight))); top = gap
        }
        let cx = rail + lw + gap
        let railF = CGRect(x: 0, y: 0, width: rail, height: H)
        let rightF: CGRect? = hasRight ? CGRect(x: cx + cw + gap, y: top, width: rw, height: 0) : nil
        let out: Frames
        switch p {
        case .underPreview:
            let ph = usable - gap - filmH
            out = Frames(rail: railF, left: CGRect(x: rail, y: top, width: lw, height: usable), preview: CGRect(x: cx, y: top, width: cw, height: ph),
                         film: CGRect(x: cx, y: top + ph + gap, width: cw, height: filmH), right: rightF.map { CGRect(x: $0.minX, y: $0.minY, width: $0.width, height: usable) },
                         leftWidth: lw, rightWidth: rw, filmHeight: filmH)
        case .fullWidth:
            let upper = usable - gap - filmH
            out = Frames(rail: railF, left: CGRect(x: rail, y: top, width: lw, height: upper), preview: CGRect(x: cx, y: top, width: cw, height: upper),
                         film: CGRect(x: rail, y: top + upper + gap, width: W - rail - gap, height: filmH), right: rightF.map { CGRect(x: $0.minX, y: $0.minY, width: $0.width, height: upper) },
                         leftWidth: lw, rightWidth: rw, filmHeight: filmH)
        }
        return out
    }
}
