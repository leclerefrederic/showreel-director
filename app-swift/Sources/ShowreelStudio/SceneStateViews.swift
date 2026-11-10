import ShowreelKit
import SwiftUI

/// "Lock all validated": one card for the Validated scenes of the library; absent when there is none.
struct LockAllValidatedButton: View {
    var short = false
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let op = project.showreel.flatMap { SceneStates.lockAllValidated($0) }
        Button { if let op = op { project.perform(op) } } label: { Label(short ? "Lock all" : "Lock all ready", systemImage: "lock") }
            .disabledWithReason(op == nil ? "No Ready scene to lock" : nil)
            .help(op == nil ? "No Ready scene to lock" : "Lock every Ready scene: frozen in time and space, nothing in them or before them can change until you unlock them.")
    }
}

/// The warning a card carries when a change of the global look would redraw locked scenes. The words are ShowreelKit's.
struct LockedLookNotice: View {
    @EnvironmentObject var theme: Theme
    let warning: LockedLookWarning

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(warning.headline, systemImage: "lock.fill").font(.callout.weight(.semibold))
            Text(warning.advice).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// The card of a global look change that touches locked scenes: before and after, the warning, then Apply anyway or Cancel.
struct LockedLookSheet: View {
    let pending: PendingLookChange
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(pending.card.title, systemImage: "paintpalette").font(.headline)
            VStack(alignment: .leading, spacing: 8) { ForEach(Array(pending.card.changes.enumerated()), id: \.offset) { _, c in ChangeRow(change: c) } }
            if let w = pending.card.lockWarning { LockedLookNotice(warning: w) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { project.cancelPendingLook() }.keyboardShortcut(.cancelAction)
                Button("Apply anyway") { project.confirmPendingLook() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20).frame(width: 420)
    }
}
