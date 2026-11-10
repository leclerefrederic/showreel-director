import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// The editing workspace: the library on the left, the viewer in the centre, the inspector (with the copilot) on the right, and the
/// storyboard strip at the bottom. Selection drives the viewer and the inspector. The views call typed operations; the rules live in ShowreelKit.
struct WorkspaceView: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var theme: Theme
    @State private var live: PanelLayout?
    @State private var dragStart: Double?

    private var sizes: PanelLayout { live ?? project.layout }

    var body: some View {
        GeometryReader { geo in
            // the frames come from ShowreelKit's `ShellLayout` (the stored sizes, clamped for drawing, never overwritten): the rail, the left panels and the right panel, the preview
            // and the Film strip, in the placement the owner chose
            let f = ShellLayout.frames(window: geo.size, placement: project.filmPlacement, sizes: sizes, right: project.rightPanel)
            let g = CGFloat(ShellLayout.gap)
            ZStack(alignment: .topLeading) {
                ViewRailView().frame(width: f.rail.width, height: f.rail.height)
                region(f.left) { LibraryPane().panelContainer() }
                region(f.preview) { CenterPane().panelContainer() }
                region(f.film) { FilmStrip().clipShape(RoundedRectangle(cornerRadius: theme.rLarge, style: .continuous)) }
                if let r = f.right {
                    region(r) { RightPanelView().panelContainer() }.transition(.move(edge: .trailing).combined(with: .opacity))
                }
                // the dividers are the gaps between the panels
                SplitHandle(vertical: true) { dx, ended in drag(.library, from: f.leftWidth, by: dx, ended: ended) }
                    .frame(width: g, height: f.left.height).offset(x: f.left.maxX, y: f.left.minY)
                if let r = f.right {
                    SplitHandle(vertical: true) { dx, ended in drag(project.rightPanel == .project ? .settings : .inspector, from: f.rightWidth, by: -dx, ended: ended) }
                        .frame(width: g, height: r.height).offset(x: r.minX - g, y: r.minY)
                }
                SplitHandle(vertical: false) { dy, ended in drag(.strip, from: f.filmHeight, by: -dy, ended: ended) }
                    .frame(width: f.film.width, height: g).offset(x: f.film.minX, y: f.film.minY - g)
            }
            .animation(Motion.spring, value: project.filmPlacement)
            .animation(Motion.spring, value: project.rightPanel)
        }
        .canvasBackground()
        .dragDropRoot(project)
        // Shift-Command-A: Clap opens and the cursor goes to its input, from anywhere in the project window
        .background { Button("") { project.openClap() }.keyboardShortcut("a", modifiers: [.command, .shift]).opacity(0).frame(width: 0, height: 0).accessibilityHidden(true) }
    }

    private func region<C: View>(_ r: CGRect, @ViewBuilder _ content: () -> C) -> some View {
        content().frame(width: max(0, r.width), height: max(0, r.height)).offset(x: r.minX, y: r.minY)
    }

    private enum Panel { case library, inspector, settings, strip }

    /// Dragging a divider changes one stored size; the new value is kept when the drag ends. The placement of the Film strip never changes it.
    private func drag(_ p: Panel, from start: Double, by delta: CGFloat, ended: Bool) {
        if dragStart == nil { dragStart = start }
        let v = (dragStart ?? start) + Double(delta)
        var l = project.layout
        switch p {
        case .library: l = l.replacing(library: v)
        case .inspector: l = l.replacing(inspector: v)
        case .settings: l = l.replacing(settings: v)
        case .strip: l = l.replacing(strip: v)
        }
        if ended { live = nil; dragStart = nil; project.setLayout(l) } else { live = l }
    }
}

/// The one panel of the right side: the Inspector, Clap, or the project settings (Look and Project).
struct RightPanelView: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        switch project.rightPanel {
        case .clap?: ClapPanel()
        case .project?: ProjectSettingsPanel()
        default: InspectorPanel()
        }
    }
}

/// A divider between two panels: a thin line to drag, with the resize cursor.
struct SplitHandle: View {
    let vertical: Bool
    let onDrag: (CGFloat, Bool) -> Void
    @EnvironmentObject var theme: Theme
    @State private var hot = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Capsule().fill(hot ? theme.accent.opacity(0.7) : Color.clear).frame(width: vertical ? 2 : 40, height: vertical ? 40 : 2)          // the gap is the divider: it shows under the pointer
        }
        .frame(width: vertical ? 6 : nil, height: vertical ? nil : 6)
        .contentShape(Rectangle())
        .onHover { inside in
            hot = inside
            if inside { (vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set() } else { NSCursor.arrow.set() }
        }
        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { onDrag(vertical ? $0.translation.width : $0.translation.height, false) }
            .onEnded { onDrag(vertical ? $0.translation.width : $0.translation.height, true) })
    }
}

