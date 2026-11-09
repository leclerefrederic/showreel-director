import ShowreelKit
import SwiftUI

/// Expert mode, a new project: one compact form with the base configuration (the languages, the formats, the target duration and a look). The same data and the
/// same typed operations as the guided path; the workspace opens when it is complete. Audience, message and tone stay optional (project settings).
struct SetupFormView: View {
    @EnvironmentObject var project: ProjectModel
    @State private var reel = ""
    @State private var duration = ""
    @State private var task: DispatchWorkItem?
    private static let formats = ["16:9", "9:16", "1:1", "4:5"]
    private static let languages = ["": "Not set", "en": "English", "fr": "French", "de": "German", "es": "Spanish", "it": "Italian", "pt": "Portuguese", "nl": "Dutch"]

    var body: some View {
        let f = project.showreel
        let missing = f.map { ProjectSetup.missing($0) } ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set up the project").font(.title2.weight(.semibold))
                    Text("Everything else depends on these choices, so they come first. The audience, the message and the tone can wait: they are in the project settings.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                section("Languages") {
                    row("Conversation language") {
                        Picker("", selection: Binding(get: { f?.conversationLanguage ?? "" }, set: { project.setParameter(.conversationLanguage, $0) })) {
                            ForEach(Self.languages.keys.sorted(), id: \.self) { Text(Self.languages[$0] ?? $0).tag($0) }
                        }.labelsHidden().frame(maxWidth: 200)
                    }
                    row("Reel languages") {
                        TextField("", text: $reel, prompt: Text("codes separated by commas, for example en, fr")).textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                            .onChange(of: reel) { _ in later { project.setParameter(.reelLanguages, reel) } }
                            .onSubmit { project.setParameter(.reelLanguages, reel) }
                    }
                }
                section("Formats") {
                    HStack {
                        ForEach(Self.formats, id: \.self) { fm in
                            Toggle(fm, isOn: Binding(get: { (f?.decisions.formats ?? []).contains(fm) }, set: { on in toggle(fm, on) })).toggleStyle(.button)
                        }
                    }
                }
                section("Target duration") {
                    row("Seconds") {
                        TextField("", text: $duration, prompt: Text("for example 45")).textFieldStyle(.roundedBorder).frame(maxWidth: 140)
                            .onChange(of: duration) { _ in later { project.setParameter(.duration, duration) } }
                            .onSubmit { project.setParameter(.duration, duration) }
                    }
                }
                section("Look") {
                    row("Starting look") { StartingLookMenu() }
                    row("Palette") {
                        if let p = f?.decisions.palette, !p.isEmpty { Swatches(colours: p) } else { Text("not chosen yet").font(.callout).foregroundStyle(.secondary) }
                    }
                    row("Titles font") { FontMenu(role: .titleFont) }
                    row("Text font") { FontMenu(role: .textFont) }
                    row("Default background") { BackgroundMenu() }
                    Text("A starting look sets all of these at once; each can still be changed here or later in the project settings.").font(.caption).foregroundStyle(.secondary)
                }
                if !missing.isEmpty {
                    Label("Still needed: " + missing.map { $0.title.lowercased() }.joined(separator: ", "), systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.orange)
                }
                Button("Open the workspace") { project.finishSetup() }.buttonStyle(.borderedProminent).controlSize(.large).disabledWithReason(f == nil ? "This project has no data yet" : missing.isEmpty ? nil : "Still to set: " + missing.map { $0.title.lowercased() }.joined(separator: ", "), way: f == nil ? "Confirm the import or create it with the banner above" : "Answer the questions above", caption: true)
            }
            .padding(28).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
        .onAppear { load() }
        .onChange(of: project.showreel) { _ in load() }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack { Text(label).font(.callout).frame(width: 150, alignment: .leading); content(); Spacer(minLength: 0) }
    }

    private func load() {
        guard let f = project.showreel else { return }
        if reel.isEmpty { reel = f.reelLanguages.joined(separator: ", ") }
        if duration.isEmpty { duration = f.decisions.duration.map { ProjectDocs.seconds($0) } ?? "" }
    }

    /// Typed values are recorded after a pause, like the project form does.
    private func later(_ work: @escaping () -> Void) {
        task?.cancel()
        let w = DispatchWorkItem(block: work)
        task = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: w)
    }

    private func toggle(_ fm: String, _ on: Bool) {
        var l = project.showreel?.decisions.formats ?? []
        if on, !l.contains(fm) { l.append(fm) } else if !on { l.removeAll { $0 == fm } }
        project.setParameter(.formats, l.joined(separator: ", "))
    }
}
