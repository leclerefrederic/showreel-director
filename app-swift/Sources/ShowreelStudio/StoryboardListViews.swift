import AppKit
import ShowreelKit
import SwiftUI

// The left panel: the Storyboard (the plan of the montage, a flat list) on top, the Resources browser below, one divider between them. The rules (the entries, the icons, the split)
// are ShowreelKit's `StoryboardList`, `SceneIcons` and `LibrarySplit`; this only draws them and relays the clicks.

struct LibraryPane: View {
    @EnvironmentObject var project: ProjectModel
    @State private var live: Double?
    @State private var dragStart: Double?
    private static let handle = 6.0

    var body: some View {
        VStack(spacing: 0) {
            if project.showreel == nil {
                Text("This project has no data yet. Confirm the import or create it with the banner above.").font(.callout).foregroundStyle(.secondary).padding(16)
                Spacer()
            } else {
                GeometryReader { geo in
                    let total = Double(geo.size.height) - Self.handle
                    let state = project.layout.resourcesState
                    let fraction = live ?? project.layout.splitFraction
                    let h = LibrarySplit.heights(total: total, fraction: fraction, state: state)
                    VStack(spacing: 0) {
                        StoryboardSection().frame(height: h.storyboard)
                        SplitHandle(vertical: false) { dy, ended in drag(total: total, storyboard: h.storyboard, dy: dy, ended: ended) }
                            .opacity(state == .open ? 1 : 0.35).allowsHitTesting(state == .open)
                            .help(state == .open ? "Drag to give more room to the Storyboard or to the Resources" : "Restore the Resources to move the divider")
                        ResourcesSection().frame(height: h.resources)
                    }
                }
            }
        }
        .panelBackground()
    }

    private func drag(total: Double, storyboard: Double, dy: CGFloat, ended: Bool) {
        if dragStart == nil { dragStart = storyboard }
        let f = LibrarySplit.fraction(total: total, storyboardHeight: dragStart ?? storyboard, moved: Double(dy))
        if ended { live = nil; dragStart = nil; project.setLibrarySplit(f) } else { live = f }
    }
}

/// The header of a section of the left panel.
private struct SectionHeader<Trailing: View>: View {
    let title: String
    let count: Int?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            if let n = count { Text("\(n)").fontSmall().foregroundStyle(.secondary) }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 10).frame(height: LibrarySplit.header)
        .background(Color.primary.opacity(0.05))
    }
}

struct ResourcesSection: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let state = project.layout.resourcesState
        VStack(spacing: 0) {
            SectionHeader(title: "Resources", count: project.assets.count) {
                if state != .collapsed {
                    Button { project.setResources(state == .expanded ? .open : .expanded) } label: { Image(systemName: state == .expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(.borderless).help(state == .expanded ? "Restore: the Storyboard comes back above the Resources" : "Expand: the Resources take the whole height of the panel")
                }
                Button { project.setResources(state == .collapsed ? .open : .collapsed) } label: { Image(systemName: state == .collapsed ? "chevron.up" : "chevron.down") }
                    .buttonStyle(.borderless).help(state == .collapsed ? "Open the Resources" : "Collapse the Resources to their header")
            }
            if state != .collapsed { ResourcesLibrary() }
        }
    }
}

