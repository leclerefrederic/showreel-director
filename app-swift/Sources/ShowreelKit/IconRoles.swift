import Foundation

/// An icon by what it means, not by its picture: the views ask for a role and the one table below says which SF Symbol draws it, so that a later skin can change the pictures
/// and nothing else.
public enum IconRole: String, CaseIterable, Sendable {
    case statusNeedsAttention = "status.needsAttention", statusNotWritten = "status.notWritten", statusOutOfDate = "status.outOfDate"
    case statusLayoutWarning = "status.layoutWarning", statusToReview = "status.toReview", statusReady = "status.ready"
    case lockClosed = "lock.closed", lockOpen = "lock.open"
    case visibleOn = "visible.on", visibleOff = "visible.off"
    case railFilm = "rail.film", railLook = "rail.look", railBuild = "rail.build", railProject = "rail.project"
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
        .railFilm: "film", .railLook: "paintpalette", .railBuild: "hammer", .railProject: "slider.horizontal.3",
        .checks: "checkmark.seal", .checksAttention: "exclamationmark.triangle.fill",
    ]

    public var symbol: String { Self.table[self] ?? "questionmark.square" }

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
