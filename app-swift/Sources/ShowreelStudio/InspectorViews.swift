import AppKit
import ShowreelKit
import SwiftUI

// MARK: the centre: the viewer

struct CenterPane: View {
    @EnvironmentObject var project: ProjectModel
    private var selectedResource: String? { if case .asset(let id) = project.selection { return id }; return nil }

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
                // what the centre shows, by one rule (ShowreelKit): the design system while the look is edited, else the resource selected in the Resources tab, else the film
                switch Resources.viewerSubject(designBoardOpen: project.showProjectSettings && project.settingsTab == .look, resourcesTab: project.libraryTab == .resources, selectedResource: selectedResource) {
                case .designBoard: DesignBoardView()
                case .resource(let id): ResourcePreview(id: id)
                case .film:
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
}

/// W1: the thumbnail of the selected scene or element, drawn by the engine. No playback and no timeline yet.
struct ViewerPane: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared

    var body: some View {
        VStack(spacing: 12) {
            FilmBanners()
            if let v = project.viewerFilmVersion, !project.viewerShowsDraft {
                FilmViewer(version: v, player: project.player)
            } else {
                Spacer(minLength: 0)
                if let fv = project.viewerFilmVersion { Button("Show the built film (\(fv))") { project.viewerShowsDraft = false }.buttonStyle(.borderless).font(.caption) }
                switch project.selection { case .scene, .sceneNode, .none: PreviewTag(); default: EmptyView() }
                content
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder private var content: some View {
        let f = project.showreel
        switch project.selection {
        case .sceneNode(let sid, _, let n) where project.nodeAsset(sid, n) != nil:
            assetView(project.nodeAsset(sid, n)!)
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
            TransitionPreview(from: id)
        case .none where project.sceneUnderPlayhead != nil:
            // nothing selected and nothing built: the viewer follows the playhead of the strip and shows the scene under it
            let s = project.sceneUnderPlayhead!
            SceneThumb(scene: s, size: EngineService.viewerSize).frame(maxWidth: 760).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            caption("\(s.label) \u{00B7} \(TimelineNav.timecode(project.playhead))", s.text.isEmpty ? "The scene under the playhead of the strip." : s.text)
        default:
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle").font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                Text("Select a scene, a resource or a look element").font(.headline)
                Text("The viewer draws it here with the film's engine. The inspector on the right shows its properties; with nothing selected it holds the project and the global look.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
            }
        }
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
            ProposalsBanner()
            Picker("", selection: $project.inspectorTab) {
                ForEach(InspectorTab.allCases.filter { $0 != .files || settings.advanced }) { tab in
                    if tab == .copilot { Label(tab.title, systemImage: ClapMark.symbol).tag(tab) } else { Text(tab.title).tag(tab) }
                }
            }
            .pickerStyle(.segmented).labelsHidden().padding(10)
            Divider()
            switch project.inspectorTab {
            case .inspector: InspectorContent()
            case .copilot: AskClapPane()
            case .files: FilesInspector()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: settings.advanced) { on in
            if !on { if project.inspectorTab == .files { project.inspectorTab = .inspector }; if case .file = project.selection { project.selection = .none } }
        }
    }
}

/// The Ask Clap tab: a selector on top (conversation, memory, sessions, journal) and the part chosen below.
struct AskClapPane: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $project.clapSection) { ForEach(ClapSection.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 10).padding(.bottom, 8)
            Divider()
            if project.clapSection == .conversation { ChatView() } else { ClapHistoryPane(section: project.clapSection) }
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
                Text(project.title).font(.title3.weight(.semibold)).lineLimit(2)
                Spacer()
                Button { project.openSettings() } label: { Label("Project settings", systemImage: "slider.horizontal.3") }
                    .help("The project's parameters and its global look, in one panel")
            }
            Text("Select a scene, a resource or a transition marker to see its properties here.").font(.callout).foregroundStyle(.secondary)
            InspectorSection(title: "Music") { MusicInspector() }.readOnlyWhenBlocked(.setting("music"))
            InspectorSection(title: "Global look") { GlobalLook() }.readOnlyWhenBlocked(.setting("look"))
        }
    }
}

