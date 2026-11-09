import AppKit
import ShowreelKit
import SwiftUI

/// The New project screen: a name, a folder and the way to set the project up, chosen once.
struct NewProjectSheet: View {
    let onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @State private var name = ""
    @State private var parent = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    @State private var mode = StudioSettings.wizard
    @State private var error: String?

    var body: some View {
        let wizard = Availability.wizard(hasKey: settings.hasKey)
        VStack(spacing: 0) {
            Form {
                Section("New project") {
                    TextField("Name", text: $name)
                    LabeledContent("Folder") {
                        HStack {
                            Text(parent.appendingPathComponent(folderName).path).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                            Button("Choose...") { chooseParent() }
                        }
                    }
                }
                Section("How do you want to set it up? You choose once, here.") {
                    HStack(alignment: .top, spacing: 12) {
                        ModeCard(title: "Wizard", symbol: "wand.and.stars", line: "Clap asks a few questions, then proposes a starting pack for you to adjust.", selected: effectiveMode == StudioSettings.wizard,
                                 reason: wizard.why) { mode = StudioSettings.wizard }
                        ModeCard(title: "Manual", symbol: "slider.horizontal.3", line: "You fill in a compact form yourself, then work in the same interface.", selected: effectiveMode == StudioSettings.manual, reason: nil) { mode = StudioSettings.manual }
                    }
                    if !wizard.isAvailable { ConnectKeyLink() }
                }
                if let e = error { Text(e).foregroundStyle(.red).font(.caption) }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabledWithReason(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Give the project a name" : nil)
            }
            .padding(12)
        }
        .frame(width: 560)
    }

    /// Wizard needs a key: without one, Manual is what is chosen.
    private var effectiveMode: String { Availability.wizard(hasKey: settings.hasKey).isAvailable ? mode : StudioSettings.manual }

    /// A folder name from the project name: no slashes, no leading dot.
    private var folderName: String {
        let n = name.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return n.hasPrefix(".") ? String(n.drop(while: { $0 == "." })) : n
    }

    private func chooseParent() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        p.prompt = "Choose"
        if p.runModal() == .OK, let u = p.url { parent = u }
    }

    private func create() {
        let dir = parent.appendingPathComponent(folderName)
        let store = ProjectStore(root: dir)
        if store.hasShowreel { error = "That folder is already a project. Use Open folder."; return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try store.create(name: name.trimmingCharacters(in: .whitespaces), conversationLanguage: nil, reelLanguages: [], mode: effectiveMode)
            dismiss()
            onCreate(dir.path)
        } catch { self.error = error.localizedDescription }
    }
}

/// One of the two ways to set up a project: who does the work, in one line. The whole card is the control; when it cannot be chosen it says why.
struct ModeCard: View {
    let title: String
    let symbol: String
    let line: String
    let selected: Bool
    let reason: Unavailable?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).font(.title2).foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(title).font(.headline)
                Text(line).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabledWithReason(reason?.reason, way: reason?.way, caption: reason != nil)
    }
}
