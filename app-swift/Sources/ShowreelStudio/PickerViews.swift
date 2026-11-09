import AppKit
import ShowreelKit
import SwiftUI

/// The catalogues of effects, scene transitions and backgrounds, as pickers where they are used: each choice is drawn by the engine in the
/// project's palette and font, and calls the typed operation of `Catalogue` (the same one a drag from the Catalogue palette makes).

/// A button that opens the picker of a catalogue. `none` is the way back to the default ("auto" for an animation, "cut" for a transition).
struct PickerButton: View {
    let kind: CatalogueKind
    let current: String
    var none: (id: String, label: String)?
    let onPick: (String) -> Void
    @State private var open = false

    private var label: String { current == none?.id ? (none?.label ?? current) : (current.isEmpty ? "Choose..." : current) }

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 4) { Text(label).lineLimit(1); Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)) }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            CataloguePicker(kind: kind, current: current, none: none) { open = false; onPick($0) }
        }
    }
}

struct CataloguePicker: View {
    let kind: CatalogueKind
    let current: String
    var none: (id: String, label: String)?
    let onPick: (String) -> Void
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var search = ""
    @State private var group = "All"

    private var all: [CatalogueChoice] { Catalogue.choices(kind) }

    var body: some View {
        let ctx = LookContext(project)
        let groups = ["All"] + Array(Set(all.map { $0.group }.filter { !$0.isEmpty })).sorted()
        let shown = all.filter { (group == "All" || $0.group == group) && (search.isEmpty || $0.id.localizedCaseInsensitiveContains(search)) }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(kind.title).font(.headline)
                TextField("Search", text: $search).textFieldStyle(.roundedBorder)
                if groups.count > 2 { Picker("", selection: $group) { ForEach(groups, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(maxWidth: 150) }
            }
            if kind == .background, !ctx.hasPalette { Text("Drawn in a neutral palette until you choose yours.").fontSmall().foregroundStyle(.secondary) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)], spacing: 10) {
                    if let n = none {
                        tile(title: n.label, chip: nil, thumb: nil, chosen: current == n.id, enabled: true, help: "") { onPick(n.id) }
                    }
                    ForEach(shown) { c in
                        tile(title: kind == .background ? (engine.catalogue?.backgrounds.first { $0.id == c.id }?.name ?? c.id) : c.id,
                             chip: c.selectable ? (c.group.isEmpty ? nil : c.group) : "preview only",
                             thumb: thumb(c, ctx), chosen: current == c.id, enabled: c.selectable, help: c.reason ?? c.detail) { onPick(c.id) }
                    }
                }
                .padding(2)
            }
        }
        .padding(12).frame(width: 520, height: 460)
        .task { await engine.start() }
    }

    @ViewBuilder private func tile(title: String, chip: String?, thumb: AnyView?, chosen: Bool, enabled: Bool, help: String, _ pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            VStack(alignment: .leading, spacing: 4) {
                if let t = thumb { t } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)).aspectRatio(16 / 9, contentMode: .fit)
                        .overlay(Image(systemName: "xmark").foregroundStyle(.secondary))
                }
                HStack(spacing: 4) {
                    Text(title).font(.callout.weight(.semibold)).lineLimit(1)
                    if let c = chip { Text(c).fontSmall().padding(.horizontal, 5).background((enabled ? Color.primary : Color.orange).opacity(0.12), in: Capsule()).lineLimit(1) }
                    Spacer(minLength: 0)
                    if chosen { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                }
            }
            .padding(6).frame(maxWidth: .infinity, alignment: .leading)
            .background(chosen ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(chosen ? Color.accentColor : Color.clear, lineWidth: 2))
            .opacity(enabled ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled).help(help)
    }

    private func thumb(_ c: CatalogueChoice, _ ctx: LookContext) -> AnyView {
        let store = project.store, engine = self.engine
        switch kind {
        case .effect, .transition:
            return AnyView(EngineThumb(token: "pk" + c.id + ctx.palette.signature + ctx.titleFont) { await engine.effectFrames(c.id, palette: ctx.palette, font: ctx.titleFont, store: store, text: ctx.text) })
        case .background:
            return AnyView(EngineThumb(token: "pb" + c.id + ctx.palette.signature + (ctx.mood ?? "")) { await engine.backgroundFrames(c.id, mood: ctx.mood, palette: ctx.palette, store: store) })
        }
    }
}

/// The floating Catalogue: a small card over the workspace, optional, that keeps every look element as something to drag onto a scene, an
/// item or a marker. It holds no setting: choosing for the whole project is in the project settings.
struct CataloguePalette: View {
    @EnvironmentObject var project: ProjectModel
    @State private var offset = CGSize(width: 24, height: 24)
    @State private var start: CGSize?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "square.grid.2x2")
                Text("Catalogue").font(.headline)
                Spacer()
                Text("drag onto a scene, an item or a marker").fontSmall().foregroundStyle(.secondary).lineLimit(1)
                Button { project.showCatalogue = false } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless).help("Close the Catalogue")
            }
            .padding(.horizontal, 10).padding(.vertical, 7).background(.bar)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { v in if start == nil { start = offset }; offset = CGSize(width: (start?.width ?? 0) + v.translation.width, height: (start?.height ?? 0) + v.translation.height) }
                .onEnded { _ in start = nil })
            Divider()
            LookLibrary(kinds: [.looks, .palettes, .backgrounds, .effects, .transitions])
        }
        .frame(width: 310, height: 440)
        .raisedBackground()
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.18)))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 4)
        .offset(offset)
        .onExitCommand { project.showCatalogue = false }
    }
}
