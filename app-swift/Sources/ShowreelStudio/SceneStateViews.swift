import ShowreelKit
import SwiftUI

/// How a scene state is drawn, everywhere the same: the list, the tree's header, the reel, the inspector. The rules (what each state reaches, what a lock
/// refuses) are ShowreelKit's `SceneState`, `SceneStates` and `SceneLock`; this only gives them an icon and a colour.
extension ShowreelFile.Scene {
    var statusSymbol: String {
        switch state {
        case .wip: return toModify ? "pencil.circle.fill" : "circle.dotted"
        case .validated: return "checkmark.circle.fill"
        case .locked: return "lock.circle.fill"
        case .ditched: return "xmark.circle"
        }
    }
    var statusColor: Color {
        switch state {
        case .wip: return toModify ? .orange : .blue
        case .validated: return .green
        case .locked: return .teal
        case .ditched: return .secondary
        }
    }
    /// The tooltip of the badge: what the state means, and the note when the scene was sent back with one.
    var statusHelp: String { state.meaning + (toModify ? ". To modify: \(note)" : "") + ". Click to change the state." }
}

/// The badge of a scene's review state. A click opens the menu of what the state can become; what cannot be chosen says why.
struct SceneStateBadge: View {
    let scene: ShowreelFile.Scene
    var size: CGFloat = 14
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        if scene.archived {
            Image(systemName: scene.statusSymbol).font(.system(size: size)).foregroundStyle(scene.statusColor).help(scene.state.meaning)
        } else {
            Menu {
                ForEach(SceneStates.choices(for: scene), id: \.state) { c in
                    Button { if let op = c.operation { project.perform(op) } } label: {
                        if c.isCurrent { Label(c.title, systemImage: "checkmark") } else { Text(c.title + (c.reason.map { " (\($0))" } ?? "")) }
                    }
                    .disabled(!c.enabled)
                }
            } label: {
                Image(systemName: scene.statusSymbol).font(.system(size: size)).foregroundStyle(scene.statusColor)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help(scene.statusHelp)
        }
    }
}

/// "Lock all validated": one card for the Validated scenes of the library; absent when there is none.
struct LockAllValidatedButton: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let op = project.showreel.flatMap { SceneStates.lockAllValidated($0) }
        Button { if let op = op { project.perform(op) } } label: { Label("Lock all validated", systemImage: "lock") }
            .disabledWithReason(op == nil ? "No validated scene to lock" : nil)
            .help(op == nil ? "No validated scene to lock" : "Lock every validated scene: nothing in them can change until you unlock them. Their place in the film still moves.")
    }
}

/// The warning a card carries when a change of the global look would redraw locked scenes. The words are ShowreelKit's.
struct LockedLookNotice: View {
    let warning: LockedLookWarning

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(warning.headline, systemImage: "lock.fill").font(.callout.weight(.semibold))
            Text(warning.advice).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                Button("Apply anyway") { project.confirmPendingLook() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 420)
    }
}
