import AppKit
import ShowreelKit
import SwiftUI

// MARK: the centre: the viewer

struct CenterPane: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            if project.centerMode == .build {
                HStack {
                    Label("Build and preview", systemImage: "play.rectangle").font(.headline)
                    Spacer()
                    Button("Back to the viewer") { project.centerMode = .viewer }
                }
                .padding(.horizontal, 12).padding(.vertical, 6).background(.bar)
                Divider()
                BuildBlockView()
            } else {
                switch project.selection {
                case .file(let p):
                    if let t = project.tab(p) { EditorView(tab: t) } else { ViewerPane() }
                case .preview: PreviewPane()
                default: ViewerPane()
                }
            }
        }
    }
}

/// W1: the thumbnail of the selected scene or element, drawn by the engine. No playback and no timeline yet.
struct ViewerPane: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder private var content: some View {
        let f = project.showreel
        switch project.selection {
        case .sceneNode(_, .raw, let item?) where item.hasPrefix("raw.") && project.assets.contains(where: { $0.id == String(item.dropFirst(4)) }):
            assetView(project.assets.first { $0.id == String(item.dropFirst(4)) }!)
        case .sceneNode(let sid, _, let item?) where item.hasPrefix("item.") && itemAsset(sid, String(item.dropFirst(5))) != nil:
            assetView(itemAsset(sid, String(item.dropFirst(5)))!)
        case .scene(let id), .sceneNode(let id, _, _):
            if let s = f?.scenes.first(where: { $0.id == id }) {
                SceneThumb(scene: s, size: EngineService.viewerSize).frame(maxWidth: 760).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                caption("\(s.id) · \(s.durationLabel)", s.text.isEmpty ? "A stand-in drawn with the project's look: the scene gets its own layers in a later phase." : s.text)
            }
        case .asset(let id):
            if let a = project.assets.first(where: { $0.id == id }) { assetView(a) }
        case .look(let kind, let id):
            LookViewer(kind: kind, id: id)
        case .transition(let id):
            if let pair = f?.transition(after: id), !pair.item.isCut { LookViewer(kind: .transitions, id: pair.item.type) }
            else { caption("Cut on beat", "The default: a hard cut on the beat, no overlap.") }
        default:
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle").font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                Text("Select a scene, a resource or a look element").font(.headline)
                Text("The viewer draws it here with the film's engine. The inspector on the right shows its properties; with nothing selected it holds the project and the global look.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
            }
        }
    }

    private func itemAsset(_ scene: String, _ item: String) -> AssetRow? {
        let r = project.showreel?.scenes.first { $0.id == scene }?.content.first { $0.id == item }?.resource
        return project.assets.first { $0.id == r }
    }

    @ViewBuilder private func assetView(_ a: AssetRow) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06))
            if let img = AssetFiles.thumbnail(a, in: project.root) { Image(nsImage: img).resizable().scaledToFit().padding(16) }
            else { Image(systemName: a.symbolName).font(.system(size: 60, weight: .light)).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: 760, maxHeight: 428).aspectRatio(16 / 9, contentMode: .fit)
        caption(a.name, "\(a.id) · \(a.type) · \(project.assetStatus[a.id]?.rawValue ?? a.status)")
    }

    private func caption(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.center)
        }
    }
}

/// What a look element looks like, drawn with the project's palette and fonts.
struct LookViewer: View {
    let kind: LookKind
    let id: String
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared

