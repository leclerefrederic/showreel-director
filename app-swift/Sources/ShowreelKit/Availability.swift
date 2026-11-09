import Foundation

// MARK: the elements an operation touches

/// A thing in the project that can be blocked, marked or lit up: the one name the model, the rules and the views share.
public enum ElementRef: Hashable, Sendable {
    case scene(String)
    case item(scene: String, item: String)
    /// A setting: `parameter.audience`, `look.palette`, `gate.review`, `music`.
    case setting(String)
    case asset(String)
    case file(String)

    /// The same element, or an item and the scene that holds it (a change to a scene's fields may touch its items).
    public func overlaps(_ o: ElementRef) -> Bool {
        if self == o { return true }
        switch (self, o) {
        case (.scene(let s), .item(let t, _)), (.item(let t, _), .scene(let s)): return s == t
        case (.setting(let a), .setting(let b)): return a.hasPrefix(b + ".") || b.hasPrefix(a + ".")     // "look" is every look setting
        default: return false
        }
    }
}

extension ProjectOperation {
    /// The elements the operation would change. An exhaustive switch: a new operation has to say what it touches.
    public var targets: [ElementRef] {
        switch self {
        case .parameter(let k, _): return [.setting("parameter." + k.rawValue)]
        case .decisions(let l, _): return l.map { .setting("look." + $0.key.rawValue) }
        case .asset(let id, _, _, _, _): return [.asset(id)]
        case .gate(let k, _): return [.setting("gate." + k)]
        case .scene(let id, _): return [.scene(id)]
        case .addScene(let id, _): return id.isEmpty ? [] : [.scene(id)]
        case .sceneEnabled(let id, _, _): return [.scene(id)]
        case .moveScene(let id, _, _): return [.scene(id)]
        case .sceneLook(let id, _): return [.scene(id)]
        case .content(let id, let op):
            switch op {
            case .add: return [.scene(id)]
            case .update(let i, _), .remove(let i), .move(let i, _): return [.item(scene: id, item: i)]
            }
        case .resize(let id, _, _): return [.scene(id)]
        case .moveCut(let a, let b, _): return [.scene(a), .scene(b)]
        case .transition(let from, _): return [.scene(from)]
        case .track, .grid, .gridSettings: return [.setting("music")]
        case .moveAsset(let id, _): return [.asset(id)]
        case .sceneLock(let ids, _): return ids.map { .scene($0) }
        case .deleteScene(let id): return [.scene(id)]
        case .addFontFiles(let p): return [.setting("look.fonts"), .setting("fonts." + p.dir)]
        case .resource(let r):
            switch r { case .addTag(let id, _), .removeTag(let id, _), .replaceFile(let id, _): return [.asset(id)]; case .renameTag: return [.setting("tags")] }
        }
    }

    /// What a build in progress does to the operation. Every operation changes what the film is made from, so every one is refused; the switch is exhaustive so that
    /// a new operation has to be classified here (an operation that could safely run during a build would be named `.allowed`).
    public var buildPolicy: BuildPolicy {
        switch self {
        case .parameter, .decisions, .asset, .gate, .scene, .addScene, .sceneEnabled, .moveScene, .sceneLook, .content, .resize, .moveCut, .transition,
             .track, .grid, .gridSettings, .moveAsset, .sceneLock, .deleteScene, .addFontFiles, .resource:
            return .refused
        }
    }
}

public enum BuildPolicy: Equatable, Sendable { case refused, allowed }

// MARK: what is going on in a project

