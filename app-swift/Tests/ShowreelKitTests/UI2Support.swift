import XCTest
@testable import ShowreelKit

/// A scene locked in a project made before UI2 has no copy of its look: it keeps following the project's look, as it did. Tests of that older behaviour strip the copy.
func stripLockedLook(_ store: ProjectStore, _ ids: [String]) throws {
    var f = try XCTUnwrap(store.loadShowreel())
    for i in f.scenes.indices where ids.contains(f.scenes[i].id) { f.scenes[i].lockedLook = nil }
    try store.save(f)
}
