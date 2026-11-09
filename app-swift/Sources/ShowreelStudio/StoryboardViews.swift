import ShowreelKit
import SwiftUI

extension ShowreelFile.Scene {
    var durationLabel: String { duration.map { "\(ProjectDocs.seconds($0)) s" } ?? "no duration" }
}

/// The form of one scene of the library, one tab at a time (all of it when `tab` is nil, as in the wizard). Typed here, recorded with Save as
/// one typed operation (one card in the history, not one per keystroke). The drafts live in this view, so they stay when the tab changes.
struct SceneForm: View {
    let id: String
    var tab: SceneTab?
    @EnvironmentObject var project: ProjectModel
    @State private var duration = ""
    @State private var text = ""
    @State private var visual = ""
    @State private var feeling = ""
    @State private var handoff = ""
    @State private var linked: Set<String> = []
    @State private var loadedFor = ""

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private func shows(_ t: SceneTab) -> Bool { tab == nil || tab == t }

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
        if linked != current { e.assets = linked.sorted().joined(separator: ", ") }
        return e == SceneEdit() ? nil : e
    }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 10) {
                if shows(.settings) {
                    field("Duration (s)", $duration, width: 110)
                    area("Feeling and tension", $feeling, 2)
                    area("Passage to the next scene", $handoff, 2)
                }
                if shows(.composition) {
                    if tab == nil { area("On-screen text", $text, 3) }
                    area(tab == nil ? "Image and motion" : "Scene note (image and motion)", $visual, 2)
                }
                if tab == nil {            // in the workspace the composition holds the resources, as elements; the guided path links them here
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Linked resources").fontSmall(weight: .semibold).foregroundStyle(.secondary)
                        let usable = project.assets.filter { $0.type != "doc" && $0.type != "data" && $0.type != "note" && $0.type != "misc" }
                        if usable.isEmpty { Text("No resource yet: add files in the Resources tab of the library.").fontSmall().foregroundStyle(.secondary) }
                        ForEach(usable) { a in
                            Toggle(isOn: Binding(get: { linked.contains(a.id) }, set: { on in if on { linked.insert(a.id) } else { linked.remove(a.id) } })) {
                                HStack {
                                    Text(a.name).lineLimit(1)
                                    if let st = project.assetStatus[a.id] { Text(st.rawValue).fontSmall().foregroundStyle(st.color) }
                                }
                            }.toggleStyle(.checkbox)
                        }
                    }
                }
                HStack {
                    Button("Save scene") { if let e = edit { project.perform(.scene(id: id, e)) } }.buttonStyle(PrimaryButtonStyle()).disabledWithReason(s.isLocked ? "\(id) is locked" : edit == nil ? "Nothing to save yet: no change" : nil, way: s.isLocked ? "Unlock it from its badge or the Review block" : nil)
                    Button("Revert") { load(force: true) }.disabled(edit == nil)
                }
                if s.isLocked { Label("Locked: nothing in this scene can change. Unlock it from its badge or the Review block.", systemImage: "lock.fill").fontSmall().foregroundStyle(.secondary) }
                else if s.state == .validated, shows(.settings) || shows(.composition) { Text("Changing the text or the duration sends this scene back to To review.").fontSmall().foregroundStyle(.secondary) }
            }
            .onAppear { load(force: false) }
            .onChange(of: project.showreel) { _ in load(force: false) }
        }
    }

    private func field(_ label: String, _ b: Binding<String>, width: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).fontSmall(weight: .semibold).foregroundStyle(.secondary)
            TextField("", text: b).textFieldStyle(.roundedBorder).frame(maxWidth: width ?? .infinity)
        }
    }

    private func area(_ label: String, _ b: Binding<String>, _ lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).fontSmall(weight: .semibold).foregroundStyle(.secondary)
            TextEditor(text: b).font(.body).frame(height: CGFloat(lines) * 20 + 10).padding(2)
                .raisedBackground()
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
        }
    }

    /// Loads the saved values, unless the user has unsaved edits in this form.
    private func load(force: Bool) {
        guard let s = scene else { return }
        if !force, loadedFor == id, edit != nil { return }
        duration = s.duration.map { ProjectDocs.seconds($0) } ?? ""
        text = s.text; visual = s.visual; feeling = s.feeling; handoff = s.handoff
        linked = Set(project.assets.filter { $0.sceneIDs.contains(id) }.map { $0.id })
        loadedFor = id
    }
}

