import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

// Design packages (docs/Claude/studio-spec.md, section 5.6). The rules (format, validation, hash, rights flow, versions, the author) are ShowreelKit's `DesignPackage`, `PackageReader`,
// `PackageLibrary`, `PackageSave` and `PackageStart`; this only draws them and asks the user.

/// The author's display name, remembered for the next package: never an e-mail address and never read from the system account.
enum PackageAuthorMemory {
    static let key = "packageAuthorName"
    static var name: String { get { UserDefaults.standard.string(forKey: key) ?? "" } set { UserDefaults.standard.set(newValue, forKey: key) } }
}

/// A `.studiopack` that the system handed to the app (double-click, a drop on the Dock icon) and that waits for the import card.
@MainActor
final class PackageInbox: ObservableObject {
    static let shared = PackageInbox()
    @Published var pending: URL?

    func receive(_ urls: [URL]) {
        guard let u = urls.first(where: { $0.pathExtension.lowercased() == PackageType.fileExtension }) else { return }
        pending = u
        NSApplication.shared.activate(ignoringOtherApps: true)
        // a library window that was closed is brought back: the import card is shown there
        NSApplication.shared.windows.first { ($0.identifier?.rawValue ?? "").hasPrefix("library") }?.makeKeyAndOrderFront(nil)
    }
}

enum PackageFormat {
    /// "9 Nov 2026" from the ISO date a package holds; the text itself when it is not one.
    static func day(_ iso: String) -> String {
        guard let d = ISO8601DateFormatter().date(from: iso) else { return iso }
        return d.formatted(date: .abbreviated, time: .omitted)
    }
    static func contentType() -> UTType? { UTType(PackageType.identifier) ?? UTType(filenameExtension: PackageType.fileExtension) }

    /// The save panel of an export; nil when the user cancels. Writes the archive and returns where.
    static func export(_ pkg: DesignPackage) throws -> URL? {
        let p = NSSavePanel()
        p.nameFieldStringValue = "\(pkg.manifest.name) \(pkg.manifest.version).\(PackageType.fileExtension)"
        if let t = contentType() { p.allowedContentTypes = [t] }
        p.message = "Export the package as a file you can send"
        guard p.runModal() == .OK, let u = p.url else { return nil }
        try pkg.write(to: u)
        return u
    }
}

// MARK: Save design as package

struct SavePackageSheet: View {
    @EnvironmentObject var project: ProjectModel
    @Environment(\.dismiss) private var dismiss
    @State private var offer = PackageOffer(look: nil, motion: nil, tone: nil, defaults: nil, resources: [])
    @State private var selection = PackageSelection()
    @State private var name = ""
    @State private var author = PackageAuthorMemory.name
    @State private var note = ""
    @State private var newPackage = false
    @State private var error: String?
    @State private var saved: (entry: LibraryPackage, package: DesignPackage)?
    @State private var exported: URL?
    private let library = PackageLibrary.standard

    private var continuation: (id: String, version: String, name: String)? { project.showreel.flatMap { PackageSave.continuation(of: $0, library: library) } }
    private var continuing: Bool { continuation != nil && !newPackage }

    var body: some View {
        VStack(spacing: 0) {
            if let s = saved { done(s) } else { form }
        }
        .frame(width: 560, height: saved == nil ? 640 : 300)
        .onAppear {
            offer = PackageSave.offer(project.store)
            selection = PackageSelection(all: offer)
            name = continuation?.name ?? project.title
        }
    }

