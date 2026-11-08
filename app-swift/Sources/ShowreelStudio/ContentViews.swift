import ShowreelKit
import SwiftUI

/// The Content tab of a scene: the ordered list of what the scene contains. The order is the processing priority.
struct SceneContentTab: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private var level: ControlLevel { scene.flatMap { project.showreel?.controlLevel(for: $0) } ?? .auto }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 14) {
                InspectorSection(title: "Control level") {
                    Picker("", selection: Binding(get: { s.controlLevel ?? "" }, set: { project.setControlLevel(id, $0) })) {
                        Text("Project's (\(project.showreel?.parameters.controlLevel ?? "auto"))").tag("")
                        ForEach(ControlLevel.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }.labelsHidden()
                    Text("\(level.help) It sets the defaults of new items; any attribute can be changed item by item.").font(.caption).foregroundStyle(.secondary)
                }
                InspectorSection(title: "Content, in priority order") {
                    Text("The AI treats the items from the first to the last: the earlier ones win conflicts of time, space and emphasis, and the last ones are simplified or dropped first if the film does not fit. This is not the stacking order on screen.")
                        .font(.caption).foregroundStyle(.secondary)
                    if s.content.isEmpty { Text("Nothing yet. Add the words, an image or a sound.").font(.callout).foregroundStyle(.secondary) }
                    ForEach(Array(s.content.enumerated()), id: \.element.id) { n, item in
                        ContentItemRow(scene: id, item: item, priority: n + 1, count: s.content.count).id(item.id)
                    }
                    Menu {
                        ForEach(ContentRules.types, id: \.self) { t in Button(ContentRules.title(t)) { project.addItem(id, type: t) } }
                    } label: { Label("Add an item", systemImage: "plus") }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                if let c = project.checks["scene"]?.first(where: { $0.id == "content.\(id)" }) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: c.level.symbol).foregroundStyle(c.level.color)
                        Text(c.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                SceneForm(id: id, tab: .content)
            }
        }
    }
}

struct FixedBadge: View {
    let fixed: Bool
    var body: some View {
        Text(fixed ? "fixed" : "auto").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 1)
            .background((fixed ? Color.accentColor : Color.secondary).opacity(0.18), in: Capsule())
            .foregroundStyle(fixed ? Color.accentColor : .secondary)
    }
}

/// One item: its subject, colour, animation and instruction, each fixed or auto. Typed here, recorded with Apply or at once for the pickers.
struct ContentItemRow: View {
    let scene: String
    let item: ShowreelFile.ContentItem
    let priority: Int
    let count: Int
    @EnvironmentObject var project: ProjectModel
    @State private var words = ""
    @State private var params = ""
    @State private var instruction = ""
    @State private var hex = "#FFFFFF"

    private var open: Binding<Bool> {
        Binding(get: { project.contentItem == item.id }, set: { project.contentItem = $0 ? item.id : nil })
    }
    private static let effects: [(cat: String, name: String)] = Look.effectList().filter { $0.cat != EngineCatalogue.transitionCategory }
    private var dirty: Bool { words != (item.text ?? "") || params != item.animation.paramsText || instruction != (item.instruction ?? "") }

    private var colorChoice: String { item.color.mode == "role" ? (item.color.role ?? "text") : item.color.mode == "custom" ? "custom" : "auto" }

