import AppKit
import ShowreelKit
import SwiftUI

/// The autosave of a scene's form (AS1). The rules are ShowreelKit's (`EditSession`, `SceneFields`, `coalesceLast`); this object holds the session, ticks the clock for the pause, turns a commit
/// into the typed operation through the model, and keeps the small marks the form shows ("Saved", "Updated").
final class SceneAutosave: ObservableObject {
    enum Mark { case saved, updated }

    @Published private(set) var session = EditSession(validate: SceneFields.invalid)
    @Published private(set) var marks: [String: Mark] = [:]
    private(set) var sceneID: String?
    weak var project: ProjectModel?
    private var timer: Timer?

    /// Declares the stored values of a scene. A clean field follows a change made elsewhere (Clap, Undo) and says "Updated"; a field being edited keeps the owner's text.
    func bind(_ scene: ShowreelFile.Scene, linked: String) {
        if sceneID != scene.id { flush(); session.close(); sceneID = scene.id; marks = [:] }
        func secs(_ x: Double?) -> String { x.map { ProjectDocs.seconds($0) } ?? "" }
        let values: [(String, String)] = [(SceneFields.duration, secs(scene.duration)), (SceneFields.text, scene.text), (SceneFields.visual, scene.visual),
                                          (SceneFields.feeling, scene.feeling), (SceneFields.handoff, scene.handoff), (SceneFields.assets, linked)]
        for (k, v) in values where session.load(k, stored: v, kind: SceneFields.kind(k)) == .updated && marks[k] == nil { show(.updated, k) }
    }

    func draft(_ key: String) -> String { session.field(key)?.draft ?? "" }
    func invalid(_ key: String) -> String? { session.field(key)?.invalid }

    func edit(_ key: String, _ value: String, stepped: Bool = false) {
        guard session.field(key)?.draft != value else { return }
        if let c = session.edit(key, draft: value, at: Date(), stepped: stepped) { run(c) }
        objectWillChange.send()
        if !session.pending.isEmpty { startTimer() }
    }

    /// A step with the stepper or the arrow keys: committed after a short debounce, not at each tick.
    func step(_ key: String) { session.markStepped(key, at: Date()); objectWillChange.send(); startTimer() }

    func blur(_ key: String) { if let c = session.blur(key) { run(c) } }
    func returnKey(_ key: String) { if let c = session.returnKey(key) { run(c) } }
    func restore(_ key: String) { session.restore(key); objectWillChange.send() }

    /// Commits whatever is pending: before another scene, another tab, a closed pane or window, a Build.
    func flush() { for c in session.flush() { run(c) } }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            for c in self.session.due(at: Date()) { self.run(c) }
            if self.session.pending.isEmpty { t.invalidate(); self.timer = nil }
        }
    }

    private func run(_ c: EditSession.Commit) {
        guard let id = sceneID, let project else { return }
        switch project.commitSceneField(id, c.key, c.value, session: &session) {
        case .saved:
            show(.saved, c.key)
            // what was typed is stored now: the field's own undo must not also take it back, so Command-Z goes to the app's Undo
            (NSApp.keyWindow?.firstResponder as? NSTextView)?.undoManager?.removeAllActions()
        case .refused(let why): session.refused(c.key, reason: why)
        }
        objectWillChange.send()
    }

    private func show(_ m: Mark, _ key: String) {
        marks[key] = m
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in if self?.marks[key] == m { self?.marks[key] = nil } }
    }
}

extension ProjectModel {
    enum FieldCommit { case saved, refused(String) }

    /// One commit of a scene's form: the same typed operation and `plan()` as ever, one undo step per field per 2 s, the journal line, and the status line only when the commit sent the
    /// scene back to To review (once per session). A refusal keeps the draft and gives its reason.
    func commitSceneField(_ id: String, _ key: String, _ value: String, session: inout EditSession) -> FieldCommit {
        let op = ProjectOperation.scene(id: id, SceneFields.edit(key, value))
        let wasValidated = showreel?.scenes.first { $0.id == id }?.state == .validated
        do {
            try store.apply(op)
            store.coalesceLast(key: SceneFields.undoKey(id, key))
            session.stored(key, value)
            refresh(); LibraryModel.shared.touch(path: root.path, name: title, step: showreel?.step)
            if wasValidated, showreel?.scenes.first(where: { $0.id == id })?.state != .validated, session.announceReview(id) { react(.backToReview(id)) }
            return .saved
        } catch {
            refresh()
            let why = error.localizedDescription
            react(StatusLine.refused(why, op: op))
            return .refused(why)
        }
    }
}

/// The autosave of a form that is not a scene's (a content item, a transition): a pause after the last change commits through the form's own typed operation, one undo step for a run of
/// changes to the same thing (`undoKey`), the pending change is committed when the form goes away, and a "Saved" mark shows next to it. `ready` is false while a draft is invalid.
struct AutoCommit<V: Equatable>: ViewModifier {
    let value: V
    let dirty: Bool
    var ready = true
    let undoKey: String
    let commit: () -> Void
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var theme: Theme
    @State private var work: DispatchWorkItem?
    @State private var saved = false

    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _ in
                work?.cancel()
                guard dirty, ready else { return }
                let w = DispatchWorkItem { fire() }
                work = w
                DispatchQueue.main.asyncAfter(deadline: .now() + EditSession.textPause, execute: w)
            }
            .onDisappear { fire() }
            .overlay(alignment: .topTrailing) {
                if saved { Label("Saved", systemImage: "checkmark").fontSmall().foregroundStyle(theme.success).transition(.opacity) }
            }
            .animation(Motion.settle, value: saved)
    }

    private func fire() {
        work?.cancel(); work = nil
        guard dirty, ready else { return }
        commit()
        project.store.coalesceLast(key: undoKey)
        (NSApp.keyWindow?.firstResponder as? NSTextView)?.undoManager?.removeAllActions()
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
    }
}

extension View {
    func autoCommit<V: Equatable>(_ value: V, dirty: Bool, ready: Bool = true, undoKey: String, commit: @escaping () -> Void) -> some View {
        modifier(AutoCommit(value: value, dirty: dirty, ready: ready, undoKey: undoKey, commit: commit))
    }
}