    var body: some View {
        let ctx = LookContext(project)
        let size = EngineService.viewerSize
        VStack(spacing: 10) {
            frames(ctx, size).frame(maxWidth: 760).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title).font(.headline)
            if !subtitle.isEmpty { Text(subtitle).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(3) }
        }
    }

    private var title: String { LookElement.title(kind, id, project: project) }
    private var subtitle: String { LookElement.subtitle(kind, id, project: project) }

    @ViewBuilder private func frames(_ ctx: LookContext, _ size: CGSize) -> some View {
        let d = project.showreel?.decisions
        switch kind {
        case .looks:
            if let p = LookPackages.all().first(where: { $0.id == id }) {
                let effect = Look.packs().first { $0.name == p.pack }?.effects.first { n in engine.catalogue?.effects.contains { $0.name == n } ?? true } ?? "Fade"
                EngineThumb(token: "v" + p.id + ctx.text) {
                    await engine.lookFrames(background: p.background, mood: Look.mood(forPack: p.pack), effect: effect, palette: EnginePalette(stored: p.palette), font: p.fonts.titles ?? "", store: project.store, text: ctx.text, size: size)
                }
            }
        case .palettes:
            let colours = id == "project" ? (d?.palette ?? []) : (LookPackages.all().first { $0.id == id }?.palette ?? [])
            EngineThumb(token: "vp" + colours.joined()) { await engine.effectFrames("Pop", palette: EnginePalette(stored: colours.isEmpty ? nil : colours), font: ctx.titleFont, store: project.store, text: ctx.text, size: size) }
        case .fonts:
            let family = LookElement.fontFamily(id, project: project)
            EngineThumb(token: "vf" + family + ctx.palette.signature) { await engine.effectFrames("Pop", palette: ctx.palette, font: family, store: project.store, text: ctx.text, size: size) }
        case .backgrounds:
            EngineThumb(token: "vb" + id + ctx.palette.signature + (d?.background?.mood ?? "")) { await engine.backgroundFrames(id, mood: d?.background?.mood, palette: ctx.palette, store: project.store, size: size) }
        case .effects:
            let name = id.hasPrefix("pack:") ? (Look.packs().first { $0.name == String(id.dropFirst(5)) }?.effects.first { n in engine.catalogue?.effects.contains { $0.name == n } ?? true } ?? "Fade") : id
            EngineThumb(token: "ve" + name + ctx.palette.signature + ctx.titleFont) { await engine.effectFrames(name, palette: ctx.palette, font: ctx.titleFont, store: project.store, text: ctx.text, size: size) }
        case .transitions:
            EngineThumb(token: "vt" + id + ctx.palette.signature) { await engine.effectFrames(id, palette: ctx.palette, font: ctx.titleFont, store: project.store, text: ctx.text, size: size) }
        }
    }
}

/// Names and facts of the library's look elements, for the viewer and the inspector.
@MainActor
enum LookElement {
    static func fontFamily(_ id: String, project: ProjectModel) -> String {
        if id.hasPrefix("asset:"), let a = project.assets.first(where: { $0.id == String(id.dropFirst(6)) }) { return AssetFonts.family(a, in: project.root) }
        return id
    }

    static func title(_ kind: LookKind, _ id: String, project: ProjectModel) -> String {
        switch kind {
        case .looks: return LookPackages.all().first { $0.id == id }?.name ?? id
        case .palettes: return id == "project" ? "Project palette" : (LookPackages.all().first { $0.id == id }?.name ?? id) + " palette"
        case .fonts: return fontFamily(id, project: project)
        case .effects: return id.hasPrefix("pack:") ? String(id.dropFirst(5)) + " (effects pack)" : id
        default: return id.isEmpty ? "" : (EngineService.shared.catalogue?.backgrounds.first { $0.id == id }?.name ?? id)
        }
    }

    static func subtitle(_ kind: LookKind, _ id: String, project: ProjectModel) -> String {
        let cat = EngineService.shared.catalogue
        switch kind {
        case .looks: return LookPackages.all().first { $0.id == id }?.why ?? ""
        case .palettes: return "Background, text, accent, accent 2"
        case .fonts: return Look.freeFonts().first { $0.name == id }?.note ?? ""
        case .backgrounds: return cat?.backgrounds.first { $0.id == id }?.desc ?? ""
        case .effects:
            if id.hasPrefix("pack:") { return Look.packs().first { $0.name == String(id.dropFirst(5)) }?.feel ?? "" }
            return cat?.effects.first { $0.name == id }?.desc ?? ""
        case .transitions: return cat?.effects.first { $0.name == id }?.desc ?? ""
        }
    }
}

// MARK: the right side: inspector, copilot, files

struct InspectorPane: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $project.inspectorTab) {
                ForEach(InspectorTab.allCases.filter { $0 != .files || settings.advanced }) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(10)
            Divider()
            switch project.inspectorTab {
            case .inspector: InspectorContent()
            case .copilot: ChatView()
            case .files: FilesInspector()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: settings.advanced) { on in
            if !on { if project.inspectorTab == .files { project.inspectorTab = .inspector }; if case .file = project.selection { project.selection = .none } }
        }
    }
}

