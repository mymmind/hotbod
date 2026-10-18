import Foundation

enum WorkoutStartCountdown {
    static let tickDuration: Duration = .seconds(1)
    static let messageHoldDuration: Duration = .milliseconds(1200)
    static let reducedMotionHoldDuration: Duration = .milliseconds(900)

    /// Nasty rally lines after 3-2-1. Short on purpose — the type is huge.
    static let rallyMessages: [String] = [
        "Pick it up, coward.",
        "Suffer correctly.",
        "Bleed for the plates.",
        "No whimpering.",
        "Hurt pretty.",
        "Grind the ugly reps.",
        "Shut up and lift.",
        "Make it violent.",
        "Chalk. Spite. Go.",
        "Heavy or homeless.",
        "Break something useful.",
        "Pain is the plan.",
        "Don't you dare bail.",
        "Ugly. Loud. Done.",
        "Spit and lock out.",
        "Ruin your excuses.",
        "This weight hates you.",
        "Get mean.",
        "Fail loud or don't.",
        "Sweat like a criminal.",
        "No soft sets.",
        "Crush it, idiot.",
        "Earn the bruise.",
        "Stop negotiating.",
        "Violence, then rest.",
        "Make the floor shake.",
        "Quit crying. Pull.",
        "Nasty work starts now.",
        "Fuck the easy reps.",
        "Leave a dent.",
        "Grip it like a grudge.",
        "All hate. No hop.",
        "Scream, then stand up.",
        "The bar doesn't care.",
        "Get stupid heavy.",
        "Wreck the set.",
        "Zero mercy.",
        "Do it angry.",
        "Blood in the chalk.",
        "Now. Harder. Again."
    ]

    static func randomMessage() -> String {
        rallyMessages.randomElement() ?? "Get mean."
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
