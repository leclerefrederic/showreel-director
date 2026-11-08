import AppKit
import ShowreelKit
import SwiftUI

private func timeText(_ t: Double) -> String {
    let m = Int(t) / 60, s = t - Double(m * 60)
    return String(format: "%d:%04.1f", m, s)
}

/// The storyboard as a film reel: frames sized by their duration on a time ruler, transition markers between them, the music underneath
/// with its grid, and a playhead. Dragging an edge changes a duration (snapped to the grid), dragging a frame reorders. The views call
/// typed operations through the model; the rules live in ShowreelKit.
struct FilmStrip: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            ReelHeader()
            Divider()
            if let f = project.showreel, f.storyboards.first != nil {
                if f.library.isEmpty {
                    Text("The storyboard is empty. Create scenes in the library: each one you switch on appears here, in order.")
                        .font(.callout).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                } else {
                    ReelScroll(f: f)
                    OffRow(f: f)
                }
            } else { Spacer() }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

struct ReelHeader: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 12) {
            Label("Storyboard", systemImage: "film.stack").font(.headline)
            if let f = project.showreel {
                Text(summary(f)).font(.callout).foregroundStyle(.secondary)
                let worst = Checks.worst((project.checks["storyboard"] ?? []) + (project.checks["scene"] ?? []))
                Image(systemName: worst.symbol).foregroundStyle(worst.color).help("Film-level checks: see the Checks menu")
                Text(timeText(project.playhead)).font(.callout.monospacedDigit()).foregroundStyle(.secondary).help("Playhead")
                Spacer()
                Picker("Snap", selection: Binding(get: { f.snapLevel() }, set: { project.setGridSettings(snap: $0) })) {
                    ForEach(SnapLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .frame(width: 130).help("Stretching a scene snaps to this level of the music grid. Hold Option to bypass it.")
                Toggle("Ripple", isOn: Binding(get: { f.ripple() }, set: { project.setGridSettings(ripple: $0) }))
                    .toggleStyle(.checkbox).help("On: the scenes after a stretched one move with it. Off: they stay where they are.")
                Slider(value: $project.pps, in: 20...220).frame(width: 90).help("Zoom")
                addMenu(f)
                ValidateButton(gate: "storyboard", block: "storyboard")
                GoButton()
            } else { Spacer() }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(.bar)
    }

    private func summary(_ f: ShowreelFile) -> String {
        var t = "\(f.film.count) scene\(f.film.count == 1 ? "" : "s") on"
        if let e = f.filmEnd { t += " · \(ProjectDocs.seconds(e)) s" }
        if let d = f.decisions.duration { t += " of \(ProjectDocs.seconds(d)) s" }
        return t
    }

    /// Scenes of the library that are not in the film: one click puts them at the end.
    private func addMenu(_ f: ShowreelFile) -> some View {
        let on = Set(f.film.map { $0.id })
        let off = f.library.filter { !on.contains($0.id) }
        return Menu {
            if off.isEmpty { Text("Every scene of the library is on") }
            ForEach(off) { s in Button("\(s.id)  \(s.text.isEmpty ? "(no text)" : String(s.text.prefix(30)))") { project.place(s.id, before: nil) } }
        } label: { Label("Add scene", systemImage: "plus") }
        .menuStyle(.borderlessButton).fixedSize().help("Add a scene of the library to the film")
    }
}

struct ReelScroll: View {
    let f: ShowreelFile
    @EnvironmentObject var project: ProjectModel
    private let frameH: CGFloat = 78

