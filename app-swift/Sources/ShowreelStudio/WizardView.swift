import AppKit
import ShowreelKit
import SwiftUI

/// Beginner mode: one question per screen, with the interview's question as the title. It records through the same operations as the blocks.
struct WizardView: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 0) {
            WizardOutline().frame(width: 220)
            Divider()
            VStack(spacing: 0) {
                if project.showreel == nil {
                    Text("This project has no data yet. Confirm the import or create it with the banner above.").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if project.wizardIndex >= project.builtSteps.count {
                    WizardDone()
                } else {
                    WizardStepView(step: project.builtSteps[project.wizardIndex]).id(project.builtSteps[project.wizardIndex].id)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// The parts in order, with how far each one is. Parts that are not built appear as coming soon.
struct WizardOutline: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(project.title).font(.headline).lineLimit(1).padding(12)
            Divider()
            List {
                ForEach(Wizard.sections, id: \.area) { b in
                    let steps = project.builtSteps.filter { $0.area == b.area }
                    let built = project.spec?.isBuilt(area: b.area) ?? false
                    let done = steps.filter { project.isDecided($0) }.count
                    Button {
                        if built { project.jumpToFirstUndecided(in: b.area) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: b.icon).frame(width: 18)
                            Text(b.name).lineLimit(1)
                            Spacer()
                            if !built { Text("Coming soon").font(.caption2).foregroundStyle(.tertiary) }
                            else if done == steps.count && !steps.isEmpty { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            else { Text("\(done)/\(steps.count)").font(.caption).foregroundStyle(.secondary) }
                        }
                        .foregroundStyle(built ? Color.primary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!built)
                }
            }
            .listStyle(.sidebar)
            Divider()
            Text("Beginner mode walks you through the questions one at a time and ends in the editing workspace. Expert mode opens the workspace at once. Switching loses nothing.")
                .font(.caption).foregroundStyle(.secondary).padding(12)
        }
    }
}

struct WizardDone: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal").font(.system(size: 40, weight: .light)).foregroundStyle(.green)
            let p = project.wizardProgress
            Text(p.decided == p.total ? "Everything that can be done now is done" : "That is all for now").font(.title2.weight(.semibold))
            Text("\(p.decided) of \(p.total) steps decided." + (p.decided < p.total ? " The rest waits for you." : ""))
                .foregroundStyle(.secondary)
            let upcoming = project.wizardSteps.filter { !$0.isBuilt }.map { $0.title }
            if !upcoming.isEmpty {
                Text("Coming soon: " + upcoming.joined(separator: ", ") + ".").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
            }
            // a new project reaches the workspace once its base configuration is set: what is missing is named, and a click goes there
            if project.needsSetup, let f = project.showreel {
                let missing = ProjectSetup.missing(f)
                if !missing.isEmpty {
                    VStack(spacing: 4) {
                        Label("The workspace opens when these are set:", systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.orange)
                        ForEach(missing) { m in
                            Button { project.jumpToFirstUndecided(in: m.section == "project" ? "project" : "look") } label: { Text(m.title + ": " + m.detail).font(.callout) }.buttonStyle(.link)
                        }
                    }
                }
            }
            HStack {
                if p.decided < p.total { Button("Go to the first undecided step") { project.resumeWizard() } }
                Button("Open the editing workspace") { project.finishSetup() }.buttonStyle(.borderedProminent)
                    .disabled(project.needsSetup && (project.showreel.map { !ProjectSetup.isComplete($0) } ?? true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One screen. Its answers are local until Next; nothing is recorded without the user's choice.
struct WizardStepView: View {
    let step: WizardStep
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var settings: AppSettings
    @State private var picked: Set<String> = []
    @State private var typed = ""
    @State private var custom = ""
    @State private var holdNote = ""
    @State private var holding = false
    @State private var showAIHelp = false

    private var index: Int { project.wizardIndex }
    private var total: Int { project.builtSteps.count }
    private var decided: Bool { project.isDecided(step) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(step.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(step.help).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    content
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            Divider()
            footer
        }
        .onAppear { load() }
        .sheet(isPresented: $showAIHelp) { ConnectAIHelp() }
    }

    // MARK: chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Wizard.sections.first { $0.area == step.area }?.name ?? step.area).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("Step \(index + 1) of \(total)").font(.caption).foregroundStyle(.secondary)
                if decided { Label("Decided", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
            }
            ProgressView(value: Double(project.wizardProgress.decided), total: Double(max(project.wizardProgress.total, 1)))
        }
        .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 10)
    }

    private var footer: some View {
        HStack {
            Button("Back") { project.wizardBack() }.disabledWithReason(index == 0 ? "This is the first question" : nil)
            Spacer()
            Button { suggest() } label: { Label(step.kind == .scenes ? "Draft with AI" : "Suggest with AI", systemImage: "sparkles") }
                .help("Optional. Clap suggests a value as a card you accept or refuse.")
            Button("Decide later") { project.wizardNext() }
            Button(nextTitle) { next() }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabledWithReason(canNext ? nil : nextReason, way: nil)
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
    }

    private var nextTitle: String { index + 1 >= total ? "Finish" : "Next" }

    // MARK: content by kind

    @ViewBuilder private var content: some View {
        switch step.kind {
        case .single(_, let options, let rec, let allowCustom):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options) { o in optionRow(o, recommended: o.value == rec, multi: false) }
                if allowCustom {
                    TextField("Or write your own", text: $custom).textFieldStyle(.roundedBorder).onChange(of: custom) { v in if !v.isEmpty { picked = [] } }
                }
            }
        case .multi(_, let options, let rec):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options) { o in optionRow(o, recommended: rec.contains(o.value), multi: true) }
            }
        case .number(_, let presets):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(presets) { o in optionRow(o, recommended: false, multi: false) }
                HStack {
                    TextField("Or a number of seconds", text: $custom).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                        .onChange(of: custom) { v in if !v.isEmpty { picked = [] } }
                    Text("seconds").foregroundStyle(.secondary)
                }
                Text("There is no default and no cap: you decide. A feasibility check follows.").font(.caption).foregroundStyle(.secondary)
            }
        case .text(let key, let examples, let optional):
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $typed)
                    .font(.body).frame(height: 110).padding(2)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
                if !examples.isEmpty {
                    Text("Examples, to start from:").font(.caption).foregroundStyle(.secondary)
                    ForEach(examples, id: \.self) { e in
                        Button { typed = e } label: { Text(e).font(.callout).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.bordered)
                    }
                }
                if optional {
                    Button("Nothing special") { project.markDecided(step); project.wizardNext() }.help("Settles this question without writing anything for \(key.title.lowercased())")
                }
            }
        case .files:
            WizardFiles(step: step)
        case .scenes: SceneListEditor()
        case .scene(let id): sceneStep(id)
        case .go: GoPanel()
        case .build: BuildPanel()
        case .lookBoard: LookBoardView()
        case .palette: PaletteEditor()
        case .font(let k): FontPickerView(roles: [k])
        case .background: BackgroundPickerView()
        case .moods: MoodsPickerView()
        case .effectsPack: EffectsPickerView()
        case .asset(let id):
            if let row = project.assets.first(where: { $0.id == id }) { assetChoices(row) }
        case .summary(let area):
            VStack(alignment: .leading, spacing: 14) {
                summaryFacts(area)
                ChecksPanel(block: area)
                ValidateButton(gate: project.spec?.gateKeys(area: area).first ?? "", block: area)
            }
        case .soon:
            EmptyView()
        }
    }

    @ViewBuilder private func sceneStep(_ id: String) -> some View {
        if let s = project.showreel?.scenes.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(s.id).font(.headline.monospaced()); Text(s.durationLabel).foregroundStyle(.secondary) }
                if !s.text.isEmpty { Text("\u{201C}\(s.text)\u{201D}").font(.title3) }
                if !s.visual.isEmpty { Text("Seen: \(s.visual)").font(.callout).foregroundStyle(.secondary) }
                if !s.feeling.isEmpty { Text("Feeling: \(s.feeling)").font(.callout).foregroundStyle(.secondary) }
                SceneDecision(id: id)
                DisclosureGroup("Edit this scene") { SceneForm(id: id).padding(.top, 6) }
            }
        }
    }

    private func optionRow(_ o: WizardStep.Option, recommended: Bool, multi: Bool) -> some View {
        let on = picked.contains(o.value)
        let symbol = multi ? (on ? "checkmark.square.fill" : "square") : (on ? "largecircle.fill.circle" : "circle")
        return Button {
            custom = ""
            if multi { if on { picked.remove(o.value) } else { picked.insert(o.value) } } else { picked = [o.value] }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).foregroundStyle(on ? Color.accentColor : .secondary).padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(o.label).font(.body.weight(.medium))
                        if recommended { Text("Recommended").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 1).background(Color.accentColor.opacity(0.18), in: Capsule()) }
                    }
                    if !o.detail.isEmpty { Text(o.detail).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func assetChoices(_ row: AssetRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("\(row.id) · \(row.type)").font(.caption).foregroundStyle(.secondary); Text("now: \(row.status)").font(.caption.weight(.semibold)) }
            if !row.notes.isEmpty { Text(row.notes).font(.callout).foregroundStyle(.orange) }
            HStack {
                Button("Approve") { decide(row, .approved) }.buttonStyle(.borderedProminent)
                Button("Exclude") { decide(row, .excluded) }
                Button("Hold...") { holdNote = row.notes; holding = true }
            }
            Text("Nothing is used in the film until you approve it.").font(.caption).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $holding) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hold \(row.name)").font(.headline)
                TextField("Why is it on hold?", text: $holdNote, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { holding = false }.keyboardShortcut(.cancelAction)
                    Button("Hold") { holding = false; if project.perform(.asset(id: row.id, status: .hold, note: holdNote, licence: nil, scenes: nil)) { project.wizardNext() } }
                        .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                        .disabled(holdNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(18).frame(width: 420)
        }
    }

    private func decide(_ row: AssetRow, _ s: AssetStatus) {
        if project.perform(.asset(id: row.id, status: s, note: nil, licence: nil, scenes: nil)) { project.wizardNext() }
    }

    @ViewBuilder private func summaryFacts(_ block: String) -> some View {
        if let f = project.showreel {
            VStack(alignment: .leading, spacing: 6) {
                if block == "project" {
                    ForEach([ParameterKey.audience, .message, .tone, .conversationLanguage, .reelLanguages, .duration, .formats, .constraints], id: \.self) { k in
                        HStack(alignment: .top) {
                            Text(k.title).font(.callout.weight(.medium)).frame(width: 150, alignment: .leading)
                            Text(k.current(f).isEmpty ? "(to decide)" : k.current(f)).font(.callout).foregroundStyle(k.current(f).isEmpty ? .secondary : .primary)
                        }
                    }
                } else {
                    let a = project.assets
                    Text("\(a.count) files: \(a.filter { $0.status == "approved" }.count) approved, \(a.filter { $0.status == "excluded" }.count) excluded, \(a.filter { $0.status == "hold" }.count) on hold, \(a.filter { $0.status == "proposed" }.count) to decide.")
                        .font(.callout)
                }
            }
        }
    }

    // MARK: answers

    /// What is already recorded shows as the current choice (decided); otherwise nothing is chosen.
    private func load() {
        guard let f = project.showreel else { return }
        switch step.kind {
        case .single(let k, let options, _, _):
            let v = k.current(f)
            if options.contains(where: { $0.value == v }) { picked = [v] } else { custom = v }
        case .multi(let k, _, _): picked = Set(ParameterKey.list(k.current(f), lowercase: k == .reelLanguages))
        case .number(let k, let presets):
            let v = k.current(f).replacingOccurrences(of: " s", with: "")
            if presets.contains(where: { $0.value == v }) { picked = [v] } else { custom = v }
        case .text(let k, _, _): typed = k.current(f)
        default: break
        }
    }

    private var answer: (ParameterKey, String)? {
        switch step.kind {
        case .single(let k, _, _, _), .number(let k, _):
            if !custom.trimmingCharacters(in: .whitespaces).isEmpty { return (k, custom) }
            return picked.first.map { (k, $0) }
        case .multi(let k, let options, _):
            guard !picked.isEmpty else { return nil }
            return (k, options.map { $0.value }.filter { picked.contains($0) }.joined(separator: ", "))
        case .text(let k, _, _):
            return typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : (k, typed)
        default: return nil
        }
    }

    /// Why Next is not available, in the words of the rule below.
    private var nextReason: String {
        switch step.kind {
        case .single, .multi, .number, .text: return "Answer the question first"
        case .soon: return "This step is not built yet"
        default: return "Decide this step first, with the editor above"
        }
    }

    private var canNext: Bool {
        switch step.kind {
        case .single, .multi, .number, .text: return answer != nil || decided
        case .files, .asset, .summary, .scenes, .scene, .go, .build, .lookBoard, .palette, .font, .background, .moods, .effectsPack: return decided
        case .soon: return false
        }
    }

    private func next() {
        if let (k, v) = answer, !project.setParameter(k, v) { return }
        project.wizardNext()
    }

    private func suggest() {
        guard settings.hasKey else { showAIHelp = true; return }
        project.showCopilot = true
        chat.ask(prompt: Wizard.suggestionPrompt(step))
    }
}

