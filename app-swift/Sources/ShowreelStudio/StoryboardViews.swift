import ShowreelKit
import SwiftUI

extension ShowreelFile.Scene {
    var timeLabel: String {
        guard let a = start, let b = end else { return "no time" }
        return "\(ProjectDocs.seconds(a))-\(ProjectDocs.seconds(b)) s"
    }
    var statusColor: Color { switch status { case "ok": return .green; case "modify": return .orange; case "ditched": return .secondary; default: return .blue } }
    var statusSymbol: String { switch status { case "ok": return "checkmark.circle.fill"; case "modify": return "pencil.circle.fill"; case "ditched": return "xmark.circle"; default: return "circle" } }
}

/// The form of one scene. Typed here, recorded with Save as one typed operation (one card in the history, not one per keystroke).
struct SceneForm: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var start = ""
    @State private var end = ""
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
        if start != secs(s.start) { e.start = start }
        if end != secs(s.end) { e.end = end }
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
                HStack {
                    Text(s.id).font(.headline.monospaced())
                    Label(s.status.capitalized, systemImage: s.statusSymbol).foregroundStyle(s.statusColor).font(.callout)
                    Spacer()
                }
                HStack {
                    field("Start (s)", $start, width: 90); field("End (s)", $end, width: 90)
                }
                area("On-screen text", $text, 3)
                area("Image and motion", $visual, 2)
                HStack(alignment: .top) { area("Feeling and tension", $feeling, 2); area("Handoff to the next scene", $handoff, 2) }
                field("In cuts (for example 15s, 45s)", $inCuts, width: nil)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Linked resources").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if project.assets.isEmpty { Text("No resource yet: add files in Resources.").font(.caption).foregroundStyle(.secondary) }
                    else {
                        ForEach(project.assets.filter { $0.type != "doc" && $0.type != "data" && $0.type != "note" && $0.type != "misc" }) { a in
                            Toggle(isOn: Binding(get: { linked.contains(a.id) }, set: { on in if on { linked.insert(a.id) } else { linked.remove(a.id) } })) {
                                HStack { Text(a.name); Text(a.status).font(.caption).foregroundStyle(a.status == "approved" ? Color.green : .orange) }
                            }.toggleStyle(.checkbox)
                        }
                    }
                }
                HStack {
                    Button("Save scene") { if let e = edit { project.perform(.scene(id: id, e)) } }.buttonStyle(.borderedProminent).disabled(edit == nil)
                    Button("Revert") { load(force: true) }.disabled(edit == nil)
                    if s.status == "ok" { Text("Changing the text or the timing sends this scene back to review.").font(.caption).foregroundStyle(.secondary) }
                }
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
        func secs(_ x: Double?) -> String { x.map { ProjectDocs.seconds($0) } ?? "" }
        start = secs(s.start); end = secs(s.end); text = s.text; visual = s.visual; feeling = s.feeling; handoff = s.handoff; inCuts = s.inCuts
        linked = Set(project.assets.filter { $0.sceneIDs.contains(id) }.map { $0.id })
        loadedFor = id
    }
}

