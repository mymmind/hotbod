import Foundation

@MainActor
enum PhoneWatchSessionBridge {
    static func publish(
        session: WorkoutSession?,
        exerciseIndex: Int,
        exerciseName: String,
        restSecondsRemaining: Int?,
        isResting: Bool
    ) {
        guard let session, session.status == .inProgress else {
            AppGroupSessionStore.clearSnapshot()
            return
        }

        guard exerciseIndex < session.exercises.count else { return }
        let exercise = session.exercises[exerciseIndex]
        let activeSetIndex = exercise.completedSets.count
        let planned = exercise.plannedSets[safe: activeSetIndex]

        let snapshot = WatchSessionSnapshot(
            sessionId: session.id,
            title: session.title,
            exerciseName: exerciseName,
            exerciseIndex: exerciseIndex,
            setIndex: activeSetIndex,
            totalSets: exercise.plannedSets.count,
            targetRepsMin: planned?.targetRepsMin ?? 0,
            targetRepsMax: planned?.targetRepsMax ?? 0,
            targetWeightKg: planned?.targetWeightKg,
            isMaxEffort: planned?.isMaxEffort ?? false,
            restSecondsRemaining: restSecondsRemaining,
            isResting: isResting,
            updatedAt: Date()
        )
        AppGroupSessionStore.writeSnapshot(snapshot)
    }

    static func consumeWatchCommand() -> WatchPendingCommand? {
        AppGroupSessionStore.consumePendingCommand()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
