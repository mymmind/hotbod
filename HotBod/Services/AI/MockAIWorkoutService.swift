import Foundation

struct MockAIWorkoutService: AIWorkoutService, Sendable {
    func classifyIntent(_ message: String) async -> CoachIntent {
        let lower = message.lowercased()
        if lower.contains("why") || lower.contains("explain") { return .explainWorkout }
        if lower.contains("minute") || lower.contains("shorter") { return .modifyWorkout }
        if lower.contains("substitut") || lower.contains("swap") || lower.contains("shoulder") { return .modifyWorkout }
        if lower.contains("generate") || lower.contains("new workout") { return .generateWorkout }
        if lower.contains("protein") { return .proteinHelp }
        if lower.contains("plateau") || lower.contains("going down") { return .analyzePlateau }
        if lower.contains("week") || lower.contains("review") { return .motivation }
        return .generalTrainingQuestion
    }

    func respond(to message: String, context: CoachContext) async throws -> CoachAIResult {
        let intent = await classifyIntent(message)
        let content: String

        switch intent {
        case .explainWorkout:
            content = context.currentWorkout?.rationale ??
                "Today's session prioritizes recovered muscle groups and respects your equipment profile."
        case .modifyWorkout:
            if let proposed = CoachOfflineWorkoutProposer.proposeModification(message: message, context: context) {
                content = """
                I compressed today's session while keeping main compounds. \
                Review the proposal and tap Apply to update your plan.
                """
                let msg = CoachMessage(id: UUID(), role: .assistant, content: content, createdAt: Date(), intent: intent)
                return CoachAIResult(message: msg, proposedWorkout: proposed, validation: nil)
            }
            content = "I can compress this session by reducing accessories and tightening rest. Main compounds stay. Confirm and I'll regenerate."
        case .generateWorkout:
            content = "Sign in with cloud coach enabled to generate a structured workout from AI. Offline mode uses the rules engine via Today → Regenerate."
        case .proteinHelp:
            let gap = max(0, context.proteinSummary.goalGrams - context.proteinSummary.todayGrams)
            content = """
            You've logged \(Int(context.proteinSummary.todayGrams))g today. \
            \(Int(gap))g remaining to hit your target. Post-workout shake closes the gap fastest.
            """
        case .analyzePlateau:
            content = "If a lift is trending down across 3 sessions, reduce load 5% and rebuild volume. Check sleep and protein compliance first."
        case .motivation:
            content = """
            This week: train consistently, hit protein above \(Int(context.proteinSummary.goalGrams * 0.85))g/day, \
            and protect recovery on lagging muscle groups.
            """
        default:
            content = "Train the plan. Log every set. Hit protein. Progress photos weekly. Ask me to explain today's workout or adjust for time/equipment."
        }

        let message = CoachMessage(id: UUID(), role: .assistant, content: content, createdAt: Date(), intent: intent)
        return CoachAIResult(message: message, proposedWorkout: nil, validation: nil)
    }
}
