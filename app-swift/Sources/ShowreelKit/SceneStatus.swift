import Foundation

/// The six states of the Status column of a scene row, worst first. The first that applies is the icon; the tooltip lists every one that applies.
public enum SceneStatusKind: Int, CaseIterable, Sendable {
    case needsAttention, notWritten, outOfDate, layoutWarning, toReview, ready

    public var title: String {
        switch self {
        case .needsAttention: return "Needs attention"
        case .notWritten: return "Not written"
        case .outOfDate: return "Out of date"
        case .layoutWarning: return "Layout warning"
        case .toReview: return "To review"
        case .ready: return "Ready"
        }
    }
    public var symbol: String { IconRole.status(self).symbol }
    public enum Tone: Sendable { case red, grey, blue, yellow, orange, green }
    public var tone: Tone {
        switch self { case .needsAttention: return .red; case .notWritten: return .grey; case .outOfDate: return .blue; case .layoutWarning: return .yellow; case .toReview: return .orange; case .ready: return .green }
    }
    /// What the legend says each state means.
    public var meaning: String {
        switch self {
        case .needsAttention: return "The scene's code test failed: its file was removed and the film shows an empty frame."
        case .notWritten: return "No scene file yet: the film shows an empty frame with its ID."
        case .outOfDate: return "The scene changed since its file was written."
        case .layoutWarning: return "Text overlaps or runs off the screen (found by the scene's own test)."
        case .toReview: return "Not Ready yet, or a change was asked for: an earlier note, if there is one, is in the tooltip."
        case .ready: return "Ready, and its file is up to date."
        }
    }
}

/// What the status rule reads of a scene. The view collects it; the rule is here.
public struct SceneStatusInput: Sendable {
    public var scene: ShowreelFile.Scene
    /// The scene is in the film (visible). A hidden scene has no scene file to speak of: only its review state counts.
    public var visible: Bool
    /// The state of the scene's file in the version the film is assembled into; nil when there is none (no version yet).
    public var build: SceneModules.Status?
    /// The first error of the test the scene's file failed (the file was removed); nil when it did not fail.
    public var failedTest: String?
    public var warnings: Int
    public init(scene: ShowreelFile.Scene, visible: Bool = true, build: SceneModules.Status?, failedTest: String? = nil, warnings: Int = 0) {
        self.scene = scene; self.visible = visible; self.build = build; self.failedTest = failedTest; self.warnings = warnings
    }
}

public struct SceneStatus: Equatable, Sendable {
    public struct Line: Equatable, Sendable { public let kind: SceneStatusKind; public let text: String }
    /// The state that wins: the first that applies, worst first.
    public let kind: SceneStatusKind
    /// Every state that applies, worst first, each with its reason and the way to fix it.
    public let lines: [Line]
    /// Lines that are not states: a file edited by hand.
    public let extra: [String]
    public var tooltip: String { (lines.map { "\u{2022} " + $0.text } + extra.map { "\u{2022} " + $0 }).joined(separator: "\n") }
}

/// THE function that decides the Status icon, for the Storyboard list and the strip's frames alike.
public enum SceneStatuses {
    public static func status(_ i: SceneStatusInput) -> SceneStatus {
        let s = i.scene
        let locked = s.isLocked
        var lines: [SceneStatus.Line] = []
        var extra: [String] = []
        var fileOK = true
        if i.visible {
            if let why = i.failedTest {
                fileOK = false
                lines.append(.init(kind: .needsAttention, text: "Needs attention: its code test failed (\(why)); its file was removed and the film shows an empty frame. " + (locked ? "Locked: unlock it to rewrite it." : "Continue the Build to write it again.")))
            } else if i.build == nil || i.build?.state == .notGenerated {
                fileOK = false
                lines.append(.init(kind: .notWritten, text: "Not written: no scene file yet, the film shows an empty frame with its ID. " + (locked ? "Locked, so a Build leaves it empty: unlock it to write it." : "Build, or Generate it with the AI.")))
            } else if i.build?.state == .stale {
                fileOK = false
                lines.append(.init(kind: .outOfDate, text: locked ? "Out of date, locked: unlock it to rewrite it. Its content, length or look changed since its file was written."
                                                                 : "Out of date: its content, length or look changed since its file was written. Generate it again, or Build, to follow the change."))
            }
            if i.warnings > 0 {
                lines.append(.init(kind: .layoutWarning, text: "\(i.warnings) layout warning\(i.warnings == 1 ? "" : "s"): text overlaps or runs off the screen. Open the list from the Build tab, then Fix this scene, or ignore it if it is wanted."))
            }
            if i.build?.state == .upToDate, i.build?.moduleEdited == true, i.failedTest == nil {
                extra.append("Edited by hand: the file is not the one that was written. It is kept; generating it again overwrites your edit.")
            }
        }
        if s.state == .wip || s.state == .ditched {
            lines.append(.init(kind: .toReview, text: s.toModify ? "To review: you asked for a change: \u{201C}\(s.note)\u{201D}. Switch Ready on when it is done." : "To review: not Ready yet. Switch Ready on when you are satisfied with it."))
        } else if fileOK {
            lines.append(.init(kind: .ready, text: i.visible ? "Ready: you are satisfied with it and its file is up to date." : "Ready: you are satisfied with it (it is hidden, so the film has no file for it)."))
        }
        // a Ready scene whose file needs attention is not shown as Ready: the file's state is what is said, and the review state stays a line only when it is To review
        let sorted = lines.sorted { $0.kind.rawValue < $1.kind.rawValue }
        return SceneStatus(kind: sorted.first?.kind ?? .ready, lines: sorted, extra: extra)
    }

