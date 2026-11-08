import ShowreelKit
import SwiftUI

extension ShowreelFile.Scene {
    var durationLabel: String { duration.map { "\(ProjectDocs.seconds($0)) s" } ?? "no duration" }
    var statusColor: Color { switch status { case "ok": return .green; case "modify": return .orange; case "ditched": return .secondary; default: return .blue } }
    var statusSymbol: String { switch status { case "ok": return "checkmark.circle.fill"; case "modify": return "pencil.circle.fill"; case "ditched": return "xmark.circle"; default: return "circle" } }
}

/// The form of one scene of the library. Typed here, recorded with Save as one typed operation (one card in the history, not one per keystroke).
struct SceneForm: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var duration = ""
    @State private var text = ""
    @State private var visual = ""
    @State private var feeling = ""
    @State private var handoff = ""
    @State private var inCuts = ""
    @State private var linked: Set<String> = []
    @State private var loadedFor = ""

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }

    private var edit: SceneEdit? {
        guard let s = scene else { return nil }
        func secs(_ x: Double?) -> String { x.map { ProjectDocs.seconds($0) } ?? "" }
        let current = Set(project.assets.filter { $0.sceneIDs.contains(id) }.map { $0.id })
        var e = SceneEdit()
        if duration != secs(s.duration) { e.duration = duration }
        if text != s.text { e.text = text }
        if visual != s.visual { e.visual = visual }
        if feeling != s.feeling { e.feeling = feeling }
        if handoff != s.handoff { e.handoff = handoff }
        if inCuts != s.inCuts { e.inCuts = inCuts }
        if linked != current { e.assets = linked.sorted().joined(separator: ", ") }
        return e == SceneEdit() ? nil : e
    }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 10) {
                field("Duration (s)", $duration, width: 110)
                area("On-screen text", $text, 3)
                area("Image and motion", $visual, 2)
                area("Feeling and tension", $feeling, 2)
                area("Passage to the next scene", $handoff, 2)
                field("In cuts (for example 15s, 45s)", $inCuts, width: nil)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Linked resources").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    let usable = project.assets.filter { $0.type != "doc" && $0.type != "data" && $0.type != "note" && $0.type != "misc" }
                    if usable.isEmpty { Text("No resource yet: add files in the Resources tab.").font(.caption).foregroundStyle(.secondary) }
                    ForEach(usable) { a in
                        Toggle(isOn: Binding(get: { linked.contains(a.id) }, set: { on in if on { linked.insert(a.id) } else { linked.remove(a.id) } })) {
                            HStack { Text(a.name).lineLimit(1); Text(a.status).font(.caption).foregroundStyle(a.status == "approved" ? Color.green : .orange) }
                        }.toggleStyle(.checkbox)
                    }
                }
                HStack {
                    Button("Save scene") { if let e = edit { project.perform(.scene(id: id, e)) } }.buttonStyle(.borderedProminent).disabled(edit == nil)
                    Button("Revert") { load(force: true) }.disabled(edit == nil)
                }
                if s.status == "ok" { Text("Changing the text or the duration sends this scene back to review.").font(.caption).foregroundStyle(.secondary) }
            }
            .onAppear { load(force: false) }
            .onChange(of: project.showreel) { _ in load(force: false) }
        }
    }

    private func field(_ label: String, _ b: Binding<String>, width: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField("", text: b).textFieldStyle(.roundedBorder).frame(maxWidth: width ?? .infinity)
        }
    }

    private func area(_ label: String, _ b: Binding<String>, _ lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: b).font(.body).frame(height: CGFloat(lines) * 20 + 10).padding(2)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
        }
    }

    /// Loads the saved values, unless the user has unsaved edits in this form.
    private func load(force: Bool) {
        guard let s = scene else { return }
        if !force, loadedFor == id, edit != nil { return }
        duration = s.duration.map { ProjectDocs.seconds($0) } ?? ""
        text = s.text; visual = s.visual; feeling = s.feeling; handoff = s.handoff; inCuts = s.inCuts
        linked = Set(project.assets.filter { $0.sceneIDs.contains(id) }.map { $0.id })
        loadedFor = id
    }
}

