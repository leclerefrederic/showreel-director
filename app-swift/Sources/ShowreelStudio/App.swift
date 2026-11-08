import AppKit
import SwiftUI

@main
struct ShowreelStudioApp: App {
    @StateObject private var env = EnvModel()
    @StateObject private var library = LibraryModel.shared
    @StateObject private var settings = AppSettings.shared

    init() {
        if CommandLine.arguments.contains("--selftest") { exit(SelfCheck.run()) }
        NSApplication.shared.setActivationPolicy(.regular)
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
                    .frame(minWidth: 1100, minHeight: 620)
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
