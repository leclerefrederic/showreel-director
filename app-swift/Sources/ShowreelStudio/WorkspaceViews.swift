import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// The editing workspace: the library on the left, the viewer in the centre, the inspector (with the copilot) on the right, and the
/// storyboard strip at the bottom. Selection drives the viewer and the inspector. The views call typed operations; the rules live in ShowreelKit.
struct WorkspaceView: View {
    @EnvironmentObject var project: ProjectModel
    @State private var live: PanelLayout?
    @State private var dragStart: Double?
    private static let centerMinWidth = 320.0, centerMinHeight = 200.0, handle = 6.0

    private var layout: PanelLayout { live ?? project.layout }

    var body: some View {
        GeometryReader { geo in
            let lw = fit(layout.libraryWidth, floor: PanelLayout.minLibrary, room: geo.size.width - layout.inspectorWidth - Self.centerMinWidth - 2 * Self.handle)
            let iw = fit(layout.inspectorWidth, floor: PanelLayout.minInspector, room: geo.size.width - lw - Self.centerMinWidth - 2 * Self.handle)
            let sh = fit(layout.stripHeight, floor: PanelLayout.minStrip, room: geo.size.height - Self.centerMinHeight - Self.handle)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    LibraryPane().frame(width: lw)
                    SplitHandle(vertical: true) { dx, ended in drag(.library, from: lw, by: dx, ended: ended) }
                    CenterPane().frame(minWidth: Self.centerMinWidth, maxWidth: .infinity)
                    SplitHandle(vertical: true) { dx, ended in drag(.inspector, from: iw, by: -dx, ended: ended) }
                    InspectorPane().frame(width: iw)
                }
                SplitHandle(vertical: false) { dy, ended in drag(.strip, from: sh, by: -dy, ended: ended) }
                FilmStrip().frame(height: sh)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .dragDropRoot(project)
    }

    /// A stored size, never under its floor; it gives way only when the window leaves no room for the others (the stored value is kept).
    private func fit(_ v: Double, floor: Double, room: Double) -> CGFloat { CGFloat(max(floor, min(v, room))) }

    private enum Panel { case library, inspector, strip }

    /// Dragging a divider changes one size; the new value is kept when the drag ends.
    private func drag(_ p: Panel, from start: CGFloat, by delta: CGFloat, ended: Bool) {
        if dragStart == nil { dragStart = Double(start) }
        let v = (dragStart ?? Double(start)) + Double(delta)
        var l = project.layout
        switch p {
        case .library: l = PanelLayout(library: v, inspector: l.inspector, strip: l.strip, settings: l.settings)
        case .inspector: l = PanelLayout(library: l.library, inspector: v, strip: l.strip, settings: l.settings)
        case .strip: l = PanelLayout(library: l.library, inspector: l.inspector, strip: v, settings: l.settings)
        }
        if ended { live = nil; dragStart = nil; project.setLayout(l) } else { live = l }
    }
}

/// A divider between two panels: a thin line to drag, with the resize cursor.
struct SplitHandle: View {
    let vertical: Bool
    let onDrag: (CGFloat, Bool) -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle().fill(Color.primary.opacity(0.18)).frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
        }
        .frame(width: vertical ? 6 : nil, height: vertical ? nil : 6)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { (vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set() } else { NSCursor.arrow.set() }
        }
        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { onDrag(vertical ? $0.translation.width : $0.translation.height, false) }
            .onEnded { onDrag(vertical ? $0.translation.width : $0.translation.height, true) })
    }
}

// MARK: library

struct LibraryPane: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            LibraryTabs().padding(10)
            Divider()
            if project.showreel == nil {
                Text("This project has no data yet. Confirm the import or create it with the banner above.").font(.callout).foregroundStyle(.secondary).padding(16)
                Spacer()
            } else {
                switch project.libraryTab {
                case .resources: ResourcesLibrary()
                case .scenes: ScenesLibrary()
                case .checks: ChecksLibrary()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// The tabs of the left panel: Resources, Scenes and Checks, with a pill on Checks that counts what is red or orange.
struct LibraryTabs: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LibraryTab.allCases) { t in
                Button { project.libraryTab = t } label: {
                    HStack(spacing: 5) {
                        Text(t.title)
                        if t == .checks, project.attentionCount > 0 {
                            Text("\(project.attentionCount)").font(.caption2.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 1)
                                .background(project.checkEntries.contains { $0.result.level == .fail } ? Color.red : Color.orange, in: Capsule())
                        }
                    }
                    .font(.callout.weight(project.libraryTab == t ? .semibold : .regular))
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                    .background(project.libraryTab == t ? Color(nsColor: .controlColor) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(Motion.quick, value: project.libraryTab)
    }
}

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
                            if !hot.isEmpty { Text("\(hot.count)").font(.caption2.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 5).background(hot.contains { $0.result.level == .fail } ? Color.red : Color.orange, in: Capsule()) }
                            Spacer()
                        }
                        ForEach(hot) { e in CheckRow(entry: e) }
                        if !rest.isEmpty {
                            DisclosureGroup("Fine or waiting (\(rest.count))") { VStack(spacing: 2) { ForEach(rest) { e in CheckRow(entry: e) } } }
                                .font(.caption).foregroundStyle(.secondary)
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
                    Text(r.detail).font(.caption).foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
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
                .background(selected ? Color.accentColor.opacity(0.2) : hovering ? Color.primary.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: selected)
    }
}

