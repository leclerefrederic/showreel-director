import ShowreelKit
import SwiftUI

/// The project's design system as a visual board, read-only: what the viewer shows while the project settings are open on the look. The data is
/// `DesignBoard` (ShowreelKit); the live background and the animation sample are drawn by the engine, so every change in a look editor shows here at once.
struct DesignBoardView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared

    var body: some View {
        if let f = project.showreel {
            let b = DesignBoard.make(f)
            let pal = EnginePalette(stored: b.hasPalette ? f.decisions.palette : nil)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(project.title).font(.title2.weight(.semibold))
                        Text("Design system").font(.title3).foregroundStyle(.secondary)
                        Spacer()
                        Text("read-only: change it in the project settings").font(.caption).foregroundStyle(.tertiary)
                    }
                    palette(b)
                    HStack(alignment: .top, spacing: 16) {
                        specimen("Titles", b.titleFont, sample: b.sampleText, size: 44, f: f)
                        specimen("Text", b.textFont, sample: "A line of text reads like this, at the size a viewer sees it. Small words, plain and clear.", size: 17, f: f)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        card("Background", b.background.map { id in engine.catalogue?.backgrounds.first { $0.id == id }?.name ?? id } ?? "none chosen yet",
                             b.backgroundMood.map { "reacts like \($0)" } ?? "calm") {
                            if let id = b.background {
                                EngineThumb(token: "db" + id + pal.signature + (b.backgroundMood ?? "")) { await engine.backgroundFrames(id, mood: b.backgroundMood, palette: pal, store: project.store, size: EngineService.viewerSize) }
                            } else { empty("No background chosen: the film starts on the palette's background colour.") }
                        }
                        card("Animation and mood", b.sampleEffect, ([b.pack.map { "pack \($0)" }] + [b.moods.isEmpty ? nil : "mood " + b.moods.joined(separator: ", ")]).compactMap { $0 }.joined(separator: " · ").nonEmpty ?? "no pack or mood chosen yet: a default stands in") {
                            EngineThumb(token: "da" + b.sampleEffect + pal.signature + (b.titleFont ?? "") + b.sampleText) {
                                await engine.effectFrames(b.sampleEffect, palette: pal, font: b.titleFont ?? "", store: project.store, text: b.sampleText, size: EngineService.viewerSize)
                            }
                        }
                    }
                }
                .padding(24).frame(maxWidth: 980).frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            .task { await engine.start() }
            .onAppear { FontRegistry.shared.registerAll(); for a in project.assets where a.type == "font" { _ = AssetFonts.family(a, in: project.root) } }
        }
    }

    // MARK: pieces

    private func palette(_ b: DesignBoard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Palette").font(.headline)
            if b.swatches.isEmpty { empty("No palette chosen yet.") }
            else {
                HStack(spacing: 0) {
                    ForEach(Array(b.swatches.enumerated()), id: \.offset) { _, s in
                        VStack(alignment: .leading, spacing: 2) {
                            Spacer()
                            Text(s.role).font(.callout.weight(.semibold))
                            Text(s.hex).font(.caption.monospaced())
                        }
                        .foregroundColor(Color(hex: s.on)).padding(10)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading).background(Color(hex: s.hex))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.15)))
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(b.contrasts.enumerated()), id: \.offset) { _, c in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: c.level.symbol).foregroundStyle(c.level.color)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(c.title).font(.callout.weight(.medium))
                                Text(c.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func specimen(_ role: String, _ name: String?, sample: String, size: CGFloat, f: ShowreelFile) -> some View {
        let family = name.map { FontRegistry.shared.family($0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack { Text(role).font(.headline); Spacer(); Text(name ?? "not chosen yet").font(.callout).foregroundStyle(.secondary) }
            Text("Aa").font(family.map { Font.custom($0, size: 64) } ?? .system(size: 64)).lineLimit(1)
            Text(sample).font(family.map { Font.custom($0, size: size) } ?? .system(size: size)).lineLimit(4).fixedSize(horizontal: false, vertical: true)
            if let n = name { LicenceBadge(assessment: FontLicense.assess(name: n, assets: project.assets, store: project.store)) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func card<C: View>(_ title: String, _ headline: String, _ caption: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.headline); Spacer(); Text(headline).font(.callout).foregroundStyle(.secondary) }
            content().clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension String { var nonEmpty: String? { isEmpty ? nil : self } }
