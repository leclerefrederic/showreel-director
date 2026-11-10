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

    /// The next scene that has a job, or nil when the queue is empty, a build runs or the model is cancelled. Scenes that no longer exist are skipped.
    private func nextThumbJob() -> (SceneThumbs.Job, ProjectStore)? {
        while !Task.isCancelled, activity.build == nil, let id = thumbQueue.next() {
            if let f = showreel, let v = playableVersion, let job = SceneThumbs.job(for: id, in: f, version: v, store: store) { return (job, store) }
            thumbQueue.finish()
        }
        return nil
    }

    private func finishThumb(_ job: SceneThumbs.Job, _ result: Result<Data, SceneCapture.CaptureError>) {
        switch result {
        case .success(let png): do { try SceneThumbs.record(job, png: png, store: store) } catch { SceneThumbs.recordFailure(job, reason: error.localizedDescription, store: store) }
        case .failure(let e): if !e.transient { SceneThumbs.recordFailure(job, reason: e.message, store: store) }
        }
        thumbQueue.finish()
        if let f = showreel { sceneThumbs = SceneThumbs.states(in: f, version: playableVersion, store: store) }
    }

    /// The loop holds the model weakly across the capture: a project closed meanwhile is released, its task is cancelled (`stopThumbs`) and the late result is dropped, not written into its folder (RF2).
    private func runThumbs(force: Bool) {
        guard thumbTask == nil else { return }
        thumbTask = Task { @MainActor [weak self] in
            while let (job, store) = self?.nextThumbJob() {
                let result = await SceneCapture.shared.capture(job, store: store)
                guard let self = self, !Task.isCancelled else { return }
                self.finishThumb(job, result)
            }
            self?.thumbQueue.finish()
            self?.thumbTask = nil
        }
    }

    /// The project is closing: nothing waits, nothing starts, and a capture still running will drop its result.
    func stopThumbs() { thumbDelay?.cancel(); thumbTask?.cancel(); thumbQueue.cancel() }
}
