import AppKit
import ShowreelKit
import SwiftUI

@main
struct ShowreelStudioApp: App {
    @StateObject private var env = EnvModel()
    @StateObject private var library = LibraryModel.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var theme = Theme()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if CommandLine.arguments.contains("--selftest") { exit(SelfCheck.run()) }
        // The Library is the one window at launch: the project windows of the last session are not reopened (a project opens when asked).
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)          // the dark theme: every window, the Settings window and the system panels (no setting yet)
        if let path = ProcessInfo.processInfo.environment["SHOWREEL_LAUNCH_LOG"] { Self.writeLaunchLog(to: path) }
    }

    /// For checking the launch without looking at the screen: SHOWREEL_LAUNCH_LOG=<file> makes the app write the windows it shows two seconds after it started.
    private static func writeLaunchLog(to path: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let visible = NSApplication.shared.windows.filter { $0.isVisible && !($0 is NSPanel) }
            var lines = ["visible windows: \(visible.count)"]
            for w in visible { lines.append("window: \(w.title.isEmpty ? "(untitled)" : w.title) | sheets: \(w.sheets.count)") }
            try? lines.joined(separator: "\n").appending("\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    var body: some Scene {
        // The first scene opens at launch: the project library. Each project opens in its own window.
        Window("Showreel Studio", id: "library") {
            LibraryView()
                .environmentObject(library)
                .environmentObject(settings)
                .environmentObject(theme)
                .preferredColorScheme(.dark)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        WindowGroup("Project", for: String.self) { $path in
            if let path = path {
                ProjectWindow(path: path)
                    .environmentObject(env)
                    .environmentObject(settings)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands { StudioCommands() }
        // the application's own settings: the Showreel Studio menu, Settings (Command-,)
        Settings { SettingsView().environmentObject(settings).environmentObject(theme).preferredColorScheme(.dark) }
    }
}

struct StudioCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedObject private var project: ProjectModel?

    /// The text being edited, when a field has the keyboard: Undo then belongs to the text, not to the project.
    private var fieldUndo: UndoManager? {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.isEditable else { return nil }
        return tv.undoManager
    }

    @ViewBuilder private func panelItem(_ title: String, _ entry: RailEntry, _ key: AppShortcuts.Shortcut, _ act: @escaping (ProjectModel) -> Void) -> some View {
        let why = project.flatMap { p in entry.unavailable(workspaceOpen: p.workspaceOpen, progressLine: p.showreel.map { ProjectSetup.progress($0).line } ?? "") }
        let letter = String(key.keys.last ?? "i")
        Button(why == nil ? title : "\(title) (\(why?.reason.lowercased() ?? ""))") { if let p = project { act(p) } }
            .keyboardShortcut(KeyEquivalent(Character(letter)), modifiers: [.command, .shift])
            .disabled(project == nil || why != nil)
    }

    var body: some Commands {
        // About: the app's version and the skill it carries
        CommandGroup(replacing: .appInfo) {
            Button("About Showreel Studio") {
                let credits = NSAttributedString(string: "Skill \(AppInfo.skillVersion) (fingerprint \(Skill.fingerprint()))", attributes: [.font: NSFont.systemFont(ofSize: 11)])
                NSApplication.shared.orderFrontStandardAboutPanel(options: [.applicationName: "Showreel Studio", .applicationVersion: AppInfo.version, .version: "", .credits: credits])
            }
        }
        // A project window always belongs to a folder: there is no blank "New Window".
        CommandGroup(replacing: .newItem) {
            Button("Project Library") { openWindow(id: "library") }.keyboardShortcut("l", modifiers: [.command, .shift])
        }
        // The right panels, with their shortcuts (Clap's is declared by the workspace). An entry that cannot act says why in its title, as Undo does.
        CommandGroup(after: .sidebar) {
            panelItem("Inspector", .inspector, AppShortcuts.inspector) { $0.showInspector() }
            panelItem("Project", .project, AppShortcuts.project) { $0.showProject() }
            panelItem("Project, Look tab", .project, AppShortcuts.look) { $0.showLook() }
        }
        // Undo and redo of every typed operation of the project in front (a text field being edited keeps its own).
        CommandGroup(replacing: .undoRedo) {
            let snap = project?.activity ?? ProjectActivity.Snapshot()
            let canU = (project?.canUndo ?? false) || (fieldUndo?.canUndo ?? false), canR = (project?.canRedo ?? false) || (fieldUndo?.canRedo ?? false)
            let u = Availability.undo(snap, can: canU), r = Availability.undo(snap, can: canR, redo: true)
            Button(u.why?.cause == .building ? "Undo (building the film)" : project?.undoTitle.map { "Undo \($0)" } ?? ("Undo" + (u.isAvailable ? "" : " (\(u.why?.reason.lowercased() ?? ""))"))) {
                if let m = fieldUndo, m.canUndo { m.undo() } else { project?.undo() }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!u.isAvailable)
            Button(r.why?.cause == .building ? "Redo (building the film)" : project?.redoTitle.map { "Redo \($0)" } ?? ("Redo" + (r.isAvailable ? "" : " (\(r.why?.reason.lowercased() ?? ""))"))) {
                if let m = fieldUndo, m.canRedo { m.redo() } else { project?.redo() }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!r.isAvailable)
        }
    }
}
