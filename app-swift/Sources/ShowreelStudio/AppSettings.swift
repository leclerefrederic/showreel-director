import Foundation
import ShowreelKit

/// Connection settings shared by every window: model, gateway, API key (Keychain only).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published private(set) var hasKey = false
    /// Bumps when the settings change, so each window rebuilds its agent at the next message.
    @Published private(set) var generation = 0
    private let defaults = UserDefaults.standard
    private var cachedKey: String? // the Keychain is read once per launch, at the first message

    var modelName: String { defaults.string(forKey: "model") ?? "claude-sonnet-5-5" }
    var baseURL: String { defaults.string(forKey: "baseURL") ?? ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"] ?? "" }
    var bearer: Bool { defaults.bool(forKey: "bearer") }

    init() { hasKey = keyExists() }

    private func envKey() -> String? {
        let env = ProcessInfo.processInfo.environment
        for name in ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"] {
            if let v = env[name], !v.isEmpty { return v }
        }
        return nil
    }

    /// Whether a key is available, without reading the Keychain secret (no prompt).
    private func keyExists() -> Bool { cachedKey != nil || Keychain.exists() || envKey() != nil }

    /// The key itself: the first call may show the Keychain prompt, later calls use the cached value.
    func apiKey() -> String? {
        if let k = cachedKey { return k }
        if let k = Keychain.get(), !k.isEmpty { cachedKey = k; return k }
        return envKey()
    }

    func save(key: String, url: String, bearer: Bool, modelName: String) {
        if !key.isEmpty { Keychain.set(key); cachedKey = key }
        var u = url.trimmingCharacters(in: .whitespaces)
        while u.hasSuffix("/") { u.removeLast() }
        defaults.set(u, forKey: "baseURL")
        defaults.set(bearer, forKey: "bearer")
        let m = modelName.trimmingCharacters(in: .whitespaces)
        defaults.set(m.isEmpty ? "claude-sonnet-5-5" : m, forKey: "model")
        hasKey = keyExists()
        generation += 1
    }
}

/// The project library as the windows see it.
final class LibraryModel: ObservableObject {
    static let shared = LibraryModel()

    private let library = ProjectLibrary()
    @Published private(set) var visible: [LibraryEntry] = []
    @Published private(set) var archived: [LibraryEntry] = []

    init() { reload() }

    func reload() {
        library.load()
        library.refreshMetadata()
        visible = library.visible
        archived = library.archived
    }

    @discardableResult func add(path: String, name: String? = nil) -> LibraryEntry {
        defer { publish() }
        return library.add(path: path, name: name)
    }
    func touch(path: String, name: String? = nil, step: String? = nil) { library.touch(path: path, name: name, step: step); publish() }
    func setPinned(_ id: String, _ on: Bool) { library.setPinned(id, on); publish() }
    func setArchived(_ id: String, _ on: Bool) { library.setArchived(id, on); publish() }
    func remove(_ id: String) { library.remove(id); publish() }

    private func publish() { visible = library.visible; archived = library.archived }
}
