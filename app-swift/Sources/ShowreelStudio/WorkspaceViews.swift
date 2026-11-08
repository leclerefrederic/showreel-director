import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// The editing workspace: the library on the left, the viewer in the centre, the inspector (with the copilot) on the right, and the
/// storyboard strip at the bottom. Selection drives the viewer and the inspector. The views call typed operations; the rules live in ShowreelKit.
struct WorkspaceView: View {
    var body: some View {
        VSplitView {
            HSplitView {
                LibraryPane().frame(minWidth: 250, idealWidth: 290, maxWidth: 420)
                CenterPane().frame(minWidth: 360)
                InspectorPane().frame(minWidth: 330, idealWidth: 390, maxWidth: 560)
            }
            .frame(minHeight: 380)
            FilmStrip().frame(minHeight: 150, idealHeight: 210, maxHeight: 320)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: library

struct LibraryPane: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $project.libraryTab) { ForEach(LibraryTab.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().padding(10)
            Divider()
            if project.showreel == nil {
                Text("This project has no data yet. Confirm the import or create it with the banner above.").font(.callout).foregroundStyle(.secondary).padding(16)
                Spacer()
            } else {
                switch project.libraryTab {
                case .resources: ResourcesLibrary()
                case .scenes: ScenesLibrary()
                case .look: LookLibrary()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// A selectable row of a library list.
struct LibraryRow<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 8).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ResourcesLibrary: View {
    @EnvironmentObject var project: ProjectModel
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { chooseFiles() } label: { Label("Add files...", systemImage: "plus") }
                Spacer()
                ValidateButton(gate: "assets", block: "library")
            }
            .padding(10)
            ZStack {
                if project.assets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
                        Text("Drop files here").font(.headline)
                        Text("Logos, screenshots, photos, fonts, music. Originals are copied into the project and never changed. Nothing is used until you approve it.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(project.assets) { a in
                                LibraryRow(selected: project.selection == .asset(a.id), action: { project.select(.asset(a.id)) }) { AssetRowView(row: a) }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
                if targeted {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .background(Color.accentColor.opacity(0.08)).padding(6).allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in drop(providers) }
        }
    }

    private func chooseFiles() {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = true
        p.prompt = "Add"
        if p.runModal() == .OK { project.addAssets(p.urls) }
    }

    private func drop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        let lock = NSLock()
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let d = item as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { lock.lock(); urls.append(u); lock.unlock() }
                group.leave()
            }
        }
        group.notify(queue: .main) { project.addAssets(urls) }
        return !providers.isEmpty
    }
}

extension AssetRow {
    var statusColor: Color {
        switch status {
        case "approved": return .green
        case "excluded": return .secondary
        case "hold": return .orange
        case "placeholder": return .purple
        default: return .blue
        }
    }
    var symbolName: String {
        switch type {
        case "logo", "icon", "illus", "img", "shot", "photo": return "photo"
        case "font": return "textformat"
        case "audio", "voice", "sfx": return "waveform"
        case "video", "frames": return "film"
        default: return "doc"
        }
    }
}

struct AssetRowView: View {
    let row: AssetRow
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06))
                if let img = AssetFiles.thumbnail(row, in: project.root) { Image(nsImage: img).resizable().scaledToFit().padding(2) }
                else { Image(systemName: row.symbolName).foregroundStyle(.secondary) }
            }
            .frame(width: 36, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name).font(.callout).lineLimit(1).truncationMode(.middle)
                Text("\(row.id) · \(row.type)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(row.status.capitalized).font(.caption2.weight(.semibold)).foregroundStyle(row.statusColor)
        }
        .opacity(row.status == "excluded" ? 0.5 : 1)
    }
}

/// Where an asset's file is, and a thumbnail when it is an image.
enum AssetFiles {
    private static let imageTypes: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg"]

    static func url(_ row: AssetRow, in root: URL) -> URL? {
        let a = root.appendingPathComponent("assets")
        if !row.file.isEmpty { return a.appendingPathComponent(row.file) }
        if row.origin != "not copied", !row.original.isEmpty { return a.appendingPathComponent("source").appendingPathComponent(row.original) }
        return nil
    }

