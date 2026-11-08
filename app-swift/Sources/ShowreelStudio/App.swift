import AppKit
import SwiftUI

@main
struct ShowreelStudioApp: App {
    @StateObject private var env = EnvModel()
    @StateObject private var library = LibraryModel.shared
    @StateObject private var settings = AppSettings.shared

    init() {
        if CommandLine.arguments.contains("--selftest") { exit(SelfCheck.run()) }
        // The Library is the one window at launch: the project windows of the last session are not reopened (a project opens when asked).
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        NSApplication.shared.setActivationPolicy(.regular)
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
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        WindowGroup("Project", for: String.self) { $path in
            if let path = path {
                ProjectWindow(path: path)
                    .environmentObject(env)
                    .environmentObject(settings)
                    .frame(minWidth: 1180, minHeight: 720)
            }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands { StudioCommands() }
    }
}

struct StudioCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // A project window always belongs to a folder: there is no blank "New Window".
        CommandGroup(replacing: .newItem) {
            Button("Project Library") { openWindow(id: "library") }.keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
