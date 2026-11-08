import ShowreelKit
import SwiftUI

/// The History tab of the project settings: the sessions with their summaries, the journal of every operation, and what Clap knows about the project. The
/// data and the rules are ShowreelKit's (`Journal`, `Sessions`, `MemoryRules`); the views only show them and relay the user's edits.
struct HistoryPanel: View {
    enum Part: String, CaseIterable, Identifiable { case knows = "What Clap knows", sessions = "Sessions", journal = "Journal"; var id: String { rawValue } }
    @EnvironmentObject var project: ProjectModel
    @State private var part: Part = .knows

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $part) { ForEach(Part.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).labelsHidden()
            switch part {
            case .knows: WhatClapKnows()
            case .sessions: SessionsList()
            case .journal: JournalList()
            }
        }
        .onAppear { project.reloadHistory() }
    }
}

// MARK: what Clap knows

struct WhatClapKnows: View {
    @EnvironmentObject var project: ProjectModel
    @State private var kind = MemoryKind.decision.rawValue
    @State private var text = ""
    @State private var reason = ""
    @State private var problem: String?
    @State private var showOthers = false

    private var active: [MemoryEntry] { project.memory.filter { $0.status == "active" }.reversed() }
    private var others: [MemoryEntry] { project.memory.filter { $0.status != "active" }.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Clap keeps about this project between sessions: decisions and their reasons, your preferences, what you rejected, constraints, open questions. It is yours: edit or delete anything. It is shown to Clap as notes, never as instructions, and it never keeps personal details or keys.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            add
            if active.isEmpty { Text("Nothing yet.").font(.callout).foregroundStyle(.secondary) }
            ForEach(active) { e in MemoryRow(entry: e) }
            if !others.isEmpty {
                DisclosureGroup("Superseded or deleted (\(others.count))", isExpanded: $showOthers) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(others) { e in
                            HStack(alignment: .firstTextBaseline) {
                                Text(e.status).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                                Text(e.text).font(.callout).strikethrough(e.status == "deleted").foregroundStyle(.secondary)
                                Spacer()
                                if e.status == "superseded" { Button("Make current") { project.editMemory(e.id, status: "active") }.buttonStyle(.borderless) }
                            }
                        }
                    }
                }.font(.callout)
            }
        }
    }

    private var add: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add a note").font(.headline)
            HStack {
                Picker("", selection: $kind) { ForEach(MemoryKind.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) } }.labelsHidden().frame(width: 140)
                TextField("One short sentence", text: $text).textFieldStyle(.roundedBorder).onSubmit { save() }
            }
            HStack {
                TextField("Why (optional)", text: $reason).textFieldStyle(.roundedBorder).onSubmit { save() }
                Button("Add") { save() }.buttonStyle(.borderedProminent).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let p = problem { Label(p, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func save() {
        problem = project.addMemory(kind: kind, text: text, reason: reason)
        if problem == nil { text = ""; reason = "" }
    }
}

struct MemoryRow: View {
    let entry: MemoryEntry
    @EnvironmentObject var project: ProjectModel
    @State private var editing = false
    @State private var text = ""
    @State private var reason = ""
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MemoryKind(rawValue: entry.kind)?.title ?? entry.kind).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.18), in: Capsule())
                if editing {
                    TextField("", text: $text).textFieldStyle(.roundedBorder).onSubmit { commit() }
                } else {
                    Text(entry.text).font(.callout).fixedSize(horizontal: false, vertical: true).onTapGesture(count: 2) { begin() }
                }
                Spacer(minLength: 4)
                if editing {
                    Button("Save") { commit() }.buttonStyle(.borderless); Button("Cancel") { editing = false; problem = nil }.buttonStyle(.borderless)
                } else {
                    Button { begin() } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).help("Edit")
                    Button { project.deleteMemory(entry.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("Delete: Clap will not use it again")
                }
            }
            if editing { TextField("Why (optional)", text: $reason).textFieldStyle(.roundedBorder) }
            else if !entry.reason.isEmpty { Text("Why: " + entry.reason).font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 8) {
                Text((entry.source == "user" ? "You" : "Clap") + ", " + ShowreelFile.dayString(entry.updated)).font(.system(size: 11)).foregroundStyle(.tertiary)
                if !entry.links.isEmpty { Text(entry.links.joined(separator: " ")).font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary) }
                if !entry.confirmed {
                    Text("not confirmed").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                    Button("Confirm") { project.editMemory(entry.id, confirm: true) }.buttonStyle(.borderless).font(.system(size: 11))
                }
            }
            if let p = problem { Label(p, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
        }
        .padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func begin() { text = entry.text; reason = entry.reason; problem = nil; editing = true }

    private func commit() {
        let r = project.editMemory(entry.id, text: text != entry.text ? text : nil, reason: reason != entry.reason ? reason : nil)
        if let r = r, !r.hasPrefix("no change") { problem = r } else { editing = false; problem = nil }
    }
}

