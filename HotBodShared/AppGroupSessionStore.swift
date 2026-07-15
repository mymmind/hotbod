import Foundation

enum WatchAppGroup {
    static let identifier = "group.com.hotbod.app"
    static let sessionSnapshotFile = "watch_session_snapshot.json"
    static let pendingCommandFile = "watch_pending_command.json"
}

struct WatchSessionSnapshot: Codable, Equatable {
    var sessionId: UUID?
    var title: String
    var exerciseName: String
    var exerciseIndex: Int
    var setIndex: Int
    var totalSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetWeightKg: Double?
    var isMaxEffort: Bool
    var restSecondsRemaining: Int?
    var isResting: Bool
    var updatedAt: Date

    static let empty = WatchSessionSnapshot(
        sessionId: nil,
        title: "HotBod",
        exerciseName: "No active session",
        exerciseIndex: 0,
        setIndex: 0,
        totalSets: 0,
        targetRepsMin: 0,
        targetRepsMax: 0,
        targetWeightKg: nil,
        isMaxEffort: false,
        restSecondsRemaining: nil,
        isResting: false,
        updatedAt: Date()
    )
}

enum WatchSessionCommand: String, Codable {
    case completeSet
    case skipRest
}

struct WatchPendingCommand: Codable, Equatable {
    let sequence: UInt64
    let action: WatchSessionCommand
    let issuedAt: Date
}

enum AppGroupSessionStore {
    private static let lock = NSLock()
    private static nonisolated(unsafe) var commandSequence: UInt64 = 0
    private static nonisolated(unsafe) var testingContainerURL: URL?

    static func configureForTesting(containerURL: URL) {
        lock.lock()
        defer { lock.unlock() }
        testingContainerURL = containerURL
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
    }

    static func resetTestingConfiguration() {
        lock.lock()
        defer { lock.unlock() }
        testingContainerURL = nil
        commandSequence = 0
    }

    private static func resolvedContainerURL() -> URL? {
        if let testingContainerURL {
            return testingContainerURL
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WatchAppGroup.identifier)
    }

    static func containerURL() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return resolvedContainerURL()
    }

    static func writeSnapshot(_ snapshot: WatchSessionSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        guard let url = resolvedContainerURL()?.appendingPathComponent(WatchAppGroup.sessionSnapshotFile) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func readSnapshot() -> WatchSessionSnapshot {
        lock.lock()
        defer { lock.unlock() }
        guard let url = resolvedContainerURL()?.appendingPathComponent(WatchAppGroup.sessionSnapshotFile),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WatchSessionSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    private static func writePendingCommand(_ command: WatchPendingCommand) {
        lock.lock()
        defer { lock.unlock() }
        guard let url = resolvedContainerURL()?.appendingPathComponent(WatchAppGroup.pendingCommandFile) else { return }
        guard let data = try? JSONEncoder().encode(command) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func issuePendingCommand(_ action: WatchSessionCommand) {
        lock.lock()
        commandSequence &+= 1
        let sequence = commandSequence
        lock.unlock()
        writePendingCommand(
            WatchPendingCommand(sequence: sequence, action: action, issuedAt: Date())
        )
    }

    static func consumePendingCommand() -> WatchPendingCommand? {
        lock.lock()
        defer { lock.unlock() }
        guard let url = resolvedContainerURL()?.appendingPathComponent(WatchAppGroup.pendingCommandFile),
              let data = try? Data(contentsOf: url),
              let command = try? JSONDecoder().decode(WatchPendingCommand.self, from: data) else {
            return nil
        }
        try? FileManager.default.removeItem(at: url)
        return command
    }

    static func clearSnapshot() {
        lock.lock()
        defer { lock.unlock() }
        guard let url = resolvedContainerURL()?.appendingPathComponent(WatchAppGroup.sessionSnapshotFile) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        guard let base = resolvedContainerURL() else { return }
        try? FileManager.default.removeItem(at: base.appendingPathComponent(WatchAppGroup.sessionSnapshotFile))
        try? FileManager.default.removeItem(at: base.appendingPathComponent(WatchAppGroup.pendingCommandFile))
    }
}
