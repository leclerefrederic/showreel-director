import Foundation
import WebKit

/// Sends agent events to the web UI and waits for the user's answers to question cards.
final class UIBridge {
    weak var webView: WKWebView?
    private let lock = NSLock()
    private var pending: CheckedContinuation<[String], Never>?

    func emit(_ ev: String, _ args: [Any]) {
        let js = "window.__studioEmit(\(jsonString(ev)), \(jsonString(args)))"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func text(_ t: String) { emit("text", [t]) }
    func endText() { emit("end", []) }
    func tool(_ name: String, _ input: [String: Any]) { emit("tool", [name, input]) }
    func show(_ url: String, _ title: String) { emit("show", [url, title]) }

    func ask(_ questions: [[String: Any]]) async -> [String] {
        await withCheckedContinuation { (c: CheckedContinuation<[String], Never>) in
            lock.lock(); pending = c; lock.unlock()
            emit("ask", [questions])
        }
    }

    func answer(_ answers: [String]) {
        lock.lock(); let c = pending; pending = nil; lock.unlock()
        c?.resume(returning: answers)
    }
}