    var body: some View {
        DisclosureGroup(isExpanded: open) {
            VStack(alignment: .leading, spacing: 8) {
                subject
                if item.type == "text" { colour }
                if item.type != "audio" { animation }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Instruction for the AI (optional)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("In your words", text: $instruction, axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Apply") { apply() }.buttonStyle(.borderedProminent).disabled(!dirty)
                    Button("Up") { project.moveItem(scene, item.id, by: -1) }.disabled(priority == 1).help("Higher priority")
                    Button("Down") { project.moveItem(scene, item.id, by: 1) }.disabled(priority == count).help("Lower priority")
                    Spacer()
                    Button("Remove", role: .destructive) { project.removeItem(scene, item.id) }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 6) {
                Text("\(priority)").font(.caption.monospacedDigit().weight(.bold)).frame(width: 18).help("Processing priority")
                Image(systemName: item.type == "text" ? "textformat" : item.type == "image" ? "photo" : "waveform").foregroundStyle(.secondary)
                Text(label).lineLimit(1).font(.callout)
                Spacer(minLength: 4)
                if item.color.isFixed { FixedBadge(fixed: true).help("Colour fixed") }
                if item.animation.isFixed { Image(systemName: "sparkles").font(.caption).foregroundStyle(Color.accentColor).help("Animation fixed: \(item.animation.text)") }
            }
        }
        .onAppear { load() }
        .onChange(of: item) { _ in load() }
    }

    private var label: String {
        if item.type == "text" { return (item.text ?? "").isEmpty ? "(no words)" : item.text! }
        return project.assets.first { $0.id == item.resource }?.name ?? item.resource ?? "(no resource)"
    }

    private func load() { words = item.text ?? ""; params = item.animation.paramsText; instruction = item.instruction ?? ""; hex = item.color.hex ?? "#FFFFFF" }

    private func apply() {
        var e = ContentEdit()
        if words != (item.text ?? ""), item.type == "text" { e.text = words }
        if params != item.animation.paramsText, item.animation.mode == "effect" { e.params = params }
        if instruction != (item.instruction ?? "") { e.instruction = instruction }
        if e != ContentEdit() { project.updateItem(scene, item.id, e) }
    }

    @ViewBuilder private var subject: some View {
        if item.type == "text" {
            VStack(alignment: .leading, spacing: 2) {
                Text("Words").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField("", text: $words, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder)
            }
        } else {
            let fit = project.assets.filter { ContentRules.accepts(item.type, asset: $0.type) && $0.status != "excluded" }
            VStack(alignment: .leading, spacing: 2) {
                Text("Resource").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("", selection: Binding(get: { item.resource ?? "" }, set: { project.updateItem(scene, item.id, ContentEdit(resource: $0)) })) {
                    ForEach(fit) { Text("\($0.name) (\(project.assetStatus[$0.id]?.rawValue ?? $0.status))").tag($0.id) }
                }.labelsHidden()
            }
        }
    }

    private var colour: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text("Colour").font(.caption.weight(.semibold)).foregroundStyle(.secondary); FixedBadge(fixed: item.color.isFixed) }
            HStack {
                Picker("", selection: Binding(get: { colorChoice }, set: { v in
                    if v == "custom" { project.updateItem(scene, item.id, ContentEdit(color: hex)) } else { project.updateItem(scene, item.id, ContentEdit(color: v)) }
                })) {
                    Text("Auto (the AI decides)").tag("auto")
                    ForEach(PaletteRole.allCases, id: \.rawValue) { Text($0.title + " (palette)").tag($0.rawValue) }
                    Text("Custom colour").tag("custom")
                }.labelsHidden()
                if item.color.mode == "custom" {
                    ColorPicker("", selection: Binding(get: { Color(hex: item.color.hex ?? "#FFFFFF") }, set: { project.updateItem(scene, item.id, ContentEdit(color: $0.hexString)) }), supportsOpacity: false).labelsHidden()
                    Text(item.color.hex ?? "").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var animation: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text("Animation").font(.caption.weight(.semibold)).foregroundStyle(.secondary); FixedBadge(fixed: item.animation.isFixed) }
            Picker("", selection: Binding(get: { item.animation.mode == "effect" ? (item.animation.effect ?? "auto") : "auto" }, set: { project.updateItem(scene, item.id, ContentEdit(animation: $0)) })) {
                Text("Auto (the AI decides)").tag("auto")
                ForEach(Self.effects, id: \.name) { Text("\($0.name) · \($0.cat)").tag($0.name) }
            }.labelsHidden()
            if item.animation.mode == "effect" {
                TextField("Parameters (key=value, key=value)", text: $params).textFieldStyle(.roundedBorder).font(.caption).onSubmit { apply() }
            }
        }
    }
}