// MARK: library

/// The checks of the project, by group (Project, Resources, Scenes, Storyboard, Music, Build). A click opens what the check is about.
struct ChecksLibrary: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let groups = CheckPanel.grouped(project.checkEntries)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if groups.isEmpty { Text("Nothing to check yet.").font(.callout).foregroundStyle(.secondary).padding(16) }
                ForEach(groups, id: \.group) { g in
                    let hot = g.entries.filter { $0.result.level == .fail || $0.result.level == .tight }
                    let rest = g.entries.filter { $0.result.level != .fail && $0.result.level != .tight }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: g.group.symbol).foregroundStyle(.secondary)
                            Text(g.group.title).font(.callout.weight(.semibold))
                            if !hot.isEmpty { Text("\(hot.count)").fontSmall(weight: .bold).foregroundStyle(.white).padding(.horizontal, 5).background(hot.contains { $0.result.level == .fail } ? Color.red : Color.orange, in: Capsule()) }
                            Spacer()
                        }
                        ForEach(hot) { e in CheckRow(entry: e) }
                        if !rest.isEmpty {
                            DisclosureGroup("Fine or waiting (\(rest.count))") { VStack(spacing: 2) { ForEach(rest) { e in CheckRow(entry: e) } } }
                                .fontSmall().foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(10)
        }
    }
}

struct CheckRow: View {
    let entry: CheckEntry
    @EnvironmentObject var project: ProjectModel
    @State private var hovering = false

    var body: some View {
        let r = entry.result
        Button { project.openCheck(entry) } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: r.level.symbol).foregroundStyle(r.level.color).frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(r.title).font(.callout.weight(.medium)).multilineTextAlignment(.leading)
                    Text(r.detail).fontSmall().foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").fontSmall().foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.primary.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Open what this is about")
    }
}

/// A selectable row of a library list.
struct LibraryRow<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 8).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .rowSurface(selected: selected, hovering: hovering)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: selected)
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

/// The items of the context menu of a scene, wherever the scene is shown (library row, frame of the reel).
struct SceneMenu: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        Button("Rename") { project.beginRename(id) }
        Divider()
        Button("Delete scene\u{2026}", role: .destructive) { project.askDelete(id) }
    }
}

/// A scene that replaces part of the project's look carries this mark: in the library, the tree and the reel.
struct OverrideBadge: View {
    let scene: ShowreelFile.Scene
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        if let f = project.showreel {
            let groups = LookOverrides.groups(of: scene, in: f)
            if !groups.isEmpty {
                Image(systemName: "paintpalette.fill").font(.system(size: 11)).foregroundColor(.orange).padding(3)
                    .background(Color.orange.opacity(0.2), in: Circle())
                    .help("This scene replaces the project's " + groups.map { $0.rawValue }.joined(separator: ", "))
            }
        }
    }
}

// MARK: look elements (the Catalogue palette)

