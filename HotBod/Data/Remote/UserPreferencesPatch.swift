import Foundation

#if canImport(Supabase)
struct UserPreferencesPatch: Encodable {
    private enum Field {
        case exercisePreferences([String: ExercisePreference])
        case todayWorkout(GeneratedWorkout?)
        case programState(TrainingProgramState)
    }

    private enum CodingKeys: String, CodingKey {
        case exercise_preferences_json
        case today_workout_json
        case program_state_json
    }

    private let field: Field

    static func exercisePreferences(_ preferences: [String: ExercisePreference]) -> Self {
        Self(field: .exercisePreferences(preferences))
    }

    static func todayWorkout(_ workout: GeneratedWorkout) -> Self {
        Self(field: .todayWorkout(workout))
    }

    static func clearTodayWorkout() -> Self {
        Self(field: .todayWorkout(nil))
    }

    static func programState(_ state: TrainingProgramState) -> Self {
        Self(field: .programState(state))
    }

    private init(field: Field) {
        self.field = field
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch field {
        case let .exercisePreferences(preferences):
            try container.encode(preferences, forKey: .exercise_preferences_json)
        case let .todayWorkout(workout):
            try container.encode(workout, forKey: .today_workout_json)
        case let .programState(state):
            try container.encode(state, forKey: .program_state_json)
        }
    }
}
#endif
