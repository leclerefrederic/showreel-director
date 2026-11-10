import AppKit
import XCTest
@testable import ShowreelKit

/// Decodes a PNG or JPEG into 8-bit RGB and counts what is in it.
struct Pixels {
    let width: Int, height: Int
    var rgb: [(Int, Int, Int)] = []
    init?(_ data: Data) {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        width = rep.pixelsWide; height = rep.pixelsHigh
        for y in 0..<height { for x in 0..<width {
            guard let c = rep.colorAt(x: x, y: y) else { continue }   // raw values: no colour-space conversion
            rgb.append((Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded())))
        } }
    }
    /// Number of distinct colours, merging colours that differ by less than 16 levels.
    var colours: Set<Int> { Set(rgb.map { ($0.0 / 16) << 8 | ($0.1 / 16) << 4 | ($0.2 / 16) }) }
    /// Fraction of pixels within `tolerance` levels of the given colour on every channel.
    func share(of hex: String, tolerance: Int = 10) -> Double {
        let t = EnginePalette.rgb(hex).map { Int($0) }
        let n = rgb.filter { abs($0.0 - t[0]) <= tolerance && abs($0.1 - t[1]) <= tolerance && abs($0.2 - t[2]) <= tolerance }.count
        return Double(n) / Double(max(1, rgb.count))
    }
}

/// The engine bridge (docs/Claude/studio-spec.md, section 6): the skill's own JavaScript, run in a web view from the skill folder only.
@MainActor
final class EngineTests: XCTestCase {
    static var shared: EngineRenderer?

    func engine() async throws -> EngineRenderer {
        if let e = Self.shared { return e }
        let e = EngineRenderer()
        try await e.start()
        Self.shared = e
        return e
    }

    let pal = EnginePalette(bg: "#101820", fg: "#FFFFFF", accent: "#F2AA4C", accent2: "#4CC2F2")

    func testTheHostPageBuildsFromTheSkillFilesOnly() throws {
        let root = try XCTUnwrap(Skill.root())
        let html = try EngineHost.pageHTML(engine: root.appendingPathComponent("engine"))
        XCTAssertTrue(html.contains("SRB") && html.contains("fx(") && html.contains("studioEngine"))
        XCTAssertFalse(html.contains("http://") && html.contains("<script src"), "no external script")
        XCTAssertFalse(html.contains("<script src"), "everything is inline: nothing is loaded from outside the bundle")
    }

    func testTheCatalogueIsTheSkillsCatalogue() async throws {
        let e = try await engine()
        let c = try XCTUnwrap(e.catalogue)
        XCTAssertGreaterThanOrEqual(c.effects.count, 240, "the 248 effects of the skill")
        XCTAssertGreaterThanOrEqual(c.backgrounds.count, 20)
        XCTAssertTrue(c.effects.contains { $0.name == "Pop" })
        XCTAssertEqual(Set(c.moods), ["punch", "playful", "tech", "clean", "cinematic", "deadpan"])
        XCTAssertTrue(c.backgrounds.contains { $0.id == "solid" })
        // the same count as the skill's own index
        let idx = try String(contentsOf: try XCTUnwrap(Skill.root()).appendingPathComponent("references/effects-index.md"), encoding: .utf8)
        XCTAssertTrue(idx.contains("\(c.effects.count)"), "effects-index.md counts \(c.effects.count) effects")
    }

