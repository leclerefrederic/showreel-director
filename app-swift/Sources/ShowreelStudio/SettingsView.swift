import ShowreelKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var url = ""
    @State private var bearer = false
    @State private var modelName = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Connection") {
                    SecureField("API key", text: $key,
                                prompt: Text(model.hasKey ? "Saved in the Keychain (leave empty to keep)" : "Paste your key"))
                    TextField("Gateway base URL", text: $url, prompt: Text("empty = api.anthropic.com"))
                    Toggle("Send the key as Authorization: Bearer (gateways)", isOn: $bearer)
                    TextField("Model", text: $modelName)
                }
                Section("Skill") {
                    LabeledContent("Version", value: Skill.fingerprint())
                }
                Section {
                    Text("The key is stored in the macOS Keychain, never in a file. The base URL has no /v1/messages at the end.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    model.save(key: key, url: url, bearer: bearer, modelName: modelName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 500)
        .onAppear {
            url = model.baseURL
            bearer = model.bearer
            modelName = model.modelName
        }
    }
}
