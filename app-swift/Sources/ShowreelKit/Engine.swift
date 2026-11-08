import AppKit
import Foundation
import WebKit

/// The four colours the engine draws with. In `decisions.palette` they are stored in this order.
public struct EnginePalette: Equatable, Sendable {
    public var bg: String, fg: String, accent: String, accent2: String
    /// Muted tone for secondary elements (the effects use it as a fifth role): by default halfway from the background to the text.
    public var mute: String
    public init(bg: String, fg: String, accent: String, accent2: String, mute: String? = nil) {
        self.bg = bg; self.fg = fg; self.accent = accent; self.accent2 = accent2
        self.mute = mute ?? EnginePalette.mix(bg, fg, 0.5)
    }

    /// The roles of a stored palette: background, text, accent, accent 2. Missing roles reuse a colour the film already has.
    public init(stored p: [String]?) {
        let l = (p ?? []).filter { EnginePalette.isHex($0) }
        bg = l.count > 0 ? l[0] : "#101820"
        fg = l.count > 1 ? l[1] : "#FFFFFF"
        accent = l.count > 2 ? l[2] : fg
        accent2 = l.count > 3 ? l[3] : accent
        mute = EnginePalette.mix(bg, fg, 0.5)
    }

    public static func rgb(_ h: String) -> [Double] {
        let s = h.dropFirst()
        return [0, 2, 4].map { Double(Int(s.dropFirst($0).prefix(2), radix: 16) ?? 0) }
    }

    /// `a` moved `t` of the way to `b`, as #RRGGBB.
    public static func mix(_ a: String, _ b: String, _ t: Double) -> String {
        guard isHex(a), isHex(b) else { return "#8A8A8A" }
        let x = rgb(a), y = rgb(b)
        return "#" + (0..<3).map { String(format: "%02X", Int((x[$0] + (y[$0] - x[$0]) * t).rounded())) }.joined()
    }

    public static func isHex(_ s: String) -> Bool { s.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil }

    public var json: [String: String] { ["bg": bg, "fg": fg, "accent": accent, "accent2": accent2, "mute": mute] }
}

public struct EngineEffect: Decodable, Identifiable, Equatable, Sendable {
    public let cat: String
    public let name: String
    public let desc: String
    public let energy: String
    public let dur: Double
    public var id: String { name }
}

public struct EngineBackground: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let family: String
    public let name: String
    public let desc: String
    public let animated: Bool
}

public struct EngineCatalogue: Decodable, Sendable {
    public let effects: [EngineEffect]
    public let backgrounds: [EngineBackground]
    public let moods: [String]
}

/// Builds the host page of the embedded engine: the skill's own JavaScript (core, kit, backgrounds and the effects), read from the
/// skill folder inside the app bundle, and a small API on top. Nothing is rewritten and nothing is fetched.
public enum EngineHost {
    /// The helpers every effect relies on (ease functions, text drawing, layers) live in the effects lab page of the skill, between
    /// two markers that build_effects_lab.py also relies on. The host reuses them, so the effects keep running on the skill's own code.
    static func preamble(from lab: String) throws -> String {
        guard let a = lab.range(of: "const clamp=(x,a=0,b=1)"), let b = lab.range(of: "/*__EFFECTS__*/", range: a.upperBound..<lab.endIndex) else {
            throw AgentError.msg("engine: the effects lab page no longer has the helper block the host reuses")
        }
        return String(lab[a.lowerBound..<b.lowerBound])
    }

    public static func pageHTML(engine: URL) throws -> String {
        func read(_ rel: String) throws -> String {
            guard let s = try? String(contentsOf: engine.appendingPathComponent(rel), encoding: .utf8) else { throw AgentError.msg("engine file missing: \(rel)") }
            return s
        }
        let fm = FileManager.default
        let effectFiles = ((try? fm.contentsOfDirectory(atPath: engine.appendingPathComponent("effects").path)) ?? []).filter { $0.hasSuffix(".js") }.sorted()
        guard !effectFiles.isEmpty else { throw AgentError.msg("engine: no effect files") }
        let effects = try effectFiles.map { try read("effects/" + $0) }.joined(separator: "\n")
        let helpers = try preamble(from: try read("effects-lab.html"))
        let host = try String(contentsOf: try hostScriptURL(), encoding: .utf8)
        return """
        <!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0">
        <script>\(try read("core.js"))</script>
        <script>\(try read("kit.js"))</script>
        <script>\(try read("backgrounds.js"))</script>
        <script>
        let FONT = 'sans-serif';
        \(helpers)
        \(effects)
        \(host)
        </script></body></html>
        """
    }

    static func hostScriptURL() throws -> URL {
        guard let u = resource("shared", dev: "app-swift/shared")?.appendingPathComponent("engine-host.js"), FileManager.default.fileExists(atPath: u.path) else {
            throw AgentError.msg("shared/engine-host.js not found")
        }
        return u
    }
}

/// Renders effects and backgrounds with the engine. One hidden web view, used by the pickers, the look board and the palette preview.
/// Frames come back as PNG data; the views cache them under `.studio/`.
@MainActor
public final class EngineRenderer: NSObject, WKNavigationDelegate {
    private let web: WKWebView
    private var loaded: CheckedContinuation<Void, Error>?
    private var isReady = false
    private var failure: Error?
    public private(set) var catalogue: EngineCatalogue?

