import Foundation

enum ExerciseCatalog {
    static func autoGroupId(for exercise: Exercise) -> String {
        let muscle = exercise.primaryMuscles.first?.rawValue ?? "general"
        return "\(muscle)_\(exercise.movementPattern.rawValue)"
    }

    static func resolvedGroupId(for exercise: Exercise) -> String {
        exercise.substitutionGroupId ?? autoGroupId(for: exercise)
    }

    static func substitutionGroup(
        for exerciseId: String,
        exercises: [Exercise],
        groups: [ExerciseSubstitutionGroup]
    ) -> ExerciseSubstitutionGroup? {
        guard let exercise = exercises.first(where: { $0.id == exerciseId }) else { return nil }
        let groupId = resolvedGroupId(for: exercise)
        if let defined = groups.first(where: { $0.id == groupId }) {
            return defined
        }
        return ExerciseSubstitutionGroup(
            id: groupId,
            name: fallbackGroupName(for: exercise),
            primaryMuscles: exercise.primaryMuscles,
            movementPattern: exercise.movementPattern,
            description: nil
        )
    }

    static func exercises(
        inGroup groupId: String,
        from exercises: [Exercise]
    ) -> [Exercise] {
        exercises
            .filter { resolvedGroupId(for: $0) == groupId }
            .sorted { $0.name < $1.name }
    }

    /// Ranked substitutes: same swap group first, then seeded links, then muscle/pattern matches.
    static func substitutes(
        for exerciseId: String,
        from exercises: [Exercise],
        availableEquipment: [Equipment],
        injuries: [BodyLimitation],
        excludeIds: Set<String> = []
    ) -> [Exercise] {
        guard let source = exercises.first(where: { $0.id == exerciseId }) else { return [] }

        let groupId = resolvedGroupId(for: source)
        let groupMembers = exercises.filter {
            $0.id != exerciseId &&
            resolvedGroupId(for: $0) == groupId &&
            passesFilters($0, availableEquipment: availableEquipment, injuries: injuries, excludeIds: excludeIds)
        }

        let seeded = source.substitutions.compactMap { id in exercises.first { $0.id == id } }
            .filter { passesFilters($0, availableEquipment: availableEquipment, injuries: injuries, excludeIds: excludeIds) }

        let algorithmic = exercises.filter { candidate in
            candidate.id != exerciseId &&
            !excludeIds.contains(candidate.id) &&
            !groupMembers.contains(where: { $0.id == candidate.id }) &&
            !seeded.contains(where: { $0.id == candidate.id }) &&
            passesFilters(candidate, availableEquipment: availableEquipment, injuries: injuries, excludeIds: excludeIds) &&
            sharesPrimaryMuscle(source, candidate) &&
            candidate.movementPattern == source.movementPattern
        }
        .sorted { ExerciseSubstitution.scoreSubstitute(source, $0) > ExerciseSubstitution.scoreSubstitute(source, $1) }

        var seen = Set<String>()
        return (groupMembers + seeded + algorithmic).filter { seen.insert($0.id).inserted }
    }

    private static func fallbackGroupName(for exercise: Exercise) -> String {
        let muscles = exercise.primaryMuscles.map(\.displayName).joined(separator: " & ")
        return "\(muscles) \(exercise.movementPattern.displayName)"
    }

    private static func passesFilters(
        _ exercise: Exercise,
        availableEquipment: [Equipment],
        injuries: [BodyLimitation],
        excludeIds: Set<String>
    ) -> Bool {
        !excludeIds.contains(exercise.id) &&
        !exercise.isAvoided &&
        ExerciseSubstitution.isEquipmentAvailable(exercise, available: availableEquipment) &&
        !ExerciseSubstitution.violatesInjuries(exercise, injuries: injuries)
    }

    private static func sharesPrimaryMuscle(_ a: Exercise, _ b: Exercise) -> Bool {
        !Set(a.primaryMuscles).isDisjoint(with: Set(b.primaryMuscles))
    }

    /// Builds an id-indexed map; later entries win when duplicate ids appear in persisted custom data.
    static func indexedById(_ exercises: [Exercise]) -> [String: Exercise] {
        Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }
}
