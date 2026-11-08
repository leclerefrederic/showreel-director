import AppKit
import ShowreelKit
import SwiftUI

/// The project library window: every project the app knows.
struct LibraryView: View {
    @EnvironmentObject var library: LibraryModel
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @State private var showNew = false
    @State private var showSettings = false

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
                List {
                    Section("Projects") {
                        ForEach(library.visible) { e in row(e) }
                    }
                    if !library.archived.isEmpty {
                        Section("Archive") {
                            ForEach(library.archived) { e in row(e) }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button { showNew = true } label: { Label("New project...", systemImage: "plus") }
                Button { openFolder() } label: { Label("Open folder...", systemImage: "folder") }
                Spacer()
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
            .padding(10)
        }
        .frame(minWidth: 560, minHeight: 420)
        .sheet(isPresented: $showNew) { NewProjectSheet { open($0) } }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { library.reload() }
        .navigationTitle("Showreel Studio")
    }

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

    private func row(_ e: LibraryEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: e.pinned ? "pin.fill" : "film").foregroundStyle(e.pinned ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name).font(.headline)
                Text(e.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(e.step).font(.caption).padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                Text(e.lastOpened.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !e.archived { open(e.path) } }
        .contextMenu {
            if e.archived {
                Button("Restore from the archive") { library.setArchived(e.id, false) }
            } else {
                Button("Open") { open(e.path) }
                Button(e.pinned ? "Unpin" : "Pin") { library.setPinned(e.id, !e.pinned) }
                Button("Archive") { library.setArchived(e.id, true) }
            }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: e.path)]) }
            Divider()
            Button("Remove from the library (files stay)") { library.remove(e.id) }
        }
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
