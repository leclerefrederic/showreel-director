import ShowreelKit
import SwiftUI

/// The Composition tab of a scene: everything the scene is made of, in priority order. Words, images and sounds are elements of one list, and the order is
/// the processing priority. A resource linked to the scene is one of them.
struct SceneCompositionTab: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private var level: ControlLevel { scene.flatMap { project.showreel?.controlLevel(for: $0) } ?? .auto }

    /// Resources that could be added as elements: not used by this scene yet, usable, and something that is shown or heard.
    private func addable(_ s: ShowreelFile.Scene) -> [AssetRow] {
        let used = Set(s.content.compactMap { $0.resource })
        return project.assets.filter { ContentRules.elementType(for: $0.type) != nil && $0.status != "excluded" && $0.status != "hold" && !used.contains($0.id) }
    }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 14) {
                InspectorSection(title: "Control level") {
                    Picker("", selection: Binding(get: { s.controlLevel ?? "" }, set: { project.setControlLevel(id, $0) })) {
                        Text("Project's (\(project.showreel?.parameters.controlLevel ?? "auto"))").tag("")
                        ForEach(ControlLevel.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }.labelsHidden()
                    Text("\(level.help) It sets the defaults of new elements; any attribute can be changed element by element.").fontSmall().foregroundStyle(.secondary)
                }
                InspectorSection(title: "Composition, in priority order") {
                    Text("The AI treats the elements from the first to the last: the earlier ones win conflicts of time, space and emphasis, and the last ones are simplified or dropped first if the film does not fit. This is not the stacking order on screen. A resource linked to the scene is an element too.")
                        .fontSmall().foregroundStyle(.secondary)
                    if s.content.isEmpty {
                        Text("Nothing yet. Add the words, or drop an image, a sound or a file here.").font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .registers(.contentSlot(scene: id, before: nil))
                    }
                    // the rows are dragged by their handle to change the priority: a gap opens where the element would land
                    let ids = s.content.map { $0.id }
                    VStack(spacing: 0) {
                        ForEach(Array(s.content.enumerated()), id: \.element.id) { n, item in
                            VStack(spacing: 0) {
                                SlotGap(target: .contentSlot(scene: id, before: item.id))
                                ContentItemRow(scene: id, item: item, priority: n + 1, count: s.content.count).id(item.id)
                                    .padding(.vertical, 2)
                                    .dropTarget(.contentItem(scene: id, item: item.id))
                                    .dropSlots(before: .contentSlot(scene: id, before: item.id), after: .contentSlot(scene: id, before: n + 1 < ids.count ? ids[n + 1] : nil))
                            }
                            .transition(Motion.appear)
                        }
                        SlotGap(target: .contentSlot(scene: id, before: nil))
                    }
                    .animation(Motion.spring, value: ids)
                    Menu {
                        Button("Words") { project.addItem(id, type: "text") }
                        let more = addable(s)
                        if !more.isEmpty { Divider(); Text("From the resources") }
                        ForEach(more) { a in Button(a.name) { project.addResource(id, a.id) } }
                    } label: { Label("Add an element", systemImage: "plus") }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                let leftovers = (project.trees[id]?.first { $0.group == .composition }?.nodes ?? []).filter { $0.id.hasPrefix("raw.") }
                if !leftovers.isEmpty {
                    InspectorSection(title: "Other linked resources") {
                        Text("Linked to the scene, but not shown or heard: a font, a file that needs attention, an excluded one.").fontSmall().foregroundStyle(.secondary)
                        ForEach(leftovers) { n in
                            HStack {
                                Text(n.title).font(.callout).lineLimit(1)
                                if let st = n.status { Text(st.rawValue).fontSmall().foregroundStyle(st.color) }
                                Spacer()
                                if let a = n.assetID { Button("Unlink") { project.unlink(a, from: id) }.buttonStyle(.borderless) }
                            }
                        }
                    }
                }
                if let c = project.checks["scene"]?.first(where: { $0.id == "content.\(id)" }) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: c.level.symbol).foregroundStyle(c.level.color)
                        Text(c.detail).fontSmall().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                SceneForm(id: id, tab: .composition)
            }
        }
    }
}

