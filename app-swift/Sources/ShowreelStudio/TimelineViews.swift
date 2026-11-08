import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// The storyboard strip, as an editing timeline: a dark lane stack (ruler, frames, music) that fills its panel, a time scale that can be zoomed and scrolled,
/// a toolbar with the transport. Every number it draws from (scale, sizes, ticks, what a frame shows, where a marker sits) is ShowreelKit's `Timeline.swift`;
/// the views only draw it and relay the gestures to typed operations.

enum StripColor {
    static let bg = Color(red: 0.075, green: 0.078, blue: 0.095)
    static let lane = Color(red: 0.118, green: 0.122, blue: 0.145)
    static let ruler = Color(red: 0.098, green: 0.102, blue: 0.125)
    static let frame = Color(red: 0.17, green: 0.176, blue: 0.21)
    static let line = Color.white.opacity(0.24)
    static let text = Color.white.opacity(0.94)
    static let dim = Color.white.opacity(0.66)
    static let wave = Color(red: 0.38, green: 0.66, blue: 1.0)
    static let playhead = Color(red: 1.0, green: 0.33, blue: 0.30)
    static let font = 11.0     // nothing under 11 pt
}

struct StripScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct FilmStrip: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        GeometryReader { geo in
            let f = project.showreel
            let on = Set(f?.film.map { $0.id } ?? [])
            let off = (f?.library ?? []).filter { !on.contains($0.id) }
            let offH = off.isEmpty ? 0.0 : 30.0
            let sizes = TimelineLayout.sizes(panelHeight: max(0, geo.size.height - offH), hasMusic: f?.decisions.track?.file != nil)
            VStack(spacing: 0) {
                StripToolbar(player: project.player).frame(height: sizes.toolbar)
                if let f = f, f.storyboards.first != nil {
                    if f.library.isEmpty {
                        Text("The storyboard is empty. Create scenes in the library: each one you switch on appears here, in order.")
                            .font(.system(size: 13)).foregroundStyle(StripColor.dim).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    } else {
                        TimelineBody(f: f, sizes: sizes)
                        if !off.isEmpty { OffRow(off: off).frame(height: offH) }
                    }
                } else { Spacer() }
            }
            .onAppear { project.setViewportWidth(Double(geo.size.width)) }
            .onChange(of: geo.size.width) { project.setViewportWidth(Double($0)) }
        }
        .background(StripColor.bg)
        .environment(\.colorScheme, .dark)
        .onHover { project.stripHovered = $0 }
        .background(StripKeys(project: project))
    }
}

// MARK: keyboard

/// Space plays and stops, the arrows go from scene to scene, while the pointer is over the strip and no text is being edited.
struct StripKeys: NSViewRepresentable {
    let project: ProjectModel

    final class Coordinator { var monitor: Any?; weak var project: ProjectModel? }
    func makeCoordinator() -> Coordinator { let c = Coordinator(); c.project = project; return c }

    func makeNSView(context: Context) -> NSView {
        let c = context.coordinator
        c.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak c] e in
            guard let p = c?.project, p.stripHovered, e.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  !(NSApp.keyWindow?.firstResponder is NSText) else { return e }
            switch e.keyCode {
            case 49: p.togglePlay(); return nil
            case 123: p.stepScene(by: -1); return nil
            case 124: p.stepScene(by: 1); return nil
            default: return e
            }
        }
        return NSView()
    }

    func updateNSView(_ v: NSView, context: Context) { context.coordinator.project = project }
    static func dismantleNSView(_ v: NSView, coordinator: Coordinator) { if let m = coordinator.monitor { NSEvent.removeMonitor(m) } }
}

// MARK: toolbar

