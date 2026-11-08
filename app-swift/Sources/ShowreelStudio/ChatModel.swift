import AppKit
import Foundation
import ShowreelKit
import WebKit

struct ChoiceOption: Identifiable {
    let id = UUID()
    let label: String
    let detail: String
}

struct ChoiceQuestion: Identifiable {
    let id = UUID()
    let header: String
    let text: String
    let multi: Bool
    let options: [ChoiceOption]

    init(_ d: [String: Any], index: Int) {
        header = d["header"] as? String ?? "Q\(index + 1)"
        text = d["question"] as? String ?? ""
        multi = d["multiSelect"] as? Bool ?? false
        options = (d["options"] as? [[String: Any]] ?? []).map {
            ChoiceOption(label: $0["label"] as? String ?? "", detail: $0["description"] as? String ?? "")
        }
    }
}

struct ProposalState {
    enum Status { case pending, accepted, refused }
    let proposal: Proposal
    let rows: [LineDiff.Row]
    var status: Status = .pending
}

struct OperationState {
    let card: OperationCard
    var status: ProposalState.Status = .pending
}

struct ChatItem: Identifiable {
    enum Kind { case user, assistant, steps, question, notice, proposal, operation }
    let id = UUID()
    var kind: Kind
    var text = ""
    var steps: [String] = []
    var questions: [ChoiceQuestion] = []
    var answers: [String]? = nil
    var proposal: ProposalState? = nil
    var operation: OperationState? = nil
}

/// The copilot of one project window: chat items, the agent, the preview pane's state.
/// @unchecked Sendable: every mutation of the published state happens on the main queue; the agent calls in from other threads
/// through the `AgentUI` methods, which hop to the main queue first.
final class ChatModel: ObservableObject, AgentUI, @unchecked Sendable {
    @Published var items: [ChatItem] = []
    @Published var draft = ""
    @Published var running = false
    @Published var scrollTick = 0
    @Published var showSettings = false
    @Published var previewURL: URL?
    @Published var previewTitle = "Preview"
    @Published var previewNonce = 0

    /// The preview pane's web view, set when it is created; used for screenshots.
    var previewWebView: WKWebView?
    let project: ProjectModel
    private let settings = AppSettings.shared
    private let history: ChatStore
    private var records: [ChatRecord]
    private var agent: Agent?
    private var agentGeneration = -1
    private var pending: CheckedContinuation<[String], Never>?
    private var pendingProposals: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private var pendingOperations: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private var assistantIdx: Int?
    private var stepsIdx: Int?
    /// Called once when the message sent with ask(prompt:onDone:) has been fully answered (the agent's turn is over).
    private var onDone: (() -> Void)?

    init(project: ProjectModel) {
        self.project = project
        history = ChatStore(root: project.root)
        records = history.load()
        items = records.map { ChatItem(kind: $0.role == "user" ? .user : .assistant, text: $0.text) }
    }

    var hasKey: Bool { settings.hasKey }