struct FixedBadge: View {
    let fixed: Bool
    var body: some View {
        Text(fixed ? "fixed" : "auto").fontSmall(weight: .semibold).padding(.horizontal, 6).padding(.vertical, 1)
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
    @EnvironmentObject var theme: Theme
    @State private var inText = ""
    @State private var outText = ""
    @State private var timingMessage: String?
    @State private var words = ""
    @State private var params = ""
    @State private var instruction = ""
    @State private var hex = "#FFFFFF"
    @State private var editingWords = false

    private var open: Binding<Bool> {
        Binding(get: { project.contentItem == item.id }, set: { project.contentItem = $0 ? item.id : nil })
    }
    private var dirty: Bool { words != (item.text ?? "") || params != item.animation.paramsText || instruction != (item.instruction ?? "") }

    private var colorChoice: String { item.color.mode == "role" ? (item.color.role ?? "text") : item.color.mode == "custom" ? "custom" : "auto" }

    var body: some View {
        DisclosureGroup(isExpanded: open) {
            VStack(alignment: .leading, spacing: 8) {
                subject
                if item.type == "text" { colour }
                if item.type != "audio" { animation }
                timing
                VStack(alignment: .leading, spacing: 2) {
                    Text("Instruction for the AI (optional)").fontSmall(weight: .semibold).foregroundStyle(.secondary)
                    TextField("In your words", text: $instruction, axis: .vertical).lineLimit(1...3).textFieldStyle(ThemedTextFieldStyle())
                }
                HStack {
                    Spacer()
                    Button("Remove", role: .destructive) { project.removeItem(scene, item.id) }
                }
            }
            .padding(.top, 6)
            .autoCommit([words, params, instruction], dirty: dirty, undoKey: "item:\(scene):\(item.id)") { apply() }
        } label: {
            HStack(spacing: 6) {
                Handle()
                Text("\(priority)").fontSmall(weight: .bold, digits: true).frame(width: 18).help("Processing priority")
                Image(systemName: icon).foregroundStyle(.secondary)
                if item.type == "text" {
                    // the words are edited where they stand (double-click); the rest of the item opens below
                    InlineEdit(text: item.text ?? "", placeholder: "Your words", editing: $editingWords, commit: { project.updateItem(scene, item.id, ContentEdit(text: $0)) }) {
                        Text(label).lineLimit(1).font(.callout).onTapGesture(count: 2) { editingWords = true }
                    }
                } else { Text(label).lineLimit(1).font(.callout) }
                Spacer(minLength: 4)
                if item.color.isFixed { FixedBadge(fixed: true).help("Colour fixed") }
                if item.animation.isFixed { Image(systemName: "sparkles").fontSmall().foregroundStyle(Color.accentColor).help("Animation fixed: \(item.animation.text)") }
                if item.timing.isFixed { Image(systemName: "clock").fontSmall().foregroundStyle(Color.accentColor).help("Timing fixed: \(item.timing.text)") }
                BlockMarker(ref: .item(scene: scene, item: item.id))
            }
            .flashWhenChanged(.item(scene: scene, item: item.id))
            .contentShape(Rectangle())
            .dragSource(.content(scene: scene, item: item.id), label: label, icon: icon)
        }
        .contextMenu {
            Button("Duplicate") { project.duplicateItem(scene, item.id) }
            Button(priority == 1 ? "Move to the top (it already is first)" : "Move to the top") { project.moveItem(scene, item.id, by: -count) }.disabled(priority == 1)
            Button(priority == count ? "Move to the bottom (it already is last)" : "Move to the bottom") { project.moveItem(scene, item.id, by: count) }.disabled(priority == count)
            Divider()
            Button("Remove", role: .destructive) { project.removeItem(scene, item.id) }
        }
        .onAppear { load() }
        .onChange(of: item) { _ in load() }
    }

    private var icon: String { item.type == "text" ? "textformat" : item.type == "image" ? "photo" : "waveform" }

    private var label: String {
        if item.type == "text" { return (item.text ?? "").isEmpty ? "(no words)" : item.text! }
        return project.assets.first { $0.id == item.resource }?.name ?? item.resource ?? "(no resource)"
    }

    private func load() {
        words = item.text ?? ""; params = item.animation.paramsText; instruction = item.instruction ?? ""; hex = item.color.hex ?? "#FFFFFF"
        inText = timingRule.display(item.timeIn ?? 0); outText = timingRule.display(item.timeOut ?? sceneDuration ?? timingRule.maximum)
    }

    private var sceneDuration: Double? { project.showreel?.scenes.first { $0.id == scene }?.duration }
    private var timingRule: NumericField { NumericField(minimum: 0, maximum: sceneDuration ?? 600) }
    private var timingDirty: Bool { item.timing.isFixed && (inText != timingRule.display(item.timeIn ?? 0) || outText != timingRule.display(item.timeOut ?? sceneDuration ?? timingRule.maximum)) }

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
                Text("Words").fontSmall(weight: .semibold).foregroundStyle(.secondary)
                TextField("", text: $words, axis: .vertical).lineLimit(1...4).textFieldStyle(ThemedTextFieldStyle())
            }
        } else {
            let fit = project.assets.filter { ContentRules.accepts(item.type, asset: $0.type) && $0.status != "excluded" }
            VStack(alignment: .leading, spacing: 2) {
                Text("Resource").fontSmall(weight: .semibold).foregroundStyle(.secondary)
                Picker("", selection: Binding(get: { item.resource ?? "" }, set: { project.updateItem(scene, item.id, ContentEdit(resource: $0)) })) {
                    ForEach(fit) { Text("\($0.name) (\(project.assetStatus[$0.id]?.rawValue ?? $0.status))").tag($0.id) }
                }.labelsHidden()
            }
        }
    }

    private var colour: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text("Colour").fontSmall(weight: .semibold).foregroundStyle(.secondary); FixedBadge(fixed: item.color.isFixed) }
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
                    Text(item.color.hex ?? "").fontSmall(mono: true).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// When the item is on screen, in seconds from the start of the scene: auto (the AI decides) or fixed. A value outside the scene is refused with its reason, and nothing is written.
    private var timing: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text("Timing in the scene").fontSmall(weight: .semibold).foregroundStyle(.secondary); FixedBadge(fixed: item.timing.isFixed) }
            Picker("", selection: Binding(get: { item.timing.isFixed }, set: { setTimingFixed($0) })) {
                Text("Auto (the AI decides)").tag(false)
                Text("Fixed").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden()
            .disabledWithReason(sceneDuration == nil && !item.timing.isFixed ? "The scene has no duration yet" : nil, way: "Set the scene's duration, then fix the timing")
            if item.timing.isFixed {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("In (s)").fontSmall().foregroundStyle(.secondary)
                        StepperField(text: $inText, rule: timingRule, onCommit: { applyTiming() }, width: 100)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Out (s)").fontSmall().foregroundStyle(.secondary)
                        StepperField(text: $outText, rule: timingRule, onCommit: { applyTiming() }, width: 100)
                    }
                }
                Text("Seconds from the start of the scene" + (sceneDuration.map { " (\(ProjectDocs.seconds($0)) s long)" } ?? "") + ". The item is on screen from In up to Out.").fontSmall().foregroundStyle(.secondary)
            }
            if let why = timingMessage { Text(why).fontSmall().foregroundStyle(theme.warning) }
        }
        .autoCommit([inText, outText], dirty: timingDirty, undoKey: "item:\(scene):\(item.id):times") { applyTiming() }
        .accessibilityElement(children: .contain)
    }

    private func setTimingFixed(_ fixed: Bool) {
        timingMessage = nil
        // fixing starts from "there all along" (the start to the end of the scene); going back to auto clears both bounds
        project.updateItem(scene, item.id, ContentEdit(times: fixed ? ContentTimes(start: 0, end: sceneDuration) : ContentTimes()))
    }

    private func applyTiming() {
        guard item.timing.isFixed else { return }
        guard let a = timingRule.typed(inText).result?.value, let b = timingRule.typed(outText).result?.value else { timingMessage = "In and Out are numbers of seconds, such as 1 or 2.5."; return }
        let t = ContentTimes(start: a, end: b)
        if let why = ContentTiming.validate(t, duration: sceneDuration) { timingMessage = why; return }          // refused with its reason: nothing is written
        timingMessage = nil
        if t != item.timing { project.updateItem(scene, item.id, ContentEdit(times: t)) }
    }

    private var animation: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text("Animation").fontSmall(weight: .semibold).foregroundStyle(.secondary); FixedBadge(fixed: item.animation.isFixed) }
            PickerButton(kind: .effect, current: item.animation.mode == "effect" ? (item.animation.effect ?? "auto") : "auto", none: ("auto", "Auto (the AI decides)")) {
                project.choose(.effect, $0, for: .item(scene: scene, item: item.id))
            }
            .help("An animation you pick is fixed; auto leaves it to the AI, from the project's effects pack.")
            if item.animation.mode == "effect" {
                TextField("Parameters (key=value, key=value)", text: $params).textFieldStyle(ThemedTextFieldStyle()).fontSmall().onSubmit { apply() }
            }
        }
    }
}
