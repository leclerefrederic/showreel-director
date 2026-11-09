import Foundation

/// Where the Build writes what happened, so that a hang can be read afterwards: one line in the project's journal and one in the app's own log
/// (`~/Library/Logs/ShowreelStudio/build.log`, bounded like the drag log). The tests do not write the real log.
public enum BuildLog {
    nonisolated(unsafe) public static var log: DragLog? = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        ? DragLog(url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/ShowreelStudio/build.log"), maxBytes: 400_000) : nil
}

extension ProjectStore {
    /// A line of the Build in the journal (op "build") and in the app's log.
    public func logBuild(_ version: String, _ title: String, note: String? = nil) {
        noteEvent(author: "app", op: "build", target: version, title: title, note: note)
        BuildLog.log?.note("\(root.lastPathComponent) \(version)", title + (note.map { " | " + $0 } ?? ""))
    }
}
