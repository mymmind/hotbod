import Foundation

extension AppEnvironment {
    var hasActiveWorkoutSession: Bool {
        programState.activeSessionId != nil
    }

    func fetchActiveWorkoutSession() async -> WorkoutSession? {
        guard let id = programState.activeSessionId else { return nil }
        let sessions = (try? await workoutRepository.fetchSessions()) ?? []
        guard let session = sessions.first(where: { $0.id == id && $0.status == .inProgress }) else {
            await clearActiveWorkoutSession()
            return nil
        }
        return session
    }

    func setActiveWorkoutSession(_ session: WorkoutSession) async {
        var state = programState
        state.activeSessionId = session.id
        programState = state
        try? await programStateRepository.saveState(state)
        if isSignedIn {
            try? await cloudSyncService.pushProgramState(state)
        }
    }

    func clearActiveWorkoutSession() async {
        guard programState.activeSessionId != nil else { return }
        var state = programState
        state.activeSessionId = nil
        programState = state
        try? await programStateRepository.saveState(state)
        if isSignedIn {
            try? await cloudSyncService.pushProgramState(state)
        }
    }

    func resumeOrStartWorkout(from workout: GeneratedWorkout) async -> WorkoutSession? {
        guard let profile = userProfile else { return nil }

        if let existing = await fetchActiveWorkoutSession() {
            return existing
        }

        let splitFocus = workout.splitDayFocus
            ?? TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)

        let exercises = workout.exercises.map { planned in
            WorkoutExercise(
                exerciseId: planned.exerciseId,
                orderIndex: planned.orderIndex,
                plannedSets: planned.targetSets,
                restSeconds: planned.restSeconds
            )
        }
        let session = WorkoutSession(
            userId: profile.id,
            title: workout.title,
            startedAt: Date(),
            estimatedDurationMinutes: workout.estimatedDurationMinutes,
            exercises: exercises,
            status: .inProgress,
            splitDayFocus: splitFocus
        )
        try? await workoutRepository.saveSession(session)
        await setActiveWorkoutSession(session)
        return session
    }

    func pauseWorkoutSession(_ session: WorkoutSession) async {
        try? await saveWorkoutSessionImmediately(session)
        await setActiveWorkoutSession(session)
    }

    func cancelWorkoutSession(_ session: WorkoutSession) async {
        sessionSaveTask?.cancel()
        var updated = session
        updated.status = .cancelled
        updated.completedAt = Date()
        try? await workoutRepository.saveSession(updated)
        await clearActiveWorkoutSession()
    }

    func scheduleWorkoutSessionSave(_ session: WorkoutSession) {
        sessionSaveTask?.cancel()
        let snapshot = session
        sessionSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            try? await workoutRepository.saveSession(snapshot)
        }
    }

    func saveWorkoutSessionImmediately(_ session: WorkoutSession) async throws {
        sessionSaveTask?.cancel()
        try await workoutRepository.saveSession(session)
    }

    func applyWorkoutSessionCompletion(_ session: WorkoutSession) async -> [String] {
        let allExercises = (try? await exerciseRepository.fetchAll()) ?? []
        let map = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        let completed = session.exercises.compactMap { we -> (Exercise, [CompletedSet])? in
            guard let ex = map[we.exerciseId], !we.wasSkipped else { return nil }
            return (ex, we.completedSets)
        }
        var states = recoveryStates
        states = RecoveryCalculator.applyWorkoutFatigue(states: states, exercises: allExercises, completedSets: completed)
        recoveryStates = states
        try? await recoveryRepository.saveRecoveryStates(states)

        var stats = (try? await exerciseStatsRepository.fetchStats()) ?? []
        var notes: [String] = []
        let bodyweight = userProfile?.weightKg ?? 80
        let experience = userProfile?.experienceLevel ?? .intermediate
        let goal = userProfile?.goal
        for we in session.exercises where !we.wasSkipped {
            let exercise = map[we.exerciseId]
            let updated = ProgressiveOverload.updateStats(
                existing: stats.first { $0.exerciseId == we.exerciseId },
                exerciseId: we.exerciseId,
                completedSets: we.completedSets,
                plannedSets: we.plannedSets,
                bodyweightKg: bodyweight,
                experienceLevel: experience,
                goal: goal,
                equipment: exercise?.equipment ?? []
            )
            if let name = map[we.exerciseId]?.name, let next = updated.suggestedNextWeightKg {
                notes.append("\(name): try \(Int(next))kg next session.")
            }
            if let i = stats.firstIndex(where: { $0.exerciseId == we.exerciseId }) {
                stats[i] = updated
            } else {
                stats.append(updated)
            }
        }
        try? await exerciseStatsRepository.saveStats(stats)
        return notes
    }

    func refreshWorkoutAfterSession(_ session: WorkoutSession) async {
        guard let profile = userProfile else { return }

        var state = programState
        state.activeSessionId = nil
        state.todayCompletedSessionId = session.id
        state.todayCompletedOn = TrainingSchedule.startOfDay(Date())

        let todayStart = state.todayCompletedOn
        if !TrainingSchedule.rotationAlreadyAdvancedToday(state: state, on: todayStart ?? Date()) {
            TrainingSchedule.advanceRotationIfMatchingFocus(
                state: &state,
                split: profile.preferredSplit,
                completedFocus: session.splitDayFocus
            )
            state.todayRotationAdvancedOn = todayStart
        }
        programState = state
        try? await programStateRepository.saveState(state)

        if isSignedIn {
            try? await cloudSyncService.pushSession(session)
            try? await cloudSyncService.pushRecoveryStates(recoveryStates)
            if let stats = try? await exerciseStatsRepository.fetchStats() {
                try? await cloudSyncService.pushExerciseStats(stats)
            }
            try? await cloudSyncService.pushProgramState(programState)
        }
    }

    func fetchWorkoutSessions() async -> [WorkoutSession] {
        (try? await workoutRepository.fetchSessions()) ?? []
    }

    func fetchSessionSummaries() async -> [WorkoutSessionSummary] {
        (try? await workoutRepository.fetchSessionSummaries()) ?? []
    }
}