/// What is going on in one project right now, kept by root so that the window and the agent's tools (another thread, another store object) read the same thing.
/// What Clap is doing while a request runs: the tools that read, the wait before the first token, the tokens arriving.
public enum ClapPhase: String, Sendable { case reading, preparing, writing
    public var word: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// One step of a Build: the frame of the film ("reel": project.json and reel.js) or one scene file.
public struct SceneRun: Equatable, Sendable {
    public enum State: String, Sendable { case waiting, writing, testing, repairing, done, failed }
    public var state: State = .waiting
    public var tokens = 0
    public var started: Date?
    public var finished: Date?
    public var failure: String?
    /// Done without a call: the file was already there and up to date, or a locked scene's file was carried over.
    public var kept = false
    /// The layout warnings of the scene's own test (text outside the stage, collisions): listed, never repaired by themselves.
    public var warnings: [String] = []
    public var warningCount = 0
    /// The scene's file failed its own test, even after its one repair: it is an empty frame in the film (`failure` has the error).
    public var failedTest = false
    /// When the scene entered its present state, and when the last content of its request arrived (to say how long it has been quiet).
    public var phaseStarted: Date?
    public var lastData: Date?
    /// What Clap is doing in this scene's request, the line about what is asked again, and how long its requests took in all (the generation time, which scenes written
    /// together add up).
    public var clapPhase: ClapPhase?
    public var notice: String?
    public var requestSeconds: TimeInterval = 0
    public init() {}
    public func elapsed(now: Date = Date()) -> TimeInterval { started.map { (finished ?? now).timeIntervalSince($0) } ?? 0 }
    /// How long the scene has been in its present state.
    public func inPhase(now: Date = Date()) -> TimeInterval { phaseStarted.map { now.timeIntervalSince($0) } ?? 0 }
}

public final class ProjectActivity: @unchecked Sendable {
    public struct Build: Equatable, Sendable {
        public enum Phase: String, Sendable { case generating, testing, cancelling }
        public var version: String
        public var phase: Phase
        public var started: Date
        /// For a generation of some scenes: how many, how many are done, and the one being written.
        public var total: Int?
        public var done = 0
        public var current: String?
        /// What Clap's request has used so far: its steps and its output tokens (an estimate while an answer is being written).
        public var turns = 0
        public var outputTokens = 0
        /// What Clap is doing in the request in progress: reading files, preparing an answer (no token yet) or writing it.
        public var clapPhase: ClapPhase?
        /// A Build one scene at a time: the steps in order ("reel" first, then the scenes) and the state of each.
        public var order: [String] = []
        public var runs: [String: SceneRun] = [:]
        /// How many scenes are written at the same time now (it goes down by one when the API limits requests), and the line that says so.
        public var width = 1
        public var widthNotice: String?
        /// A line about what the Build is doing again by itself ("Connection lost on S07, retrying (1 of 2)"); nil when nothing is.
        public var notice: String? { order.compactMap { runs[$0]?.notice }.first ?? widthNotice }
        /// The time the requests took, added up over the scenes: more than the real time when scenes are written together.
        public var generationSeconds: TimeInterval { runs.values.reduce(0) { $0 + $1.requestSeconds } }
        /// The layout warnings found by the scenes' own tests, by scene: kept after a stop, so that they can be listed.
        public var layoutWarnings: [String: [String]] { Dictionary(uniqueKeysWithValues: runs.compactMap { $0.value.warningCount > 0 ? ($0.key, $0.value.warnings) : nil }) }
        public init(version: String, phase: Phase, started: Date = Date(), total: Int? = nil) { self.version = version; self.phase = phase; self.started = started; self.total = total }
    }
    public enum ClapWork: Equatable, Sendable { case thinking, applying([ElementRef]) }
    public struct Pending: Equatable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let targets: [ElementRef]
        /// An edit of a file (a diff) rather than a typed change.
        public let isFile: Bool
        public init(id: String, title: String, targets: [ElementRef], isFile: Bool = false) { self.id = id; self.title = title; self.targets = targets; self.isFile = isFile }
    }
    public struct Snapshot: Equatable, Sendable {
        public var build: Build?
        public var clap: ClapWork?
        public var proposals: [Pending] = []
        public init() {}
        public var isBuilding: Bool { build != nil }
        public var isIdle: Bool { build == nil && clap == nil && proposals.isEmpty }
        public func proposal(blocking ref: ElementRef) -> Pending? { proposals.first { p in p.targets.contains { $0.overlaps(ref) } } }
    }

