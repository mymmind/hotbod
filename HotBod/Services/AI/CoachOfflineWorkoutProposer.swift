import Foundation

enum CoachOfflineWorkoutProposer {
    static func proposeModification(message: String, context: CoachContext) -> GeneratedWorkout? {
        guard let current = context.currentWorkout else { return nil }

        let options = CoachOfflineModify.generationOptions(
            from: message,
            profile: stubProfile(from: context)
        )

        var proposed = GeneratedWorkout(
            id: UUID(),
            title: current.title,
            estimatedDurationMinutes: current.estimatedDurationMinutes,
            focus: current.focus,
            exercises: current.exercises,
            rationale: "Offline coach adjustment based on your request.",
            safetyNotes: current.safetyNotes,
            generatedBy: .aiAssisted,
            createdAt: Date(),
            sessionMode: current.sessionMode,
            splitDayFocus: current.splitDayFocus
        )

        if let targetMinutes = options.targetDurationMinutes,
           targetMinutes < proposed.estimatedDurationMinutes {
            proposed = compress(workout: proposed, targetMinutes: targetMinutes)
        }

        if let soreness = options.soreness, soreness != .none {
            proposed = softenForSoreness(workout: proposed, soreness: soreness)
        }

        guard !isEffectivelySame(proposed, current) else { return nil }
        guard CoachModificationSafety.isSafeModification(
            proposed: proposed,
            current: current,
            allowedExerciseIds: Set(context.allowedExerciseIds)
        ) else { return nil }

        return proposed
    }

    private static func compress(workout: GeneratedWorkout, targetMinutes: Int) -> GeneratedWorkout {
        var updated = workout
        updated.estimatedDurationMinutes = targetMinutes

        while estimatedMinutes(for: updated) > targetMinutes, updated.exercises.count > 1 {
            updated.exercises.removeLast()
        }

        if estimatedMinutes(for: updated) > targetMinutes {
            updated.exercises = updated.exercises.map { exercise in
                var trimmed = exercise
                if trimmed.targetSets.count > 2 {
                    trimmed.targetSets = Array(trimmed.targetSets.dropLast())
                }
                return trimmed
            }
        }

        updated.estimatedDurationMinutes = min(targetMinutes, estimatedMinutes(for: updated))
        return updated
    }

    private static func softenForSoreness(workout: GeneratedWorkout, soreness: SorenessLevel) -> GeneratedWorkout {
        var updated = workout
        let dropCount = soreness == .severe ? 2 : 1
        updated.exercises = updated.exercises.map { exercise in
            var softened = exercise
            if softened.targetSets.count > dropCount {
                softened.targetSets = Array(softened.targetSets.dropLast(dropCount))
            }
            softened.restSeconds = min(softened.restSeconds + 15, 150)
            return softened
        }
        updated.sessionMode = .recovery
        updated.safetyNotes = Array(Set(updated.safetyNotes + ["Recovery-focused volume reduction applied."]))
        updated.estimatedDurationMinutes = max(20, estimatedMinutes(for: updated) - 5)
        return updated
    }

    private static func estimatedMinutes(for workout: GeneratedWorkout) -> Int {
        let setMinutes = workout.exercises.reduce(0) { $0 + $1.targetSets.count * 2 }
        let restMinutes = workout.exercises.reduce(0) { partial, exercise in
            partial + max(0, exercise.targetSets.count - 1) * exercise.restSeconds / 60
        }
        return max(20, setMinutes + restMinutes)
    }

    private static func isEffectivelySame(_ lhs: GeneratedWorkout, _ rhs: GeneratedWorkout) -> Bool {
        lhs.estimatedDurationMinutes == rhs.estimatedDurationMinutes
            && lhs.exercises == rhs.exercises
            && lhs.sessionMode == rhs.sessionMode
    }

    private static func stubProfile(from context: CoachContext) -> UserProfile {
        var profile = UserProfile.empty()
        profile.goal = context.userProfile.goal
        profile.experienceLevel = context.userProfile.experienceLevel
        profile.proteinGoalGrams = context.userProfile.proteinGoalGrams
        profile.preferredSessionLengthMinutes = context.targetDurationMinutes
        profile.limitations = context.limitations
        profile.availableEquipment = context.availableEquipment
        return profile
    }
}