struct StoryboardSection: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings
    @State private var showNotIn = true
    @State private var showLegend = false

    private var list: StoryboardList? { project.showreel.map { StoryboardList.build($0, store: project.store) } }

    var body: some View {
        let expanded = project.layout.resourcesState == .expanded
        VStack(spacing: 0) {
            SectionHeader(title: "Storyboard", count: list?.sceneIDs.count) {
                if expanded { Button("Restore") { project.setResources(.open) }.buttonStyle(.borderless).fontSmall().help("Bring the Storyboard back above the Resources") }
            }
            if !expanded, let l = list {
                HStack(spacing: 6) {
                    Button { project.addScene() } label: { Label("New", systemImage: "plus") }.help("Add a scene")
                    Button { draft() } label: { Label("Draft", systemImage: "sparkles") }.help("Optional. Clap proposes scenes as cards you accept or refuse.")
                    LockAllValidatedButton(short: true)
                    Spacer()
                    Button { showLegend.toggle() } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless).help("What the icons mean")
                        .popover(isPresented: $showLegend, arrowEdge: .bottom) { StatusLegend() }
                }
                .controlSize(.small).padding(.horizontal, 10).padding(.vertical, 6)
                if l.entries.isEmpty && l.notIn.isEmpty {
                    Text("No scene yet. Create one, or draft with the AI.").font(.callout).foregroundStyle(.secondary).padding(16)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView { entries(l) }
                            // a selection made on the strip or anywhere else brings its row into view
                            .onChange(of: project.selection.sceneID) { id in if let id { Motion.with(.select) { proxy.scrollTo("scene:" + id) } } }
                    }
                }
            } else if !expanded { Spacer() }
        }
        .onHover { project.listHovered = $0 }
        .background(ListKeys(project: project))
    }

    @ViewBuilder private func entries(_ l: StoryboardList) -> some View {
        VStack(spacing: 0) {
            ForEach(l.entries) { e in
                switch e {
                case .scene(let id):
                    if let s = project.showreel?.scenes.first(where: { $0.id == id }) { StoryboardSceneRow(scene: s, next: l.next(after: id)) }
                case .transition(let line):
                    TransitionLine(line: line)
                }
            }
            SlotGap(target: .reelSlot(before: nil))
            if !l.notIn.isEmpty { notIn(l.notIn) }
        }
        .animation(Motion.spring, value: l.entries.map { $0.id })
        .padding(.horizontal, 6)
    }

    private func notIn(_ rows: [StoryboardList.NotIn]) -> some View {
        DisclosureGroup("Not in the storyboard (\(rows.count))", isExpanded: $showNotIn) {
            ForEach(rows) { r in
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash").foregroundStyle(.secondary).frame(width: 14)
                    Text(r.id).font(.callout.monospaced())
                    Text(r.text).lineLimit(1).fontSmall().foregroundStyle(.secondary)
                    Spacer()
                    Button(r.wayBack) { project.setEnabled(r.id, true) }.buttonStyle(.borderless).fontSmall().help("Put the scene back in the storyboard, at the end")
                }
                .help(r.why)
                .dragSource(.scene(r.id), label: r.id, icon: "film")
            }
            Text("A hidden scene stays in the project. Drag one into the list to put it in the storyboard.").fontSmall().foregroundStyle(.secondary)
        }
        .font(.callout).padding(10)
    }

    private func draft() {
        guard settings.hasKey else { project.error = "Drafting needs an AI. Connect one in Settings, or write the scenes by hand: everything else works without it."; return }
        project.showClap()
        chat.ask(prompt: Wizard.draftScenesPrompt, status: "Scene draft requested")
    }
}

/// One scene of the storyboard, in fixed columns: the handle, the ID, the name with the first words under it, the duration, then Status (read-only), Visible (the eye) and Locked
/// (the lock). A click on the scene selects it everywhere (the strip, the inspector). The columns and the rules behind them are ShowreelKit's (`StoryboardList.row`, `SceneStatuses`, `SceneSwitches`).
struct StoryboardSceneRow: View {
    @EnvironmentObject var theme: Theme
    let scene: ShowreelFile.Scene
    let next: String?
    @EnvironmentObject var project: ProjectModel
    @State private var hovering = false
    @State private var refused = 0

    static let idWidth: CGFloat = 34, durationWidth: CGFloat = 42, iconWidth: CGFloat = 20

