import XCTest
@testable import ShowreelKit

/// A scene locked in a project made before UI2 has no copy of its look: it keeps following the project's look, as it did. Tests of that older behaviour strip the copy.
func stripLockedLook(_ store: ProjectStore, _ ids: [String]) throws {
    var f = try XCTUnwrap(store.loadShowreel())
    for i in f.scenes.indices where ids.contains(f.scenes[i].id) { f.scenes[i].lockedLook = nil }
    try store.save(f)
}

/// FIX1: a `ScrollView` whose content builder holds several views with no stack around them overlays them. This scan of the view sources lists each such place.
func scrollViewsWithSiblingViews(in text: String) -> [Int] {
    let lines = text.components(separatedBy: "\n")
    var found: [Int] = []
    for (i, l) in lines.enumerated() {
        guard l.range(of: #"ScrollView(\([^)]*\))? \{\s*$"#, options: .regularExpression) != nil else { continue }
        let base = l.prefix { $0 == " " }.count
        var views = 0, j = i + 1
        while j < lines.count {
            let t = lines[j], ind = t.prefix { $0 == " " }.count, s = t.trimmingCharacters(in: .whitespaces)
            j += 1
            if s.isEmpty { continue }
            if ind <= base && s.hasPrefix("}") { break }
            if ind == base + 4, !s.hasPrefix("."), !s.hasPrefix(")"), !s.hasPrefix("}"), !s.hasPrefix("//"), !s.hasPrefix("let "), !s.hasPrefix("var "), !s.hasPrefix("guard ") { views += 1 }
        }
        if views > 1 { found.append(i + 1) }
    }
    return found
}
