// swiftlint:disable function_body_length
import SwiftUI

extension WorkoutSessionView {
    func swapGroup(for exerciseId: String) -> ExerciseSubstitutionGroup? {
        swapResolver?.substitutionGroup(for: exerciseId)
    }

    func swapCandidates(for exerciseId: String) -> [Exercise] {
        let used = Set(session.exercises.map(\.exerciseId))
        return swapResolver?.swapCandidates(for: exerciseId, workoutExerciseIds: used) ?? []
    }

    func canSwapExercise(at index: Int) -> Bool {
        guard session.exercises.indices.contains(index) else { return false }
        let exercise = session.exercises[index]
        guard !exercise.wasSkipped else { return false }
        return exercise.completedSets.isEmpty || index == currentExerciseIndex
    }

    @ViewBuilder
    func swapSheetContent(for target: SessionSwapTarget) -> some View {
        let exercise = session.exercises[target.index]
        SwapExerciseSheet(
            currentExerciseId: exercise.exerciseId,
            substitutionGroup: swapGroup(for: exercise.exerciseId),
            substitutes: swapCandidates(for: exercise.exerciseId)
        ) { substitute in
            swapExercise(at: target.index, to: substitute.id)
        }
    }

    func presentSwapSheet(for index: Int) {
        if !UITestConfiguration.isUITesting {
            guard canSwapExercise(at: index) else { return }
        }
        swapTarget = SessionSwapTarget(index: index)
    }

    func swapExercise(at index: Int, to newExerciseId: String) {
        guard session.exercises.indices.contains(index),
              let substitute = exerciseMap[newExerciseId] else { return }
        let existing = session.exercises[index]
        let experience = environment.userProfile?.experienceLevel ?? .intermediate
        let replannedSets = ExerciseSwapReplanner.replannedSets(
            preservingStructureFrom: existing.plannedSets,
            for: substitute,
            stats: exerciseStatsById[newExerciseId],
            bodyweightKg: bodyWeightKg,
            experience: experience,
            weightCeilings: environment.userProfile?.maxAvailableWeightKg ?? [:]
        )
        session.exercises[index] = WorkoutExercise(
            id: existing.id,
            exerciseId: newExerciseId,
            orderIndex: existing.orderIndex,
            plannedSets: replannedSets,
            completedSets: [],
            restSeconds: existing.restSeconds,
            groupId: existing.groupId
        )
        if index == currentExerciseIndex {
            weightTexts = [:]
            repsTexts = [:]
            pendingRpeBySetId = [:]
            durationTexts = [:]
            distanceTexts = [:]
            optionalLoadEnabledByExerciseId[existing.id] = false
        }
        feedback.play(.exerciseSwap)
        environment.scheduleWorkoutSessionSave(session)
        Task {
            await environment.syncTodayWorkoutExerciseSwap(
                orderIndex: existing.orderIndex,
                newExerciseId: newExerciseId,
                plannedSets: replannedSets
            )
        }
        swapTarget = nil
    }

    func completeCurrentSet(
        exercise: WorkoutExercise,
        meta: Exercise,
        showWeightInput: Bool
    ) {
        dismissKeyboard()
        guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let setIndex = session.exercises[idx].completedSets.count
        guard setIndex < session.exercises[idx].plannedSets.count else { return }
        let planned = session.exercises[idx].plannedSets[setIndex]
        let weight: Double? = showWeightInput
            ? (Double(weightTexts[planned.id] ?? "") ?? planned.targetWeightKg)
            : nil
        let reps = Int(repsTexts[planned.id] ?? "") ?? (planned.targetRepsMin > 0 ? planned.targetRepsMin : 1)
        let durationSeconds = Int(durationTexts[planned.id] ?? "")
            ?? planned.targetDurationSeconds
        let distanceMeters = Double(distanceTexts[planned.id] ?? "")
            ?? planned.targetDistanceMeters
        let loggedRPE = (planned.isWarmup || planned.isCooldown) ? nil : pendingRpeBySetId[planned.id]
        let needsRIRPrompt = !planned.isWarmup
            && !planned.isCooldown
            && usesRepMetric(for: meta)
            && loggedRPE == nil
        let completed = CompletedSet(
            setIndex: setIndex,
            weightKg: weight,
            reps: usesRepMetric(for: meta) ? reps : 0,
            rpe: loggedRPE,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            isWarmup: planned.isWarmup,
            isCooldown: planned.isCooldown
        )
        session.exercises[idx].completedSets.append(completed)
        pendingRpeBySetId.removeValue(forKey: planned.id)
        environment.scheduleWorkoutSessionSave(session)

        let isPR = isPersonalRecord(exerciseId: exercise.exerciseId, completed: completed, showWeightInput: showWeightInput)
        flashCompletedSet(planned.id, isPR: isPR)
        feedback.play(isPR ? .personalRecord : .setComplete)

        let allSetsDone = session.exercises[idx].completedSets.count >= session.exercises[idx].plannedSets.count
        let postAction = PostSetActionPlanner.action(
            allSetsDone: allSetsDone,
            isWarmup: planned.isWarmup,
            isCooldown: planned.isCooldown,
            exerciseRestSeconds: session.exercises[idx].restSeconds
        )

        if needsRIRPrompt {
            rirPromptExerciseIndex = idx
            rirPromptSetIndex = setIndex
            pendingPostSetAction = postAction
            showRIRPrompt = true
        } else {
            executePostSetAction(postAction)
        }
        syncWatchSnapshot()
    }