    private static let lock = NSLock()
    private static var all: [String: ProjectActivity] = [:]
    public static func `for`(_ root: URL) -> ProjectActivity {
        lock.lock(); defer { lock.unlock() }
        let k = root.standardizedFileURL.path
        if let a = all[k] { return a }
        let a = ProjectActivity(); all[k] = a; return a
    }

    private let guardLock = NSLock()
    private var state = Snapshot()
    /// Called after every change, on the thread that changed it.
    public var observer: ((Snapshot) -> Void)?
    public init() {}

    public var snapshot: Snapshot { guardLock.lock(); defer { guardLock.unlock() }; return state }

    public func update(_ change: (inout Snapshot) -> Void) {
        guardLock.lock(); change(&state); let s = state; guardLock.unlock()
        observer?(s)
    }
    public func reset() { update { $0 = Snapshot() } }

    private var hook: (() -> Void)?
    /// What stops the work in progress that no task of the window owns (a generation Clap started). Set by that work while it runs, cleared at its end.
    public func setCancelHook(_ h: (() -> Void)?) { guardLock.lock(); hook = h; guardLock.unlock() }
    /// Stops that work if there is some. true: there was something to stop.
    @discardableResult
    public func cancelRunning() -> Bool { guardLock.lock(); let h = hook; guardLock.unlock(); h?(); return h != nil }
    public func addProposal(_ p: Pending) { update { $0.proposals.removeAll { $0.id == p.id }; $0.proposals.append(p) } }
    public func removeProposal(_ id: String) { update { $0.proposals.removeAll { $0.id == id } } }
}

// MARK: available, or not, and why

/// Why something is not available, how to get it back, and what blocked it.
public struct Unavailable: Equatable, Sendable {
    public enum Cause: String, Sendable { case building, proposal, locked, clapWorking, noKey, busy, notReady, notAssembled, legacy }
    public enum Link: Equatable, Sendable { case proposal(String), scene(String), setting(String), build, key, assemble }
    public let cause: Cause
    public let reason: String
    public let way: String
    public let link: Link?
    public init(_ cause: Cause, reason: String, way: String, link: Link? = nil) { self.cause = cause; self.reason = reason; self.way = way; self.link = link }
    /// The one sentence a tooltip or a refusal says.
    public var message: String { reason + ". " + way }
}

public enum Availability: Equatable, Sendable {
    case available
    case unavailable(Unavailable)
    public var isAvailable: Bool { if case .available = self { return true } else { return false } }
    public var why: Unavailable? { if case .unavailable(let u) = self { return u } else { return nil } }
}

public enum Reasons {
    public static let building = Unavailable(.building, reason: "Building the film: any change now would affect the film under construction",
                                             way: "Wait for the end, or Cancel the build", link: .build)
    public static func proposal(_ p: ActivityPending) -> Unavailable {
        Unavailable(.proposal, reason: "Waiting for your answer on a proposal from Clap (\(p.title))", way: "Accept or refuse the proposal: click to see it", link: .proposal(p.id))
    }
    public static func locked(_ id: String) -> Unavailable { Unavailable(.locked, reason: "\(id) is locked", way: "Unlock it first: switch its Locked off", link: .scene(id)) }
    public static let noKey = Unavailable(.noKey, reason: "No API key", way: "Connect an AI in Settings (Command-,); everything else works without one", link: .key)
    public static func clapWorking(_ ids: [String]) -> Unavailable {
        Unavailable(.clapWorking, reason: ids.isEmpty ? "Clap is applying changes" : "Clap is applying changes to \(ids.joined(separator: ", "))", way: "Wait a moment, or stop Clap in the Ask Clap tab")
    }
    public static let clapBusy = Unavailable(.busy, reason: "Clap is busy with a request", way: "Wait for the answer, or stop Clap in the Ask Clap tab")
}
public typealias ActivityPending = ProjectActivity.Pending

