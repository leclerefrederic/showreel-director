import ShowreelKit
import SwiftUI

/// The project form, in sections: the base configuration of the film (formats, duration, languages), the brief, the control level. The same form is the set-up of a Manual
/// project (all of it, `part` nil) and the pieces of the settings panel (PT1): above the tabs the name and the compact base configuration, then the Brief and the Format. The rules (what is set, how far, what the duration allows) are ShowreelKit's `ProjectSetup`; typed text is recorded after a pause
/// through the typed operations, like everywhere.
struct ProjectForm: View {
    /// The pieces of the settings panel (PT1); nil is the whole form, as the set-up of a new project shows it.
    enum Part { case header, brief, format }
    @EnvironmentObject var theme: Theme
    /// The set-up of a new project: the look is chosen here too.
    var setup = false
    var part: Part?
    @EnvironmentObject var project: ProjectModel
    @State private var drafts: [ParameterKey: String] = [:]
    @State private var dirty: Set<ParameterKey> = []
    @State private var commitTask: DispatchWorkItem?

    private static let formats: [(id: String, name: String, w: CGFloat, h: CGFloat)] = [("16:9", "Desktop", 16, 9), ("9:16", "Mobile", 9, 16), ("1:1", "Square", 1, 1), ("4:5", "Portrait feed", 4, 5)]
    private static let presets = ProjectSetup.durationChoices
    private static let typed: [ParameterKey] = [.name, .audience, .message, .tone, .duration, .constraints]
    private static let examples: [ParameterKey: String] = [
        .audience: "For example: marketing leads at mid-size software companies, watching on a laptop",
        .message: "For example: plan the whole launch in one place",
        .tone: "For example: warm, confident, a little playful",
        .constraints: "For example: no customer names; every claim needs a source",
    ]

