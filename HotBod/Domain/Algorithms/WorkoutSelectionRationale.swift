import Foundation

enum WorkoutSelectionRationale {
    static func build(
        input: WorkoutGenerationInput,
        muscles: [MuscleGroup],
        selectedExercises: [Exercise],
        sessionMode: SessionMode,
        filterOptions: WorkoutSelectionFilterContext
    ) -> [String] {
        var lines: [String] = []

        if sessionMode == .recovery {
            lines.append("Recovery session — reduced volume based on soreness and fatigue.")
            return lines
        }

        for muscle in muscles {
            let recovery = Int(GenerationConstants.Recovery.recovery(for: muscle, in: input.muscleRecovery))
            lines.append("\(muscle.displayName): \(recovery)% recovered")
        }

        let splitLabel = input.splitDayFocus?.displayName ?? input.userProfile.preferredSplit.displayName
        lines.append("\(splitLabel) rotation for today's focus")

        let variability = input.userPreferences.exerciseVariability
        if variability.appliesJitter {
            lines.append("Exercise variety: \(variability.displayName.lowercased())")
        }

        if !input.userPreferences.avoidExerciseIds.isEmpty {
            lines.append("Excluded \(input.userPreferences.avoidExerciseIds.count) exercise(s) to refresh selection")
        }

        if input.userProfile.preferredExerciseGrouping != .none {
            lines.append("Grouped as \(input.userProfile.preferredExerciseGrouping.displayName.lowercased())")
        }

        if input.userProfile.includeCooldown {
            lines.append("Cooldown sets appended to each exercise")
        }
        if input.userProfile.cardioBlockPlacement != .none {
            lines.append("Cardio block at \(input.userProfile.cardioBlockPlacement.displayName.lowercased()) of session")
        }
        if !input.userProfile.maxAvailableWeightKg.isEmpty {
            lines.append("Loads capped by equipment max-weight limits")
        }

        let favoriteCount = selectedExercises.filter(\.isFavorite).count
        if favoriteCount > 0 {
            lines.append("Boosted \(favoriteCount) favorite exercise(s) in scoring")
        }

        if filterOptions.includeAvoided {
            lines.append("Relaxed avoided-exercise filter — limited alternatives")
        }
        if filterOptions.relaxDifficultyPenalty {
            lines.append("Relaxed experience filter — limited alternatives")
        }

        return lines
    }
}

struct WorkoutSelectionFilterContext: Equatable {
    var includeAvoided = false
    var relaxDifficultyPenalty = false
}
