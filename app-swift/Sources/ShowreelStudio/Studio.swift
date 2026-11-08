import AppKit
import Security
import WebKit

enum Keychain {
    static let service = "ShowreelStudio"
    static func get() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func set(_ v: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(v.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Bridge between the web UI (window.studio) and the native side.
final class Studio: NSObject, WKScriptMessageHandlerWithReply, WKUIDelegate {
    let ui = UIBridge()
    private var agent: Agent?
    private let defaults = UserDefaults.standard

    private var model: String { defaults.string(forKey: "model") ?? "claude-sonnet-5-5" }
    private var project: String? { defaults.string(forKey: "project") }
    private func apiKey() -> String? {
        if let k = Keychain.get(), !k.isEmpty { return k }
        let e = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        return (e?.isEmpty == false) ? e : nil
    }

    func attach(_ web: WKWebView) { ui.webView = web }

    /// Defines window.studio in the page, calling the native handler.
    static let glue = """
    (function(){
      const L={};
      window.__studioEmit=function(ev,args){(L[ev]||[]).forEach(function(f){f.apply(null,args)})};
      const call=function(name,arg){return window.webkit.messageHandlers.studio.postMessage({name:name,arg:arg===undefined?null:arg})};
      const on=function(ev){return function(f){(L[ev]=L[ev]||[]).push(f)}};
      window.studio={
        cfg:function(){return call('cfg')},setKey:function(k){return call('setKey',k)},setModel:function(m){return call('setModel',m)},
        pickProject:function(){return call('pickProject')},send:function(t){return call('send',t)},stop:function(){return call('stop')},
        reset:function(){return call('reset')},answer:function(a){return call('answer',a)},
        readClipboard:function(){return call('readClipboard')},reveal:function(f){return call('reveal',f)},
        onText:on('text'),onEnd:on('end'),onTool:on('tool'),onAsk:on('ask'),onShow:on('show')
      };
    })();
    """

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any], let name = body["name"] as? String else {
            replyHandler(nil, "bad message"); return
        }
        let arg = body["arg"]
        switch name {
        case "cfg":
            replyHandler(["hasKey": apiKey() != nil, "model": model, "project": project ?? ""], nil)
        case "setKey":
            if let k = arg as? String { Keychain.set(k); agent = nil }
            replyHandler(true, nil)
        case "setModel":
            if let m = arg as? String { defaults.set(m, forKey: "model"); agent = nil }
            replyHandler(true, nil)
        case "pickProject":
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
            panel.begin { [weak self] r in
                if r == .OK, let u = panel.url {
                    self?.defaults.set(u.path, forKey: "project"); self?.agent = nil
                    replyHandler(u.path, nil)
                } else { replyHandler("", nil) }
            }
        case "send":
            let text = arg as? String ?? ""
            Task { replyHandler(await self.send(text), nil) }
        case "stop":
            agent?.abort(); ui.answer([]); replyHandler(true, nil)
        case "reset":
            agent = nil; replyHandler(true, nil)
        case "answer":
            ui.answer((arg as? [Any])?.map { "\($0)" } ?? []); replyHandler(true, nil)
        case "readClipboard":
            replyHandler(NSPasteboard.general.string(forType: .string) ?? "", nil)
        case "reveal":
            if let s = arg as? String, let u = URL(string: s), u.isFileURL { NSWorkspace.shared.activateFileViewerSelecting([u]) }
            replyHandler(true, nil)
        default:
            replyHandler(nil, "unknown call \(name)")
        }
    }

    private func send(_ text: String) async -> String {
        guard let key = apiKey() else { return "Set your API key first." }
        guard let proj = project else { return "Choose a project folder first." }
        do {
            if agent == nil { agent = try Agent(apiKey: key, model: model, project: URL(fileURLWithPath: proj), ui: ui) }
            try await agent!.send(text)
            return ""
        } catch { return "Error: \(error.localizedDescription)" }
    }

    // JavaScript prompt() (used for the API key field): native text input dialog.
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = NSAlert()
        a.messageText = prompt
        let f = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
        f.stringValue = defaultText ?? ""
        a.accessoryView = f
        a.addButton(withTitle: "OK"); a.addButton(withTitle: "Cancel")
        completionHandler(a.runModal() == .alertFirstButtonReturn ? f.stringValue : nil)
    }

    // Links that open a new window (font specimens, for example) go to the default browser.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = navigationAction.request.url { NSWorkspace.shared.open(u) }
        return nil
    }
}
