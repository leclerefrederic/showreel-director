import AppKit
import ShowreelKit
import SwiftUI

/// The project library window: every project the app knows. A row has a hover state; one click opens the project; its state is plain text (Setup, Storyboard,
/// Built, Outdated, Missing), never a button. The application's settings are in the app menu only.
struct LibraryView: View {
    @EnvironmentObject var library: LibraryModel
    @Environment(\.openWindow) private var openWindow
    @State private var showNew = false
    @State private var updating: LibraryEntry?
    @State private var restoring: LibraryEntry?
    @State private var trashing: (entry: LibraryEntry, prompt: LibraryRules.TrashPrompt)?
    @State private var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            if library.visible.isEmpty && library.archived.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "film.stack").font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                    Text("No project yet").font(.title2.weight(.semibold))
                    Text("Create one, or open a folder that already holds a reel project.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        header("Projects")
                        ForEach(library.visible) { e in ProjectRow(entry: e, state: library.state(e), actions: actions) }
                        if !library.archived.isEmpty {
                            header("Archive").padding(.top, 12)
                            ForEach(library.archived) { e in ProjectRow(entry: e, state: library.state(e), actions: actions) }
                        }
                    }
                    .padding(10)
                    .animation(Motion.spring, value: library.visible.map { $0.id })
                }
            }
            Divider()
            HStack {
                Button { showNew = true } label: { Label("New project...", systemImage: "plus") }
                Button { openFolder() } label: { Label("Open folder...", systemImage: "folder") }
                Spacer()
            }
            .padding(10)
        }
        .frame(minWidth: 560, minHeight: 420)
        .sheet(isPresented: $showNew) { NewProjectSheet { open($0) } }
        .sheet(item: $updating) { e in
            UpdateSheet(store: ProjectStore(root: URL(fileURLWithPath: e.path))) {
                if let open = OpenProjects.shared.model(forPath: e.path), !open.confirmLeaving(.updateProject) { return }      // the project is open in a window with work in progress
                do { try ProjectFormat.update(ProjectStore(root: URL(fileURLWithPath: e.path))); library.reload() } catch { notice = error.localizedDescription }
            }
        }
        .sheet(item: $restoring) { e in
            RestoreSheet(store: ProjectStore(root: URL(fileURLWithPath: e.path))) { b in
                if let open = OpenProjects.shared.model(forPath: e.path), !open.confirmLeaving(.restoreBackup) { return }
                do { try ProjectFormat.restore(ProjectStore(root: URL(fileURLWithPath: e.path)), b); library.reload() } catch { notice = error.localizedDescription }
            }
        }
        .alert(trashing.map { "Move \u{201C}\($0.entry.name)\u{201D} to the Trash?" } ?? "", isPresented: Binding(get: { trashing != nil }, set: { if !$0 { trashing = nil } })) {
            Button("Move to Trash", role: .destructive) { if let t = trashing { do { try library.moveToTrash(t.entry) } catch { notice = error.localizedDescription } }; trashing = nil }
            Button("Cancel", role: .cancel) { trashing = nil }
        } message: { Text(trashing?.prompt.message ?? "") }
        .alert("Library", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("OK") { notice = nil } } message: { Text(notice ?? "") }
        .onAppear { library.reload() }
        .navigationTitle("Showreel Studio")
    }

    private func header(_ t: String) -> some View { Text(t).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.top, 2) }

    private func open(_ path: String) {
        library.add(path: path)
        openWindow(value: path)
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Open"
        panel.message = "Choose a project folder"
        if panel.runModal() == .OK, let u = panel.url { open(u.path) }
    }

    private func locate(_ e: LibraryEntry) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.prompt = "Locate"; panel.message = "Choose the folder of \u{201C}\(e.name)\u{201D}"
        if panel.runModal() == .OK, let u = panel.url { do { try library.locate(e.id, to: u.path) } catch { notice = error.localizedDescription } }
    }

    /// What a row can do. The rules (what is refused, what is asked) are ShowreelKit's.
    private var actions: LibraryActions {
        LibraryActions(
            open: { open($0.path) },
            locate: { locate($0) },
            update: { e in if let why = LibraryRules.refusal(forChangingDataOf: e.path, openPaths: library.openPaths) { notice = why } else { updating = e } },
            restore: { e in if let why = LibraryRules.refusal(forChangingDataOf: e.path, openPaths: library.openPaths) { notice = why } else { restoring = e } },
            trash: { e in if let why = LibraryRules.trashRefusal(path: e.path, openPaths: library.openPaths) { notice = why } else { trashing = (e, LibraryRules.trashPrompt(name: e.name, path: e.path)) } },
            setPinned: { library.setPinned($0.id, !$0.pinned) },
            setArchived: { library.setArchived($0.id, !$0.archived) },
            remove: { library.remove($0.id) })
    }
}

