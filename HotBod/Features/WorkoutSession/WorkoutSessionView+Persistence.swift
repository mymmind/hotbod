import SwiftUI

extension WorkoutSessionView {
    func persistWorkoutCompletion() async {
        try? await environment.saveWorkoutSessionImmediately(session)
        progressionNotes = await environment.applyWorkoutSessionCompletion(session)
        let sessions = await environment.fetchWorkoutSessions()
        completionWorkoutStreak = TrainingStreakCalculator.workoutStreak(sessions: sessions)
        feedback.play(.workoutComplete)
    }

    func finishWorkout() {
        showExerciseComplete = false
        showRIRPrompt = false
        showCompletion = true
        session.status = .completed
        session.completedAt = Date()
        clearPersistedRestState()
        pendingPostSetAction = nil
        Task { await persistWorkoutCompletion() }
    }

    func loadExercises() async {
        let used = Set(session.exercises.map(\.exerciseId))
        if UITestConfiguration.isUITesting {
            let all = await environment.fetchAllExercises()
            exerciseMap = ExerciseCatalog.indexedById(all)
            allExercises = all
            substitutionGroups = (try? await environment.exerciseRepository.fetchSubstitutionGroups()) ?? []
            swapResolver = await environment.loadExerciseSwapResolver(usedExerciseIds: used)
            let stats = await environment.fetchExerciseStats()
            exerciseStatsById = Dictionary(uniqueKeysWithValues: stats.map { ($0.exerciseId, $0) })
            for exerciseId in used where exerciseMap[exerciseId] == nil {
                if let exercise = ExerciseSeedLoader.load().first(where: { $0.id == exerciseId }) {
                    exerciseMap[exerciseId] = exercise
                }
            }
            sessionResourcesLoaded = true
            return
        }
        if let resolver = await environment.loadExerciseSwapResolver(usedExerciseIds: used) {
            swapResolver = resolver
            allExercises = resolver.allExercises
            substitutionGroups = resolver.substitutionGroups
            exerciseMap = resolver.exerciseMap
        }
        for exerciseId in used where exerciseMap[exerciseId] == nil {
            if let exercise = await environment.fetchExercise(id: exerciseId) {
                exerciseMap[exerciseId] = exercise
            }
        }
        let stats = await environment.fetchExerciseStats()
        exerciseStatsById = Dictionary(uniqueKeysWithValues: stats.map { ($0.exerciseId, $0) })
        sessionResourcesLoaded = true
    }
}
