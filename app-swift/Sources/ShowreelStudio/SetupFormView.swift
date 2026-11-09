import ShowreelKit
import SwiftUI

/// A new project in Manual mode: the same form as the Project tab of the settings, with the look chosen here too. The workspace opens when the base configuration is complete
/// (the rule of phase P2); the button says what is still to set.
struct SetupFormView: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let f = project.showreel
        let missing = f.map { ProjectSetup.missing($0) } ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set up the project").font(.title2.weight(.semibold))
                    Text("Everything else depends on the choices marked Required, so they come first. The brief and the control level can wait.").font(.callout).foregroundStyle(.secondary)
                }
                ProjectForm(setup: true)
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Look").font(.headline); Text("Required").fontSmall(weight: .semibold).foregroundStyle(.orange).padding(.horizontal, 6).padding(.vertical, 1).background(Color.orange.opacity(0.14), in: Capsule()) }
                    row("Starting look") { StartingLookMenu() }
                    row("Palette") {
                        if let p = f?.decisions.palette, !p.isEmpty { Swatches(colours: p) } else { Text("not chosen yet").font(.callout).foregroundStyle(.secondary) }
                    }
                    row("Titles font") { FontMenu(role: .titleFont) }
                    row("Text font") { FontMenu(role: .textFont) }
                    row("Default background") { BackgroundMenu() }
                    Text("A starting look sets all of these at once; each can still be changed here or later in the project settings.").fontSmall().foregroundStyle(.secondary)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button("Open the workspace") { project.finishSetup() }.buttonStyle(PrimaryButtonStyle()).controlSize(.large)
                    .disabledWithReason(f == nil ? "This project has no data yet" : missing.isEmpty ? nil : "Still to set: " + missing.map { $0.title.lowercased() }.joined(separator: ", "),
                                        way: f == nil ? "Confirm the import or create it with the banner above" : "Set them above", caption: true)
            }
            .padding(28).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack { Text(label).font(.callout).frame(width: 150, alignment: .leading); content(); Spacer(minLength: 0) }
    }
}
