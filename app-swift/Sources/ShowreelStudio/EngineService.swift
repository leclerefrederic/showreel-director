import AppKit
import CoreText
import CryptoKit
import ShowreelKit

/// The engine as the pickers use it: one renderer, fonts registered for it, and thumbnails cached under the project's `.studio/thumbs/`.
@MainActor
final class EngineService: ObservableObject {
    static let shared = EngineService()

    @Published private(set) var ready = false
    @Published private(set) var failure: String?
    private let renderer = EngineRenderer()
    private var starting: Task<Void, Never>?
    private var registeredFonts: Set<String> = []
    private lazy var engineStamp: String = {
        // the cache is valid for one version of the engine: skill version and fingerprint, plus the newest engine file in a dev run
        let dir = Skill.root()?.appendingPathComponent("engine")
        let newest = (try? FileManager.default.subpathsOfDirectory(atPath: dir?.path ?? ""))?.compactMap { rel -> Date? in
            dir.flatMap { try? $0.appendingPathComponent(rel).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        }.max()
        return "\(Skill.version() ?? "?")|\(Skill.fingerprint())|\(newest.map { String($0.timeIntervalSince1970) } ?? "")"
    }()

    var catalogue: EngineCatalogue? { renderer.catalogue }

    func start() async {
        if ready { return }
        if let t = starting { await t.value; return }
        let t = Task { @MainActor in
            do { try await renderer.start(); ready = true } catch { failure = error.localizedDescription }
        }
        starting = t
        await t.value
        starting = nil
    }

    // MARK: fonts

    /// Makes a font usable in engine renders, by the name chosen in the project. Returns the CSS family to draw with.
    func family(for name: String, store: ProjectStore) async -> String {
        guard !name.isEmpty else { return "sans-serif" }
        if registeredFonts.contains(name) { return name }
        var data: Data?, mime = "font/woff2"
        if let f = Look.freeFonts().first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }), let u = Look.previewURL(for: f) { data = try? Data(contentsOf: u) }
        else if let a = Assets.load(store).first(where: { $0.type == "font" && ($0.original + $0.file).lowercased().contains(name.lowercased().filter { $0.isLetter || $0.isNumber }) }) {
            let u = store.root.appendingPathComponent("assets/" + (a.file.isEmpty ? "source/" + a.original : a.file))
            data = try? Data(contentsOf: u)
            mime = ["ttf": "font/ttf", "otf": "font/otf", "woff": "font/woff"][u.pathExtension.lowercased()] ?? "font/woff2"
        }
        guard let d = data else { return "sans-serif" }
        do { try await renderer.registerFont(family: name, dataURL: "data:\(mime);base64," + d.base64EncodedString()); registeredFonts.insert(name); return name }
        catch { return "sans-serif" }
    }

    // MARK: cached frames

    private func key(_ parts: [String]) -> String {
        SHA256.hash(data: Data((parts + [engineStamp]).joined(separator: "\u{1}").utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func cached(_ store: ProjectStore, _ k: String, _ make: () async throws -> [Data]) async -> [NSImage] {
        let dir = store.root.appendingPathComponent(".studio/thumbs")
        let fm = FileManager.default
        if let names = try? fm.contentsOfDirectory(atPath: dir.path).filter({ $0.hasPrefix(k + "-") }).sorted(), !names.isEmpty {
            let imgs = names.compactMap { NSImage(contentsOf: dir.appendingPathComponent($0)) }
            if imgs.count == names.count { return imgs }
        }
        guard let frames = try? await make() else { return [] }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, d) in frames.enumerated() { try? d.write(to: dir.appendingPathComponent(String(format: "%@-%02d.jpg", k, i))) }
        return frames.compactMap { NSImage(data: $0) }
    }

    static let frameSize = CGSize(width: 320, height: 180)

    static let viewerSize = CGSize(width: 640, height: 360)

    private func tag(_ size: CGSize) -> String { "\(Int(size.width))" }

    func effectFrames(_ name: String, palette: EnginePalette, font: String, store: ProjectStore, text: String = "Simple. Fast. Yours.", size: CGSize = EngineService.frameSize) async -> [NSImage] {
        await start()
        let fam = await family(for: font, store: store)
        return await cached(store, key(["effect", name, palette.signature, fam, text, tag(size)])) {
            try await renderer.effectStrip(name, palette: palette, font: fam, frames: 10, text: text, size: size)
        }
    }

    func backgroundFrames(_ id: String, mood: String?, palette: EnginePalette, store: ProjectStore, size: CGSize = EngineService.frameSize) async -> [NSImage] {
        await start()
        var params: [String: Any] = [:]
        if let m = mood, !m.isEmpty { params["mood"] = m }
        return await cached(store, key(["background", id, mood ?? "", palette.signature, tag(size)])) {
            try await renderer.backgroundStrip(id, params: params, palette: palette, frames: 12, seconds: 4, size: size)
        }
    }

    func lookFrames(background: String, mood: String?, effect: String, palette: EnginePalette, font: String, store: ProjectStore, text: String, size: CGSize = EngineService.frameSize) async -> [NSImage] {
        await start()
        let fam = await family(for: font, store: store)
        var params: [String: Any] = [:]
        if let m = mood, !m.isEmpty { params["mood"] = m }
        return await cached(store, key(["look", background, mood ?? "", effect, palette.signature, fam, text, tag(size)])) {
            try await renderer.lookStrip(background: background, params: params, effect: effect, palette: palette, font: fam, frames: 12, text: text, size: size)
        }
    }

    /// A scene as the engine can show it today: its words with the project's effects pack, over the project's background, in the project's
    /// palette and title font. A scene has no layers yet (phase W4), so this is a stand-in that follows the global look.
    func sceneFrames(_ scene: ShowreelFile.Scene, file: ShowreelFile?, store: ProjectStore, size: CGSize = EngineService.frameSize) async -> [NSImage] {
        await start()
        let d = file?.decisions
        let palette = EnginePalette(stored: d?.palette)
        let font = d?.fonts?.titles ?? ""
        let line = scene.text.split(separator: "\n").first.map(String.init) ?? scene.texts.sorted { $0.key < $1.key }.first?.value ?? ""
        let text = String((line.trimmingCharacters(in: .whitespaces).isEmpty ? scene.id : line).prefix(60))
        let names = Look.packs().first { $0.name == (d?.effectsPack ?? d?.moods?.first ?? "") }?.effects ?? []
        let effect = names.first { n in catalogue?.effects.contains { $0.name == n } ?? true } ?? "Fade"
        if let bg = d?.background?.id, !bg.isEmpty, catalogue?.backgrounds.contains(where: { $0.id == bg }) ?? false {
            return await lookFrames(background: bg, mood: d?.background?.mood, effect: effect, palette: palette, font: font, store: store, text: text, size: size)
        }
        return await effectFrames(effect, palette: palette, font: font, store: store, text: text, size: size)
    }

    /// One still of an effect with a palette, not cached (the palette editor changes it while the user picks colours).
    func still(effect: String, palette: EnginePalette, font: String, store: ProjectStore, t: Double) async -> NSImage? {
        await start()
        let fam = await family(for: font, store: store)
        return (try? await renderer.renderEffect(effect, palette: palette, font: fam, t: t, size: CGSize(width: 480, height: 270))).flatMap { NSImage(data: $0) }
    }
}

extension EnginePalette {
    /// A stable text for cache keys (a dictionary would list its keys in any order).
    var signature: String { [bg, fg, accent, accent2, mute].joined(separator: ",") }
}
