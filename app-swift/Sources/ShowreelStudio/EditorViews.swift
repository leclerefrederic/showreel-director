import ShowreelKit
import SwiftUI

/// A text file in the center pane: markdown (with preview), JSON (checked), CSV (as a table) or plain text.
struct EditorView: View {
    @ObservedObject var tab: EditorTab
    @EnvironmentObject var project: ProjectModel
    @State private var preview = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if tab.diskChanged { changedBanner }
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(tab.path).font(.callout.monospaced()).lineLimit(1).truncationMode(.head)
            if tab.dirty { Text("unsaved").font(.caption).foregroundStyle(.orange) }
            Spacer()
            if tab.kind == .markdown {
                Picker("", selection: $preview) {
                    Text("Edit").tag(false)
                    Text("Preview").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .labelsHidden()
            }
            Button { project.historyFor = tab } label: { Label("History", systemImage: "clock.arrow.circlepath") }
                .help("Earlier versions, with diff and restore")
            Button { project.save(tab) } label: { Label("Save", systemImage: "square.and.arrow.down") }
                .keyboardShortcut("s", modifiers: .command)
                .disabledWithReason(tab.kind == .json && jsonError != nil ? "The JSON has an error: \(jsonError ?? "")" : !tab.dirty ? "No change to save" : nil, way: tab.kind == .json && jsonError != nil ? "Fix it first" : nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var changedBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("This file changed on disk while you were editing it.").font(.callout)
            Spacer()
            Button("Load the disk version") { project.reloadFromDisk(tab) }
            Button("Keep mine") { tab.diskChanged = false }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.14))
    }

    private var jsonError: String? {
        do { _ = try JSONSerialization.jsonObject(with: Data(tab.text.utf8), options: [.fragmentsAllowed]); return nil }
        catch { return (error as NSError).localizedDescription }
    }

    @ViewBuilder private var content: some View {
        switch tab.kind {
        case .markdown:
            if preview { MarkdownPreview(text: tab.text) } else { TextArea(text: $tab.text) }
        case .json:
            VStack(spacing: 0) {
                TextArea(text: $tab.text)
                HStack {
                    Image(systemName: jsonError == nil ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(jsonError == nil ? Color.green : Color.red)
                    Text(jsonError.map { "Not valid JSON: \($0)" } ?? "Valid JSON").font(.caption).lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(.bar)
            }
        case .csv:
            CSVTable(text: $tab.text)
        case .text, .binary:
            TextArea(text: $tab.text)
        }
    }
}

struct TextArea: View {
    @Binding var text: String
    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 13, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor))
    }
}

/// Headings, lists and inline styling; tables and code stay as typed.
struct MarkdownPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    row(line)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .textSelection(.enabled)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder private func row(_ line: String) -> some View {
        let level = line.prefix { $0 == "#" }.count
        if level > 0, level <= 6, line.dropFirst(level).first == " " {
            Text(inline(String(line.dropFirst(level + 1))))
                .font(level == 1 ? .title.bold() : level == 2 ? .title2.bold() : .headline)
                .padding(.top, 6)
        } else if line.hasPrefix("|") || line.hasPrefix("```") || line.hasPrefix("    ") {
            Text(line).font(.system(size: 12, design: .monospaced))
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Color.clear.frame(height: 4)
        } else {
            Text(inline(line))
        }
    }

    private func inline(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)
    }
}

/// A CSV file as an editable grid.
struct CSVTable: View {
    @Binding var text: String
    @State private var rows: [[String]] = []
    @State private var loaded = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
                    ForEach(rows.indices, id: \.self) { r in
                        GridRow {
                            ForEach(columns.indices, id: \.self) { c in
                                TextField("", text: cell(r, c))
                                    .textFieldStyle(.roundedBorder)
                                    .font(r == 0 ? .callout.bold() : .callout)
                                    .frame(minWidth: 110, idealWidth: 160)
                            }
                            if r > 0 {
                                Button { rows.remove(at: r); push() } label: { Image(systemName: "minus.circle") }
                                    .buttonStyle(.borderless).help("Delete this row")
                            }
                        }
                    }
                }
                .padding(10)
            }
            HStack {
                Button { rows.append(Array(repeating: "", count: max(columns.count, 1))); push() } label: { Label("Row", systemImage: "plus") }
                Button { addColumn() } label: { Label("Column", systemImage: "plus") }
                Spacer()
                Text("\(max(rows.count - 1, 0)) rows, \(columns.count) columns").font(.caption).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.bar)
        }
        .onAppear { pull() }
        .onChange(of: text) { t in if t != loaded { pull() } }
    }

    private var columns: [Int] { Array(0..<(rows.map { $0.count }.max() ?? 0)) }

    private func cell(_ r: Int, _ c: Int) -> Binding<String> {
        Binding(get: { r < rows.count && c < rows[r].count ? rows[r][c] : "" },
                set: { v in
                    guard r < rows.count else { return }
                    while rows[r].count <= c { rows[r].append("") }
                    rows[r][c] = v
                    push()
                })
    }

    private func addColumn() {
        if rows.isEmpty { rows = [[""]] } else { for i in rows.indices { rows[i].append("") } }
        push()
    }

    private func pull() { rows = CSV.parse(text); loaded = text }
    private func push() { let t = CSV.write(rows); loaded = t; text = t }
}

/// Earlier versions of a file: pick one, see what differs from now, restore it.
struct HistoryView: View {
    let tab: EditorTab
    @EnvironmentObject var project: ProjectModel
    @Environment(\.dismiss) private var dismiss
    @State private var snapshots: [Snapshot] = []
    @State private var chosen: Snapshot?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History of \(tab.path)").font(.headline)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            if snapshots.isEmpty {
                Text("No earlier version yet. A version is kept each time the file changes.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    List(snapshots, selection: Binding(get: { chosen?.id }, set: { id in chosen = snapshots.first { $0.id == id } })) { s in
                        Text(label(s)).tag(s.id)
                    }
                    .frame(minWidth: 180, idealWidth: 200, maxWidth: 260)
                    VStack(spacing: 0) {
                        if let s = chosen, let old = project.store.content(of: s) {
                            DiffView(rows: LineDiff.collapse(LineDiff.diff(old, tab.text), context: 3)).padding(8)
                            Divider()
                            HStack {
                                Text("Red: in the old version. Green: in the file now.").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("Restore this version") { project.restore(tab, s); dismiss() }
                                    .buttonStyle(.borderedProminent)
                            }
                            .padding(10)
                        } else {
                            Text("Pick a version").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(minWidth: 380)
                }
            }
        }
        .frame(width: 760, height: 480)
        .onAppear { snapshots = project.store.snapshots(tab.path); chosen = snapshots.first }
    }

    private func label(_ s: Snapshot) -> String {
        guard let d = s.date else { return s.id }
        return d.formatted(date: .abbreviated, time: .standard)
    }
}
