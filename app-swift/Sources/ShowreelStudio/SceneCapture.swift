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
    private var navigation: CheckedContinuation<Bool, Never>?

    override init() {
        let c = WKWebViewConfiguration()
        c.mediaTypesRequiringUserActionForPlayback = []
        let css = "var s=document.createElement('style');s.textContent='#bar,#ov{display:none!important}';document.head.appendChild(s);"
        c.userContentController.addUserScript(WKUserScript(source: css, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        web = WKWebView(frame: CGRect(origin: .zero, size: Self.size), configuration: c)
        // a web view only draws inside a window: this one is the size of the picture, nearly transparent, behind everything, and out of the Window menu and of the cycle
        host = NSWindow(contentRect: CGRect(origin: CGPoint(x: -4000, y: -4000), size: Self.size), styleMask: .borderless, backing: .buffered, defer: false)
        super.init()
        web.navigationDelegate = self
        host.contentView = web; host.alphaValue = 0.01; host.ignoresMouseEvents = true; host.isReleasedWhenClosed = false
        host.isExcludedFromWindowsMenu = true; host.collectionBehavior = [.transient, .ignoresCycle, .stationary]; host.level = .normal
        host.orderBack(nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finishLoading(true) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finishLoading(false) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finishLoading(false) }
    private func finishLoading(_ ok: Bool) { navigation?.resume(returning: ok); navigation = nil }

    private func load(_ url: URL) async -> Bool {
        if loaded == url { return true }
        loaded = nil
        let ok: Bool = await withCheckedContinuation { c in
            navigation = c
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            Task { @MainActor [weak self] in try? await Task.sleep(nanoseconds: 20_000_000_000); self?.finishLoading(false) }          // a page that never ends loading is a failure, not a hang
        }
        if ok { loaded = url }
        return ok
    }

    /// The PNG of the scene at the job's instant, or the reason it could not be made.
    func capture(_ job: SceneThumbs.Job, store: ProjectStore) async -> Result<Data, CaptureError> {
        let page = Versions.distURL(store, job.version)
        guard FileManager.default.fileExists(atPath: page.path) else { return .failure(CaptureError("The built page of \(job.version) is missing.")) }
        guard await load(page) else { return .failure(CaptureError("The film page did not load.")) }
        let js = "(function(){var s=document.getElementById('seek');if(!s)return false;s.value=Math.round(\(job.time) * 10);s.dispatchEvent(new Event('input'));return true;})()"
        guard let ok = try? await web.evaluateJavaScript(js) as? Bool, ok else { return .failure(CaptureError("The film page has no seek control.")) }
        try? await Task.sleep(nanoseconds: 350_000_000)          // let the scene draw its frame
        let cfg = WKSnapshotConfiguration(); cfg.rect = CGRect(origin: .zero, size: Self.size); cfg.snapshotWidth = NSNumber(value: Double(Self.size.width))
        let image: NSImage? = await withCheckedContinuation { c in web.takeSnapshot(with: cfg) { img, _ in c.resume(returning: img) } }
        guard let img = image, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
            return .failure(CaptureError("The web view gave no image."))
        }
        return .success(png)
    }

    struct CaptureError: Error { let message: String; init(_ m: String) { message = m } }
}
