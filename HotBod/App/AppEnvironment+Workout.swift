import Foundation

extension AppEnvironment {
    @discardableResult
    func regenerateTodayWorkout(profile: UserProfile, options: WorkoutGenerationOptions = WorkoutGenerationOptions()) async -> Bool {
        let onRestDay = !TrainingSchedule.isTrainingDay(profile: profile)
        return await regenerateTodayWorkout(
            profile: profile,
            options: options,
            allowsUnscheduledDay: onRestDay && todayWorkout != nil,
            requiresProAccess: !onRestDay
        )
    }

    /// Initial plan creation on launch/onboarding — does not consume free regeneration quota.
    @discardableResult
    func ensureTodayWorkoutOnLaunch(profile: UserProfile) async -> Bool {
        await regenerateTodayWorkout(
            profile: profile,
            options: WorkoutGenerationOptions(),
            allowsUnscheduledDay: false,
            requiresProAccess: false
        )
    }

    func cancelWorkoutGenerationIfNeeded() {
        workoutGenerationToken &+= 1
        isWorkoutGenerationActive = false
    }

    func seedUITestTodayWorkoutIfNeeded(force: Bool = false) async {
        guard UITestConfiguration.isUITesting else { return }
        guard force || todayWorkout == nil else { return }
        let workout = GeneratedWorkout(
            id: UUID(),
            title: "UI Test Workout",
            estimatedDurationMinutes: 45,
            focus: [.chest],
            exercises: [
                PlannedExercise(
                    exerciseId: "bench_press",
                    orderIndex: 0,
                    targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)],
                    restSeconds: 90
                ),
                PlannedExercise(
                    exerciseId: "dumbbell_press",
                    orderIndex: 1,
                    targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 24)],
                    restSeconds: 90
                ),
                PlannedExercise(
                    exerciseId: "cable_fly",
                    orderIndex: 2,
                    targetSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 12, targetWeightKg: 15)],
                    restSeconds: 60
                )
            ],
            rationale: "UI test seed",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: Date()
        )
        todayWorkout = workout
        try? await workoutRepository.saveTodayWorkout(workout)
    }

    @discardableResult
    func generateTodayWorkoutOnRestDay(
        profile: UserProfile,
        options: WorkoutGenerationOptions = WorkoutGenerationOptions()
    ) async -> Bool {
        await regenerateTodayWorkout(
            profile: profile,
            options: options,
            allowsUnscheduledDay: true,
            requiresProAccess: false
        )
    }

    /// Rebuilds today's plan after readiness input changes (e.g. soreness).
    @discardableResult
    func refreshTodayWorkoutForReadinessChange(profile: UserProfile) async -> Bool {
        guard !isTodayWorkoutCompleted else { return false }
        if isRestDay {
            guard todayWorkout != nil else { return false }
            return await generateTodayWorkoutOnRestDay(profile: profile)
        }
        return await regenerateTodayWorkout(profile: profile)
    }

    private func regenerateTodayWorkout(
        profile: UserProfile,
        options: WorkoutGenerationOptions,
        allowsUnscheduledDay: Bool,
        requiresProAccess: Bool
    ) async -> Bool {
        guard allowsUnscheduledDay
            || TrainingSchedule.isTrainingDay(profile: profile)
            || todayWorkout != nil else { return false }
        guard !isTodayWorkoutCompleted else { return false }
        guard reserveWorkoutGeneration() else { return false }
        defer { releaseWorkoutGenerationReservation() }

        if requiresProAccess {
            guard canAccess(.unlimitedGeneration) else {
                presentPaywall(for: .unlimitedGeneration)
                return false
            }
        }

        await cancelActiveWorkoutIfNeeded()
        await applyRecoveryDecay()

        let splitFocus = TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)
        var effectiveOptions = options
        if effectiveOptions.excludeExerciseIds.isEmpty,
           let current = todayWorkout,
           TrainingSchedule.isTrainingDay(profile: profile) {
            effectiveOptions.excludeExerciseIds = current.exercises.map(\.exerciseId)
            effectiveOptions.preferVariation = true
        }

        if await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: effectiveOptions
        ) {
            if requiresProAccess, !isPro { await recordRegenerationUsage() }
            return true
        }

        guard !effectiveOptions.excludeExerciseIds.isEmpty else { return false }

        var fallbackOptions = options
        fallbackOptions.excludeExerciseIds = []
        fallbackOptions.preferVariation = true
        if await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: fallbackOptions
        ) {
            if requiresProAccess, !isPro { await recordRegenerationUsage() }
            return true
        }
        return false
    }

    /// Clears "today completed" state and generates a fresh plan for the same day.
    /// Useful for "restart training" / "redo session" UX.
    @discardableResult
    func restartTodayWorkout(profile: UserProfile, options: WorkoutGenerationOptions = WorkoutGenerationOptions()) async -> Bool {
        guard TrainingSchedule.isTrainingDay(profile: profile) else { return false }
        guard reserveWorkoutGeneration() else { return false }
        defer { releaseWorkoutGenerationReservation() }

        await cancelActiveWorkoutIfNeeded()
        await applyRecoveryDecay()

        let splitFocus = TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)
        var effectiveOptions = options

        // Exclude the currently displayed workout exercises to encourage swaps.
        if effectiveOptions.excludeExerciseIds.isEmpty, let current = todayWorkout {
            effectiveOptions.excludeExerciseIds = current.exercises.map(\.exerciseId)
            effectiveOptions.preferVariation = true
        }

        if await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: effectiveOptions
        ) {
            return await clearTodayCompletionMarkers()
        }

        // If excluding the previous exercises was too strict, retry without exclusions.
        guard !effectiveOptions.excludeExerciseIds.isEmpty else { return false }
        var fallbackOptions = options
        fallbackOptions.excludeExerciseIds = []
        fallbackOptions.preferVariation = true
        guard await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: fallbackOptions
        ) else { return false }

        return await clearTodayCompletionMarkers()
    }

    @discardableResult
    func switchTodaySplitFocus() async -> Bool {
        guard let profile = userProfile,
              TrainingSchedule.isTrainingDay(profile: profile) else { return false }
        guard reserveWorkoutGeneration() else { return false }
        defer { releaseWorkoutGenerationReservation() }

        await cancelActiveWorkoutIfNeeded()
        await applyRecoveryDecay()

        var proposedState = programState
        let wasCompleted = TrainingSchedule.isTodayWorkoutCompleted(state: proposedState)
        TrainingSchedule.toggleSplitFocus(state: &proposedState, split: profile.preferredSplit)
        let splitFocus = TrainingSchedule.currentSplitFocus(state: proposedState, split: profile.preferredSplit)

        var options = WorkoutGenerationOptions()
        options.preferVariation = true
        if let current = todayWorkout {
            options.excludeExerciseIds = current.exercises.map(\.exerciseId)
        }

        if await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: options
        ) {
            return await applySplitFocusChange(proposedState, clearCompletion: wasCompleted)
        }

        guard !options.excludeExerciseIds.isEmpty else { return false }

        var fallbackOptions = WorkoutGenerationOptions()
        fallbackOptions.preferVariation = true
        guard await persistRegeneratedWorkout(
            profile: profile,
            splitDayFocus: splitFocus,
            options: fallbackOptions
        ) else { return false }

        return await applySplitFocusChange(proposedState, clearCompletion: wasCompleted)
    }

    @discardableResult
    private func clearTodayCompletionMarkers() async -> Bool {
        guard TrainingSchedule.isTodayWorkoutCompleted(state: programState) else { return true }

        var state = programState
        state.todayCompletedSessionId = nil
        state.todayCompletedOn = nil
        programState = state
        try? await programStateRepository.saveState(state)
        if isSignedIn {
            try? await cloudSyncService.pushProgramState(state)
        }
        return true
    }

    @discardableResult
    private func applySplitFocusChange(_ state: TrainingProgramState, clearCompletion: Bool) async -> Bool {
        var updated = state
        if clearCompletion {
            updated.todayCompletedSessionId = nil
            updated.todayCompletedOn = nil
        }
        programState = updated
        try? await programStateRepository.saveState(updated)
        if isSignedIn {
            try? await cloudSyncService.pushProgramState(updated)
        }
        return true
    }

    func persistRegeneratedWorkout(
        profile: UserProfile,
        splitDayFocus: SplitDayFocus?,
        options: WorkoutGenerationOptions
    ) async -> Bool {
        guard let workout = await generateWorkout(profile: profile, splitDayFocus: splitDayFocus, options: options) else {
            return false
        }
        guard !Task.isCancelled else { return false }

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
        let before = programState
        var state = programState
        TrainingSchedule.clearStaleCompletion(state: &state)
        TrainingSchedule.clearLegacyUpcomingWorkout(state: &state)
        guard state != before else { return }

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
            stats = exerciseStats.filter { !$0.isOrphaned }
        } else {
            stats = ((try? await exerciseStatsRepository.fetchStats()) ?? []).filter { !$0.isOrphaned }
        }

        let effectiveSoreness = soreness ?? sorenessLevel
        let recentlyTrained = Set(summaries.prefix(2).flatMap(\.muscleGroups))
        let sorenessAdjustedStates = RecoveryCalculator.applySoreness(
            states: recoveryStates,
            level: effectiveSoreness,
            recentlyTrainedMuscles: recentlyTrained
        )
        let recovery = RecoveryCalculator.recoveryMap(from: sorenessAdjustedStates)
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
                exerciseVariability: options.preferVariation ? .varied : profile.preferredExerciseVariability
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
        workoutGenerationToken &+= 1
        let token = workoutGenerationToken
        isWorkoutGenerationActive = true
        defer {
            if token == workoutGenerationToken {
                isWorkoutGenerationActive = false
            }
        }

        guard !Task.isCancelled else { return nil }

        lastGenerationFailure = nil
        let input = await makeWorkoutGenerationInput(
            profile: profile,
            splitDayFocus: splitDayFocus,
            options: options
        )
        guard !Task.isCancelled, token == workoutGenerationToken else { return nil }

        do {
            let workout = try await workoutGenerationService.generate(input: input)
            guard !Task.isCancelled, token == workoutGenerationToken else { return nil }
            let validation = workoutGenerationService.validate(workout: workout, input: input)
            lastValidation = validation
            guard validation.isValid else {
                lastGenerationFailure = .planValidationFailed(
                    summary: validation.errors.first ?? "Generated workout did not pass safety checks."
                )
                return nil
            }
            return workout
        } catch let failure as GenerationFailure {
            guard token == workoutGenerationToken else { return nil }
            lastGenerationFailure = failure
            lastValidation = nil
            return nil
        } catch {
            guard token == workoutGenerationToken else { return nil }
            lastValidation = nil
            return nil
        }
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

    @discardableResult
    func reserveWorkoutGeneration() -> Bool {
        guard !isReservingWorkoutGeneration else { return false }
        isReservingWorkoutGeneration = true
        return true
    }

    func releaseWorkoutGenerationReservation() {
        isReservingWorkoutGeneration = false
    }
}
