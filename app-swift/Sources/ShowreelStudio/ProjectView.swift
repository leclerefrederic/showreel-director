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
    @State private var showChecks = false

    private var inWizard: Bool { project.mode == StudioSettings.beginner && !project.workspaceOpen }

    var body: some View {
        VStack(spacing: 0) {
            if let offer = project.importOffer { ImportBanner(offer: offer) }
            if !project.docIssues.isEmpty { DocBanner() }
            if inWizard {
                HSplitView {
                    WizardView().frame(minWidth: 560)
                    if project.showCopilot { ChatView().frame(minWidth: 340, idealWidth: 400) }
                }
            } else {
                WorkspaceView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { openWindow(id: "library") } label: { Label("Library", systemImage: "books.vertical") }
                    .help("Project library")
            }
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $project.mode) {
                    Text("Beginner").tag(StudioSettings.beginner)
                    Text("Expert").tag(StudioSettings.expert)
                }
                .pickerStyle(.segmented).frame(width: 200)
                .help("Beginner: a guided path that ends in the workspace. Expert: the workspace at once. Switching loses nothing.")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if inWizard {
                    Button { project.showCopilot.toggle() } label: { Label("Copilot", systemImage: "sidebar.right") }
                        .help(project.showCopilot ? "Hide the copilot" : "Show the copilot")
                    Button { project.workspaceOpen = true } label: { Label("Workspace", systemImage: "rectangle.split.3x1") }
                        .help("Open the editing workspace")
                } else {
                    if project.mode == StudioSettings.beginner {
                        Button { project.workspaceOpen = false; project.resumeWizard() } label: { Label("Guide", systemImage: "list.number") }
                            .help("Back to the guided path")
                    }
                    Button { showChecks.toggle() } label: { Label("Checks", systemImage: Checks.worst(project.checks.values.flatMap { $0 }).symbol) }
                        .help("The checks and the gates of the process, green or red, no AI")
                        .popover(isPresented: $showChecks) { ChecksPopover() }
                    Button { project.resetLayout() } label: { Label("Reset layout", systemImage: "rectangle.3.group") }
                        .help("Reset layout: put the library, the inspector and the storyboard back to their standard sizes")
                        .disabled(project.layout.isStandard)
                    GoButton()
                    Button { project.centerMode = project.centerMode == .build ? .viewer : .build } label: { Label("Build", systemImage: "play.rectangle") }
                        .help("Build the film, test it and play it")
                }
                Button { chat.showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                    .help("Settings")
            }
        }
        .sheet(isPresented: $chat.showSettings) { SettingsView() }
        .sheet(item: $project.historyFor) { tab in HistoryView(tab: tab) }
        .sheet(isPresented: Binding(get: { project.reimport != nil }, set: { if !$0 { project.reimport = nil } })) { ReimportSheet() }
        .alert("Something went wrong", isPresented: Binding(get: { project.error != nil }, set: { if !$0 { project.error = nil } })) {
            Button("OK") { project.error = nil }
        } message: { Text(project.error ?? "") }
    }
}

/// The process bar of the workspace: every area's checks and gates, in the order of the process.
struct ChecksPopover: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Wizard.sections.filter { Blocks.areas.contains($0.area) }, id: \.area) { s in
                    VStack(alignment: .leading, spacing: 4) {
                        let results = project.checks[s.area] ?? []
                        Label(s.name, systemImage: Checks.worst(results).symbol).font(.headline).foregroundStyle(Checks.worst(results).color)
                        ChecksList(areas: [s.area])
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 420, height: 480)
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
