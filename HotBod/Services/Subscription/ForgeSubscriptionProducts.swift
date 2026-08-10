import Foundation

enum ForgeSubscriptionProducts {
    static let monthly = "com.hotbod.app.pro.monthly"
    static let annual = "com.hotbod.app.pro.annual"

    static let all: [String] = [monthly, annual]
}

/// Toggle before release to re-enable StoreKit gates and free-tier limits.
enum SubscriptionConfig {
#if DEBUG
    private static let defaultUnrestrictedAccess = true
#else
    private static let defaultUnrestrictedAccess = false
#endif

    /// Unit-test seam to exercise free-tier gates under DEBUG. Always clear in `defer`/tearDown.
    nonisolated(unsafe) static var unrestrictedAccessOverride: Bool?

    static var unrestrictedAccess: Bool {
        unrestrictedAccessOverride ?? defaultUnrestrictedAccess
    }
}

enum FreeTierLimits {
    static let weeklyRegenerations = 3
}

enum ProFeature: String, Identifiable, CaseIterable {
    case unlimitedGeneration
    case coachWorkoutApply
    case bodyPhotoHistory
    case workoutExport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedGeneration: "Unlimited Workout Generation"
        case .coachWorkoutApply: "Coach Workout Changes"
        case .bodyPhotoHistory: "Full Body Progress History"
        case .workoutExport: "Workout Share & Export"
        }
    }

    var subtitle: String {
        switch self {
        case .unlimitedGeneration: "Regenerate and adapt every session without weekly limits."
        case .coachWorkoutApply: "Apply AI coach proposals to today's plan instantly."
        case .bodyPhotoHistory: "Compare trends across your full photo timeline."
        case .workoutExport: "Share completion cards and session summaries."
        }
    }
}