struct StripToolbar: View {
    @ObservedObject var player: ReelPlayer
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 12) {
            left.frame(maxWidth: .infinity, alignment: .leading)
            transport
            right.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .background(StripColor.ruler)
        .overlay(alignment: .bottom) { Rectangle().fill(StripColor.line).frame(height: 1) }
    }

    private var left: some View {
        HStack(spacing: 10) {
            Label("Storyboard", systemImage: "film.stack").font(.system(size: 13, weight: .semibold)).foregroundStyle(StripColor.text)
            if let f = project.showreel {
                Text(summary(f)).font(.system(size: 12)).foregroundStyle(StripColor.dim).lineLimit(1)
            }
        }
    }

    private func summary(_ f: ShowreelFile) -> String {
        var t = "\(f.film.count) scene\(f.film.count == 1 ? "" : "s")"
        if let e = f.filmEnd { t += " \u{00B7} " + TimelineNav.timecode(e) }
        if let d = f.decisions.duration { t += " of \(ProjectDocs.seconds(d)) s" }
        return t
    }

    private var transport: some View {
        let total = project.showreel.map { TimelineNav.filmLength($0) } ?? 0
        return HStack(spacing: 8) {
            Button { project.stepScene(by: -1) } label: { Image(systemName: "backward.end.fill") }.buttonStyle(.borderless).help("Previous scene (left arrow)")
            Button { project.togglePlay() } label: {
                Image(systemName: project.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 13)).frame(width: 30, height: 24)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain).help(project.isPlaying ? "Pause (space)" : "Play from the playhead (space, while the pointer is over the strip)")
            Button { project.stepScene(by: 1) } label: { Image(systemName: "forward.end.fill") }.buttonStyle(.borderless).help("Next scene (right arrow)")
            Text(TimelineNav.timecode(project.playhead)).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(StripColor.text)
                .frame(minWidth: 52, alignment: .trailing)
            Text("/ " + TimelineNav.timecode(total)).font(.system(size: 12, design: .monospaced)).foregroundStyle(StripColor.dim)
        }
        .foregroundStyle(StripColor.text)
    }

    private var right: some View {
        HStack(spacing: 10) {
            zoom
            if let f = project.showreel {
                snap(f)
                Toggle(isOn: Binding(get: { f.ripple() }, set: { project.setGridSettings(ripple: $0) })) {
                    Image(systemName: "arrow.left.and.right.square")
                }
                .toggleStyle(.button).help("Ripple: when a scene is stretched, the scenes after it move with it. Off: they stay where they are.")
                addMenu(f)
                StripPrimaryAction()
            }
        }
    }

    private var zoom: some View {
        HStack(spacing: 6) {
            Button { project.zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
                .buttonStyle(.borderless).keyboardShortcut("-", modifiers: .command).help("Zoom out (Command-Minus)")
            Slider(value: Binding(get: { TimelineScale.sliderPosition(project.timeline.pps) }, set: { project.setScale(TimelineScale.pps(sliderPosition: $0)) }), in: 0...1)
                .frame(width: 96).help("Time scale")
            Button { project.zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
                .buttonStyle(.borderless).keyboardShortcut("=", modifiers: .command).help("Zoom in (Command-Plus)")
                .background { Button("") { project.zoomIn() }.keyboardShortcut("+", modifiers: .command).opacity(0).frame(width: 0, height: 0) }
            Menu {
                Button("Fit the whole film") { project.fitFilm() }.keyboardShortcut("0", modifiers: .command)
                Button("Fit selection") { project.fitSelection() }
            } label: { Image(systemName: "arrow.up.left.and.down.right.magnifyingglass") }
            .menuStyle(.borderlessButton).fixedSize().help("Fit the film (Command-0) or the selection")
        }
        .foregroundStyle(StripColor.text)
    }

    private func snap(_ f: ShowreelFile) -> some View {
        Menu {
            ForEach(SnapLevel.allCases, id: \.self) { l in
                Button { project.setGridSettings(snap: l) } label: { Text((f.snapLevel() == l ? "\u{2713} " : "") + l.title) }
            }
        } label: {
            HStack(spacing: 3) { Image(systemName: "magnet"); Text(f.snapLevel().title).font(.system(size: 12)) }
        }
        .menuStyle(.borderlessButton).fixedSize()
        .help("Stretching a scene snaps to this level of the music grid: beat, bar, section, drop or off. Hold Option to bypass it.")
    }

    /// Scenes of the library that are not in the film, and a new scene.
    private func addMenu(_ f: ShowreelFile) -> some View {
        let on = Set(f.film.map { $0.id })
        let off = f.library.filter { !on.contains($0.id) }
        return Menu {
            Button("New scene") { project.addScene() }
            if !off.isEmpty { Divider() }
            ForEach(off) { s in Button("\(s.label)  \(s.text.isEmpty ? "(no text)" : String(s.text.prefix(30)))") { project.place(s.id, before: nil) } }
        } label: { Label("Add scene", systemImage: "plus") }
        .menuStyle(.borderlessButton).fixedSize().help("Add a scene to the film")
    }
}

/// The one prominent action of the strip: validate the storyboard, then give the Go.
struct StripPrimaryAction: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let g = project.showreel?.gates ?? [:]
        let validated = g["storyboard"] == "passed"
        HStack(spacing: 6) {
            if !validated {
                Button { project.perform(.gate("storyboard", passed: true)) } label: { Label("Validate storyboard", systemImage: "checkmark.circle") }
                    .buttonStyle(.borderedProminent).disabled((project.showreel?.film.isEmpty) ?? true)
                    .help("Say the storyboard is as you want it. Then the scenes are reviewed and you give the Go.")
            } else {
                GoButton().buttonStyle(.borderedProminent)
                if g["review"] != "passed" {
                    Button("Reopen") { project.perform(.gate("storyboard", passed: false)) }.buttonStyle(.borderless).font(.system(size: 11)).help("Take the validation back to keep editing")
                }
            }
        }
    }
}

