import Foundation

enum WorkoutStartCountdown {
    static let tickDuration: Duration = .seconds(1)
    static let messageHoldDuration: Duration = .milliseconds(1200)
    static let reducedMotionHoldDuration: Duration = .milliseconds(900)

    static func openingLine(for session: WorkoutSession) -> String {
        guard let first = session.exercises.first else { return "Start when ready." }
        let working = first.plannedSets.filter { !$0.isWarmup && !$0.isCooldown }
        let sets = working.isEmpty ? first.plannedSets.count : working.count
        let name = first.exerciseId.replacingOccurrences(of: "_", with: " ").capitalized
        if let weight = (working.first ?? first.plannedSets.first)?.targetWeightKg, weight > 0 {
            return "\(name)\n\(sets) sets · \(Int(weight)) kg"
        }
        return "\(name)\n\(sets) sets"
    }
}

enum WorkoutStartFlow {
    @MainActor
    static func begin(
        from workout: GeneratedWorkout,
        isResume: Bool,
        environment: AppEnvironment,
        router: AppRouter
    ) async -> WorkoutSession? {
        let showCountdown = !isResume && !UITestConfiguration.isUITesting
        guard let session = await environment.resumeOrStartWorkout(
            from: workout,
            deferStartTimestamp: showCountdown
        ) else { return nil }

        await routeAfterStart(session, environment: environment, router: router)
        return session
    }

    @MainActor
    static func routeAfterStart(
        _ session: WorkoutSession,
        environment: AppEnvironment,
        router: AppRouter
    ) async {
        if session.startedAt == nil, !UITestConfiguration.isUITesting {
            router.showWorkoutStartCountdown(for: session)
            return
        }

        let ready = await environment.commitWorkoutSessionStartIfNeeded(session)
        router.replace(with: .workoutSession(ready))
    }

    @MainActor
    static func finishCountdown(
        environment: AppEnvironment,
        router: AppRouter
    ) async {
        guard let pending = router.workoutStartCountdownSession else { return }
        let ready = await environment.commitWorkoutSessionStartIfNeeded(pending)
        router.finishWorkoutStartCountdown(navigatingTo: ready)
    }
}
