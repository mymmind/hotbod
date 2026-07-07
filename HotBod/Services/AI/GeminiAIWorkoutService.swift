import Foundation

final class GeminiAIWorkoutService: AIWorkoutService, Sendable {
    private let fallback: MockAIWorkoutService
    private let exerciseRepository: any ExerciseRepository
    private let session: URLSession

    init(exerciseRepository: any ExerciseRepository, fallback: MockAIWorkoutService = MockAIWorkoutService()) {
        self.fallback = fallback
        self.exerciseRepository = exerciseRepository
        self.session = URLSession.shared
    }

    func classifyIntent(_ message: String) async -> CoachIntent {
        await fallback.classifyIntent(message)
    }

    func respond(to message: String, context: CoachContext) async throws -> CoachAIResult {
        let intent = await classifyIntent(message)

        switch intent {
        case .generateWorkout:
            return try await generateWorkoutResponse(message: message, context: context, intent: intent)
        case .modifyWorkout:
            return try await modifyWorkoutResponse(message: message, context: context, intent: intent)
        case .explainWorkout:
            return try await explainWorkoutResponse(message: message, context: context, intent: intent)
        default:
            let fallbackResult = try await fallback.respond(to: message, context: context)
            return fallbackResult
        }
    }

    // MARK: - Intent-Specific Responses

    private func generateWorkoutResponse(
        message: String,
        context: CoachContext,
        intent: CoachIntent
    ) async throws -> CoachAIResult {
        guard GeminiConfig.isConfigured else {
            return try await fallback.respond(to: message, context: context)
        }

        let generatedWorkout = try await callGeminiForWorkoutGeneration(message: message, context: context)
        let aiMessage = CoachMessage(
            id: UUID(),
            role: .assistant,
            content: "I've generated a customized workout for you. Check the details and adjust if needed.",
            createdAt: Date(),
            intent: intent
        )
        return CoachAIResult(message: aiMessage, proposedWorkout: generatedWorkout, validation: nil)
    }

    private func modifyWorkoutResponse(
        message: String,
        context: CoachContext,
        intent: CoachIntent
    ) async throws -> CoachAIResult {
        let shouldRegenerate = message.lowercased().contains("faster") ||
            message.lowercased().contains("shorter") ||
            message.lowercased().contains("lighter") ||
            message.lowercased().contains("reset") ||
            message.lowercased().contains("modify")

        if shouldRegenerate, let currentWorkout = context.currentWorkout, GeminiConfig.isConfigured {
            let generatedWorkout = try await callGeminiForModification(
                message: message,
                context: context,
                currentWorkout: currentWorkout
            )
            let aiMessage = CoachMessage(
                id: UUID(),
                role: .assistant,
                content: "Workout modified as requested. Ready to train?",
                createdAt: Date(),
                intent: intent
            )
            return CoachAIResult(message: aiMessage, proposedWorkout: generatedWorkout, validation: nil)
        }

        let fallbackResult = try await fallback.respond(to: message, context: context)
        return fallbackResult
    }

    private func explainWorkoutResponse(
        message: String,
        context: CoachContext,
        intent: CoachIntent
    ) async throws -> CoachAIResult {
        guard GeminiConfig.isConfigured, let currentWorkout = context.currentWorkout else {
            return try await fallback.respond(to: message, context: context)
        }

        let explanation = try await callGeminiForExplanation(
            message: message,
            context: context,
            workout: currentWorkout
        )
        let aiMessage = CoachMessage(
            id: UUID(),
            role: .assistant,
            content: explanation,
            createdAt: Date(),
            intent: intent
        )
        return CoachAIResult(message: aiMessage, proposedWorkout: nil, validation: nil)
    }

    // MARK: - Gemini API Calls

    private func callGeminiForWorkoutGeneration(
        message: String,
        context: CoachContext
    ) async throws -> GeneratedWorkout? {
        let prompt = buildWorkoutGenerationPrompt(message: message, context: context)
        let geminResponse = try await callGeminiAPI(prompt: prompt)

        guard let workout = try parseWorkoutFromGemini(response: geminResponse, context: context) else {
            return nil
        }

        return workout
    }

    private func callGeminiForModification(
        message: String,
        context: CoachContext,
        currentWorkout: GeneratedWorkout
    ) async throws -> GeneratedWorkout? {
        let prompt = buildWorkoutModificationPrompt(message: message, context: context, currentWorkout: currentWorkout)
        let geminiResponse = try await callGeminiAPI(prompt: prompt)

        guard let workout = try parseWorkoutFromGemini(response: geminiResponse, context: context) else {
            return nil
        }

        return workout
    }

