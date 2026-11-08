import AppKit
import SwiftUI

@main
struct ShowreelStudioApp: App {
    @StateObject private var model = ChatModel()
    @StateObject private var env = EnvModel()

    init() {
        if CommandLine.arguments.contains("--selftest") { exit(SelfCheck.run()) }
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Showreel Studio") {
            ContentView()
                .environmentObject(model)
                .environmentObject(env)
                .frame(minWidth: 980, minHeight: 620)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") { model.reset() }.keyboardShortcut("n")
            }
        }
    }
}
