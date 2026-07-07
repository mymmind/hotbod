import Foundation

extension AppEnvironment {
    @discardableResult
    func regenerateTodayWorkout(profile: UserProfile, options: WorkoutGenerationOptions = WorkoutGenerationOptions()) async -> Bool {
        guard TrainingSchedule.isTrainingDay(profile: profile), !isTodayWorkoutCompleted else { return false }

        await cancelActiveWorkoutIfNeeded()
        await applyRecoveryDecay()

        let splitFocus = TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)
        var effectiveOptions = options
        if effectiveOptions.excludeExerciseIds.isEmpty, let current = todayWorkout {
            effectiveOptions.excludeExerciseIds = current.exercises.map(\.exerciseId)
            effectiveOptions.preferVariation = true
        }

        if await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: effectiveOptions
        ) {
            return true
        }

        guard !effectiveOptions.excludeExerciseIds.isEmpty else { return false }

        var fallbackOptions = options
        fallbackOptions.excludeExerciseIds = []
        fallbackOptions.preferVariation = true
        return await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: fallbackOptions
        )
    }

    @discardableResult
    func switchTodaySplitFocus() async -> Bool {
        guard let profile = userProfile,
              TrainingSchedule.isTrainingDay(profile: profile),
              !isTodayWorkoutCompleted else { return false }

        await cancelActiveWorkoutIfNeeded()

        var state = programState
        TrainingSchedule.toggleSplitFocus(state: &state, split: profile.preferredSplit)
        programState = state
        try? await programStateRepository.saveState(state)
        if isSignedIn {
            try? await cloudSyncService.pushProgramState(state)
        }

        await applyRecoveryDecay()
        let splitFocus = TrainingSchedule.currentSplitFocus(state: state, split: profile.preferredSplit)
        var options = WorkoutGenerationOptions()
        options.preferVariation = true
        return await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: options
        )
    }

    func persistRegeneratedWorkout(
        profile: UserProfile,
        splitDayFocus: SplitDayFocus?,
        options: WorkoutGenerationOptions
    ) async -> Bool {
        guard let workout = await generateWorkout(profile: profile, splitDayFocus: splitDayFocus, options: options) else {
            return false
        }

        todayWorkout = workout
        try? await workoutRepository.saveTodayWorkout(workout)
        if isSignedIn {
            try? await cloudSyncService.pushTodayWorkout(workout)
        }
        return true
    }

    func fetchTodayCompletedSession() async -> WorkoutSession? {
        guard let sessionId = programState.todayCompletedSessionId else { return nil }
        let sessions = (try? await workoutRepository.fetchSessions()) ?? []
        return sessions.first { $0.id == sessionId && $0.status == .completed }
    }

    func normalizeProgramStateForToday(profile: UserProfile) async {
        var state = programState
        TrainingSchedule.clearStaleCompletion(state: &state)
        TrainingSchedule.clearExpiredUpcomingWorkout(state: &state)

        if TrainingSchedule.isUpcomingWorkoutValid(state: state, profile: profile),
           let upcoming = state.upcomingWorkout {
            todayWorkout = upcoming
            try? await workoutRepository.saveTodayWorkout(upcoming)
            state.upcomingWorkout = nil
            state.upcomingWorkoutFor = nil
            if isSignedIn {
                try? await cloudSyncService.pushTodayWorkout(upcoming)
            }
        }

        programState = state
        try? await programStateRepository.saveState(state)
        if isSignedIn {
            try? await cloudSyncService.pushProgramState(state)
        }
    }

    func makeWorkoutGenerationInput(
        profile: UserProfile,
        splitDayFocus: SplitDayFocus?,
        options: WorkoutGenerationOptions = WorkoutGenerationOptions(),
        recentWorkouts: [WorkoutSessionSummary]? = nil,
        exerciseStats: [UserExerciseStats]? = nil,
        soreness: SorenessLevel? = nil
    ) async -> WorkoutGenerationInput {
        let summaries: [WorkoutSessionSummary]
        if let recentWorkouts {
            summaries = recentWorkouts
        } else {
            summaries = (try? await workoutRepository.fetchSessionSummaries()) ?? []
        }

        let stats: [UserExerciseStats]
        if let exerciseStats {
            stats = exerciseStats
        } else {
            stats = (try? await exerciseStatsRepository.fetchStats()) ?? []
        }

        let recovery = Dictionary(uniqueKeysWithValues: recoveryStates.map { ($0.muscleGroup, $0.recoveryPercentage) })
        let exercises = (try? await exerciseRepository.fetchAll()) ?? []
        let favoriteIds = exercises.filter(\.isFavorite).map(\.id)

        return WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: options.targetDurationMinutes ?? profile.preferredSessionLengthMinutes,
            preferredMuscleGroups: profile.preferredMuscleGroups ?? [],
            avoidedMuscleGroups: profile.avoidedMuscleGroups ?? [],
            injuries: profile.limitations,
            recentWorkouts: summaries,
            muscleRecovery: recovery,
            exerciseStats: stats,
            userPreferences: WorkoutPreferences(
                avoidExerciseIds: options.excludeExerciseIds,
                favoriteExerciseIds: favoriteIds,
                preferVariation: options.preferVariation
            ),
            readiness: ReadinessInput(
                sleepScore: healthReadiness.sleepScore,
                soreness: soreness ?? sorenessLevel
            ),
            splitDayFocus: splitDayFocus
        )
    }

    func generateWorkout(
        profile: UserProfile,
        splitDayFocus: SplitDayFocus?,
        options: WorkoutGenerationOptions = WorkoutGenerationOptions()
    ) async -> GeneratedWorkout? {
        let input = await makeWorkoutGenerationInput(
            profile: profile,
            splitDayFocus: splitDayFocus,
            options: options
        )

        guard let workout = try? await workoutGenerationService.generate(input: input) else { return nil }
        let validation = workoutGenerationService.validate(workout: workout, input: input)
        lastValidation = validation
        guard validation.isValid else { return nil }
        return workout
    }

    func pregenerateUpcomingWorkout(profile: UserProfile, state: TrainingProgramState) async {
        guard TrainingSchedule.nextTrainingDate(profile: profile) != nil else { return }

        let splitFocus = TrainingSchedule.currentSplitFocus(state: state, split: profile.preferredSplit)
        guard let workout = await generateWorkout(profile: profile, splitDayFocus: splitFocus) else { return }
        guard let nextDate = TrainingSchedule.nextTrainingDate(profile: profile) else { return }

        var updated = state
        updated.upcomingWorkout = workout
        updated.upcomingWorkoutFor = TrainingSchedule.startOfDay(nextDate)
        programState = updated
        try? await programStateRepository.saveState(updated)
    }

    func saveTodayWorkout(_ workout: GeneratedWorkout) async throws {
        todayWorkout = workout
        try await workoutRepository.saveTodayWorkout(workout)
        if isSignedIn {
            try? await cloudSyncService.pushTodayWorkout(workout)
        }
    }

    func cancelActiveWorkoutIfNeeded() async {
        guard let session = await fetchActiveWorkoutSession() else { return }
        await cancelWorkoutSession(session)
    }
}