struct ResourcesLibrary: View {
    @EnvironmentObject var project: ProjectModel

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
                        let ids = project.assets.map { $0.id }
                        VStack(spacing: 0) {
                            ForEach(Array(project.assets.enumerated()), id: \.element.id) { n, a in
                                VStack(spacing: 0) {
                                    SlotGap(target: .assetSlot(before: a.id))
                                    LibraryRow(selected: project.selection == .asset(a.id), action: { project.select(.asset(a.id)) }) {
                                        HStack(spacing: 6) { Handle(); AssetRowView(row: a) }
                                    }
                                    .padding(.vertical, 1)
                                    .dragSource(.resource(a.id), label: a.name, icon: a.symbolName)
                                    .dropSlots(before: .assetSlot(before: a.id), after: .assetSlot(before: n + 1 < ids.count ? ids[n + 1] : nil))
                                    .contextMenu { menu(a) }
                                }
                                .transition(Motion.appear)
                            }
                            SlotGap(target: .assetSlot(before: nil))
                        }
                        .animation(Motion.spring, value: ids)
                        .padding(.horizontal, 6)
                    }
                }
            }
            .dropTarget(.resourceList)      // files from the Finder land here: added with the automatic checks
        }
    }

    @ViewBuilder private func menu(_ a: AssetRow) -> some View {
        if a.status == "proposed" || a.status == "placeholder" { Button("Approve") { project.setAssetStatus(a.id, .approved) } }
        if a.status == "excluded" { Button("Put back") { project.setAssetStatus(a.id, .proposed) } }
        else { Button("Exclude from the project", role: .destructive) { project.setAssetStatus(a.id, .excluded) } }
        if let u = AssetFiles.url(a, in: project.root) { Divider(); Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) } }
    }

    private func chooseFiles() {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = true
        p.prompt = "Add"
        if p.runModal() == .OK { project.addAssets(p.urls) }
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
                    .help("Optional. Clap proposes scenes as cards you accept or refuse.")
                LockAllValidatedButton()
                Spacer()
            }
            .padding(10)
            let list = file?.orderedLibrary ?? []
            if list.isEmpty {
                Text("No scene yet. Create one, or draft with the AI.").font(.callout).foregroundStyle(.secondary).padding(16)
                Spacer()
            } else {
                ScrollView {
                    let ids = list.map { $0.id }
                    VStack(spacing: 0) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { n, s in
                            let next: String? = n + 1 < ids.count ? ids[n + 1] : nil
                            VStack(alignment: .leading, spacing: 0) {
                                SlotGap(target: .librarySlot(before: s.id))
                                HStack(spacing: 4) {
                                    Handle()
                                    Button { toggle(s.id) } label: { Image(systemName: project.expanded.contains(s.id) ? "chevron.down" : "chevron.right").frame(width: 12) }
                                        .buttonStyle(.borderless).help("Show what the scene is made of")
                                    Toggle("", isOn: Binding(get: { onIDs.contains(s.id) }, set: { project.setEnabled(s.id, $0) }))
                                        .toggleStyle(.checkbox).labelsHidden().help("In the film (the storyboard)")
                                    LibraryRow(selected: project.selection == .scene(s.id), action: { project.select(.scene(s.id)) }) { SceneRowView(scene: s, on: onIDs.contains(s.id)) }
                                        .simultaneousGesture(TapGesture(count: 2).onEnded { project.beginRename(s.id) })
                                }
                                .padding(.vertical, 1)
                                .dragSource(.scene(s.id), label: s.label, icon: "film")
                                .dropTarget(.scene(s.id))
                                .dropSlots(before: .librarySlot(before: s.id), after: .librarySlot(before: next))
                                .contextMenu { SceneMenu(id: s.id) }
                                if project.expanded.contains(s.id) { SceneTreeView(scene: s.id).padding(.leading, 34).padding(.bottom, 4).transition(.opacity) }
                            }
                            .transition(Motion.appear)
                        }
                        SlotGap(target: .librarySlot(before: nil))
                    }
                    .animation(Motion.spring, value: ids)
                    .animation(Motion.spring, value: project.expanded)
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

    private func toggle(_ id: String) {
        if project.expanded.contains(id) { project.expanded.remove(id) } else { project.expanded.insert(id) }
    }

    private func draft() {
        guard settings.hasKey else { project.error = "Drafting needs an AI. Connect one in Settings, or write the scenes by hand: everything else works without it."; return }
        project.inspectorTab = .copilot
        chat.ask(prompt: Wizard.draftScenesPrompt)
    }
}

