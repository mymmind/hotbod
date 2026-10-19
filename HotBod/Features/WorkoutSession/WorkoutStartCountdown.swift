import Foundation

enum WorkoutStartCountdown {
    static let tickDuration: Duration = .seconds(1)
    static let messageHoldDuration: Duration = .milliseconds(1200)
    static let reducedMotionHoldDuration: Duration = .milliseconds(900)

    /// First-exercise line shown after 3-2-1. Names the work; no slogans.
    static func openingLine(for session: WorkoutSession, exerciseName: String? = nil) -> String {
        let exercises = session.exercises.sorted { $0.orderIndex < $1.orderIndex }
        guard let exercise = exercises.first else { return "Start when ready." }
        let name = exerciseName ?? humanizedExerciseName(exercise.exerciseId)
        let working = exercise.plannedSets.filter { !$0.isWarmup && !$0.isCooldown }
        let sets = working.isEmpty ? exercise.plannedSets : working
        guard !sets.isEmpty else { return name }
        let setLabel = sets.count == 1 ? "1 set" : "\(sets.count) sets"
        guard let weight = sets.first?.targetWeightKg, weight != 0 else {
            return "\(name)\n\(setLabel)"
        }
        let number = weight.rounded() == weight ? String(Int(weight)) : String(format: "%.1f", weight)
        let unit = openingLoadUnit(weight: weight, exerciseId: exercise.exerciseId)
        return "\(name)\n\(setLabel) · \(number) \(unit)"
    }

    private static func openingLoadUnit(weight: Double, exerciseId: String) -> String {
        if weight < 0 { return "kg assist" }
        let semantics = ExerciseMetadataResolver.resolvedWeightDisplaySemantics(exerciseId: exerciseId)
        if semantics == .resistanceLevel { return "lvl" }
        return semantics.compactLoadUnit.trimmingCharacters(in: .whitespaces)
    }

    private static func humanizedExerciseName(_ exerciseId: String) -> String {
        exerciseId
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
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