extension Availability {
    /// Whether an element can be edited now. The first thing that blocks it is the reason: a build, a proposal waiting on it, a lock, Clap working on it.
    public static func edit(_ ref: ElementRef, in s: ProjectActivity.Snapshot, file: ShowreelFile?) -> Availability {
        if s.isBuilding { return .unavailable(Reasons.building) }
        if let p = s.proposal(blocking: ref) { return .unavailable(Reasons.proposal(p)) }
        switch ref {
        case .scene(let id), .item(let id, _):
            if file?.scenes.first(where: { $0.id == id })?.isLocked == true { return .unavailable(Reasons.locked(id)) }
        default: break
        }
        if case .applying(let refs)? = s.clap, refs.contains(where: { $0.overlaps(ref) }) {
            return .unavailable(Reasons.clapWorking(refs.compactMap { if case .scene(let i) = $0 { return i } else { return nil } }))
        }
        return .available
    }

    /// Whether the Build button works: a build is not running, Clap is not busy, there is a key, and the Go is given with a scene to build.
    public static func startBuild(in s: ProjectActivity.Snapshot, hasKey: Bool, canBuild: Bool, clapRunning: Bool) -> Availability {
        if s.isBuilding { return .unavailable(Unavailable(.building, reason: "A build is already running", way: "Wait for the end, or Cancel the build", link: .build)) }
        if !hasKey { return .unavailable(Reasons.noKey) }
        if clapRunning { return .unavailable(Reasons.clapBusy) }
        if !canBuild { return .unavailable(Unavailable(.notReady, reason: "The build waits for the Go", way: "Validate every scene, then give the Go from the Scene editor")) }
        return .available
    }

    /// Whether Clap can be asked something: a key, and not while it is already answering.
    public static func askClap(in s: ProjectActivity.Snapshot, hasKey: Bool, clapRunning: Bool) -> Availability {
        if !hasKey { return .unavailable(Reasons.noKey) }
        if clapRunning { return .unavailable(Reasons.clapBusy) }
        return .available
    }
}

extension ProjectActivity.Snapshot {
    /// Why a typed operation is refused by what is going on (not by the rules of the project): a build in progress, or a proposal waiting on what it touches.
    public func refusal(of op: ProjectOperation) -> Unavailable? {
        if isBuilding, op.buildPolicy == .refused { return Reasons.building }
        for t in op.targets { if let p = proposal(blocking: t) { return Reasons.proposal(p) } }
        return nil
    }
}

extension ProjectStore {
    public var activity: ProjectActivity { ProjectActivity.for(root) }

    /// The one place that says no while a build is running: for the typed operations (through plan), undo and redo, a file the user edits, files added, an update, a restore.
    public func buildRefusal() -> AgentError? {
        activity.snapshot.isBuilding ? AgentError.msg(Reasons.building.message) : nil
    }

    /// A proposal that was not answered because the window closed or the app quit: it is not applied, and the journal says so.
    public func noteUnanswered(_ p: ProjectActivity.Pending) {
        journal.append(JournalEntry(author: "clap", op: p.isFile ? "file" : "proposal", target: p.targets.first.map { "\($0)" } ?? "", title: p.title, state: "refused",
                                    note: "not answered: the window was closed or the app was quit", session: sessionID))
    }
}

// MARK: what Clap is doing

public enum ClapActivity {
    static let reading: Set<String> = ["get_state", "read_file", "list_dir", "screenshot_preview", "show_page", "ask_user", "open_block", "remember", "update_memory", "forget", "bash"]

    /// What a tool call of Clap's means for the interface: reading and asking leave it thinking; a change names the scenes it works on.
    public static func work(for tool: String, input: [String: Any]) -> ProjectActivity.ClapWork {
        if reading.contains(tool) || tool.hasPrefix("get_") || tool.hasPrefix("read_") { return .thinking }
        var refs: [ElementRef] = []
        for k in ["id", "scene", "from", "before", "after"] { if let v = input[k] as? String, v.hasPrefix("S") { refs.append(.scene(v)) } }
        if let l = input["scenes"] as? [String] { refs += l.map { .scene($0) } }
        return .applying(Array(Set(refs)).sorted { "\($0)" < "\($1)" })
    }

