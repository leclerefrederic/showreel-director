import AppKit
import CoreText
import ShowreelKit
import SwiftUI

// MARK: shared pieces

extension Color {
    init(hex: String) {
        let c = EnginePalette.rgb(EnginePalette.isHex(hex) ? hex : "#808080")
        self.init(.sRGB, red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255, opacity: 1)
    }
    var hexString: String {
        let n = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(format: "#%02X%02X%02X", Int((n.redComponent * 255).rounded()), Int((n.greenComponent * 255).rounded()), Int((n.blueComponent * 255).rounded()))
    }
}

/// A thumbnail that plays the frames the engine drew.
struct AnimatedThumb: View {
    let frames: [NSImage]
    var failure: String?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.06))
            if frames.isEmpty {
                if let f = failure { Text(f).font(.caption2).foregroundStyle(.secondary).padding(6) } else { ProgressView().controlSize(.small) }
            } else {
                TimelineView(.periodic(from: .now, by: 0.12)) { ctx in
                    Image(nsImage: frames[Int(ctx.date.timeIntervalSinceReferenceDate / 0.12) % frames.count]).resizable().scaledToFit()
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Loads its frames from the engine when it appears, and again when `token` changes (a new palette or font).
struct EngineThumb: View {
    let token: String
    let load: () async -> [NSImage]
    @ObservedObject private var engine = EngineService.shared
    @State private var frames: [NSImage] = []

    var body: some View {
        AnimatedThumb(frames: frames, failure: engine.failure).task(id: token) { frames = await load() }
    }
}

/// Fonts registered with CoreText so that SwiftUI draws real samples. The previews are woff2 files in the skill folder inside the app.
@MainActor
final class FontRegistry {
    static let shared = FontRegistry()
    private var families: [String: String] = [:]
    private var done = false

    func registerAll() {
        guard !done else { return }
        done = true
        for f in Look.freeFonts() { if let u = Look.previewURL(for: f) { families[f.name] = register(u) ?? f.name } }
    }

    @discardableResult
    func register(_ url: URL) -> String? {
        let d = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        var err: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)   // already registered is fine
        return d?.first.flatMap { CTFontDescriptorCopyAttribute($0, kCTFontFamilyNameAttribute) as? String }
    }

    func family(_ name: String) -> String { families[name] ?? name }
}

/// What a font's licence means for the film, as a coloured line.
struct LicenceBadge: View {
    let assessment: FontLicense.Assessment
    var body: some View {
        Label(assessment.message, systemImage: assessment.level == .ok ? "checkmark.seal.fill" : assessment.level == .fail ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(assessment.level == .ok ? Color.green : assessment.level == .fail ? .red : .orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Project facts the pickers use to draw their previews.
struct LookContext {
    let palette: EnginePalette
    let hasPalette: Bool
    let titleFont: String
    let text: String
    let mood: String?

    @MainActor init(_ p: ProjectModel) {
        let d = p.showreel?.decisions
        palette = EnginePalette(stored: d?.palette)
        hasPalette = (d?.palette?.count ?? 0) >= 2
        titleFont = d?.fonts?.titles ?? ""
        let m = (p.showreel?.parameters.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        text = m.isEmpty ? "Simple. Fast. Yours." : String(m.prefix(40))
        mood = d?.background?.mood
    }
}

struct Swatches: View {
    let colours: [String]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(colours.enumerated()), id: \.offset) { _, c in
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: c)).frame(width: 22, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.2)))
            }
        }
    }
}

// MARK: look board

