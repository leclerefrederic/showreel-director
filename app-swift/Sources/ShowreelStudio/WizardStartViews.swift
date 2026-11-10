import ShowreelKit
import SwiftUI

/// A new project in Wizard mode: Clap leads a short interview in the chat and proposes a starting pack as cards; the progress of the base configuration is on the left.
/// The rules (what is set, what Wizard needs, what the pack is) are ShowreelKit's; the way out to Manual keeps every answer.
struct WizardStartView: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HSplitView {
            left.frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
            ChatView().frame(minWidth: 420)
        }
        .onAppear { project.startWizardIfNeeded(chat: chat) }
    }

    private var left: some View {
        let f = project.showreel
        let p = f.map { ProjectSetup.progress($0) }
        let wiz = Availability.wizard(hasKey: settings.hasKey)
        let failed = chat.lastEnd?.isError == true
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Setting up with Clap").font(.title2.weight(.semibold))
                Text("Clap asks a few questions, then proposes a starting pack as cards: the base configuration, a look, the scenes and their order. Nothing is saved until you accept a card, and you can accept them one by one or all at once.")
                    .font(.callout).foregroundStyle(.secondary)
                if let p = p { Text(p.line).font(.headline) }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(f.map { ProjectSetup.requirements($0) } ?? []) { r in
                        Label(r.title, systemImage: r.isSet ? "checkmark.circle.fill" : "circle").foregroundStyle(r.isSet ? Color.green : Color.secondary).font(.callout)
                    }
                    Text("Audience, message and tone are optional.").fontSmall().foregroundStyle(.secondary)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                if let w = wiz.why {
                    notice(w.reason + ". " + w.way + ".", symbol: "key")
                } else if failed, let e = chat.lastEnd {
                    notice("Clap could not go on: \(e.text). Your answers are kept.", symbol: "exclamationmark.triangle")
                }
                HStack {
                    Button("Fill the form myself") { project.continueInManual() }.buttonStyle(SecondaryButtonStyle())
                        .help("Your answers so far become typed changes, and the setup goes on as a form. Manual projects stay Manual.")
                    if failed || !wiz.isAvailable {
                        Spacer(minLength: 0)
                    }
                }
                Text("The workspace opens by itself as soon as the base configuration is complete.").fontSmall().foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    private func notice(_ text: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.orange)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
