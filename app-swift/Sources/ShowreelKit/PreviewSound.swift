import Foundation

/// Who owns the sound of the window: the preview of a resource, the assembled film, or nobody. Starting one stops the other, so two never play at once, and a preview
/// that is no longer the selected resource stops. The rule is here; the player objects only carry out the effects it returns.
public struct SoundOwnership: Equatable, Sendable {
    public enum Owner: Equatable, Sendable { case none, resource(String), film }
    public enum Effect: Equatable, Sendable { case stopFilm, stopPreview(String) }
    public private(set) var owner: Owner = .none
    public init() {}

    public mutating func startPreview(_ id: String) -> [Effect] {
        defer { owner = .resource(id) }
        switch owner {
        case .film: return [.stopFilm]
        case .resource(let other) where other != id: return [.stopPreview(other)]
        default: return []
        }
    }

    public mutating func startFilm() -> [Effect] {
        defer { owner = .film }
        if case .resource(let id) = owner { return [.stopPreview(id)] }
        return []
    }

    /// The preview or the film ended or was paused by its own control.
    public mutating func stopped(_ o: Owner) { if owner == o { owner = .none } }

    /// The selection changed: a preview of another resource (or of none) stops.
    public mutating func selectionChanged(to id: String?) -> [Effect] {
        if case .resource(let old) = owner, old != id { owner = .none; return [.stopPreview(old)] }
        return []
    }

    /// The window of the project went away, or the project changed: everything stops.
    public mutating func stopAll() -> [Effect] {
        defer { owner = .none }
        switch owner { case .film: return [.stopFilm]; case .resource(let id): return [.stopPreview(id)]; case .none: return [] }
    }
}

public extension Availability {
    /// The film's play controls while a resource is previewed in the centre: not active, with the reason and the way, so that two play controls never compete.
    static func playFilm(_ s: FilmBuild.Status, previewingResource: Bool) -> Availability {
        if previewingResource {
            return .unavailable(Unavailable(.busy, reason: "Previewing a resource", way: "Select a scene or close the preview to play the film"))
        }
        return play(s)
    }
}