/// Three complete looks to compare, drawn by the engine. Choosing one records its palette, fonts, background and moods.
struct LookBoardView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var offset = 0

    var body: some View {
        let tone = project.showreel?.parameters.tone
        let packages = LookPackages.three(tone: tone, offset: offset)
        let ctx = LookContext(project)
        VStack(alignment: .leading, spacing: 12) {
            Text("Starting points, not defaults: none is chosen until you click. After choosing, each part can still be changed.").font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 14) {
                ForEach(packages) { p in card(p, ctx, recommended: LookPackages.matches(p, tone: tone)) }
            }
            Button("Show other looks") { offset += 1 }.disabled(LookPackages.all().count <= 3)
        }
    }

    private func isChosen(_ p: LookPackage) -> Bool {
        guard let d = project.showreel?.decisions else { return false }
        return d.palette == p.palette.map { $0.uppercased() } && d.background?.id == p.background && d.fonts?.titles == p.fonts.titles && d.effectsPack == p.pack
    }

    private func card(_ p: LookPackage, _ ctx: LookContext, recommended: Bool) -> some View {
        let effect = Look.packs().first { $0.name == p.pack }?.effects.first { n in engine.catalogue?.effects.contains { $0.name == n } ?? true } ?? "Fade"
        let pal = EnginePalette(stored: p.palette)
        return VStack(alignment: .leading, spacing: 8) {
            EngineThumb(token: p.id + ctx.text) {
                await engine.lookFrames(background: p.background, mood: Look.mood(forPack: p.pack), effect: effect, palette: pal, font: p.fonts.titles ?? "", store: project.store, text: ctx.text)
            }
            HStack {
                Text(p.name).font(.headline)
                if recommended { Text("Fits your tone").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 1).background(Color.accentColor.opacity(0.18), in: Capsule()) }
            }
            Text(p.why).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Swatches(colours: p.palette)
            Text("\(p.fonts.titles ?? "") + \(p.fonts.text ?? "") · \(p.pack) · \(p.background)").font(.caption2).foregroundStyle(.secondary)
            if isChosen(p) {
                Label("Chosen", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
            } else {
                Button("Choose this look") { project.perform(.decisions(p.decisions, title: "Choose the look: \(p.name)")) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isChosen(p) ? Color.green : Color.primary.opacity(0.08), lineWidth: isChosen(p) ? 2 : 1))
    }
}

// MARK: palette

struct PaletteEditor: View {
    var compact = false
    @EnvironmentObject var project: ProjectModel
    @State private var draft: [String] = ["#101820", "#FFFFFF", "#F2AA4C"]
    @State private var loaded: [String]?
    @State private var still: NSImage?
    private static let roles = ["Background", "Text", "Accent", "Accent 2"]

    private var saved: [String] { project.showreel?.decisions.palette ?? [] }
    private var dirty: Bool { draft != saved }