    var body: some View {
        let f = project.showreel
        let row = f.map { StoryboardList.row(scene, in: $0) }
        let selected = project.selection.sceneID == scene.id
        VStack(spacing: 0) {
            SlotGap(target: .reelSlot(before: scene.id))
            HStack(spacing: 4) {
                Handle()
                HStack(spacing: 6) {
                    Text(scene.id).font(.callout.monospaced().weight(.semibold)).frame(width: Self.idWidth, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        InlineEdit(text: scene.name ?? "", placeholder: "Name this scene",
                                   editing: Binding(get: { project.renaming == scene.id }, set: { if !$0, project.renaming == scene.id { project.renaming = nil } }),
                                   commit: { project.renameScene(scene.id, $0) }) {
                            Text(row?.title ?? scene.id).lineLimit(1).truncationMode(.tail).font(.callout.weight(scene.name == nil ? .regular : .medium))
                        }
                        if let sub = row?.subtitle, !sub.isEmpty { Text(sub).fontSmall().foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail) }
                    }
                    Spacer(minLength: 2)
                    Text(row?.duration ?? "").fontSmall(digits: true).foregroundStyle(.secondary).frame(width: Self.durationWidth, alignment: .trailing)
                }
                .contentShape(Rectangle())
                // the single click acts at once: a double-tap recognised first makes SwiftUI hold the single tap back for the double-click interval (PF1), so the rename is a simultaneous one
                .onTapGesture { project.focusScene(scene.id) }
                .simultaneousGesture(TapGesture(count: 2).onEnded { project.beginRename(scene.id) })
                SceneStatusIcon(scene: scene)
                switchButton(.eye)
                switchButton(.lock)
                BlockMarker(ref: .scene(scene.id))
            }
            .padding(.horizontal, 4).padding(.vertical, 4)
            .rowSurface(selected: selected, hovering: hovering)
            .onHover { hovering = $0 }
            .flashWhenChanged(.scene(scene.id))
            .temporaryVeil(.scene(scene.id))
            .dragSource(.scene(scene.id), label: scene.label, icon: "film")
            .dropTarget(.scene(scene.id))          // a resource dropped on a row goes to the scene
            .dropSlots(before: .reelSlot(before: scene.id), after: .reelSlot(before: next))
            .contextMenu { SceneMenu(id: scene.id) }
        }
        .arrives()
    }

    private enum Column { case eye, lock }

    /// The eye and the lock: a click flips the switch, a refusal says why (in the tooltip and in the status line) and how to get out of it.
    @ViewBuilder private func switchButton(_ c: Column) -> some View {
        if let f = project.showreel {
            let sw = c == .eye ? SceneSwitches.visible(scene, in: f, activity: project.activity) : SceneSwitches.locked(scene, activity: project.activity)
            let name = c == .eye ? "Visible" : "Locked"
            let symbol = c == .eye ? (sw.on ? "eye" : "eye.slash") : (sw.on ? "lock.fill" : "lock.open")
            let what = c == .eye ? (sw.on ? "In the film. Click to hide it." : "Hidden: not in the film. Click to show it.")
                                 : (sw.on ? "Locked: frozen in time and space. Click to unlock it (Undo brings the lock back)." : "Not locked. Click to lock it: nothing in it or before it can change.")
            Button { if sw.unavailable != nil { refused += 1 }; project.flip(sw) } label: {
                ToggleIcon(symbol: symbol, size: 12).frame(width: Self.iconWidth, height: Self.iconWidth)
                    .foregroundStyle(sw.on ? (c == .lock ? theme.lockOn : Color.primary) : Color.secondary.opacity(c == .lock ? 0.45 : 0.9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .nudge(trigger: refused)
            .opacity(sw.unavailable != nil ? 0.5 : 1)
            .help(sw.unavailable.map { "\(name): " + $0.message } ?? what)
            .accessibilityLabel(name + ": " + (sw.on ? "on" : "off"))
        }
    }
}

/// The thin line between two scenes, indented under the scene it leaves and joined to both by a vertical connector: a glyph, "Flip card \u{00B7} 0.55 s" or "Cut", and what the
/// marker says about itself. A click selects the marker on the strip and opens its inspector.
struct TransitionLine: View {
    @EnvironmentObject var theme: Theme
    let line: StoryboardList.TransitionLine
    @EnvironmentObject var project: ProjectModel
    @State private var hovering = false

    var body: some View {
        let selected = project.selection == .transition(line.from)
        HStack(spacing: 0) {
            Rectangle().fill(Color.secondary.opacity(0.45)).frame(width: 1).padding(.leading, 30)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: line.glyph).font(.system(size: 11)).foregroundStyle(line.isCut ? Color.secondary : Color.accentColor).frame(width: 14)
                    Text(line.text).fontSmall().foregroundStyle(.secondary).lineLimit(1)
                }
                ForEach(line.marks, id: \.self) { Text($0).fontSmall().foregroundStyle(theme.mark).padding(.leading, 19).lineLimit(2) }
            }
            .padding(.leading, 8).padding(.vertical, 2).padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowSurface(selected: selected, hovering: hovering)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { project.selectTransition(from: line.from) }
        .dropTarget(.marker(from: line.from))           // a transition of the Catalogue dropped on the line goes to that marker
        .help(project.transitionHelp(from: line.from, base: line.tooltip))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Select") { project.selectTransition(from: line.from) }
    }
}

