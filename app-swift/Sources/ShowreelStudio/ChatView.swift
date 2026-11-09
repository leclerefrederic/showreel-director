import ShowreelKit
import SwiftUI

struct ChatView: View {
    @EnvironmentObject var model: ChatModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            CopilotHeader()
            Divider()
            if model.items.isEmpty {
                WelcomeView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(model.items) { item in
                                ItemView(item: item).id(item.id)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.accentColor, lineWidth: model.focusedCard == item.id ? 3 : 0).allowsHitTesting(false))
                                    .animation(.easeOut(duration: 0.4), value: model.focusedCard)
                            }
                            Color.clear.frame(height: 1).id("end")
                        }
                        .padding(16)
                    }
                    .onChange(of: model.focusTick) { _ in if let id = model.focusedCard { withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .center) } } }
                    .onChange(of: model.scrollTick) { _ in
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("end", anchor: .bottom) }
                    }
                }
            }
            if settings.hasKey { Composer() } else { ConnectAIView() }
        }
        .panelBackground()
    }
}

struct CopilotHeader: View {
    @EnvironmentObject var model: ChatModel
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 8) {
            Label(ClapMark.title, systemImage: ClapMark.symbol).font(.headline)
            ClapActivityChip()
            Spacer()
            Toggle("Apply directly", isOn: $project.applyDirectly)
                .toggleStyle(.checkbox)
                .help("Off: Clap's edits to your files wait for your OK as a diff. On: they are written at once (the history keeps the old version).")
            Button { model.reset() } label: { Image(systemName: "square.and.pencil") }
                .help("New conversation (the old one stays in .studio/chat)")
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct WelcomeView: View {
    @EnvironmentObject var model: ChatModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(ClapMark.title)
                .font(.title2.weight(.semibold))
            Text("Ask for a draft, an explanation or a fix. Edits to your files come as a diff you accept or refuse.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct Composer: View {
    @EnvironmentObject var model: ChatModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask Clap...", text: $model.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.vertical, 8)
                .padding(.leading, 6)
                .onSubmit { model.send() }
            Button {
                if model.running { model.stop() } else { model.send() }
            } label: {
                Image(systemName: model.running ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .disabled(!model.running && model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.08)))
        .padding(12)
    }
}

struct ItemView: View {
    let item: ChatItem

    var body: some View {
        switch item.kind {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(item.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        case .assistant:
            Text(markdown(item.text))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .steps:
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(item.steps.enumerated()), id: \.offset) { _, s in
                        Text(s).fontSmall(mono: true).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.top, 4)
            } label: {
                Label("Working: \(item.steps.count) \(item.steps.count == 1 ? "step" : "steps")",
                      systemImage: "gearshape.2")
                    .fontSmall()
                    .foregroundStyle(.secondary)
            }
        case .question:
            QuestionCard(item: item)
        case .proposal:
            ProposalCard(item: item)
        case .operation:
            OperationCardView(item: item)
        case .notice:
            Label(item.text, systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)
    }
}

struct QuestionCard: View {
    let item: ChatItem
    @EnvironmentObject var model: ChatModel
    @State private var selection: [Int: Set<Int>] = [:] // one independent set per question

    private var complete: Bool {
        item.questions.indices.allSatisfy { !(selection[$0] ?? []).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(item.questions.enumerated()), id: \.element.id) { qi, q in
                VStack(alignment: .leading, spacing: 8) {
                    Text(q.text).font(.headline)
                    ForEach(Array(q.options.enumerated()), id: \.element.id) { oi, o in
                        optionRow(qi: qi, oi: oi, q: q, o: o)
                    }
                }
            }
            if item.answers == nil {
                HStack {
                    Spacer()
                    Button("Confirm") { confirm() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!complete)
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08)))
        .opacity(item.answers == nil ? 1 : 0.65)
        .disabled(item.answers != nil)
    }

    private func optionRow(qi: Int, oi: Int, q: ChoiceQuestion, o: ChoiceOption) -> some View {
        let on = (selection[qi] ?? []).contains(oi)
        let symbol = q.multi ? (on ? "checkmark.square.fill" : "square") : (on ? "largecircle.fill.circle" : "circle")
        return Button {
            var s = selection[qi] ?? []
            if q.multi { if on { s.remove(oi) } else { s.insert(oi) } } else { s = [oi] }
            selection[qi] = s
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(on ? Color.accentColor : Color.secondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.label).font(.body.weight(.medium))
                    if !o.detail.isEmpty { Text(o.detail).fontSmall().foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(on ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func confirm() {
        let answers = item.questions.enumerated().map { qi, q in
            (selection[qi] ?? []).sorted().map { q.options[$0].label }.joined(separator: ", ")
        }
        model.submit(item.id, answers: answers)
    }
}

/// A copilot edit waiting for the user: the diff, then Accept or Refuse.
struct ProposalCard: View {
    let item: ChatItem
    @EnvironmentObject var model: ChatModel
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        if let p = item.proposal {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(p.proposal.original == nil ? "New file" : "Proposed edit", systemImage: "doc.badge.gearshape")
                        .font(.headline)
                    Spacer()
                    if settings.advanced {
                        Button(p.proposal.file) { project.open(p.proposal.file) }
                            .buttonStyle(.link).fontSmall(mono: true)
                            .help("Open the file")
                    } else {
                        Text(p.proposal.file).fontSmall(mono: true).foregroundStyle(.secondary)
                    }
                }
                if !p.proposal.note.isEmpty { Text(p.proposal.note).font(.callout) }
                DiffView(rows: p.rows).frame(maxHeight: 260)
                switch p.status {
                case .pending:
                    HStack {
                        Spacer()
                        Button("Refuse") { model.resolveProposal(item.id, accept: false) }
                        Button("Accept") { model.resolveProposal(item.id, accept: true) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                case .accepted:
                    Label("Accepted", systemImage: "checkmark.circle.fill").fontSmall().foregroundStyle(.secondary)
                case .refused:
                    Label("Refused", systemImage: "xmark.circle").fontSmall().foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08)))
        }
    }
}

/// Added lines in green, removed lines in red, long unchanged runs folded.
struct DiffView: View {
    let rows: [LineDiff.Row]

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case .gap(let n):
                        Text("  ... \(n) unchanged line\(n == 1 ? "" : "s")")
                            .foregroundStyle(.tertiary)
                    case .line(let l):
                        Text(prefix(l) + l.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(color(l))
                    }
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .padding(6)
        }
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func prefix(_ l: DiffLine) -> String { l.kind == .added ? "+ " : l.kind == .removed ? "- " : "  " }
    private func color(_ l: DiffLine) -> Color {
        l.kind == .added ? Color.green.opacity(0.18) : l.kind == .removed ? Color.red.opacity(0.18) : .clear
    }
}

/// A typed change as a plain card: what changes, from what, to what. Accept or refuse.
struct OperationCardView: View {
    let item: ChatItem
    @EnvironmentObject var model: ChatModel

    var body: some View {
        if let o = item.operation {
            VStack(alignment: .leading, spacing: 10) {
                Label(o.card.title, systemImage: ClapMark.symbol).font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(o.card.changes.enumerated()), id: \.offset) { _, c in ChangeRow(change: c) }
                }
                if let w = o.card.lockWarning { LockedLookNotice(warning: w) }
                switch o.status {
                case .pending:
                    HStack {
                        Spacer()
                        Button("Refuse") { model.resolveOperation(item.id, accept: false) }
                        Button(o.card.lockWarning == nil ? "Accept" : "Apply anyway") { model.resolveOperation(item.id, accept: true) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                case .accepted:
                    Label("Accepted", systemImage: "checkmark.circle.fill").fontSmall().foregroundStyle(.secondary)
                case .refused:
                    Label("Refused", systemImage: "xmark.circle").fontSmall().foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08)))
        }
    }
}

/// Without a key the Ask Clap panel says so and how to connect one. Nothing else in the app waits for it.
struct ConnectAIView: View {
    @EnvironmentObject var model: ChatModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Clap is off", systemImage: ClapMark.symbol).font(.headline)
            Text("It answers questions, suggests values and makes changes that you accept or refuse. You can build a project by hand without it. Only generating the film (Build) needs an AI.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Connect AI") { AppSettingsWindow.open() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(12)
    }
}

/// A small link that opens the one place where the API key is set (the app's settings window).
struct ConnectKeyLink: View {
    var body: some View { Button("Connect an API key") { AppSettingsWindow.open() }.buttonStyle(.link).fontSmall() }
}
