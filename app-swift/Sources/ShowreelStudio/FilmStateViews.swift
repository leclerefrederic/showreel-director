import ShowreelKit
import SwiftUI

// The state of the film and of each scene, drawn. The rules (what is stale, which version is read, what can be assembled or generated, what a transition says) are
// ShowreelKit's `FilmBuild`, `Availability` and `TransitionNotes`; nothing here decides.

/// The mark of a scene's build: not generated, up to date, stale, or edited by hand. Square, so it is not mistaken for the review state (WIP, Validated, Locked), which is round.
/// The same component in the list, the reel, the tree and the inspector. Absent in the old format, which has no scene files.
struct BuildIndicator: View {
    let id: String
    var labelled = false
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        if project.film.state != .legacy, project.film.target != nil, let st = project.film.scenes[id] {
            let m = Self.mark(st)
            let lockedWhy = st.state == .stale ? Availability.regenerate(id, project.film, file: project.showreel).why?.message : nil
            HStack(spacing: 4) {
                Image(systemName: m.symbol).font(.system(size: 9, weight: .bold)).foregroundStyle(m.color)
                    .frame(width: 16, height: 16).background(m.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                if labelled { Text(m.title).font(.caption).foregroundStyle(.secondary) }
            }
            .help(lockedWhy.map { "Stale. " + $0 } ?? m.help)
        }
    }

    static func mark(_ s: SceneModules.Status) -> (symbol: String, color: Color, title: String, help: String) {
        switch s.state {
        case .notGenerated: return ("square.dashed", .gray, "Not generated", "Not generated: the film shows an empty frame with this scene's ID. Generate it with the AI.")
        case .stale: return ("arrow.triangle.2.circlepath", .orange, "Stale", "Stale: its content, length or look changed since its file was generated. Generate it again to follow the change.")
        case .upToDate:
            return s.moduleEdited ? ("square.and.pencil", .blue, "Edited by hand", "Edited by hand: the file is not the one that was generated. It is kept; the scene is not stale.")
                                  : ("checkmark", .green, "Generated", "Generated from its present content, length and look.")
        }
    }
}

/// The persistent badges of a scene, in the order the layout rule gives: the review state, then the build state. The same on the list, the tree, the reel and the inspector.
struct SceneBadges: View {
    let scene: ShowreelFile.Scene
    var size: CGFloat = 14
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MarkLayout.badges(for: scene, film: project.film), id: \.self) { b in
                switch b {
                case .review: SceneStateBadge(scene: scene, size: size)
                case .build: BuildIndicator(id: scene.id)
                }
            }
        }
    }
}

/// What a transition says about itself: drawn approximately at assembly, and whether its free instruction was used.
struct TransitionNoteView: View {
    let from: String
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        if let f = project.showreel, let n = TransitionNotes.note(after: from, in: f, store: project.store) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(n.lines, id: \.self) { Label($0, systemImage: "info.circle").font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }
}

extension ProjectModel {
    /// The tooltip of a transition marker: what it is, and what to know about it.
    func transitionHelp(from id: String, base: String) -> String {
        guard let f = showreel, let n = TransitionNotes.note(after: id, in: f, store: store) else { return base }
        return ([base] + n.lines).joined(separator: "\n")
    }
}

/// The small label that says a thumbnail is the quick draft, not the assembled film.
struct PreviewTag: View {
    var text = "Preview: a quick draft, not the assembled film"
    var body: some View {
        Label(text, systemImage: "eye").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 3).background(Color.primary.opacity(0.07), in: Capsule())
    }
}

/// The reel header's counter: "Film up to date", "Film stale", "2 scenes to generate", "Old format", and the way to the next step.
struct FilmStatusChip: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let f = project.film
        HStack(spacing: 6) {
            Circle().fill(color(f)).frame(width: 8, height: 8)
            Text(f.counter).font(.system(size: 11, weight: .semibold))
            if f.state == .stale || (f.state == .neverAssembled && f.target != nil && f.state != .legacy) {
                Button(project.assembling ? "Assembling\u{2026}" : "Assemble") { project.assembleFilm() }
                    .buttonStyle(.borderless).font(.system(size: 11, weight: .semibold))
                    .disabledWithReason(project.assembling ? "Assembling" : Availability.assemble(f, in: project.activity).reasonText, way: Availability.assemble(f, in: project.activity).wayText)
            }
        }
        .help(f.staleLine ?? (f.state == .legacy ? FilmBuild.legacySentence : f.ungenerated.isEmpty ? "The assembled film matches the project." : "Scenes with no file are shown as empty frames until they are generated."))
    }

    private func color(_ f: FilmBuild.Status) -> Color {
        if f.state == .legacy || f.state == .neverAssembled { return .gray }
        return f.isOK ? .green : .orange
    }
}