    // MARK: user actions (main thread)

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !running else { return }
        guard let key = settings.apiKey() else { notice("Connect an AI to talk to the copilot. Everything else works without one."); return }
        draft = ""
        items.append(ChatItem(kind: .user, text: text))
        remember(ChatRecord(role: "user", text: text))
        assistantIdx = nil; stepsIdx = nil
        running = true; scrollTick += 1
        do {
            if agent == nil || agentGeneration != settings.generation {
                agent = try Agent(apiKey: key, model: settings.modelName, baseURL: settings.baseURL, bearer: settings.bearer,
                                  project: project.root, ui: self, history: ChatStore.seed(from: records))
                agentGeneration = settings.generation
            }
        } catch {
            notice("Error: \(error.localizedDescription)"); running = false; return
        }
        guard let a = agent else { return }
        let context = project.contextLine
        Task { [weak self] in
            do { try await a.send(text, context: context) } catch { self?.postNotice("Error: \(error.localizedDescription)") }
            self?.finish()
        }
    }

    /// Sends a message on the user's behalf (the wizard's "Suggest with AI"). The copilot answers with a card to accept or refuse.
    @discardableResult
    func ask(prompt: String, onDone: (() -> Void)? = nil) -> Bool {
        guard !running else { notice("The copilot is busy: wait for it to finish."); return false }
        guard settings.hasKey else { notice("Connect an AI to talk to the copilot. Everything else works without one."); return false }
        draft = prompt
        self.onDone = onDone
        send()
        return running
    }

    func stop() {
        agent?.abort()
        resumePending([])
        resolveAllProposals(false)
    }

    /// Starts a new session: the old one stays in `.studio/chat/`.
    func reset() {
        agent?.abort()
        resumePending([])
        resolveAllProposals(false)
        agent = nil
        items = []
        records = []
        history.startNewSession()
        assistantIdx = nil; stepsIdx = nil
        running = false
    }

    func submit(_ itemID: UUID, answers: [String]) {
        if let i = items.firstIndex(where: { $0.id == itemID }) { items[i].answers = answers }
        resumePending(answers)
        scrollTick += 1
    }

    func resolveProposal(_ itemID: UUID, accept: Bool) {
        if let i = items.firstIndex(where: { $0.id == itemID }) { items[i].proposal?.status = accept ? .accepted : .refused }
        pendingProposals.removeValue(forKey: itemID)?.resume(returning: accept)
        scrollTick += 1
    }

    func pastePicks() {
        guard let t = NSPasteboard.general.string(forType: .string), !t.isEmpty else { return }
        draft += (draft.isEmpty ? "" : "\n") + t
    }

    func revealPreview() {
        if let u = previewURL { NSWorkspace.shared.activateFileViewerSelecting([u]) }
    }

    // MARK: helpers (main thread)

    private func remember(_ r: ChatRecord) { records.append(r); history.append(r) }

    private func resumePending(_ answers: [String]) {
        let c = pending
        pending = nil
        c?.resume(returning: answers)
    }

    private func resolveAllProposals(_ accept: Bool) {
        for id in Array(pendingProposals.keys) { resolveProposal(id, accept: accept) }
        for id in Array(pendingOperations.keys) { resolveOperation(id, accept: accept) }
    }

    func resolveOperation(_ itemID: UUID, accept: Bool) {
        if let i = items.firstIndex(where: { $0.id == itemID }) { items[i].operation?.status = accept ? .accepted : .refused }
        pendingOperations.removeValue(forKey: itemID)?.resume(returning: accept)
        scrollTick += 1
    }

    private func notice(_ t: String) {
        items.append(ChatItem(kind: .notice, text: t)); scrollTick += 1
    }

    private func postNotice(_ t: String) { DispatchQueue.main.async { self.notice(t) } }

    /// Writes the assistant text being streamed to the history, once it is complete.
    private func flushAssistant() {
        if let i = assistantIdx, i < items.count, !items[i].text.isEmpty { remember(ChatRecord(role: "assistant", text: items[i].text)) }
        assistantIdx = nil
    }

    private func finish() {
        DispatchQueue.main.async {
            self.flushAssistant(); self.running = false
            let done = self.onDone; self.onDone = nil
            done?()
        }
    }

    // MARK: AgentUI (called from any thread)

    func text(_ t: String) {
        DispatchQueue.main.async {
            if let i = self.assistantIdx {
                self.items[i].text += t
            } else {
                self.stepsIdx = nil
                self.items.append(ChatItem(kind: .assistant, text: t))
                self.assistantIdx = self.items.count - 1
            }
            self.scrollTick += 1
        }
    }

    func endText() { DispatchQueue.main.async { self.flushAssistant() } }

    func tool(_ name: String, _ input: [String: Any]) {
        var d = name
        if name == "bash" { d += ": " + String((input["command"] as? String ?? "").prefix(200)) }
        else if let p = input["path"] as? String ?? input["file"] as? String { d += ": " + p }
        DispatchQueue.main.async {
            self.flushAssistant()
            if let i = self.stepsIdx {
                self.items[i].steps.append(d)
            } else {
                self.items.append(ChatItem(kind: .steps, steps: [d]))
                self.stepsIdx = self.items.count - 1
            }
            self.scrollTick += 1
        }
    }

    func show(_ url: String, _ title: String) {
        DispatchQueue.main.async {
            self.previewURL = URL(string: url)
            self.previewTitle = title
            self.previewNonce += 1
            self.project.selected = .preview
        }
    }

    func foregroundFile() async -> String? { await onMain { self.project.foreground } }
    func foregroundBlock() async -> String? { await onMain { self.project.foregroundBlock } }

    func openBlock(_ id: String) async {
        await onMain {
            // in Beginner mode there are no blocks to switch to: the wizard goes to the first undecided step of that block
            if self.project.mode == StudioSettings.beginner { self.project.jumpToFirstUndecided(in: id) } else { self.project.selectBlock(id) }
        }
    }

    func proposeOperation(_ card: OperationCard) async -> Bool {
        await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            DispatchQueue.main.async {
                self.stepsIdx = nil; self.flushAssistant()
                let item = ChatItem(kind: .operation, operation: OperationState(card: card))
                self.items.append(item)
                self.pendingOperations[item.id] = c
                self.scrollTick += 1
            }
        }
    }

    func propose(_ p: Proposal) async -> Bool {
        await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            DispatchQueue.main.async {
                self.stepsIdx = nil; self.flushAssistant()
                let rows = LineDiff.collapse(LineDiff.diff(p.original ?? "", p.proposed))
                let item = ChatItem(kind: .proposal, proposal: ProposalState(proposal: p, rows: rows))
                self.items.append(item)
                self.pendingProposals[item.id] = c
                self.scrollTick += 1
            }
        }
    }

    private func onMain<T>(_ f: @escaping () -> T) async -> T {
        await withCheckedContinuation { (c: CheckedContinuation<T, Never>) in
            DispatchQueue.main.async { c.resume(returning: f()) }
        }
    }

    /// A JPEG of the preview pane (at most 1280 pt wide), or nil when nothing is open.
    func screenshot(javascript: String?, waitMs: Int) async -> Data? {
        guard await onMain({ self.previewWebView != nil && self.previewURL != nil }) else { return nil }
        for _ in 0..<50 { // let the page finish loading, at most 5 s
            if await onMain({ !(self.previewWebView?.isLoading ?? false) }) { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        if let js = javascript, !js.isEmpty {
            await onMain { self.previewWebView?.evaluateJavaScript(js, completionHandler: nil) }
        }
        try? await Task.sleep(nanoseconds: UInt64(max(0, waitMs)) * 1_000_000)
        return await withCheckedContinuation { (c: CheckedContinuation<Data?, Never>) in
            DispatchQueue.main.async {
                guard let web = self.previewWebView else { c.resume(returning: nil); return }
                web.takeSnapshot(with: nil) { image, _ in
                    c.resume(returning: image.flatMap { Self.jpeg($0) })
                }
            }
        }
    }

    private static func jpeg(_ image: NSImage) -> Data? {
        var img = image
        if image.size.width > 1280 {
            let s = 1280 / image.size.width
            let size = NSSize(width: 1280, height: image.size.height * s)
            let small = NSImage(size: size)
            small.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
            small.unlockFocus()
            img = small
        }
        guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    func ask(_ questions: [[String: Any]]) async -> [String] {
        await withCheckedContinuation { (c: CheckedContinuation<[String], Never>) in
            DispatchQueue.main.async {
                self.stepsIdx = nil; self.flushAssistant()
                self.pending = c
                let qs = questions.enumerated().map { ChoiceQuestion($0.element, index: $0.offset) }
                self.items.append(ChatItem(kind: .question, questions: qs))
                self.scrollTick += 1
            }
        }
    }
}
