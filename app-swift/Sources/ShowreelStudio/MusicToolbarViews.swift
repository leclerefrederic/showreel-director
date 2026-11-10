import ShowreelKit
import SwiftUI

/// The music lane's toolbar (MT1): Beat, Bars, Sections and Drop show or hide their marks, Analyse runs the analysis again, and the track's name and tempo end the bar.
/// What each button may do, and why not, is ShowreelKit's `MusicToolbar`; a view only draws it.
struct MusicToolbarView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var project: ProjectModel

    private static let symbols: [MusicToolbarButton: String] = [.beat: "metronome", .bars: "rectangle.split.3x1", .sections: "rectangle.3.group", .drop: "arrow.down.to.line", .analyse: "waveform.badge.magnifyingglass"]

    var body: some View {
        let ctx = project.musicToolbarContext
        HStack(spacing: 10) {
            ForEach(MusicToolbarButton.allCases.filter { $0.isToggle }, id: \.self) { b in toggle(b, ctx) }
            analyse(ctx)
            Spacer(minLength: 8)
            if let t = MusicToolbar.trackSummary(file: project.showreel?.decisions.track?.file, music: project.music) {
                Text(MusicToolbar.shortName(t.name)).font(.system(size: theme.strip.font, weight: .semibold)).foregroundStyle(theme.strip.text).lineLimit(1).help(t.name)
                if let bpm = t.bpm { Text(bpm).font(.system(size: theme.strip.font).monospacedDigit()).foregroundStyle(theme.strip.dim) }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(theme.strip.ruler)
        .overlay(alignment: .top) { Rectangle().fill(theme.strip.line).frame(height: 1) }
        .foregroundStyle(theme.strip.text)
    }

    private func toggle(_ b: MusicToolbarButton, _ ctx: MusicToolbarContext) -> some View {
        let why = MusicToolbar.availability(b, ctx)
        return Toggle(isOn: Binding(get: { project.musicBar.isOn(b) }, set: { _ in project.toggleMusicMark(b) })) {
            HStack(spacing: 3) { Image(systemName: Self.symbols[b] ?? "circle"); Text(b.title).font(.system(size: 12)) }
        }
        .toggleStyle(.button)
        .disabledWithReason(why?.reason, way: why?.way)
        .help(Self.help(b))
    }

    private func analyse(_ ctx: MusicToolbarContext) -> some View {
        let why = MusicToolbar.availability(.analyse, ctx)
        let status = MusicToolbar.analyseStatus(analysing: project.analysing, notice: project.musicNotice)
        return HStack(spacing: 6) {
            Button { project.analyseTrack() } label: {
                HStack(spacing: 3) {
                    if status == .running { ProgressView().controlSize(.small) } else { Image(systemName: Self.symbols[.analyse] ?? "circle") }
                    Text(status == .running ? "Analysing\u{2026}" : "Analyse").font(.system(size: 12))
                }
            }
            .disabledWithReason(why?.reason, way: why?.way)
            .help("Finds the beats, bars, sections and drops of the track again. The current ones stay until the new result is written. It needs numpy and ffmpeg.")
            if case .failed(let r) = status {
                Label("Analysis failed", systemImage: "exclamationmark.triangle").font(.system(size: theme.strip.font)).foregroundStyle(theme.strip.section()).lineLimit(1).help(r + " The earlier result is kept.")
            }
        }
    }

    private static func help(_ b: MusicToolbarButton) -> String {
        switch b {
        case .beat: return "Show the beats. Scenes snap to the finest marks that are shown."
        case .bars: return "Show the bars."
        case .sections: return "Colour the sections of the track. Hover the top of the lane for a name."
        case .drop: return "Show the drops and key accents."
        case .analyse: return ""
        }
    }
}