    func testAnEffectRendersSomething() async throws {
        let e = try await engine()
        let png = try await e.renderEffect("Pop", palette: pal, font: "Helvetica", t: 0.9, size: CGSize(width: 320, height: 180))
        let px = try XCTUnwrap(Pixels(png))
        XCTAssertEqual(px.width, 320); XCTAssertEqual(px.height, 180)
        XCTAssertGreaterThan(px.colours.count, 3, "not a flat image")
        XCTAssertGreaterThan(px.share(of: pal.bg), 0.5, "the palette's background fills the frame")
        XCTAssertGreaterThan(px.share(of: pal.fg), 0.003, "the text is drawn in the palette's text colour")
        // another palette gives another picture: the engine really uses the colours it is given
        let other = try await e.renderEffect("Pop", palette: EnginePalette(bg: "#FFFFFF", fg: "#000000", accent: "#FF0000", accent2: "#00FF00"), font: "Helvetica", t: 0.9)
        XCTAssertNotEqual(png, other)
        let otherPx = try XCTUnwrap(Pixels(other))
        XCTAssertGreaterThan(otherPx.share(of: "#FFFFFF"), 0.5)
        // and it moves: the first and the settled frame differ
        let early = try await e.renderEffect("Pop", palette: pal, font: "Helvetica", t: 0.0)
        XCTAssertNotEqual(early, png)
    }

    func testABackgroundRendersSomething() async throws {
        let e = try await engine()
        let png = try await e.renderBackground("duotone", palette: pal, t: 0)
        let px = try XCTUnwrap(Pixels(png))
        XCTAssertGreaterThan(px.colours.count, 1)
        XCTAssertGreaterThan(px.share(of: pal.bg), 0.4)
        let solidPNG = try await e.renderBackground("solid", palette: pal, t: 0)
        let solid = try XCTUnwrap(Pixels(solidPNG))
        XCTAssertGreaterThan(solid.share(of: pal.bg), 0.98, "a solid background is the palette's background colour")
        // an animated background changes with time
        let anim = try XCTUnwrap(e.catalogue?.backgrounds.first { $0.animated })
        let a = try await e.renderBackground(anim.id, palette: pal, t: 0.0)
        let b = try await e.renderBackground(anim.id, palette: pal, t: 1.7)
        XCTAssertNotEqual(a, b, "\(anim.id) is animated")
        let calm = try await e.renderBackground(anim.id, params: ["reduced": true], palette: pal, t: 1.7)
        let calm0 = try await e.renderBackground(anim.id, params: ["reduced": true], palette: pal, t: 0.2)
        XCTAssertEqual(calm, calm0, "reduced motion freezes it")
    }

    func testStripsGiveAnimatedFrames() async throws {
        let e = try await engine()
        let eff = try await e.effectStrip("Slam", palette: pal, font: "Helvetica", frames: 8, size: CGSize(width: 160, height: 90))
        XCTAssertEqual(eff.count, 8)
        XCTAssertGreaterThan(Set(eff).count, 4, "the frames differ: it is an animation")
        let bg = try await e.backgroundStrip("solid", palette: pal, frames: 4, size: CGSize(width: 160, height: 90))
        XCTAssertEqual(bg.count, 4)
    }

    func testEveryEffectAndBackgroundDrawsWithoutError() async throws {
        let e = try await engine()
        let c = try XCTUnwrap(e.catalogue)
        for ef in c.effects { _ = try await e.renderEffect(ef.name, palette: pal, font: "Helvetica", t: ef.dur * 0.6, size: CGSize(width: 64, height: 36)) }
        for b in c.backgrounds { _ = try await e.renderBackground(b.id, params: ["mood": "punch"], palette: pal, t: 0.8, size: CGSize(width: 64, height: 36)) }
        let errs = try await e.errors()
        XCTAssertEqual(errs, [], "the engine raised errors while drawing")
    }

    func testAFontCanBeRegisteredForTheEngine() async throws {
        let e = try await engine()
        let root = try XCTUnwrap(Skill.root())
        let woff = try Data(contentsOf: root.appendingPathComponent("engine/fonts-preview/anton.woff2"))
        try await e.registerFont(family: "StudioTestAnton", dataURL: "data:font/woff2;base64," + woff.base64EncodedString())
        let withFont = try await e.renderEffect("Fade", palette: pal, font: "StudioTestAnton", t: 1.2)
        let without = try await e.renderEffect("Fade", palette: pal, font: "Helvetica", t: 1.2)
        XCTAssertNotEqual(withFont, without, "the registered font is the one drawn")
    }
}