    var body: some View {
        let pps = CGFloat(project.pps)
        let tl = f.timeline()
        let seconds = max(tl.last?.end ?? 0, project.music?.duration ?? project.trackDuration, f.decisions.duration ?? 0, 8)
        let width = CGFloat(seconds) * pps + 120
        ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    ReelRuler(width: width, pps: pps).frame(width: width, height: 20)
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(width: width, height: frameH)
                            .dropDestination(for: String.self) { ids, _ in
                                guard let id = ids.first, !id.contains(":") else { return false }
                                project.place(id, before: nil); return true
                            }
                        ForEach(Array(tl.enumerated()), id: \.element.scene.id) { i, t in
                            FrameView(timed: t, previous: i > 0 ? tl[i - 1].scene.id : nil, pps: pps, height: frameH)
                                .offset(x: CGFloat(t.start ?? 0) * pps)
                        }
                        ForEach(Array(tl.enumerated()), id: \.element.scene.id) { i, t in
                            if i + 1 < tl.count {
                                TransitionMarker(from: t.scene.id, transition: t.item.transition)
                                    .offset(x: CGFloat(tl[i + 1].start ?? t.end ?? 0) * pps - 11, y: frameH - 26)
                            }
                        }
                    }
                    .frame(width: width, height: frameH)
                    MusicLane(width: width, pps: pps).frame(width: width, height: 54)
                }
                Rectangle().fill(Color.red).frame(width: 1.5)
                    .frame(height: 20 + frameH + 54 + 8)
                    .offset(x: CGFloat(project.playhead) * pps).allowsHitTesting(false)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
        }
    }
}

/// Seconds, or the bars of the music when it is analysed. Click or drag to place the playhead.
struct ReelRuler: View {
    let width: CGFloat
    let pps: CGFloat
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        Canvas { ctx, size in
            let line = Color.secondary.opacity(0.5)
            if let m = project.music {
                let every = max(1, Int((46 / (CGFloat(m.bars.count > 1 ? m.bars[1] - m.bars[0] : 2) * pps)).rounded(.up)))
                for (i, b) in m.bars.enumerated() where i % every == 0 {
                    let x = CGFloat(b) * pps
                    ctx.fill(Path(CGRect(x: x, y: 8, width: 1, height: 12)), with: .color(line))
                    ctx.draw(Text("\(i + 1)").font(.system(size: 9)).foregroundColor(.secondary), at: CGPoint(x: x + 8, y: 6))
                }
            } else {
                let step: Double = pps > 100 ? 1 : pps > 45 ? 2 : 5
                var t = 0.0
                while CGFloat(t) * pps < size.width {
                    let x = CGFloat(t) * pps
                    ctx.fill(Path(CGRect(x: x, y: 8, width: 1, height: 12)), with: .color(line))
                    ctx.draw(Text(timeText(t)).font(.system(size: 9)).foregroundColor(.secondary), at: CGPoint(x: x + 14, y: 6))
                    t += step
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { project.playhead = max(0, Double($0.location.x / pps)) })
        .help(project.music == nil ? "Seconds" : "Bars of the music")
    }
}

/// One scene of the film: its thumbnail sized by its duration, ID, review state, on/off, and two edges to drag.
struct FrameView: View {
    let timed: TimedScene
    let previous: String?
    let pps: CGFloat
    let height: CGFloat
    @EnvironmentObject var project: ProjectModel
    @State private var targeted = false
    @State private var dragging: (edge: Int, dx: CGFloat)?

