import Foundation

struct ExerciseSwapResolver {
    let allExercises: [Exercise]
    let substitutionGroups: [ExerciseSubstitutionGroup]
    let profile: UserProfile
    let usedExerciseIds: Set<String>

    static func load(from repository: any ExerciseRepository, profile: UserProfile, usedExerciseIds: Set<String>) async -> ExerciseSwapResolver {
        let all = (try? await repository.fetchAll()) ?? []
        let groups = (try? await repository.fetchSubstitutionGroups()) ?? []
        return ExerciseSwapResolver(
            allExercises: all,
            substitutionGroups: groups,
            profile: profile,
            usedExerciseIds: usedExerciseIds
        )
    }

    func substitutionGroup(for exerciseId: String) -> ExerciseSubstitutionGroup? {
        ExerciseCatalog.substitutionGroup(
            for: exerciseId,
            exercises: allExercises,
            groups: substitutionGroups
        )
    }

    func swapCandidates(for exerciseId: String, workoutExerciseIds: Set<String>? = nil) -> [Exercise] {
        let excludeIds = workoutExerciseIds ?? usedExerciseIds
        return ExerciseSubstitution.candidates(
            for: exerciseId,
            from: allExercises,
            availableEquipment: profile.availableEquipment,
            injuries: profile.limitations,
            excludeIds: excludeIds
        )
    }

    var exerciseMap: [String: Exercise] {
        Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
    }
}