    /// The legend of the "?" button: the six states, then the eye and the lock.
    public static let legend: [(symbol: String, title: String, meaning: String)] =
        SceneStatusKind.allCases.map { ($0.symbol, $0.title, $0.meaning) } + [
            (IconRole.visibleOn.symbol, "Visible", "The scene is in the film. A crossed eye: it is hidden and listed under \u{201C}Not in the storyboard\u{201D}. Click to switch."),
            (IconRole.lockClosed.symbol, "Locked", "Frozen in time and space, visible or hidden: nothing in it changes, nothing before it can move it, and a Build never rewrites it. Only a Ready scene can be locked."),
        ]
}

/// The three switches of a scene and its Delete button: whether each can be used now, and when not, why and how to get out of it.
public enum SceneSwitches {
    public struct Switch: Equatable, Sendable {
        public let on: Bool
        /// What the switch does when it is flipped; nil when it cannot be used now.
        public let operation: ProjectOperation?
        public let unavailable: Unavailable?
    }

    static func building(_ s: ProjectActivity.Snapshot) -> Unavailable? { s.isBuilding ? Reasons.building : nil }

    public static func visible(_ s: ShowreelFile.Scene, in f: ShowreelFile, activity: ProjectActivity.Snapshot) -> Switch {
        let on = f.film.contains { $0.id == s.id }
        if let b = building(activity) { return Switch(on: on, operation: nil, unavailable: b) }
        if s.isLocked { return Switch(on: on, operation: nil, unavailable: Reasons.locked(s.id)) }
        return Switch(on: on, operation: .sceneEnabled(id: s.id, enabled: !on, montage: nil), unavailable: nil)
    }

    /// Ready on means you are satisfied with the scene; off means To review.
    public static func ready(_ s: ShowreelFile.Scene, activity: ProjectActivity.Snapshot) -> Switch {
        let on = s.state.isReviewed
        if let b = building(activity) { return Switch(on: on, operation: nil, unavailable: b) }
        if s.isLocked { return Switch(on: true, operation: nil, unavailable: Reasons.locked(s.id)) }
        return Switch(on: on, operation: .scene(id: s.id, SceneEdit(status: on ? SceneState.wip.rawValue : SceneState.validated.rawValue)), unavailable: nil)
    }

    /// Only a Ready scene can be locked; unlocking is always possible (with Undo).
    public static func locked(_ s: ShowreelFile.Scene, activity: ProjectActivity.Snapshot) -> Switch {
        if let b = building(activity) { return Switch(on: s.isLocked, operation: nil, unavailable: b) }
        if s.isLocked { return Switch(on: true, operation: .sceneLock(ids: [s.id], locked: false), unavailable: nil) }
        guard s.state == .validated else {
            return Switch(on: false, operation: nil, unavailable: Unavailable(.notReady, reason: SceneLock.makeReadyFirst, way: "Switch Ready on, then lock it"))
        }
        return Switch(on: false, operation: .sceneLock(ids: [s.id], locked: true), unavailable: nil)
    }

    /// Delete scene: refused on a locked scene and during a Build.
    public static func delete(_ s: ShowreelFile.Scene, activity: ProjectActivity.Snapshot) -> Switch {
        if let b = building(activity) { return Switch(on: false, operation: nil, unavailable: b) }
        if s.isLocked { return Switch(on: false, operation: nil, unavailable: Unavailable(.locked, reason: "\(s.id) is locked", way: "Unlock it first", link: .scene(s.id))) }
        return Switch(on: false, operation: .deleteScene(id: s.id), unavailable: nil)
    }

    /// The confirmation of a deletion: what is lost, and that Undo brings it back.
    public static func deletePrompt(_ s: ShowreelFile.Scene, losses: [String]) -> (title: String, message: String) {
        ("Delete scene \(s.label)?", "This deletes the scene for good" + (losses.isEmpty ? "." : ": it loses " + losses.joined(separator: ", ") + ".") + " \(s.id) is never given to another scene. Undo (Edit menu) brings it back.")
    }
}
