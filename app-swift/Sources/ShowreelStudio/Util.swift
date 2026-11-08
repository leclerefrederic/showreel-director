import Foundation

func jsonData(_ o: Any) -> Data {
    (try? JSONSerialization.data(withJSONObject: o, options: [.fragmentsAllowed])) ?? Data("null".utf8)
}

func jsonString(_ o: Any) -> String {
    String(data: jsonData(o), encoding: .utf8) ?? "null"
}

func clip(_ s: String, limit: Int = 20000) -> String {
    guard s.count > limit else { return s }
    return String(s.prefix(limit / 2)) + "\n...[cut \(s.count - limit) chars]...\n" + String(s.suffix(limit / 2))
}

enum AgentError: Error, LocalizedError {
    case msg(String)
    var errorDescription: String? {
        switch self { case .msg(let m): return m }
    }
}

extension URL {
    func isInside(_ root: URL) -> Bool {
        let a = self.resolvingSymlinksInPath().standardizedFileURL.path
        let b = root.resolvingSymlinksInPath().standardizedFileURL.path
        return a == b || a.hasPrefix(b.hasSuffix("/") ? b : b + "/")
    }
}

/// Finds a folder or file shipped inside the .app (Resources/<name>) or, when run from the source tree (swift run),
/// by walking up from the current directory looking for `dev` (for example "app/src-ui").
func resource(_ name: String, dev: String) -> URL? {
    let fm = FileManager.default
    if let r = Bundle.main.resourceURL?.appendingPathComponent(name), fm.fileExists(atPath: r.path) { return r }
    // A packaged app never looks outside its bundle: a missing resource is an error, not a reason to read the repository.
    if Bundle.main.bundlePath.hasSuffix(".app") { return nil }
    var d = URL(fileURLWithPath: fm.currentDirectoryPath)
    for _ in 0..<6 {
        let c = d.appendingPathComponent(dev)
        if fm.fileExists(atPath: c.path) { return c }
        d.deleteLastPathComponent()
    }
    return nil
}
