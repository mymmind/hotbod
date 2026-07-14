import Foundation

enum SessionExercisePlanner {
    static func makeWorkoutExercise(
        exercise: Exercise,
        orderIndex: Int,
        experience: ExperienceLevel,
        goal: TrainingGoal,
        bodyWeightKg: Double,
        stats: UserExerciseStats?,
        weightCeilings: [Equipment: Double] = [:]
    ) -> WorkoutExercise {
        let prescription = exercise.resolvedPrescriptionType
        let repRange = ExercisePrescriptionOverrides.effectiveRepRange(
            exerciseId: exercise.id,
            stats: stats,
            goal: goal,
            experience: experience
        )
        let setCount = max(1, ExercisePrescriptionOverrides.effectiveSetCount(
            exerciseId: exercise.id,
            experience: experience,
            pattern: exercise.movementPattern
        ))
        let restSeconds = ExercisePrescriptionOverrides.effectiveRestSeconds(
            exerciseId: exercise.id,
            goal: goal,
            mechanics: exercise.resolvedMechanics
        )
        let rpeTarget = ExercisePrescriptionOverrides.effectiveRPETarget(
            exerciseId: exercise.id,
            fallback: 8
        )

        var weight = stats?.planningWeightKg
            ?? ProgressiveOverload.suggestedStartWeight(
                for: exercise,
                bodyweight: bodyWeightKg,
                experience: experience
            )
        weight = GenerationConstants.Weight.roundToAvailable(
            weight,
            equipment: exercise.equipment,
            ceilings: weightCeilings
        )
        let loadMode = exercise.resolvedLoadTrackingMode
        let plannedWeight: Double? = loadMode.allowsExternalLoadPlanning ? weight : nil

        let sets = (0..<setCount).map { _ in
            plannedSet(
                prescription: prescription,
                exercise: exercise,
                minReps: repRange.min,
                maxReps: repRange.max,
                plannedWeight: plannedWeight,
                rpeTarget: rpeTarget
            )
        }

        return WorkoutExercise(
            exerciseId: exercise.id,
            orderIndex: orderIndex,
            plannedSets: sets,
            restSeconds: restSeconds
        )
    }

    static func makePlannedExercise(
        exercise: Exercise,
        orderIndex: Int,
        experience: ExperienceLevel,
        goal: TrainingGoal,
        bodyWeightKg: Double,
        stats: UserExerciseStats?,
        weightCeilings: [Equipment: Double] = [:]
    ) -> PlannedExercise {
        let workoutExercise = makeWorkoutExercise(
            exercise: exercise,
            orderIndex: orderIndex,
            experience: experience,
            goal: goal,
            bodyWeightKg: bodyWeightKg,
            stats: stats,
            weightCeilings: weightCeilings
        )
        return PlannedExercise(
            exerciseId: workoutExercise.exerciseId,
            orderIndex: workoutExercise.orderIndex,
            targetSets: workoutExercise.plannedSets,
            restSeconds: workoutExercise.restSeconds,
            reason: "Added manually."
        )
    }

    private static func plannedSet(
        prescription: PrescriptionType,
        exercise: Exercise,
        minReps: Int,
        maxReps: Int,
        plannedWeight: Double?,
        rpeTarget: Double
    ) -> PlannedSet {
        switch prescription {
        case .time:
            return PlannedSet(
                targetRepsMin: 0,
                targetRepsMax: 0,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget,
                targetDurationSeconds: ExerciseMetadataResolver.defaultDurationSeconds(for: exercise)
            )
        case .distance, .distanceOrTime:
            return PlannedSet(
                targetRepsMin: 0,
                targetRepsMax: 0,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget,
                targetDistanceMeters: ExerciseMetadataResolver.defaultDistanceMeters(for: exercise)
            )
        case .reps:
            return PlannedSet(
                targetRepsMin: minReps,
                targetRepsMax: maxReps,
                targetWeightKg: plannedWeight,
                rpeTarget: rpeTarget
            )
        }
    }
}
