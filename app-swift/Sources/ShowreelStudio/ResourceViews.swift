import AppKit
import AVFoundation
import ShowreelKit
import SwiftUI

// The Resources tab, its preview in the centre and the inspector of a resource. The rules (the groups, the four states, the tags, what needs attention and what settles it,
// what the centre shows) are ShowreelKit's `Resources`, `ResourceState`, `ResourceAttention`, `RightsAnswer`; this only draws them.

extension ProjectModel {
    func toggleFold(_ key: String) {
        let m = Resources.toggled(key, memory: foldMemory)
        foldMemory = m
        var s = store.settings; s.collapsed = m; store.settings = s
    }
    func addTag(_ id: String, _ tag: String) { perform(.resource(.addTag(id: id, tag: tag))) }
    func removeTag(_ id: String, _ tag: String) { perform(.resource(.removeTag(id: id, tag: tag))) }
    func renameTag(_ from: String, _ to: String) { if perform(.resource(.renameTag(from: from, to: to))), tagFilter == from { tagFilter = to } }
}

struct ResourcesLibrary: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let tags = Resources.allTags(project.assets, in: project.showreel)
        VStack(spacing: 0) {
            HStack {
                Button { chooseFiles() } label: { Label("Add files...", systemImage: "plus") }
                Spacer()
                if !tags.isEmpty {
                    Menu {
                        Button("All resources") { project.tagFilter = nil }
                        Divider()
                        ForEach(tags, id: \.self) { t in Button(t) { project.tagFilter = t } }
                        if let t = project.tagFilter, t != "placeholder" { Divider(); Button("Rename \u{201C}\(t)\u{201D}...") { project.renamingTag = t } }
                    } label: { Label(project.tagFilter.map { "Tag: \($0)" } ?? "Tags", systemImage: "tag") }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                ValidateButton(gate: "assets", block: "library")
            }
            .padding(10)
            ZStack {
                if project.assets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
                        Text("Drop files here").font(.headline)
                        Text("Logos, screenshots, photos, fonts, music. Originals are copied into the project and never changed. A file is checked at once: if something looks wrong it waits for you, and is never used meanwhile.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            let sections = Resources.sections(project.assets, file: project.showreel, tag: project.tagFilter, memory: project.foldMemory)
                            if sections.isEmpty { Text("No resource has this tag.").font(.caption).foregroundStyle(.secondary).padding(10) }
                            ForEach(sections) { sec in
                                header(sec.group.title, count: sec.count, folded: sec.folded, key: sec.group.rawValue, level: 0)
                                if !sec.folded {
                                    ForEach(sec.subs) { sub in
                                        header(sub.heading, count: sub.rows.count, folded: sub.folded, key: sub.key, level: 1)
                                        if !sub.folded { ForEach(sub.rows) { a in row(a) } }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
            }
            .dropTarget(.resourceList)      // files from the Finder land here: added with the automatic checks
        }
        .alert("Rename the tag", isPresented: Binding(get: { project.renamingTag != nil }, set: { if !$0 { project.renamingTag = nil } })) {
            RenameTagField()
        } message: { Text("It is renamed on every resource that has it.") }
    }

    private func header(_ title: String, count: Int, folded: Bool, key: String, level: Int) -> some View {
        Button { project.toggleFold(key) } label: {
            HStack(spacing: 4) {
                Image(systemName: folded ? "chevron.right" : "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.secondary).frame(width: 12)
                Text(title).font(level == 0 ? .subheadline.weight(.semibold) : .caption.weight(.semibold)).foregroundStyle(level == 0 ? Color.primary : .secondary)
                Text("\(count)").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.leading, CGFloat(level) * 14).padding(.top, level == 0 ? 8 : 2).contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(folded ? "Show" : "Fold")
    }

    private func row(_ a: AssetRow) -> some View {
        LibraryRow(selected: project.selection == .asset(a.id), action: { project.select(.asset(a.id)); project.libraryTab = .resources }) { AssetRowView(row: a) }
            .padding(.vertical, 1).padding(.leading, 28)
            .dragSource(.resource(a.id), label: a.name, icon: a.symbolName)
            .contextMenu { menu(a) }
    }

    @ViewBuilder private func menu(_ a: AssetRow) -> some View {
        switch a.state(in: project.showreel) {
        case .proposal: Button("Approve") { project.setAssetStatus(a.id, .approved) }; Button("Decline") { project.setAssetStatus(a.id, .excluded) }
        case .declined: Button("Put back") { project.setAssetStatus(a.id, .approved) }
        case .needsAttention: Button("Leave it out", role: .destructive) { project.setAssetStatus(a.id, .excluded) }
        default: Button("Exclude from the project", role: .destructive) { project.setAssetStatus(a.id, .excluded) }
        }
        if let u = AssetFiles.url(a, in: project.root) { Divider(); Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) } }
    }

    private func chooseFiles() {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = true
        p.prompt = "Add"
        if p.runModal() == .OK { project.addAssets(p.urls) }
    }
}

private struct RenameTagField: View {
    @EnvironmentObject var project: ProjectModel
    @State private var name = ""
    var body: some View {
        TextField("New name", text: $name)
        Button("Rename") { if let t = project.renamingTag { project.renameTag(t, name) }; project.renamingTag = nil }
            .disabledWithReason(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Type the new name" : nil)
        Button("Cancel", role: .cancel) { project.renamingTag = nil }
    }
}

struct AssetRowView: View {
    let row: AssetRow
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let state = row.state(in: project.showreel)
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06))
                if let img = AssetFiles.thumbnail(row, in: project.root) { Image(nsImage: img).resizable().scaledToFit().padding(2) }
                else { Image(systemName: row.symbolName).foregroundStyle(.secondary) }
            }
            .frame(width: 36, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name).font(.callout).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 4) {
                    Text(state.title).font(.caption2.weight(.semibold)).foregroundStyle(color(state)).lineLimit(1)
                    ForEach(Resources.tags(of: row, in: project.showreel), id: \.self) { Text($0).font(.caption2).padding(.horizontal, 4).background(Color.primary.opacity(0.08), in: Capsule()) }
                }
                if row.type == "font", let d = FontUse.describe(row, store: project.store) { Text(d).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 4)
            BlockMarker(ref: .asset(row.id))
        }
        .opacity(state == .declined ? 0.5 : 1)
        .temporaryVeil(.asset(row.id))
    }

    private func color(_ s: ResourceState) -> Color {
        switch s { case .needsAttention: return .orange; case .proposal: return .blue; case .used: return .green; case .declined: return .secondary; case .available: return .secondary }
    }
}

