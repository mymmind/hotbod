import Foundation

enum PersistenceHelper {
    private static let lock = NSLock()
    private static nonisolated(unsafe) var testingOverrideURL: URL?

    private static func resolvedAppSupportURL() -> URL {
        if let testingOverrideURL {
            try? FileManager.default.createDirectory(at: testingOverrideURL, withIntermediateDirectories: true)
            return testingOverrideURL
        }
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var appSupportURL: URL {
        lock.lock()
        defer { lock.unlock() }
        return resolvedAppSupportURL()
    }

    static func configureForTesting(baseURL: URL) {
        lock.lock()
        defer { lock.unlock() }
        testingOverrideURL = baseURL
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    static func resetTestingConfiguration() {
        lock.lock()
        defer { lock.unlock() }
        testingOverrideURL = nil
    }

    static func clearAllPersistedData() {
        lock.lock()
        defer { lock.unlock() }
        let url = resolvedAppSupportURL()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        ) else { return }
        for item in contents {
            try? FileManager.default.removeItem(at: item)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let url = resolvedAppSupportURL().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to filename: String) {
        lock.lock()
        defer { lock.unlock() }
        let url = resolvedAppSupportURL().appendingPathComponent(filename)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func remove(_ filename: String) {
        lock.lock()
        defer { lock.unlock() }
        let url = resolvedAppSupportURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
