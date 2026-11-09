import AppKit
import ShowreelKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppSettings
    @State private var key = ""
    @State private var url = ""
    @State private var bearer = false
    @State private var modelName = ""
    @State private var idle = ""

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
                Section("Advanced") {
                    TextField("No-answer timeout (seconds)", text: $idle, prompt: Text("\(Int(AgentLimits.idleTimeout))"))
                        .help("A request is cut, and said so, when the API sends nothing for this long. At least 5.")
                }
                Section("Skill") {
                    LabeledContent("Version", value: (Skill.version().map { $0 + " " } ?? "") + "(" + Skill.fingerprint() + ")")
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
                Button("Cancel") { close() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    model.save(key: key, url: url, bearer: bearer, modelName: modelName)
                    if let n = Double(idle.trimmingCharacters(in: .whitespaces)) { model.idleTimeout = n } else if idle.isEmpty { model.idleTimeout = AgentLimits.idleTimeout }
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 500)
        .onAppear {
            key = ""
            url = model.baseURL
            bearer = model.bearer
            modelName = model.modelName
            idle = model.idleTimeout == AgentLimits.idleTimeout ? "" : String(Int(model.idleTimeout))
        }
    }

    private func close() {
        key = ""
        NSApp.keyWindow?.close()
    }
}