// MARK: the lanes

struct TimelineBody: View {
    let f: ShowreelFile
    let sizes: TimelineSizes
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var dnd: DragState
    @State private var mag: CGFloat = 1

    private let gapW: CGFloat = 64

    private func gapIndex(_ tl: [TimedScene]) -> Int? {
        guard case .reelSlot(let before)? = dnd.hover, let item = dnd.item, project.verdict(item, .reelSlot(before: before)).isValid else { return nil }
        guard let b = before else { return tl.count }
        return tl.firstIndex { $0.scene.id == b }
    }

    var body: some View {
        let vp = project.timeline
        let tl = f.timeline()
        let pps = vp.pps
        let width = project.viewportWidth
        let contentW = CGFloat(TimelineScale.contentWidth(duration: project.timelineLength, pps: pps, viewport: width))
        let laneTop = sizes.ruler + sizes.padding + sizes.markerRow
        let gap = gapIndex(tl)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        TimelineRulerView(vp: vp, viewport: width, height: sizes.ruler, music: project.music).frame(width: contentW, height: sizes.ruler)
                        Color.clear.frame(height: sizes.padding + sizes.markerRow)
                        ZStack(alignment: .topLeading) {
                            Color.clear.frame(width: contentW, height: sizes.frame).registers(.reelSlot(before: nil))     // empty room: the end of the film
                            if let g = gap {
                                let x = g < tl.count ? TimelineScale.x(tl[g].start ?? 0, pps: pps) : TimelineScale.x(tl.last?.end ?? 0, pps: pps)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .frame(width: gapW - 6, height: sizes.frame).offset(x: CGFloat(x) + 3)
                                if g < tl.count { Color.clear.frame(width: gapW, height: sizes.frame).registers(.reelSlot(before: tl[g].scene.id)).offset(x: CGFloat(x)) }
                            }
                            ForEach(Array(tl.enumerated()), id: \.element.scene.id) { i, t in
                                let w = CGFloat(max(1, (t.length ?? 3) * pps))
                                let next: String? = i + 1 < tl.count ? tl[i + 1].scene.id : nil
                                FrameView(timed: t, previous: i > 0 ? tl[i - 1].scene.id : nil, pps: CGFloat(pps), width: w, height: CGFloat(sizes.frame))
                                    .dropSlots(before: .reelSlot(before: t.scene.id), after: .reelSlot(before: next), vertical: false)
                                    .offset(x: CGFloat(TimelineScale.x(t.start ?? 0, pps: pps)) + ((gap ?? Int.max) <= i ? gapW : 0))
                            }
                            ForEach(Array(tl.enumerated()), id: \.element.scene.id) { i, t in
                                if i + 1 < tl.count {
                                    let nx = tl[i + 1]
                                    let cut = TimelineScale.x(nx.start ?? t.end ?? 0, pps: pps)
                                    let place = MarkerLayout.place(cutX: cut, prevWidth: (t.length ?? 3) * pps, nextWidth: (nx.length ?? 3) * pps, sizes: sizes)
                                    if place.visible {
                                        TransitionMarker(from: t.scene.id, transition: t.item.transition, place: place)
                                            .offset(x: ((gap ?? Int.max) <= i + 1 ? gapW : 0))
                                    }
                                }
                            }
                        }
                        .frame(width: contentW, height: sizes.frame, alignment: .topLeading)
                        Color.clear.frame(height: sizes.gap)
                        MusicLane(contentW: contentW, vp: vp).frame(width: contentW, height: sizes.music)
                        Color.clear.frame(height: sizes.padding)
                    }
                    Rectangle().fill(StripColor.playhead).frame(width: 2, height: CGFloat(laneTop + sizes.frame + sizes.gap + sizes.music))
                        .offset(x: CGFloat(TimelineScale.x(project.playhead, pps: pps)) - 1).allowsHitTesting(false)
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 11)).foregroundStyle(StripColor.playhead)
                        .offset(x: CGFloat(TimelineScale.x(project.playhead, pps: pps)) - 5.5, y: CGFloat(sizes.ruler) - 12).allowsHitTesting(false)
                    Color.clear.frame(width: 1, height: 1).padding(.leading, CGFloat(vp.scroll)).id("anchor")
                }
                .background(GeometryReader { g in Color.clear.preference(key: StripScrollKey.self, value: -g.frame(in: .named("strip")).minX) })
            }
            .coordinateSpace(name: "strip")
            .onPreferenceChange(StripScrollKey.self) { x in DispatchQueue.main.async { project.scrolled(to: Double(x)) } }
            .onChange(of: project.scrollRequest) { _ in proxy.scrollTo("anchor", anchor: .leading) }
            .simultaneousGesture(MagnificationGesture().onChanged { v in project.zoom(by: Double(v / mag)); mag = v }.onEnded { _ in mag = 1 })
            .onContinuousHover { phase in if case .active(let p) = phase { project.pointerX = Double(p.x) } }
            .animation(Motion.spring, value: dnd.hover)
        }
    }
}