/// The items of the context menu of a scene, wherever the scene is shown (library row, frame of the reel).
struct SceneMenu: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        Button("Rename") { project.beginRename(id) }
        Button("Duplicate") { project.duplicateScene(id) }
        Divider()
        Button("Archive", role: .destructive) { project.archiveScene(id) }
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
                Image(systemName: "paintpalette.fill").font(.system(size: 9)).foregroundColor(.orange).padding(3)
                    .background(Color.orange.opacity(0.2), in: Circle())
                    .help("This scene replaces the project's " + groups.map { $0.rawValue }.joined(separator: ", "))
            }
        }
    }
}

struct SceneRowView: View {
    let scene: ShowreelFile.Scene
    let on: Bool
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 8) {
            SceneStateBadge(scene: scene)
            Text(scene.id).font(.callout.monospaced().weight(.semibold))
            VStack(alignment: .leading, spacing: 0) {
                InlineEdit(text: scene.name ?? "", placeholder: "Name this scene",
                           editing: Binding(get: { project.renaming == scene.id }, set: { if !$0, project.renaming == scene.id { project.renaming = nil } }),
                           commit: { project.renameScene(scene.id, $0) }) {
                    if let n = scene.name { Text(n).lineLimit(1).font(.callout.weight(.medium)) }
                    else { Text(scene.text.isEmpty ? "(no text)" : scene.text).lineLimit(1).font(.callout) }
                }
                Text((scene.name != nil && !scene.text.isEmpty ? scene.text + " \u{00B7} " : "") + scene.durationLabel).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            OverrideBadge(scene: scene)
            Spacer(minLength: 0)
        }
        .opacity(on ? 1 : 0.5)
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
                    TextField("Search", text: $search).textFieldStyle(.roundedBorder)
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
                    HStack { Text(e.name).font(.callout); Spacer(); if Look.isPreviewOnly(e.name) { chip("preview only") } else { Text(e.energy).font(.caption2).foregroundStyle(.secondary) } }
                }
            }
        }
    }

    /// A look element can be dragged onto what takes it (a background or a look onto a scene, an effect onto an item, a transition onto a marker).
    @ViewBuilder private func row<C: View>(_ kind: LookKind, _ id: String, @ViewBuilder _ content: @escaping () -> C) -> some View {
        let r = LibraryRow(selected: project.selection == .look(kind, id), action: { project.select(.look(kind, id)) }, content: content)
        if let item = DragItem.library(kind: kind.rawValue, id: id) {
            r.dragSource(item, label: id.hasPrefix("pack:") ? String(id.dropFirst(5)) : id, icon: kind == .transitions ? "arrow.left.arrow.right" : kind == .effects ? "sparkles" : kind == .backgrounds ? "rectangle.on.rectangle" : "paintpalette")
        } else { r }
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
        return [scene.id, "\(String(describing: scene.overrides))", scene.text, scene.texts.sorted { $0.key < $1.key }.map { $0.value }.joined(), (d?.palette ?? []).joined(), d?.fonts?.titles ?? "", d?.background?.id ?? "",
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
            ForEach(project.trees[scene] ?? []) { g in group(g) }
        }
        .animation(Motion.spring, value: project.trees[scene] ?? [])
    }

    /// A group of the tree. Clicking its title opens the matching tab of the scene's inspector; its nodes open it on that element.
    @ViewBuilder private func group(_ g: SceneGroupNodes) -> some View {
        Button { project.selectNode(scene, g.group, nil) } label: {
            HStack(spacing: 4) {
                Text(g.group.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                if g.group != .look && !g.nodes.isEmpty { Text("\(g.nodes.count)").font(.caption2).foregroundStyle(.tertiary) }
                if g.group == .look, let s = project.showreel?.scenes.first(where: { $0.id == scene }) { OverrideBadge(scene: s) }
                Spacer()
            }
            .padding(.top, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropTarget(.sceneNode(scene: scene, group: g.group, node: nil))
        if g.nodes.isEmpty {
            Text(g.group == .effects ? "none yet" : "nothing yet").font(.caption2).foregroundStyle(.tertiary).padding(.leading, 8)
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
                        Text(n.title).font(.caption).lineLimit(1).truncationMode(.middle)
                        Text(n.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    if let st = n.status { Text(st.rawValue).font(.caption2.weight(.semibold)).foregroundStyle(st.color) }
                    if let o = n.origin { Text(o.rawValue).font(.caption2).foregroundStyle(o == .overridden ? Color.orange : .secondary) }
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
