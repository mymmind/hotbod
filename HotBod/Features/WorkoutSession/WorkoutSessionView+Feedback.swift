import SwiftUI

enum PendingPostSetAction: Equatable {
    case rest(seconds: Int, advanceAfter: Bool)
    case exerciseComplete
}

extension WorkoutSessionView {
    func endRestTimer(skipped: Bool) {
        if !skipped, restSecondsRemaining == 0 {
            feedback.play(.restTimerEnd)
        }
        clearRestTimerState()
        environment.scheduleWorkoutSessionSave(session)
        if shouldAdvanceExerciseAfterRest {
            shouldAdvanceExerciseAfterRest = false
            presentExerciseCompleteOrAdvance()
        }
        syncWatchSnapshot()
    }

    func handleRestTimerTick() {
        guard isResting else { return }

        if restSecondsRemaining == 0 {
            endRestTimer(skipped: false)
            return
        }

        if restSecondsRemaining == 10, !restWarningPlayed {
            restWarningPlayed = true
            feedback.play(.restTimerWarning)
        }

        syncWatchSnapshot()
    }

    func startRestTimer(seconds: Int) {
        let total = max(seconds, 1)
        restTotalSeconds = total
        restEndDate = Date().addingTimeInterval(TimeInterval(total))
        session.activeRestEndAt = restEndDate
        session.activeRestTotalSeconds = total
        session.activeRestAdvancesExercise = shouldAdvanceExerciseAfterRest
        restWarningPlayed = false
        feedback.prepare(for: .restTimerEnd)
        feedback.play(.restTimerStart)
        isResting = true
        environment.scheduleWorkoutSessionSave(session)
        syncWatchSnapshot()
    }

    func addRestTime(seconds: Int = 30) {
        guard isResting else { return }
        let base = restEndDate ?? Date()
        restEndDate = base.addingTimeInterval(TimeInterval(seconds))
        session.activeRestEndAt = restEndDate
        environment.scheduleWorkoutSessionSave(session)
        syncWatchSnapshot()
    }

    func restoreRestTimerIfNeeded() {
        guard let end = session.activeRestEndAt else { return }
        shouldAdvanceExerciseAfterRest = session.activeRestAdvancesExercise ?? false
        if end > Date() {
            restEndDate = end
            restTotalSeconds = session.activeRestTotalSeconds ?? max(1, Int(ceil(end.timeIntervalSince(Date()))))
            isResting = true
        } else {
            clearRestTimerState()
            environment.scheduleWorkoutSessionSave(session)
            if shouldAdvanceExerciseAfterRest {
                shouldAdvanceExerciseAfterRest = false
                presentExerciseCompleteOrAdvance()
            }
        }
    }

    func clearRestTimerState() {
        isResting = false
        restEndDate = nil
        restWarningPlayed = false
        session.activeRestEndAt = nil
        session.activeRestTotalSeconds = nil
        session.activeRestAdvancesExercise = nil
    }

    func clearPersistedRestState() {
        clearRestTimerState()
        shouldAdvanceExerciseAfterRest = false
    }

    var restSecondsRemaining: Int {
        guard let end = restEndDate else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSince(Date()))))
    }

    func executePostSetAction(_ action: PendingPostSetAction) {
        switch action {
        case let .rest(seconds, advanceAfter):
            shouldAdvanceExerciseAfterRest = advanceAfter
            startRestTimer(seconds: seconds)
        case .exerciseComplete:
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                presentExerciseCompleteOrAdvance()
            }
        }
    }

    func finishRIRPromptFlow() {
        showRIRPrompt = false
        rirPromptExerciseIndex = nil
        rirPromptSetIndex = nil
        guard let action = pendingPostSetAction else { return }
        pendingPostSetAction = nil
        executePostSetAction(action)
    }

    func syncWatchSnapshot() {
        guard let exercise = currentExercise,
              let meta = exerciseMap[exercise.exerciseId] else {
            PhoneWatchSessionBridge.publish(
                session: session,
                exerciseIndex: currentExerciseIndex,
                exerciseName: "—",
                restSecondsRemaining: isResting ? restSecondsRemaining : nil,
                isResting: isResting
            )
            return
        }
        PhoneWatchSessionBridge.publish(
            session: session,
            exerciseIndex: currentExerciseIndex,
            exerciseName: meta.name,
            restSecondsRemaining: isResting ? restSecondsRemaining : nil,
            isResting: isResting
        )
    }

    func processWatchCommand(showWeightInput: Bool) {
        guard let command = PhoneWatchSessionBridge.consumeWatchCommand() else { return }
        guard let exercise = currentExercise,
              let meta = exerciseMap[exercise.exerciseId] else { return }
        switch command.action {
        case .completeSet:
            completeCurrentSet(exercise: exercise, meta: meta, showWeightInput: showWeightInput)
        case .skipRest:
            if isResting {
                endRestTimer(skipped: true)
            }
        }
    }

    func isPersonalRecord(
        exerciseId: String,
        completed: CompletedSet,
        showWeightInput: Bool
    ) -> Bool {
        guard !completed.isWarmup, showWeightInput, let weight = completed.weightKg else { return false }
        let newE1RM = ProgressiveOverload.estimateOneRepMax(weight: weight, reps: completed.reps)
        let prior = exerciseStatsById[exerciseId]?.estimatedOneRepMax ?? 0
        return newE1RM > prior + 0.5
    }

    func flashCompletedSet(_ setId: UUID, isPR: Bool) {
        flashSetId = setId
        if isPR { prSetId = setId }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(isPR ? 700 : 450))
            if flashSetId == setId { flashSetId = nil }
            if prSetId == setId { prSetId = nil }
        }
    }
}
