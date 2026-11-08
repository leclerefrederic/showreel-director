import Foundation

public struct FileNode: Identifiable, Hashable {
    public let id: String          // path relative to the project
    public let name: String
    public let isDir: Bool
    public var children: [FileNode]?   // nil for files, as List(children:) expects
}

public enum FileKind: Equatable { case markdown, json, csv, text, binary }

public enum ProjectTree {
    static let skipped: Set<String> = ["node_modules", "__pycache__"]

    /// The project folder as a tree: folders first, then names; hidden files, `.studio` and caches left out.
    public static func scan(_ root: URL, maxDepth: Int = 8, maxEntries: Int = 4000) -> [FileNode] {
        var count = 0
        func walk(_ dir: URL, _ rel: String, _ depth: Int) -> [FileNode] {
            guard depth <= maxDepth, count < maxEntries,
                  let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
            var nodes: [FileNode] = []
            for u in items {
                let n = u.lastPathComponent
                if n.hasPrefix(".") || skipped.contains(n) { continue }
                count += 1
                let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let r = rel.isEmpty ? n : rel + "/" + n
                nodes.append(FileNode(id: r, name: n, isDir: isDir, children: isDir ? walk(u, r, depth + 1) : nil))
            }
            return nodes.sorted { ($0.isDir ? 0 : 1, $0.name.lowercased()) < ($1.isDir ? 0 : 1, $1.name.lowercased()) }
        }
        return walk(root, "", 0)
    }

    static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "mp4", "mov", "m4v", "webm", "mp3", "wav", "aac", "m4a", "flac", "ogg",
        "pdf", "zip", "ttf", "otf", "woff", "woff2", "icns", "psd", "ai", "skill",
    ]

    /// How a file opens: its own editor, a plain text editor, or the system viewer (binary).
    public static func kind(of path: String) -> FileKind {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown": return .markdown
        case "json": return .json
        case "csv": return .csv
        default: return binaryExtensions.contains(ext) ? .binary : .text
        }
    }
}
