import AppKit
import ShowreelKit
import SwiftUI

// MARK: inspectors

/// The passage between two scenes: type from the library, duration, parameters, an instruction for the AI.
struct TransitionInspector: View {
    let from: String
    @EnvironmentObject var project: ProjectModel
    @State private var duration = ""
    @State private var params = ""
    @State private var instruction = ""

    private var pair: (item: ShowreelFile.Transition, next: ShowreelFile.Scene)? { project.showreel?.transition(after: from) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorHeader(title: "\(from) \u{2192} \(pair?.next.id ?? "?")", subtitle: "Transition")
            if let p = pair {
                InspectorSection(title: "Type") {
                    // the catalogue with the engine's previews; a transition that does not run between two real scenes stays visible but cannot be chosen
                    PickerButton(kind: .transition, current: p.item.isCut ? "cut" : p.item.type, none: ("cut", "Cut on beat (default)")) {
                        project.choose(.transition, $0, for: .marker(from: from))
                    }
                    if Look.isPreviewOnly(p.item.type) { Label("Preview only: it does not run between two real scenes. Choose another or a cut.", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
                    if let lib = Look.transitions().first(where: { $0.name == p.item.type }) { Text(lib.desc).font(.caption).foregroundStyle(.secondary) }
                    TransitionNoteView(from: from)
                }
                if !p.item.isCut {
                    InspectorSection(title: "Timing and parameters") {
                        TextField("Duration (s)", text: $duration).textFieldStyle(.roundedBorder).frame(maxWidth: 140)
                        TextField("Parameters (key=value, key=value)", text: $params).textFieldStyle(.roundedBorder)
                    }
                }
                InspectorSection(title: "Instruction for the AI (optional)") {
                    TextField("For a match cut: which element becomes which", text: $instruction, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Apply") { apply(p.item) }.buttonStyle(.borderedProminent).disabledWithReason(dirty(p.item) ? nil : "Nothing changed yet")
                    Button("Revert to a cut") { project.setTransition(from: from, nil) }.disabledWithReason(p.item.isCut && p.item.instruction == nil ? "It already is a cut" : nil)
                }
                Text("A transition overlaps the end of \(from) and the start of \(p.next.id); the film's length does not change. It is data for the build today: the reel player cuts hard until the transition compositor exists.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("\(from) is the last scene that is on: a transition sits between two scenes.").font(.callout).foregroundStyle(.secondary)
            }
        }
        .onAppear { load() }
        .onChange(of: project.showreel) { _ in load() }
    }

    private func load() {
        guard let p = pair else { return }
        duration = p.item.duration.map { ProjectDocs.seconds($0) } ?? ""; params = paramsText(p.item)
        instruction = p.item.instruction ?? ""
    }

    private func paramsText(_ t: ShowreelFile.Transition) -> String { ShowreelFile.ContentAnimation(mode: "effect", effect: t.type, params: t.params).paramsText }

    private func dirty(_ t: ShowreelFile.Transition) -> Bool {
        duration != (t.duration.map { ProjectDocs.seconds($0) } ?? "") || params != paramsText(t) || instruction != (t.instruction ?? "")
    }

    private func apply(_ t: ShowreelFile.Transition) {
        var e = TransitionEdit()
        if !t.isCut {
            if duration != (t.duration.map { ProjectDocs.seconds($0) } ?? ""), let d = Double(duration.replacingOccurrences(of: ",", with: ".")) { e.duration = d }
            if params != paramsText(t) { e.params = params }
        }
        if instruction != (t.instruction ?? "") { e.instruction = instruction }
        if e != TransitionEdit() { project.setTransition(from: from, e) }
    }
}

/// The project's music: the track, its analysis, and the corrections of the tempo and of the first beat.
struct MusicInspector: View {
    @EnvironmentObject var project: ProjectModel
    @State private var bpm = ""
    @State private var firstBeat = ""

    private var track: ShowreelFile.Track? { project.showreel?.decisions.track }
    private var audio: [AssetRow] { project.assets.filter { $0.type == "audio" && $0.status == "approved" && !$0.file.isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let t = track, let f = t.file {
                HStack { Image(systemName: "waveform"); Text((f as NSString).lastPathComponent).lineLimit(1); Spacer(); Button("Remove") { project.attachTrack(nil) }.buttonStyle(.borderless) }
            } else {
                Text("No music. Only approved audio files can be used.").font(.callout).foregroundStyle(.secondary)
            }
            Menu(track?.file == nil ? "Attach music..." : "Change music...") {
                if audio.isEmpty { Text("No approved audio resource: add and approve one in the library") }
                ForEach(audio) { a in Button(a.name) { project.attachTrack(a.id) } }
            }.menuStyle(.borderlessButton).fixedSize()
            if project.analysing { HStack { ProgressView().controlSize(.small); Text("Analysing the track...").font(.callout).foregroundStyle(.secondary) } }
            if let m = project.music {
                Text("\(ProjectDocs.seconds(m.bpm)) BPM · first beat \(ProjectDocs.seconds(m.firstBeat)) s · \(m.bars.count) bars · constant tempo (the analysis assumes it)\(track?.manual == true ? " · corrected by you" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                if let d = m.strongestDrop { Text("Strongest drop at \(ProjectDocs.seconds(d)) s" + (m.breaks.isEmpty ? "" : ", \(m.breaks.count) break\(m.breaks.count == 1 ? "" : "s") marked")).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    TextField("BPM", text: $bpm).textFieldStyle(.roundedBorder).frame(width: 80)
                    TextField("First beat (s)", text: $firstBeat).textFieldStyle(.roundedBorder).frame(width: 110)
                    Button("Recompute the grid") { project.correctGrid(bpm: Double(bpm.replacingOccurrences(of: ",", with: ".")), firstBeat: Double(firstBeat.replacingOccurrences(of: ",", with: "."))) }
                        .disabled(project.analysing || (Double(bpm.replacingOccurrences(of: ",", with: ".")) == nil && Double(firstBeat.replacingOccurrences(of: ",", with: ".")) == nil))
                }
                Text("If the grid is off, give the real tempo and/or the time of a real first beat. Check by ear: tempo changes are not followed.").font(.caption2).foregroundStyle(.tertiary)
            } else if let n = project.musicNotice { Text(n).font(.caption).foregroundStyle(.orange) }
        }
        .onAppear { load() }
        .onChange(of: project.music) { _ in load() }
    }

    private func load() {
        if let m = project.music { bpm = ProjectDocs.seconds(m.bpm); firstBeat = ProjectDocs.seconds(m.firstBeat) } else { bpm = ""; firstBeat = "" }
    }
}