    private var form: some View {
        let avail = Availability.savePackage(in: project.activity, offer: offer)
        return VStack(spacing: 0) {
            Form {
                Section("What goes in") {
                    if let l = offer.look { Toggle(isOn: $selection.look) { part("Look", lookLine(l)) } }
                    if let m = offer.motion { Toggle(isOn: $selection.motion) { part("Default transition", m.defaultTransition + (m.duration.map { ", \(ProjectDocs.seconds($0)) s" } ?? "")) } }
                    if let t = offer.tone { Toggle(isOn: $selection.tone) { part("Tone", t) } }
                    if let d = offer.defaults { Toggle(isOn: $selection.defaults) { part("Defaults", defaultsLine(d)) } }
                    if offer.look == nil && offer.motion == nil && offer.tone == nil && offer.defaults == nil { Text("The project has no look, tone or defaults yet.").foregroundStyle(.secondary) }
                }
                Section("Resources") {
                    if offer.resources.isEmpty { Text("No resource is available to carry: only approved files can go in.").foregroundStyle(.secondary) }
                    ForEach(offer.resources) { r in
                        Toggle(isOn: Binding(get: { selection.resources.contains(r.id) }, set: { if $0 { selection.resources.insert(r.id) } else { selection.resources.remove(r.id) } })) {
                            part(r.row.name, [r.row.type, rights(r), r.tags.isEmpty ? nil : "tags: " + r.tags.joined(separator: ", ")].compactMap { $0 }.joined(separator: " \u{00B7} "))
                        }
                    }
                }
                Section("Package") {
                    if let c = continuation {
                        Picker("Save as", selection: $newPackage) {
                            Text("Version \(c.version) of \u{201C}\(c.name)\u{201D}").tag(false)
                            Text("A new package").tag(true)
                        }.pickerStyle(.radioGroup)
                    }
                    TextField("Name", text: $name)
                    TextField("Author", text: $author, prompt: Text("A display name or a team name, never an e-mail address"))
                    TextField("Note", text: $note, prompt: Text(continuing ? "What changed in this version (required)" : "What this package is for (optional)"), axis: .vertical).lineLimit(2...4)
                }
                if let e = error { Text(e).foregroundStyle(.red).fontSmall() }
            }
            .formStyle(.grouped)
            HStack {
                Text("Saving a package does not change the project.").fontSmall().foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save in the library") { save() }.keyboardShortcut(.defaultAction).buttonStyle(PrimaryButtonStyle())
                    .disabledWithReason(avail.why?.reason ?? (name.trimmingCharacters(in: .whitespaces).isEmpty ? "Give the package a name" : author.trimmingCharacters(in: .whitespaces).isEmpty ? "Give the author a display name" : continuing && note.trimmingCharacters(in: .whitespaces).isEmpty ? "Say what changed in this version" : nil),
                                        way: avail.why?.way)
            }
            .padding(12)
        }
    }

    private func part(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
            if !detail.isEmpty { Text(detail).fontSmall().foregroundStyle(.secondary).lineLimit(2) }
        }
    }
    private func lookLine(_ l: PackageDesign.Look) -> String {
        [l.palette.map { "\($0.count) colours" }, l.titleFont.map { "titles in \($0)" }, l.textFont.map { "text in \($0)" }, l.background.map { "background \($0)" }].compactMap { $0 }.joined(separator: ", ")
    }
    private func defaultsLine(_ d: PackageDesign.Defaults) -> String {
        [d.formats.map { $0.joined(separator: ", ") }, d.duration.map { "\(ProjectDocs.seconds($0)) s" }, d.reelLanguages.map { $0.joined(separator: ", ") }, d.controlLevel.map { "control: \($0)" }].compactMap { $0 }.joined(separator: " \u{00B7} ")
    }
    private func rights(_ r: OfferedResource) -> String {
        if r.openFont { return "open font licence" }
        guard let a = r.rights else { return "no rights stated" }
        return r.rightsDetail.isEmpty ? a.rawValue : "\(a.rawValue): \(r.rightsDetail)"
    }

    private func save() {
        do {
            let a = try PackageAuthor.validate(author)
            let pkg = try PackageSave.build(store: project.store, selection: selection, name: name, author: a, note: note, continuing: continuing, library: library)
            let entry = try library.add(pkg)
            PackageAuthorMemory.name = a
            project.react(StatusLine.packageSaved(name: pkg.manifest.name, version: pkg.manifest.version, exported: false))
            saved = (entry, pkg)
        } catch { self.error = error.localizedDescription }
    }

    private func done(_ s: (entry: LibraryPackage, package: DesignPackage)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Saved in the library", systemImage: "checkmark.circle.fill").font(.title3.weight(.semibold)).foregroundStyle(.green)
            Text("\u{201C}\(s.package.manifest.name)\u{201D} version \(s.package.manifest.version), hash \(s.package.manifest.shortHash). The project did not change.").font(.callout)
            if let u = exported { Text("Exported to \(u.path)").fontSmall().foregroundStyle(.secondary).textSelection(.enabled) }
            HStack {
                Button("Export a .studiopack file\u{2026}") {
                    do { if let u = try PackageFormat.export(s.package) { exported = u; project.react(StatusLine.packageSaved(name: s.package.manifest.name, version: s.package.manifest.version, exported: true)) } } catch { self.error = error.localizedDescription }
                }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([exported ?? s.entry.archive]) }.buttonStyle(SecondaryButtonStyle())
            }
            if let e = error { Text(e).foregroundStyle(.red).fontSmall() }
            Spacer()
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(PrimaryButtonStyle()) }
        }
        .padding(20)
    }
}

