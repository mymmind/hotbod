import Foundation
import OSLog

#if canImport(Supabase)
import Supabase
#endif

actor RemoteAIWorkoutService: AIWorkoutService {
    private static let logger = Logger(subsystem: "com.hotbod.app", category: "RemoteAIWorkoutService")
    #if canImport(Supabase)
    private let client: SupabaseClient
    #endif
    private let auth: AuthService
    private let fallback: MockAIWorkoutService

    #if canImport(Supabase)
    init(client: SupabaseClient, auth: AuthService, fallback: MockAIWorkoutService = MockAIWorkoutService()) {
        self.client = client
        self.auth = auth
        self.fallback = fallback
    }
    #else
    init(auth: AuthService, fallback: MockAIWorkoutService = MockAIWorkoutService()) {
        self.auth = auth
        self.fallback = fallback
    }
    #endif

    func classifyIntent(_ message: String) async -> CoachIntent {
        await fallback.classifyIntent(message)
    }

    func respond(to message: String, context: CoachContext) async throws -> CoachAIResult {
        #if canImport(Supabase)
        guard auth.isAvailable, await auth.currentUserId() != nil else {
            let content = "Sign in under Settings to use the cloud coach. Offline responses are limited until you're signed in."
            let coachMessage = CoachMessage(
                id: UUID(),
                role: .assistant,
                content: content,
                createdAt: Date(),
                intent: .generalTrainingQuestion
            )
            return CoachAIResult(message: coachMessage, proposedWorkout: nil, validation: nil)
        }

        do {
            let request = CoachInvokeRequest(message: message, context: context)
            let response: RemoteCoachResponse = try await client.functions.invoke(
                "coach",
                options: FunctionInvokeOptions(body: request)
            )

            let intent = CoachIntent(rawValue: response.intent) ?? .unknown
            var content = response.content
            if !response.safetyNotes.isEmpty {
                let notes = response.safetyNotes.joined(separator: " ")
                if !content.contains(notes) {
                    content += "\n\n" + notes
                }
            }

            let coachMessage = CoachMessage(
                id: UUID(),
                role: .assistant,
                content: content,
                createdAt: Date(),
                intent: intent
            )

            let mapping = response.proposedWorkout.map { AIWorkoutPayloadMapper.map($0) }
            return CoachAIResult(
                message: coachMessage,
                proposedWorkout: mapping?.workout,
                validation: response.validation,
                droppedExerciseIds: mapping?.droppedExerciseIds ?? []
            )
        } catch {
            logCoachFailure(error)
            var offline = try await fallback.respond(to: message, context: context)
            offline.message.content += "\n\n(Cloud coach unavailable — using offline responses.)"
            return offline
        }
        #else
        return try await fallback.respond(to: message, context: context)
        #endif
    }

    private func logCoachFailure(_ error: Error) {
        if error is DecodingError {
            Self.logger.error("Cloud coach response decoding failed: \(error.localizedDescription, privacy: .public)")
        } else if error is URLError {
            Self.logger.error("Cloud coach transport failed: \(error.localizedDescription, privacy: .public)")
        } else {
            Self.logger.error("Cloud coach request failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
