import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Live Apple Foundation Models client for Phase 1 scaffolding.
/// On-device uses `SystemLanguageModel`; PCC maps to unavailable until an iOS 27 SDK
/// exposes `PrivateCloudComputeLanguageModel` for compilation.
@MainActor
final class SystemAppleLanguageModeling: AppleLanguageModeling {
    func availability(for kind: AppleLanguageModelKind) -> AppleLanguageModelAvailability {
        #if canImport(FoundationModels)
        switch kind {
        case .onDevice:
            return Self.mapOnDeviceAvailability(SystemLanguageModel.default.availability)
        case .privateCloudCompute:
            return Self.privateCloudComputeAvailability()
        }
        #else
        return .unavailable(reason: .notSupportedInThisBuild)
        #endif
    }

    func quota(for kind: AppleLanguageModelKind) -> AppleLanguageQuotaSnapshot? {
        switch kind {
        case .onDevice:
            return nil
        case .privateCloudCompute:
            #if canImport(FoundationModels)
            return Self.privateCloudComputeQuota()
            #else
            return nil
            #endif
        }
    }

    func complete(prompt: String, kind: AppleLanguageModelKind) async throws -> String {
        switch availability(for: kind) {
        case .unavailable(let reason):
            throw AppleLanguageModelingError.unavailable(reason)
        case .available:
            break
        }

        #if canImport(FoundationModels)
        switch kind {
        case .onDevice:
            let session = LanguageModelSession(model: .default)
            let response = try await session.respond(to: prompt)
            let text = response.content
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AppleLanguageModelingError.emptyResponse
            }
            return text
        case .privateCloudCompute:
            // PCC session APIs are not visible in the iOS 26.5 swiftinterface.
            throw AppleLanguageModelingError.unavailable(.notSupportedInThisBuild)
        }
        #else
        throw AppleLanguageModelingError.unavailable(.notSupportedInThisBuild)
        #endif
    }
}

#if canImport(FoundationModels)
extension SystemAppleLanguageModeling {
    private static func mapOnDeviceAvailability(
        _ availability: SystemLanguageModel.Availability
    ) -> AppleLanguageModelAvailability {
        switch availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: .deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(reason: .appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .unavailable(reason: .modelNotReady)
            @unknown default:
                return .unavailable(reason: .unknown)
            }
        @unknown default:
            return .unavailable(reason: .unknown)
        }
    }

    /// PCC types ship in FoundationModels binaries but are not declared in the
    /// iOS 26.5 module interface. Gate on iOS 27; until an iOS 27 SDK exposes
    /// `PrivateCloudComputeLanguageModel`, map to `.notSupportedInThisBuild`.
    private static func privateCloudComputeAvailability() -> AppleLanguageModelAvailability {
        guard #available(iOS 27.0, *) else {
            return .unavailable(reason: .notSupportedInThisBuild)
        }
        return .unavailable(reason: .notSupportedInThisBuild)
    }

    private static func privateCloudComputeQuota() -> AppleLanguageQuotaSnapshot? {
        guard #available(iOS 27.0, *) else {
            return nil
        }
        return nil
    }
}
#endif
