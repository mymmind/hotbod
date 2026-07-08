import Foundation

struct CatalogSweepResult: Equatable {
    var removedWorkoutExerciseIds: [String] = []
    var flaggedOrphanStatIds: [String] = []
    var workoutNeedsRegeneration: Bool = false
}

enum CatalogIntegrity {
    static let minWorkoutExercises = GenerationConstants.Session.minStandardExercises

    /// Repairs persisted user data after catalog changes. Exercise IDs in seed data are permanent —
    /// rename via `aliases` in ExerciseContent.json, never by changing `id`.
    static func sweep(
        catalogIds: Set<String>,
        workout: inout GeneratedWorkout?,
        stats: inout [UserExerciseStats]
    ) -> CatalogSweepResult {
        var result = CatalogSweepResult()

        if var current = workout {
            let before = current.exercises.count
            current.exercises.removeAll { planned in
                guard !catalogIds.contains(planned.exerciseId) else { return false }
                result.removedWorkoutExerciseIds.append(planned.exerciseId)
                return true
            }
            if current.exercises.count != before {
                if current.exercises.isEmpty {
                    result.workoutNeedsRegeneration = true
                    workout = nil
                } else if current.exercises.count < minWorkoutExercises {
                    result.workoutNeedsRegeneration = true
                    workout = nil
                } else {
                    workout = current
                }
            }
        }

        for index in stats.indices {
            if catalogIds.contains(stats[index].exerciseId) {
                if stats[index].isOrphaned {
                    stats[index].isOrphaned = false
                }
            } else if !stats[index].isOrphaned {
                stats[index].isOrphaned = true
                result.flaggedOrphanStatIds.append(stats[index].exerciseId)
            }
        }

        return result
    }
}
