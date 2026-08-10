import Foundation
import OSLog

#if canImport(Supabase)
import Supabase
#endif

struct UnavailablePhysiqueAssessmentService: PhysiqueAssessmentServing, Sendable {
    func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment {
        throw URLError(.notConnectedToInternet)
    }
}

struct RemotePhysiqueAssessmentPayload: Codable {
    let photoQuality: RemotePhysiquePhotoQualityPayload
    let physique: RemotePhysiqueBuildSummaryPayload
    let muscleEntries: [RemotePhysiqueMuscleEntryPayload]
    let developmentPriorities: [RemotePhysiqueDevelopmentPriorityPayload]
    let trainingBias: RemotePhysiqueTrainingBiasPayload
    let limitations: [String]
    let confidenceBands: RemotePhysiqueConfidenceBandsPayload
    let whyTodaySummary: String
}

struct RemotePhysiquePhotoQualityPayload: Codable {
    let anglesAvailable: [String]
    let lightingQuality: String
    let overallConfidence: Double
}

struct RemotePhysiqueBuildSummaryPayload: Codable {
    let overallArchetype: String
    let frameSize: String
    let shoulderToWaist: String
    let waist: String
    let torso: String
    let muscularity: String
    let leanness: String
}

struct RemotePhysiqueMuscleEntryPayload: Codable {
    let muscle: String
    let current: String
    let priorityRank: Int?
    let notes: String
    let confidence: String
}

struct RemotePhysiqueDevelopmentPriorityPayload: Codable {
    let muscle: String
    let reason: String
}

struct RemotePhysiqueTrainingBiasPayload: Codable {
    let preferredMuscleGroups: [String]
    let rationale: String
}

struct RemotePhysiqueConfidenceBandsPayload: Codable {
    let high: [String]
    let medium: [String]
    let low: [String]
}

struct PhysiqueAssessInvokeRequest: Codable {
    let metrics: PhysiqueAssessMetricsPayload
    let anglesAvailable: [String]
    let profile: PhysiqueAssessProfilePayload
}

struct PhysiqueAssessMetricsPayload: Codable {
    let front: BodyPhotoAnalysis
    let back: BodyPhotoAnalysis
    let side: BodyPhotoAnalysis?
}

struct PhysiqueAssessProfilePayload: Codable {
    let goal: String
    let experienceLevel: String
    let limitations: [String]
}

actor RemotePhysiqueAssessmentService: PhysiqueAssessmentServing {
    private static let logger = Logger(subsystem: "com.hotbod.app", category: "RemotePhysiqueAssessmentService")

    #if canImport(Supabase)
    private let client: SupabaseClient
    #endif
    private let auth: AuthService

    #if canImport(Supabase)
    init(client: SupabaseClient, auth: AuthService) {
        self.client = client
        self.auth = auth
    }
    #else
    init(auth: AuthService) {
        self.auth = auth
    }
    #endif

    func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment {
        #if canImport(Supabase)
        guard auth.isAvailable, await auth.currentUserId() != nil else {
            throw URLError(.userAuthenticationRequired)
        }

        let invokeRequest = Self.makeInvokeRequest(from: request)
        let response: RemotePhysiqueAssessmentPayload
        do {
            response = try await client.functions.invoke(
                "physique-assess",
                options: FunctionInvokeOptions(body: invokeRequest)
            )
        } catch {
            logFailure(error)
            throw error
        }

        return PhysiqueAssessmentSanitizer.map(response, request: request)
        #else
        throw URLError(.notConnectedToInternet)
        #endif
    }

    private static func makeInvokeRequest(from request: PhysiqueAssessmentRequest) -> PhysiqueAssessInvokeRequest {
        var angles = ["front", "back"]
        if request.sideMetrics != nil {
            angles.append("side")
        }

        return PhysiqueAssessInvokeRequest(
            metrics: PhysiqueAssessMetricsPayload(
                front: request.frontMetrics,
                back: request.backMetrics,
                side: request.sideMetrics
            ),
            anglesAvailable: angles,
            profile: PhysiqueAssessProfilePayload(
                goal: request.profile.goal.rawValue,
                experienceLevel: request.profile.experienceLevel.rawValue,
                limitations: request.profile.limitations.map(\.rawValue)
            )
        )
    }

    private func logFailure(_ error: Error) {
        if error is DecodingError {
            Self.logger.error("Cloud physique assessment decoding failed: \(error.localizedDescription, privacy: .public)")
        } else if error is URLError {
            Self.logger.error("Cloud physique assessment transport failed: \(error.localizedDescription, privacy: .public)")
        } else {
            Self.logger.error("Cloud physique assessment request failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