// MARK: ruler

struct TimelineRulerView: View {
    let vp: TimelineScale.Viewport
    let viewport: Double
    let height: Double
    let music: MusicAnalysis?
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let pps = vp.pps
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(StripColor.ruler))
            let a = max(0, TimelineScale.time(atX: vp.scroll - 40, pps: pps)), b = TimelineScale.time(atX: vp.scroll + viewport + 40, pps: pps)
            let ticks = TimelineRuler.ticks(pps: pps, from: a, to: b, bars: music?.bars ?? [], beats: music?.beats ?? [])
            for t in ticks {
                let x = CGFloat(TimelineScale.x(t.time, pps: pps))
                switch t.kind {
                case .time:
                    let h: CGFloat = t.major ? 12 : 6
                    ctx.fill(Path(CGRect(x: x, y: size.height - h, width: 1, height: h)), with: .color(t.major ? StripColor.dim : StripColor.line))
                    if let l = t.label { ctx.draw(Text(l).font(.system(size: StripColor.font, weight: .medium, design: .monospaced)).foregroundColor(StripColor.text), at: CGPoint(x: x + 4, y: 8), anchor: .leading) }
                case .bar:
                    ctx.fill(Path(CGRect(x: x, y: size.height - 10, width: 1.5, height: 10)), with: .color(StripColor.wave))
                    if let l = t.label { ctx.draw(Text(l).font(.system(size: StripColor.font, weight: .semibold)).foregroundColor(StripColor.wave), at: CGPoint(x: x + 4, y: size.height - 8), anchor: .leading) }
                case .beat:
                    ctx.fill(Path(CGRect(x: x, y: size.height - 5, width: 1, height: 5)), with: .color(StripColor.wave.opacity(0.7)))
                }
            }
            ctx.fill(Path(CGRect(x: 0, y: size.height - 1, width: size.width, height: 1)), with: .color(StripColor.line))
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { project.playhead = max(0, TimelineScale.time(atX: Double($0.location.x), pps: pps)) })
        .help(music == nil ? "Seconds: click or drag to place the playhead" : "Seconds and bars of the music: click or drag to place the playhead")
    }
}