/// The scene list with its editor: add, edit, reorder, ditch. IDs are stable; moving a scene never renames it.
struct StoryboardEditor: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings
    @State private var selected: String?
    @State private var ditching: String?

    private var scenes: [ShowreelFile.Scene] { project.showreel?.scenes ?? [] }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button { add() } label: { Label("Add scene", systemImage: "plus") }
                    Button { draft() } label: { Label("Draft with AI", systemImage: "sparkles") }
                        .help("Optional. The copilot proposes scenes as cards you accept or refuse.")
                }
                if scenes.isEmpty {
                    Text("No scene yet. Add one, or draft with the AI.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 20)
                } else {
                    List(selection: $selected) {
                        ForEach(scenes) { s in row(s).tag(s.id) }
                            .onMove { from, to in move(from, to) }
                    }
                    .frame(minHeight: 220, maxHeight: 420)
                }
                Text("Drag to reorder: the order changes, the IDs never do. A ditched scene keeps its ID.").font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 330)
            VStack(alignment: .leading) {
                if let id = selected, scenes.contains(where: { $0.id == id }) {
                    SceneForm(id: id).id(id)
                    HStack {
                        if scenes.first(where: { $0.id == id })?.status == "ditched" {
                            Button("Bring it back") { project.perform(.scene(id: id, SceneEdit(status: "open"))) }
                        } else {
                            Button("Ditch scene", role: .destructive) { ditching = id }
                        }
                    }
                } else {
                    Text("Pick a scene to edit it.").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .alert("Ditch \(ditching ?? "")?", isPresented: Binding(get: { ditching != nil }, set: { if !$0 { ditching = nil } })) {
            Button("Ditch", role: .destructive) { if let d = ditching { project.perform(.scene(id: d, SceneEdit(status: "ditched"))) }; ditching = nil }
            Button("Cancel", role: .cancel) { ditching = nil }
        } message: { Text("The scene stays in the list, marked ditched, and its ID is never reused. You can bring it back.") }
        .onAppear { if selected == nil { selected = scenes.first?.id } }
    }

    private func row(_ s: ShowreelFile.Scene) -> some View {
        HStack(spacing: 8) {
            Image(systemName: s.statusSymbol).foregroundStyle(s.statusColor)
            Text(s.id).font(.callout.monospaced().weight(.semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(s.text.isEmpty ? "(no text)" : s.text).lineLimit(1).font(.callout)
                Text(s.timeLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .opacity(s.status == "ditched" ? 0.5 : 1)
        .strikethrough(s.status == "ditched")
    }

    private func add() {
        let last = scenes.last { $0.status != "ditched" }
        let start = last?.end ?? 0
        var e = SceneEdit(start: ProjectDocs.seconds(start), end: ProjectDocs.seconds(start + 3))
        if let l = scenes.last { e.after = l.id }
        let before = Set(scenes.map { $0.id })
        if project.perform(.addScene(id: "", e)) { selected = project.showreel?.scenes.first { !before.contains($0.id) }?.id }
    }

    private func move(_ from: IndexSet, _ to: Int) {
        guard let i = from.first else { return }
        var order = scenes.map { $0.id }
        let moved = order.remove(at: i)
        let dest = to > i ? to - 1 : to
        order.insert(moved, at: dest)
        let after = dest == 0 ? "start" : order[dest - 1]
        project.perform(.scene(id: moved, SceneEdit(after: after)))
    }

    private func draft() {
        guard settings.hasKey else { project.error = "Drafting needs an AI. Connect one in Settings, or write the scenes by hand: everything else works without it."; return }
        project.showCopilot = true
        chat.ask(prompt: "I am writing the storyboard. From the project (get_state: audience, message, tone, duration, look, assets), draft the scenes in order and propose each one with add_scene so I can accept or refuse each card. Keep to the duration, give every scene a start and an end, keep lines short enough for the reading budget, and link only approved assets.")
    }
}

struct StoryboardBlockView: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storyboard").font(.title2.weight(.semibold))
                        Text("The film, scene by scene. The reading budget and the feasibility are checked as you write, without an AI.").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if project.showreel != nil { ValidateButton(gate: "storyboard", block: "storyboard") }
                }
                if project.showreel == nil {
                    Text("This project has no data yet. Confirm the import or create it with the banner above.").foregroundStyle(.secondary)
                } else {
                    StoryboardEditor()
                    ChecksPanel(block: "storyboard")
                }
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: scene editor and the Go

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

/// Mark one scene OK, MODIFY or DITCH, with a note.
struct SceneDecision: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var note = ""
    @State private var loadedFor = ""

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your decision").font(.headline)
                TextField("Note (what to change, or why)", text: $note, axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
                HStack {
                    Button("OK") { decide("ok") }.buttonStyle(.borderedProminent).tint(.green).disabled(s.status == "ok" && note == s.note)
                    Button("MODIFY") { decide("modify") }.tint(.orange).disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("DITCH", role: .destructive) { decide("ditched") }
                    Spacer()
                    Label(s.status.capitalized, systemImage: s.statusSymbol).foregroundStyle(s.statusColor)
                }
                if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("MODIFY needs a note that says what to change.").font(.caption).foregroundStyle(.secondary) }
            }
            .onAppear { if loadedFor != id { note = s.note; loadedFor = id } }
            .onChange(of: project.showreel) { _ in if loadedFor != id { note = s.note; loadedFor = id } }
        }
    }

    private func decide(_ status: String) {
        project.perform(.scene(id: id, SceneEdit(note: note, status: status)))
    }
}

struct SceneEditorBlockView: View {
    @EnvironmentObject var project: ProjectModel
    @State private var selected: String?

    private var live: [ShowreelFile.Scene] { SceneRules.live(project.showreel ?? ShowreelFile(name: "")) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scene editor").font(.title2.weight(.semibold))
                    Text("Go through the scenes one at a time: OK, MODIFY or DITCH, with a note. When every scene is decided, you give the Go.").font(.callout).foregroundStyle(.secondary)
                }
                if live.isEmpty {
                    Text("No scene to review yet. Write the storyboard first.").foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        List(selection: $selected) {
                            ForEach(live) { s in
                                HStack { Image(systemName: s.statusSymbol).foregroundStyle(s.statusColor); Text(s.id).font(.callout.monospaced().weight(.semibold)); Text(s.text.isEmpty ? "(no text)" : s.text).lineLimit(1) }.tag(s.id)
                            }
                        }
                        .frame(width: 260, height: min(CGFloat(live.count) * 30 + 20, 360))
                        VStack(alignment: .leading, spacing: 14) {
                            if let id = selected ?? live.first?.id {
                                SceneForm(id: id).id(id)
                                Divider()
                                SceneDecision(id: id).id(id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ChecksPanel(block: "scene")
                    GoPanel()
                }
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { if selected == nil { selected = live.first?.id } }
    }
}
