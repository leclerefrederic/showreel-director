import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// Project block: the questions of the interview's first round, as a form. Every change is a typed operation.
struct ProjectBlockView: View {
    @EnvironmentObject var project: ProjectModel
    @State private var drafts: [ParameterKey: String] = [:]
    @State private var dirty: Set<ParameterKey> = []
    @State private var commitTask: DispatchWorkItem?

    private static let formats = ["16:9", "9:16", "1:1", "4:5"]
    private static let languages = ["": "Not set", "en": "English", "fr": "French", "de": "German", "es": "Spanish", "it": "Italian", "pt": "Portuguese", "nl": "Dutch"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if project.showreel == nil { missing } else { form }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { load() }
        .onChange(of: project.showreel) { _ in load() }
        .onDisappear { commit() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Project").font(.title2.weight(.semibold))
                Text("The answers the film is built on. The copilot reads them and does not ask again.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if project.showreel != nil { ValidateButton(gate: "interview", block: "project") }
        }
    }

    private var missing: some View {
        Text("This project has no data yet. Confirm the import or create it with the banner above.").foregroundStyle(.secondary)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            field(.name, lines: 1)
            field(.audience, lines: 3)
            field(.message, lines: 3)
            field(.tone, lines: 2)
            VStack(alignment: .leading, spacing: 4) {
                label(.conversationLanguage)
                Picker("", selection: Binding(get: { project.showreel?.conversationLanguage ?? "" }, set: { v in
                    project.perform(.parameter(.conversationLanguage, v))
                })) {
                    ForEach(Self.languages.keys.sorted(), id: \.self) { Text(Self.languages[$0] ?? $0).tag($0) }
                }
                .labelsHidden().frame(maxWidth: 220)
                help(.conversationLanguage)
            }
            field(.reelLanguages, lines: 1, prompt: "codes separated by commas, for example en, fr")
            VStack(alignment: .leading, spacing: 4) {
                label(.formats)
                HStack {
                    ForEach(Self.formats, id: \.self) { f in
                        Toggle(f, isOn: Binding(get: { (project.showreel?.decisions.formats ?? []).contains(f) }, set: { on in toggleFormat(f, on) }))
                            .toggleStyle(.button)
                    }
                }
                help(.formats)
            }
            field(.duration, lines: 1, prompt: "seconds, for example 45", width: 160)
            field(.constraints, lines: 3)
        }
    }

    private func label(_ k: ParameterKey) -> some View { Text(k.title).font(.headline) }
    private func help(_ k: ParameterKey) -> some View { Text(k.help).font(.caption).foregroundStyle(.secondary) }

    private func field(_ k: ParameterKey, lines: Int, prompt: String = "", width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(k)
            let binding = Binding(get: { drafts[k] ?? "" }, set: { v in drafts[k] = v; dirty.insert(k); schedule() })
            if lines == 1 {
                TextField("", text: binding, prompt: Text(prompt)).textFieldStyle(.roundedBorder).frame(maxWidth: width ?? .infinity)
                    .onSubmit { commit() }
            } else {
                TextEditor(text: binding)
                    .font(.body)
                    .frame(height: CGFloat(lines) * 22 + 12)
                    .padding(2)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
            }
            help(k)
        }
    }

    // drafts: what is typed; committed after a pause, on Return and when the block is left
    private static let typed: [ParameterKey] = [.name, .audience, .message, .tone, .reelLanguages, .duration, .constraints]

    private func load() {
        guard let f = project.showreel else { return }
        for k in Self.typed where !dirty.contains(k) { drafts[k] = k.current(f).replacingOccurrences(of: " s", with: "", options: .anchored, range: nil) }
        if !dirty.contains(.duration) { drafts[.duration] = f.decisions.duration.map { ProjectDocs.seconds($0) } ?? "" }
    }

    private func schedule() {
        commitTask?.cancel()
        let w = DispatchWorkItem { commit() }
        commitTask = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: w)
    }

    private func commit() {
        commitTask?.cancel()
        guard let f = project.showreel else { return }
        for k in dirty.sorted(by: { $0.rawValue < $1.rawValue }) {
            var now = ""
            var probe = f
            let draft = drafts[k] ?? ""
            do { try k.set(draft, in: &probe); now = k.current(probe) } catch { project.error = error.localizedDescription; dirty.remove(k); drafts[k] = k.current(f); continue }
            if now != k.current(f) { project.perform(.parameter(k, draft)) }
            dirty.remove(k)
        }
        load()
    }

    private func toggleFormat(_ f: String, _ on: Bool) {
        var l = project.showreel?.decisions.formats ?? []
        if on, !l.contains(f) { l.append(f) } else if !on { l.removeAll { $0 == f } }
        project.perform(.parameter(.formats, l.joined(separator: ", ")))
    }
}

/// "Mark this block as validated": the gate of the block, set by the user.
struct ValidateButton: View {
    let gate: String
    let block: String
    @EnvironmentObject var project: ProjectModel

    private var passed: Bool { project.showreel?.gates[gate] == "passed" }

