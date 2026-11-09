import ShowreelKit
import SwiftUI

/// The Transitions tab of the left panel: the film's transitions, one row per pair of consecutive scenes, and under them the catalogue, which is a drag source for the
/// markers of the reel. The rules (the rows, their marks, what the catalogue refuses and why) are ShowreelKit's `TransitionList` and `Catalogue`; this only draws them.
struct TransitionsLibrary: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if let f = project.showreel {
                    let rows = TransitionList.rows(f, store: project.store)
                    Text("In the film").font(.subheadline.weight(.semibold)).padding(.top, 8).padding(.horizontal, 8)
                    if rows.isEmpty {
                        Text(TransitionList.emptyText).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.vertical, 6)
                    } else {
                        ForEach(rows) { r in TransitionRowView(row: r) }
                    }
                }
                Divider().padding(.vertical, 8)
                Text("Catalogue").font(.subheadline.weight(.semibold)).padding(.horizontal, 8)
                Text("Drag one onto a marker of the reel or a row above.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                ForEach(TransitionList.catalogue()) { c in CatalogueRow(choice: c) }
            }
            .padding(.horizontal, 6).padding(.bottom, 10)
        }
    }
}

/// "S01 to S02: Push, 0.6 s". A click selects the marker on the reel and opens its inspector; a transition of the catalogue dropped on the row goes to that marker.
struct TransitionRowView: View {
    let row: TransitionRow
    @EnvironmentObject var project: ProjectModel
    @State private var hovering = false

    var body: some View {
        let selected = project.selection == .transition(TransitionList.selection(of: row))
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: row.isCut ? "scissors" : "arrow.left.arrow.right").font(.caption).foregroundStyle(row.isCut ? Color.secondary : Color.accentColor).frame(width: 14)
                Text(row.title).font(.callout).lineLimit(1)
            }
            ForEach(row.marks, id: \.self) { m in Text(m).font(.caption2).foregroundStyle(.orange).padding(.leading, 20).lineLimit(2) }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor.opacity(0.2) : hovering ? Color.primary.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { project.selectTransition(from: TransitionList.selection(of: row)) }
        .dropTarget(.marker(from: row.from))
        .help(project.transitionHelp(from: row.from, base: row.title))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Select") { project.selectTransition(from: row.from) }
    }
}

/// One transition of the catalogue. The six that only run as previews are marked and refused at the drop with their reason.
struct CatalogueRow: View {
    let choice: CatalogueChoice
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        DragRow(selected: project.selection == .look(.transitions, choice.id), item: Catalogue.dragItem(.transition, choice.id), label: choice.id, icon: "arrow.left.arrow.right",
                help: choice.reason ?? (choice.detail.isEmpty ? "Drag onto a marker of the reel" : choice.detail),
                action: { project.select(.look(.transitions, choice.id)) }) {
            HStack {
                Text(choice.id).font(.callout)
                Spacer()
                if choice.selectable { Text(choice.group).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                else { Text("preview only").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 1).background(Color.orange.opacity(0.2), in: Capsule()) }
            }
        }
        .opacity(choice.selectable ? 1 : 0.7)
    }
}