// MARK: the inspector of a resource

struct AssetInspector: View {
    let id: String
    @EnvironmentObject var project: ProjectModel
    @State private var tag = ""

    var body: some View {
        if let row = project.assets.first(where: { $0.id == id }) {
            let state = row.state(in: project.showreel)
            VStack(alignment: .leading, spacing: 14) {
                InspectorHeader(title: row.name, subtitle: "\(row.id) \u{00B7} \(row.group.title)")
                Label(state.title, systemImage: symbol(state)).font(.callout.weight(.semibold)).foregroundStyle(color(state))
                if case .used(let scenes) = state { chips(scenes) }
                if state == .proposal { proposal(row) }
                if state == .needsAttention { attention(row) }
                if row.type == "font", let d = FontUse.describe(row, store: project.store) { Text(d).font(.callout).foregroundStyle(.secondary) }
                tags(row)
                DetailsSection(row: row)
                if state == .declined { Button("Put back") { project.setAssetStatus(row.id, .approved) }.help("It becomes available again") }
            }
            .readOnlyWhenBlocked(.asset(id))
        } else {
            Text("This resource is not in the project any more.").foregroundStyle(.secondary)
        }
    }

    private func chips(_ scenes: [String]) -> some View {
        HStack(spacing: 6) {
            Text("Used in").font(.caption).foregroundStyle(.secondary)
            ForEach(scenes, id: \.self) { s in
                Button { project.select(.scene(s)) } label: { Text(s).font(.caption.monospaced().weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.accentColor.opacity(0.16), in: Capsule()) }
                    .buttonStyle(.plain).help("Select \(s)")
            }
            Text("Linking is done from the scene.").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func tags(_ row: AssetRow) -> some View {
        let mine = Resources.tags(of: row, in: project.showreel)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Tags").font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                ForEach(mine, id: \.self) { t in
                    HStack(spacing: 3) {
                        Text(t).font(.caption)
                        Button { project.removeTag(row.id, t) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Remove the tag")
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3).background(Color.primary.opacity(0.08), in: Capsule())
                }
                TextField("", text: $tag, prompt: Text("Add a tag, for example logo")).textFieldStyle(.roundedBorder).frame(maxWidth: 200)
                    .onSubmit { let t = tag; tag = ""; if !t.trimmingCharacters(in: .whitespaces).isEmpty { project.addTag(row.id, t) } }
            }
            Text("\u{201C}placeholder\u{201D} marks a stand-in: the release gate lists it.").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: a proposal

    private func proposal(_ row: AssetRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Clap suggests using this resource", systemImage: ClapMark.symbol).font(.callout.weight(.semibold))
            Text(row.notes.isEmpty ? "No reason was given." : row.notes).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
                Button("Decline") { project.setAssetStatus(row.id, .excluded) }
                Button("Approve") { project.setAssetStatus(row.id, .approved) }.buttonStyle(.borderedProminent)
            }
            Text("Approving makes it available (and links it to the scene it was proposed for). Declining puts it away so that it is not proposed again.").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: a file that needs attention

    private func attention(_ row: AssetRow) -> some View {
        AttentionBox(row: row)
    }

    private func symbol(_ s: ResourceState) -> String { switch s { case .needsAttention: return "exclamationmark.triangle.fill"; case .proposal: return "sparkles"; case .used: return "checkmark.circle.fill"; case .declined: return "xmark.circle"; case .available: return "circle" } }
    private func color(_ s: ResourceState) -> Color { switch s { case .needsAttention: return .orange; case .proposal: return .blue; case .used: return .green; default: return .secondary } }
}

/// What a flagged file says and how to settle it. The file stays in source/, out of Clap's sight and out of the build, until it is.
struct AttentionBox: View {
    let row: AssetRow
    @EnvironmentObject var project: ProjectModel
    @State private var answer: RightsAnswer?
    @State private var detail = ""
    @State private var reason = ""

    var body: some View {
        let a = ResourceAttention.of(row, store: project.store)
        VStack(alignment: .leading, spacing: 10) {
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill").font(.callout.weight(.semibold)).foregroundStyle(.orange)
            ForEach(a.reasons, id: \.self) { Text("\u{2022} " + $0.prefix(1).uppercased() + $0.dropFirst()).font(.callout).fixedSize(horizontal: false, vertical: true) }
            Text("It cannot be used, and Clap cannot see it, until this is settled.").font(.caption).foregroundStyle(.secondary)
            if a.asksRights {
                Text("What are you allowed to do with it?").font(.subheadline.weight(.medium))
                ForEach(RightsAnswer.allCases, id: \.self) { r in
                    Button { answer = r } label: {
                        HStack { Image(systemName: answer == r ? "largecircle.fill.circle" : "circle"); Text(r.title).font(.callout); Spacer() }
                            .padding(8).background(answer == r ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous)).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                if let r = answer {
                    TextField("", text: $detail, prompt: Text(r.detailHint), axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
                    if r == .unknown { Text("With unknown rights the file stays here.").font(.caption).foregroundStyle(.secondary) }
                    Button(r == .unknown ? "Keep it here" : "Confirm") { project.perform(r.operation(id: row.id, detail: detail)); answer = nil; detail = "" }.buttonStyle(.borderedProminent)
                }
            }
            if a.canAcceptRisk && !a.mustReplace {
                TextField("", text: $reason, prompt: Text("Why is it fine to use it anyway?"), axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
                Button("Accept the risk") { project.perform(.asset(id: row.id, status: .approved, note: "accepted: " + reason.trimmingCharacters(in: .whitespacesAndNewlines), licence: nil, scenes: nil)); reason = "" }
                    .disabledWithReason(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Say why first" : nil, way: "A short reason is kept with the file")
            }
            HStack {
                Button("Replace the file...") { replace() }
                Button("Leave it out", role: .destructive) { project.setAssetStatus(row.id, .excluded) }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func replace() {
        let p = NSOpenPanel(); p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = false; p.prompt = "Replace"
        if p.runModal() == .OK, let u = p.url { project.perform(.resource(.replaceFile(id: row.id, url: u))) }
    }
}

// MARK: the preview in the centre

extension ProjectModel {
    /// The details of a resource, read off the main thread (kept while the file does not change).
    func loadDetails(_ row: AssetRow) async -> ResourceDetails {
        let store = self.store, f = self.showreel, cache = detailsCache
        let key = ResourceDetailsReader.identity(row, store: store) + "|" + row.status + "|" + row.licenceNote + "|" + row.notes + "|" + (f?.scenes.map { $0.id + ($0.content.contains { $0.resource == row.id } ? "*" : "") }.joined() ?? "")
        if let d = cache.cached(key) { return d }
        return await Task.detached(priority: .userInitiated) { cache.details(key) { ResourceDetailsReader.read(row, store: store, file: f) } }.value
    }
}

/// The selected resource, in the viewer: the image, the sound or the music with its tags, its cover and a small player, the font as a specimen. It is made again, with a clean
/// state and its own player, for every resource (its identity is the resource and its file), so what is shown and heard is always the selected one.
struct ResourcePreview: View {
    let id: String
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        if let a = project.assets.first(where: { $0.id == id }), let url = ResourceDetailsReader.fileURL(a, store: project.store) {
            let identity = ResourceDetailsReader.identity(a, store: project.store)
            ResourcePreviewBody(row: a, url: url).id(identity)
        } else {
            Text("This resource has no file to show.").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ResourcePreviewBody: View {
    let row: AssetRow
    let url: URL
    @EnvironmentObject var project: ProjectModel
    @State private var details: ResourceDetails?

    var body: some View {
        VStack(spacing: 12) {
            PreviewTag(text: "Preview of the resource")
            switch row.group {
            case .images: image
            case .music, .sounds: AudioPreview(resource: row.id, url: url)
            case .fonts: FontSpecimen(row: row, url: url)
            case .other: Image(systemName: row.symbolName).font(.system(size: 60, weight: .light)).foregroundStyle(.secondary)
            }
            Text(row.name).font(.headline)
            Text(row.state(in: project.showreel).title).font(.callout).foregroundStyle(.secondary)
            if let d = details {
                if !d.summary.isEmpty { Text(d.summary).font(.callout.monospacedDigit()).foregroundStyle(.secondary).textSelection(.enabled) }
                ForEach(d.warnings, id: \.self) { Label($0, systemImage: "location.fill").font(.caption).foregroundStyle(.orange) }
            } else { HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Reading the file\u{2026}").font(.caption).foregroundStyle(.secondary) } }
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { details = await project.loadDetails(row) }
    }

    @ViewBuilder private var image: some View {
        if let img = NSImage(contentsOf: url) { Image(nsImage: img).resizable().scaledToFit().frame(maxWidth: 760, maxHeight: 428).clipShape(RoundedRectangle(cornerRadius: 8)) }
        else { Image(systemName: row.symbolName).font(.system(size: 60, weight: .light)).foregroundStyle(.secondary) }
    }
}

final class SimplePlayer: ObservableObject {
    private var player: AVAudioPlayer?
    private var timer: Timer?
    @Published var playing = false
    @Published var time = 0.0
    @Published var duration = 0.0
    /// The file could not be opened for playing here.
    @Published var failed = false
    var onStop: (() -> Void)?

    func load(_ url: URL) {
        stop()
        player = try? AVAudioPlayer(contentsOf: url)
        failed = player == nil
        duration = player?.duration ?? 0; time = 0
        player?.prepareToPlay()
    }
    func toggle() {
        guard let p = player else { return }
        if p.isPlaying { pause() }
        else {
            p.play(); playing = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let p = self.player else { return }
                self.time = p.currentTime
                if !p.isPlaying { self.pause() }
            }
        }
    }
    private func pause() { player?.pause(); timer?.invalidate(); timer = nil; if playing { playing = false; onStop?() } }
    func seek(_ t: Double) { player?.currentTime = t; time = t }
    /// Stops, goes back to the start and lets go of the file.
    func stop() {
        player?.stop(); player?.currentTime = 0; timer?.invalidate(); timer = nil
        let was = playing; playing = false; time = 0
        if was { onStop?() }
    }
    deinit { timer?.invalidate(); player?.stop() }
}

struct AudioPreview: View {
    let resource: String
    let url: URL
    @EnvironmentObject var project: ProjectModel
    @StateObject private var player = SimplePlayer()
    @State private var meta: AudioMetadata?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 12) {
            if let d = meta?.artwork, let img = NSImage(data: d) { Image(nsImage: img).resizable().scaledToFit().frame(width: 220, height: 220).clipShape(RoundedRectangle(cornerRadius: 10)) }
            else { Image(systemName: "music.note").font(.system(size: 70, weight: .light)).foregroundStyle(.secondary).frame(width: 220, height: 160) }
            VStack(spacing: 2) {
                if loading { HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Loading\u{2026}").font(.caption).foregroundStyle(.secondary) } }
                else {
                    if let t = meta?.title, !t.isEmpty { Text(t).font(.title3.weight(.semibold)) }
                    if let a = meta?.artist, !a.isEmpty { Text(a).foregroundStyle(.secondary) }
                    if let al = meta?.album, !al.isEmpty { Text(al).font(.caption).foregroundStyle(.secondary) }
                    if meta?.title == nil && meta?.artist == nil { Text("No tags in this file.").font(.caption).foregroundStyle(.secondary) }
                }
            }
            HStack(spacing: 10) {
                Button { player.toggle(); if player.playing { project.previewStarted(resource) } } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill").frame(width: 18) }
                    .disabledWithReason(loading ? "Loading the file" : player.failed ? "This file cannot be played here" : nil)
                Slider(value: Binding(get: { player.time }, set: { player.seek($0) }), in: 0...max(player.duration, 0.1)).frame(maxWidth: 360).disabled(loading || player.failed)
                Text(player.duration > 0 ? "\(DetailFormat.duration(player.time)) / \(DetailFormat.duration(player.duration))" : "0:00").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .task {
            loading = true
            let u = url
            meta = await Task.detached { AudioMetadata.read(u) }.value
            player.onStop = { [resource] in project.previewStopped(resource) }
            player.load(u)
            loading = false
        }
        .onChange(of: project.soundOwner) { o in if o != .resource(resource), player.playing { player.stop() } }      // the film started, or another preview did
        .onDisappear { player.stop(); project.previewStopped(resource) }
    }
}

struct FontSpecimen: View {
    let row: AssetRow
    let url: URL
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let family = FontRegistry.shared.register(url) ?? (row.name as NSString).deletingPathExtension
        let info = FontInfo.read(url)
        VStack(spacing: 10) {
            Text("Aa").font(.custom(family, size: 96))
            Text("A title in this font").font(.custom(family, size: 40).weight(.bold))
            Text("A line of text reads like this, at the size a viewer sees it.").font(.custom(family, size: 18))
            if let i = info { Text(i.family + " \u{00B7} weight " + (i.weightRange.map { "\($0.lowerBound) to \($0.upperBound)" } ?? "\(i.weight)") + (i.italic ? " \u{00B7} italic" : "")).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// The Details section of the inspector: what the file says about itself, in groups of label and value. Right-click copies a value.
struct DetailsSection: View {
    let row: AssetRow
    @EnvironmentObject var project: ProjectModel
    @State private var details: ResourceDetails?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Details").font(.headline)
                Spacer()
                if let u = ResourceDetailsReader.fileURL(row, store: project.store) { Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) }.buttonStyle(.borderless).font(.caption) }
            }
            if let d = details {
                ForEach(d.warnings, id: \.self) { Label($0, systemImage: "location.fill").font(.callout).foregroundStyle(.orange) }
                ForEach(d.groups, id: \.title) { g in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(g.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 3) {
                            ForEach(g.rows, id: \.label) { r in
                                GridRow {
                                    Text(r.label).font(.caption).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                                    Text(r.value).font(.caption).foregroundStyle(r.emphasis ? Color.orange : .primary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                        .contextMenu { Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(r.value, forType: .string) } }
                                }
                            }
                        }
                    }
                }
            } else { HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Reading the file\u{2026}").font(.caption).foregroundStyle(.secondary) } }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: ResourceDetailsReader.identity(row, store: project.store) + row.status + row.licenceNote + row.notes) { details = await project.loadDetails(row) }
    }
}