/// The banners of the viewer: an incomplete version, the old format, a failed assembly, a film never assembled or stale (with Assemble), and scenes not generated (with the
/// one card that offers to generate them).
struct FilmBanners: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let f = project.film
        let locked = Set((project.showreel?.scenes ?? []).filter { $0.isLocked }.map { $0.id })
        let want = f.toGenerate
        let offer = GenerationOffer(ids: want.filter { !locked.contains($0) }, excluded: want.filter { locked.contains($0) }.map { ($0, SceneLock.reason($0)) },
                                    handEdited: want.filter { !locked.contains($0) && (f.scenes[$0]?.moduleEdited ?? false) }, missing: f.ungenerated)
        VStack(spacing: 6) {
            ForEach(f.incomplete, id: \.self) { v in
                banner("Version \(v) is incomplete (the build was stopped). Build again, or generate the missing scenes.", symbol: "exclamationmark.triangle", tint: .orange)
            }
            if f.state == .legacy { banner(FilmBuild.legacySentence, symbol: "clock.arrow.circlepath", tint: .gray) }
            if let e = project.assemblyError {
                banner(e, symbol: "xmark.octagon", tint: .red) { Button("Dismiss") { project.assemblyError = nil }.buttonStyle(.borderless).font(.caption) }
            }
            if f.state == .neverAssembled, f.playable == nil, f.target != nil {
                banner("The film has not been assembled yet: there is nothing to play.", symbol: "film", tint: .gray) { assembleButton(f) }
            } else if let line = f.staleLine {
                banner(line + ".", symbol: "arrow.triangle.2.circlepath", tint: .orange) { assembleButton(f) }
            }
            if let line = offer.staleLine, f.state != .legacy { banner(line + ".", symbol: "arrow.triangle.2.circlepath", tint: .orange) }
            if (offer.bannerLine != nil || offer.staleLine != nil), f.state != .legacy {
                banner(offer.bannerLine.map { $0 + "." } ?? "Generate again to follow the changes.", symbol: "square.dashed", tint: .orange) {
                    let a = Availability.generate(offer.ids, f, in: project.activity, hasKey: AppSettings.shared.hasKey, file: project.showreel)
                    Button("Generate \(offer.ids.count) scene\(offer.ids.count == 1 ? "" : "s")") { project.offerGeneration() }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .disabledWithReason(a.reasonText, way: a.wayText)
                }
                ForEach(offer.excluded, id: \.id) { x in Text("\(x.id) is left out of the offer: \(x.reason).").font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }

    private func assembleButton(_ f: FilmBuild.Status) -> some View {
        let a = Availability.assemble(f, in: project.activity)
        return Button(project.assembling ? "Assembling\u{2026}" : "Assemble") { project.assembleFilm() }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .disabledWithReason(project.assembling ? "Assembling the film" : a.reasonText, way: project.assembling ? nil : a.wayText)
            .help("Assemble the film from the scene files: free, no AI")
    }

    private func banner<A: View>(_ text: String, symbol: String, tint: Color, @ViewBuilder action: () -> A = { EmptyView() }) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 16)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Spacer(minLength: 6)
            action()
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// The one card that offers to generate scenes: which files, how many calls, the cost as an estimate, and the scenes left out. Nothing is asked of the AI before the yes.
struct GenerateScenesSheet: View {
    let pending: PendingGeneration
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(pending.card.title, systemImage: ClapMark.symbol).font(.headline)
            VStack(alignment: .leading, spacing: 8) { ForEach(Array(pending.card.changes.enumerated()), id: \.offset) { _, c in ChangeRow(change: c) } }
            ForEach(pending.handEdited, id: \.self) { id in
                Toggle(isOn: Binding(get: { pending.overwrite.contains(id) }, set: { _ in project.toggleOverwrite(id) })) {
                    Text("\(id) was edited by hand. Generate it too, and overwrite my edit.").font(.callout)
                }.toggleStyle(.checkbox)
            }
            ForEach(pending.excluded, id: \.id) { x in Text("\(x.id) is left out: \(x.reason).").font(.caption).foregroundStyle(.secondary) }
            Text("The project is read-only while the scenes are generated. Cancel stops the request; what was not written is not written.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { project.generationOffer = nil }.keyboardShortcut(.cancelAction)
                Button("Generate \(pending.all.count) scene\(pending.all.count == 1 ? "" : "s")") { project.confirmGeneration() }.buttonStyle(.borderedProminent)
                    .disabledWithReason(pending.all.isEmpty ? "No scene is selected" : nil, way: "Tick a hand-edited scene to overwrite it")
            }
        }
        .padding(20).frame(width: 460)
    }
}

