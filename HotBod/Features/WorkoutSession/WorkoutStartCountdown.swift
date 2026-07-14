import Foundation

enum WorkoutStartCountdown {
    static let tickDuration: Duration = .seconds(1)
    static let messageHoldDuration: Duration = .milliseconds(1200)
    static let reducedMotionHoldDuration: Duration = .milliseconds(900)

    /// Short rally lines after 3-2-1. Start energy only — no mid-session or finish copy.
    static let rallyMessages: [String] = [
        "Let's go!",
        "Let's get it!",
        "Lock in!",
        "Work starts now.",
        "Set the tone.",
        "Start strong.",
        "Here we go.",
        "Time to work.",
        "Get moving.",
        "Focus up.",
        "Train with intent.",
        "Every rep counts.",
        "Make it count.",
        "Own this session.",
        "Bring your best.",
        "Show up strong.",
        "Go hard!",
        "You got this!",
        "Hit it hard.",
        "All gas.",
        "Go all in.",
        "Push the pace.",
        "Bring the intensity.",
        "Attack every rep.",
        "Raise the standard.",
        "Outwork yesterday.",
        "Go earn it.",
        "Put in the work.",
        "Strength is earned.",
        "Discipline over mood.",
        "Nothing comes easy.",
        "Control the weight.",
        "Clean reps only.",
        "Move with purpose.",
        "Build from rep one.",
        "Momentum starts now.",
        "Stay locked in.",
        "Get after it."
    ]

    static func randomMessage() -> String {
        rallyMessages.randomElement() ?? rallyMessages[0]
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
