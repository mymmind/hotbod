import Foundation

enum PersistenceHelper {
    private static let lock = NSLock()

    static var appSupportURL: URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application support directory unavailable")
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let url = appSupportURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to filename: String) {
        lock.lock()
        defer { lock.unlock() }
        let url = appSupportURL.appendingPathComponent(filename)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func remove(_ filename: String) {
        lock.lock()
        defer { lock.unlock() }
        let url = appSupportURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