// MARK: sessions

struct SessionsList: View {
    @EnvironmentObject var project: ProjectModel
    @State private var open: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if project.sessionRows.isEmpty { Text("No session yet.").font(.callout).foregroundStyle(.secondary) }
            ForEach(project.sessionRows) { s in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(s.date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? s.id).font(.callout.weight(.semibold))
                        Spacer()
                        Text("\(s.operations) operation\(s.operations == 1 ? "" : "s") \u{00B7} \(s.messages) message\(s.messages == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if let t = s.summary { Text(t).font(.callout).fixedSize(horizontal: false, vertical: true) }
                    else { Text(s.messages == 0 ? "No conversation in this session." : "No summary: it is written when a session ends and an AI is connected.").font(.callout).foregroundStyle(.secondary) }
                    if s.messages > 0 {
                        DisclosureGroup("Transcript", isExpanded: Binding(get: { open == s.id }, set: { open = $0 ? s.id : nil })) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(project.transcript(of: s.id).enumerated()), id: \.offset) { _, r in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(r.role == "user" ? "You" : "Clap").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                        Text(r.text).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }.font(.callout)
                    }
                }
                .padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

// MARK: journal

struct JournalList: View {
    @EnvironmentObject var project: ProjectModel
    @State private var author = ""
    @State private var op = ""
    @State private var state = ""

    var body: some View {
        let all = project.journalEntries
        let rows = JournalFilter.apply(all, author: author, op: op, state: state)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Author", selection: $author) { Text("Everyone").tag(""); ForEach(JournalEntry.authors, id: \.self) { Text($0 == "clap" ? "Clap" : $0.capitalized).tag($0) } }.frame(maxWidth: 170)
                Picker("Type", selection: $op) { Text("Every type").tag(""); ForEach(Array(Set(all.map { $0.op })).sorted(), id: \.self) { Text($0).tag($0) } }.frame(maxWidth: 200)
                Picker("State", selection: $state) { Text("Any state").tag(""); ForEach(JournalEntry.states, id: \.self) { Text($0.capitalized).tag($0) } }.frame(maxWidth: 170)
            }
            if rows.isEmpty { Text(all.isEmpty ? "Nothing has been done yet." : "Nothing matches.").font(.callout).foregroundStyle(.secondary) }
            ForEach(rows.prefix(300)) { e in JournalRow(entry: e) }
            if rows.count > 300 { Text("The 300 most recent of \(rows.count).").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct JournalRow: View {
    let entry: JournalEntry
    @EnvironmentObject var project: ProjectModel
    @State private var hovering = false

    private var symbol: (String, Color) {
        switch entry.state {
        case "applied": return ("checkmark.circle.fill", .green)
        case "refused": return ("xmark.circle.fill", .red)
        case "undone": return ("arrow.uturn.backward.circle.fill", .orange)
        default: return ("arrow.uturn.forward.circle.fill", .blue)
        }
    }

    var body: some View {
        let linked = JournalLinks.target(of: entry) != nil
        Button { project.openJournal(entry) } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbol.0).foregroundStyle(symbol.1).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.callout.weight(.medium)).multilineTextAlignment(.leading)
                    if let n = entry.note { Text(n).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                    if !entry.before.isEmpty || !entry.after.isEmpty { Text("\(entry.before)  \u{2192}  \(entry.after)").font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(2).multilineTextAlignment(.leading) }
                    Text("\(entry.time.formatted(date: .abbreviated, time: .standard)) \u{00B7} \(entry.author == "clap" ? "Clap" : entry.author) \u{00B7} \(entry.state) \u{00B7} \(entry.op) \(entry.target)")
                        .font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer(minLength: 2)
                if linked { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
            }
            .padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering && linked ? Color.primary.opacity(0.07) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!linked)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}
