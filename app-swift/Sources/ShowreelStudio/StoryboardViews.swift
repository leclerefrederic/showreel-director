import ShowreelKit
import SwiftUI

extension ShowreelFile.Scene {
    var durationLabel: String { duration.map { "\(ProjectDocs.seconds($0)) s" } ?? "no duration" }
}

/// The form of one scene of the library, one tab at a time (all of it when `tab` is nil, as in the wizard). There is no Save: each field commits through the one typed operation when it
/// loses focus, on Return, or after a pause in typing (ShowreelKit's `EditSession`), and Undo is the way back. The drafts live in `SceneAutosave`.
struct SceneForm: View {
    let id: String
    var tab: SceneTab?
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var theme: Theme
    @StateObject private var auto = SceneAutosave()
    @FocusState private var focus: String?
    @State private var lastFocus: String?

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private func shows(_ t: SceneTab) -> Bool { tab == nil || tab == t }
    private var linkedNow: Set<String> { Set(project.assets.filter { $0.sceneIDs.contains(id) }.map { $0.id }) }

    /// Why the fields cannot be edited now (a locked scene, a Build in progress), or nil.
    private var blockedReason: String? {
        if scene?.isLocked == true { return "\(id) is locked" }
        return project.blocked(.scene(id))?.reason
    }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    if shows(.settings) {
                        durationField
                        area("Feeling and tension", SceneFields.feeling, 2)
                        area("Passage to the next scene", SceneFields.handoff, 2)
                    }
                    if shows(.composition) {
                        if tab == nil { area("On-screen text", SceneFields.text, 3) }
                        area(tab == nil ? "Image and motion" : "Scene note (image and motion)", SceneFields.visual, 2)
                    }
                    if tab == nil {            // in the workspace the composition holds the resources, as elements; the guided path links them here
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text("Linked resources").fontSmall(weight: .semibold).foregroundStyle(.secondary); SavedMark(auto: auto, key: SceneFields.assets) }
                            let usable = project.assets.filter { $0.type != "doc" && $0.type != "data" && $0.type != "note" && $0.type != "misc" }
                            if usable.isEmpty { Text("No resource yet: add files in the Resources tab of the library.").fontSmall().foregroundStyle(.secondary) }
                            ForEach(usable) { a in
                                Toggle(isOn: Binding(get: { linkedDraft.contains(a.id) }, set: { on in
                                    var l = linkedDraft; if on { l.insert(a.id) } else { l.remove(a.id) }
                                    auto.edit(SceneFields.assets, l.sorted().joined(separator: ", "))
                                })) {
                                    HStack {
                                        Text(a.name).lineLimit(1)
                                        if let st = project.assetStatus[a.id] { Text(st.rawValue).fontSmall().foregroundStyle(st.color) }
                                    }
                                }.toggleStyle(.checkbox)
                            }
                        }
                    }
                }
                .disabledWithReason(blockedReason, way: s.isLocked ? "Unlock it from its badge or the Review block" : nil)
                if s.isLocked { Label("Locked: nothing in this scene can change. Unlock it from its badge or the Review block.", systemImage: "lock.fill").fontSmall().foregroundStyle(.secondary) }
            }
            .onAppear { auto.project = project; project.activeAutosave = auto; auto.bind(s, linked: linkedNow.sorted().joined(separator: ", ")) }
            .onDisappear { auto.flush(); if project.activeAutosave === auto { project.activeAutosave = nil } }
            .onChange(of: project.showreel) { _ in if let s = scene { auto.bind(s, linked: linkedNow.sorted().joined(separator: ", ")) } }
            .onChange(of: id) { _ in auto.flush() }
            .onChange(of: focus) { now in
                if let was = lastFocus, was != now { auto.blur(was) }
                lastFocus = now
            }
        }
    }

    private var linkedDraft: Set<String> { Set(auto.draft(SceneFields.assets).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }) }

    private func binding(_ key: String) -> Binding<String> { Binding(get: { auto.draft(key) }, set: { auto.edit(key, $0, stepped: false) }) }

    private func label(_ text: String, _ key: String) -> some View {
        HStack(spacing: 6) { Text(text).fontSmall(weight: .semibold).foregroundStyle(.secondary); SavedMark(auto: auto, key: key) }
    }

    /// The reason a draft was not saved, next to the field, with the way out.
    @ViewBuilder private func problem(_ key: String) -> some View {
        if let why = auto.invalid(key) {
            HStack(spacing: 6) {
                Text(why).fontSmall().foregroundStyle(theme.danger)
                Button("Restore the saved value") { auto.restore(key) }.buttonStyle(.borderless).fontSmall()
            }
        }
    }

    private var durationField: some View {
        VStack(alignment: .leading, spacing: 2) {
            label("Duration (s)", SceneFields.duration)
            StepperField(text: binding(SceneFields.duration), onStep: { auto.step(SceneFields.duration) }, onCommit: { auto.returnKey(SceneFields.duration) })
                .focused($focus, equals: SceneFields.duration)
            problem(SceneFields.duration)
        }
    }

    private func field(_ title: String, _ key: String, width: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label(title, key)
            TextField("", text: binding(key)).textFieldStyle(ThemedTextFieldStyle()).frame(maxWidth: width ?? .infinity)
                .focused($focus, equals: key).onSubmit { auto.returnKey(key) }
            problem(key)
        }
    }

    /// A placeholder that is a real example of what the field holds.
    private let placeholders = [SceneFields.feeling: "For example: calm, then a sudden lift", SceneFields.handoff: "For example: the title slides out as the next scene's background rises",
                                SceneFields.text: "For example: One tool for every launch", SceneFields.visual: "For example: a slow push-in on the product, soft light"]

    private func area(_ title: String, _ key: String, _ lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label(title, key)
            GrowingTextEditor(text: binding(key), placeholder: placeholders[key] ?? "")
                .environment(\.fieldError, auto.invalid(key))
                .focused($focus, equals: key)
            problem(key)
        }
    }
}