    var body: some View {
        let f = project.showreel
        VStack(alignment: .leading, spacing: 16) {
            if part == nil || part == .header, let f = f { progress(f) }
            if part == .header || (part == nil && !setup) { compact(.name, "Project name") }
            if part == nil || part == .format {
                section("Film", required: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        formatsRow(f)
                        durationRow(f)
                        languagesRow(f)
                    }
                }
            }
            if part == nil || part == .brief {
                section("Brief", required: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Optional. Say it in a few words; you can come back to it.").fontSmall().foregroundStyle(.secondary)
                        compact(.audience, "Audience"); compact(.message, "Message"); compact(.tone, "Tone"); compact(.constraints, "Constraints")
                    }
                }
                section("Control level", required: false) { controlCards(f) }
            }
        }
        .onAppear { load() }
        .onChange(of: project.showreel) { _ in load() }
        .onDisappear { commit() }
    }

    // MARK: the pieces

    private func section<C: View>(_ title: String, required: Bool, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.headline); if required { Text("Required").fontSmall(weight: .semibold).foregroundStyle(theme.warning).padding(.horizontal, 6).padding(.vertical, 1).background(theme.warning.opacity(0.14), in: Capsule()) } }
            content()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// "3 of 4 set" and what each of the four is.
    private func progress(_ f: ShowreelFile) -> some View {
        let p = ProjectSetup.progress(f)
        return VStack(alignment: .leading, spacing: 6) {
            HStack { Text("Base configuration").font(.headline); Spacer(); Text(p.line).font(.callout.weight(.semibold)).foregroundStyle(p.set == p.total ? theme.success : theme.warning) }
            ProgressView(value: Double(p.set), total: Double(p.total))
            HStack(spacing: 10) {
                ForEach(ProjectSetup.requirements(f)) { r in
                    let label = Label(r.title, systemImage: r.isSet ? "checkmark.circle.fill" : "circle").fontSmall().foregroundStyle(r.isSet ? theme.success : .secondary)
                    if part == .header {
                        // an item goes to the tab where it is set (PT1)
                        Button { project.settingsTab = ProjectTab.tab(forRequirement: r.id) } label: { label }.buttonStyle(.plain).help("Go to \(ProjectTab.tab(forRequirement: r.id).title)")
                    } else { label }
                }
            }
        }
    }

    private func formatsRow(_ f: ShowreelFile?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Formats").font(.subheadline.weight(.medium))
            HStack(spacing: 10) {
                ForEach(Self.formats, id: \.id) { fm in
                    let on = (f?.decisions.formats ?? []).contains(fm.id)
                    Button { toggleFormat(fm.id, !on) } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3).stroke(on ? Color.accentColor : Color.secondary, lineWidth: 1.5).background(RoundedRectangle(cornerRadius: 3).fill(on ? Color.accentColor.opacity(0.18) : .clear))
                                .aspectRatio(fm.w / fm.h, contentMode: .fit).frame(height: 34)
                                .frame(width: 44, height: 44)
                            Text(fm.id).fontSmall(weight: .semibold); Text(fm.name).fontSmall().foregroundStyle(.secondary)
                        }
                        .padding(8).background(on ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(on ? Color.accentColor : Color.primary.opacity(0.1)))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            if fm9x16(f) { Text("9:16 changes the layout design: decide it now.").fontSmall().foregroundStyle(.secondary) }
        }
    }
    private func fm9x16(_ f: ShowreelFile?) -> Bool { (f?.decisions.formats ?? []).contains("9:16") }

    private func durationRow(_ f: ShowreelFile?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Target duration").font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.self) { n in
                    let on = f?.decisions.duration == Double(n)
                    Button("\(n) s") { drafts[.duration] = String(n); dirty.insert(.duration); commit() }
                        .buttonStyle(ChipStyle(selected: on)).accessibilityAddTraits(on ? .isSelected : [])
                }
                StepperField(text: Binding(get: { drafts[.duration] ?? "" }, set: { drafts[.duration] = $0; dirty.insert(.duration); schedule() }), rule: NumericField(minimum: 5, maximum: 600), onStep: { schedule() }, onCommit: { commit() }, width: 96)
            }
            if let f = f, let h = ProjectSetup.durationHint(f) {
                Label(h.text, systemImage: h.level == .ok ? "checkmark.circle" : h.level == .fail ? "xmark.octagon" : "exclamationmark.triangle")
                    .fontSmall().foregroundStyle(h.level == .ok ? theme.success : h.level == .fail ? theme.danger : theme.warning).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func languagesRow(_ f: ShowreelFile?) -> some View {
        let codes = f?.reelLanguages ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("Film languages").font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                ForEach(Array(codes.enumerated()), id: \.element) { i, c in
                    HStack(spacing: 4) {
                        Text(ProjectLanguages.name(c)).font(.callout)
                        if i == 0 && codes.count > 1 { Text("master").fontSmall().foregroundStyle(.secondary) }
                        Button { setReel(codes.filter { $0 != c }) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Remove \(ProjectLanguages.name(c))")
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.accentColor.opacity(0.14), in: Capsule())
                }
                Menu("Add a language") {
                    ForEach(ProjectLanguages.all.filter { !codes.contains($0.code) }, id: \.code) { l in Button(l.name) { setReel(codes + [l.code]) } }
                }.menuStyle(.borderlessButton).fixedSize()
                if codes.isEmpty { Text("Pick at least one.").fontSmall().foregroundStyle(.secondary) }
            }
            Text(ParameterKey.reelLanguages.help).fontSmall().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func controlCards(_ f: ShowreelFile?) -> some View {
        let current = f?.parameters.controlLevel ?? "auto"
        return HStack(alignment: .top, spacing: 10) {
            ForEach(ControlLevel.allCases, id: \.rawValue) { l in
                Button { if l.rawValue != current { project.perform(.parameter(.controlLevel, l.rawValue)) } } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.title).font(.callout.weight(.semibold))
                        Text(l.help).fontSmall().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10).frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                    .background(current == l.rawValue ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(current == l.rawValue ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: current == l.rawValue ? 2 : 1))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }

    private func compact(_ k: ParameterKey, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.medium))
            TextField("", text: Binding(get: { drafts[k] ?? "" }, set: { drafts[k] = $0; dirty.insert(k); schedule() }), prompt: Text(Self.examples[k] ?? ""), axis: .vertical)
                .lineLimit(1...3).textFieldStyle(ThemedTextFieldStyle()).environment(\.fieldVerticalPadding, CGFloat(FormLayout.multilinePadding)).onSubmit { commit() }
        }
    }

    // MARK: what is typed is recorded after a pause, on Return and when the form is left

    private func load() {
        guard let f = project.showreel else { return }
        for k in Self.typed where !dirty.contains(k) { drafts[k] = k.current(f) }
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
            let draft = drafts[k] ?? ""
            var probe = f
            do { try k.set(draft, in: &probe) } catch { project.error = error.localizedDescription; dirty.remove(k); drafts[k] = k.current(f); continue }
            if k.current(probe) != k.current(f) { project.perform(.parameter(k, draft)) }
            dirty.remove(k)
        }
        load()
    }

    private func toggleFormat(_ id: String, _ on: Bool) {
        var l = project.showreel?.decisions.formats ?? []
        if on, !l.contains(id) { l.append(id) } else if !on { l.removeAll { $0 == id } }
        project.perform(.parameter(.formats, l.joined(separator: ", ")))
    }

    private func setReel(_ codes: [String]) { project.perform(.parameter(.reelLanguages, codes.joined(separator: ", "))) }
}