struct LookLibrary: View {
    /// The kinds the list offers (the Catalogue palette leaves fonts out: a font has nothing to be dropped on).
    var kinds: [LookKind] = LookKind.allCases
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var search = ""
    private let fonts = Look.freeFonts()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $project.lookKind) { ForEach(kinds) { Text($0.title).tag($0) } }.labelsHidden()
                if [.fonts, .effects, .backgrounds].contains(project.lookKind) {
                    TextField("Search", text: $search).textFieldStyle(ThemedTextFieldStyle())
                }
            }
            .padding(10)
            ScrollView {
                LazyVStack(spacing: 2) { rows }.padding(.horizontal, 6)
            }
        }
        .task { await engine.start() }
        .onAppear { FontRegistry.shared.registerAll(); if !kinds.contains(project.lookKind), let k = kinds.first { project.lookKind = k } }
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
                        Text(p.why).fontSmall().foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        case .palettes:
            row(.palettes, "project") {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Project palette").font(.callout.weight(.semibold))
                    if let p = d?.palette, !p.isEmpty { Swatches(colours: p) } else { Text("Not chosen yet").fontSmall().foregroundStyle(.secondary) }
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
                        Text("Your font").fontSmall().foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(fonts.filter { matches($0.name) }) { f in
                row(.fonts, f.name) {
                    HStack {
                        Text(f.name).font(.custom(FontRegistry.shared.family(f.name), size: 17)).lineLimit(1)
                        Spacer()
                        Text(f.cat).fontSmall().foregroundStyle(.secondary)
                    }
                }
            }
        case .backgrounds:
            ForEach((engine.catalogue?.backgrounds ?? []).filter { matches($0.name) || matches($0.family) }) { b in
                row(.backgrounds, b.id) {
                    HStack { Text(b.name).font(.callout); Spacer(); Text(b.animated ? "Animated" : b.family).fontSmall().foregroundStyle(.secondary) }
                }
            }
        case .effects:
            ForEach(Look.packs().filter { matches($0.name) }) { p in
                row(.effects, "pack:" + p.name) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack { Text(p.name).font(.callout.weight(.semibold)); chip("Pack"); Spacer() }
                        Text(p.feel).fontSmall().foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            ForEach((engine.catalogue?.effects ?? []).filter { $0.cat != EngineCatalogue.transitionCategory && matches($0.name) }) { e in
                row(.effects, e.name) {
                    HStack { Text(e.name).font(.callout); Spacer(); Text(e.cat).fontSmall().foregroundStyle(.secondary).lineLimit(1) }
                }
            }
        case .transitions:
            ForEach((engine.catalogue?.effects ?? []).filter { $0.cat == EngineCatalogue.transitionCategory }) { e in
                row(.transitions, e.name) {
                    HStack { Text(e.name).font(.callout); Spacer(); if Look.isPreviewOnly(e.name) { chip("preview only") } else { Text(e.energy).fontSmall().foregroundStyle(.secondary) } }
                }
            }
        }
    }

    /// A look element can be dragged onto what takes it (a background or a look onto a scene, an effect onto an item, a transition onto a marker).
    @ViewBuilder private func row<C: View>(_ kind: LookKind, _ id: String, @ViewBuilder _ content: @escaping () -> C) -> some View {
        if let item = DragItem.library(kind: kind.rawValue, id: id) {
            DragRow(selected: project.selection == .look(kind, id), item: item, label: id.hasPrefix("pack:") ? String(id.dropFirst(5)) : id,
                    icon: kind == .transitions ? "arrow.left.arrow.right" : kind == .effects ? "sparkles" : kind == .backgrounds ? "rectangle.on.rectangle" : "paintpalette",
                    help: "Drag onto what takes it, or click to see it", action: { project.select(.look(kind, id)) }, content: content)
        } else { LibraryRow(selected: project.selection == .look(kind, id), action: { project.select(.look(kind, id)) }, content: content) }
    }

    private func chip(_ t: String) -> some View {
        Text(t).fontSmall(weight: .semibold).padding(.horizontal, 6).padding(.vertical, 1).background(Color.accentColor.opacity(0.18), in: Capsule())
    }
}

/// The family name of a font file the user added.
enum AssetFonts {
    @MainActor static func family(_ a: AssetRow, in root: URL) -> String {
        guard let u = AssetFiles.url(a, in: root) else { return (a.name as NSString).deletingPathExtension }
        return FontRegistry.shared.register(u) ?? (a.name as NSString).deletingPathExtension
    }
}

/// A scene's picture in the viewer, before a build has one to play (the strip's frames show the captured PNG instead, W4b). A scene with content is drawn from what the content says
/// (`StageThumb`, W4), at `time`; a scene with no content yet is the engine's stand-in (see `EngineSceneThumb`).
struct SceneThumb: View {
    let scene: ShowreelFile.Scene
    var size: CGSize = EngineService.frameSize
    /// Seconds from the scene's start; nil is the scene's own still time.
    var time: Double?

    var body: some View {
        if scene.content.isEmpty { EngineSceneThumb(scene: scene, size: size) }
        else { StageThumb(scene: scene, time: time ?? ContentTiming.stillTime(of: scene), size: size) }
    }
}

/// A scene with no content, drawn by the engine (see EngineService.sceneFrames): an animation in the viewer.
struct EngineSceneThumb: View {
    let scene: ShowreelFile.Scene
    var size: CGSize = EngineService.frameSize
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var frames: [NSImage] = []