// MARK: frames

/// One scene of the film: thumbnails at the height of the lane, its ID (and name when there is room), review state, duration, two edges to drag.
struct FrameView: View {
    let timed: TimedScene
    let previous: String?
    let pps: CGFloat
    let width: CGFloat
    let height: CGFloat
    @EnvironmentObject var project: ProjectModel
    @State private var hovering = false
    @State private var dragging: (edge: Int, dx: CGFloat)?

    private var scene: ShowreelFile.Scene { timed.scene }
    private var selected: Bool { project.selection.sceneID == scene.id }

    var body: some View {
        let e = FrameLayout.elements(width: Double(width), height: Double(height), hasName: scene.name != nil, idLength: scene.id.count, nameLength: scene.name?.count ?? 0)
        ZStack(alignment: .topLeading) {
            thumbs(e)
            LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
            if let r = e.label { label(e.mode).frame(maxWidth: r.width, alignment: .leading).offset(x: r.minX, y: r.minY) }
            if let r = e.status {
                Image(systemName: scene.statusSymbol).font(.system(size: 12)).foregroundStyle(scene.statusColor).frame(width: r.width, height: r.height)
                    .background(.black.opacity(0.6), in: Circle()).offset(x: r.minX, y: r.minY)
            }
            if let r = e.eye {
                Button { project.setEnabled(scene.id, false) } label: { Image(systemName: "eye.slash").font(.system(size: 11)).frame(width: r.width, height: r.height) }
                    .buttonStyle(.plain).foregroundStyle(.white).background(.black.opacity(0.6), in: Circle()).offset(x: r.minX, y: r.minY)
                    .help("Switch off: the scene stays in the library")
            }
            if let r = e.pill {
                Text(timed.length.map { ProjectDocs.seconds($0) + " s" } ?? "no length").font(.system(size: StripColor.font, weight: .medium).monospacedDigit()).foregroundStyle(.white).lineLimit(1)
                    .frame(width: r.width, height: r.height).background(.black.opacity(0.7), in: Capsule()).offset(x: r.minX, y: r.minY)
            }
            HStack(spacing: 0) {
                edge(0).opacity(previous == nil ? 0 : 1).allowsHitTesting(previous != nil)
                Spacer(minLength: 0)
                edge(1)
            }
            .frame(width: width, height: height)
            if let d = dragging { dragLabel(d) }
        }
        .frame(width: width, height: height)
        .background(StripColor.frame)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(selected ? Color.accentColor : hovering ? Color.white.opacity(0.65) : Color.white.opacity(0.28), lineWidth: selected ? 3 : hovering ? 2 : 1))
        .shadow(color: selected ? Color.accentColor.opacity(0.55) : .clear, radius: 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: selected)
        .onTapGesture { project.select(.scene(scene.id)); if let s = timed.start { project.playhead = s } }
        .dragSource(.scene(scene.id), label: scene.label, icon: "film")
        .dropTarget(.scene(scene.id))       // a resource, a background or a look dropped on a frame goes to that scene
        .contextMenu {
            Button("Rename") { project.beginRename(scene.id) }
            Button("Duplicate") { project.duplicateScene(scene.id) }
            Button("Switch off") { project.setEnabled(scene.id, false) }
            Divider()
            Button("Archive", role: .destructive) { project.archiveScene(scene.id) }
        }
        .help(scene.label)
    }

    /// Thumbnails at the shape of 16:9 and the height of the lane, side by side when the frame is longer than one; one, cropped, when it is shorter.
    private func thumbs(_ e: FrameElements) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<e.thumbTiles, id: \.self) { _ in
                SceneThumb(scene: scene, still: true).frame(width: CGFloat(e.thumbWidth), height: height).clipped()
            }
        }
        .frame(width: width, height: height, alignment: .leading).clipped()
    }

    @ViewBuilder private func label(_ m: LabelMode) -> some View {
        let id = m == .shortID ? String(scene.id.drop { !$0.isNumber }) : scene.id
        HStack(spacing: 4) {
            Text(id).font(.system(size: StripColor.font, weight: .bold, design: .monospaced)).foregroundStyle(.white).lineLimit(1)
            if m == .idAndName, let n = scene.name { Text(n).font(.system(size: StripColor.font, weight: .medium)).foregroundStyle(.white.opacity(0.92)).lineLimit(1) }
            OverrideBadge(scene: scene)
        }
        .padding(.horizontal, 5).frame(height: 18).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4)).fixedSize(horizontal: m != .idAndName, vertical: true)
    }

    /// An edge: the left one moves the cut with the scene before, the right one changes this scene's duration.
    private func edge(_ side: Int) -> some View {
        Rectangle().fill(Color.white.opacity(dragging?.edge == side ? 0.55 : hovering ? 0.28 : 0.0)).frame(width: 7)
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
        return Text(TimelineNav.timecode(s)).font(.system(size: 12, weight: .bold, design: .monospaced)).padding(4).background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.white).frame(width: width, height: height, alignment: d.edge == 1 ? .topTrailing : .topLeading).padding(.top, 26)
    }
}

