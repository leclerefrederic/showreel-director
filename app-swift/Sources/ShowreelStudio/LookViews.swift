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

// MARK: the layout of a look editor

/// A look editor: the current choice is a large card pinned at the top while the options scroll under it; the options are a library below and never repeat
/// the current choice. Choosing swaps the card with a soft transition (not at all with "Reduce motion"). `key` names the current choice: when it changes, the card swaps.
struct PinnedChoices<Pinned: View, Options: View>: View {
    let key: String
    var optionsTitle = "Other options"
    @ViewBuilder let pinned: () -> Pinned
    @ViewBuilder let options: () -> Options

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
            Section {
                Text(optionsTitle).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                options()
            } header: {
                pinned()
                    .id(key).transition(Motion.appear)
                    .padding(.bottom, 8).background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .animation(Motion.spring, value: key)
    }
}

/// The big card of a current choice: a label, a frame of the film's engine, what it is.
struct CurrentCard<Content: View>: View {
    var label = "Current choice"
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Color.accentColor)
            content()
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.accentColor, lineWidth: 2))
    }
}

private let optionColumns = [GridItem(.adaptive(minimum: 200), spacing: 12, alignment: .top)]

private func optionBox<C: View>(@ViewBuilder _ c: () -> C) -> some View {
    c().padding(10).frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
}

private func chip(_ t: String) -> some View {
    Text(t).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 1).background(Color.accentColor.opacity(0.18), in: Capsule())
}

// MARK: look board