/// What the global look is now. Each part is changed in the project settings, the one place that edits it.
struct GlobalLook: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let d = project.showreel?.decisions
        VStack(alignment: .leading, spacing: 10) {
            row("Palette", .palette) { if let p = d?.palette, !p.isEmpty { Swatches(colours: p) } else { Text("not chosen yet").font(.callout).foregroundStyle(.secondary) } }
            ForEach([DecisionKey.titleFont, .textFont], id: \.self) { k in
                let name = project.showreel.map { k.current($0) } ?? ""
                row(k.title, .fonts) {
                    Text(name.isEmpty ? "not chosen yet" : name).font(.callout).foregroundStyle(name.isEmpty ? .secondary : .primary)
                    if !name.isEmpty { LicenceBadge(assessment: FontLicense.assess(name: name, assets: project.assets, store: project.store)) }
                }
            }
            summary("Background", [d?.background?.id, d?.background?.mood.flatMap { $0.isEmpty ? nil : "reacts like \($0)" }].compactMap { $0 }.joined(separator: ", "), .background)
            summary("Motion moods", (d?.moods ?? []).joined(separator: ", "), .moods)
            summary("Effects pack", d?.effectsPack ?? "", .effects)
            Button { project.openSettings(.look, look: .looks) } label: { Label("Pick a complete look...", systemImage: "wand.and.stars") }
        }
    }

    private func row<C: View>(_ title: String, _ section: LookSection, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(title).font(.callout.weight(.medium)); Spacer(); Button("Change...") { project.openSettings(.look, look: section) }.buttonStyle(.borderless) }
            content()
        }
    }

    private func summary(_ title: String, _ value: String, _ section: LookSection) -> some View {
        row(title, section) { Text(value.isEmpty ? "not chosen yet" : value).font(.callout).foregroundStyle(value.isEmpty ? .secondary : .primary) }
    }
}

// MARK: a scene

