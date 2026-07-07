import Foundation

struct CoachAIResult {
    var message: CoachMessage
    var proposedWorkout: GeneratedWorkout?
    var validation: WorkoutValidationResult?
    var droppedExerciseIds: [String] = []
}

struct RemoteCoachResponse: Codable {
    let intent: String
    let content: String
    let proposedWorkout: AIWorkoutPayload?
    let safetyNotes: [String]
    let validation: WorkoutValidationResult?
}

struct AIWorkoutPayload: Codable {
    let title: String
    let estimatedDurationMinutes: Int
    let focus: [String]
    let exercises: [AIPlannedExercisePayload]
    let rationale: String
    let safetyNotes: [String]
}

struct AIPlannedExercisePayload: Codable {
    let exerciseId: String
    let reason: String?
    let restSeconds: Int?
    let sets: [AIPlannedSetPayload]
}

struct AIPlannedSetPayload: Codable {
    let targetRepsMin: Int
    let targetRepsMax: Int
    let targetWeightKg: Double?
    let rpeTarget: Double?
}

struct CoachInvokeRequest: Codable {
    let message: String
    let context: CoachContext
}

struct AIWorkoutMappingResult {
    let workout: GeneratedWorkout
    let droppedExerciseIds: [String]
}

enum AIWorkoutPayloadMapper {
    static func map(
        _ payload: AIWorkoutPayload,
        catalog: [Exercise] = ExerciseSeedLoader.load(),
        aliasIndex: [String: String]? = nil
    ) -> AIWorkoutMappingResult {
        let catalogIds = Set(catalog.map(\.id))
        let aliases = aliasIndex ?? ExerciseCatalogLoader.loadAliasIndex()
        var dropped: [String] = []
        var mappedExercises: [(AIPlannedExercisePayload, String)] = []

        for exercise in payload.exercises {
            if let canonical = ExerciseIdResolver.canonicalId(
                exercise.exerciseId,
                catalog: catalogIds,
                aliasIndex: aliases
            ) {
                mappedExercises.append((exercise, canonical))
            } else {
                dropped.append(exercise.exerciseId)
            }
        }

        let workout = GeneratedWorkout(
            id: UUID(),
            title: payload.title,
            estimatedDurationMinutes: payload.estimatedDurationMinutes,
            focus: payload.focus.compactMap { MuscleGroup(rawValue: $0) },
            exercises: mappedExercises.enumerated().map { index, item in
                let (exercise, canonicalId) = item
                return PlannedExercise(
                    exerciseId: canonicalId,
                    orderIndex: index,
                    targetSets: exercise.sets.map {
                        PlannedSet(
                            targetRepsMin: $0.targetRepsMin,
                            targetRepsMax: $0.targetRepsMax,
                            targetWeightKg: $0.targetWeightKg,
                            rpeTarget: $0.rpeTarget
                        )
                    },
                    restSeconds: exercise.restSeconds ?? 90,
                    reason: exercise.reason ?? ""
                )
            },
            rationale: payload.rationale,
            safetyNotes: payload.safetyNotes,
            generatedBy: .aiAssisted,
            createdAt: Date()
        )

        return AIWorkoutMappingResult(workout: workout, droppedExerciseIds: dropped)
    }

    static func toGeneratedWorkout(
        _ payload: AIWorkoutPayload,
        catalog: [Exercise] = ExerciseSeedLoader.load()
    ) -> GeneratedWorkout {
        map(payload, catalog: catalog).workout
    }
}
