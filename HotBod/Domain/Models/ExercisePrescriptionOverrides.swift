import Foundation

struct ExercisePrescriptionOverride: Codable, Hashable {
    var sets: Int?
    var repRangeMin: Int?
    var repRangeMax: Int?
    var restSeconds: Int?
    var warmupSets: Int?
    var rpeTarget: Double?
    var prescriptionType: PrescriptionType?
    var defaultDurationSeconds: Int?
    var defaultDistanceMeters: Double?
    var weightDisplaySemantics: WeightDisplaySemantics?
}

struct ExercisePrescriptionOverridesBundle: Codable {
    var exercises: [String: ExercisePrescriptionOverride] = [:]
}

enum ExercisePrescriptionOverridesLoader {
    static var resourceBundle: Bundle { ExerciseCatalogLoader.resourceBundle }

    static func load() -> ExercisePrescriptionOverridesBundle {
        guard let url = resourceBundle.url(forResource: "ExercisePrescriptionOverrides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(ExercisePrescriptionOverridesBundle.self, from: data) else {
            return ExercisePrescriptionOverridesBundle()
        }
        return bundle
    }

    static func apply(_ override: ExercisePrescriptionOverride, to exercise: inout Exercise) {
        if let prescriptionType = override.prescriptionType {
            exercise.prescriptionType = prescriptionType
        }
        if let defaultDurationSeconds = override.defaultDurationSeconds {
            exercise.defaultDurationSeconds = defaultDurationSeconds
        }
        if let defaultDistanceMeters = override.defaultDistanceMeters {
            exercise.defaultDistanceMeters = defaultDistanceMeters
        }
        if let weightDisplaySemantics = override.weightDisplaySemantics {
            exercise.weightDisplaySemantics = weightDisplaySemantics
        }
    }
}

enum ExercisePrescriptionOverrides {
    private static let cached: ExercisePrescriptionOverridesBundle = ExercisePrescriptionOverridesLoader.load()

    static func override(for exerciseId: String) -> ExercisePrescriptionOverride? {
        cached.exercises[exerciseId]
    }

    static func effectiveRepRange(
        exerciseId: String,
        stats: UserExerciseStats?,
        goal: TrainingGoal,
        experience: ExperienceLevel
    ) -> (min: Int, max: Int) {
        if let override = cached.exercises[exerciseId],
           let min = override.repRangeMin,
           let max = override.repRangeMax {
            return (min, max)
        }
        return GenerationConstants.Prescription.effectiveRepRange(
            stats: stats,
            goal: goal,
            experience: experience
        )
    }

    static func effectiveSetCount(
        exerciseId: String,
        experience: ExperienceLevel,
        pattern: MovementPattern
    ) -> Int {
        if let sets = cached.exercises[exerciseId]?.sets {
            return sets
        }
        return GenerationConstants.Prescription.setCount(experience: experience, pattern: pattern)
    }

    static func effectiveRestSeconds(
        exerciseId: String,
        goal: TrainingGoal,
        mechanics: MechanicsType
    ) -> Int {
        if let rest = cached.exercises[exerciseId]?.restSeconds {
            return rest
        }
        return WorkoutGenerationAlgorithms.restSeconds(goal: goal, mechanics: mechanics)
    }

    static func effectiveRPETarget(
        exerciseId: String,
        fallback: Double
    ) -> Double {
        cached.exercises[exerciseId]?.rpeTarget ?? fallback
    }
}
