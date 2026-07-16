import SwiftUI

enum PendingPostSetAction: Equatable {
    case rest(seconds: Int, advanceAfter: Bool)
    case exerciseComplete
}

extension WorkoutSessionView {
    func endRestTimer(skipped: Bool) {
        let endKind = restTimerKind
        if !skipped, restSecondsRemaining == 0 {
            feedback.play(.restTimerEnd(kind: RestTimerFeedbackPlanner.endKind(for: endKind)))
        }
        clearRestTimerState()
        environment.scheduleWorkoutSessionSave(session)
        if shouldAdvanceExerciseAfterRest {
            shouldAdvanceExerciseAfterRest = false
            presentExerciseCompleteOrAdvance(playFeedback: endKind != .transitionRest)
        }
        syncWatchSnapshot()
    }

    func handleRestTimerTick() {
        guard isResting else { return }

        if restSecondsRemaining == 0 {
            endRestTimer(skipped: false)
            return
        }

        if let cue = RestTimerFeedbackPlanner.pendingCue(
            secondsRemaining: restSecondsRemaining,
            totalSeconds: max(restTotalSeconds, 1),
            timerKind: restTimerKind,
            played: restFeedbackCuesPlayed
        ) {
            restFeedbackCuesPlayed.insert(cue)
            feedback.play(feedbackEvent(for: cue))
        }

        syncWatchSnapshot()
    }

    func startRestTimer(seconds: Int) {
        let total = max(seconds, 1)
        restTotalSeconds = total
        restTimerKind = RestTimerFeedbackPlanner.timerKind(
            advancesExercise: shouldAdvanceExerciseAfterRest,
            totalSeconds: total
        )
        restEndDate = Date().addingTimeInterval(TimeInterval(total))
        session.activeRestEndAt = restEndDate
        session.activeRestTotalSeconds = total
        session.activeRestAdvancesExercise = shouldAdvanceExerciseAfterRest
        restFeedbackCuesPlayed = []
        feedback.prepare(for: .restTimerEnd(kind: RestTimerFeedbackPlanner.endKind(for: restTimerKind)))
        feedback.play(.restTimerStart)
        isResting = true
        environment.scheduleWorkoutSessionSave(session)
        syncWatchSnapshot()
    }

    func addRestTime(seconds: Int = 30) {
        guard isResting else { return }
        let base = restEndDate ?? Date()
        restEndDate = base.addingTimeInterval(TimeInterval(seconds))
        restTotalSeconds += seconds
        restTimerKind = RestTimerFeedbackPlanner.timerKind(
            advancesExercise: shouldAdvanceExerciseAfterRest,
            totalSeconds: max(restTotalSeconds, 1)
        )
        session.activeRestEndAt = restEndDate
        session.activeRestTotalSeconds = restTotalSeconds
        environment.scheduleWorkoutSessionSave(session)
        syncWatchSnapshot()
    }

    func restoreRestTimerIfNeeded() {
        guard let end = session.activeRestEndAt else { return }
        shouldAdvanceExerciseAfterRest = session.activeRestAdvancesExercise ?? false
        if end > Date() {
            restEndDate = end
            restTotalSeconds = session.activeRestTotalSeconds ?? max(1, Int(ceil(end.timeIntervalSince(Date()))))
            restTimerKind = RestTimerFeedbackPlanner.timerKind(
                advancesExercise: shouldAdvanceExerciseAfterRest,
                totalSeconds: max(restTotalSeconds, 1)
            )
            restFeedbackCuesPlayed = RestTimerFeedbackPlanner.cuesToMarkSkipped(
                afterResumingWith: restSecondsRemaining,
                totalSeconds: max(restTotalSeconds, 1),
                timerKind: restTimerKind
            )
            isResting = true
        } else {
            let expiredKind = RestTimerFeedbackPlanner.timerKind(
                advancesExercise: shouldAdvanceExerciseAfterRest,
                totalSeconds: session.activeRestTotalSeconds ?? 0
            )
            feedback.play(.restTimerEnd(kind: RestTimerFeedbackPlanner.endKind(for: expiredKind)))
            clearRestTimerState()
            environment.scheduleWorkoutSessionSave(session)
            if shouldAdvanceExerciseAfterRest {
                shouldAdvanceExerciseAfterRest = false
                presentExerciseCompleteOrAdvance(playFeedback: expiredKind != .transitionRest)
            }
        }
    }

    func clearRestTimerState() {
        isResting = false
        restEndDate = nil
        restFeedbackCuesPlayed = []
        restTimerKind = .setRest
        session.activeRestEndAt = nil
        session.activeRestTotalSeconds = nil
        session.activeRestAdvancesExercise = nil
    }

    func clearPersistedRestState() {
        clearRestTimerState()
        shouldAdvanceExerciseAfterRest = false
    }

    var restSecondsRemaining: Int {
        restSecondsRemaining(at: Date())
    }

    func restSecondsRemaining(at date: Date) -> Int {
        guard let end = restEndDate else { return 0 }
        return WorkoutSessionCalculator.restSecondsRemaining(until: end, at: date)
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

    private func feedbackEvent(for cue: RestTimerFeedbackCue) -> ForgeFeedbackEvent {
        switch cue {
        case .tenSecondWarning:
            return .restTimerWarning
        case let .countdown(second):
            return .restTimerCountdown(second: second)
        }
    }
}