    var body: some View {
        let layout = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        layout {
            VStack(alignment: .leading, spacing: 12) {
                Text(saved.isEmpty ? "These are starting colours: nothing is saved until you press Save." : "The saved palette. Change a colour, then Save.")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(draft.indices, id: \.self) { i in
                    HStack {
                        Text(i < Self.roles.count ? Self.roles[i] : "Extra").frame(width: 100, alignment: .leading)
                        ColorPicker("", selection: Binding(get: { Color(hex: draft[i]) }, set: { draft[i] = $0.hexString }), supportsOpacity: false).labelsHidden()
                        Text(draft[i]).font(.callout.monospaced()).foregroundStyle(.secondary)
                        if i == 3 { Button { draft.remove(at: 3) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).help("Remove accent 2") }
                    }
                }
                if draft.count < 4 { Button { draft.append(draft.last ?? "#F2AA4C") } label: { Label("Add accent 2", systemImage: "plus") }.buttonStyle(.borderless) }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Contrast.checks(draft)) { r in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: r.level.symbol).foregroundStyle(r.level.color)
                            VStack(alignment: .leading, spacing: 0) { Text(r.title).font(.callout.weight(.medium)); Text(r.detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                HStack {
                    Button("Save palette") { project.perform(.decisions([DecisionChange(.palette, draft.joined(separator: ", "))], title: nil)) }
                        .buttonStyle(.borderedProminent).disabled(!dirty || draft.count < 2)
                    Button("Revert") { draft = saved.isEmpty ? ["#101820", "#FFFFFF", "#F2AA4C"] : saved }.disabled(!dirty)
                }
            }
            .frame(maxWidth: compact ? .infinity : 380, alignment: .leading)
            VStack {
                if let img = still { Image(nsImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 10)) }
                else { Rectangle().fill(Color.primary.opacity(0.06)).aspectRatio(16 / 9, contentMode: .fit).overlay(ProgressView()) }
                Text("A frame of the film's engine in these colours.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { if loaded == nil { loaded = saved; if !saved.isEmpty { draft = saved } } }
        .onChange(of: project.showreel?.decisions.palette) { p in if let p = p, !dirty || draft == loaded { draft = p; loaded = p } }
        .task(id: draft.joined()) {
            try? await Task.sleep(nanoseconds: 250_000_000)   // let a colour drag settle
            let ctx = LookContext(project)
            still = await EngineService.shared.still(effect: "Pop", palette: EnginePalette(stored: draft), font: ctx.titleFont, store: project.store, t: 0.9)
        }
    }
}

// MARK: fonts

struct FontPickerView: View {
    let roles: [DecisionKey]
    @EnvironmentObject var project: ProjectModel
    @State private var search = ""
    @State private var cat = "All"
    private let fonts = Look.freeFonts()

    var body: some View {
        let f = project.showreel
        let ctx = LookContext(project)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(roles, id: \.self) { role in
                let name = f.map { role.current($0) } ?? ""
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(role.title): \(name.isEmpty ? "not chosen yet" : name)").font(.headline)
                    if !name.isEmpty { LicenceBadge(assessment: FontLicense.assess(name: name, assets: project.assets, store: project.store)) }
                }
            }
            HStack {
                TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                Picker("", selection: $cat) { ForEach(["All"] + Array(Set(fonts.map { $0.cat })).sorted(), id: \.self) { Text($0).tag($0) } }
                    .labelsHidden().frame(maxWidth: 160)
            }
            let mine = project.assets.filter { $0.type == "font" && $0.status != "excluded" }
            if !mine.isEmpty {
                Text("Your fonts").font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(mine) { a in yourFont(a, ctx) }
                }
            }
            Text("Free fonts").font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(fonts.filter { (cat == "All" || $0.cat == cat) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }) { font in
                    freeFont(font, ctx)
                }
            }
        }
        .onAppear { FontRegistry.shared.registerAll() }
    }

    private func buttons(_ name: String) -> some View {
        HStack {
            ForEach(roles, id: \.self) { role in
                let on = project.showreel.map { role.current($0) == name } ?? false
                Button(roles.count == 1 ? (on ? "Chosen" : "Use this font") : (role == .titleFont ? "Titles" : "Text")) {
                    project.perform(.decisions([DecisionChange(role, name)], title: nil))
                }
                .buttonStyle(.bordered).tint(on ? .green : nil).disabled(on)
            }
        }
    }

    private func freeFont(_ f: Look.Font, _ ctx: LookContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ctx.text).font(.custom(FontRegistry.shared.family(f.name), size: 24)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            HStack { Text(f.name).font(.callout.weight(.semibold)); Text(f.cat).font(.caption2).padding(.horizontal, 5).background(Color.primary.opacity(0.08), in: Capsule()) }
            Text(f.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            buttons(f.name)
        }
        .padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func yourFont(_ a: AssetRow, _ ctx: LookContext) -> some View {
        let url = project.root.appendingPathComponent("assets/" + (a.file.isEmpty ? "source/" + a.original : a.file))
        let family = FontRegistry.shared.register(url) ?? (a.name as NSString).deletingPathExtension
        let verdict = FontLicense.assess(name: family, assets: project.assets, store: project.store)
        return VStack(alignment: .leading, spacing: 6) {
            Text(ctx.text).font(.custom(family, size: 24)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            Text(family).font(.callout.weight(.semibold))
            LicenceBadge(assessment: verdict)
            buttons(family)
        }
        .padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: background

struct BackgroundPickerView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var family = "All"
    @State private var mood = ""

    var body: some View {
        let ctx = LookContext(project)
        let list = engine.catalogue?.backgrounds ?? []
        let chosen = project.showreel?.decisions.background?.id ?? ""
        VStack(alignment: .leading, spacing: 12) {
            if !ctx.hasPalette { Text("Drawn in a neutral palette until you choose yours.").font(.caption).foregroundStyle(.secondary) }
            HStack {
                Picker("Family", selection: $family) { ForEach(["All"] + Array(Set(list.map { $0.family })).sorted(), id: \.self) { Text($0).tag($0) } }.frame(maxWidth: 220)
                Picker("Reacts to music like", selection: $mood) {
                    Text("Calm (no reaction)").tag("")
                    ForEach(Look.backgroundMoods(), id: \.self) { Text($0.capitalized).tag($0) }
                }.frame(maxWidth: 300)
            }
            Text("The mood only changes how animated backgrounds breathe with a track. It is saved with the background.").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(list.filter { family == "All" || $0.family == family }) { b in
                    VStack(alignment: .leading, spacing: 6) {
                        EngineThumb(token: b.id + ctx.palette.signature + mood) { await engine.backgroundFrames(b.id, mood: mood, palette: ctx.palette, store: project.store) }
                        HStack { Text(b.name).font(.callout.weight(.semibold)); Text(b.animated ? "Animated" : b.family).font(.caption2).padding(.horizontal, 5).background(Color.primary.opacity(0.08), in: Capsule()) }
                        Text(b.desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Button(chosen == b.id ? "Chosen" : "Use this background") {
                            project.perform(.decisions([DecisionChange(.background, b.id), DecisionChange(.backgroundMood, mood)], title: "Set background: \(b.name)"))
                        }
                        .buttonStyle(.bordered).tint(chosen == b.id ? .green : nil)
                    }
                    .padding(10).background(Color.primary.opacity(chosen == b.id ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .task { await engine.start(); mood = project.showreel?.decisions.background?.mood ?? "" }
    }
}

// MARK: moods and effects

struct MoodsPickerView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var selected: [String] = []

    var body: some View {
        let ctx = LookContext(project)
        let saved = project.showreel?.decisions.moods ?? []
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick one or two moods. Each is a coherent set of motion; you will see its effects next.").font(.callout).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(Look.packs()) { p in
                    let on = selected.contains(p.name)
                    Button {
                        if on { selected.removeAll { $0 == p.name } } else if selected.count < 2 { selected.append(p.name) } else { selected = [selected[1], p.name] }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            if let first = p.effects.first(where: { n in engine.catalogue?.effects.contains { $0.name == n } ?? true }) {
                                EngineThumb(token: first + ctx.palette.signature + ctx.titleFont) { await engine.effectFrames(first, palette: ctx.palette, font: ctx.titleFont, store: project.store, text: ctx.text) }
                            }
                            HStack { Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(on ? Color.accentColor : .secondary); Text(p.name).font(.headline) }
                            Text(p.feel).font(.caption).foregroundStyle(.secondary)
                            Text(p.effects.joined(separator: " · ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(on ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Button("Use these moods") { project.perform(.decisions([DecisionChange(.moods, selected.joined(separator: ", "))], title: nil)) }
                    .buttonStyle(.borderedProminent).disabled(selected.isEmpty || selected == saved)
                if !saved.isEmpty && selected == saved { Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }
        }
        .onAppear { selected = saved }
        .task { await engine.start() }
    }
}

struct EffectsPickerView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var pack = ""
    @State private var all = false
    @State private var search = ""
    @State private var cat = "All"

    var body: some View {
        let ctx = LookContext(project)
        let packs = Look.packs()
        let saved = project.showreel?.decisions.effectsPack ?? ""
        let current = packs.first { $0.name == pack }
        let list = engine.catalogue?.effects ?? []
        let shown: [EngineEffect] = all
            ? list.filter { (cat == "All" || $0.cat == cat) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
            : (current?.effects ?? []).compactMap { n in list.first { $0.name == n } }
        VStack(alignment: .leading, spacing: 12) {
            Picker("Pack", selection: $pack) {
                ForEach(packs) { p in Text(p.name + ((project.showreel?.decisions.moods ?? []).contains(p.name) ? "  (your mood)" : "")).tag(p.name) }
            }.frame(maxWidth: 360)
            if let c = current { Text(c.feel).font(.callout).foregroundStyle(.secondary) }
            HStack {
                Button(saved == pack ? "Chosen" : "Use \(pack) as the effects pack") {
                    project.perform(.decisions([DecisionChange(.effectsPack, pack)], title: nil))
                }.buttonStyle(.borderedProminent).disabled(saved == pack || pack.isEmpty)
                Toggle("Browse every effect", isOn: $all).toggleStyle(.checkbox)
                if all {
                    TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                    Picker("", selection: $cat) { ForEach(["All"] + Array(Set(list.map { $0.cat })).sorted(), id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(maxWidth: 160)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(shown) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        EngineThumb(token: e.name + ctx.palette.signature + ctx.titleFont) { await engine.effectFrames(e.name, palette: ctx.palette, font: ctx.titleFont, store: project.store, text: ctx.text) }
                        HStack { Text(e.name).font(.callout.weight(.semibold)); Text(e.energy).font(.caption2).padding(.horizontal, 5).background(Color.primary.opacity(0.08), in: Capsule()) }
                        Text(e.desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .onAppear { if pack.isEmpty { pack = !saved.isEmpty ? saved : (project.showreel?.decisions.moods?.first ?? packs.first?.name ?? "") } }
        .task { await engine.start() }
    }
}