    private var scene: ShowreelFile.Scene { timed.scene }
    private var width: CGFloat { max(34, CGFloat(timed.length ?? 3) * pps) }
    private var selected: Bool { project.selection.sceneID == scene.id }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SceneThumb(scene: scene, still: true).frame(width: width, height: height).clipped()
            Text(scene.id).font(.caption2.monospaced().weight(.bold)).padding(.horizontal, 5).padding(.vertical, 1)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(.white).padding(4)
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: scene.statusSymbol).font(.caption).foregroundStyle(scene.statusColor).padding(3).background(.black.opacity(0.45), in: Circle())
                    Button { project.setEnabled(scene.id, false) } label: { Image(systemName: "eye.slash").font(.caption) }
                        .buttonStyle(.borderless).help("Switch off: the scene stays in the library")
                }.padding(3)
                Spacer()
                HStack {
                    Text(timed.length.map { ProjectDocs.seconds($0) + " s" } ?? "no duration").font(.caption2.monospacedDigit())
                        .padding(.horizontal, 4).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3)).foregroundStyle(.white)
                    Spacer()
                }.padding(4)
            }
            .frame(width: width, height: height)
            HStack(spacing: 0) {
                edge(0).opacity(previous == nil ? 0 : 1).allowsHitTesting(previous != nil)
                Spacer(minLength: 0)
                edge(1)
            }
            .frame(width: width, height: height)
            if let d = dragging { dragLabel(d) }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(targeted || selected ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: targeted || selected ? 3 : 1))
        .contentShape(Rectangle())
        .onTapGesture { project.select(.scene(scene.id)); if let s = timed.start { project.playhead = s } }
        .draggable(scene.id)
        .dropDestination(for: String.self, action: { ids, _ in
            guard let id = ids.first, id != scene.id, !id.contains(":") else { return false }
            project.place(id, before: scene.id); return true
        }, isTargeted: { targeted = $0 })
    }

    /// An edge: the left one moves the cut with the scene before, the right one changes this scene's duration.
    private func edge(_ side: Int) -> some View {
        Rectangle().fill(Color.accentColor.opacity(dragging?.edge == side ? 0.9 : 0.35)).frame(width: 7)
            .contentShape(Rectangle())
            .onHover { $0 ? NSCursor.resizeLeftRight.set() : NSCursor.arrow.set() }
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { dragging = (side, $0.translation.width) }
                .onEnded { v in
                    dragging = nil
                    let dt = Double(v.translation.width / pps), bypass = NSEvent.modifierFlags.contains(.option)
                    guard let start = timed.start else { return }
                    if side == 1, let end = timed.end { project.stretch(scene: scene.id, toEnd: end + dt, bypass: bypass) }
                    else if side == 0, let p = previous { project.moveCut(before: p, after: scene.id, to: start + dt, bypass: bypass) }
                })
            .help(side == 0 ? "Drag to move the cut with the previous scene" : "Drag to change the duration. Snaps to the grid; hold Option to bypass.")
    }

    private func dragLabel(_ d: (edge: Int, dx: CGFloat)) -> some View {
        let dt = Double(d.dx / pps), bypass = NSEvent.modifierFlags.contains(.option)
        let t = d.edge == 1 ? (timed.end ?? 0) + dt : (timed.start ?? 0) + dt
        let s = project.snapped(t, bypass: bypass)
        return Text(timeText(s)).font(.caption2.monospacedDigit().weight(.bold)).padding(3).background(Color.accentColor, in: RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(.white).frame(width: width, height: height, alignment: d.edge == 1 ? .topTrailing : .topLeading).padding(.top, 24)
    }
}

/// The passage to the next scene. A diamond for the default cut, a filled marker for a named transition; a transition dropped from the library lands here.
struct TransitionMarker: View {
    let from: String
    let transition: ShowreelFile.Transition
    @EnvironmentObject var project: ProjectModel
    @State private var targeted = false

    var body: some View {
        let selected = project.selection == .transition(from)
        ZStack {
            Circle().fill(transition.isCut ? Color(nsColor: .controlBackgroundColor) : Color.accentColor).frame(width: 22, height: 22)
            Image(systemName: transition.isCut ? "scissors" : "arrow.left.arrow.right").font(.system(size: 10, weight: .bold))
                .foregroundStyle(transition.isCut ? Color.secondary : .white)
        }
        .overlay(Circle().stroke(targeted || selected ? Color.accentColor : Color.primary.opacity(0.35), lineWidth: targeted || selected ? 3 : 1))
        .contentShape(Circle())
        .help(transition.text)
        .onTapGesture { project.selectTransition(from: from) }
        .dropDestination(for: String.self, action: { ids, _ in
            guard let p = ids.first, p.hasPrefix("transition:") else { return false }
            project.selectTransition(from: from)
            return project.setTransition(from: from, TransitionEdit(type: String(p.dropFirst(11))))
        }, isTargeted: { targeted = $0 })
    }
}

