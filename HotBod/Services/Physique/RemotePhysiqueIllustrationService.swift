import Foundation
import OSLog

#if canImport(Supabase)
import Supabase
#endif

struct RemotePhysiqueIllustrateRequest: Encodable {
    var assessmentId: String
    var imageBase64: String
    var priorityMuscles: [String]
    var directionGenericLabels: [String]
}

struct RemotePhysiqueIllustrateResponse: Decodable {
    var imageBase64: String
    var contentType: String
}

struct RemotePhysiqueIllustrateErrorResponse: Decodable {
    var error: String
}

actor RemotePhysiqueIllustrationService: PhysiqueIllustrationService {
    private static let logger = Logger(
        subsystem: "com.hotbod.app",
        category: "RemotePhysiqueIllustrationService"
    )

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

    func generate(
        assessmentId: UUID,
        hints: PhysiqueIllustrationHints,
        imageData: Data
    ) async throws -> Data {
        #if canImport(Supabase)
        guard auth.isAvailable, await auth.currentUserId() != nil else {
            throw PhysiqueIllustrationError.notConfigured
        }

        let invokeRequest = RemotePhysiqueIllustrateRequest(
            assessmentId: assessmentId.uuidString,
            imageBase64: imageData.base64EncodedString(),
            priorityMuscles: hints.priorityMuscles.map(\.rawValue),
            directionGenericLabels: hints.directionGenericLabels
        )

        let response: RemotePhysiqueIllustrateResponse
        do {
            response = try await client.functions.invoke(
                "physique-illustrate",
                options: FunctionInvokeOptions(body: invokeRequest)
            )
        } catch {
            logFailure(error)
            throw Self.mapInvokeError(error)
        }

        guard let decoded = Data(base64Encoded: response.imageBase64), !decoded.isEmpty else {
            throw PhysiqueIllustrationError.invalidResponse
        }
        return decoded
        #else
        throw PhysiqueIllustrationError.notConfigured
        #endif
    }

    private func logFailure(_ error: Error) {
        if error is DecodingError {
            Self.logger.error(
                "Cloud physique illustration decoding failed: \(error.localizedDescription, privacy: .public)"
            )
        } else if error is URLError {
            Self.logger.error(
                "Cloud physique illustration transport failed: \(error.localizedDescription, privacy: .public)"
            )
        } else {
            Self.logger.error(
                "Cloud physique illustration request failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func mapInvokeError(_ error: Error) -> PhysiqueIllustrationError {
        #if canImport(Supabase)
        if case FunctionsError.httpError(_, let data) = error,
           let payload = try? JSONDecoder().decode(RemotePhysiqueIllustrateErrorResponse.self, from: data),
           !payload.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .serverMessage(payload.error)
        }
        #endif
        if error is DecodingError {
            return .invalidResponse
        }
        return .unavailable
    }
}
