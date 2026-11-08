import ShowreelKit
import SwiftUI

/// The window of one project: files on the left, preview and editors in the middle, the copilot on the right.
struct ProjectWindow: View {
    @StateObject private var win: WindowModel
    @EnvironmentObject var env: EnvModel

    init(path: String) { _win = StateObject(wrappedValue: WindowModel(path: path)) }

    var body: some View {
        Group {
            if env.ready {
                ProjectView()
            } else {
                SetupView()
            }
        }
        .environmentObject(win.project)
        .environmentObject(win.chat)
        .navigationTitle(win.project.title)
        .onAppear { win.project.start() }
    }
}

struct ProjectView: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if let offer = project.importOffer { ImportBanner(offer: offer) }
            HSplitView {
                FilesSidebar()
                    .frame(minWidth: 170, idealWidth: 210, maxWidth: 320)
                CenterPane()
                    .frame(minWidth: 380)
                ChatView()
                    .frame(minWidth: 340, idealWidth: 400)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { openWindow(id: "library") } label: { Label("Library", systemImage: "books.vertical") }
                    .help("Project library")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { chat.showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                    .help("Settings")
            }
        }
        .sheet(isPresented: $chat.showSettings) { SettingsView() }
        .sheet(item: $project.historyFor) { tab in HistoryView(tab: tab) }
        .alert("Something went wrong", isPresented: Binding(get: { project.error != nil }, set: { if !$0 { project.error = nil } })) {
            Button("OK") { project.error = nil }
        } message: { Text(project.error ?? "") }
    }
}

/// Shown when the folder has no showreel.json: what was read from the markdown, to confirm.
struct ImportBanner: View {
    let offer: ImportResult
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.sources.isEmpty ? "This folder has no showreel.json." : "No showreel.json yet: read from " + offer.sources.joined(separator: " and ") + ".")
                    .font(.callout.weight(.medium))
                Text(offer.found.isEmpty ? "Nothing to import. Create it to keep the project's decisions in one file."
                     : "Found: " + offer.found.joined(separator: "; ") + ". Check, then confirm.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Not now") { project.dismissImport() }
            Button(offer.found.isEmpty ? "Create" : "Confirm") { project.confirmImport() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.12))
    }
}

struct FilesSidebar: View {
    @EnvironmentObject var project: ProjectModel
    @State private var selection: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files").font(.headline)
                Spacer()
                Button { project.reloadTree() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Refresh")
                Button { NSWorkspace.shared.activateFileViewerSelecting([project.root]) } label: { Image(systemName: "folder") }
                    .buttonStyle(.borderless).help("Show the project in Finder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            Divider()
            List(project.tree, children: \.children, selection: $selection) { node in
                Label(node.name, systemImage: icon(node))
                    .lineLimit(1)
                    .contextMenu {
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.root.appendingPathComponent(node.id)]) }
                        if !node.isDir { Button("Open with the system viewer") { NSWorkspace.shared.open(project.root.appendingPathComponent(node.id)) } }
                    }
            }
            .listStyle(.sidebar)
            .onChange(of: selection) { id in
                guard let id = id, let n = project.node(id), !n.isDir else { return }
                project.open(id)
            }
        }
    }

    private func icon(_ n: FileNode) -> String {
        if n.isDir { return "folder" }
        switch ProjectTree.kind(of: n.id) {
        case .markdown: return "doc.richtext"
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .text: return "doc.text"
        case .binary: return "photo.on.rectangle"
        }
    }
}

struct CenterPane: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            switch project.selected {
            case .preview:
                PreviewPane()
            case .file(let p):
                if let t = project.tab(p) { EditorView(tab: t) } else { PreviewPane() }
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                chip(title: "Preview", icon: "rectangle.on.rectangle", on: project.selected == .preview, dirty: false, close: nil) {
                    project.selected = .preview
                }
                ForEach(project.tabs) { t in
                    chip(title: t.name, icon: "doc.text", on: project.selected == .file(t.path), dirty: t.dirty, close: { project.close(t) }) {
                        project.selected = .file(t.path)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(.bar)
    }

    private func chip(title: String, icon: String, on: Bool, dirty: Bool, close: (() -> Void)?, pick: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption)
            Text(title).lineLimit(1)
            if dirty { Circle().fill(Color.secondary).frame(width: 6, height: 6) }
            if let close = close {
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                    .buttonStyle(.borderless)
            }
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(on ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
    }
}