/// The project's music under the reel: waveform drawn by the app, the grid of the analysis, the strongest drop and the breaks.
struct MusicLane: View {
    let width: CGFloat
    let pps: CGFloat
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            if project.showreel?.decisions.track?.file == nil {
                RoundedRectangle(cornerRadius: 6).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(.tertiary)
                    .frame(width: min(width, 520), height: 40)
                    .overlay(Text("No music. Attach an approved audio file in the Inspector (nothing selected) to time the film against it.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8))
            } else {
                Canvas { ctx, size in
                    let mid = size.height / 2
                    if let m = project.music {
                        for b in m.breaks { ctx.fill(Path(CGRect(x: CGFloat(b.start) * pps, y: 0, width: CGFloat(b.end - b.start) * pps, height: size.height)), with: .color(.orange.opacity(0.16))) }
                    }
                    let dur = max(project.trackDuration, project.music?.duration ?? 0)
                    let n = project.waveform.count
                    if n > 0, dur > 0 {
                        var x: CGFloat = 0
                        let end = CGFloat(dur) * pps
                        while x < min(end, size.width) {
                            let i = min(n - 1, Int(Double(x / pps) / dur * Double(n)))
                            let h = max(1, CGFloat(project.waveform[i]) * (size.height - 6))
                            ctx.fill(Path(CGRect(x: x, y: mid - h / 2, width: 1.5, height: h)), with: .color(.accentColor.opacity(0.55)))
                            x += 2
                        }
                    }
                    if let m = project.music {
                        let spacing = CGFloat(60 / max(m.bpm, 1)) * pps
                        if spacing >= 6 { for b in m.beats { ctx.fill(Path(CGRect(x: CGFloat(b) * pps, y: size.height - 8, width: 1, height: 8)), with: .color(.secondary.opacity(0.6))) } }
                        for b in m.bars { ctx.fill(Path(CGRect(x: CGFloat(b) * pps, y: 0, width: 1, height: size.height)), with: .color(.secondary.opacity(0.28))) }
                        if let d = m.strongestDrop {
                            ctx.fill(Path(CGRect(x: CGFloat(d) * pps - 1, y: 0, width: 2.5, height: size.height)), with: .color(.red))
                            ctx.draw(Text("strongest drop").font(.system(size: 9, weight: .bold)).foregroundColor(.red), at: CGPoint(x: CGFloat(d) * pps + 48, y: 7))
                        }
                        for b in m.breaks { ctx.draw(Text("break").font(.system(size: 9)).foregroundColor(.orange), at: CGPoint(x: CGFloat(b.start) * pps + 18, y: size.height - 12)) }
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { project.playhead = max(0, Double($0.location.x / pps)) })
                if project.analysing { ProgressView().controlSize(.small).padding(6) }
                else if project.music == nil { Text(project.musicNotice ?? "Not analysed: the grid is a plain time ruler.").font(.caption).foregroundStyle(.orange).padding(6) }
            }
        }
    }
}

/// Scenes that are not in the film.
struct OffRow: View {
    let f: ShowreelFile
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let on = Set(f.film.map { $0.id })
        let off = f.library.filter { !on.contains($0.id) }
        if !off.isEmpty {
            HStack(spacing: 6) {
                Text("Off:").font(.caption).foregroundStyle(.secondary)
                ForEach(off) { s in
                    Button { project.place(s.id, before: nil) } label: { Label(s.id, systemImage: "eye") }.buttonStyle(.bordered).controlSize(.mini)
                        .help("Switch on: at the end of the film")
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 3)
        }
    }
}

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
                    // a transition that does not run between two real scenes stays visible but cannot be chosen
                    Menu {
                        Button("Cut on beat (default)") { project.setTransition(from: from, TransitionEdit(type: "cut")) }
                        Divider()
                        ForEach(Look.transitions(), id: \.name) { t in
                            Button(Look.isPreviewOnly(t.name) ? "\(t.name) (preview only)" : "\(t.name) · \(t.energy)") { project.setTransition(from: from, TransitionEdit(type: t.name)) }
                                .disabled(Look.isPreviewOnly(t.name))
                        }
                    } label: { Text(p.item.isCut ? "Cut on beat (default)" : p.item.type) }
                    .menuStyle(.borderlessButton).fixedSize()
                    if Look.isPreviewOnly(p.item.type) { Label("Preview only: it does not run between two real scenes. Choose another or a cut.", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
                    if let lib = Look.transitions().first(where: { $0.name == p.item.type }) { Text(lib.desc).font(.caption).foregroundStyle(.secondary) }
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
                    Button("Apply") { apply(p.item) }.buttonStyle(.borderedProminent).disabled(!dirty(p.item))
                    Button("Revert to a cut") { project.setTransition(from: from, nil) }.disabled(p.item.isCut && p.item.instruction == nil)
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