/// What the inspector shows for the selection. Nothing selected: the project and the global look.
struct InspectorContent: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if project.showreel == nil {
                    Text("This project has no data yet. Confirm the import or create it with the banner above.").foregroundStyle(.secondary)
                } else {
                    switch project.selection {
                    case .scene(let id), .sceneNode(let id, _, _): SceneInspector(id: id).id(id)
                    case .transition(let id): TransitionInspector(from: id).id(id)
                    case .asset(let id): AssetInspector(id: id).id(id)
                    case .look(let kind, let id): LookInspector(kind: kind, id: id).id(kind.rawValue + id)
                    default: ProjectInspector()
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct InspectorHeader: View {
    let title: String
    var subtitle: String = ""
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold)).lineLimit(2)
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Button { project.selection = .none } label: { Label("Project", systemImage: "slider.horizontal.3") }
                .buttonStyle(.borderless).help("Back to the project parameters and the global look")
        }
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: nothing selected

struct ProjectInspector: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Project").font(.title3.weight(.semibold))
                Spacer()
                ValidateButton(gate: "interview", block: "inspector")
            }
            ProjectForm()
            InspectorSection(title: "Music") { MusicInspector() }
            InspectorSection(title: "Global look") { GlobalLook() }
            InspectorSection(title: "Checks") { ChecksList(areas: ["project", "look"]) }
        }
    }
}

/// The global look: palette, fonts, background and motion, with the way to the library's elements.
struct GlobalLook: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let d = project.showreel?.decisions
        VStack(alignment: .leading, spacing: 12) {
            PaletteEditor(compact: true)
            Divider()
            ForEach([DecisionKey.titleFont, .textFont], id: \.self) { k in
                let name = project.showreel.map { k.current($0) } ?? ""
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text(k.title).font(.callout.weight(.medium)); Spacer(); Button(name.isEmpty ? "Choose..." : "Change...") { browse(.fonts) }.buttonStyle(.borderless) }
                    Text(name.isEmpty ? "not chosen yet" : name).font(.callout).foregroundStyle(name.isEmpty ? .secondary : .primary)
                    if !name.isEmpty { LicenceBadge(assessment: FontLicense.assess(name: name, assets: project.assets, store: project.store)) }
                }
            }
            Divider()
            summary("Background", [d?.background?.id, d?.background?.mood.flatMap { $0.isEmpty ? nil : "reacts like \($0)" }].compactMap { $0 }.joined(separator: ", "), .backgrounds)
            summary("Motion moods", (d?.moods ?? []).joined(separator: ", "), .effects)
            summary("Effects pack", d?.effectsPack ?? "", .effects)
            Button { browse(.looks) } label: { Label("Pick a complete look...", systemImage: "wand.and.stars") }
            ValidateButton(gate: "style", block: "inspector")
        }
    }

    private func summary(_ title: String, _ value: String, _ kind: LookKind) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(title).font(.callout.weight(.medium)); Spacer(); Button(value.isEmpty ? "Choose..." : "Change...") { browse(kind) }.buttonStyle(.borderless) }
            Text(value.isEmpty ? "not chosen yet" : value).font(.callout).foregroundStyle(value.isEmpty ? .secondary : .primary)
        }
    }

    private func browse(_ kind: LookKind) { project.libraryTab = .look; project.lookKind = kind }
}

