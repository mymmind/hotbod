import XCTest
@testable import HotBod

func makeExerciseWithPattern(_ pattern: MovementPattern) -> Exercise {
    makeTestExercise(id: "test_exercise", primaryMuscles: [.quads], pattern: pattern)
}

func makeTestExercise(
    id: String,
    primaryMuscles: [MuscleGroup] = [.chest],
    secondaryMuscles: [MuscleGroup] = [],
    pattern: MovementPattern = .horizontalPush,
    mechanics: MechanicsType? = .compound,
    equipment: [Equipment] = [.barbell, .dumbbell, .cable, .bodyweight]
) -> Exercise {
    Exercise(
        id: id,
        name: id.replacingOccurrences(of: "_", with: " ").capitalized,
        slug: id,
        primaryMuscles: primaryMuscles,
        secondaryMuscles: secondaryMuscles,
        equipment: equipment,
        movementPattern: pattern,
        difficulty: .intermediate,
        forceType: nil,
        mechanics: mechanics,
        instructions: [],
        formCues: [],
        commonMistakes: [],
        contraindications: [],
        substitutions: [],
        progressions: [],
        regressions: [],
        demoVideos: [],
        imageUrl: nil,
        tags: []
    )
}

let chestWorkoutExercises: [Exercise] = [
    makeTestExercise(id: "bench_press"),
    makeTestExercise(id: "incline_press"),
    makeTestExercise(id: "dumbbell_press"),
    makeTestExercise(id: "cable_fly", mechanics: .isolation)
]

func randomIndex(in range: Range<Int>, using rng: inout SeededRandomNumberGenerator) -> Int {
    Int.random(in: range, using: &rng)
}

func randomDouble(in range: ClosedRange<Double>, using rng: inout SeededRandomNumberGenerator) -> Double {
    Double.random(in: range, using: &rng)
}

func makePlannedExercise(id: String, sets: Int, rest: Int) -> PlannedExercise {
    PlannedExercise(
        exerciseId: id,
        orderIndex: 0,
        targetSets: Array(repeating: PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60), count: sets),
        restSeconds: rest,
        intensity: .moderate
    )
}

func recoverySortKeyForTests(
    _ muscle: MuscleGroup,
    input: WorkoutGenerationInput,
    preferred: [MuscleGroup]
) -> Double {
    var recovery = input.muscleRecovery
    if let sleep = input.readiness?.sleepScore {
        if sleep < GenerationConstants.Recovery.poorSleepScoreThreshold {
            recovery = recovery.mapValues { max(0, $0 - GenerationConstants.Recovery.poorSleepRecoveryPenalty) }
        } else if sleep < GenerationConstants.Recovery.suboptimalSleepScoreThreshold {
            recovery = recovery.mapValues { max(0, $0 - GenerationConstants.Recovery.suboptimalSleepRecoveryPenalty) }
        }
    }
    let base = GenerationConstants.Recovery.recovery(for: muscle, in: recovery)
    let bonus = preferred.contains(muscle) ? GenerationConstants.Targeting.preferredMuscleRecoveryBonus : 0
    return base + bonus
}
