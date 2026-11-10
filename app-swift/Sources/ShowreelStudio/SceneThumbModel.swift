import ShowreelKit
import SwiftUI

/// Scene thumbnails as the project runs them (W4b): the states come from ShowreelKit's `SceneThumbs`, captures are queued one at a time and start after a quiet delay, never during a build.
extension ProjectModel {
    /// Recomputes every scene's state from the files, drops the pictures of scenes that no longer exist, and asks for the captures that can bring a picture up to date.
    func refreshThumbStates() {
        guard let f = showreel else { sceneThumbs = [:]; return }
        let v = playableVersion
        SceneThumbs.cleanOrphans(in: f, store: store)
        let s = SceneThumbs.states(in: f, version: v, store: store)
        if s != sceneThumbs { sceneThumbs = s }
        let todo = SceneThumbs.capturable(in: f, version: v, store: store)
        if !todo.isEmpty, activity.build == nil, !assembling { scheduleThumbs(todo, by: "the app") }
    }

    /// The scene's thumbnail again, by hand ("Refresh thumbnail"): refused with its reason when nothing could change.
    func refreshThumbnail(_ id: String) {
        if let u = SceneThumbs.refreshAvailability(sceneThumbs[id], activity: activity).why { react(StatusLine.refused(u.message)); return }
        SceneThumbs.note(store, scenes: [id], by: "button")
        scheduleThumbs([id], by: "button", force: true)
    }

    func refreshStaleThumbnails() {
        guard let f = showreel else { return }
        let ids = f.film.map { $0.id }.filter { if case .fresh = sceneThumbs[$0] { return false } else { return true } }
        guard !ids.isEmpty else { showToast("Every thumbnail is up to date."); return }
        SceneThumbs.note(store, scenes: ids, by: "button")
        scheduleThumbs(ids, by: "button", force: true)
    }

    /// Waits for the quiet delay (a new request restarts it, so edits are coalesced), then captures the queue one scene at a time.
    private func scheduleThumbs(_ ids: [String], by: String, force: Bool = false) {
        thumbQueue.enqueue(ids)
        thumbDelay?.cancel()
        thumbDelay = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(force ? 0 : SceneThumbs.quietDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.runThumbs(force: force)
        }
    }

    private func runThumbs(force: Bool) {
        guard thumbTask == nil else { return }
        thumbTask = Task { @MainActor [weak self] in
            while let self = self, !Task.isCancelled, self.activity.build == nil, let id = self.thumbQueue.next() {
                if let f = self.showreel, let v = self.playableVersion, let job = SceneThumbs.job(for: id, in: f, version: v, store: self.store) {
                    switch await SceneCapture.shared.capture(job, store: self.store) {
                    case .success(let png): do { try SceneThumbs.record(job, png: png, store: self.store) } catch { SceneThumbs.recordFailure(job, reason: error.localizedDescription, store: self.store) }
                    case .failure(let e): SceneThumbs.recordFailure(job, reason: e.message, store: self.store)
                    }
                }
                self.thumbQueue.finish()
                if let f = self.showreel { self.sceneThumbs = SceneThumbs.states(in: f, version: self.playableVersion, store: self.store) }
            }
            self?.thumbQueue.finish()
            self?.thumbTask = nil
        }
    }
}