    static func thumbnail(_ row: AssetRow, in root: URL) -> NSImage? {
        guard let u = url(row, in: root), imageTypes.contains(u.pathExtension.lowercased()) else { return nil }
        return NSImage(contentsOf: u)
    }
}

struct ScenesLibrary: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings
    @State private var showArchived = false

    private var file: ShowreelFile? { project.showreel }
    private var onIDs: Set<String> { Set(file?.film.map { $0.id } ?? []) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { project.addScene() } label: { Label("New scene", systemImage: "plus") }
                Button { draft() } label: { Label("Draft with AI", systemImage: "sparkles") }
                    .help("Optional. The copilot proposes scenes as cards you accept or refuse.")
                Spacer()
            }
            .padding(10)
            let list = file?.orderedLibrary ?? []
            if list.isEmpty {
                Text("No scene yet. Create one, or draft with the AI.").font(.callout).foregroundStyle(.secondary).padding(16)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(list) { s in
                            HStack(spacing: 4) {
                                Toggle("", isOn: Binding(get: { onIDs.contains(s.id) }, set: { project.setEnabled(s.id, $0) }))
                                    .toggleStyle(.checkbox).labelsHidden().help("In the film (the storyboard)")
                                LibraryRow(selected: project.selection == .scene(s.id), action: { project.select(.scene(s.id)) }) { SceneRowView(scene: s, on: onIDs.contains(s.id)) }
                            }
                            .contextMenu {
                                Button("Duplicate") { project.addScene(copying: s.id) }
                                Button("Archive", role: .destructive) { project.archiveScene(s.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    let archived = file?.scenes.filter { $0.archived } ?? []
                    if !archived.isEmpty {
                        DisclosureGroup("Archived (\(archived.count))", isExpanded: $showArchived) {
                            ForEach(archived) { s in
                                HStack {
                                    Text(s.id).font(.callout.monospaced()).strikethrough()
                                    Text(s.text.isEmpty ? "" : s.text).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Bring back") { project.restoreScene(s.id) }.buttonStyle(.borderless).font(.caption)
                                }
                            }
                            Text("An archived scene keeps its ID for good.").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(10)
                    }
                }
            }
        }
    }

    private func draft() {
        guard settings.hasKey else { project.error = "Drafting needs an AI. Connect one in Settings, or write the scenes by hand: everything else works without it."; return }
        project.inspectorTab = .copilot
        chat.ask(prompt: Wizard.draftScenesPrompt)
    }
}

struct SceneRowView: View {
    let scene: ShowreelFile.Scene
    let on: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: scene.statusSymbol).foregroundStyle(scene.statusColor)
            Text(scene.id).font(.callout.monospaced().weight(.semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(scene.text.isEmpty ? "(no text)" : scene.text).lineLimit(1).font(.callout)
                Text(scene.durationLabel).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .opacity(on ? 1 : 0.5)
    }
}

// MARK: look elements

struct LookLibrary: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var search = ""
    private let fonts = Look.freeFonts()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $project.lookKind) { ForEach(LookKind.allCases) { Text($0.title).tag($0) } }.labelsHidden()
                if [.fonts, .effects, .backgrounds].contains(project.lookKind) {
                    TextField("Search", text: $search).textFieldStyle(.roundedBorder)
                }
            }
            .padding(10)
            ScrollView {
                LazyVStack(spacing: 2) { rows }.padding(.horizontal, 6)
            }
        }
        .task { await engine.start() }
        .onAppear { FontRegistry.shared.registerAll() }
        .onChange(of: project.lookKind) { _ in search = "" }
    }

    private func matches(_ s: String) -> Bool { search.isEmpty || s.localizedCaseInsensitiveContains(search) }

    @ViewBuilder private var rows: some View {
        let kind = project.lookKind
        let d = project.showreel?.decisions
        switch kind {
        case .looks:
            let tone = project.showreel?.parameters.tone
            ForEach(LookPackages.all()) { p in
                row(.looks, p.id) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text(p.name).font(.callout.weight(.semibold)); if LookPackages.matches(p, tone: tone) { chip("Fits your tone") }; Spacer() }
                        Swatches(colours: p.palette)
                        Text(p.why).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        case .palettes:
            row(.palettes, "project") {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Project palette").font(.callout.weight(.semibold))
                    if let p = d?.palette, !p.isEmpty { Swatches(colours: p) } else { Text("Not chosen yet").font(.caption).foregroundStyle(.secondary) }
                }
            }
            ForEach(LookPackages.all()) { p in
                row(.palettes, p.id) {
                    VStack(alignment: .leading, spacing: 3) { Text(p.name).font(.callout); Swatches(colours: p.palette) }
                }
            }
        case .fonts:
            ForEach(project.assets.filter { $0.type == "font" && $0.status != "excluded" && matches($0.name) }) { a in
                row(.fonts, "asset:" + a.id) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(AssetFonts.family(a, in: project.root)).font(.callout.weight(.semibold))
                        Text("Your font").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(fonts.filter { matches($0.name) }) { f in
                row(.fonts, f.name) {
                    HStack {
                        Text(f.name).font(.custom(FontRegistry.shared.family(f.name), size: 17)).lineLimit(1)
                        Spacer()
                        Text(f.cat).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        case .backgrounds:
            ForEach((engine.catalogue?.backgrounds ?? []).filter { matches($0.name) || matches($0.family) }) { b in
                row(.backgrounds, b.id) {
                    HStack { Text(b.name).font(.callout); Spacer(); Text(b.animated ? "Animated" : b.family).font(.caption2).foregroundStyle(.secondary) }
                }
            }
        case .effects:
            ForEach(Look.packs().filter { matches($0.name) }) { p in
                row(.effects, "pack:" + p.name) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack { Text(p.name).font(.callout.weight(.semibold)); chip("Pack"); Spacer() }
                        Text(p.feel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            ForEach((engine.catalogue?.effects ?? []).filter { $0.cat != EngineCatalogue.transitionCategory && matches($0.name) }) { e in
                row(.effects, e.name) {
                    HStack { Text(e.name).font(.callout); Spacer(); Text(e.cat).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
        case .transitions:
            ForEach((engine.catalogue?.effects ?? []).filter { $0.cat == EngineCatalogue.transitionCategory }) { e in
                row(.transitions, e.name) {
                    HStack { Text(e.name).font(.callout); Spacer(); Text(e.energy).font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func row<C: View>(_ kind: LookKind, _ id: String, @ViewBuilder _ content: @escaping () -> C) -> some View {
        LibraryRow(selected: project.selection == .look(kind, id), action: { project.select(.look(kind, id)) }, content: content)
    }

    private func chip(_ t: String) -> some View {
        Text(t).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 1).background(Color.accentColor.opacity(0.18), in: Capsule())
    }
}

/// The family name of a font file the user added.
enum AssetFonts {
    @MainActor static func family(_ a: AssetRow, in root: URL) -> String {
        guard let u = AssetFiles.url(a, in: root) else { return (a.name as NSString).deletingPathExtension }
        return FontRegistry.shared.register(u) ?? (a.name as NSString).deletingPathExtension
    }
}

// MARK: storyboard strip

struct FilmStrip: View {
    @EnvironmentObject var project: ProjectModel

    private var file: ShowreelFile? { project.showreel }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let f = file, let m = f.storyboards.first {
                let items = m.items.filter { it in f.scenes.contains { $0.id == it.scene && !$0.archived } }
                if items.isEmpty {
                    Text("The storyboard is empty. Create scenes in the library: each one you switch on appears here, in order.")
                        .font(.callout).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                } else {
                    let timed = Dictionary(f.timeline().map { ($0.scene.id, $0) }, uniquingKeysWith: { a, _ in a })
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(items, id: \.scene) { it in
                                if let s = f.scenes.first(where: { $0.id == it.scene }) {
                                    FrameCard(scene: s, item: it, timed: timed[s.id]).id(it.scene)
                                }
                            }
                            Color.clear.frame(width: 60, height: 100)
                                .dropDestination(for: String.self) { ids, _ in
                                    guard let id = ids.first else { return false }
                                    project.moveScene(id, before: nil); return true
                                }
                        }
                        .padding(10)
                    }
                }
            } else {
                Spacer()
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Storyboard", systemImage: "film.stack").font(.headline)
            if let f = file {
                let end = f.filmEnd
                let target = f.decisions.duration
                Text(summary(count: f.film.count, end: end, target: target)).font(.callout).foregroundStyle(.secondary)
                let worst = Checks.worst((project.checks["storyboard"] ?? []) + (project.checks["scene"] ?? []))
                Image(systemName: worst.symbol).foregroundStyle(worst.color).help("Film-level checks: see the Checks menu")
            }
            Spacer()
            if file != nil {
                ValidateButton(gate: "storyboard", block: "storyboard")
                GoButton()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.bar)
    }

    private func summary(count: Int, end: Double?, target: Double?) -> String {
        var t = "\(count) scene\(count == 1 ? "" : "s") on"
        if let e = end { t += " · \(ProjectDocs.seconds(e)) s" }
        if let d = target { t += " of \(ProjectDocs.seconds(d)) s" }
        return t
    }
}

/// One frame of the strip: the scene's thumbnail, its ID, duration and review state, on or off. Drag it to reorder.
struct FrameCard: View {
    let scene: ShowreelFile.Scene
    let item: ShowreelFile.MontageItem
    let timed: TimedScene?
    @EnvironmentObject var project: ProjectModel
    @State private var targeted = false

    private var selected: Bool { project.selection == .scene(scene.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                SceneThumb(scene: scene, still: true)
                    .frame(width: 168, height: 94)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .opacity(item.enabled ? 1 : 0.35)
                Text(scene.id).font(.caption2.monospaced().weight(.bold)).padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(.white).padding(4)
                if !item.enabled { Text("OFF").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 168, height: 94) }
            }
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(targeted ? Color.accentColor : selected ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: selected || targeted ? 3 : 1))
            HStack(spacing: 6) {
                Image(systemName: scene.statusSymbol).foregroundStyle(scene.statusColor).font(.caption)
                Text(scene.durationLabel == "no duration" ? "no duration" : scene.durationLabel).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(get: { item.enabled }, set: { project.setEnabled(scene.id, $0) })).toggleStyle(.switch).controlSize(.mini).labelsHidden()
                    .help("In the film")
            }
            .frame(width: 168)
            if let t = timed, let a = t.start { Text("from \(ProjectDocs.seconds(a)) s").font(.caption2).foregroundStyle(.tertiary) }
        }
        .contentShape(Rectangle())
        .onTapGesture { project.select(.scene(scene.id)) }
        .draggable(scene.id)
        .dropDestination(for: String.self, action: { ids, _ in
            guard let id = ids.first, id != scene.id else { return false }
            project.moveScene(id, before: scene.id); return true
        }, isTargeted: { targeted = $0 })
    }
}

/// A scene drawn by the engine (see EngineService.sceneFrames): a still for the strip, an animation in the viewer.
struct SceneThumb: View {
    let scene: ShowreelFile.Scene
    var still = false
    var size: CGSize = EngineService.frameSize
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var frames: [NSImage] = []

    private var token: String {
        let d = project.showreel?.decisions
        return [scene.id, scene.text, scene.texts.sorted { $0.key < $1.key }.map { $0.value }.joined(), (d?.palette ?? []).joined(), d?.fonts?.titles ?? "", d?.background?.id ?? "",
                d?.background?.mood ?? "", d?.effectsPack ?? "", (d?.moods ?? []).joined(), "\(Int(size.width))"].joined(separator: "|")
    }

    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.06))
            if frames.isEmpty {
                if let f = engine.failure { Text(f).font(.caption2).foregroundStyle(.secondary).padding(4) } else { ProgressView().controlSize(.small) }
            } else if still {
                Image(nsImage: frames[min(frames.count - 1, frames.count * 3 / 4)]).resizable().scaledToFill()
            } else {
                TimelineView(.periodic(from: .now, by: 0.12)) { ctx in
                    Image(nsImage: frames[Int(ctx.date.timeIntervalSinceReferenceDate / 0.12) % frames.count]).resizable().scaledToFit()
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .task(id: token) { frames = await engine.sceneFrames(scene, file: project.showreel, store: project.store, size: size) }
    }
}
