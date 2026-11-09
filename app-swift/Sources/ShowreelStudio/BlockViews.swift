import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// The project's parameters, as a form: the questions of the interview's first round. Every change is a typed operation.
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
