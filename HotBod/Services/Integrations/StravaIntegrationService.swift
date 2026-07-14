import Foundation

/// Strava OAuth + activity upload — stub until OAuth credentials and backend token storage exist.
protocol StravaIntegrationService: Sendable {
    var isConfigured: Bool { get }
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect() async
    func publishCompletedWorkout(_ session: WorkoutSession) async throws
}

struct NoOpStravaIntegrationService: StravaIntegrationService, Sendable {
    var isConfigured: Bool { false }
    var isConnected: Bool { false }

    func connect() async throws {
        throw StravaIntegrationError.notConfigured
    }

    func disconnect() async {}

    func publishCompletedWorkout(_ session: WorkoutSession) async throws {
        throw StravaIntegrationError.notConfigured
    }
}

enum StravaIntegrationError: LocalizedError, Equatable {
    case notConfigured
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Strava integration is not configured in this build."
        case .notConnected:
            return "Connect Strava in Settings before sharing workouts."
        }
    }
}

enum StravaIntegrationServiceFactory {
    static func makeDefault() -> any StravaIntegrationService {
        NoOpStravaIntegrationService()
    }
}
