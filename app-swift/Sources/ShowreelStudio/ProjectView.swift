import ShowreelKit
import SwiftUI

/// The window of one project: the blocks of the film on the left, the selected block in the middle, the copilot on the right.
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
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if let offer = project.importOffer { ImportBanner(offer: offer) }
            if !project.docIssues.isEmpty { DocBanner() }
            HSplitView {
                BlocksSidebar()
                    .frame(minWidth: 190, idealWidth: 220, maxWidth: 320)
                CenterPane()
                    .frame(minWidth: 420)
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
        .onChange(of: settings.advanced) { on in
            if !on, case .file = project.selected { project.selectBlock(project.lastBlock) }
        }
        .sheet(isPresented: $chat.showSettings) { SettingsView() }
        .sheet(item: $project.historyFor) { tab in HistoryView(tab: tab) }
        .sheet(isPresented: Binding(get: { project.reimport != nil }, set: { if !$0 { project.reimport = nil } })) { ReimportSheet() }
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
                Text(offer.sources.isEmpty ? "This project has no data file yet." : "This project was made outside the app: read from " + offer.sources.joined(separator: " and ") + ".")
                    .font(.callout.weight(.medium))
                Text(offer.found.isEmpty ? "Nothing to import. Create the project data to fill it in from the blocks."
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

/// A generated document was changed (or written) outside the app: the app asks, it never overwrites.
struct DocBanner: View {
    @EnvironmentObject var project: ProjectModel

    private var names: String {
        let n = project.docIssues.map { ProjectModel.friendly($0.file) }
        return n.count <= 1 ? (n.first ?? "") : n.dropLast().joined(separator: ", ") + " and " + (n.last ?? "")
    }
    private var verb: String { project.docIssues.allSatisfy { $0.state == .foreign } ? "written outside the app" : "changed outside the app" }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(names.prefix(1).uppercased() + names.dropFirst()) \(project.docIssues.count > 1 ? "were" : "was") \(verb).").font(.callout.weight(.medium))
                Text("The app does not overwrite them. Review what it can read from them, or leave them as they are.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Leave as is") { project.leaveDocs() }
            Button("Review...") { project.reviewReimport() }.buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.14))
    }
}

struct ReimportSheet: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import from the changed documents").font(.title3.weight(.semibold))
            if let r = project.reimport {
                if r.changes.isEmpty {
                    Text("None of the project's data differs from what the app holds. The documents differ only in wording or layout.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Reading \(r.files.map { ProjectModel.friendly($0) }.joined(separator: ", ")) would change:").foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(r.changes.enumerated()), id: \.offset) { _, c in ChangeRow(change: c) }
                        }
                    }
                    .frame(maxHeight: 280)
                }
                Text("Only the project questions, palette, fonts, languages, duration and scenes are read. The documents are then rewritten by the app; the old versions stay in the history.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Replace the documents with the app's version", role: .destructive) { project.replaceDocs() }
                Spacer()
                Button("Cancel") { project.reimport = nil }.keyboardShortcut(.cancelAction)
                Button("Import these changes") { project.acceptReimport() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(project.reimport?.changes.isEmpty ?? true)
            }
        }
        .padding(18)
        .frame(width: 560)
    }
}

/// "Label: before -> after", the plain form of a change.
struct ChangeRow: View {
    let change: Change
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(change.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 6) {
                Text(change.before).foregroundStyle(.secondary).strikethrough(change.before != "(empty)" && change.before != "(none)")
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                Text(change.after).fontWeight(.medium)
            }
            .font(.callout)
            .textSelection(.enabled)
        }
    }
}


struct BlocksSidebar: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings

    private var selection: Binding<String?> {
        Binding(get: {
            switch project.selected {
            case .block(let b): return "block:" + b
            case .preview: return "preview"
            case .file(let p): return "file:" + p
            }
        }, set: { v in
            guard let v = v else { return }
            if v.hasPrefix("block:") { project.selectBlock(String(v.dropFirst(6))) }
            else if v == "preview" { project.selected = .preview }
            else if v.hasPrefix("file:") {
                let rel = String(v.dropFirst(5))
                if let n = project.node(rel), !n.isDir { project.open(rel) }
            }
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(project.title).font(.headline).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            Divider()
            List(selection: selection) {
                Section("Film") {
                    ForEach(project.spec?.blocks ?? []) { b in
                        BlockRow(block: b, status: project.status(b.id)).tag("block:" + b.id)
                    }
                    if chat.previewURL != nil {
                        Label("Preview", systemImage: "rectangle.on.rectangle").tag("preview")
                    }
                }
                if settings.advanced {
                    Section("Files (advanced)") {
                        OutlineGroup(project.tree, children: \.children) { node in
                            Label(node.name, systemImage: icon(node)).lineLimit(1).tag((node.isDir ? "dir:" : "file:") + node.id)
                                .contextMenu {
                                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.root.appendingPathComponent(node.id)]) }
                                    if !node.isDir { Button("Open with the system viewer") { NSWorkspace.shared.open(project.root.appendingPathComponent(node.id)) } }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Button { NSWorkspace.shared.activateFileViewerSelecting([project.root]) } label: { Label("Show in Finder", systemImage: "folder") }
                    .buttonStyle(.borderless)
                Toggle("Advanced panel", isOn: $settings.advanced)
                    .toggleStyle(.checkbox)
                    .help("Shows the project's files with editors and history, for debugging. Off by default.")
            }
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
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

struct BlockRow: View {
    let block: ProcessSpec.BlockSpec
    let status: BlockStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: block.icon).frame(width: 18)
            Text(block.name).lineLimit(1)
            Spacer()
            switch status {
            case .soon: Text("Soon").font(.caption2).foregroundStyle(.tertiary)
            case .todo: Image(systemName: "circle").foregroundStyle(.tertiary).help(status.label)
            case .inProgress: Image(systemName: "circle.lefthalf.filled").foregroundStyle(Color.accentColor).help(status.label)
            case .validated: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).help(status.label)
            }
        }
        .foregroundStyle(status == .soon ? .secondary : .primary)
    }
}

struct CenterPane: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            if settings.advanced && !project.tabs.isEmpty { tabBar; Divider() }
            switch project.selected {
            case .block(let id):
                BlockHost(id: id)
            case .preview:
                PreviewPane()
            case .file(let p):
                if let t = project.tab(p) { EditorView(tab: t) } else { BlockHost(id: project.lastBlock) }
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                chip(title: "Blocks", icon: "square.grid.2x2", on: project.foreground == nil, dirty: false, close: nil) { project.selectBlock(project.lastBlock) }
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

/// The view of one block of the sidebar.
struct BlockHost: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        switch id {
        case "project": ProjectBlockView()
        case "resources": ResourcesBlockView()
        default: ComingSoonView(block: project.spec?.block(id))
        }
    }
}

struct ComingSoonView: View {
    let block: ProcessSpec.BlockSpec?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: block?.icon ?? "hourglass").font(.system(size: 40, weight: .light)).foregroundStyle(.secondary)
            Text(block?.name ?? "Block").font(.title2.weight(.semibold))
            Text("Coming soon").font(.headline).foregroundStyle(.secondary)
            Text("This block is not built yet (phase \(block?.phase ?? "later")). Until then the copilot carries this step in the chat.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}