/// The scene list of the wizard's storyboard step: add, edit, reorder, delete. IDs are stable; moving a scene never renames it.
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
                    .help("Optional. Clap proposes scenes as cards you accept or refuse.")
            }
            if scenes.isEmpty {
                Text("No scene yet. Add one, or draft with the AI.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 20)
            } else {
                let ids = scenes.map { $0.id }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(scenes.enumerated()), id: \.element.id) { n, s in
                            VStack(spacing: 0) {
                                SlotGap(target: .librarySlot(before: s.id))
                                HStack(spacing: 8) {
                                    Handle()
                                    SceneStatusIcon(scene: s)
                                    Text(s.id).font(.callout.monospaced().weight(.semibold))
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(s.name ?? (s.text.isEmpty ? "(no text)" : s.text)).lineLimit(1).font(.callout)
                                        Text(s.durationLabel).fontSmall().foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(selected == s.id ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .contentShape(Rectangle())
                                .onTapGesture { selected = s.id }
                                .dragSource(.scene(s.id), label: s.label, icon: "film")
                                .dropTarget(.scene(s.id))
                                .dropSlots(before: .librarySlot(before: s.id), after: .librarySlot(before: n + 1 < ids.count ? ids[n + 1] : nil))
                                .contextMenu { SceneMenu(id: s.id) }
                            }
                            .transition(Motion.appear)
                        }
                        SlotGap(target: .librarySlot(before: nil))
                    }
                    .animation(Motion.spring, value: ids)
                    .padding(.horizontal, 4)
                }
                .frame(minHeight: 160, maxHeight: 300)
                Text("Drag to reorder: the order changes, the IDs never do.").fontSmall().foregroundStyle(.secondary)
                if let id = selected, scenes.contains(where: { $0.id == id }) {
                    Divider()
                    SceneForm(id: id).id(id)
                    Button("Delete scene\u{2026}", role: .destructive) { project.askDelete(id) }
                }
            }
        }
    }

    private func draft() {
        guard settings.hasKey else { project.error = "Drafting needs an AI. Connect one in Settings, or write the scenes by hand: everything else works without it."; return }
        project.showCopilot = true
        chat.ask(prompt: Wizard.draftScenesPrompt, status: "Scene draft requested")
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
                Text(blocker.map { "Not yet: \($0)." } ?? "Every visible scene is Ready. The build never starts without your Go, and the app never gives it for you.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Give the Go") { confirming = true }.buttonStyle(PrimaryButtonStyle()).disabled(blocker != nil)
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

/// The three switches of a scene, Visible, Ready and Locked, its instruction and the Delete button. Each switch is one typed operation (ShowreelKit's `SceneSwitches` decides what
/// is allowed and why not); an unavailable switch says why and how to get out of it.
struct SceneSwitchesView: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var note = ""
    @State private var loadedFor = ""

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }

    var body: some View {
        if let s = scene, let f = project.showreel {
            let visible = SceneSwitches.visible(s, in: f, activity: project.activity), ready = SceneSwitches.ready(s, activity: project.activity)
            let locked = SceneSwitches.locked(s, activity: project.activity), delete = SceneSwitches.delete(s, activity: project.activity)
            VStack(alignment: .leading, spacing: 8) {
                switchRow("Visible", systemImage: visible.on ? "eye" : "eye.slash", visible, help: "In the film. Off: hidden, listed under \u{201C}Not in the storyboard\u{201D}.")
                switchRow("Ready", systemImage: "checkmark.circle", ready, help: "You are satisfied with the scene. Off: To review.")
                switchRow("Locked", systemImage: "lock", locked, help: "Frozen in time and space: nothing in it or before it can change, and a Build never rewrites it. Only a Ready scene can be locked.")
                TextField("Instruction (what to change, or why)", text: $note, axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
                    .onSubmit { commitNote() }
                    .disabledWithReason(s.isLocked ? "\(id) is locked" : project.activity.isBuilding ? Reasons.building.reason : nil, way: s.isLocked ? "Unlock it first" : "Wait for the end, or Cancel the build")
                Text(s.toModify ? "To review, with an instruction: it is shown in the Status tooltip." : "To ask for a change: switch Ready off and write the instruction. Press Return to keep it.")
                    .fontSmall().foregroundStyle(.secondary)
                Button("Delete scene\u{2026}", role: .destructive) { project.askDelete(id) }
                    .disabledWithReason(delete.unavailable?.reason, way: delete.unavailable?.way)
                    .help("Deletes the scene for good, with a confirmation. Undo brings it back.")
            }
            .onAppear { if loadedFor != id { note = s.note; loadedFor = id } }
            .onChange(of: project.showreel) { _ in if loadedFor != id { note = s.note; loadedFor = id } }
        }
    }

    private func switchRow(_ title: String, systemImage: String, _ sw: SceneSwitches.Switch, help: String) -> some View {
        Toggle(isOn: Binding(get: { sw.on }, set: { _ in project.flip(sw) })) { Label(title, systemImage: systemImage) }
            .toggleStyle(ThemedToggleStyle())
            .disabledWithReason(sw.unavailable?.reason, way: sw.unavailable?.way)
            .help(sw.unavailable.map { $0.message } ?? help)
    }

    private func commitNote() {
        guard let s = scene, note != s.note else { return }
        project.perform(.scene(id: id, SceneEdit(note: note)))
    }
}
