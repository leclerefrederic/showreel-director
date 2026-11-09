import ShowreelKit
import SwiftUI

/// The bar at the top of a project whose file is of an older revision. Opening it wrote nothing; the user decides.
struct OutdatedBanner: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("This project was made with an older version of the app.").font(.callout.weight(.medium))
                Text("Nothing was changed by opening it. Update it to the current format when you are ready: a backup is made first.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Not now") { project.updateBannerDismissed = true }
            Button("Update project...") { project.showUpdateSheet = true }.buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14).padding(.vertical, 8).background(Color.blue.opacity(0.12))
    }
}

/// "Update project...": the list of what will change, then the backup, the migration and the new revision.
struct UpdateSheet: View {
    let store: ProjectStore
    let run: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let plan = ProjectFormat.plan(store)
        VStack(alignment: .leading, spacing: 12) {
            Text("Update project").font(.title3.weight(.semibold))
            if let p = plan {
                Text("This project is at revision \(p.from); this version of the app writes revision \(p.to). What will change:").font(.callout)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(p.changes.enumerated()), id: \.offset) { _, c in
                            HStack(alignment: .firstTextBaseline, spacing: 8) { Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.secondary); Text(c).font(.callout).fixedSize(horizontal: false, vertical: true) }
                        }
                    }
                }
                .frame(maxHeight: 220)
                Label("First, a copy of showreel.json, the generated documents and the manifest goes to .studio/backups/. \"Restore backup...\" in the Library puts it back exactly. Keys the app does not know are kept.", systemImage: "externaldrive")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else { Text("This project is up to date.").font(.callout) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Back up and update") { run(); dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabledWithReason(plan == nil ? "Nothing to update: this project already is at the current revision" : nil)
            }
        }
        .padding(18).frame(width: 540)
    }
}

/// "Restore backup...": the copies made before an update, newest first.
struct RestoreSheet: View {
    let store: ProjectStore
    let run: (ProjectBackup) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picked: String?

    var body: some View {
        let list = ProjectFormat.backups(store)
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore backup").font(.title3.weight(.semibold))
            if list.isEmpty { Text("This project has no backup yet. One is made each time you update it.").font(.callout).foregroundStyle(.secondary) }
            else {
                List(list, selection: $picked) { b in
                    HStack {
                        Text(b.date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? b.id).font(.callout.weight(.medium))
                        Text("revision \(b.revision) \u{00B7} \(b.files.count) files").font(.caption).foregroundStyle(.secondary)
                    }.tag(b.id)
                }
                .frame(height: 180)
                Text("The files are put back exactly as they were. What they replace is backed up first, so this can be undone.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Restore") { if let b = list.first(where: { $0.id == picked }) { run(b); dismiss() } }.buttonStyle(.borderedProminent).disabledWithReason(picked == nil ? "Pick a backup first" : nil)
            }
        }
        .padding(18).frame(width: 480)
    }
}
