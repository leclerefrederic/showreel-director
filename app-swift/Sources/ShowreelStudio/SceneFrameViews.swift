import ShowreelKit
import SwiftUI

/// The picture of a scene in the strip and in the inspector (W4b): the PNG captured from the real scene, the same PNG with a mark when it is out of date, or a plain placeholder that says
/// why there is no picture and how to get one. The state is ShowreelKit's `SceneThumbs.State`, derived from the files; this only draws it.
struct SceneFrameImage: View {
    let scene: ShowreelFile.Scene
    /// The inspector's larger picture: the placeholder shows its reason in words.
    var large = false
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var theme: Theme

    private var state: SceneThumbs.State { project.sceneThumbs[scene.id] ?? .placeholder(reason: "The picture of this scene is being prepared.") }

    var body: some View {
        let s = state
        ZStack {
            if let u = s.url, let img = SceneImageCache.image(u) {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                placeholder(s)
            }
            if case .stale = s { staleMark }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.describe(scene, s))
        .help(Self.describe(scene, s))
    }

    static func describe(_ scene: ShowreelFile.Scene, _ s: SceneThumbs.State) -> String {
        switch s {
        case .fresh: return "Picture of \(scene.label), captured from the built film."
        case .stale(_, let why, _): return "Out of date. " + why
        case .placeholder(let r): return "No picture for \(scene.label). " + r
        case .failed(let r): return "The picture of \(scene.label) could not be captured: " + r + " Use Refresh thumbnail to try again."
        }
    }

    private func placeholder(_ s: SceneThumbs.State) -> some View {
        let first = scene.text.split(separator: "\n").first.map(String.init) ?? scene.content.first(where: { $0.type == "text" })?.text ?? ""
        return ZStack {
            Rectangle().fill(theme.strip.black(0.35))
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: { if case .failed = s { return "exclamationmark.triangle" } else { return "photo" } }())
                    Text("\(scene.id) \u{00B7} \(scene.durationLabel)").lineLimit(1)
                }
                .fontSmall(weight: .semibold)
                if !first.isEmpty { Text(first).fontSmall().lineLimit(large ? 3 : 1) }
                if large, let r = reason(s) { Text(r).fontSmall().multilineTextAlignment(.center) }
            }
            .foregroundStyle(theme.strip.white(0.85)).padding(6)
        }
    }

    private func reason(_ s: SceneThumbs.State) -> String? {
        switch s { case .placeholder(let r): return r; case .failed(let r): return "Capture failed: " + r; default: return nil }
    }

    private var staleMark: some View {
        Image(systemName: "clock.badge.exclamationmark").font(.system(size: large ? 14 : 10)).padding(large ? 5 : 3)
            .background(theme.strip.black(0.7), in: Circle()).foregroundStyle(theme.strip.white())
            .padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

/// The decoded pictures, by file: a strip of thirty frames reads each PNG once.
enum SceneImageCache {
    private static let cache = NSCache<NSURL, NSImage>()
    static func image(_ u: URL) -> NSImage? {
        if let i = cache.object(forKey: u as NSURL) { return i }
        guard let i = NSImage(contentsOf: u) else { return nil }
        cache.setObject(i, forKey: u as NSURL); return i
    }
}

/// The inspector's picture of the scene, larger, with the way to refresh it.
struct SceneFramePanel: View {
    let scene: ShowreelFile.Scene
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let why = SceneThumbs.refreshAvailability(project.sceneThumbs[scene.id], activity: project.activity).why
        VStack(alignment: .leading, spacing: 6) {
            SceneFrameImage(scene: scene, large: true).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button { project.refreshThumbnail(scene.id) } label: { Label("Refresh thumbnail", systemImage: "arrow.clockwise") }
                .buttonStyle(.borderless).fontSmall()
                .disabledWithReason(why.map { $0.reason }, way: why?.way, caption: true)
        }
    }
}
