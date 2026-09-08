import Foundation

enum AIWorkoutServiceSelection: Equatable {
    case remote
    case gemini
    case mock

    static func preferred(
        personalUse: Bool,
        supabaseConfigured: Bool,
        geminiConfigured: Bool
    ) -> Self {
        if personalUse {
            return geminiConfigured ? .gemini : .mock
        }
        if supabaseConfigured { return .remote }
        if geminiConfigured { return .gemini }
        return .mock
    }
}
