import ShowreelKit
import SwiftUI

// The two buttons at the foot of the rail: Undo and Redo. A press does what the Edit menu does (one operation, two doors); pressed and held, or right-clicked, a button lists the last
// actions so that several steps go at once. The rules (the list, the tooltip, the availability) are ShowreelKit's `UndoHistory`, `RailHistory` and `Availability.undo`.

struct RailHistoryButtons: View {
    @EnvironmentObject var theme: Theme

    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(theme.hairline).frame(width: 36, height: 1).padding(.bottom, theme.space(0))
            HStack(spacing: 2) { RailHistoryButton(redo: false); RailHistoryButton(redo: true) }
        }
    }
}

private struct RailHistoryButton: View {
    let redo: Bool
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var theme: Theme
    @State private var hovering = false

    var body: some View {
        let a = Availability.undo(project.activity, can: redo ? project.canRedo : project.canUndo, redo: redo)
        let title = redo ? project.redoTitle : project.undoTitle
        let name = redo ? "Redo" : "Undo"
        Menu { list } label: {
            Image(systemName: (redo ? IconRole.railRedo : IconRole.railUndo).symbol).font(.system(size: 14, weight: .regular)).frame(width: 24, height: 24)
                .foregroundStyle(a.isAvailable ? theme.textSecondary : theme.textSecondary.opacity(0.5))
                .background(hovering && a.isAvailable ? theme.raised : Color.clear, in: RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous))
        } primaryAction: { if redo { project.redo() } else { project.undo() } }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .onHover { hovering = $0 }
        .contextMenu { list }
        .help(RailHistory.tooltip(redo: redo, title: title, a))
        .accessibilityLabel(name).accessibilityHint("Press and hold for the last actions")
        .disabledWithReason(a.why?.reason, way: a.why?.way)
    }

    /// The steps this button goes through (choosing one goes back to just after it), and the ones of the other side apart, dimmed.
    @ViewBuilder private var list: some View {
        let h = project.undoHistory
        let own = redo ? h.redo : h.undo, other = redo ? h.undo : h.redo
        Section(redo ? "Redo up to" : "Undo back to") {
            ForEach(Array(own.enumerated()), id: \.offset) { _, item in
                Button(item.title) { if redo { project.redo(steps: item.steps) } else { project.undo(steps: item.steps) } }
            }
        }
        if !other.isEmpty {
            Section(redo ? "Done" : "Undone") {
                ForEach(Array(other.enumerated()), id: \.offset) { _, item in Button(item.title) {}.disabled(true) }
            }
        }
    }
}