/// The legend of the "?" button: the six Status states, then the eye and the lock.
struct StatusLegend: View {
    @EnvironmentObject var theme: Theme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What the icons mean").font(.headline)
            ForEach(Array(SceneStatuses.legend.enumerated()), id: \.offset) { n, e in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: e.symbol).foregroundStyle(n < SceneStatusKind.allCases.count ? theme.status(SceneStatusKind.allCases[n]) : theme.textPrimary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.title).font(.callout.weight(.semibold))
                        Text(e.meaning).fontSmall().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Text("The Status is the worst state that applies, top to bottom; its tooltip lists every state of the scene.").fontSmall().foregroundStyle(.secondary)
        }
        .padding(14).frame(width: 330)
    }
}

/// The arrow keys move from scene to scene and Delete switches the selected scene off (with Undo), while the pointer is over the Storyboard list and no text is being edited.
struct ListKeys: NSViewRepresentable {
    let project: ProjectModel

    final class Coordinator { var monitor: Any?; weak var project: ProjectModel? }
    func makeCoordinator() -> Coordinator { let c = Coordinator(); c.project = project; return c }

    func makeNSView(context: Context) -> NSView {
        let c = context.coordinator
        c.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak c] e in
            guard let p = c?.project, p.listHovered, e.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  !(NSApp.keyWindow?.firstResponder is NSText) else { return e }
            switch e.keyCode {
            case 125: p.stepScene(by: 1); return nil
            case 126: p.stepScene(by: -1); return nil
            case 51, 117: if let id = p.selection.sceneID { p.setEnabled(id, false); return nil }; return e
            default: return e
            }
        }
        return NSView()
    }

    func updateNSView(_ v: NSView, context: Context) { context.coordinator.project = project }
    static func dismantleNSView(_ v: NSView, coordinator: Coordinator) { if let m = coordinator.monitor { NSEvent.removeMonitor(m) } }
}

/// The badge of the top bar: how many checks are red or orange; a click opens the list in the centre.
struct ChecksBadge: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let v = CheckBadge.value(project.checkEntries)
        Button { project.centerMode = project.centerMode == .checks ? .viewer : .checks } label: {
            HStack(spacing: 4) {
                Image(systemName: v.tone == .clear ? "checkmark.seal" : "exclamationmark.triangle.fill")
                Text(v.label)
            }
            .foregroundStyle(v.tone == .problem ? theme.danger : v.tone == .attention ? theme.mark : Color.primary)
        }
        .help(v.help)
    }
}