/// The footer of the project settings: where the project came from, and the way to save its design.
struct PackageSettingsFooter: View {
    @EnvironmentObject var project: ProjectModel
    @State private var showSave = false
    @State private var originName: String?

    var body: some View {
        let offer = PackageSave.offer(project.store)
        let avail = Availability.savePackage(in: project.activity, offer: offer)
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Design package").fontSmall(weight: .semibold).foregroundStyle(.secondary)
            if let o = project.showreel?.package {
                Text("Started from \u{201C}\(originName ?? "a package")\u{201D} version \(o.version) (hash \(o.hash.prefix(8)))").fontSmall().foregroundStyle(.secondary)
            }
            Button { showSave = true } label: { Label("Save design as package\u{2026}", systemImage: "shippingbox") }
                .disabledWithReason(avail.why?.reason, way: avail.why?.way)
                .help("Saves the look, the tone, the defaults and the resources you choose, to start other reels from.")
        }
        .sheet(isPresented: $showSave) { SavePackageSheet().environmentObject(project) }
        .task { if let o = project.showreel?.package { originName = await Task.detached { PackageLibrary.standard.entry(o.id, o.version)?.manifest.name }.value } }
    }
}

// MARK: the import card

struct PackageImportSheet: View {
    let url: URL
    /// Called when the package is in the library; `start` asks for a new project from it.
    let onAdded: (LibraryPackage, _ start: Bool) -> Void
    /// False inside the New project sheet, where adding the package already selects it.
    var offersStart = true
    @Environment(\.dismiss) private var dismiss
    @State private var result: Result<PackageRead, Error>?
    @State private var decided = false
    @State private var rights = false
    @State private var error: String?
    private let library = PackageLibrary.standard

    var body: some View {
        VStack(spacing: 0) {
            switch result {
            case nil: ProgressView("Reading the package\u{2026}").padding(40)
            case .failure(let e): failure(e)
            case .success(let r): card(r)
            }
        }
        .frame(width: 560)
        .task { result = await Task.detached { Result { try PackageReader.read(url) } }.value }
    }

