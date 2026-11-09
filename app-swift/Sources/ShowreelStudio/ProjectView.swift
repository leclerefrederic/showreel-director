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
        .focusedSceneObject(win.project)          // the Edit menu's Undo and Redo act on the project in front
        .navigationTitle(win.project.title)
        .onAppear { win.project.start() }
        .background(CloseGuardHook(project: win.project))
        .onDisappear { win.chat.endSession() }          // the window closed: the session ends, and Clap writes its summary (none without a key)
    }
}

struct ProjectView: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    /// A new project's base configuration is not done: Clap's interview (Wizard) or the form (Manual) shows, never the workspace.
    private var inSetup: Bool { project.needsSetup || !project.workspaceOpen }

    var body: some View {
        VStack(spacing: 0) {
            if let offer = project.importOffer { ImportBanner(offer: offer) }
            if !project.docIssues.isEmpty { DocBanner() }
            if project.outdated && !project.updateBannerDismissed { OutdatedBanner() }
            if inSetup {
                if project.mode == StudioSettings.wizard { WizardStartView() } else { SetupFormView() }
            } else {
                WorkspaceView()
            }
        }
        .overlay(alignment: .bottom) { ToastHost().padding(.bottom, 14) }
        // the project settings slide in over the right side; the Catalogue is a small floating card (both optional, both opened from the top bar)
        .overlay(alignment: .trailing) {
            if project.showProjectSettings { SettingsDock().transition(.move(edge: .trailing)) }
        }
        .overlay(alignment: .topLeading) {
            if project.showCatalogue { CataloguePalette().transition(.opacity) }
        }
        .animation(Motion.spring, value: project.showProjectSettings)
        .animation(Motion.quick, value: project.showCatalogue)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { openWindow(id: "library") } label: { Label("Library", systemImage: "books.vertical") }
                    .help("Project library")
            }
            ToolbarItem(placement: .status) {
                HStack(spacing: 10) { BuildProgressPanel(compact: true); ClapActivityChip() }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if inSetup {
                    Button { project.finishSetup() } label: { Label("Workspace", systemImage: "rectangle.split.3x1") }
                        .disabledWithReason(project.showreel.map { ProjectSetup.isComplete($0) ? nil : "The base configuration is not complete: " + ProjectSetup.progress($0).line } ?? "This project has no data yet", way: "Set the rest, then the workspace opens")
                } else {
                    Button { project.showCatalogue.toggle() } label: { Label("Catalogue", systemImage: "square.grid.2x2") }
                        .keyboardShortcut("k", modifiers: [.command, .shift])
                        .help("The Catalogue: effects, transitions, backgrounds and looks to drag onto a scene, an item or a marker (Shift-Command-K)")
                    Button { project.resetLayout() } label: { Label("Reset layout", systemImage: "rectangle.3.group") }
                        .help("Reset layout: put the library, the inspector and the storyboard back to their standard sizes")
                        .disabledWithReason(project.layout.isStandard ? "The layout already is the standard one" : nil)
                    Button { project.centerMode = project.centerMode == .build ? .viewer : .build } label: { Label("Build", systemImage: "play.rectangle") }
                        .help("Build the film, test it and play it")
                }
                Button { project.showProjectSettings.toggle() } label: { Label("Project settings", systemImage: "slider.horizontal.3") }
                    .help("The project's parameters and its global look. The application's settings (key, model, environment) are in the Showreel Studio menu, Settings (Command-,).")
            }
        }
        .sheet(isPresented: $project.showUpdateSheet) { UpdateSheet(store: project.store) { project.updateProject() } }
        .sheet(item: $project.pendingLook) { LockedLookSheet(pending: $0) }
        .sheet(item: $project.generationOffer) { GenerateScenesSheet(pending: $0) }
        .sheet(item: $project.fontOffer) { FontOfferSheet(pending: $0) }
        .sheet(item: $project.fontsAtBuild) { FontsAtBuildSheet(pending: $0) }
        .alert(item: $project.fontFailure) { f in
            Alert(title: Text("The files of \(f.family) could not be added"), message: Text(f.text),
                  primaryButton: .default(Text("Try again")) { if let r = f.retry { r() } else { project.addFontFiles(f.family) } }, secondaryButton: .cancel(Text("Close")))
        }
        .alert(item: $project.buildFailure) { f in
            let retry = { if let c = project.chat { project.startBuild(with: c) } }
            let oneByOne = { if let c = project.chat { project.startBuild(with: c, oneByOne: true) } }
            return f.remedy == .oneByOne
                ? Alert(title: Text("The Build stopped"), message: Text(f.message),
                        primaryButton: .default(Text("Generate the scenes one by one"), action: oneByOne),
                        secondaryButton: .default(Text("Try again"), action: retry))
                : Alert(title: Text("The Build stopped"), message: Text(f.message),
                        primaryButton: .default(Text("Try again"), action: retry), secondaryButton: .cancel(Text("Close")))
        }
        .sheet(item: $project.historyFor) { tab in HistoryView(tab: tab) }
        .sheet(isPresented: Binding(get: { project.reimport != nil }, set: { if !$0 { project.reimport = nil } })) { ReimportSheet() }
        // a drop that would replace a scene's look asks first; saying no changes nothing
        .alert(project.pendingDrop?.message ?? "", isPresented: Binding(get: { project.pendingDrop != nil }, set: { if !$0 { project.cancelPendingDrop() } })) {
            Button("Replace") { project.confirmPendingDrop() }
            Button("Cancel", role: .cancel) { project.cancelPendingDrop() }
        } message: { Text(project.pendingDrop.map { project.verdict($0.item, $0.target).text } ?? "") }
        .alert("Something went wrong", isPresented: Binding(get: { project.error != nil }, set: { if !$0 { project.error = nil } })) {
            Button("OK") { project.error = nil }
        } message: { Text(project.error ?? "") }
    }
}

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
