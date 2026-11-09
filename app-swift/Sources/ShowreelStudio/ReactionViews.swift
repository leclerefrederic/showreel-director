import AppKit
import ShowreelKit
import SwiftUI

// The action/reaction layer. The rules (what is blocked, why, how to get it back, when to warn on closing) are ShowreelKit's: `Availability`, `ProjectActivity`, `CloseGuard`.
// What is here only draws them, and brings the answers (a card, the Cancel of a build, the warning) to the user.

/// The project windows that are open, so that quitting the app can ask each one whether work is in progress.
final class OpenProjects {
    static let shared = OpenProjects()
    private struct Box { weak var model: ProjectModel? }
    private var boxes: [Box] = []
    func register(_ m: ProjectModel) { boxes.removeAll { $0.model == nil }; boxes.append(Box(model: m)) }
    var all: [ProjectModel] { boxes.compactMap { $0.model } }
    func model(forPath p: String) -> ProjectModel? { all.first { $0.root.standardizedFileURL.path == URL(fileURLWithPath: p).standardizedFileURL.path } }
}

extension ProjectModel {
    var sceneProgress: (done: Int, total: Int)? {
        guard let b = activity.build else { return nil }
        let p = BuildProgress.scenes(version: b.version, store: store); return (p.done, p.total)
    }

    func closeAlert(_ c: CloseGuard.Context) -> CloseGuard.Alert? {
        CloseGuard.alert(activity, context: c, scenes: sceneProgress, lastWorking: BuildProgress.lastWorking(store))
    }

    /// The warning before closing, quitting, updating or restoring while work is in progress. true: go on (the work was stopped as the alert said); false: keep working.
    /// The window only shows what the rules say.
    func confirmLeaving(_ c: CloseGuard.Context) -> Bool {
        guard let a = closeAlert(c) else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = a.title
        alert.informativeText = a.lines.joined(separator: "\n\n")
        alert.addButton(withTitle: a.keep)             // the first button is the default: Return keeps working
        alert.addButton(withTitle: a.confirm)
        guard alert.runModal() == .alertSecondButtonReturn else { return false }
        if c == .quit, a.proposals > 0 { chat?.journalUnanswered() }           // the process ends right after: the journal is written here
        if a.cancelsBuild { cancelBuild() }
        if a.interruptsClap || (a.proposals > 0 && c != .quit) { chat?.stop() }
        return true
    }
}

// MARK: closing the window and quitting

/// Asks before the window closes (the red button, Command-W) when work is in progress. The window's own delegate keeps everything else.
struct CloseGuardHook: NSViewRepresentable {
    let project: ProjectModel

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { context.coordinator.attach(v.window) }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) { DispatchQueue.main.async { context.coordinator.attach(v.window) } }
    func makeCoordinator() -> Coordinator { Coordinator(project) }

    final class Coordinator: NSObject, NSWindowDelegate {
        let project: ProjectModel
        weak var original: NSWindowDelegate?
        init(_ p: ProjectModel) { project = p }
        func attach(_ w: NSWindow?) {
            guard let w = w, w.delegate !== self else { return }
            original = w.delegate; w.delegate = self
        }
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard project.confirmLeaving(.closeWindow) else { return false }
            return original?.windowShouldClose?(sender) ?? true
        }
        override func responds(to s: Selector!) -> Bool { super.responds(to: s) || (original?.responds(to: s) ?? false) }
        override func forwardingTarget(for s: Selector!) -> Any? { (original?.responds(to: s) ?? false) ? original : super.forwardingTarget(for: s) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// A `.studiopack` opened by double-click, dropped on the Dock icon or sent by Open With: the import card shows it.
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in PackageInbox.shared.receive(urls) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for m in OpenProjects.shared.all where !(m.activity.isIdle) {
            if !m.confirmLeaving(.quit) { return .terminateCancel }
        }
        return .terminateNow
    }
}

// MARK: blocked elements

