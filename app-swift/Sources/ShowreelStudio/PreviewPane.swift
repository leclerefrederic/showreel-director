import SwiftUI
import WebKit

struct PreviewPane: View {
    @EnvironmentObject var model: ChatModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(model.previewTitle).font(.headline).lineLimit(1)
                Spacer()
                Button { model.pastePicks() } label: { Label("Send my picks to the chat", systemImage: "arrowshape.turn.up.left") }
                    .help("Pastes what the page copied to the clipboard into the message box")
                    .disabledWithReason(model.previewURL == nil ? "Nothing is shown yet" : nil)
                Button { model.revealPreview() } label: { Image(systemName: "folder") }
                    .help("Show in Finder")
                    .disabledWithReason(model.previewURL == nil ? "Nothing is shown yet" : nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            Divider()
            if let url = model.previewURL {
                WebPreview(url: url, nonce: model.previewNonce, onCreate: { model.previewWebView = $0 })
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Pages open here")
                        .foregroundStyle(.secondary)
                    Text("Look board, pickers, scene cards, the reel.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
            }
        }
    }
}

/// Shows a local HTML page of the project or of the skill (pickers, boards, the reel).
struct WebPreview: NSViewRepresentable {
    let url: URL
    let nonce: Int
    let onCreate: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKUIDelegate {
        var loaded: (URL, Int)?
        // Links that open a new window (font specimens, for example) go to the default browser.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let u = navigationAction.request.url { NSWorkspace.shared.open(u) }
            return nil
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        w.uiDelegate = context.coordinator
        if #available(macOS 13.3, *) { w.isInspectable = true }
        onCreate(w)
        return w
    }

    func updateNSView(_ w: WKWebView, context: Context) {
        if let l = context.coordinator.loaded, l.0 == url, l.1 == nonce { return }
        context.coordinator.loaded = (url, nonce)
        w.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }
}
