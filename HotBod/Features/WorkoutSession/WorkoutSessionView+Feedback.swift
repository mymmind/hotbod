import SwiftUI

private struct WatchSetDraft {
    var weight: Double?
    var secondary: Int
    var label: String
    var unit: String
    var nextSummary: String?
}

private struct WatchSecondaryMetric {
    var value: Int
    var label: String
}

extension WorkoutSessionView {
    func endRestTimer(skipped: Bool) {
        let endKind = restTimerKind
        if !skipped, restSecondsRemaining == 0 {
            feedback.play(.restTimerEnd(kind: RestTimerFeedbackPlanner.endKind(for: endKind)))
        }
        clearRestTimerState()
        environment.scheduleWorkoutSessionSave(session)
        if let target = pendingAdvanceExerciseIndex {
            pendingAdvanceExerciseIndex = nil
            shouldAdvanceExerciseAfterRest = false
            goToExercise(at: target)
        } else if shouldAdvanceExerciseAfterRest {
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

    func restorePendingGroupAdvance() {
        guard pendingAdvanceExerciseIndex == nil, shouldAdvanceExerciseAfterRest else { return }
        let anchor = newestGroupedCompletionIndex() ?? currentExerciseIndex
        guard session.exercises.indices.contains(anchor) else { return }
        let exercise = session.exercises[anchor]
        guard let last = exercise.completedSets.map(\.setIndex).max() else { return }
        pendingAdvanceExerciseIndex = SetAdvancePlanner.partnerIndex(
            exercises: session.exercises,
            exerciseIndex: anchor,
            completedSetIndex: last
        )
    }

    /// The grouped exercise that owns the latest logged set. A fresh view opens on the first
    /// incomplete member, which is often the partner the rest was heading toward.
    private func newestGroupedCompletionIndex() -> Int? {
        var best: (index: Int, date: Date)?
        for (index, exercise) in session.exercises.enumerated() {
            guard exercise.groupId != nil else { continue }
            guard let date = exercise.completedSets.map(\.completedAt).max() else { continue }
            if let best, date <= best.date { continue }
            best = (index, date)
        }
        return best?.index
    }

    func restoreRestTimerIfNeeded() {
        guard let end = session.activeRestEndAt else { return }
        shouldAdvanceExerciseAfterRest = session.activeRestAdvancesExercise ?? false
        restorePendingGroupAdvance()
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
            if pendingAdvanceExerciseIndex == nil {
                restorePendingGroupAdvance()
            }
            if let target = pendingAdvanceExerciseIndex {
                pendingAdvanceExerciseIndex = nil
                shouldAdvanceExerciseAfterRest = false
                goToExercise(at: target)
            } else if shouldAdvanceExerciseAfterRest {
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
                isResting: isResting,
                restEndsAt: restEndDate
            )
            return
        }
        let draft = watchDraft(for: exercise, meta: meta)
        PhoneWatchSessionBridge.publish(
            session: session,
            exerciseIndex: currentExerciseIndex,
            setIndex: watchSetIndex(for: exercise) ?? max(exercise.plannedSets.count - 1, 0),
            exerciseName: meta.name,
            restSecondsRemaining: isResting ? restSecondsRemaining : nil,
            isResting: isResting,
            restEndsAt: restEndDate,
            loggedWeightKg: draft.weight,
            secondaryValue: draft.secondary,
            secondaryLabel: draft.label,
            loadUnit: draft.unit,
            loadStep: meta.resolvedWeightDisplaySemantics.loadStep,
            nextSummary: draft.nextSummary
        )
    }

    func drainWatchCommands(showWeightInput: Bool) {
        while let command = PhoneWatchSessionBridge.consumeWatchCommand() {
            applyWatchCommand(command, showWeightInput: showWeightInput)
        }
    }

    func processWatchCommand(showWeightInput: Bool) {
        drainWatchCommands(showWeightInput: showWeightInput)
    }

    var watchShowsWeightInput: Bool {
        guard let exercise = currentExercise,
              let meta = exerciseMap[exercise.exerciseId] else { return false }
        return showWeightInput(for: exercise, meta: meta)
    }

    private var watchSetEditsAreStale: Bool {
        if showExerciseComplete || showCompletion { return true }
        guard let exercise = currentExercise else { return true }
        return WorkoutSessionCalculator.isExerciseComplete(exercise)
    }

    private func applyWatchCommand(_ command: WatchPendingCommand, showWeightInput: Bool) {
        switch command.action {
        case .startWorkout:
            return
        case .endWorkout:
            finishWorkout()
            return
        case .skipRest:
            if isResting {
                endRestTimer(skipped: true)
            }
            return
        default:
            break
        }
        guard !watchSetEditsAreStale else { return }
        guard let exercise = currentExercise,
              let meta = exerciseMap[exercise.exerciseId] else { return }
        switch command.action {
        case .completeSet:
            completeCurrentSet(exercise: exercise, meta: meta, showWeightInput: showWeightInput)
        case .increaseWeight:
            nudgeWatchLoad(exercise: exercise, meta: meta, delta: meta.resolvedWeightDisplaySemantics.loadStep)
        case .decreaseWeight:
            nudgeWatchLoad(exercise: exercise, meta: meta, delta: -meta.resolvedWeightDisplaySemantics.loadStep)
        case .increaseReps:
            nudgeWatchSecondary(exercise: exercise, meta: meta, delta: 1)
        case .decreaseReps:
            nudgeWatchSecondary(exercise: exercise, meta: meta, delta: -1)
        case .startWorkout, .endWorkout, .skipRest:
            break
        }
    }

    private func watchSetIndex(for exercise: WorkoutExercise) -> Int? {
        WorkoutSessionCalculator.firstIncompleteSetIndex(
            plannedCount: exercise.plannedSets.count,
            completedSetIndexes: Set(exercise.completedSets.map(\.setIndex))
        )
    }

    private func watchDraft(for exercise: WorkoutExercise, meta: Exercise) -> WatchSetDraft {
        let semantics = meta.resolvedWeightDisplaySemantics
        let unit = semantics == .resistanceLevel ? "lvl" : "kg"
        guard let index = watchSetIndex(for: exercise) else {
            return WatchSetDraft(weight: nil, secondary: 0, label: "reps", unit: unit, nextSummary: nil)
        }
        let planned = exercise.plannedSets[index]
        let completed = exercise.completedSets.first { $0.setIndex == index }
        let weight = Double(weightTexts[planned.id] ?? "")
            ?? completed?.weightKg
            ?? planned.targetWeightKg
        let secondary = watchSecondary(
            meta: meta,
            planned: planned,
            completed: completed
        )
        let nextIndex = WorkoutSessionCalculator.firstIncompleteSetIndex(
            plannedCount: exercise.plannedSets.count,
            completedSetIndexes: Set(exercise.completedSets.map(\.setIndex)).union([index])
        )
        let next = nextIndex.flatMap { exercise.plannedSets.indices.contains($0) ? exercise.plannedSets[$0] : nil }
        return WatchSetDraft(
            weight: weight,
            secondary: secondary.value,
            label: secondary.label,
            unit: unit,
            nextSummary: next.map { watchNextSummary($0, unit: unit, meta: meta) }
        )
    }

    private func watchSecondary(
        meta: Exercise,
        planned: PlannedSet,
        completed: CompletedSet?
    ) -> WatchSecondaryMetric {
        if usesDurationMetric(for: meta), !usesRepMetric(for: meta) {
            let seconds = Int(durationTexts[planned.id] ?? "")
                ?? completed?.durationSeconds
                ?? planned.targetDurationSeconds
                ?? 0
            return WatchSecondaryMetric(value: seconds, label: "sec")
        }
        if usesDistanceMetric(for: meta), !usesRepMetric(for: meta) {
            let meters = Int(distanceTexts[planned.id] ?? "")
                ?? completed?.distanceMeters.map { Int($0) }
                ?? planned.targetDistanceMeters.map { Int($0) }
                ?? 0
            return WatchSecondaryMetric(value: meters, label: "m")
        }
        let reps = Int(repsTexts[planned.id] ?? "")
            ?? completed?.reps
            ?? planned.targetRepsMin
        return WatchSecondaryMetric(value: reps, label: "reps")
    }

    private func watchNextSummary(_ planned: PlannedSet, unit: String, meta: Exercise) -> String {
        if usesDurationMetric(for: meta), !usesRepMetric(for: meta), let seconds = planned.targetDurationSeconds {
            if let weight = planned.targetWeightKg {
                return "Next \(formattedWatchLoad(weight, unit: unit)) · \(seconds) sec"
            }
            return "Next \(seconds) sec"
        }
        let reps = planned.isMaxEffort ? "\(planned.targetRepsMin)+" : "\(planned.targetRepsMin)–\(planned.targetRepsMax)"
        if let weight = planned.targetWeightKg {
            return "Next \(formattedWatchLoad(weight, unit: unit)) × \(reps)"
        }
        return "Next \(reps) reps"
    }

    private func formattedWatchLoad(_ value: Double, unit: String) -> String {
        let number = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        return unit == "lvl" ? "\(number) lvl" : "\(number) kg"
    }

    private func nudgeWatchLoad(exercise: WorkoutExercise, meta: Exercise, delta: Double) {
        guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }),
              let setIndex = watchSetIndex(for: exercise) else { return }
        let planned = session.exercises[idx].plannedSets[setIndex]
        let completed = session.exercises[idx].completedSets.first { $0.setIndex == setIndex }
        let current = Double(weightTexts[planned.id] ?? "")
            ?? completed?.weightKg
            ?? planned.targetWeightKg
            ?? 0
        let unit = meta.resolvedWeightDisplaySemantics == .resistanceLevel ? "lvl" : "kg"
        let next = WatchLoadAdjuster.adjustedLoad(current: current, delta: delta, unit: unit)
        weightTexts[planned.id] = WorkoutSessionMetricDrafts.formatWeightKg(next)
        if completed != nil {
            updateCompletedSet(exerciseId: exercise.id, setIndex: setIndex, weightKg: next)
        } else {
            session.exercises[idx].plannedSets[setIndex].targetWeightKg = next
            environment.scheduleWorkoutSessionSave(session)
        }
        syncWatchSnapshot()
    }

    private func nudgeWatchSecondary(exercise: WorkoutExercise, meta: Exercise, delta: Int) {
        guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }),
              let setIndex = watchSetIndex(for: exercise) else { return }
        let planned = session.exercises[idx].plannedSets[setIndex]
        let completed = session.exercises[idx].completedSets.first { $0.setIndex == setIndex }
        let current = watchSecondary(meta: meta, planned: planned, completed: completed)
        let step = current.label == "sec" ? 15 : (current.label == "m" ? 5 : 1)
        let next = WatchLoadAdjuster.adjustedSecondary(
            current: current.value,
            delta: delta * step,
            label: current.label
        )
        if current.label == "sec" {
            durationTexts[planned.id] = String(next)
            if completed != nil {
                updateCompletedSet(exerciseId: exercise.id, setIndex: setIndex, durationSeconds: next)
            } else {
                session.exercises[idx].plannedSets[setIndex].targetDurationSeconds = next
                environment.scheduleWorkoutSessionSave(session)
            }
        } else if current.label == "m" {
            distanceTexts[planned.id] = String(next)
            if completed != nil {
                updateCompletedSet(exerciseId: exercise.id, setIndex: setIndex, distanceMeters: Double(next))
            } else {
                session.exercises[idx].plannedSets[setIndex].targetDistanceMeters = Double(next)
                environment.scheduleWorkoutSessionSave(session)
            }
        } else {
            repsTexts[planned.id] = String(next)
            if completed != nil {
                updateCompletedSet(exerciseId: exercise.id, setIndex: setIndex, reps: next)
            } else {
                session.exercises[idx].plannedSets[setIndex].targetRepsMin = next
                if session.exercises[idx].plannedSets[setIndex].targetRepsMax < next {
                    session.exercises[idx].plannedSets[setIndex].targetRepsMax = next
                }
                environment.scheduleWorkoutSessionSave(session)
            }
        }
        syncWatchSnapshot()
    }

    func isPersonalRecord(
        exerciseId: String,
        completed: CompletedSet,
        showWeightInput: Bool
    ) -> Bool {
        guard !completed.isWarmup, showWeightInput, let weight = completed.weightKg, weight > 0 else { return false }
        let semantics = exerciseMap[exerciseId]?.resolvedWeightDisplaySemantics
            ?? ExerciseMetadataResolver.resolvedWeightDisplaySemantics(exerciseId: exerciseId)
        guard semantics.tracksExternalKilograms else { return false }
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
