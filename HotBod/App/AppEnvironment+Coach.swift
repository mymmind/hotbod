import Foundation

extension AppEnvironment {
    func fetchCoachMessages() async -> [CoachMessage] {
        (try? await coachRepository.fetchMessages()) ?? []
    }

    func saveCoachMessage(_ message: CoachMessage) async throws {
        try await coachRepository.saveMessage(message)
    }

    func fetchAllExercises() async -> [Exercise] {
        (try? await exerciseRepository.fetchAll()) ?? []
    }

    func fetchExerciseStats() async -> [UserExerciseStats] {
        (try? await exerciseStatsRepository.fetchStats()) ?? []
    }

    func fetchExercise(id: String) async -> Exercise? {
        try? await exerciseRepository.fetch(id: id)
    }

    func fetchSubstitutionGroups() async -> [ExerciseSubstitutionGroup] {
        (try? await exerciseRepository.fetchSubstitutionGroups()) ?? []
    }

    func updateExerciseFavorite(id: String, isFavorite: Bool) async throws {
        try await exerciseRepository.updateFavorite(id: id, isFavorite: isFavorite)
    }

    func updateExerciseAvoided(id: String, isAvoided: Bool) async throws {
        try await exerciseRepository.updateAvoided(id: id, isAvoided: isAvoided)
    }

    func updateExercisePreference(id: String, preference: ExercisePreference) async throws {
        try await exerciseRepository.updatePreference(id: id, preference: preference)
    }

    func createCustomExercise(_ exercise: Exercise) async throws -> Exercise {
        try await exerciseRepository.createCustomExercise(exercise)
    }

    func deleteCustomExercise(id: String) async throws {
        try await exerciseRepository.deleteCustomExercise(id: id)
    }

    func loadExerciseSwapResolver(usedExerciseIds: Set<String>) async -> ExerciseSwapResolver? {
        guard let profile = userProfile else { return nil }
        return await ExerciseSwapResolver.load(
            from: exerciseRepository,
            profile: profile,
            usedExerciseIds: usedExerciseIds
        )
    }

    func tryAutoApplyCoachModification(
        result: CoachAIResult,
        allowedExerciseIds: [String]
    ) async -> Bool {
        guard result.message.intent == .modifyWorkout,
              let proposed = result.proposedWorkout else { return false }

        if await blocksCoachWorkoutModification() {
            coachWorkoutUpdateMessage = "Finish or discard your current session before applying coach changes."
            return false
        }

        guard CoachModificationSafety.isSafeModification(
            proposed: proposed,
            current: todayWorkout,
            allowedExerciseIds: Set(allowedExerciseIds)
        ) else { return false }

        guard let profile = userProfile else { return false }

        let input = await makeWorkoutGenerationInput(
            profile: profile,
            splitDayFocus: TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)
        )

        let localValidation = workoutGenerationService.validate(workout: proposed, input: input)
        let serverValid = result.validation?.isValid ?? true
        guard localValidation.isValid, serverValid else { return false }

        let applied = await applyAIWorkout(proposed, serverValidation: result.validation)
        if applied {
            coachWorkoutUpdateMessage = "Workout updated"
        }
        return applied
    }

    @discardableResult
    func applyAIWorkout(_ workout: GeneratedWorkout, serverValidation: WorkoutValidationResult? = nil) async -> Bool {
        guard let profile = userProfile else { return false }

        if !canAccess(.coachWorkoutApply) {
            presentPaywall(for: .coachWorkoutApply)
            return false
        }

        if await blocksCoachWorkoutModification() {
            coachWorkoutUpdateMessage = "Finish or discard your current session before applying coach changes."
            return false
        }

        let input = await makeWorkoutGenerationInput(
            profile: profile,
            splitDayFocus: TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)
        )

        let localValidation = workoutGenerationService.validate(workout: workout, input: input)
        let merged = WorkoutValidationResult(
            isValid: localValidation.isValid && (serverValidation?.isValid ?? true),
            errors: localValidation.errors + (serverValidation?.errors ?? []),
            warnings: localValidation.warnings + (serverValidation?.warnings ?? [])
        )
        lastValidation = merged
        guard merged.isValid else { return false }

        todayWorkout = workout
        try? await workoutRepository.saveTodayWorkout(workout)
        if isSignedIn {
            try? await cloudSyncService.pushTodayWorkout(workout)
        }
        return true
    }
}
