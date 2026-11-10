import Foundation

/// An icon by what it means, not by its picture: the views ask for a role and the one table below says which SF Symbol draws it, so that a later skin can change the pictures
/// and nothing else.
public enum IconRole: String, CaseIterable, Sendable {
    case statusNeedsAttention = "status.needsAttention", statusNotWritten = "status.notWritten", statusOutOfDate = "status.outOfDate"
    case statusLayoutWarning = "status.layoutWarning", statusToReview = "status.toReview", statusReady = "status.ready"
    case lockClosed = "lock.closed", lockOpen = "lock.open"
    case visibleOn = "visible.on", visibleOff = "visible.off"
    case railFilm = "rail.film", railBuild = "rail.build", railProject = "rail.project"
    case railInspector = "rail.inspector", railClap = "rail.clap"
    /// The two pictograms of the Film placement and the reset of the proportions: drawn by the theme (a small window with its regions), not SF Symbols; a skin can replace them.
    case layoutUnderPreview = "layout.underPreview", layoutFullWidth = "layout.fullWidth", resetLayout = "layout.reset"
    /// The run state of a scene during a Build.
    case runWaiting = "run.waiting", runWriting = "run.writing", runTesting = "run.testing", runRepairing = "run.repairing", runDone = "run.done", runFailed = "run.failed"
    case checks = "checks", checksAttention = "checks.attention"

    /// THE table: every role has one SF Symbol.
    public static let table: [IconRole: String] = [
        .statusNeedsAttention: "exclamationmark.circle.fill",
        .statusNotWritten: "circle.dashed",
        .statusOutOfDate: "arrow.triangle.2.circlepath.circle.fill",
        .statusLayoutWarning: "exclamationmark.triangle.fill",
        .statusToReview: "hammer.fill",
        .statusReady: "checkmark.circle.fill",
        .lockClosed: "lock.fill", .lockOpen: "lock.open",
        .visibleOn: "eye", .visibleOff: "eye.slash",
        .railFilm: "film", .railBuild: "hammer", .railProject: "slider.horizontal.3",
        .railInspector: "sidebar.right", .railClap: "sparkles",
        .layoutUnderPreview: "pictogram.filmUnderPreview", .layoutFullWidth: "pictogram.filmFullWidth", .resetLayout: "arrow.counterclockwise",
        .runWaiting: "circle.fill", .runWriting: "pencil", .runTesting: "checkmark.shield", .runRepairing: "wrench.and.screwdriver", .runDone: "checkmark", .runFailed: "xmark.octagon",
        .checks: "checkmark.seal", .checksAttention: "exclamationmark.triangle.fill",
    ]

    public var symbol: String { Self.table[self] ?? "questionmark.square" }
    /// A role drawn by the theme as a pictogram instead of an SF Symbol.
    public var isPictogram: Bool { symbol.hasPrefix("pictogram.") }

    public static func status(_ k: SceneStatusKind) -> IconRole {
        switch k {
        case .needsAttention: return .statusNeedsAttention
        case .notWritten: return .statusNotWritten
        case .outOfDate: return .statusOutOfDate
        case .layoutWarning: return .statusLayoutWarning
        case .toReview: return .statusToReview
        case .ready: return .statusReady
        }
    }
    public static var statusRoles: [IconRole] { SceneStatusKind.allCases.map { status($0) } }
}
