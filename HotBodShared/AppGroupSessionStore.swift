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
    let action: WatchSessionCommand
    let issuedAt: Date
}

enum AppGroupSessionStore {
    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WatchAppGroup.identifier)
    }

    static func writeSnapshot(_ snapshot: WatchSessionSnapshot) {
        guard let url = containerURL()?.appendingPathComponent(WatchAppGroup.sessionSnapshotFile) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func readSnapshot() -> WatchSessionSnapshot {
        guard let url = containerURL()?.appendingPathComponent(WatchAppGroup.sessionSnapshotFile),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WatchSessionSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func writePendingCommand(_ command: WatchPendingCommand) {
        guard let url = containerURL()?.appendingPathComponent(WatchAppGroup.pendingCommandFile) else { return }
        guard let data = try? JSONEncoder().encode(command) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func consumePendingCommand() -> WatchPendingCommand? {
        guard let url = containerURL()?.appendingPathComponent(WatchAppGroup.pendingCommandFile),
              let data = try? Data(contentsOf: url),
              let command = try? JSONDecoder().decode(WatchPendingCommand.self, from: data) else {
            return nil
        }
        try? FileManager.default.removeItem(at: url)
        return command
    }

    static func clearSnapshot() {
        guard let url = containerURL()?.appendingPathComponent(WatchAppGroup.sessionSnapshotFile) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func clearAll() {
        clearSnapshot()
        guard let url = containerURL()?.appendingPathComponent(WatchAppGroup.pendingCommandFile) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
