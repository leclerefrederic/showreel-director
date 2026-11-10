import Foundation
import os

/// A measurement helper for the interface's critical paths (PF1): in a debug build it wraps a call in an `os_signpost` interval ("Points of Interest" in Instruments, subsystem
/// `ShowreelStudio`); in a release build it only calls the body.
public enum DebugProbe {
    #if DEBUG
    private static let log = OSLog(subsystem: "ShowreelStudio", category: .pointsOfInterest)
    #endif

    @discardableResult
    public static func interval<T>(_ name: StaticString, _ body: () -> T) -> T {
        #if DEBUG
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        defer { os_signpost(.end, log: log, name: name, signpostID: id) }
        #endif
        return body()
    }
}