    /// The words of the activity chip.
    public static func label(_ s: ProjectActivity.Snapshot) -> String? {
        if !s.proposals.isEmpty { return "Waiting for your answer: \(s.proposals.count) proposal\(s.proposals.count == 1 ? "" : "s") from Clap" }
        switch s.clap {
        case .thinking?: return "Clap is thinking\u{2026}"
        case .applying?: return "Clap is applying changes\u{2026}"
        case nil: return nil
        }
    }
}

// MARK: the line at the bottom of the window

public struct StatusLine: Equatable, Sendable {
    public enum Kind: Sendable { case applied, refused }
    public let kind: Kind
    public let text: String
    public let targets: [ElementRef]
    public let undoable: Bool
    public init(kind: Kind, text: String, targets: [ElementRef], undoable: Bool) { self.kind = kind; self.text = text; self.targets = targets; self.undoable = undoable }

    /// The end of an assembly: "Film assembled: 6 scenes, 3 transitions".
    public static func assembled(_ o: AssemblyOutcome) -> StatusLine { StatusLine(kind: .applied, text: o.message, targets: [], undoable: false) }

    /// The end of a generation: "2 scenes generated".
    public static func generated(_ ids: [String]) -> StatusLine {
        StatusLine(kind: .applied, text: "\(ids.count) scene\(ids.count == 1 ? "" : "s") generated: \(ids.joined(separator: ", ")). Assemble the film to see \(ids.count == 1 ? "it" : "them").", targets: ids.map { .scene($0) }, undoable: false)
    }

    /// "Applied: S02 duration 4 s to 6 s", from the card the operation made.
    public static func applied(_ op: ProjectOperation, card: OperationCard) -> StatusLine { applied(card: card, targets: op.targets) }

    public static func applied(card: OperationCard, targets: [ElementRef]) -> StatusLine {
        var t = "Applied: "
        if let c = card.changes.first {
            t += "\(c.label) \(c.before) to \(c.after)"
            if card.changes.count > 1 { t += " (+\(card.changes.count - 1) more)" }
        } else { t += card.title }
        return StatusLine(kind: .applied, text: t, targets: targets, undoable: true)
    }

    /// A refusal, with its reason and the way out (the sentence the rule gave).
    public static func refused(_ message: String, op: ProjectOperation? = nil) -> StatusLine {
        StatusLine(kind: .refused, text: "Not done: " + message, targets: op?.targets ?? [], undoable: false)
    }
}

// MARK: a build in progress

public enum BuildProgress {
    /// How far the scene files are: `done` written of `total`, and the one being written ("Scene 3 of 6"). Read from the version folder.
    public static func scenes(version: String, store: ProjectStore) -> (done: Int, total: Int, current: String?) {
        guard let f = store.loadShowreel() else { return (0, 0, nil) }
        let ids = f.film.map { $0.id }
        let done = ids.filter { SceneModules.moduleHash(version: version, scene: $0, store: store) != nil }.count
        return (done, ids.count, done < ids.count ? ids.first { SceneModules.moduleHash(version: version, scene: $0, store: store) == nil } : nil)
    }

    public static func elapsed(_ s: TimeInterval) -> String { s < 60 ? "\(Int(s)) s" : "\(Int(s / 60)) min" }

    /// "Step 7, about 12 400 output tokens": nil until Clap has started.
    public static func usageLine(turns: Int, outputTokens: Int) -> String? {
        guard turns > 0 else { return nil }
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "; f.locale = Locale(identifier: "en_US")
        return "Step \(turns), \(outputTokens == 0 ? "" : "about ")\(f.string(from: NSNumber(value: outputTokens)) ?? "\(outputTokens)") output tokens"
    }

    /// "12 400 output tokens" (an estimate while Clap writes); nil when none yet.
    public static func tokensLine(_ n: Int) -> String? {
        guard n > 0 else { return nil }
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "; f.locale = Locale(identifier: "en_US")
        return "\(f.string(from: NSNumber(value: n)) ?? "\(n)") tokens"
    }

    /// The scene line of the panel: "Scene 3 of 6".
    public static func sceneLine(done: Int, total: Int) -> String? { total == 0 ? nil : "Scene \(min(done + 1, total)) of \(total)" }