/// The card of "Build a new version": how many scenes are written and why, how many are reused unchanged, the calls and a rough cost. Nothing is asked of the AI before the yes.
/// A Build that stopped is offered to continue, or to start over after a confirmation. When nothing changed, only Assemble is offered.
struct BuildConfirmSheet: View {
    let pending: PendingBuild
    @EnvironmentObject var project: ProjectModel
    @State private var confirmOver = false
    @State private var confirmAll = false

    private var unlocked: Int { project.showreel?.film.filter { !$0.isLocked }.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(pending.card.title, systemImage: ClapMark.symbol).font(.headline)
            if pending.plan.unchanged {
                Text("Every scene is up to date. Assemble puts the montage, the transitions and the music as they are now into the film, with no request.").font(.callout)
            }
            VStack(alignment: .leading, spacing: 8) { ForEach(Array(pending.card.changes.enumerated()), id: \.offset) { _, c in ChangeRow(change: c) } }
            ForEach(pending.plan.handEdited, id: \.self) { id in
                Toggle(isOn: Binding(get: { pending.overwrite.contains(id) }, set: { _ in project.toggleBuildOverwrite(id) })) {
                    Text("\(id) was edited by hand and is out of date. Write it again too, and overwrite my edit.").font(.callout)
                }.toggleStyle(.checkbox)
            }
            if !pending.plan.unchanged {
                Text("The project is read-only while the film is written. Each file is saved as soon as it is written, so a stop loses only the scene being written. Cancel build stops it; you can continue from where it stopped.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                if pending.resuming { Button("Start over\u{2026}") { confirmOver = true }.help("Remove what this Build already wrote and begin again") }
                Button("Rewrite everything\u{2026}") { confirmAll = true }
                    .disabledWithReason(unlocked == 0 ? "Every scene is locked" : nil, way: "Unlock a scene to write it again")
                    .help("Write every scene that is not locked again, whatever its state")
                Spacer()
                Button("Cancel", role: .cancel) { project.buildOffer = nil }.keyboardShortcut(.cancelAction)
                if pending.plan.unchanged {
                    Button("Assemble") { project.assembleInsteadOfBuild() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                } else {
                    Button(pending.resuming ? "Continue the build" : "Build \(pending.version)") { project.confirmBuild() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20).frame(width: 520)
        .alert("Start \(pending.version) over?", isPresented: $confirmOver) {
            Button("Start over", role: .destructive) { project.startOverBuild() }
            Button("Keep what is written", role: .cancel) {}
        } message: { Text("The scene files, project.json and reel.js already written in \(pending.version) are removed, including any scene file you edited by hand. film.json stays.") }
        .alert("Rewrite all \(unlocked) scenes?", isPresented: $confirmAll) {
            Button("Rewrite everything", role: .destructive) { project.rewriteEverything() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("That is \(unlocked + 1) requests (the frame of the film and \(unlocked) scene\(unlocked == 1 ? "" : "s"), about \(unlocked + 1) min) even for scenes that did not change. Locked scenes are kept. Edits you made by hand in the scenes that are not locked are lost.") }
    }
}

/// The layout warnings found by the scenes' own tests, scene by scene. They are a matter of taste (a text that overlaps may be wanted): nothing is repaired by itself, and
/// "Fix this scene" is one generation of that scene, with the warnings as its instruction, behind a confirmation card. A locked scene cannot be fixed.
struct LayoutWarningsSheet: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Layout warnings", systemImage: "exclamationmark.triangle").font(.headline)
            if project.layoutWarnings.isEmpty { Text("None left.").foregroundStyle(.secondary) }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(project.layoutWarnings.keys.sorted(), id: \.self) { id in
                        let list = project.layoutWarnings[id] ?? []
                        let locked = project.showreel?.scenes.first { $0.id == id }?.isLocked == true
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(id): \(list.count) warning\(list.count == 1 ? "" : "s")").font(.callout.weight(.semibold))
                                Spacer()
                                Button("Fix this scene") { project.fixLayout(id) }
                                    .disabledWithReason(locked ? "\(id) is locked" : nil, way: "Unlock the scene first")
                            }
                            ForEach(Array(list.prefix(4).enumerated()), id: \.offset) { _, w in Text(w).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                        }
                    }
                }
            }.frame(maxHeight: 320)
            Text("A text that overlaps or leaves the stage is sometimes wanted, so nothing is changed unless you ask. Fixing a scene writes it again (one request) after a card.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Close") { project.showLayoutWarnings = false }.keyboardShortcut(.cancelAction) }
        }
        .padding(20).frame(width: 520)
    }
}