/// The starting looks. The look the project has chosen is the card at the top; the other looks form the library below it.
struct LookBoardView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared

    var body: some View {
        let tone = project.showreel?.parameters.tone
        let ctx = LookContext(project)
        // looks that fit the tone come first: a recommendation, never a pre-selection
        let all = LookPackages.all(), fits = all.filter { LookPackages.matches($0, tone: tone) }, rest = all.filter { !LookPackages.matches($0, tone: tone) }
        let part = LookChoices.split(fits + rest, id: { $0.id }, current: project.showreel.flatMap { LookChoices.currentLook($0) })
        PinnedChoices(key: part.current?.id ?? "own-look", optionsTitle: "Starting points, not defaults: none changes anything until you choose it") {
            CurrentCard(label: part.current == nil ? "Your own look" : "Current look") { current(part.current, ctx) }
        } options: {
            LazyVGrid(columns: optionColumns, spacing: 12) {
                ForEach(part.others) { p in card(p, ctx, recommended: LookPackages.matches(p, tone: tone)) }
            }
        }
    }

    @ViewBuilder private func current(_ p: LookPackage?, _ ctx: LookContext) -> some View {
        if let p = p {
            preview(p, ctx).frame(maxWidth: 440)
            HStack { Text(p.name).font(.title3.weight(.semibold)); Label("Chosen", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout) }
            Text(p.why).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Swatches(colours: p.palette)
            Text("\(p.fonts.titles ?? "") + \(p.fonts.text ?? "") \u{00B7} \(p.pack) \u{00B7} \(p.background)").font(.caption).foregroundStyle(.secondary)
        } else if let f = project.showreel, f.decisions.palette != nil || f.decisions.background != nil {
            let d = f.decisions
            Text("A mix of your own choices: not one of the starting looks.").font(.callout).foregroundStyle(.secondary)
            if let pal = d.palette, !pal.isEmpty { Swatches(colours: pal) }
            Text([d.fonts?.titles, d.fonts?.text, d.background?.id, d.effectsPack].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")).font(.caption).foregroundStyle(.secondary)
        } else {
            Text("No look chosen yet. Pick a starting point below, or choose the palette, fonts and background one by one.").font(.callout).foregroundStyle(.secondary)
        }
    }

    private func preview(_ p: LookPackage, _ ctx: LookContext) -> some View {
        let effect = Look.packs().first { $0.name == p.pack }?.effects.first { n in engine.catalogue?.effects.contains { $0.name == n } ?? true } ?? "Fade"
        let pal = EnginePalette(stored: p.palette)
        return EngineThumb(token: p.id + ctx.text) {
            await engine.lookFrames(background: p.background, mood: Look.mood(forPack: p.pack), effect: effect, palette: pal, font: p.fonts.titles ?? "", store: project.store, text: ctx.text)
        }
    }

    private func card(_ p: LookPackage, _ ctx: LookContext, recommended: Bool) -> some View {
        optionBox {
            VStack(alignment: .leading, spacing: 8) {
                preview(p, ctx)
                HStack { Text(p.name).font(.headline); if recommended { chip("Fits your tone") } }
                Text(p.why).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Swatches(colours: p.palette)
                Text("\(p.fonts.titles ?? "") + \(p.fonts.text ?? "") \u{00B7} \(p.pack) \u{00B7} \(p.background)").font(.caption2).foregroundStyle(.secondary)
                Button("Choose this look") { project.perform(.decisions(p.decisions, title: "Choose the look: \(p.name)")) }.buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: palette

/// The palette. The saved one is the card at the top, with a frame of the engine in its colours; the colours can be edited under it, and the palettes of the
/// starting looks (the one the project has already is not repeated) are the library.
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
        let part = LookChoices.split(LookPackages.all(), id: { $0.id }, current: project.showreel.flatMap { LookChoices.currentPalette($0) })
        PinnedChoices(key: saved.joined(separator: ","), optionsTitle: "Palettes of the starting looks") {
            CurrentCard(label: saved.isEmpty ? "No palette yet" : (part.current.map { "Current palette \u{00B7} \($0.name)" } ?? "Current palette")) {
                HStack(alignment: .top, spacing: 14) {
                    if let img = still { Image(nsImage: img).resizable().scaledToFit().frame(maxWidth: 280).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    else { Rectangle().fill(Color.primary.opacity(0.06)).aspectRatio(16 / 9, contentMode: .fit).frame(maxWidth: 280).overlay(ProgressView()).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    VStack(alignment: .leading, spacing: 6) {
                        if saved.isEmpty { Text("Choose a palette below, or edit the starting colours.").font(.callout).foregroundStyle(.secondary) }
                        ForEach(Array(saved.enumerated()), id: \.offset) { i, hex in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 5).fill(Color(hex: hex)).frame(width: 26, height: 26).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.2)))
                                Text(i < Self.roles.count ? Self.roles[i] : "Extra").font(.callout.weight(.medium))
                                Text(hex).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } options: {
            VStack(alignment: .leading, spacing: 14) {
                editor
                LazyVGrid(columns: optionColumns, spacing: 12) {
                    ForEach(part.others) { p in
                        optionBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(p.name).font(.callout.weight(.semibold))
                                Swatches(colours: p.palette)
                                Button("Use this palette") { project.perform(.decisions([DecisionChange(.palette, p.palette.joined(separator: ", "))], title: "Use the \(p.name) palette")) }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { if loaded == nil { loaded = saved; if !saved.isEmpty { draft = saved } } }
        .onChange(of: project.showreel?.decisions.palette) { p in if let p = p, !dirty || draft == loaded { draft = p; loaded = p } }
        .task(id: saved.joined()) {
            let ctx = LookContext(project)
            still = await EngineService.shared.still(effect: "Pop", palette: EnginePalette(stored: saved.isEmpty ? nil : saved), font: ctx.titleFont, store: project.store, t: 0.9)
        }
    }

    /// Edit the colours one by one, with the contrast checks as they change.
    private var editor: some View {
        optionBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Edit the colours").font(.callout.weight(.semibold))
                Text(saved.isEmpty ? "These are starting colours: nothing is saved until you press Save." : "Change a colour, then Save.").font(.caption).foregroundStyle(.secondary)
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
        }
    }
}

// MARK: fonts

/// The fonts. The titles font and the text font are the cards at the top; the fonts that are not chosen are the library below.
struct FontPickerView: View {
    let roles: [DecisionKey]
    @EnvironmentObject var project: ProjectModel
    @State private var search = ""
    @State private var cat = "All"
    private let fonts = Look.freeFonts()

    private func chosen(_ role: DecisionKey) -> String { project.showreel.map { role.current($0) } ?? "" }

    var body: some View {
        let ctx = LookContext(project)
        let names = roles.map { chosen($0) }.filter { !$0.isEmpty }
        let mine = project.assets.filter { $0.type == "font" && $0.status != "excluded" }
        let free = fonts.filter { !names.contains($0.name) && (cat == "All" || $0.cat == cat) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
        PinnedChoices(key: names.joined(separator: "|") + "|" + roles.map { $0.rawValue }.joined(), optionsTitle: "Other fonts") {
            VStack(spacing: 8) { ForEach(roles, id: \.self) { role in CurrentCard(label: role == .titleFont ? "Titles font" : role == .textFont ? "Text font" : "Font") { specimen(role, ctx) } } }
        } options: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                    Picker("", selection: $cat) { ForEach(["All"] + Array(Set(fonts.map { $0.cat })).sorted(), id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(maxWidth: 160)
                }
                let others = mine.filter { a in !names.contains(FontRegistry.shared.register(fontURL(a)) ?? (a.name as NSString).deletingPathExtension) }
                if !others.isEmpty {
                    Text("Your fonts").font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: optionColumns, spacing: 12) { ForEach(others) { a in yourFont(a, ctx) } }
                }
                Text("Free fonts").font(.subheadline.weight(.semibold))
                LazyVGrid(columns: optionColumns, spacing: 12) { ForEach(free) { f in freeFont(f, ctx) } }
            }
        }
        .onAppear { FontRegistry.shared.registerAll() }
    }

    private func fontURL(_ a: AssetRow) -> URL { project.root.appendingPathComponent("assets/" + (a.file.isEmpty ? "source/" + a.original : a.file)) }

    private func specimen(_ role: DecisionKey, _ ctx: LookContext) -> some View {
        let name = chosen(role)
        return VStack(alignment: .leading, spacing: 6) {
            if name.isEmpty { Text("Not chosen yet: pick one below.").font(.callout).foregroundStyle(.secondary) }
            else {
                Text(ctx.text).font(.custom(FontRegistry.shared.family(name), size: 30)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Text(name).font(.callout.weight(.semibold))
                LicenceBadge(assessment: FontLicense.assess(name: name, assets: project.assets, store: project.store))
            }
        }
    }

    private func buttons(_ name: String) -> some View {
        HStack {
            ForEach(roles, id: \.self) { role in
                Button(roles.count == 1 ? "Use this font" : (role == .titleFont ? "Use for titles" : "Use for text")) {
                    project.perform(.decisions([DecisionChange(role, name)], title: nil))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func freeFont(_ f: Look.Font, _ ctx: LookContext) -> some View {
        optionBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(ctx.text).font(.custom(FontRegistry.shared.family(f.name), size: 22)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                HStack { Text(f.name).font(.callout.weight(.semibold)); Text(f.cat).font(.caption2).padding(.horizontal, 5).background(Color.primary.opacity(0.08), in: Capsule()) }
                Text(f.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                buttons(f.name)
            }
        }
    }

    private func yourFont(_ a: AssetRow, _ ctx: LookContext) -> some View {
        let family = FontRegistry.shared.register(fontURL(a)) ?? (a.name as NSString).deletingPathExtension
        let verdict = FontLicense.assess(name: family, assets: project.assets, store: project.store)
        return optionBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(ctx.text).font(.custom(family, size: 22)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                Text(family).font(.callout.weight(.semibold))
                LicenceBadge(assessment: verdict)
                buttons(family)
            }
        }
    }
}

// MARK: background

/// The default background. The chosen one runs live in the card at the top, with the way it reacts to music; the other backgrounds are the library.
struct BackgroundPickerView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var family = "All"
    @State private var mood = ""

    var body: some View {
        let ctx = LookContext(project)
        let list = engine.catalogue?.backgrounds ?? []
        let chosen = project.showreel?.decisions.background?.id ?? ""
        let part = LookChoices.split(list, id: { $0.id }, current: chosen)
        PinnedChoices(key: chosen, optionsTitle: "Other backgrounds") {
            CurrentCard(label: chosen.isEmpty ? "No background yet" : "Current background") {
                if let b = part.current {
                    EngineThumb(token: "bc" + b.id + ctx.palette.signature + mood) { await engine.backgroundFrames(b.id, mood: mood, palette: ctx.palette, store: project.store, size: EngineService.viewerSize) }.frame(maxWidth: 440)
                    HStack { Text(b.name).font(.title3.weight(.semibold)); chip(b.animated ? "Animated" : b.family) }
                    Text(b.desc).font(.callout).foregroundStyle(.secondary)
                } else { Text("Pick a background below: the film starts on the palette's background colour until then.").font(.callout).foregroundStyle(.secondary) }
                Picker("Reacts to music like", selection: Binding(get: { mood }, set: { m in
                    mood = m
                    if !chosen.isEmpty { project.perform(.decisions([DecisionChange(.background, chosen), DecisionChange(.backgroundMood, m)], title: "Set background: \(part.current?.name ?? chosen)")) }
                })) {
                    Text("Calm (no reaction)").tag("")
                    ForEach(Look.backgroundMoods(), id: \.self) { Text($0.capitalized).tag($0) }
                }.frame(maxWidth: 320)
                Text("The mood only changes how animated backgrounds breathe with a track. It is saved with the background.").font(.caption).foregroundStyle(.secondary)
            }
        } options: {
            VStack(alignment: .leading, spacing: 10) {
                if !ctx.hasPalette { Text("Drawn in a neutral palette until you choose yours.").font(.caption).foregroundStyle(.secondary) }
                Picker("Family", selection: $family) { ForEach(["All"] + Array(Set(list.map { $0.family })).sorted(), id: \.self) { Text($0).tag($0) } }.frame(maxWidth: 220)
                LazyVGrid(columns: optionColumns, spacing: 12) {
                    ForEach(part.others.filter { family == "All" || $0.family == family }) { b in
                        optionBox {
                            VStack(alignment: .leading, spacing: 6) {
                                EngineThumb(token: b.id + ctx.palette.signature + mood) { await engine.backgroundFrames(b.id, mood: mood, palette: ctx.palette, store: project.store) }
                                HStack { Text(b.name).font(.callout.weight(.semibold)); chip(b.animated ? "Animated" : b.family) }
                                Text(b.desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                Button("Use this background") {
                                    project.perform(.decisions([DecisionChange(.background, b.id), DecisionChange(.backgroundMood, mood)], title: "Set background: \(b.name)"))
                                }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .task { await engine.start(); mood = project.showreel?.decisions.background?.mood ?? "" }
    }
}

// MARK: moods and effects

/// The motion moods (one or two). The chosen ones are the cards at the top; the other packs are the library. A pick is a draft until "Use these moods".
struct MoodsPickerView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var selected: [String] = []

    var body: some View {
        let ctx = LookContext(project)
        let saved = project.showreel?.decisions.moods ?? []
        let part = LookChoices.split(Look.packs(), id: { $0.name }, currents: selected)
        PinnedChoices(key: selected.joined(separator: "|"), optionsTitle: "Other moods: pick one or two, then use them") {
            VStack(spacing: 8) {
                ForEach(part.current) { p in
                    CurrentCard(label: "Your mood") {
                        HStack(alignment: .top, spacing: 12) {
                            thumb(p, ctx).frame(maxWidth: 240)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.name).font(.title3.weight(.semibold))
                                Text(p.feel).font(.callout).foregroundStyle(.secondary)
                                Text(p.effects.joined(separator: " \u{00B7} ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                                Button("Remove") { selected.removeAll { $0 == p.name } }.buttonStyle(.borderless)
                            }
                        }
                    }
                }
                if part.current.isEmpty { CurrentCard(label: "No mood yet") { Text("Pick one or two moods below. Each is a coherent set of motion.").font(.callout).foregroundStyle(.secondary) } }
                HStack {
                    Button("Use these moods") { project.perform(.decisions([DecisionChange(.moods, selected.joined(separator: ", "))], title: nil)) }
                        .buttonStyle(.borderedProminent).disabled(selected.isEmpty || selected == saved)
                    if !saved.isEmpty && selected == saved { Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
            }
        } options: {
            LazyVGrid(columns: optionColumns, spacing: 12) {
                ForEach(part.others) { p in
                    Button {
                        if selected.count < 2 { selected.append(p.name) } else { selected = [selected[1], p.name] }
                    } label: {
                        optionBox {
                            VStack(alignment: .leading, spacing: 6) {
                                thumb(p, ctx)
                                Text(p.name).font(.headline)
                                Text(p.feel).font(.caption).foregroundStyle(.secondary)
                                Text(p.effects.joined(separator: " \u{00B7} ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { selected = saved }
        .onChange(of: project.showreel?.decisions.moods) { m in selected = m ?? [] }
        .task { await engine.start() }
    }

    @ViewBuilder private func thumb(_ p: Look.Pack, _ ctx: LookContext) -> some View {
        if let first = p.effects.first(where: { n in engine.catalogue?.effects.contains { $0.name == n } ?? true }) {
            EngineThumb(token: first + ctx.palette.signature + ctx.titleFont) { await engine.effectFrames(first, palette: ctx.palette, font: ctx.titleFont, store: project.store, text: ctx.text) }
        }
    }
}

/// The effects pack. The chosen pack is the card at the top, with its effects; the other packs are the library, and every effect of the catalogue can be browsed.
struct EffectsPickerView: View {
    @EnvironmentObject var project: ProjectModel
    @ObservedObject private var engine = EngineService.shared
    @State private var all = false
    @State private var search = ""
    @State private var cat = "All"

    var body: some View {
        let ctx = LookContext(project)
        let saved = project.showreel?.decisions.effectsPack ?? ""
        let part = LookChoices.split(Look.packs(), id: { $0.name }, current: saved)
        let list = engine.catalogue?.effects ?? []
        PinnedChoices(key: saved, optionsTitle: "Other packs") {
            CurrentCard(label: saved.isEmpty ? "No effects pack yet" : "Current effects pack") {
                if let p = part.current {
                    HStack(alignment: .top, spacing: 12) {
                        thumb(p, ctx).frame(maxWidth: 260)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(p.name).font(.title3.weight(.semibold)); if (project.showreel?.decisions.moods ?? []).contains(p.name) { chip("your mood") } }
                            Text(p.feel).font(.callout).foregroundStyle(.secondary)
                            Text(p.effects.joined(separator: " \u{00B7} ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else { Text("Pick a pack below: the AI draws its animations from it.").font(.callout).foregroundStyle(.secondary) }
            }
        } options: {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: optionColumns, spacing: 12) {
                    ForEach(part.others) { p in
                        optionBox {
                            VStack(alignment: .leading, spacing: 6) {
                                thumb(p, ctx)
                                HStack { Text(p.name).font(.headline); if (project.showreel?.decisions.moods ?? []).contains(p.name) { chip("your mood") } }
                                Text(p.feel).font(.caption).foregroundStyle(.secondary)
                                Text(p.effects.joined(separator: " \u{00B7} ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                                Button("Use \(p.name) as the effects pack") { project.perform(.decisions([DecisionChange(.effectsPack, p.name)], title: nil)) }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Toggle("Browse every effect of the catalogue", isOn: $all).toggleStyle(.checkbox)
                if all {
                    HStack {
                        TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                        Picker("", selection: $cat) { ForEach(["All"] + Array(Set(list.map { $0.cat })).sorted(), id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(maxWidth: 160)
                    }
                    LazyVGrid(columns: optionColumns, spacing: 12) {
                        ForEach(list.filter { $0.cat != EngineCatalogue.transitionCategory && (cat == "All" || $0.cat == cat) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }) { e in
                            optionBox {
                                VStack(alignment: .leading, spacing: 4) {
                                    EngineThumb(token: e.name + ctx.palette.signature + ctx.titleFont) { await engine.effectFrames(e.name, palette: ctx.palette, font: ctx.titleFont, store: project.store, text: ctx.text) }
                                    HStack { Text(e.name).font(.callout.weight(.semibold)); Text(e.energy).font(.caption2).padding(.horizontal, 5).background(Color.primary.opacity(0.08), in: Capsule()) }
                                    Text(e.desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task { await engine.start() }
    }

    @ViewBuilder private func thumb(_ p: Look.Pack, _ ctx: LookContext) -> some View {
        if let first = p.effects.first(where: { n in engine.catalogue?.effects.contains { $0.name == n } ?? true }) {
            EngineThumb(token: first + ctx.palette.signature + ctx.titleFont) { await engine.effectFrames(first, palette: ctx.palette, font: ctx.titleFont, store: project.store, text: ctx.text) }
        }
    }
}

// MARK: compact controls (the setup form of Expert mode)

/// The same choices as the editors above, as menus: a starting look sets the palette, the fonts, the background and the pack at once.
struct StartingLookMenu: View {
    @EnvironmentObject var project: ProjectModel
    var body: some View {
        Menu("Choose a starting look...") {
            ForEach(LookPackages.all()) { p in Button(p.name) { project.perform(.decisions(p.decisions, title: "Choose the look: \(p.name)")) } }
        }.menuStyle(.borderlessButton).fixedSize()
    }
}

struct FontMenu: View {
    let role: DecisionKey
    @EnvironmentObject var project: ProjectModel
    var body: some View {
        let current = project.showreel.map { role.current($0) } ?? ""
        Menu(current.isEmpty ? "Choose..." : current) {
            ForEach(Look.freeFonts()) { f in Button(f.name) { project.perform(.decisions([DecisionChange(role, f.name)], title: nil)) } }
        }.menuStyle(.borderlessButton).fixedSize()
    }
}

struct BackgroundMenu: View {
    @EnvironmentObject var project: ProjectModel
    var body: some View {
        let current = project.showreel?.decisions.background?.id ?? ""
        let mood = project.showreel?.decisions.background?.mood ?? ""
        Menu(current.isEmpty ? "Choose..." : current) {
            ForEach(Look.backgroundIDs(), id: \.self) { id in
                Button(id) { project.perform(.decisions([DecisionChange(.background, id), DecisionChange(.backgroundMood, mood)], title: "Set background: \(id)")) }
            }
        }.menuStyle(.borderlessButton).fixedSize()
    }
}