/// Why an element is read-only, and the way out, in one box: the reason, what to do, and the button that does it.
struct BlockedNotice: View {
    let reason: Unavailable
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(.orange).frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(reason.reason).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text(reason.way).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let b = button { Button(b.0) { b.1() }.buttonStyle(.borderless).font(.caption.weight(.semibold)) }
            }
            Spacer(minLength: 0)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var icon: String { reason.cause == .building ? "hammer" : reason.cause == .proposal ? ClapMark.symbol : "lock" }
    private var button: (String, () -> Void)? {
        switch reason.cause {
        case .proposal: return ("Show the proposal", { project.followLink(reason, chat: chat) })
        case .building: return ("Cancel the build", { project.cancelBuild() })
        case .clapWorking: return ("Stop Clap", { chat.stop() })
        default: return nil
        }
    }
}

/// Makes what it wraps read-only, with the reason above it, while any of the elements is blocked by a build, a proposal waiting on it, or Clap working on it. The tabs and
/// the headers stay outside it, so looking and navigating always work.
struct ReadOnlyWhenBlocked: ViewModifier {
    let refs: [ElementRef]
    @EnvironmentObject var project: ProjectModel

    func body(content: Content) -> some View {
        let why = refs.lazy.compactMap { project.blocked($0) }.first
        VStack(alignment: .leading, spacing: 10) {
            if let why = why { BlockedNotice(reason: why) }
            content.disabled(why != nil).opacity(why == nil ? 1 : 0.55)
        }
        .animation(Motion.quick, value: why)
    }
}

/// A small mark on a row or a frame: "Clap proposes a change" or "Locked during build", with the reason in its tooltip. A click goes to the answer.
struct BlockMarker: View {
    let ref: ElementRef
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        if let u = project.blocked(ref) {
            Button { project.followLink(u, chat: chat) } label: {
                Label(u.cause == .building ? "Locked during build" : u.cause == .proposal ? "Clap proposes a change" : "Clap is working", systemImage: u.cause == .building ? "hammer" : ClapMark.symbol)
                    .labelStyle(.iconOnly).font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                    .padding(3).background(Color.orange.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain).help(u.message)
        }
    }
}

/// The element lights up for a second after it changed.
struct FlashWhenChanged: ViewModifier {
    let ref: ElementRef
    @EnvironmentObject var project: ProjectModel
    func body(content: Content) -> some View {
        let on = project.flashed.contains { $0.overlaps(ref) }
        content.overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(on ? 0.25 : 0)).allowsHitTesting(false))
            .animation(.easeOut(duration: 0.6), value: on)
    }
}

/// The temporary mark: a thin tinted outline around the whole row or frame while a proposal waits on it or the build runs. It sits under the badges and never hides them
/// (`MarkLayout`); the small button at the end of the row (`BlockMarker`) takes the user to the answer.
struct TemporaryVeil: ViewModifier {
    let ref: ElementRef
    var radius: CGFloat = 8
    @EnvironmentObject var project: ProjectModel

    func body(content: Content) -> some View {
        let on = project.blocked(ref) != nil
        content.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.orange.opacity(on ? 0.85 : 0), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.orange.opacity(on ? 0.07 : 0)))
                .allowsHitTesting(false))
            .animation(Motion.quick, value: on)
    }
}

extension View {
    func temporaryVeil(_ ref: ElementRef, radius: CGFloat = 8) -> some View { modifier(TemporaryVeil(ref: ref, radius: radius)) }
    func readOnlyWhenBlocked(_ refs: ElementRef...) -> some View { modifier(ReadOnlyWhenBlocked(refs: refs)) }
    func flashWhenChanged(_ ref: ElementRef) -> some View { modifier(FlashWhenChanged(ref: ref)) }

    /// The standard disabled control: it looks disabled, says why at once in its tooltip, and (when it matters) in a short line under it. A nil reason leaves it enabled.
    func disabledWithReason(_ reason: String?, way: String? = nil, caption: Bool = false) -> some View {
        modifier(DisabledWithReason(reason: reason, way: way, caption: caption))
    }
}

