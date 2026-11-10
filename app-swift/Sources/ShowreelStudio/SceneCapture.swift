import AppKit
import ShowreelKit
import WebKit

/// Captures a scene's thumbnail (W4b): the built film's own page, loaded in a web view that is never shown, put at one instant and snapshotted as a PNG. One film page per version
/// stays loaded for every scene of that version. The rules (keys, states, storage, queue) are ShowreelKit's `SceneThumbs`; this only drives the web view. Main thread only.
@MainActor
final class SceneCapture: NSObject, WKNavigationDelegate {
    static let shared = SceneCapture()
    static let size = CGSize(width: 640, height: 360)
    private let web: WKWebView
    private let host: NSWindow
    private var loaded: URL?
    private var navigation: CheckedContinuation<LoadOutcome, Never>?
    private var gate = LoadGate()

    override init() {
        let c = WKWebViewConfiguration()
        c.mediaTypesRequiringUserActionForPlayback = []
        let css = "var s=document.createElement('style');s.textContent='#bar,#ov{display:none!important}';document.head.appendChild(s);"
        c.userContentController.addUserScript(WKUserScript(source: css, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        web = WKWebView(frame: CGRect(origin: .zero, size: Self.size), configuration: c)
        // a web view only draws inside a window that is on a screen and ordered in (W4c: off screen or ordered back, the page's clock never runs and every picture is blank): this one is
        // the size of the picture, nearly transparent, in the screen's lower left corner, deaf to the mouse, and out of the Window menu and of the cycle
        let corner = NSScreen.main?.visibleFrame.origin ?? .zero
        host = NSWindow(contentRect: CGRect(origin: corner, size: Self.size), styleMask: .borderless, backing: .buffered, defer: false)
        super.init()
        web.navigationDelegate = self
        host.contentView = web; host.alphaValue = 0.01; host.ignoresMouseEvents = true; host.isReleasedWhenClosed = false
        host.isExcludedFromWindowsMenu = true; host.collectionBehavior = [.transient, .ignoresCycle, .stationary]; host.level = .normal
        host.orderFrontRegardless()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finishLoading(.loaded) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finishLoading(.failed) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finishLoading(.failed) }
    /// Ends the load that owns `token` (the current one for the web view's own callbacks); a timeout of an earlier load finds its token stale and does nothing (RF2).
    private func finishLoading(_ outcome: LoadOutcome, token: Int? = nil) {
        guard gate.finish(token ?? gate.current) else { return }
        navigation?.resume(returning: outcome); navigation = nil
    }

    private func load(_ url: URL) async -> LoadOutcome {
        if loaded == url { return .loaded }
        loaded = nil
        if gate.isPending { navigation?.resume(returning: .superseded); navigation = nil }
        let token = gate.begin()
        let outcome: LoadOutcome = await withCheckedContinuation { c in
            navigation = c
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            Task { @MainActor [weak self] in try? await Task.sleep(nanoseconds: 20_000_000_000); self?.finishLoading(.timedOut, token: token) }          // a page that never ends loading is a failure, not a hang
        }
        if outcome == .loaded { loaded = url }
        return outcome
    }

    /// The PNG of the scene at the job's instant, or the reason it could not be made.
    func capture(_ job: SceneThumbs.Job, store: ProjectStore) async -> Result<Data, CaptureError> {
        let page = Versions.distURL(store, job.version)
        guard FileManager.default.fileExists(atPath: page.path) else { return .failure(CaptureError("The built page of \(job.version) is missing.")) }
        let loading = await load(page)
        guard loading == .loaded else { return .failure(CaptureError("The film page did not load.", transient: loading.isTransient)) }
        let js = "(function(){var s=document.getElementById('seek');if(!s)return false;s.value=Math.round(\(job.time) * 10);s.dispatchEvent(new Event('input'));return true;})()"
        guard let ok = try? await web.evaluateJavaScript(js) as? Bool, ok else { return .failure(CaptureError("The film page has no seek control.")) }
        // the page draws on its own clock: wait until that clock shows the instant, so that what is snapshotted is the scene and not the page before its first frame
        let want = SceneThumbs.timecode(job.time)
        var drew = false
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let tm = try? await web.evaluateJavaScript("document.getElementById('tm') ? document.getElementById('tm').textContent : ''") as? String, tm.hasPrefix(want) { drew = true; break }
        }
        guard drew else { return .failure(CaptureError("The film page did not draw the scene (its clock never reached \(want)).")) }
        try? await Task.sleep(nanoseconds: 150_000_000)          // one more frame after the clock moved
        let cfg = WKSnapshotConfiguration(); cfg.rect = CGRect(origin: .zero, size: Self.size); cfg.snapshotWidth = NSNumber(value: Double(Self.size.width))
        let image: NSImage? = await withCheckedContinuation { c in web.takeSnapshot(with: cfg) { img, _ in c.resume(returning: img) } }
        guard let img = image, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
            return .failure(CaptureError("The web view gave no image."))
        }
        return .success(png)
    }

    /// `transient`: a timeout or a cancelled load says nothing about the scene, so it is not remembered as the scene's failure and the capture is tried again.
    struct CaptureError: Error { let message: String; let transient: Bool; init(_ m: String, transient: Bool = false) { message = m; self.transient = transient } }
}
