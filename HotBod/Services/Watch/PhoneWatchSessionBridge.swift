import Foundation
import WatchConnectivity

@MainActor
enum PhoneWatchConnectivity {
    static func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = PhoneWatchSessionDelegate.shared
        session.activate()
    }
}

final class PhoneWatchSessionDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneWatchSessionDelegate()

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        postDrain()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        postDrain()
    }

    private func postDrain() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .hotbodWatchCommandsPending, object: nil)
        }
    }
}

@MainActor
enum PhoneWatchSessionBridge {

    static func publishReady(title: String) {
        var snapshot = WatchSessionSnapshot.empty
        snapshot.title = title
        snapshot.exerciseName = "Ready to start"
        snapshot.phase = .ready
        snapshot.updatedAt = Date()
        AppGroupSessionStore.writeSnapshot(snapshot)
    }

    static func publishIdle() {
        AppGroupSessionStore.clearSnapshot()
    }

    static func publish(
        session: WorkoutSession?,
        exerciseIndex: Int,
        setIndex: Int? = nil,
        exerciseName: String,
        restSecondsRemaining: Int?,
        isResting: Bool,
        restEndsAt: Date? = nil,
        loggedWeightKg: Double? = nil,
        secondaryValue: Int? = nil,
        secondaryLabel: String? = nil,
        loadUnit: String? = nil,
        loadStep: Double? = nil,
        nextSummary: String? = nil
    ) {
        guard let session, session.status == .inProgress else {
            AppGroupSessionStore.clearSnapshot()
            return
        }

        guard exerciseIndex < session.exercises.count else { return }
        let exercise = session.exercises[exerciseIndex]
        let displayIndex = setIndex.flatMap { exercise.plannedSets.indices.contains($0) ? $0 : nil }
            ?? min(exercise.completedSets.count, max(exercise.plannedSets.count - 1, 0))
        let planned = exercise.plannedSets[safe: displayIndex]

        let snapshot = WatchSessionSnapshot(
            sessionId: session.id,
            title: session.title,
            exerciseName: exerciseName,
            exerciseIndex: exerciseIndex,
            setIndex: displayIndex,
            totalSets: exercise.plannedSets.count,
            targetRepsMin: planned?.targetRepsMin ?? 0,
            targetRepsMax: planned?.targetRepsMax ?? 0,
            targetWeightKg: planned?.targetWeightKg,
            isMaxEffort: planned?.isMaxEffort ?? false,
            restSecondsRemaining: restSecondsRemaining,
            isResting: isResting,
            updatedAt: Date(),
            loggedWeightKg: loggedWeightKg ?? planned?.targetWeightKg,
            secondaryValue: secondaryValue,
            secondaryLabel: secondaryLabel,
            nextSummary: nextSummary,
            loadUnit: loadUnit,
            loadStep: loadStep,
            restEndsAt: isResting ? restEndsAt : nil,
            phase: .active
        )
        AppGroupSessionStore.writeSnapshot(snapshot)
    }

    static func consumeWatchCommand() -> WatchPendingCommand? {
        AppGroupSessionStore.consumeNextCommand()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
