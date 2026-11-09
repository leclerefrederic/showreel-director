import Foundation

/// The checks of the project, grouped the way the Checks tab of the left panel shows them.
public enum CheckGroup: String, CaseIterable, Identifiable, Sendable {
    case project, resources, scenes, storyboard, music, build
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .project: return "slider.horizontal.3"
        case .resources: return "photo.on.rectangle"
        case .scenes: return "film"
        case .storyboard: return "film.stack"
        case .music: return "waveform"
        case .build: return "play.rectangle"
        }
    }
}

/// What a check points at: the thing to open to put it right.
public enum CheckTarget: Equatable, Sendable {
    case project                              // the project settings, parameters
    case look(LookSection)                    // the project settings, a look editor
    case resource(String)                     // one resource
    case resources                            // the Resources tab
    case scene(String, tab: String)           // a scene, on a tab of its inspector ("settings", "composition")
    case transition(from: String)             // the marker after a scene
    case music                                // the music, in the inspector
    case storyboard
    case build
}

public struct CheckEntry: Identifiable, Equatable, Sendable {
    public let result: CheckResult
    public let group: CheckGroup
    public let target: CheckTarget
    public var id: String { result.id }
}

public enum CheckPanel {
    /// The base of an id: a repeated one carries "#2".
    static func base(_ id: String) -> String { id.split(separator: "#").first.map(String.init) ?? id }

    public static func group(of r: CheckResult) -> CheckGroup {
        let b = base(r.id)
        if ["reel.music", "reel.starts", "reel.drop", "reel.calm", "reel.length"].contains(b) { return .music }
        switch r.block {
        case "project", "look": return .project
        case "resources": return .resources
        case "scene": return .scenes
        case "storyboard": return .storyboard
        case "build": return .build
        default: return .project
        }
    }

    static func firstScene(in text: String) -> String? {
        text.range(of: #"S\d{2,}[a-z]?"#, options: .regularExpression).map { String(text[$0]) }
    }

    /// The element to open for a check, from its id (and, for the checks that gather several, the first one that is wrong).
    public static func target(of r: CheckResult, file f: ShowreelFile?, assets: [AssetRow], status: [String: NodeStatus]) -> CheckTarget {
        let b = base(r.id)
        if b.hasPrefix("setup.") {
            let item = String(b.dropFirst(6))
            switch item { case "palette": return .look(.palette); case "fonts": return .look(.fonts); case "background": return .look(.background); default: return .project }
        }
        if b.hasPrefix("feasibility") { return .project }
        if b.hasPrefix("font.") { return .look(.fonts) }
        if b == "look.background" { return .look(.background) }
        if b == "look.effects" { return .look(.effects) }
        if b.hasPrefix("palette.") { return .look(.palette) }
        switch b {
        case "assets.hold": return assets.first { $0.status == "hold" }.map { .resource($0.id) } ?? .resources
        case "assets.files": return assets.first { status[$0.id] == .missing }.map { .resource($0.id) } ?? .resources
        case "assets.excluded": return assets.first { $0.status == "excluded" && $0.file.hasPrefix("prepared/") }.map { .resource($0.id) } ?? .resources
        case "assets.placeholder": return assets.first { $0.status == "placeholder" }.map { .resource($0.id) } ?? .resources
        case "storyboard.assets": return assets.first { !$0.sceneIDs.isEmpty && $0.status != "approved" && $0.status != "excluded" }.map { .resource($0.id) } ?? .resources
        case "storyboard.times":
            return f?.timeline().first { $0.length == nil }.map { .scene($0.scene.id, tab: "settings") } ?? .storyboard
        case "review.all":
            return f?.film.first { !$0.state.isReviewed }.map { .scene($0.id, tab: "settings") } ?? .storyboard
        case "reel.transition-length", "reel.transition-text": return firstScene(in: r.detail).map { .transition(from: $0) } ?? .storyboard
        case "reel.starts": return firstScene(in: r.detail).map { .scene($0, tab: "settings") } ?? .music
        case "reel.music", "reel.drop", "reel.calm", "reel.length": return .music
        case "reel.flashes": return .storyboard
        case "gate.interview": return .project
        case "gate.assets": return .resources
        case "gate.style": return .look(.looks)
        case "gate.storyboard", "gate.review": return .storyboard
        default: break
        }
        if b.hasPrefix("reading."), let s = firstScene(in: b) { return .scene(s, tab: "composition") }
        if b.hasPrefix("content."), let s = firstScene(in: b) { return .scene(s, tab: "composition") }
        if b.hasPrefix("review."), let s = firstScene(in: b) { return .scene(s, tab: "settings") }
        if b.hasPrefix("build.") || b.hasPrefix("gate.") && ["build", "verify", "publish"].contains(String(b.dropFirst(5))) { return .build }
        switch group(of: r) {
        case .project: return .project
        case .resources: return .resources
        case .scenes, .storyboard: return .storyboard
        case .music: return .music
        case .build: return .build
        }
    }

    /// Every check of every area as an entry with its group and its target.
    public static func entries(_ byArea: [String: [CheckResult]], file: ShowreelFile?, assets: [AssetRow], status: [String: NodeStatus]) -> [CheckEntry] {
        let order = ["project", "look", "resources", "scene", "storyboard", "build"]
        let areas = order.filter { byArea[$0] != nil } + byArea.keys.filter { !order.contains($0) }.sorted()
        var seen = Set<String>()
        var out: [CheckEntry] = []
        for a in areas { for r in byArea[a] ?? [] where seen.insert(r.id).inserted { out.append(CheckEntry(result: r, group: group(of: r), target: target(of: r, file: file, assets: assets, status: status))) } }
        return out
    }

    /// The checks that need attention: red or orange. Grey (not enough data yet) and green do not count.
    public static func attention(_ e: [CheckEntry]) -> Int { e.filter { $0.result.level == .fail || $0.result.level == .tight }.count }

    /// The entries by group, in the order of the tab, each group worst first; a group with no check is left out.
    public static func grouped(_ e: [CheckEntry]) -> [(group: CheckGroup, entries: [CheckEntry])] {
        CheckGroup.allCases.compactMap { g in
            let list = e.filter { $0.group == g }
            guard !list.isEmpty else { return nil }
            return (g, list.enumerated().sorted { ($0.element.result.level, -$0.offset) > ($1.element.result.level, -$1.offset) }.map { $0.element })
        }
    }
}
