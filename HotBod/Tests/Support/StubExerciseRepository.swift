import Foundation
@testable import HotBod

actor StubExerciseRepository: ExerciseRepository {
    var exercises: [Exercise]
    private var preferences: [String: ExercisePreference] = [:]

    init(exercises: [Exercise]) {
        self.exercises = exercises
        for exercise in exercises where exercise.preference != .neutral {
            preferences[exercise.id] = exercise.preference
        }
    }

    func fetchAll() async throws -> [Exercise] {
        exercises.map { exercise in
            var copy = exercise
            copy.preference = preferences[exercise.id] ?? .neutral
            return copy
        }
    }

    func fetch(id: String) async throws -> Exercise? {
        try await fetchAll().first { $0.id == id }
    }

    func fetchSubstitutionGroups() async throws -> [ExerciseSubstitutionGroup] { [] }
    func fetchExercises(inGroup groupId: String) async throws -> [Exercise] { [] }
    func substitutionGroup(for exerciseId: String) async throws -> ExerciseSubstitutionGroup? { nil }

    func updateFavorite(id: String, isFavorite: Bool) async throws {
        let current = preferences[id] ?? .neutral
        let next: ExercisePreference
        if isFavorite {
            next = .favorite
        } else if current == .favorite {
            next = .neutral
        } else {
            next = current
        }
        try await updatePreference(id: id, preference: next)
    }

    func updateAvoided(id: String, isAvoided: Bool) async throws {
        let current = exercises.first { $0.id == id }?.preference ?? .neutral
        let next: ExercisePreference
        if isAvoided {
            next = .excluded
        } else if current == .excluded {
            next = .neutral
        } else {
            next = current
        }
        try await updatePreference(id: id, preference: next)
    }

    func updatePreference(id: String, preference: ExercisePreference) async throws {
        if preference == .neutral {
            preferences.removeValue(forKey: id)
        } else {
            preferences[id] = preference
        }
    }

    func resetUserPreferences() async throws {
        preferences.removeAll()
    }

    func resetCustomExercises() async throws {
        exercises.removeAll { $0.isCustom }
        let remainingIds = Set(exercises.map(\.id))
        preferences = preferences.filter { remainingIds.contains($0.key) }
    }

    func preferenceOverrides() async -> [String: ExercisePreference] {
        preferences
    }

    func applyPreferenceOverrides(_ overrides: [String: ExercisePreference]) async throws {
        preferences = overrides
        for index in exercises.indices {
            exercises[index].preference = overrides[exercises[index].id] ?? .neutral
        }
    }

    func createCustomExercise(_ exercise: Exercise) async throws -> Exercise {
        var custom = exercise
        custom.isCustom = true
        exercises.append(custom)
        return custom
    }

    func deleteCustomExercise(id: String) async throws {
        exercises.removeAll { $0.id == id && $0.isCustom }
        preferences.removeValue(forKey: id)
    }
}

func makeStubExercise(
    id: String,
    muscles: [MuscleGroup],
    pattern: MovementPattern,
    equipment: [Equipment] = [.bodyweight],
    isAvoided: Bool = false,
    preference: ExercisePreference? = nil,
    difficulty: ExerciseDifficulty = .intermediate,
    contraindications: [String] = []
) -> Exercise {
    Exercise(
        id: id,
        name: id,
        slug: id,
        primaryMuscles: muscles,
        secondaryMuscles: [],
        equipment: equipment,
        movementPattern: pattern,
        difficulty: difficulty,
        forceType: nil,
        mechanics: pattern.inferredMechanics,
        instructions: [],
        formCues: [],
        commonMistakes: [],
        contraindications: contraindications,
        substitutions: [],
        progressions: [],
        regressions: [],
        demoVideos: [],
        imageUrl: nil,
        tags: [],
        preference: preference ?? (isAvoided ? .excluded : .neutral)
    )
}
