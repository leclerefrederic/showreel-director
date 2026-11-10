import ShowreelKit
import SwiftUI

/// A scene drawn from what its content says (W4): the items on screen at a time, with the colours the project's palette gives them, the images of its resources, over the project's
/// background. It never invents what the AI has not produced: an `auto` colour is drawn neutral, an `auto` animation is not drawn, and the picture says so ("AI decides").
struct StageThumb: View {
    let scene: ShowreelFile.Scene
    let time: Double
    var size: CGSize = EngineService.frameSize
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var theme: Theme
    @ObservedObject private var engine = EngineService.shared
    @State private var backdrop: [NSImage] = []

    private var frame: StageFrame { Stage.frame(of: scene, in: project.showreel, at: time) }

    private var backdropToken: String {
        let f = project.showreel
        return [scene.id, f?.effective(.background, for: scene) ?? "", f?.effective(.backgroundMood, for: scene) ?? "", f?.effective(.palette, for: scene) ?? "", "\(Int(size.width))"].joined(separator: "|")
    }

    var body: some View {
        let f = frame
        ZStack {
            backdropView(f)
            GeometryReader { g in stage(f, g.size) }
            if f.aiDecides { flag }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Stage.description(of: f, scene: scene))
        .help(Stage.description(of: f, scene: scene))
        .task(id: backdropToken) { await loadBackdrop() }
    }

    @ViewBuilder private func backdropView(_ f: StageFrame) -> some View {
        if !backdrop.isEmpty {
            Image(nsImage: backdrop[min(backdrop.count - 1, Int((time.truncatingRemainder(dividingBy: 4)) / 4 * Double(backdrop.count)))]).resizable().scaledToFill()
        } else {
            Rectangle().fill(f.backgroundHex.map { theme.color($0) } ?? theme.strip.bg)
        }
    }

    private func stage(_ f: StageFrame, _ s: CGSize) -> some View {
        VStack(spacing: s.height * 0.05) {
            if !f.images.isEmpty {
                HStack(spacing: s.width * 0.03) { ForEach(f.images, id: \.id) { image($0) } }
                    .frame(maxHeight: s.height * (f.texts.isEmpty ? 0.7 : 0.4))
            }
            ForEach(f.texts, id: \.id) { t in
                Text(t.text.isEmpty ? " " : t.text).font(.system(size: s.height * 0.13, weight: .semibold))
                    .foregroundStyle(t.colorHex.map { theme.color($0) } ?? theme.strip.white(0.9)).lineLimit(3).minimumScaleFactor(0.4).multilineTextAlignment(.center)
            }
        }
        .padding(s.width * 0.06).frame(width: s.width, height: s.height)
        .overlay(alignment: .bottomLeading) {
            if !f.sounds.isEmpty { Image(systemName: "waveform").foregroundStyle(theme.strip.white(0.8)).padding(4) }
        }
    }

    @ViewBuilder private func image(_ i: StageItem) -> some View {
        if let row = project.assets.first(where: { $0.id == i.resource }), let img = AssetFiles.thumbnail(row, in: project.root) {
            Image(nsImage: img).resizable().scaledToFit()
        } else {
            Image(systemName: "photo").resizable().scaledToFit().foregroundStyle(theme.strip.white(0.6))
        }
    }

    private var flag: some View {
        Label("AI decides", systemImage: "sparkles").fontSmall().padding(.horizontal, 6).padding(.vertical, 2).background(theme.raised.opacity(0.85), in: Capsule())
        .foregroundStyle(theme.textSecondary).padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private func loadBackdrop() async {
        guard let f = project.showreel else { backdrop = []; return }
        let bg = f.effective(.background, for: scene)
        guard !bg.isEmpty, engine.catalogue?.backgrounds.contains(where: { $0.id == bg }) ?? false else { backdrop = []; return }
        let pal = f.effective(.palette, for: scene).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        backdrop = await engine.backgroundFrames(bg, mood: f.effective(.backgroundMood, for: scene), palette: EnginePalette(stored: pal.isEmpty ? nil : pal), store: project.store, size: size)
    }
}
