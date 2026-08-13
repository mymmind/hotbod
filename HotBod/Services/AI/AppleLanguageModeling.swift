import Foundation

enum AppleLanguageModelKind: String, Sendable, Equatable {
    case onDevice
    case privateCloudCompute
}

enum AppleLanguageModelAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: AppleLanguageModelUnavailableReason)
}

enum AppleLanguageModelUnavailableReason: String, Sendable, Equatable {
    case deviceNotEligible
    case systemNotReady
    case appleIntelligenceNotEnabled
    case modelNotReady
    case quotaLimitReached
    case networkRequired
    case notSupportedInThisBuild
    case unknown
}

struct AppleLanguageQuotaSnapshot: Equatable, Sendable {
    var isLimitReached: Bool
    var resetDate: Date?
}

/// Phase 1 surface: availability + lightweight prompt for future phases.
/// Does not yet replace coach / physique services.
/// Isolated to MainActor so `@MainActor` clients (mock / system) can conform under Swift 6.
@MainActor
protocol AppleLanguageModeling: AnyObject, Sendable {
    func availability(for kind: AppleLanguageModelKind) -> AppleLanguageModelAvailability
    func quota(for kind: AppleLanguageModelKind) -> AppleLanguageQuotaSnapshot?
    func complete(prompt: String, kind: AppleLanguageModelKind) async throws -> String
}

enum AppleLanguageModelingError: Error, Equatable {
    case unavailable(AppleLanguageModelUnavailableReason)
    case emptyResponse
}