/// The scene list of the wizard's storyboard step: add, edit, reorder, archive. IDs are stable; moving a scene never renames it.
struct SceneListEditor: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings
    @State private var selected: String?

    private var scenes: [ShowreelFile.Scene] { project.showreel?.orderedLibrary ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { if project.addScene(), let n = project.showreel?.scenes.last { selected = n.id } } label: { Label("Add scene", systemImage: "plus") }
                Button { draft() } label: { Label("Draft with AI", systemImage: "sparkles") }
                    .help("Optional. The copilot proposes scenes as cards you accept or refuse.")
            }
            if scenes.isEmpty {
                Text("No scene yet. Add one, or draft with the AI.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 20)
            } else {
                List(selection: $selected) {
                    ForEach(scenes) { s in
                        HStack(spacing: 8) {
                            Image(systemName: s.statusSymbol).foregroundStyle(s.statusColor)
                            Text(s.id).font(.callout.monospaced().weight(.semibold))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(s.text.isEmpty ? "(no text)" : s.text).lineLimit(1).font(.callout)
                                Text(s.durationLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.tag(s.id)
                    }
                    .onMove { from, to in move(from, to) }
                }
                .frame(minHeight: 160, maxHeight: 300)
                Text("Drag to reorder: the order changes, the IDs never do.").font(.caption).foregroundStyle(.secondary)
                if let id = selected, scenes.contains(where: { $0.id == id }) {
                    Divider()
                    SceneForm(id: id).id(id)
                    Button("Archive scene", role: .destructive) { project.archiveScene(id); selected = nil }
                }
            }
        }
    }

    private func move(_ from: IndexSet, _ to: Int) {
        guard let i = from.first else { return }
        let moved = scenes[i].id
        let dest = to > i ? to : to       // `to` is the index the row lands before, in the list as it was
        let target: String? = dest >= scenes.count ? nil : scenes[dest].id
        project.moveScene(moved, before: target == moved ? nil : target)
    }

    private func draft() {
        guard settings.hasKey else { project.error = "Drafting needs an AI. Connect one in Settings, or write the scenes by hand: everything else works without it."; return }
        project.showCopilot = true
        chat.ask(prompt: Wizard.draftScenesPrompt)
    }
}

/// The explicit Go. It is only ever given by this button; nothing deduces it, and the copilot has no way to press it.
struct GoPanel: View {
    @EnvironmentObject var project: ProjectModel
    @State private var confirming = false

    private var given: Bool { project.showreel?.gates["review"] == "passed" }
    private var blocker: String? { project.store.goBlocking() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: given ? "checkmark.seal.fill" : "flag.checkered").foregroundStyle(given ? Color.green : .secondary)
                Text(given ? "The Go is given" : "The Go").font(.headline)
            }
            if given {
                Text("The build may start. If you change a scene, the Go is taken back and must be given again.").font(.callout).foregroundStyle(.secondary)
                Button("Take the Go back") { project.perform(.gate("review", passed: false)) }
            } else {
                Text(blocker.map { "Not yet: \($0)." } ?? "Every scene is OK or ditched. The build never starts without your Go, and the app never gives it for you.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Give the Go") { confirming = true }.buttonStyle(.borderedProminent).disabled(blocker != nil)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert("Give the Go?", isPresented: $confirming) {
            Button("Give the Go") { project.perform(.gate("review", passed: true)) }
            Button("Not yet", role: .cancel) {}
        } message: { Text("This is your decision to start the build. If you change a scene afterwards, the Go is taken back.") }
    }
}

/// The Go as a button for the toolbar and the storyboard strip. Same rule as the panel: explicit, never deduced.
struct GoButton: View {
    @EnvironmentObject var project: ProjectModel
    @State private var confirming = false

    private var given: Bool { project.showreel?.gates["review"] == "passed" }
    private var blocker: String? { project.store.goBlocking() }

    var body: some View {
        Button {
            if given { project.perform(.gate("review", passed: false)) } else { confirming = true }
        } label: {
            Label(given ? "Go given" : "Give the Go", systemImage: given ? "checkmark.seal.fill" : "flag.checkered")
        }
        .tint(given ? .green : nil)
        .disabled(!given && blocker != nil)
        .help(given ? "The build may start. Click to take the Go back." : (blocker.map { "Not yet: \($0)." } ?? "Your decision to start the build. The app never gives it for you."))
        .alert("Give the Go?", isPresented: $confirming) {
            Button("Give the Go") { project.perform(.gate("review", passed: true)) }
            Button("Not yet", role: .cancel) {}
        } message: { Text("This is your decision to start the build. If you change a scene afterwards, the Go is taken back.") }
    }
}

/// Mark one scene OK, MODIFY or DITCH, with a note.
struct SceneDecision: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var note = ""
    @State private var loadedFor = ""
    @State private var ditching = false

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review").font(.headline)
                TextField("Note (what to change, or why)", text: $note, axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
                HStack {
                    Button("OK") { decide("ok") }.buttonStyle(.borderedProminent).tint(.green).disabled(s.status == "ok" && note == s.note)
                    Button("MODIFY") { decide("modify") }.tint(.orange).disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("DITCH", role: .destructive) { ditching = true }
                    Spacer()
                    Label(s.status.capitalized, systemImage: s.statusSymbol).foregroundStyle(s.statusColor)
                }
                if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("MODIFY needs a note that says what to change.").font(.caption).foregroundStyle(.secondary) }
            }
            .onAppear { if loadedFor != id { note = s.note; loadedFor = id } }
            .onChange(of: project.showreel) { _ in if loadedFor != id { note = s.note; loadedFor = id } }
            .alert("Ditch \(id)?", isPresented: $ditching) {
                Button("Ditch", role: .destructive) { decide("ditched") }
                Button("Cancel", role: .cancel) {}
            } message: { Text("The scene is archived and switched off in every montage. Its ID is never reused. You can bring it back from the library.") }
        }
    }

    private func decide(_ status: String) {
        project.perform(.scene(id: id, SceneEdit(note: note, status: status)))
    }
}