struct DisabledWithReason: ViewModifier {
    let reason: String?
    let way: String?
    let caption: Bool

    func body(content: Content) -> some View {
        let text = reason.map { r in way.map { r + ". " + $0 } ?? r }
        VStack(alignment: .leading, spacing: 3) {
            content.disabled(reason != nil).help(text ?? "")
                .overlay { if reason != nil { Color.clear.contentShape(Rectangle()).help(text ?? "") } }       // a disabled control has no tooltip of its own on every macOS: the cover gives it one
            if caption, let t = text { Text(t).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

extension Availability {
    /// The message for `disabledWithReason`.
    var reasonText: String? { why?.reason }
    var wayText: String? { why?.way }
}

// MARK: proposals waiting, Clap working, a build running

/// At the top of the inspector while Clap's cards wait for an answer: how many, Accept all and Refuse all, and a link to each card.
struct ProposalsBanner: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        let list = project.activity.proposals
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Waiting for your answer: \(list.count) proposal\(list.count == 1 ? "" : "s") from Clap", systemImage: ClapMark.symbol).font(.callout.weight(.semibold))
                    Spacer()
                    Button("Refuse all") { chat.answerAll(accept: false) }
                    Button("Accept all") { chat.answerAll(accept: true) }.buttonStyle(.borderedProminent)
                }
                ForEach(list) { p in
                    Button { chat.focus(card: p.id) } label: { Label(p.title, systemImage: "arrow.turn.down.right").font(.caption).lineLimit(1) }
                        .buttonStyle(.borderless).help("Show this proposal in the conversation")
                }
                Text("The elements it changes are read-only until you answer.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1))
            Divider()
        }
    }
}

/// What Clap is doing, and how its last request ended: "Clap is thinking...", "Clap is applying changes...", then "Clap is done", an error in plain words, or "Clap was stopped".
struct ClapActivityChip: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        HStack(spacing: 6) {
            if let l = ClapActivity.label(project.activity), project.activity.build == nil {
                if project.activity.proposals.isEmpty { ProgressView().controlSize(.mini) } else { Image(systemName: "hourglass").foregroundStyle(.orange) }
                Text(l).font(.caption)
                if project.activity.proposals.isEmpty { Button("Stop") { chat.stop() }.buttonStyle(.borderless).font(.caption.weight(.semibold)).help("Stops Clap: what it already changed stays, and can be undone") }
            } else if let e = chat.lastEnd {
                Image(systemName: e.isError ? "exclamationmark.triangle.fill" : "checkmark.circle").foregroundStyle(e.isError ? Color.orange : Color.green)
                Text(e.text).font(.caption).lineLimit(2)
            }
        }
        .animation(Motion.quick, value: chat.lastEnd)
    }
}