// MARK: transitions

/// The passage to the next scene: a diamond on the cut with the icon of its type, a generous area to click. A transition dropped from the library lands here.
struct TransitionMarker: View {
    let from: String
    let transition: ShowreelFile.Transition
    let place: MarkerPlacement
    @EnvironmentObject var project: ProjectModel

    private var symbol: String {
        if transition.isCut { return "scissors" }
        let t = transition.type.lowercased()
        if t.contains("push") || t.contains("slide") || t.contains("wipe") { return "arrow.right" }
        if t.contains("iris") || t.contains("circle") { return "circle.dashed" }
        if t.contains("fade") || t.contains("dissolve") { return "circle.lefthalf.filled" }
        if t.contains("zoom") { return "plus.magnifyingglass" }
        return "arrow.left.arrow.right"
    }

    var body: some View {
        let selected = project.selection == .transition(from)
        let side = place.size * 0.72
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(transition.isCut ? Color(white: 0.2) : Color.accentColor)
                .frame(width: side, height: side).rotationEffect(.degrees(45))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(selected ? Color.white : Color.white.opacity(0.55), lineWidth: selected ? 2.5 : 1).frame(width: side, height: side).rotationEffect(.degrees(45)))
            Image(systemName: symbol).font(.system(size: place.size > 20 ? 11 : 9, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: place.hit.width, height: place.hit.height)
        .contentShape(Rectangle())
        .help(transition.text)
        .onTapGesture { project.selectTransition(from: from) }
        .dropTarget(.marker(from: from))     // a transition dropped from the library lands here
        .contextMenu {
            Button("Edit the transition") { project.selectTransition(from: from) }
            Button("Set to a cut") { project.setTransition(from: from, nil) }.disabled(transition.isCut)
        }
        .offset(x: place.hit.minX, y: place.hit.minY)
    }
}

// MARK: music