/// The files step: drop or add files, or say there are none yet.
struct WizardFiles: View {
    let step: WizardStep
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8]))
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
                    Text(project.assets.isEmpty ? "Drop files here" : "\(project.assets.count) files added. Drop more, or go on.").font(.headline)
                    Button("Add files...") { choose() }
                }
                .padding(24)
            }
            .frame(height: 150)
            .dropTarget(.resourceList)      // the same drop as the workspace's resources list: added with the automatic checks
            if project.assets.isEmpty {
                Button("I have no files yet") { project.markDecided(step); project.wizardNext() }
            }
        }
    }

    private func choose() {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = true; p.prompt = "Add"
        if p.runModal() == .OK { project.addAssets(p.urls) }
    }
}

/// What the AI button says when no key is connected. The wizard goes on by hand.
struct ConnectAIHelp: View {
    @EnvironmentObject var chat: ChatModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggest with AI needs a key", systemImage: "sparkles").font(.headline)
            Text("This button asks Clap for a suggestion, shown as a card you accept or refuse. To use it, connect an AI in Settings: paste an API key (it is kept in the macOS Keychain) or set a gateway.")
                .font(.callout)
            Text("You do not need it. Every question can be answered by hand, and the wizard goes on without it.").font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Continue by hand") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Connect AI") { dismiss(); AppSettingsWindow.open() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18).frame(width: 440)
    }
}