    /// The last version that was built and works (it has a page in dist/), or nil.
    public static func lastWorking(_ store: ProjectStore) -> String? { Versions.working(store) }
}

// MARK: closing

/// Whether closing, quitting or replacing the project's files needs a warning, and what it says. The texts follow what the code really does: the work in the version
/// folder stays on disk, nothing is refunded, an answer is interrupted but what it applied stays, an unanswered proposal is recorded as refused.
public enum CloseGuard {
    public enum Context: String, CaseIterable, Sendable { case closeWindow, quit, openOtherProject, updateProject, restoreBackup }

    public struct Alert: Equatable, Sendable {
        public let title: String
        public let lines: [String]
        public let keep: String
        public let confirm: String
        public let cancelsBuild: Bool
        public let interruptsClap: Bool
        public let proposals: Int
    }

    static func verb(_ c: Context) -> (action: String, button: String) {
        switch c {
        case .closeWindow: return ("close this window", "close")
        case .quit: return ("quit", "quit")
        case .openOtherProject: return ("open another project", "open it")
        case .updateProject: return ("update the project", "update")
        case .restoreBackup: return ("restore the backup", "restore")
        }
    }

    /// nil when nothing is in progress. Opening another project from the library opens another window and interrupts nothing, so it never warns.
    public static func alert(_ s: ProjectActivity.Snapshot, context: Context, scenes: (done: Int, total: Int)? = nil, lastWorking: String?, now: Date = Date()) -> Alert? {
        if context == .openOtherProject || s.isIdle { return nil }
        let v = verb(context)
        var lines: [String] = []
        var title = ""
        if let b = s.build {
            let age = BuildProgress.elapsed(now.timeIntervalSince(b.started))
            let keptAt = lastWorking.map { "the film stays at its last working version (\($0))" } ?? "the film has no working version yet"
            if b.phase == .testing {
                title = "The film is being tested"
                lines.append("The film \(b.version) is being assembled and tested (\(age)). If you \(v.action), the checks stop: nothing is lost, \(b.version) stays as it was written and can be tested again with Test it again; \(keptAt). No tokens are used in this step.")
            } else {
                title = "A build is running"
                let prog = scenes.flatMap { BuildProgress.sceneLine(done: $0.done, total: $0.total).map { $0.lowercased() } }
                lines.append("A build is running (\(prog.map { $0 + ", " } ?? "")\(age)). If you \(v.action), the build stops. What it wrote so far stays in \(b.version) (the scene files written until now), not assembled and not tested; \(keptAt). Tokens already used are not refunded.")
            }
        }
        if s.clap != nil, s.build == nil {
            title = "Clap is working"
            lines.append("Clap is answering. If you \(v.action), the answer stops there: what it already changed stays (each change is in the journal and can be undone), what it had not done yet is not done. Tokens already used are not refunded.")
        }
        let typed = s.proposals.filter { !$0.isFile }.count, files = s.proposals.filter { $0.isFile }.count
        if typed + files > 0 {
            if title.isEmpty { title = "Clap is waiting for your answer" }
            var t = "\(s.proposals.count) proposal\(s.proposals.count == 1 ? " from Clap is" : "s from Clap are") waiting for your answer. If you \(v.action), none is applied"
            if typed > 0 { t += "; \(typed == 1 ? "the change is" : "the \(typed) changes are") recorded as refused in the journal" }
            if files > 0 { t += "; \(files == 1 ? "the proposed edit of a file is" : "the \(files) proposed edits of files are") dropped and the file stays as it is" }
            lines.append(t + ".")
        }
        guard !lines.isEmpty else { return nil }
        let confirm = s.build != nil ? "Cancel build and \(v.button)" : (context == .closeWindow || context == .quit ? "\(v.button.capitalized) anyway" : "Stop Clap and \(v.button)")
        return Alert(title: title, lines: lines, keep: "Keep working", confirm: confirm, cancelsBuild: s.build != nil, interruptsClap: s.clap != nil, proposals: s.proposals.count)
    }
}
