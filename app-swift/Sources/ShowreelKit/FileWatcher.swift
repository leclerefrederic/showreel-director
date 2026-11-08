import CoreServices
import Foundation

/// Reports changes under a folder (FSEvents), so open editors can refresh. `.studio` and `.DS_Store` are ignored.
public final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let root: String
    private let onChange: ([String]) -> Void

    /// `onChange` receives paths relative to the folder, on the main queue.
    public init?(root: URL, onChange: @escaping ([String]) -> Void) {
        self.root = root.resolvingSymlinksInPath().standardizedFileURL.path
        self.onChange = onChange
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let cb: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info = info else { return }
            let me = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let list = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            me.handle(Array(list.prefix(count)))
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let s = FSEventStreamCreate(nil, cb, &ctx, [self.root] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.15, flags) else { return nil }
        stream = s
        FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
        FSEventStreamStart(s)
    }

    private func handle(_ paths: [String]) {
        var rel: [String] = []
        for p in paths where p.hasPrefix(root) {
            let r = String(p.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if r.isEmpty || r == ".DS_Store" || r.hasSuffix("/.DS_Store") { continue }
            if r == ProjectStore.studioDir || r.hasPrefix(ProjectStore.studioDir + "/") { continue }
            rel.append(r)
        }
        if !rel.isEmpty { onChange(rel) }
    }

    public func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }
}
