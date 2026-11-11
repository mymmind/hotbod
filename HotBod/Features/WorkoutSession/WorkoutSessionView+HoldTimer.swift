import SwiftUI

extension WorkoutSessionView {
    var activeHoldCountdown: HoldCountdown? {
        guard
            let endsAt = session.activeHoldEndsAt,
            let target = session.activeHoldTargetSeconds,
            let plannedSetId = session.activeHoldPlannedSetId,
            let exerciseId = session.activeHoldExerciseId,
            let setIndex = session.activeHoldSetIndex
        else { return nil }
        return HoldCountdown(
            plannedSetId: plannedSetId,
            workoutExerciseId: exerciseId,
            setIndex: setIndex,
            targetSeconds: target,
            endsAt: endsAt
        )
    }

    func holdSecondsRemaining(at date: Date = Date()) -> Int {
        activeHoldCountdown?.remaining(at: date) ?? 0
    }

    func clearHoldTimerState() {
        isHoldRunning = false
        session.activeHoldEndsAt = nil
        session.activeHoldTargetSeconds = nil
        session.activeHoldPlannedSetId = nil
        session.activeHoldExerciseId = nil
        session.activeHoldSetIndex = nil
    }

    func persistHoldState(_ hold: HoldCountdown?) {
        if let hold {
            session.activeHoldEndsAt = hold.endsAt
            session.activeHoldTargetSeconds = hold.targetSeconds
            session.activeHoldPlannedSetId = hold.plannedSetId
            session.activeHoldExerciseId = hold.workoutExerciseId
            session.activeHoldSetIndex = hold.setIndex
            isHoldRunning = true
        } else {
            clearHoldTimerState()
        }
        environment.scheduleWorkoutSessionSave(session)
    }

    func canOfferHoldStart(for exercise: WorkoutExercise, meta: Exercise) -> Bool {
        guard !isResting, !isHoldRunning else { return false }
        guard usesDurationMetric(for: meta) else { return false }
        return WorkoutSessionCalculator.firstIncompleteSetIndex(
            plannedCount: exercise.plannedSets.count,
            completedSetIndexes: Set(exercise.completedSets.map(\.setIndex))
        ) != nil
    }

    func startHoldForCurrentExercise() {
        guard let exercise = currentExercise,
              let meta = exerciseMap[exercise.exerciseId]
        else { return }
        startHoldTimer(for: exercise, meta: meta)
    }

    func startHoldTimer(for exercise: WorkoutExercise, meta: Exercise) {
        guard canOfferHoldStart(for: exercise, meta: meta) else { return }
        guard let setIndex = WorkoutSessionCalculator.firstIncompleteSetIndex(
            plannedCount: exercise.plannedSets.count,
            completedSetIndexes: Set(exercise.completedSets.map(\.setIndex))
        ) else { return }
        let planned = exercise.plannedSets[setIndex]
        let resolution = HoldCountdownTarget.resolve(
            draft: durationTexts[planned.id],
            plannedSeconds: planned.targetDurationSeconds,
            exerciseDefault: ExerciseMetadataResolver.defaultDurationSeconds(for: meta)
        )
        guard case .seconds(let target) = resolution else { return }

        clearPersistedRestState()
        let hold = HoldCountdown.starting(
            plannedSetId: planned.id,
            workoutExerciseId: exercise.id,
            setIndex: setIndex,
            targetSeconds: target
        )
        persistHoldState(hold)
        feedback.play(.buttonPress)
    }

    func stopHoldTimer() {
        guard let hold = activeHoldCountdown else { return }
        applyHoldOutcome(hold.outcome(at: Date()), hold: hold)
    }

    func handleHoldTimerTick() {
        guard let hold = activeHoldCountdown else { return }
        if hold.remaining(at: Date()) == 0 {
            applyHoldOutcome(.commit(seconds: hold.targetSeconds), hold: hold)
        }
    }

