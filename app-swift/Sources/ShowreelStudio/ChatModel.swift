import AppKit
import Foundation
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

struct ChatItem: Identifiable {
    enum Kind { case user, assistant, steps, question, notice }
    let id = UUID()
    var kind: Kind
    var text = ""
    var steps: [String] = []
    var questions: [ChoiceQuestion] = []
    var answers: [String]? = nil
}

/// State of the window. Every mutation happens on the main thread; the agent calls in from other threads
/// through the `AgentUI` methods, which hop to the main queue.
final class ChatModel: ObservableObject, AgentUI {
    @Published var items: [ChatItem] = []
    @Published var draft = ""
    @Published var running = false
    @Published var scrollTick = 0
    @Published var project: String?
    @Published var hasKey = false
    @Published var showSettings = false
    @Published var previewURL: URL?
    @Published var previewTitle = "Preview"
    @Published var previewNonce = 0

    /// The preview pane's web view, set when it is created; used for screenshots.
    var previewWebView: WKWebView?
    private var agent: Agent?
    private var pending: CheckedContinuation<[String], Never>?
    private var assistantIdx: Int?
    private var stepsIdx: Int?
    private let defaults = UserDefaults.standard
    private var cachedKey: String? // the Keychain is read once per launch, at the first message

    var modelName: String { defaults.string(forKey: "model") ?? "claude-sonnet-5-5" }
    var baseURL: String { defaults.string(forKey: "baseURL") ?? ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"] ?? "" }
    var bearer: Bool { defaults.bool(forKey: "bearer") }
    var projectName: String { project.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Choose a folder" }

    init() {
        project = defaults.string(forKey: "project")
        hasKey = keyExists()
    }

    private func envKey() -> String? {
        let env = ProcessInfo.processInfo.environment
        for name in ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"] {
            if let v = env[name], !v.isEmpty { return v }
        }
        return nil
    }

    /// Whether a key is available, without reading the Keychain secret (no prompt).
    private func keyExists() -> Bool { cachedKey != nil || Keychain.exists() || envKey() != nil }

    /// The key itself: the first call may show the Keychain prompt, later calls use the cached value.
    private func apiKey() -> String? {
        if let k = cachedKey { return k }
        if let k = Keychain.get(), !k.isEmpty { cachedKey = k; return k }
        return envKey()
    }

    // MARK: user actions (main thread)

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !running else { return }
        guard let key = apiKey() else { notice("Add your API key in Settings to start."); showSettings = true; return }
        guard let proj = project else { notice("Choose a project folder first."); pickProject(); return }
        draft = ""
        items.append(ChatItem(kind: .user, text: text))
        assistantIdx = nil; stepsIdx = nil
        running = true; scrollTick += 1
        do {
            if agent == nil {
                agent = try Agent(apiKey: key, model: modelName, baseURL: baseURL, bearer: bearer,
                                  project: URL(fileURLWithPath: proj), ui: self)
            }
        } catch {
            notice("Error: \(error.localizedDescription)"); running = false; return
        }
        guard let a = agent else { return }
        Task { [weak self] in
            do { try await a.send(text) } catch { self?.postNotice("Error: \(error.localizedDescription)") }
            self?.finish()
        }
    }

    func stop() {
        agent?.abort()
        resumePending([])
    }

    func reset() {
        agent?.abort()
        resumePending([])
        agent = nil
        items = []
        assistantIdx = nil; stepsIdx = nil
        running = false
    }

    func pickProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.begin { [weak self] r in
            guard r == .OK, let u = panel.url, let self = self else { return }
            self.defaults.set(u.path, forKey: "project")
            self.project = u.path
            self.agent = nil
        }
    }

    func saveSettings(key: String, url: String, bearer: Bool, modelName: String) {
        if !key.isEmpty { Keychain.set(key); cachedKey = key }
        var u = url.trimmingCharacters(in: .whitespaces)
        while u.hasSuffix("/") { u.removeLast() }
        defaults.set(u, forKey: "baseURL")
        defaults.set(bearer, forKey: "bearer")
        let m = modelName.trimmingCharacters(in: .whitespaces)
        defaults.set(m.isEmpty ? "claude-sonnet-5-5" : m, forKey: "model")
        hasKey = keyExists()
        agent = nil
    }

    func submit(_ itemID: UUID, answers: [String]) {
        if let i = items.firstIndex(where: { $0.id == itemID }) { items[i].answers = answers }
        resumePending(answers)
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

    private func resumePending(_ answers: [String]) {
        let c = pending
        pending = nil
        c?.resume(returning: answers)
    }

    private func notice(_ t: String) {
        items.append(ChatItem(kind: .notice, text: t)); scrollTick += 1
    }

    private func postNotice(_ t: String) { DispatchQueue.main.async { self.notice(t) } }
    private func finish() { DispatchQueue.main.async { self.running = false; self.assistantIdx = nil } }

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

    func endText() { DispatchQueue.main.async { self.assistantIdx = nil } }

    func tool(_ name: String, _ input: [String: Any]) {
        var d = name
        if name == "bash" { d += ": " + String((input["command"] as? String ?? "").prefix(200)) }
        else if let p = input["path"] as? String { d += ": " + p }
        DispatchQueue.main.async {
            self.assistantIdx = nil
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
                self.stepsIdx = nil; self.assistantIdx = nil
                self.pending = c
                let qs = questions.enumerated().map { ChoiceQuestion($0.element, index: $0.offset) }
                self.items.append(ChatItem(kind: .question, questions: qs))
                self.scrollTick += 1
            }
        }
    }
}
