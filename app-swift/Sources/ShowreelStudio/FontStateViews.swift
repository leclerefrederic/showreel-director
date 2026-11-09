import ShowreelKit
import SwiftUI

/// The state of a Look font: Needs files, Preview only or Embedded, the sentence that says what the film will do, and the one button that fixes it. The rules are ShowreelKit's
/// (`FontUse`, `Availability.addFontFiles`); this only draws them.
struct FontStateView: View {
    let family: String
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let s = FontUse.state(family, store: project.store)
        let a = Availability.addFontFiles(family, in: project.activity, store: project.store)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon(s)).foregroundStyle(color(s))
                Text(FontUse.label(s)).font(.caption.weight(.semibold)).foregroundStyle(color(s))
            }
            Text(FontUse.line(s)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if case .embedded = s {} else {
                Button("Add the font files") { project.addFontFiles(family) }.controlSize(.small)
                    .disabledWithReason(a.reasonText, way: a.wayText, caption: !a.isAvailable)
            }
        }
    }

    private func icon(_ s: FontUse.State) -> String { switch s { case .needsFiles: return "exclamationmark.triangle.fill"; case .previewOnly: return "eye"; case .embedded: return "checkmark.seal.fill" } }
    private func color(_ s: FontUse.State) -> Color { switch s { case .needsFiles: return .orange; case .previewOnly: return .gray; case .embedded: return .green } }
}

/// The card of Add font files: the font, where it comes from, the licence, the files and their size, the network, and what accepting means.
struct FontOfferSheet: View {
    let pending: PendingFontOffer
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(pending.offer.card.title, systemImage: "textformat").font(.headline)
            VStack(alignment: .leading, spacing: 8) { ForEach(Array(pending.offer.card.changes.enumerated()), id: \.offset) { _, c in ChangeRow(change: c) } }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { project.fontOffer = nil }.keyboardShortcut(.cancelAction)
                Button("Download and approve") { project.confirmFontOffer() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 520)
    }
}

/// The question before a build when a font of the Look has no file: nothing is downloaded until "Download and continue".
struct FontsAtBuildSheet: View {
    let pending: PendingFontsAtBuild
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(pending.question.card.title, systemImage: "textformat").font(.headline)
            Text("These fonts have no file in the project, so the built reel would use a system font. It looks different and can vary between computers.").font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) { ForEach(Array(pending.question.card.changes.prefix(4).enumerated()), id: \.offset) { _, c in ChangeRow(change: c) } }
            HStack {
                Button("Cancel", role: .cancel) { project.answerFonts(.cancel) }.keyboardShortcut(.cancelAction).help("Nothing is downloaded and the build does not start")
                Spacer()
                Button("Continue with a system font") { project.answerFonts(.systemFont) }.help("The build starts now; the Fonts step stays orange and says so")
                Button("Download and continue") { project.answerFonts(.download) }.buttonStyle(.borderedProminent).help("Downloads the files, approves them for the reel, then starts")
            }
        }
        .padding(20).frame(width: 560)
    }
}