/// While the film is being built: the step, the scene, what Clap is doing (reading, preparing, writing), the tokens and the time, and one line per step with its state.
/// Cancel build says what will happen. Updated every second.
struct BuildProgressPanel: View {
    var compact = false
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        if let b = project.activity.build {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let scenes = b.order.filter { $0 != BuildJob.frameStep }
                let hasRuns = !scenes.isEmpty
                let p = BuildProgress.scenes(version: b.version, store: project.store)
                let step = b.phase == .generating ? "Clap is writing the film" : b.phase == .testing ? "Assembling and testing" : "Stopping the build\u{2026}"
                let current = b.current ?? ""
                let scene = b.phase == .generating ? (hasRuns ? BuildProgress.sceneLine(done: b.done, total: scenes.count) : BuildProgress.sceneLine(done: p.done, total: p.total)) : nil
                let phase = b.phase == .generating ? b.clapPhase?.word : nil
                let time = BuildProgress.elapsed(ctx.date.timeIntervalSince(b.started))
                let usage = b.phase == .generating ? (hasRuns ? BuildProgress.tokensLine(b.outputTokens) : BuildProgress.usageLine(turns: b.turns, outputTokens: b.outputTokens)) : nil
                if compact {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(([b.version, scene, phase, usage].compactMap { $0 } + [time]).joined(separator: " \u{00B7} ")).font(.caption)
                        Button("Cancel build") { project.cancelBuild() }.buttonStyle(.borderless).font(.caption.weight(.semibold)).help(cancelHelp(b))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Building \(b.version)").font(.headline)
                            Spacer()
                            Button("Cancel build") { project.cancelBuild() }.disabled(b.phase == .cancelling).help(cancelHelp(b))
                        }
                        if hasRuns, b.phase == .generating { ProgressView(value: Double(b.done), total: Double(max(scenes.count, 1))) }
                        else if p.total > 0, b.phase == .generating { ProgressView(value: Double(p.done), total: Double(p.total)) }
                        Text(([step, scene, phase, usage].compactMap { $0 } + [time]).joined(separator: " \u{00B7} ")).font(.callout).foregroundStyle(.secondary)
                        if b.phase == .generating, hasRuns {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(b.order, id: \.self) { id in
                                    if let r = b.runs[id] { StepRow(id: id, run: r, now: ctx.date, current: id == current || (id == BuildJob.frameStep && b.current == nil && r.state == .writing), phase: phase) }
                                }
                            }
                        }
                        Text("Everything is read-only while the film is built: any change now would affect it. Looking, playing a finished film and asking Clap a question still work. \(cancelHelp(b))")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func cancelHelp(_ b: ProjectActivity.Build) -> String {
        let last = BuildProgress.lastWorking(project.store).map { "The film stays at \($0)." } ?? "The film has no working version yet."
        return b.phase == .testing ? "Cancel stops the test; nothing is lost. \(last)"
            : "Cancel stops the writing now: what was written stays in \(b.version), not built, and the Build can be continued. \(last) Tokens already used are not refunded."
    }
}

/// One step of the Build: waiting, writing (with what Clap is doing), done or failed, with its tokens and time.
struct StepRow: View {
    let id: String
    let run: SceneRun
    let now: Date
    let current: Bool
    let phase: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 14)
            Text(id == BuildJob.frameStep ? "Frame (project.json, reel.js)" : id).font(.caption.weight(current ? .semibold : .regular))
            Spacer(minLength: 6)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .help(run.failure ?? "")
    }

    private var symbol: String {
        switch run.state { case .waiting: return "circle"; case .writing: return "pencil.circle.fill"; case .testing: return "checkmark.shield"; case .repairing: return "wrench.and.screwdriver.fill"
        case .done: return run.warningCount > 0 ? "checkmark.circle" : "checkmark.circle.fill"; case .failed: return "exclamationmark.triangle.fill" }
    }
    private var tint: Color {
        switch run.state { case .waiting: return .secondary; case .writing, .testing, .repairing: return .accentColor; case .done: return run.warningCount > 0 ? .orange : .green; case .failed: return .red }
    }
    private var detail: String {
        switch run.state {
        case .waiting: return "waiting"
        case .writing: return ["writing" + (phase.map { " (\($0.lowercased()))" } ?? ""), BuildProgress.tokensLine(run.tokens), BuildProgress.elapsed(run.elapsed(now: now))].compactMap { $0 }.joined(separator: " \u{00B7} ")
        case .testing: return "testing"
        case .repairing: return ["repairing", BuildProgress.tokensLine(run.tokens), BuildProgress.elapsed(run.elapsed(now: now))].compactMap { $0 }.joined(separator: " \u{00B7} ")
        case .done: return run.kept ? "kept" : ["done", run.warningCount > 0 ? "\(run.warningCount) layout warning\(run.warningCount == 1 ? "" : "s")" : nil, BuildProgress.tokensLine(run.tokens), BuildProgress.elapsed(run.elapsed(now: now))].compactMap { $0 }.joined(separator: " \u{00B7} ")
        case .failed: return run.failedTest ? "failed (test): " + (run.failure ?? "") : (run.failure ?? "failed")
        }
    }
}