    var body: some View {
        Button {
            project.perform(.gate(gate, passed: !passed))
        } label: {
            Label(passed ? "Validated" : "Mark as validated", systemImage: passed ? "checkmark.circle.fill" : "checkmark.circle")
        }
        .buttonStyle(.bordered)
        .tint(passed ? .green : .accentColor)
        .help(passed ? "Click to reopen this block" : "Say you are done with this block")
    }
}

/// Resources block: the assets as a grid. Drop files in, decide on each one, link it to scenes.
struct ResourcesBlockView: View {
    @EnvironmentObject var project: ProjectModel
    @State private var targeted = false
    @State private var holding: AssetRow?
    @State private var holdNote = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resources").font(.title2.weight(.semibold))
                    Text("Drop your logos, screenshots, photos, fonts and music here. Nothing is used in the film until you approve it.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { chooseFiles() } label: { Label("Add files...", systemImage: "plus") }
                if project.showreel != nil { ValidateButton(gate: "assets", block: "resources") }
            }
            .padding(24)
            Divider()
            ZStack {
                if project.assets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 36, weight: .light)).foregroundStyle(.secondary)
                        Text("Drop files here").font(.headline)
                        Text("Files only, not folders. Originals are copied into the project and never changed.").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14, alignment: .top)], spacing: 14) {
                            ForEach(project.assets) { row in
                                AssetCard(row: row, onHold: { holding = row; holdNote = row.notes })
                            }
                        }
                        .padding(24)
                    }
                }
                if targeted {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .background(Color.accentColor.opacity(0.08)).padding(10).allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in drop(providers) }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $holding) { row in
            VStack(alignment: .leading, spacing: 12) {
                Text("Hold \(row.name)").font(.headline)
                Text("A held file is not used until you decide. Say why, so you and the copilot remember.").font(.callout).foregroundStyle(.secondary)
                TextField("Why is it on hold?", text: $holdNote, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { holding = nil }.keyboardShortcut(.cancelAction)
                    Button("Hold") { project.perform(.asset(id: row.id, status: .hold, note: holdNote, licence: nil, scenes: nil)); holding = nil }
                        .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                        .disabled(holdNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(18).frame(width: 420)
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

struct AssetCard: View {
    let row: AssetRow
    let onHold: () -> Void
    @EnvironmentObject var project: ProjectModel
    @State private var licence = ""
    @State private var scenes = ""
    @State private var note = ""

    private static let imageTypes: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg"]

    private var fileURL: URL? {
        let a = project.root.appendingPathComponent("assets")
        if !row.file.isEmpty { return a.appendingPathComponent(row.file) }
        if row.origin != "not copied", !row.original.isEmpty { return a.appendingPathComponent("source").appendingPathComponent(row.original) }
        return nil
    }

    private var thumbnail: NSImage? {
        guard let u = fileURL, Self.imageTypes.contains(u.pathExtension.lowercased()) else { return nil }
        return NSImage(contentsOf: u)
    }

    private var color: Color {
        switch row.status {
        case "approved": return .green
        case "excluded": return .secondary
        case "hold": return .orange
        case "placeholder": return .purple
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06))
                if let img = thumbnail {
                    Image(nsImage: img).resizable().scaledToFit().padding(6)
                } else {
                    Image(systemName: symbol).font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
                }
            }
            .frame(height: 110)
            .opacity(row.status == "excluded" ? 0.45 : 1)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    Text("\(row.id) · \(row.type)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                statusMenu
            }
            if !row.notes.isEmpty {
                Text(row.notes).font(.caption).foregroundStyle(row.status == "hold" ? Color.orange : .secondary).lineLimit(3)
            }
            TextField("Used in scenes (S01, S07)", text: $scenes).textFieldStyle(.roundedBorder).font(.caption)
                .onSubmit { project.perform(.asset(id: row.id, status: nil, note: nil, licence: nil, scenes: scenes)) }
            TextField("Licence note", text: $licence).textFieldStyle(.roundedBorder).font(.caption)
                .onSubmit { project.perform(.asset(id: row.id, status: nil, note: nil, licence: licence, scenes: nil)) }
            TextField("Note", text: $note).textFieldStyle(.roundedBorder).font(.caption)
                .onSubmit { project.perform(.asset(id: row.id, status: nil, note: note, licence: nil, scenes: nil)) }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.08)))
        .onAppear { sync() }
        .onChange(of: row) { _ in sync() }
        .contextMenu {
            if let u = fileURL { Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) } }
        }
    }

    private func sync() { licence = row.licenceNote; scenes = row.scene; note = row.notes }

    private var statusMenu: some View {
        Menu {
            ForEach(AssetStatus.allCases, id: \.self) { s in
                Button(s.rawValue.capitalized) {
                    if s == .hold { onHold() } else { project.perform(.asset(id: row.id, status: s, note: nil, licence: nil, scenes: nil)) }
                }
                .disabled(row.status == s.rawValue)
            }
        } label: {
            Text(row.status.capitalized).font(.caption.weight(.semibold)).foregroundStyle(color)
        }
        .menuStyle(.borderlessButton).fixedSize()
    }

    private var symbol: String {
        switch row.type {
        case "logo", "icon", "illus", "img", "shot", "photo": return "photo"
        case "font": return "textformat"
        case "audio", "voice", "sfx": return "waveform"
        case "video", "frames": return "film"
        default: return "doc"
        }
    }
}