/// The project's music directly under the frames: a filled waveform on the time scale, the grid of the analysis; empty, a large place to drop an audio file.
struct MusicLane: View {
    let contentW: CGFloat
    let vp: TimelineScale.Viewport
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(StripColor.lane)
            if project.showreel?.decisions.track?.file == nil { emptyState } else { lane }
        }
        .dropTarget(.musicLane)
    }

    private var emptyState: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.badge.plus").font(.system(size: 26)).foregroundStyle(StripColor.wave)
            VStack(alignment: .leading, spacing: 2) {
                Text("Drop an audio file here to time the film on its beat").font(.system(size: 14, weight: .semibold)).foregroundStyle(StripColor.text)
                Text("Or drag one from the Resources tab. The grid of the music then appears in the ruler, and scenes snap to it.").font(.system(size: 12)).foregroundStyle(StripColor.dim)
            }
            Button("Choose music") { choose() }.buttonStyle(.borderedProminent)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: min(contentW, max(project.viewportWidth, 600)), alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(StripColor.line, style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])).frame(width: min(contentW, max(project.viewportWidth, 600))), alignment: .leading)
    }

    private func choose() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.audio]; p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = false; p.prompt = "Use as the music"
        if p.runModal() == .OK, let u = p.url { project.performDrop(.files([u]), on: .musicLane) }
    }

    private var lane: some View {
        let pps = vp.pps
        return ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                let mid = size.height / 2
                if let m = project.music { for b in m.breaks { ctx.fill(Path(CGRect(x: CGFloat(TimelineScale.x(b.start, pps: pps)), y: 0, width: CGFloat((b.end - b.start) * pps), height: size.height)), with: .color(.orange.opacity(0.2))) } }
                let dur = max(project.trackDuration, project.music?.duration ?? 0)
                let n = project.waveform.count
                if n > 0, dur > 0 {
                    let x0 = max(0, vp.scroll - 20), x1 = min(Double(size.width), vp.scroll + project.viewportWidth + 20)
                    let end = TimelineScale.x(dur, pps: pps)
                    var top: [CGPoint] = [], bottom: [CGPoint] = []
                    var x = x0
                    while x <= min(x1, end) {
                        let t = TimelineScale.time(atX: x, pps: pps)
                        let i = min(n - 1, max(0, Int(t / dur * Double(n))))
                        let h = max(1.5, CGFloat(project.waveform[i]) * (size.height - 8))
                        top.append(CGPoint(x: x, y: mid - h / 2)); bottom.append(CGPoint(x: x, y: mid + h / 2))
                        x += 1.5
                    }
                    if top.count > 1 {
                        var p = Path(); p.move(to: top[0]); top.dropFirst().forEach { p.addLine(to: $0) }; bottom.reversed().forEach { p.addLine(to: $0) }; p.closeSubpath()
                        ctx.fill(p, with: .linearGradient(Gradient(colors: [StripColor.wave, StripColor.wave.opacity(0.6)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                    }
                }
                if let m = project.music {
                    for b in m.bars { ctx.fill(Path(CGRect(x: CGFloat(TimelineScale.x(b, pps: pps)), y: 0, width: 1, height: size.height)), with: .color(.white.opacity(0.22))) }
                    if let d = m.strongestDrop {
                        ctx.fill(Path(CGRect(x: CGFloat(TimelineScale.x(d, pps: pps)) - 1, y: 0, width: 2.5, height: size.height)), with: .color(StripColor.playhead))
                        ctx.draw(Text("strongest drop").font(.system(size: StripColor.font, weight: .bold)).foregroundColor(StripColor.playhead), at: CGPoint(x: CGFloat(TimelineScale.x(d, pps: pps)) + 6, y: 10), anchor: .leading)
                    }
                    for b in m.breaks { ctx.draw(Text("break").font(.system(size: StripColor.font)).foregroundColor(.orange), at: CGPoint(x: CGFloat(TimelineScale.x(b.start, pps: pps)) + 6, y: size.height - 10), anchor: .leading) }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { project.playhead = max(0, TimelineScale.time(atX: Double($0.location.x), pps: pps)) })
            if project.analysing { ProgressView().controlSize(.small).padding(8) }
            else if project.music == nil { Text(project.musicNotice ?? "Not analysed: the ruler shows plain time.").font(.system(size: 12)).foregroundStyle(.orange).padding(8) }
        }
    }
}

// MARK: scenes that are off

/// Scenes of the library that are not in the film: dimmed chips, one click puts one at the end, or drag it into the frames.
struct OffRow: View {
    let off: [ShowreelFile.Scene]
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        HStack(spacing: 6) {
            Text("Off:").font(.system(size: 12)).foregroundStyle(StripColor.dim)
            ForEach(off) { s in
                Button { project.place(s.id, before: nil) } label: { Label(s.id, systemImage: "eye").font(.system(size: StripColor.font)) }
                    .buttonStyle(.bordered).controlSize(.small).opacity(0.6)
                    .dragSource(.scene(s.id), label: s.label, icon: "film")
                    .help("\(s.label) is off. Click to switch it on at the end of the film, or drag it into the frames.")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .background(StripColor.ruler)
    }
}
