import Foundation

enum CoreFinisherPlanner {
    private static let preferredFinisherIds = [
        "plank",
        "dead_bug",
        "bird_dog",
        "back_extension",
        "russian_twist",
        "side_plank"
    ]

    static func appendCoreFinisher(
        to planned: inout [PlannedExercise],
        exercises: [Exercise],
        availableEquipment: [Equipment],
        experience: ExperienceLevel
    ) {
        guard !planned.isEmpty else { return }

        let existingIds = Set(planned.map(\.exerciseId))
        let candidates = exercises.filter { exercise in
            guard !existingIds.contains(exercise.id) else { return false }
            guard EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: availableEquipment) else { return false }
            let targetsCore = exercise.primaryMuscles.contains(.abs)
                || exercise.primaryMuscles.contains(.lowerBack)
                || exercise.secondaryMuscles.contains(.abs)
            return targetsCore && exercise.movementPattern != .cardio
        }

        let ordered = candidates.sorted { lhs, rhs in
            let lhsRank = preferredFinisherIds.firstIndex(of: lhs.id) ?? Int.max
            let rhsRank = preferredFinisherIds.firstIndex(of: rhs.id) ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.name < rhs.name
        }

        let count = experience == .beginner ? 1 : 2
        for exercise in ordered.prefix(count) {
            let finisher = buildFinisherExercise(exercise, orderIndex: planned.count)
            planned.append(finisher)
        }

        for index in planned.indices {
            planned[index].orderIndex = index
        }
    }

    private static func buildFinisherExercise(_ exercise: Exercise, orderIndex: Int) -> PlannedExercise {
        let prescription = ExerciseMetadataResolver.resolvedPrescriptionType(for: exercise)
        let sets: [PlannedSet]
        switch prescription {
        case .time:
            let seconds = ExerciseMetadataResolver.defaultDurationSeconds(for: exercise)
            sets = [
                PlannedSet(
                    targetRepsMin: 0,
                    targetRepsMax: 0,
                    rpeTarget: 7,
                    targetDurationSeconds: seconds
                )
            ]
        case .distance, .distanceOrTime:
            let meters = ExerciseMetadataResolver.defaultDistanceMeters(for: exercise)
            sets = [
                PlannedSet(
                    targetRepsMin: 0,
                    targetRepsMax: 0,
                    rpeTarget: 7,
                    targetDistanceMeters: meters
                )
            ]
        case .reps:
            sets = [
                PlannedSet(
                    targetRepsMin: 12,
                    targetRepsMax: 15,
                    rpeTarget: 7
                )
            ]
        }

        return PlannedExercise(
            exerciseId: exercise.id,
            orderIndex: orderIndex,
            targetSets: sets,
            restSeconds: 45,
            intensity: .light,
            reason: "Core finisher — abs and spinal stability at session end."
        )
    }
}
