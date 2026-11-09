import AppKit
import ShowreelKit
import SwiftUI
import WebKit

/// Plays a built version (vN/dist/index.html) in the viewer. The page is the reel's own player, with its bar and its start overlay hidden: the app's
/// transport (play, pause, scrub, sound) drives it through the page's own controls, and the music is the track embedded in the build. Main thread only.
final class ReelPlayer: NSObject, ObservableObject, WKNavigationDelegate {
    let web: WKWebView
    @Published private(set) var ready = false
    @Published private(set) var started = false
    @Published private(set) var playing = false
    @Published private(set) var time = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var hasTrack = false
    @Published var sound = true
    private(set) var loaded: URL?
    private var target = 0.0
    private var timer: Timer?
    private var lastTime = -1.0
    private var muted = false

    override init() {
        let c = WKWebViewConfiguration()
        c.mediaTypesRequiringUserActionForPlayback = []          // the transport button is the user's gesture: let the page's audio start from it
        let css = "var s=document.createElement('style');s.textContent='#bar,#ov{display:none!important}';document.head.appendChild(s);"
        c.userContentController.addUserScript(WKUserScript(source: css, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        web = WKWebView(frame: .zero, configuration: c)
        super.init()
        web.navigationDelegate = self
        if #available(macOS 13.3, *) { web.isInspectable = true }
    }

    deinit { timer?.invalidate() }

    /// Loads a built page and shows it at `time` (paused). Reloading the same page only seeks.
    func load(_ url: URL, at t: Double, force: Bool = false) {
        target = t
        if loaded == url, ready, !force { seek(t); return }
        loaded = url; ready = false; started = false; playing = false; muted = false; lastTime = -1
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        js("[window.SR.data.dur, !!document.getElementById('trackdata')]") { [weak self] v in
            guard let a = v as? [Any], a.count == 2 else { return }
            self?.duration = (a[0] as? NSNumber)?.doubleValue ?? 0; self?.hasTrack = (a[1] as? NSNumber)?.boolValue ?? false
            self?.seek(self?.target ?? 0)
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.poll() }
    }

    private func js(_ s: String, _ done: ((Any?) -> Void)? = nil) { web.evaluateJavaScript(s) { v, _ in done?(v) } }

    private func poll() {
        guard ready else { return }
        js("Number(document.getElementById('seek').value) / 10") { [weak self] v in
            guard let self = self, let t = (v as? NSNumber)?.doubleValue else { return }
            self.playing = self.started && self.lastTime >= 0 && abs(t - self.lastTime) > 0.04 && t < self.duration - 0.05
            self.lastTime = t
            if self.started { self.time = t }
        }
    }

    /// Puts the reel at `t` seconds (playing or not).
    func seek(_ t: Double) {
        let v = max(0, min(t, max(duration, t)))
        time = v; target = v; lastTime = v
        js("(function(){var s=document.getElementById('seek');s.value=Math.round(\(v) * 10);s.dispatchEvent(new Event('input'));})()")
    }

    /// Play from the current position; the first time it starts the page (with its sound when there is a track and sound is on).
    func play() {
        guard ready else { return }
        if !started {
            let at = time
            js("(function(){var b=document.getElementById('\(sound ? "ov1" : "ov2")');if(!b||b.style.display==='none')b=document.getElementById('ov2');b.click();})()")
            started = true; muted = false
            // the page starts from 0 once its audio is decoded: put it where the playhead is when it runs
            Task { @MainActor in
                for _ in 0..<30 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if self.lastTime > 0.02 || self.duration == 0 { break }
                }
                self.seek(at)
            }
        } else if !playing { js("document.getElementById('pp').click()") }
    }

    func pause() { if started, playing { js("document.getElementById('pp').click()"); playing = false } }
    func toggle() { playing ? pause() : play() }

    /// Sound on or off, also while it plays (the page's own mute).
    func setSound(_ on: Bool) {
        sound = on
        if started, muted == on { js("document.getElementById('mu').click()"); muted = !on }
    }
}

struct ReelWebView: NSViewRepresentable {
    let player: ReelPlayer
    func makeNSView(context: Context) -> WKWebView { player.web }
    func updateNSView(_ v: WKWebView, context: Context) {}
}

/// The viewer when a version is built: the film at the playhead of the reel, with transport and sound.
struct FilmViewer: View {
    let version: String
    @EnvironmentObject var project: ProjectModel
    @ObservedObject var player: ReelPlayer