struct SceneInspector: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var editingName = false

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private var on: Bool { project.showreel?.film.contains { $0.id == id } ?? false }

    var body: some View {
        if let s = scene {
            VStack(alignment: .leading, spacing: 14) {
                // the name is a label next to the ID: double-click to change it where it stands
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        InlineEdit(text: s.name ?? "", placeholder: "Name this scene", editing: $editingName, commit: { project.renameScene(id, $0) }) {
                            Text("Scene \(s.label)").font(.title3.weight(.semibold)).lineLimit(2)
                                .onTapGesture(count: 2) { editingName = true }
                                .help("Double-click to name the scene. The ID never changes.")
                        }
                        HStack(spacing: 4) {
                            if !s.archived { SceneBadges(scene: s, size: 12) }
                            Text(s.archived ? "Archived" : "\(s.durationLabel) · \(s.state.title)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button { project.selection = .none } label: { Label("Project", systemImage: "slider.horizontal.3") }
                        .buttonStyle(.borderless).help("Back to the project parameters and the global look")
                }
                if s.archived {
                    InspectorSection(title: "Archived") {
                        Text("This scene left the lists. Its ID stays reserved.").font(.callout).foregroundStyle(.secondary)
                        Button("Bring it back") { project.restoreScene(id) }
                    }
                } else {
                    Picker("", selection: $project.sceneTab) { ForEach(SceneTab.allCases) { Text($0.title).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden()
                    Group { switch project.sceneTab {
                    case .settings:
                        Toggle("In the film", isOn: Binding(get: { on }, set: { project.setEnabled(id, $0) })).toggleStyle(.switch)
                        SceneForm(id: id, tab: .settings)
                        InspectorSection(title: "Review") { SceneDecision(id: id) }
                        HStack {
                            Button("Duplicate") { project.duplicateScene(id) }
                            Button("Archive", role: .destructive) { project.archiveScene(id) }
                                .help("Takes the scene out of the lists. Its ID is never reused.")
                        }
                    case .composition:
                        SceneCompositionTab(id: id)
                    case .effects:
                        SceneEffectsTab(id: id)
                    case .look:
                        SceneLookTab(id: id)
                    } }
                    .readOnlyWhenBlocked(.scene(id))
                }
            }
        }
    }
}

/// Background, palette and fonts of one scene. They are the project's, shown locked, until the user asks to replace them for this scene with the switch of the
/// group; switching it off gives the project's values back. The rules (what a switch does) are ShowreelKit's `LookOverrides`.
struct SceneLookTab: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var palette: [String] = []
    @State private var unlocked: Set<SceneLookGroup> = []
    private let fonts = Look.freeFonts().map { $0.name }

    private var scene: ShowreelFile.Scene? { project.showreel?.scenes.first { $0.id == id } }
    private func eff(_ k: DecisionKey) -> String { scene.flatMap { project.showreel?.effective(k, for: $0) } ?? "" }
    private func state(_ g: SceneLookGroup) -> LookOverrides.State? { scene.flatMap { s in project.showreel.map { LookOverrides.state(g, scene: s, in: $0) } } }
    private func isOn(_ g: SceneLookGroup) -> Bool { (state(g)?.overridden ?? false) || unlocked.contains(g) }
    private func focused(_ g: SceneLookGroup) -> Bool { project.lookFocus == g.rawValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The scene follows the project's design system. Replace a group only when this scene must differ: the values then belong to this scene alone.").font(.caption).foregroundStyle(.secondary)
            group(.background) {
                if isOn(.background) {
                    HStack { Text("Background").font(.callout); PickerButton(kind: .background, current: eff(.background)) { project.choose(.background, $0, for: .scene(id)) } }
                    Picker("Reacts to music like", selection: Binding(get: { eff(.backgroundMood) }, set: { project.setSceneLook(id, [DecisionChange(.backgroundMood, $0)]) })) {
                        Text("Calm").tag("")
                        ForEach(Look.backgroundMoods(), id: \.self) { Text($0.capitalized).tag($0) }
                    }
                } else {
                    locked([eff(.background).isEmpty ? "no background chosen in the project yet" : eff(.background), eff(.backgroundMood).isEmpty ? nil : "reacts like \(eff(.backgroundMood))"])
                }
            }
            group(.palette) {
                if isOn(.palette) {
                    ForEach(palette.indices, id: \.self) { i in
                        HStack {
                            Text(["Background", "Text", "Accent", "Accent 2"][min(i, 3)]).frame(width: 90, alignment: .leading)
                            ColorPicker("", selection: Binding(get: { Color(hex: palette[i]) }, set: { palette[i] = $0.hexString }), supportsOpacity: false).labelsHidden()
                            Text(palette[i]).font(.callout.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                    Button("Apply this palette to the scene") { project.setSceneLook(id, [DecisionChange(.palette, palette.joined(separator: ", "))]) }
                        .disabledWithReason(palette.count < 2 ? "A palette needs at least 2 colours" : palette.map { $0.uppercased() } == eff(.palette).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).uppercased() } ? "This already is the scene's palette" : nil)
                } else {
                    let p = eff(.palette).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    if p.isEmpty { locked(["no palette chosen in the project yet"]) } else { Swatches(colours: p).opacity(0.85) }
                }
            }
            group(.fonts) {
                if isOn(.fonts) { fontPicker("Titles", .titleFont); fontPicker("Text", .textFont) }
                else { locked([eff(.titleFont).isEmpty ? nil : "Titles: \(eff(.titleFont))", eff(.textFont).isEmpty ? nil : "Text: \(eff(.textFont))"].map { $0 } + (eff(.titleFont).isEmpty && eff(.textFont).isEmpty ? ["no fonts chosen in the project yet"] : [])) }
            }
        }
        .onAppear { loadPalette() }
        .onChange(of: project.showreel) { _ in loadPalette() }
        .onChange(of: id) { _ in unlocked = [] }
    }

    /// One group: its switch, the mark (inherited or replaced), and the content, locked or editable.
    private func group<C: View>(_ g: SceneLookGroup, @ViewBuilder _ content: @escaping () -> C) -> some View {
        let on = isOn(g), st = state(g)
        return InspectorSection(title: g.title) {
            HStack {
                Toggle("Replace for this scene", isOn: Binding(get: { on }, set: { flip(g, $0) })).toggleStyle(.switch)
                Spacer()
                Text(st?.overridden == true ? "replaced" : "inherited").font(.caption.weight(.semibold)).foregroundStyle(st?.overridden == true ? Color.orange : .secondary)
            }
            if st?.overridden == true, let proj = st?.project.sorted(by: { $0.key.rawValue < $1.key.rawValue }).map({ $0.value }).filter({ !$0.isEmpty }), !proj.isEmpty {
                Text("project: " + proj.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            content()
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(focused(g) ? Color.accentColor : Color.clear, lineWidth: 2))
        .animation(Motion.quick, value: on)
    }

    private func flip(_ g: SceneLookGroup, _ on: Bool) {
        guard let s = scene, let f = project.showreel else { return }
        if on {
            if let op = LookOverrides.enable(g, scene: s, in: f) { project.perform(op) } else { unlocked.insert(g) }
        } else {
            unlocked.remove(g)
            if state(g)?.overridden == true { project.perform(LookOverrides.disable(g, scene: id)) }
        }
    }

    private func locked(_ lines: [String?]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.compactMap { $0 }.enumerated()), id: \.offset) { _, l in Text(l).font(.callout).foregroundStyle(.secondary) }
            Label("locked to the project", systemImage: "lock.fill").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func loadPalette() {
        let p = eff(.palette).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        palette = p.count >= 2 ? p : ["#101820", "#FFFFFF", "#F2AA4C"]
    }

    private func fontPicker(_ title: String, _ k: DecisionKey) -> some View {
        Picker(title, selection: Binding(get: { eff(k) }, set: { project.setSceneLook(id, [DecisionChange(k, $0)]) })) {
            if !eff(k).isEmpty, !fonts.contains(eff(k)) { Text(eff(k)).tag(eff(k)) }
            ForEach(fonts, id: \.self) { Text($0).tag($0) }
        }
    }
}

// MARK: a resource

// MARK: a look element

struct LookInspector: View {
    let kind: LookKind
    let id: String
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorHeader(title: LookElement.title(kind, id, project: project), subtitle: kind.title)
            let sub = LookElement.subtitle(kind, id, project: project)
            if !sub.isEmpty { Text(sub).font(.callout).foregroundStyle(.secondary) }
            actions
        }
    }

    /// A look element is a source: it is dragged onto what takes it, or chosen where it is used. The project-wide choices have one editor, in the project settings.
    @ViewBuilder private var actions: some View {
        switch kind {
        case .looks:
            if let p = LookPackages.all().first(where: { $0.id == id }) {
                Swatches(colours: p.palette)
                Text("\(p.fonts.titles ?? "") + \(p.fonts.text ?? "") · \(p.pack) · \(p.background)").font(.caption).foregroundStyle(.secondary)
                hint("Drag it onto a scene to give that scene this look. Choosing it for the whole project is in the project settings.", .looks)
            }
        case .palettes:
            if let p = LookPackages.all().first(where: { $0.id == id }) {
                Swatches(colours: p.palette)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Contrast.checks(p.palette)) { r in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: r.level.symbol).foregroundStyle(r.level.color)
                            VStack(alignment: .leading, spacing: 0) { Text(r.title).font(.callout.weight(.medium)); Text(r.detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                hint("Drag it onto a scene to give that scene this palette. The project's palette is in the project settings.", .palette)
            } else { hint("The project's palette is edited in the project settings.", .palette) }
        case .fonts:
            LicenceBadge(assessment: FontLicense.assess(name: LookElement.fontFamily(id, project: project), assets: project.assets, store: project.store))
            if !id.hasPrefix("asset:") { Text("The free fonts here are previews to choose from. A film embeds only the font files you add as approved resources.").font(.caption).foregroundStyle(.secondary) }
            hint("The fonts of the project are chosen in the project settings.", .fonts)
        case .backgrounds:
            hint("Drag it onto a scene to give that scene this background, or choose it in the scene's Look tab. The project's default background is in the project settings.", .background)
        case .effects:
            if id.hasPrefix("pack:") {
                let name = String(id.dropFirst(5))
                Text((Look.packs().first { $0.name == name }?.effects ?? []).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                hint("A pack is a whole-project choice: the moods and the effects pack are in the project settings.", .effects)
            } else if let e = engine.catalogue?.effects.first(where: { $0.name == id }) {
                Text("\(e.cat) · energy \(e.energy) · \(String(format: "%.1f", e.dur)) s").font(.caption).foregroundStyle(.secondary)
                Text("Drag it onto a content item, or pick it in the item's animation.").font(.caption).foregroundStyle(.secondary)
            }
        case .transitions:
            if let e = engine.catalogue?.effects.first(where: { $0.name == id }) {
                Text("energy \(e.energy) · \(String(format: "%.1f", e.dur)) s").font(.caption).foregroundStyle(.secondary)
            }
            if Look.isPreviewOnly(id) { Label("Preview only: it does not run between two real scenes, so it cannot be chosen for a montage.", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
            else { Text("Drag it onto a marker of the reel, or choose it in the inspector of a transition.").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func hint(_ text: String, _ section: LookSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.caption).foregroundStyle(.secondary)
            Button("Open the project settings") { project.openSettings(.look, look: section) }.buttonStyle(.bordered)
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