    private var token: String {
        let d = project.showreel?.decisions
        return [scene.id, "\(String(describing: scene.overrides))", scene.text, scene.texts.sorted { $0.key < $1.key }.map { $0.value }.joined(), (d?.palette ?? []).joined(), d?.fonts?.titles ?? "", d?.background?.id ?? "",
                d?.background?.mood ?? "", d?.effectsPack ?? "", (d?.moods ?? []).joined(), "\(Int(size.width))"].joined(separator: "|")
    }

    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.06))
            if frames.isEmpty {
                if let f = engine.failure { Text(f).fontSmall().foregroundStyle(.secondary).padding(4) } else { ProgressView().controlSize(.small) }
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

// MARK: the scene tree

extension NodeStatus {
    var color: Color {
        switch self {
        case .approved: return .green
        case .toApprove: return .orange
        case .missing, .overBudget: return .red
        case .excluded: return .secondary
        }
    }
}

/// What a scene is made of: Raw, Texts, Effects, Background, Look. Selecting a node opens the matching tab of the scene's inspector. The nodes take drops
/// (a resource links it to the scene, an effect goes on an item's node), and the items can be dragged to change their priority.
struct SceneTreeView: View {
    let scene: String
    @EnvironmentObject var project: ProjectModel

    private var order: [String] { project.showreel?.scenes.first { $0.id == scene }?.content.map { $0.id } ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let s = project.showreel?.scenes.first(where: { $0.id == scene }) {
                HStack(spacing: 6) { SceneStatusIcon(scene: s); Text(project.sceneStatus(for: s).kind.title).fontSmall().foregroundStyle(.secondary); Spacer(); BlockMarker(ref: .scene(scene)) }
                    .padding(.vertical, 2).temporaryVeil(.scene(scene), radius: 5)
            }
            ForEach(project.trees[scene] ?? []) { g in group(g) }
        }
        .animation(Motion.spring, value: project.trees[scene] ?? [])
    }

    /// A group of the tree. Clicking its title opens the matching tab of the scene's inspector; its nodes open it on that element.
    @ViewBuilder private func group(_ g: SceneGroupNodes) -> some View {
        Button { project.selectNode(scene, g.group, nil) } label: {
            HStack(spacing: 4) {
                Text(g.group.title).fontSmall(weight: .semibold).foregroundStyle(.secondary)
                if g.group != .look && !g.nodes.isEmpty { Text("\(g.nodes.count)").fontSmall().foregroundStyle(.tertiary) }
                if g.group == .look, let s = project.showreel?.scenes.first(where: { $0.id == scene }) { OverrideBadge(scene: s) }
                Spacer()
            }
            .padding(.top, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropTarget(.sceneNode(scene: scene, group: g.group, node: nil))
        if g.nodes.isEmpty {
            Text(g.group == .effects ? "none yet" : "nothing yet").fontSmall().foregroundStyle(.tertiary).padding(.leading, 8)
        }
        ForEach(g.nodes) { n in node(g.group, n) }
        if g.group == .composition { SlotGap(target: .contentSlot(scene: scene, before: nil), size: 24) }
    }

    @ViewBuilder private func node(_ group: SceneGroup, _ n: SceneNode) -> some View {
        let item: String? = n.id.hasPrefix("item.") ? String(n.id.dropFirst(5)) : nil
        let next: String? = item.flatMap { i in order.firstIndex(of: i).flatMap { $0 + 1 < order.count ? order[$0 + 1] : nil } }
        VStack(spacing: 0) {
            if let i = item { SlotGap(target: .contentSlot(scene: scene, before: i), size: 24) }
            let row = LibraryRow(selected: project.selection == .sceneNode(scene, group, n.id), action: { project.selectNode(scene, group, n.id) }) {
                HStack(spacing: 6) {
                    if item != nil { Handle() }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(n.title).fontSmall().lineLimit(1).truncationMode(.middle)
                        Text(n.detail).fontSmall().foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    if let i = item { BlockMarker(ref: .item(scene: scene, item: i)) }
                    if let st = n.status { Text(st.rawValue).fontSmall(weight: .semibold).foregroundStyle(st.color) }
                    if let o = n.origin { Text(o.rawValue).fontSmall().foregroundStyle(o == .overridden ? Color.orange : .secondary) }
                }
            }
            .dropTarget(.sceneNode(scene: scene, group: group, node: n.id))
            .contextMenu { nodeMenu(n, item) }
            if let i = item {
                row.dragSource(.content(scene: scene, item: i), label: n.title, icon: "line.3.horizontal")
                    .dropSlots(before: .contentSlot(scene: scene, before: i), after: .contentSlot(scene: scene, before: next))
            } else { row }
        }
        .transition(Motion.appear)
    }

    @ViewBuilder private func nodeMenu(_ n: SceneNode, _ item: String?) -> some View {
        if let i = item {
            Button("Duplicate") { project.duplicateItem(scene, i) }
            Button("Remove", role: .destructive) { project.removeItem(scene, i) }
        } else if n.id.hasPrefix("raw."), let a = n.assetID {
            Button("Unlink from the scene", role: .destructive) { project.unlink(a, from: scene) }
        }
    }
}