    private func callGeminiForExplanation(
        message: String,
        context: CoachContext,
        workout: GeneratedWorkout
    ) async throws -> String {
        let prompt = buildExplanationPrompt(message: message, context: context, workout: workout)
        let geminiResponse = try await callGeminiAPI(prompt: prompt)
        return geminiResponse
    }

    private func callGeminiAPI(prompt: String) async throws -> String {
        guard let apiKey = GeminiConfig.apiKey,
              let model = GeminiConfig.model else {
            throw NSError(domain: "GeminiConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gemini API key not configured"])
        }

        guard let url = URLBuilder.httpsURL(
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        ) else {
            throw NSError(domain: "GeminiConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini API URL"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gemini API request failed"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response"])
        }

        return text
    }

    // MARK: - Response Parsing

    private func parseWorkoutFromGemini(response: String, context: CoachContext) throws -> GeneratedWorkout? {
        let jsonPattern = "\\{[^{}]*\"exercises\"[^{}]*\\}"
        guard let regex = try? NSRegularExpression(pattern: jsonPattern),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            return nil
        }

        let jsonString = String(response[range])
        guard let jsonData = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(AIWorkoutPayload.self, from: jsonData) else {
            return nil
        }

        return AIWorkoutPayloadMapper.toGeneratedWorkout(payload)
    }

    // MARK: - Prompt Builders

    private func buildWorkoutGenerationPrompt(message: String, context: CoachContext) -> String {
        let equipment = context.availableEquipment.map { $0.rawValue }.joined(separator: ", ")
        let duration = context.targetDurationMinutes
        let goal = context.userProfile.goal.rawValue
        let experience = context.userProfile.experienceLevel.rawValue

        return """
        You are an expert strength training coach. Generate a structured workout based on this request:

        User Request: \(message)
        User Goal: \(goal)
        Experience Level: \(experience)
        Available Equipment: \(equipment)
        Target Duration: \(duration) minutes
        
        Return a JSON object with this structure (valid JSON only, no markdown):
        {
          "title": "Workout Name",
          "estimatedDurationMinutes": \(duration),
          "focus": ["muscle group 1", "muscle group 2"],
          "exercises": [
            {
              "exerciseId": "exercise-name-slug",
              "reason": "Why this exercise",
              "restSeconds": 90,
              "sets": [
                {"targetRepsMin": 8, "targetRepsMax": 12, "targetWeightKg": 80, "rpeTarget": 7}
              ]
            }
          ],
          "rationale": "Why this workout structure",
          "safetyNotes": ["Safety note 1"]
        }

        Constraints:
        - Use only equipment from: \(equipment)
        - Keep exercises practical and safe
        - Return ONLY valid JSON, no explanations
        - exerciseId must match catalog IDs exactly (lowercase with underscores, e.g. "bench_press")
        - Include 4-8 exercises for balanced development
        - Respect \(duration) minute target
        """
    }

    private func buildWorkoutModificationPrompt(
        message: String,
        context: CoachContext,
        currentWorkout: GeneratedWorkout
    ) -> String {
        let equipment = context.availableEquipment.map { $0.rawValue }.joined(separator: ", ")
        let currentExercises = currentWorkout.exercises.count
        let currentDuration = currentWorkout.estimatedDurationMinutes

        return """
        Modify this workout based on the user's request:

        User Request: \(message)
        Current Workout Duration: \(currentDuration) minutes
        Current Exercise Count: \(currentExercises)

        Return a modified JSON workout with the same structure as before:
        {
          "title": "Modified Workout Name",
          "estimatedDurationMinutes": \(currentDuration),
          "focus": ["muscle group 1", "muscle group 2"],
          "exercises": [
            {
              "exerciseId": "exercise-name-slug",
              "reason": "Why this exercise",
              "restSeconds": 90,
              "sets": [
                {"targetRepsMin": 8, "targetRepsMax": 12, "targetWeightKg": 80, "rpeTarget": 7}
              ]
            }
          ],
          "rationale": "Why this modified structure",
          "safetyNotes": []
        }

        Constraints:
        - Use only equipment from: \(equipment)
        - Return ONLY valid JSON
        - Keep exercises safe and practical
        - Respect the user's modification request
        """
    }

    private func buildExplanationPrompt(
        message: String,
        context: CoachContext,
        workout: GeneratedWorkout
    ) -> String {
        let exerciseNames = workout.exercises
            .prefix(3)
            .map { "- \($0.exerciseId)" }
            .joined(separator: "\n")

        return """
        Explain this workout concisely to the user:

        User Question: \(message)
        Workout Title: \(workout.title)
        Rationale: \(workout.rationale)
        Key Exercises:
        \(exerciseNames)

        Provide a brief, coaching explanation (2-3 sentences) that:
        - Explains the goal of the workout
        - Addresses the user's specific question
        - Is encouraging but not cheesy
        """
    }
}