    public override init() {
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 360), configuration: WKWebViewConfiguration())
        super.init()
        web.navigationDelegate = self
    }

    /// Loads the host page from the skill folder (the app bundle when packaged) and reads the catalogue.
    public func start() async throws {
        if isReady { return }
        guard let root = Skill.root() else { throw AgentError.msg("Skill folder not found") }
        let html = try EngineHost.pageHTML(engine: root.appendingPathComponent("engine"))
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            loaded = c
            web.loadHTMLString(html, baseURL: nil)
        }
        isReady = true
        let json = try await call("return studioEngine.catalogue()", [:]) as? String ?? ""
        catalogue = try JSONDecoder().decode(EngineCatalogue.self, from: Data(json.utf8))
    }

    public nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.loaded?.resume(); self.loaded = nil }
    }
    public nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.loaded?.resume(throwing: error); self.loaded = nil }
    }
    public nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.loaded?.resume(throwing: error); self.loaded = nil }
    }

    private func call(_ body: String, _ args: [String: Any]) async throws -> Any? {
        try await web.callAsyncJavaScript(body, arguments: args, in: nil, contentWorld: .page)
    }

    static func data(fromDataURL s: String) throws -> Data {
        guard let comma = s.firstIndex(of: ","), let d = Data(base64Encoded: String(s[s.index(after: comma)...])) else { throw AgentError.msg("engine returned no image") }
        return d
    }

    /// Makes a font family available to the engine (a data URL of a woff2, ttf or otf file).
    public func registerFont(family: String, dataURL: String) async throws {
        _ = try await call("await studioEngine.registerFont(family, url); return true", ["family": family, "url": dataURL])
    }

    /// One frame of an effect at time `t` seconds (the effect's own clock), as PNG.
    public func renderEffect(_ name: String, palette: EnginePalette, font: String, t: Double, text: String = "Simple. Fast. Yours.", size: CGSize = CGSize(width: 320, height: 180)) async throws -> Data {
        let r = try await call("return await studioEngine.renderEffect(name, pal, font, t, text, w, h)",
                               ["name": name, "pal": palette.json, "font": font, "t": t, "text": text, "w": Int(size.width), "h": Int(size.height)])
        guard let s = r as? String else { throw AgentError.msg("engine: no such effect \(name)") }
        return try Self.data(fromDataURL: s)
    }

    /// One frame of a background at time `t` seconds, as PNG. `params` is the options object of SRB.draw (mood, reduced, ...).
    public func renderBackground(_ id: String, params: [String: Any] = [:], palette: EnginePalette, t: Double, size: CGSize = CGSize(width: 320, height: 180)) async throws -> Data {
        let r = try await call("return await studioEngine.renderBackground(id, params, pal, t, w, h)",
                               ["id": id, "params": params, "pal": palette.json, "t": t, "w": Int(size.width), "h": Int(size.height)])
        guard let s = r as? String else { throw AgentError.msg("engine: no such background \(id)") }
        return try Self.data(fromDataURL: s)
    }

    /// `frames` frames covering the effect's duration (plus a short hold), for an animated thumbnail.
    public func effectStrip(_ name: String, palette: EnginePalette, font: String, frames: Int, text: String = "Simple. Fast. Yours.", size: CGSize = CGSize(width: 320, height: 180)) async throws -> [Data] {
        let r = try await call("return await studioEngine.effectStrip(name, pal, font, n, text, w, h)",
                               ["name": name, "pal": palette.json, "font": font, "n": frames, "text": text, "w": Int(size.width), "h": Int(size.height)])
        return try Self.strip(r)
    }

    public func backgroundStrip(_ id: String, params: [String: Any] = [:], palette: EnginePalette, frames: Int, seconds: Double = 4, size: CGSize = CGSize(width: 320, height: 180)) async throws -> [Data] {
        let r = try await call("return await studioEngine.backgroundStrip(id, params, pal, n, secs, w, h)",
                               ["id": id, "params": params, "pal": palette.json, "n": frames, "secs": seconds, "w": Int(size.width), "h": Int(size.height)])
        return try Self.strip(r)
    }

    /// Frames of an effect played over a background: what a look feels like.
    public func lookStrip(background: String, params: [String: Any] = [:], effect: String, palette: EnginePalette, font: String, frames: Int,
                          text: String = "Simple. Fast. Yours.", size: CGSize = CGSize(width: 320, height: 180)) async throws -> [Data] {
        let r = try await call("return await studioEngine.lookStrip(bg, params, name, pal, font, n, text, w, h)",
                               ["bg": background, "params": params, "name": effect, "pal": palette.json, "font": font, "n": frames, "text": text,
                                "w": Int(size.width), "h": Int(size.height)])
        return try Self.strip(r)
    }

    static func strip(_ r: Any?) throws -> [Data] {
        guard let s = r as? String, let a = (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String] else { throw AgentError.msg("engine returned no frames") }
        return try a.map { try data(fromDataURL: $0) }
    }

    /// Errors the engine raised while drawing (an effect that throws), for the self-test.
    public func errors() async throws -> [String] {
        let r = try await call("return JSON.stringify(studioEngine.errors())", [:]) as? String ?? "[]"
        return (try? JSONDecoder().decode([String].self, from: Data(r.utf8))) ?? []
    }
}
