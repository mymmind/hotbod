import Foundation

enum ExerciseMetadataResolver {
    private static let perHandExerciseIds: Set<String> = [
        "dumbbell_fly",
        "walking_lunge",
        "bulgarian_split_squat",
        "farmers_carry",
        "rear_delt_fly",
        "dumbbell_press",
        "dumbbell_row",
        "dumbbell_curl",
        "dumbbell_lateral_raise",
        "dumbbell_shoulder_press",
        "single_arm_row",
        "single_leg_rdl"
    ]

    private static let totalWeightExerciseIds: Set<String> = [
        "goblet_squat"
    ]

    private static let timeExerciseIds: Set<String> = [
        "plank",
        "side_plank",
        "rower",
        "battle_ropes",
        "mountain_climber"
    ]

    private static let distanceExerciseIds: Set<String> = [
        "sled_push"
    ]

    private static let distanceOrTimeExerciseIds: Set<String> = [
        "farmers_carry"
    ]

    static func resolvedWeightDisplaySemantics(for exercise: Exercise) -> WeightDisplaySemantics {
        if let explicit = exercise.weightDisplaySemantics {
            return explicit
        }
        if totalWeightExerciseIds.contains(exercise.id) {
            return .total
        }
        if perHandExerciseIds.contains(exercise.id) {
            return .perHand
        }
        if exercise.equipment.contains(.dumbbell) || exercise.equipment.contains(.kettlebell) {
            switch exercise.movementPattern {
            case .horizontalPush, .verticalPush, .horizontalPull, .verticalPull,
                 .lunge, .carry, .isolation:
                return .perHand
            default:
                break
            }
        }
        return .total
    }

    static func resolvedPrescriptionType(for exercise: Exercise) -> PrescriptionType {
        if let explicit = exercise.prescriptionType {
            return explicit
        }
        if distanceOrTimeExerciseIds.contains(exercise.id) {
            return .distanceOrTime
        }
        if timeExerciseIds.contains(exercise.id) || exercise.movementPattern == .cardio {
            return .time
        }
        if distanceExerciseIds.contains(exercise.id) {
            return .distance
        }
        return .reps
    }

    static func defaultDurationSeconds(for exercise: Exercise) -> Int {
        exercise.defaultDurationSeconds ?? {
            switch exercise.movementPattern {
            case .cardio: 300
            case .antiRotation: 45
            default: 30
            }
        }()
    }

    static func defaultDistanceMeters(for exercise: Exercise) -> Double {
        exercise.defaultDistanceMeters ?? 40
    }
}