struct ChecksList: View {
    let areas: [String]
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let all = areas.flatMap { project.checks[$0] ?? [] }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(all) { r in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: r.level.symbol).foregroundStyle(r.level.color).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.title).font(.callout.weight(.medium))
                        Text(r.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if all.isEmpty { Text("Nothing to check yet.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

// MARK: a scene

struct SceneInspector: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private var on: Bool { project.showreel?.film.contains { $0.id == id } ?? false }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 14) {
                InspectorHeader(title: "Scene \(s.id)", subtitle: s.archived ? "Archived" : "\(s.durationLabel) · \(s.status)")
                if s.archived {
                    InspectorSection(title: "Archived") {
                        Text("This scene left the lists. Its ID stays reserved.").font(.callout).foregroundStyle(.secondary)
                        Button("Bring it back") { project.restoreScene(id) }
                    }
                } else {
                    Picker("", selection: $project.sceneTab) { ForEach(SceneTab.allCases) { Text($0.title).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden()
                    switch project.sceneTab {
                    case .settings:
                        Toggle("In the film", isOn: Binding(get: { on }, set: { project.setEnabled(id, $0) })).toggleStyle(.switch)
                        SceneForm(id: id, tab: .settings)
                        InspectorSection(title: "Review") { SceneDecision(id: id) }
                        HStack {
                            Button("Duplicate") { project.addScene(copying: id) }
                            Button("Archive", role: .destructive) { project.archiveScene(id) }
                                .help("Takes the scene out of the lists. Its ID is never reused.")
                        }
                    case .content:
                        SceneContentTab(id: id)
                    case .effects:
                        InspectorSection(title: "Effects of the whole scene") {
                            Text("Scene-wide effects (background effects, whole-scene moves) live here; none yet. An item's own animation is set on the item, in the Content tab. The project's effects pack applies.")
                                .font(.callout).foregroundStyle(.secondary)
                            if let p = project.showreel?.decisions.effectsPack, !p.isEmpty { Label("Project pack: \(p)", systemImage: "sparkles").font(.callout) }
                        }
                        InspectorSection(title: "Used by the items") {
                            let used = project.trees[id]?.first { $0.group == .effects }?.nodes ?? []
                            if used.isEmpty { Text("No item names an effect: the AI decides.").font(.callout).foregroundStyle(.secondary) }
                            ForEach(used) { n in HStack { Text(n.title).font(.callout.weight(.medium)); Text(n.detail).font(.caption).foregroundStyle(.secondary) } }
                        }
                    case .resources:
                        SceneForm(id: id, tab: .resources)
                    case .look:
                        SceneLookTab(id: id)
                    }
                }
            }
        }
    }
}

/// Background and look of one scene: inherited from the project, or overridden here, with the way back.
struct SceneLookTab: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var palette: [String] = []
    private let fonts = Look.freeFonts().map { $0.name }

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private func eff(_ k: DecisionKey) -> String { scene.flatMap { project.showreel?.effective(k, for: $0) } ?? "" }
    private func over(_ k: DecisionKey) -> Bool { scene.flatMap { project.showreel?.isOverridden(k, for: $0) } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorSection(title: "Background") {
                mark(over(.background) || over(.backgroundMood), project: (project.showreel?.decisions.background?.id).map { $0 + ((project.showreel?.decisions.background?.mood).map { m in m.isEmpty ? "" : " (\(m))" } ?? "") })
                Picker("Background", selection: Binding(get: { eff(.background) }, set: { project.setSceneLook(id, [DecisionChange(.background, $0)]) })) {
                    Text(eff(.background).isEmpty ? "(none)" : "Project's").tag(over(.background) ? "" : eff(.background))
                    ForEach(Look.backgroundIDs(), id: \.self) { Text($0).tag($0) }
                }
                Picker("Reacts to music like", selection: Binding(get: { eff(.backgroundMood) }, set: { project.setSceneLook(id, [DecisionChange(.backgroundMood, $0)]) })) {
                    Text("Calm / project's").tag(over(.backgroundMood) ? "" : eff(.backgroundMood))
                    ForEach(Look.backgroundMoods(), id: \.self) { Text($0.capitalized).tag($0) }
                }
                if over(.background) || over(.backgroundMood) {
                    Button("Revert to project") { project.setSceneLook(id, [DecisionChange(.background, ""), DecisionChange(.backgroundMood, "")]) }
                }
            }
            InspectorSection(title: "Palette") {
                mark(over(.palette), project: (project.showreel?.decisions.palette).map { $0.joined(separator: ", ") })
                ForEach(palette.indices, id: \.self) { i in
                    HStack {
                        Text(["Background", "Text", "Accent", "Accent 2"][min(i, 3)]).frame(width: 90, alignment: .leading)
                        ColorPicker("", selection: Binding(get: { Color(hex: palette[i]) }, set: { palette[i] = $0.hexString }), supportsOpacity: false).labelsHidden()
                        Text(palette[i]).font(.callout.monospaced()).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Override the palette") { project.setSceneLook(id, [DecisionChange(.palette, palette.joined(separator: ", "))]) }
                        .disabled(palette.count < 2 || palette.map { $0.uppercased() } == eff(.palette).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).uppercased() })
                    if over(.palette) { Button("Revert to project") { project.setSceneLook(id, [DecisionChange(.palette, "")]) } }
                }
            }
            InspectorSection(title: "Fonts") {
                mark(over(.titleFont) || over(.textFont), project: [project.showreel?.decisions.fonts?.titles, project.showreel?.decisions.fonts?.text].compactMap { $0 }.joined(separator: " / "))
                fontPicker("Titles", .titleFont)
                fontPicker("Text", .textFont)
                if over(.titleFont) || over(.textFont) {
                    Button("Revert to project") { project.setSceneLook(id, [DecisionChange(.titleFont, ""), DecisionChange(.textFont, "")]) }
                }
            }
        }
        .onAppear { loadPalette() }
        .onChange(of: project.showreel) { _ in loadPalette() }
    }

    private func loadPalette() {
        let p = eff(.palette).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        palette = p.count >= 2 ? p : ["#101820", "#FFFFFF", "#F2AA4C"]
    }

    private func fontPicker(_ title: String, _ k: DecisionKey) -> some View {
        Picker(title, selection: Binding(get: { eff(k) }, set: { project.setSceneLook(id, [DecisionChange(k, $0)]) })) {
            Text(eff(k).isEmpty ? "(none)" : "Project's").tag(over(k) ? "" : eff(k))
            ForEach(fonts, id: \.self) { Text($0).tag($0) }
        }
    }

    @ViewBuilder private func mark(_ overridden: Bool, project value: String?) -> some View {
        if overridden {
            HStack { Text("overridden").font(.caption.weight(.semibold)).foregroundStyle(.orange); Text("project: \(value?.isEmpty == false ? value! : "(none)")").font(.caption).foregroundStyle(.secondary) }
        } else {
            HStack { Text("inherited").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text(value?.isEmpty == false ? value! : "project value not chosen yet").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

// MARK: a resource

struct AssetInspector: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var holding: AssetRow?
    @State private var holdNote = ""

    var body: some View {
        if let row = project.assets.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 14) {
                InspectorHeader(title: row.name, subtitle: "\(row.id) · \(row.type)")
                AssetCard(row: row, onHold: { holding = row; holdNote = row.notes })
                Text("Nothing is used in the film until you approve it.").font(.caption).foregroundStyle(.secondary)
            }
            .sheet(item: $holding) { r in
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hold \(r.name)").font(.headline)
                    Text("A held file is not used until you decide. Say why, so you and the copilot remember.").font(.callout).foregroundStyle(.secondary)
                    TextField("Why is it on hold?", text: $holdNote, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Cancel") { holding = nil }.keyboardShortcut(.cancelAction)
                        Button("Hold") { project.perform(.asset(id: r.id, status: .hold, note: holdNote, licence: nil, scenes: nil)); holding = nil }
                            .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                            .disabled(holdNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(18).frame(width: 420)
            }
        } else {
            Text("This resource is not in the project any more.").foregroundStyle(.secondary)
        }
    }
}

// MARK: a look element

struct LookInspector: View {
    let kind: LookKind
    let id: String
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var mood = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorHeader(title: LookElement.title(kind, id, project: project), subtitle: kind.title)
            let sub = LookElement.subtitle(kind, id, project: project)
            if !sub.isEmpty { Text(sub).font(.callout).foregroundStyle(.secondary) }
            actions
        }
    }

    @ViewBuilder private var actions: some View {
        let d = project.showreel?.decisions
        switch kind {
        case .looks:
            if let p = LookPackages.all().first(where: { $0.id == id }) {
                let chosen = d?.palette == p.palette.map { $0.uppercased() } && d?.background?.id == p.background && d?.fonts?.titles == p.fonts.titles && d?.effectsPack == p.pack
                Swatches(colours: p.palette)
                Text("\(p.fonts.titles ?? "") + \(p.fonts.text ?? "") · \(p.pack) · \(p.background)").font(.caption).foregroundStyle(.secondary)
                Text("Starting points, not defaults: nothing changes until you click. After choosing, each part can still be changed.").font(.caption).foregroundStyle(.secondary)
                if chosen { Label("Chosen", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                else { Button("Choose this look") { project.perform(.decisions(p.decisions, title: "Choose the look: \(p.name)")) }.buttonStyle(.borderedProminent) }
            }
        case .palettes:
            if id == "project" {
                PaletteEditor(compact: true)
            } else if let p = LookPackages.all().first(where: { $0.id == id }) {
                let upper = p.palette.map { $0.uppercased() }
                Swatches(colours: p.palette)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Contrast.checks(p.palette)) { r in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: r.level.symbol).foregroundStyle(r.level.color)
                            VStack(alignment: .leading, spacing: 0) { Text(r.title).font(.callout.weight(.medium)); Text(r.detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                if d?.palette == upper { Label("This is the project palette", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                else { Button("Use as the project palette") { project.perform(.decisions([DecisionChange(.palette, p.palette.joined(separator: ", "))], title: "Use the \(p.name) palette")) }.buttonStyle(.borderedProminent) }
            }
        case .fonts:
            let family = LookElement.fontFamily(id, project: project)
            LicenceBadge(assessment: FontLicense.assess(name: family, assets: project.assets, store: project.store))
            HStack {
                ForEach([DecisionKey.titleFont, .textFont], id: \.self) { role in
                    let on = project.showreel.map { role.current($0) == family } ?? false
                    Button(on ? "\(role == .titleFont ? "Titles" : "Text"): chosen" : "Use for \(role == .titleFont ? "titles" : "text")") {
                        project.perform(.decisions([DecisionChange(role, family)], title: nil))
                    }
                    .buttonStyle(.bordered).tint(on ? .green : nil).disabled(on)
                }
            }
            if !id.hasPrefix("asset:") { Text("The free fonts here are previews to choose from. A film embeds only the font files you add as approved resources.").font(.caption).foregroundStyle(.secondary) }
        case .backgrounds:
            let chosen = d?.background?.id == id
            Picker("Reacts to music like", selection: $mood) {
                Text("Calm (no reaction)").tag("")
                ForEach(Look.backgroundMoods(), id: \.self) { Text($0.capitalized).tag($0) }
            }
            Text("The mood only changes how animated backgrounds breathe with a track. It is saved with the background.").font(.caption).foregroundStyle(.secondary)
            Button(chosen && (d?.background?.mood ?? "") == mood ? "Chosen" : "Use this background") {
                let name = engine.catalogue?.backgrounds.first { $0.id == id }?.name ?? id
                project.perform(.decisions([DecisionChange(.background, id), DecisionChange(.backgroundMood, mood)], title: "Set background: \(name)"))
            }
            .buttonStyle(.borderedProminent).disabled(chosen && (d?.background?.mood ?? "") == mood)
            .onAppear { mood = d?.background?.mood ?? "" }
        case .effects:
            if id.hasPrefix("pack:") {
                let name = String(id.dropFirst(5))
                let pack = Look.packs().first { $0.name == name }
                Text((pack?.effects ?? []).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    let isMood = (d?.moods ?? []).contains(name)
                    Button(isMood ? "Mood: chosen" : "Use as my mood") { project.perform(.decisions([DecisionChange(.moods, name)], title: nil)) }.disabled(isMood)
                    let isPack = d?.effectsPack == name
                    Button(isPack ? "Effects pack: chosen" : "Use as the effects pack") { project.perform(.decisions([DecisionChange(.effectsPack, name)], title: nil)) }
                        .buttonStyle(.borderedProminent).disabled(isPack)
                }
            } else if let e = engine.catalogue?.effects.first(where: { $0.name == id }) {
                Text("\(e.cat) · energy \(e.energy) · \(String(format: "%.1f", e.dur)) s").font(.caption).foregroundStyle(.secondary)
                Text("An effect is used through an effects pack today; picking single effects per scene comes with layers.").font(.caption).foregroundStyle(.secondary)
            }
        case .transitions:
            if let e = engine.catalogue?.effects.first(where: { $0.name == id }) {
                Text("energy \(e.energy) · \(String(format: "%.1f", e.dur)) s").font(.caption).foregroundStyle(.secondary)
            }
            Text("A transition sits between two scenes of the storyboard. Choosing one per passage comes with the film reel (next phase).").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: files (Advanced)

struct FilesInspector: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        List {
            OutlineGroup(project.tree, children: \.children) { node in
                Label(node.name, systemImage: icon(node)).lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture { if !node.isDir { project.open(node.id) } }
                    .contextMenu {
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.root.appendingPathComponent(node.id)]) }
                        if !node.isDir { Button("Open with the system viewer") { NSWorkspace.shared.open(project.root.appendingPathComponent(node.id)) } }
                    }
            }
        }
        .listStyle(.sidebar)
    }

    private func icon(_ n: FileNode) -> String {
        if n.isDir { return "folder" }
        switch ProjectTree.kind(of: n.id) {
        case .markdown: return "doc.richtext"
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .text: return "doc.text"
        case .binary: return "photo.on.rectangle"
        }
    }
}
