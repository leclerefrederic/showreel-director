import Foundation

/// The motion of the interface, defined once as numbers (no SwiftUI): durations, curves, the spring of the sliding panes, a speed scale and the rule of "Reduce motion". The views
/// never hold a duration or a curve of their own: they ask for a pattern by meaning (ShowreelStudio/Motion.swift maps these numbers to SwiftUI).
public struct MotionTokens: Equatable, Sendable {
    /// What a curve is, by the part it plays.
    public enum Curve: Equatable, Sendable {
        /// What arrives: it starts fast and settles (ease out).
        case decelerate
        /// What leaves: it starts slowly and goes (ease in).
        case accelerate
        /// A small overshoot, reserved for arrivals and confirmations.
        case overshoot
        /// The slight bounce of the sliding panes (Look, Project, Clap): a spring.
        case panelSpring
    }

    public struct Spring: Equatable, Sendable { public var response: Double; public var damping: Double }

    public var fast = 0.12, base = 0.2, slow = 0.3
    /// The spring of the panes the owner likes: the same feel as before it was a token.
    public var panel = Spring(response: 0.32, damping: 0.82)
    /// The overshoot of an arrival or a confirmation.
    public var confirm = Spring(response: 0.28, damping: 0.62)
    /// 1 by default; 0 turns every motion off; a skin may set another.
    public var speed = 1.0
    /// No motion for a direct action lasts longer than this.
    public static let directLimit = 0.3
    public static let standard = MotionTokens()

    public init() {}

    /// The patterns of the interface, by what they mean.
    public enum Pattern: String, CaseIterable, Sendable {
        /// The highlight of a selection slides from one row or frame to the next.
        case select
        /// An icon changes state: a short pulse.
        case stateChange
        /// A switch slides, an icon cross-fades with a tiny scale.
        case toggle
        /// A row or a frame arrives into the gap that opened for it.
        case arrive
        /// A row or a frame leaves and its gap closes.
        case depart
        /// Things move into their place (a reorder, a resize).
        case settle
        /// A control that refused shakes a little.
        case nudge
        /// A panel slides in or out.
        case panel
        /// A diamond pops when selected, a drop target lights up.
        case pop
    }

    /// What a pattern is: how long, with which curve, and whether it moves (otherwise it only fades).
    public struct Resolved: Equatable, Sendable {
        public var duration: Double
        public var curve: Curve
        /// False: the pattern is a short fade (or nothing): the information stays, the movement goes.
        public var moves: Bool
        public var isNone: Bool { duration == 0 }
    }

    /// The duration of a pattern before the speed scale.
    public func baseDuration(_ p: Pattern) -> Double {
        switch p {
        case .select, .arrive, .depart, .settle, .toggle: return base
        case .stateChange, .pop: return slow
        case .nudge: return base
        case .panel: return slow
        }
    }

    public func curve(_ p: Pattern) -> Curve {
        switch p {
        case .arrive: return .decelerate
        case .depart: return .accelerate
        case .stateChange, .pop, .nudge: return .overshoot
        case .panel: return .panelSpring
        case .select, .toggle, .settle: return .decelerate
        }
    }

    /// The one function that applies the speed scale and "Reduce motion": a speed of 0 gives none; Reduce motion turns every movement into a short fade (or nothing for a nudge, a
    /// pulse and a pop, which only move); a direct action never lasts more than `directLimit`.
    public func resolve(_ p: Pattern, reduceMotion: Bool) -> Resolved {
        guard speed > 0 else { return Resolved(duration: 0, curve: curve(p), moves: false) }
        if reduceMotion {
            switch p {
            case .nudge, .stateChange, .pop: return Resolved(duration: 0, curve: .decelerate, moves: false)
            default: return Resolved(duration: min(fast / speed, Self.directLimit), curve: .decelerate, moves: false)
            }
        }
        return Resolved(duration: min(baseDuration(p) / speed, Self.directLimit), curve: curve(p), moves: true)
    }
}

/// How a Build's scene shows its run state on its row and its frame: one label and one icon each, so that the state never depends on movement.
public enum RunAppearance: Equatable, Sendable {
    /// What the mark does while the state lasts; under Reduce motion every one of them is still (the label and the icon say it).
    public enum Motion: Equatable, Sendable { case still, pulse, sweep, alternate }

    public struct Look: Equatable, Sendable {
        public let label: String
        public let role: IconRole
        public let motion: Motion
        /// The mark is the whole icon of the row (a finished scene settles into its normal Status icon).
        public let replacesStatus: Bool
    }

    public static func look(_ s: SceneRun.State) -> Look {
        switch s {
        case .waiting: return Look(label: "Waiting", role: .runWaiting, motion: .still, replacesStatus: true)
        case .writing: return Look(label: "Writing", role: .runWriting, motion: .pulse, replacesStatus: true)
        case .testing: return Look(label: "Testing", role: .runTesting, motion: .sweep, replacesStatus: true)
        case .repairing: return Look(label: "Repairing", role: .runRepairing, motion: .alternate, replacesStatus: true)
        case .done: return Look(label: "Done", role: .runDone, motion: .still, replacesStatus: false)
        case .failed: return Look(label: "Failed", role: .runFailed, motion: .still, replacesStatus: true)
        }
    }
}
