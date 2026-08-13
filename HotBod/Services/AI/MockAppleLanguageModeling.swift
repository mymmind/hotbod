import Foundation

@MainActor
final class MockAppleLanguageModeling: AppleLanguageModeling {
    var onDeviceAvailability: AppleLanguageModelAvailability = .available
    var pccAvailability: AppleLanguageModelAvailability = .available
    var pccQuota: AppleLanguageQuotaSnapshot? = AppleLanguageQuotaSnapshot(isLimitReached: false, resetDate: nil)
    var cannedResponse: String = "mock-apple-response"
    private(set) var lastPrompt: String?
    private(set) var lastKind: AppleLanguageModelKind?

    func availability(for kind: AppleLanguageModelKind) -> AppleLanguageModelAvailability {
        switch kind {
        case .onDevice:
            onDeviceAvailability
        case .privateCloudCompute:
            pccAvailability
        }
    }

    func quota(for kind: AppleLanguageModelKind) -> AppleLanguageQuotaSnapshot? {
        switch kind {
        case .onDevice:
            nil
        case .privateCloudCompute:
            pccQuota
        }
    }

    func complete(prompt: String, kind: AppleLanguageModelKind) async throws -> String {
        lastPrompt = prompt
        lastKind = kind
        switch availability(for: kind) {
        case .available:
            return cannedResponse
        case .unavailable(let reason):
            throw AppleLanguageModelingError.unavailable(reason)
        }
    }
}