    private var url: URL { Versions.distURL(project.store, version) }
    private var current: Bool? { Film.isCurrent(version: version, store: project.store) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(version) built").fontSmall(weight: .semibold)
                Spacer()
                Button("Show the preview thumbnails") { project.viewerShowsDraft = true }.buttonStyle(.borderless).fontSmall()
            }
            ReelWebView(player: player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.15)))
            HStack(spacing: 10) {
                Button { project.togglePlay() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill").frame(width: 18) }
                    .keyboardShortcut(.space, modifiers: []).help(player.playing ? "Pause" : "Play from the playhead")
                Slider(value: Binding(get: { project.playhead }, set: { project.playhead = $0 }), in: 0...max(player.duration, 1))
                Text(String(format: "%.1f / %.1f s", project.playhead, player.duration)).fontSmall(digits: true).foregroundStyle(.secondary)
                Toggle(isOn: Binding(get: { player.sound }, set: { player.setSound($0) })) { Image(systemName: player.sound ? "speaker.wave.2.fill" : "speaker.slash.fill") }
                    .toggleStyle(.button).disabled(!player.hasTrack).help(player.hasTrack ? "The music of the build" : "This build has no music")
            }
        }
        .onAppear { player.load(url, at: project.playhead, force: project.playNonce != lastNonce); lastNonce = project.playNonce }
        .onChange(of: project.playNonce) { _ in player.load(url, at: project.playhead, force: true); lastNonce = project.playNonce }
        .onChange(of: version) { _ in player.load(url, at: project.playhead, force: true) }
        .onChange(of: project.playhead) { t in if abs(t - player.time) > 0.12 { player.seek(t) } }       // the reel's playhead was moved by hand
        .onReceive(player.$time) { t in if player.playing, abs(t - project.playhead) > 0.01 { project.playhead = t } }    // the film plays: the playhead follows
        .onDisappear { player.pause() }
    }

    @State private var lastNonce = -1
}

/// Before a build: the outgoing and the incoming scene's thumbnails mixed by the transition of the library (the film layer's own compositor).
struct TransitionPreview: View {
    let from: String
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        if let f = project.showreel, let pair = f.transition(after: from), let a = f.scenes.first(where: { $0.id == from }) {
            VStack(spacing: 10) {
                if pair.item.isCut {
                    HStack(spacing: 8) {
                        SceneThumb(scene: a).clipShape(RoundedRectangle(cornerRadius: 8))
                        Image(systemName: "scissors").foregroundStyle(.secondary)
                        SceneThumb(scene: pair.next).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.frame(maxWidth: 760)
                    Text("\(from) \u{2192} \(pair.next.id): cut on the beat").font(.headline)
                    Text("Choose a transition in the inspector, or drag one from the library onto the marker.").font(.callout).foregroundStyle(.secondary)
                } else {
                    EngineThumb(token: "tp|\(pair.item.type)|\(EngineService.shared.sceneToken(a, f))|\(EngineService.shared.sceneToken(pair.next, f))") {
                        await EngineService.shared.transitionFrames(pair.item.type, from: a, to: pair.next, file: f, store: project.store)
                    }
                    .frame(maxWidth: 760).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("\(from) \u{2192} \(pair.next.id): \(pair.item.text)").font(.headline)
                    PreviewTag()
                    Text("A preview made from the two scenes' thumbnails; the assembled film draws the scenes themselves.").font(.callout).foregroundStyle(.secondary)
                    TransitionNoteView(from: from)
                }
            }
        } else {
            Text("\(from) is the last scene that is on: a transition sits between two scenes.").foregroundStyle(.secondary)
        }
    }
}