struct LibraryActions {
    let open: (LibraryEntry) -> Void
    let locate: (LibraryEntry) -> Void
    let update: (LibraryEntry) -> Void
    let restore: (LibraryEntry) -> Void
    let trash: (LibraryEntry) -> Void
    let setPinned: (LibraryEntry) -> Void
    let setArchived: (LibraryEntry) -> Void
    let remove: (LibraryEntry) -> Void
}

struct ProjectRow: View {
    let entry: LibraryEntry
    let state: LibraryState
    let actions: LibraryActions
    @State private var hovering = false

    private var color: Color { state == .missing ? .red : state == .outdated ? .blue : .secondary }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.pinned ? "pin.fill" : state == .missing ? "exclamationmark.triangle" : "film")
                .foregroundStyle(entry.pinned ? Color.accentColor : state == .missing ? Color.red : .secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.headline)
                Text(entry.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if state == .missing {
                Button("Locate...") { actions.locate(entry) }.controlSize(.small)
                Button("Remove") { actions.remove(entry) }.controlSize(.small)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.rawValue).font(.caption.weight(.medium)).foregroundStyle(color)      // plain text, not a pill
                Text(entry.lastOpened.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
            }
            if state != .missing {
                HStack(spacing: 3) {
                    if hovering { Text("Open").font(.callout.weight(.medium)).transition(.opacity) }
                    Image(systemName: "chevron.right").font(.callout.weight(.semibold))
                }
                .foregroundStyle(hovering ? Color.accentColor : Color.secondary.opacity(0.5)).frame(minWidth: 18, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(hovering && state != .missing ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .onTapGesture { if state != .missing { actions.open(entry) } }
        .contextMenu {
            if state != .missing { Button("Open") { actions.open(entry) } }
            if state == .missing { Button("Locate...") { actions.locate(entry) } }
            if !entry.archived && state != .missing { Button(entry.pinned ? "Unpin" : "Pin") { actions.setPinned(entry) } }
            Button(entry.archived ? "Restore from the archive" : "Archive") { actions.setArchived(entry) }
            if state != .missing {
                Divider()
                if state == .outdated { Button("Update project...") { actions.update(entry) } }
                Button("Restore backup...") { actions.restore(entry) }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)]) }
            }
            Divider()
            Button("Remove from Library") { actions.remove(entry) }
            if state != .missing { Button("Move to Trash...", role: .destructive) { actions.trash(entry) } }
        }
        .help(state == .missing ? "The folder is not where it was: Locate it, or Remove the entry" : "Open this project")
    }
}

struct NewProjectSheet: View {
    let onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var parent = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    @State private var language = "en"
    @State private var reelLanguages = "en"
    @State private var error: String?

    private static let languages = ["en": "English", "fr": "French", "de": "German", "es": "Spanish", "it": "Italian", "pt": "Portuguese", "nl": "Dutch"]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New project") {
                    TextField("Name", text: $name)
                    LabeledContent("Folder") {
                        HStack {
                            Text(parent.appendingPathComponent(folderName).path).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                            Button("Choose...") { chooseParent() }
                        }
                    }
                    Picker("Conversation language", selection: $language) {
                        ForEach(Self.languages.keys.sorted(), id: \.self) { Text(Self.languages[$0] ?? $0).tag($0) }
                    }
                    TextField("Reel languages", text: $reelLanguages, prompt: Text("codes separated by commas, for example en, fr"))
                }
                if let e = error { Text(e).foregroundStyle(.red).font(.caption) }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 520)
    }

    /// A folder name from the project name: no slashes, no leading dot.
    private var folderName: String {
        let n = name.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return n.hasPrefix(".") ? String(n.drop(while: { $0 == "." })) : n
    }

    private func chooseParent() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        p.prompt = "Choose"
        if p.runModal() == .OK, let u = p.url { parent = u }
    }

    private func create() {
        let dir = parent.appendingPathComponent(folderName)
        let store = ProjectStore(root: dir)
        if store.hasShowreel { error = "That folder is already a project. Use Open folder."; return }
        let langs = reelLanguages.split(whereSeparator: { ", ;".contains($0) }).map { $0.lowercased() }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try store.create(name: name.trimmingCharacters(in: .whitespaces), conversationLanguage: language, reelLanguages: langs)
            dismiss()
            onCreate(dir.path)
        } catch { self.error = error.localizedDescription }
    }
}