    func restoreHoldTimerIfNeeded() {
        guard
            let endsAt = session.activeHoldEndsAt,
            let target = session.activeHoldTargetSeconds,
            let plannedSetId = session.activeHoldPlannedSetId,
            let exerciseId = session.activeHoldExerciseId,
            let setIndex = session.activeHoldSetIndex
        else { return }

        guard let exerciseIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              session.exercises[exerciseIdx].plannedSets.indices.contains(setIndex),
              session.exercises[exerciseIdx].plannedSets[setIndex].id == plannedSetId
        else {
            clearHoldTimerState()
            environment.scheduleWorkoutSessionSave(session)
            return
        }

        if session.exercises[exerciseIdx].completedSets.contains(where: { $0.setIndex == setIndex }) {
            clearHoldTimerState()
            environment.scheduleWorkoutSessionSave(session)
            return
        }

        let hold = HoldCountdown(
            plannedSetId: plannedSetId,
            workoutExerciseId: exerciseId,
            setIndex: setIndex,
            targetSeconds: target,
            endsAt: endsAt
        )

        if endsAt <= Date() {
            applyHoldOutcome(.commit(seconds: target), hold: hold)
        } else {
            isHoldRunning = true
        }
    }

    private func applyHoldOutcome(_ outcome: HoldCommitOutcome, hold: HoldCountdown) {
        switch outcome {
        case .cancel:
            clearHoldTimerState()
            environment.scheduleWorkoutSessionSave(session)
        case .commit(let seconds):
            clearHoldTimerState()
            var nextDurations = durationTexts
            nextDurations[hold.plannedSetId] = String(seconds)
            durationTexts = nextDurations

            guard let exercise = session.exercises.first(where: { $0.id == hold.workoutExerciseId }),
                  let meta = exerciseMap[exercise.exerciseId]
            else {
                environment.scheduleWorkoutSessionSave(session)
                return
            }

            let showWeight = showWeightInput(for: exercise, meta: meta)
            completeCurrentSet(
                exercise: exercise,
                meta: meta,
                showWeightInput: showWeight,
                preferredSetIndex: hold.setIndex
            )
        }
    }

    @ViewBuilder
    func holdTimerBar(exercise: WorkoutExercise, meta: Exercise) -> some View {
        if isResting {
            EmptyView()
        } else if isHoldRunning, let hold = activeHoldCountdown {
            let runningName: String? = {
                if hold.workoutExerciseId == exercise.id { return nil }
                return exerciseMap[session.exercises.first(where: { $0.id == hold.workoutExerciseId })?.exerciseId ?? ""]?.name
            }()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ForgeHoldTimerBar(
                    secondsRemaining: hold.remaining(at: context.date),
                    totalSeconds: hold.targetSeconds,
                    exerciseName: runningName,
                    isRunning: true,
                    onStart: {},
                    onStop: { stopHoldTimer() }
                )
            }
            .transition(ForgeMotion.slideUp)
        } else if canOfferHoldStart(for: exercise, meta: meta) {
            let setIndex = WorkoutSessionCalculator.firstIncompleteSetIndex(
                plannedCount: exercise.plannedSets.count,
                completedSetIndexes: Set(exercise.completedSets.map(\.setIndex))
            )
            let planned = setIndex.map { exercise.plannedSets[$0] }
            let target: Int = {
                guard let planned else { return ExerciseMetadataResolver.defaultDurationSeconds(for: meta) }
                switch HoldCountdownTarget.resolve(
                    draft: durationTexts[planned.id],
                    plannedSeconds: planned.targetDurationSeconds,
                    exerciseDefault: ExerciseMetadataResolver.defaultDurationSeconds(for: meta)
                ) {
                case .seconds(let value): return value
                case .blocked: return planned.targetDurationSeconds
                    ?? ExerciseMetadataResolver.defaultDurationSeconds(for: meta)
                }
            }()
            ForgeHoldTimerBar(
                secondsRemaining: target,
                totalSeconds: max(target, 1),
                exerciseName: nil,
                isRunning: false,
                onStart: { startHoldForCurrentExercise() },
                onStop: {}
            )
            .transition(ForgeMotion.slideUp)
        }
    }
}