    private func failure(_ e: Error) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("This file cannot be opened as a package", systemImage: "xmark.octagon.fill").font(.headline).foregroundStyle(.red)
            Text(e.localizedDescription).font(.callout)
            Text("Nothing was kept and nothing was run.").fontSmall().foregroundStyle(.secondary)
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(20)
    }

    private func card(_ r: PackageRead) -> some View {
        let m = r.package.manifest
        let needs = r.integrity.needsDecision && !decided
        return VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Image(systemName: "shippingbox.fill").font(.largeTitle).foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name).font(.title2.weight(.semibold))
                            Text("by \(m.author.isEmpty ? "(no name)" : m.author)").foregroundStyle(.secondary)
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                        row("Version", m.version); row("Created", PackageFormat.day(m.created)); row("Modified", PackageFormat.day(m.modified)); row("Hash", m.shortHash)
                        row("Signature", "Not signed")
                        if let rel = library.relation(of: m) { row("In your library", rel) }
                    }.font(.callout)
                    if !m.note.isEmpty { Text(m.note).font(.callout).foregroundStyle(.secondary) }
                    integrity(r)
                    if r.needsNewerApp { Label("This package needs a newer version of Showreel Studio.", systemImage: "arrow.up.circle").foregroundStyle(.orange).font(.callout) }
                    resources(r.package)
                    Toggle(isOn: $rights) { Text("I confirm I hold the rights to use these resources").font(.callout.weight(.medium)) }
                        .disabled(r.package.resources.isEmpty)
                    Text(rights ? "The confirmation is recorded with this version." : "Without it the package is kept, but its resources enter a project on Needs attention (\u{201C}\(PackageStart.notConfirmed)\u{201D}).")
                        .fontSmall().foregroundStyle(.secondary)
                    if let e = error { Text(e).foregroundStyle(.red).fontSmall() }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add to the library") { add(r, start: false) }.buttonStyle(PrimaryButtonStyle())
                    .disabledWithReason(needs ? "Decide about the warning above first" : r.needsNewerApp ? "This package needs a newer version of the app" : nil)
                if offersStart {
                    Button("Add and start a project") { add(r, start: true) }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                        .disabledWithReason(needs ? "Decide about the warning above first" : r.needsNewerApp ? "This package needs a newer version of the app" : nil)
                }
            }
            .padding(12)
        }
    }

    private func row(_ k: String, _ v: String) -> some View { GridRow { Text(k).foregroundStyle(.secondary); Text(v).textSelection(.enabled) } }

    private func integrity(_ r: PackageRead) -> some View {
        let ok = r.integrity == .matches
        return VStack(alignment: .leading, spacing: 6) {
            Label(r.integrity.title, systemImage: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").font(.callout.weight(.semibold)).foregroundStyle(ok ? Color.green : .orange)
            Text(r.integrity.detail).fontSmall().foregroundStyle(.secondary)
            ForEach(r.problems, id: \.self) { Text("\u{2022} " + $0).fontSmall() }
            if !ok && !decided {
                HStack {
                    Button("Continue anyway") { decided = true }
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            if !ok && decided { Text("You chose to continue with this package.").fontSmall().foregroundStyle(.orange) }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading).background((ok ? Color.green : .orange).opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func resources(_ p: DesignPackage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(p.resources.isEmpty ? "No resource" : "\(p.resources.count) resource\(p.resources.count == 1 ? "" : "s"), with the rights their author declared").font(.callout.weight(.semibold))
            ForEach(p.resources) { r in
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(r.originalName) \u{00B7} \(r.type)").font(.callout)
                    Text(r.rightsLine + (r.approvedBy.map { " \u{00B7} approved by \($0)" + (r.approvedAt.map { " on " + PackageFormat.day($0) } ?? "") } ?? "")).fontSmall().foregroundStyle(.secondary)
                }
            }
        }
    }

    private func add(_ r: PackageRead, start: Bool) {
        do {
            let e = try library.add(r.package)
            if rights { try library.confirm(e, by: PackageAuthorMemory.name.isEmpty ? nil : PackageAuthorMemory.name) }
            let kept = library.entry(e.manifest.id, e.manifest.version) ?? e
            dismiss()
            onAdded(kept, start)
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: starting a project from a package

/// The optional step of the New project sheet: a package of the library, or a `.studiopack` file.
struct PackagePickerSection: View {
    @Binding var selected: LibraryPackage?
    @State private var packages = PackageLibrary.standard.list()
    @State private var importing: URL?
    @State private var error: String?

    var body: some View {
        Section("Start from a design package (optional)") {
            Picker("Package", selection: Binding(get: { selected?.id ?? "" }, set: { id in selected = packages.first { $0.id == id } })) {
                Text("None, start from scratch").tag("")
                ForEach(packages) { p in Text("\(p.manifest.name) \(p.manifest.version) \u{00B7} \(p.manifest.author)").tag(p.id) }
            }
            if let p = selected {
                Text(p.isConfirmed ? "Rights confirmed: its resources will be available." : "Rights not confirmed: its resources will enter the project on Needs attention.")
                    .fontSmall().foregroundStyle(p.isConfirmed ? Color.secondary : .orange)
            }
            Button("Open a .studiopack\u{2026}") { choose() }.buttonStyle(SecondaryButtonStyle())
            if let e = error { Text(e).foregroundStyle(.red).fontSmall() }
        }
        .sheet(item: Binding(get: { importing.map { ImportTicket(url: $0) } }, set: { importing = $0?.url })) { t in
            PackageImportSheet(url: t.url, onAdded: { entry, _ in packages = PackageLibrary.standard.list(); selected = entry }, offersStart: false)
        }
        .onAppear { packages = PackageLibrary.standard.list() }
    }

    private func choose() {
        let p = NSOpenPanel(); p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = false
        if let t = PackageFormat.contentType() { p.allowedContentTypes = [t] }
        p.prompt = "Open"; p.message = "Choose a design package"
        if p.runModal() == .OK, let u = p.url { importing = u }
    }
}

struct ImportTicket: Identifiable { let url: URL; var id: String { url.path } }
