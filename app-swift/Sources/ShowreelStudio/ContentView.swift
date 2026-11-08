import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ChatModel
    @EnvironmentObject var env: EnvModel

    var body: some View {
        Group {
            if env.ready {
                HSplitView {
                    ChatView()
                        .frame(minWidth: 380, idealWidth: 460)
                    PreviewPane()
                        .frame(minWidth: 380)
                }
            } else {
                SetupView()
            }
        }
        .onChange(of: env.ready) { ready in
            if ready && !model.hasKey { model.showSettings = true }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { model.pickProject() } label: { Label(model.projectName, systemImage: "folder") }
                    .help("Choose the project folder")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.reset() } label: { Label("New conversation", systemImage: "square.and.pencil") }
                    .help("New conversation")
                Button { model.showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                    .help("Settings")
            }
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView().environmentObject(model)
        }
    }
}
