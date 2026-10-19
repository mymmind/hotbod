import Darwin
import Foundation

enum WatchAppGroup {
    static let identifier = "group.com.hotbod.app"
    static let sessionSnapshotFile = "watch_session_snapshot.json"
    static let pendingCommandFile = "watch_pending_command.json"
}

enum WatchSessionPhase: String, Codable, Equatable {
    case idle
    case ready
    case active
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
    var loggedWeightKg: Double? = nil
    var secondaryValue: Int? = nil
    var secondaryLabel: String? = nil
    var nextSummary: String? = nil
    var loadUnit: String? = nil
    var loadStep: Double? = nil
    var restEndsAt: Date? = nil
    var phase: WatchSessionPhase? = nil

    var resolvedPhase: WatchSessionPhase {
        if let phase { return phase }
        return sessionId == nil ? .idle : .active
    }

    var resolvedLoadUnit: String { loadUnit ?? "kg" }

    var resolvedLoadStep: Double {
        loadStep ?? (resolvedLoadUnit == "lvl" ? 1 : 2.5)
    }

    var displayWeightKg: Double? { loggedWeightKg ?? targetWeightKg }

    var displaySecondaryValue: Int { secondaryValue ?? targetRepsMin }

    var displaySecondaryLabel: String { secondaryLabel ?? "reps" }

    func restRemaining(at date: Date) -> Int? {
        guard isResting else { return nil }
        if let restEndsAt {
            return max(0, Int(ceil(restEndsAt.timeIntervalSince(date))))
        }
        return restSecondsRemaining
    }

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
    case startWorkout
    case endWorkout
    case increaseWeight
    case decreaseWeight
    case increaseReps
    case decreaseReps
}

extension Notification.Name {
    /// Posted when the watch asks the phone to drain the app-group command queue.
    static let hotbodWatchCommandsPending = Notification.Name("hotbod.watchCommandsPending")
}

struct WatchPendingCommand: Codable, Equatable, Identifiable {
    let id: UUID
    let action: WatchSessionCommand
    let issuedAt: Date

    init(id: UUID = UUID(), action: WatchSessionCommand, issuedAt: Date = Date()) {
        self.id = id
        self.action = action
        self.issuedAt = issuedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, action, issuedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        action = try container.decode(WatchSessionCommand.self, forKey: .action)
        issuedAt = try container.decodeIfPresent(Date.self, forKey: .issuedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(action, forKey: .action)
        try container.encode(issuedAt, forKey: .issuedAt)
    }
}

enum WatchRestHaptic {
    /// Fires once when the on-screen rest clock crosses from a positive value to zero.
    static func shouldFire(lastDisplayedRemaining: Int?, displayedRemaining: Int?) -> Bool {
        guard let lastDisplayedRemaining, lastDisplayedRemaining > 0 else { return false }
        return displayedRemaining == 0
    }
}

enum AppGroupSessionStore {
    private static let lock = NSLock()
    private static let maxQueuedCommands = 20
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

    static func issuePendingCommand(_ action: WatchSessionCommand) {
        withCommandQueue {
            guard let url = pendingCommandURLUnlocked() else { return }
            var queue = readQueueUnlocked(at: url)
            queue.append(WatchPendingCommand(action: action))
            if queue.count > maxQueuedCommands {
                queue.removeFirst(queue.count - maxQueuedCommands)
            }
            writeQueueUnlocked(queue, to: url)
        }
    }

    static func consumeNextCommand() -> WatchPendingCommand? {
        withCommandQueue {
            guard let url = pendingCommandURLUnlocked() else { return nil }
            var queue = readQueueUnlocked(at: url)
            guard !queue.isEmpty else { return nil }
            let next = queue.removeFirst()
            writeQueueUnlocked(queue, to: url)
            return next
        }
    }

    /// Removes matching commands and leaves the rest in order. Used so start/end can run while set edits stay queued.
    static func consumeCommands(matching predicate: (WatchSessionCommand) -> Bool) -> [WatchPendingCommand] {
        withCommandQueue {
            guard let url = pendingCommandURLUnlocked() else { return [] }
            let queue = readQueueUnlocked(at: url)
            writeQueueUnlocked(queue.filter { !predicate($0.action) }, to: url)
            return queue.filter { predicate($0.action) }
        }
    }

    /// In-process lock plus `flock` so the phone and watch cannot clobber the same queue file.
    private static func withCommandQueue<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        let descriptor = openCommandLock()
        if descriptor >= 0 {
            _ = flock(descriptor, LOCK_EX)
        }
        defer {
            if descriptor >= 0 {
                _ = flock(descriptor, LOCK_UN)
                close(descriptor)
            }
        }
        return body()
    }

    private static func openCommandLock() -> Int32 {
        guard let url = resolvedContainerURL()?.appendingPathComponent("watch_pending_command.lock") else {
            return -1
        }
        return url.path.withCString { path in
            open(path, O_CREAT | O_RDWR, 0o644)
        }
    }

    private static func pendingCommandURLUnlocked() -> URL? {
        resolvedContainerURL()?.appendingPathComponent(WatchAppGroup.pendingCommandFile)
    }

    private static func readQueueUnlocked(at url: URL) -> [WatchPendingCommand] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        if let queue = try? JSONDecoder().decode([WatchPendingCommand].self, from: data) {
            return queue
        }
        if let single = try? JSONDecoder().decode(WatchPendingCommand.self, from: data) {
            return [single]
        }
        return []
    }

    private static func writeQueueUnlocked(_ queue: [WatchPendingCommand], to url: URL) {
        if queue.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let data = try? JSONEncoder().encode(queue) else { return }
        try? data.write(to: url, options: .atomic)
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