/// The small mark next to a field's label after a commit: "Saved" (a check) or "Updated" (a change made elsewhere); it fades after about 1.5 s, and is static under Reduce motion.
struct SavedMark: View {
    @ObservedObject var auto: SceneAutosave
    let key: String
    @EnvironmentObject var theme: Theme

    var body: some View {
        Group {
            switch auto.marks[key] {
            case .saved?: Label("Saved", systemImage: "checkmark").fontSmall().foregroundStyle(theme.success).transition(.opacity)
            case .updated?: Label("Updated", systemImage: "arrow.triangle.2.circlepath").fontSmall().foregroundStyle(theme.textSecondary).transition(.opacity)
            case nil: EmptyView()
            }
        }
        .animation(Motion.settle, value: auto.marks[key] == nil)
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
                    .buttonStyle(DestructiveButtonStyle())
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

/// The three switches of a scene, Visible, Ready and Locked, its instruction and the Delete button. Each switch is one typed operation (ShowreelKit's `SceneSwitches` decides what
/// is allowed and why not); an unavailable switch says why and how to get out of it.
struct SceneSwitchesView: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }

    var body: some View {
        if let s = scene, let f = project.showreel {
            let visible = SceneSwitches.visible(s, in: f, activity: project.activity), ready = SceneSwitches.ready(s, activity: project.activity)
            let locked = SceneSwitches.locked(s, activity: project.activity), delete = SceneSwitches.delete(s, activity: project.activity)
            VStack(alignment: .leading, spacing: 8) {
                switchRow("Visible", systemImage: visible.on ? "eye" : "eye.slash", visible, help: "In the film. Off: hidden, listed under \u{201C}Not in the storyboard\u{201D}.")
                switchRow("Ready", systemImage: "checkmark.circle", ready, help: "You are satisfied with the scene. Off: To review.")
                switchRow("Locked", systemImage: "lock", locked, help: "Frozen in time and space: nothing in it or before it can change, and a Build never rewrites it. Only a Ready scene can be locked.")
                if s.toModify { Text("Earlier note: \(s.note)").fontSmall().foregroundStyle(.secondary).lineLimit(3).help("A note kept from an earlier change request. It is read-only here; the Status tooltip shows it too.") }
                Button("Delete scene\u{2026}", role: .destructive) { project.askDelete(id) }
                    .disabledWithReason(delete.unavailable?.reason, way: delete.unavailable?.way)
                    .help("Deletes the scene for good, with a confirmation. Undo brings it back.")
            }
        }
    }

    private func switchRow(_ title: String, systemImage: String, _ sw: SceneSwitches.Switch, help: String) -> some View {
        IconRow(symbol: systemImage, title: title) {
            Toggle("", isOn: Binding(get: { sw.on }, set: { _ in project.flip(sw) })).labelsHidden().toggleStyle(ThemedToggleStyle())
        }
            .disabledWithReason(sw.unavailable?.reason, way: sw.unavailable?.way)
            .help(sw.unavailable.map { $0.message } ?? help)
    }
}