    func showWeightInput(for exercise: WorkoutExercise, meta: Exercise) -> Bool {
        let loadMode = meta.resolvedLoadTrackingMode
        let hasExternalLoadInHistory = exercise.completedSets.contains { $0.weightKg != nil }
            || exercise.plannedSets.contains(where: { $0.targetWeightKg != nil })
        let optionalEnabled = optionalLoadEnabledByExerciseId[exercise.id] ?? hasExternalLoadInHistory
        switch loadMode {
        case .none: return false
        case .optional: return optionalEnabled
        case .supported, .required: return true
        }
    }

    func canGroupWithNext(exercise: WorkoutExercise) -> Bool {
        let index = currentExerciseIndex
        guard index + 1 < session.exercises.count else { return false }
        let next = session.exercises[index + 1]
        guard exercise.groupId != next.groupId else { return false }
        guard let currentMeta = exerciseMap[exercise.exerciseId],
              let nextMeta = exerciseMap[next.exerciseId] else { return false }
        return ExerciseGroupPlanner.areCompatibleForGrouping(currentMeta, nextMeta)
    }

    func groupWithNextExercise() {
        ExerciseGroupPlanner.groupAdjacent(in: &session.exercises, at: currentExerciseIndex)
        environment.scheduleWorkoutSessionSave(session)
    }

    func ungroupCurrentExercise() {
        ExerciseGroupPlanner.ungroup(in: &session.exercises, at: currentExerciseIndex)
        environment.scheduleWorkoutSessionSave(session)
    }

    func addSet(exercise: WorkoutExercise) {
        guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let last = session.exercises[idx].plannedSets.last ?? PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        session.exercises[idx].plannedSets.append(last)
        environment.scheduleWorkoutSessionSave(session)
    }

    func skipExercise() {
        guard let idx = session.exercises.indices.contains(currentExerciseIndex) ? currentExerciseIndex : nil else { return }
        session.exercises[idx].wasSkipped = true
        clearPersistedRestState()
        environment.scheduleWorkoutSessionSave(session)
        advanceExercise()
    }

    func goToPreviousExercise() {
        goToExercise(at: currentExerciseIndex - 1)
    }

    func goToNextExercise() {
        goToExercise(at: currentExerciseIndex + 1)
    }

    func applyRIRSelection(_ rir: Int) {
        if let exerciseIdx = rirPromptExerciseIndex,
           let setIndex = rirPromptSetIndex,
           session.exercises.indices.contains(exerciseIdx),
           let completedIdx = session.exercises[exerciseIdx].completedSets.firstIndex(where: { $0.setIndex == setIndex }) {
            session.exercises[exerciseIdx].completedSets[completedIdx].rir = rir
            session.exercises[exerciseIdx].completedSets[completedIdx].rpe = EffortFeedbackMapping.rpe(fromRIR: rir)
            session.exercises[exerciseIdx].completedSets[completedIdx].isFailure = rir == 0
            environment.scheduleWorkoutSessionSave(session)
        }
        finishRIRPromptFlow()
    }

    func presentExerciseCompleteOrAdvance(playFeedback: Bool = true) {
        if playFeedback {
            feedback.play(.exerciseComplete)
        }
        withAnimation(ForgeMotion.standard) {
            showExerciseComplete = true
        }
    }

    func appendExercise(_ exercise: Exercise) {
        let profile = environment.userProfile
        let newExercise = SessionExercisePlanner.makeWorkoutExercise(
            exercise: exercise,
            orderIndex: session.exercises.count,
            experience: profile?.experienceLevel ?? .intermediate,
            goal: profile?.goal ?? .buildMuscle,
            bodyWeightKg: bodyWeightKg,
            stats: exerciseStatsById[exercise.id],
            weightCeilings: profile?.maxAvailableWeightKg ?? [:]
        )
        session.exercises.append(newExercise)
        exerciseMap[exercise.id] = exercise
        environment.scheduleWorkoutSessionSave(session)
        feedback.play(.exerciseSwap)
    }

    func goToExercise(at index: Int) {
        guard session.exercises.indices.contains(index) else { return }
        guard index != currentExerciseIndex else { return }
        dismissKeyboard()
        clearPersistedRestState()
        pendingPostSetAction = nil
        withAnimation(ForgeMotion.exercise) {
            currentExerciseIndex = index
            furthestExerciseIndex = max(furthestExerciseIndex, index)
            clearMetricTexts()
            showExerciseComplete = false
        }
        environment.scheduleWorkoutSessionSave(session)
    }

    func advanceExercise() {
        showExerciseComplete = false
        pendingPostSetAction = nil
        clearPersistedRestState()
        if currentExerciseIndex + 1 < session.exercises.count {
            withAnimation(ForgeMotion.exercise) {
                currentExerciseIndex += 1
                furthestExerciseIndex = max(furthestExerciseIndex, currentExerciseIndex)
                clearMetricTexts()
            }
        } else {
            finishWorkout()
        }
    }
}
