import Foundation

/// What the agent loop and the tools need from the interface.
protocol AgentUI: AnyObject {
    func text(_ t: String)
    func endText()
    func tool(_ name: String, _ input: [String: Any])
    func show(_ url: String, _ title: String)
    func screenshot(javascript: String?, waitMs: Int) async -> Data?
    func ask(_ questions: [[String: Any]]) async -> [String]
}
