import XCTest
@testable import HotBod

final class ExerciseVarietyScoringTests: XCTestCase {
    func testAdditionalPrimaryMusclesUseSecondaryWeight() {
        let dualPrimary = makeTestExercise(
            id: "dual_primary",
            primaryMuscles: [.chest, .triceps],
            pattern: .verticalPush
        )
        let singlePlusSecondary = makeTestExercise(
            id: "single_plus_secondary",
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            pattern: .horizontalPush
        )
        let targets: [MuscleGroup] = [.chest, .triceps]
        let scored = WorkoutGenerationAlgorithms.scoreExercises(
            [dualPrimary, singlePlusSecondary],
            targetMuscles: targets,
            experience: .intermediate,
            stats: [],
            recoveryBias: false
        )
        let dualScore = scored.first { $0.0.id == "dual_primary" }?.1 ?? -1
        let peerScore = scored.first { $0.0.id == "single_plus_secondary" }?.1 ?? -1
        let expected = GenerationConstants.Scoring.primaryMuscleWeight
            + GenerationConstants.Scoring.additionalPrimaryMuscleWeight
        XCTAssertEqual(dualScore, expected, accuracy: 0.001)
        XCTAssertEqual(peerScore, expected, accuracy: 0.001)
    }

    func testRegression_recentlyLoggedMainLiftIsDemoted() {
        let exercise = makeTestExercise(id: "bench_press", primaryMuscles: [.chest])
        let recentStats = [
            UserExerciseStats(
                exerciseId: "bench_press",
                recentSets: [
                    CompletedSet(
                        setIndex: 0,
                        weightKg: 80,
                        reps: 8,
                        completedAt: Date().addingTimeInterval(-86_400)
                    )
                ],
                preferredRepRangeMin: 8,
                preferredRepRangeMax: 10
            )
        ]
        let staleStats = [
            UserExerciseStats(
                exerciseId: "bench_press",
                recentSets: [
                    CompletedSet(
                        setIndex: 0,
                        weightKg: 80,
                        reps: 8,
                        completedAt: Date().addingTimeInterval(-30 * 86_400)
                    )
                ],
                preferredRepRangeMin: 8,
                preferredRepRangeMax: 10
            )
        ]
        let recentScore = WorkoutGenerationAlgorithms.scoreExercises(
            [exercise],
            targetMuscles: [.chest],
            experience: .intermediate,
            stats: recentStats,
            recoveryBias: false
        ).first?.1 ?? 0
        let staleScore = WorkoutGenerationAlgorithms.scoreExercises(
            [exercise],
            targetMuscles: [.chest],
            experience: .intermediate,
            stats: staleStats,
            recoveryBias: false
        ).first?.1 ?? 0
        XCTAssertEqual(
            recentScore,
            staleScore - GenerationConstants.Scoring.recentUsePenaltyUnder3Days,
            accuracy: 0.001
        )
    }

    func testRegression_pushScoringDoesNotPreferDualPrimaryOverPress() {
        let dipsLike = makeTestExercise(
            id: "dips_like",
            primaryMuscles: [.chest, .triceps],
            secondaryMuscles: [.shoulders],
            pattern: .verticalPush
        )
        let benchLike = makeTestExercise(
            id: "bench_like",
            primaryMuscles: [.chest],
            secondaryMuscles: [.shoulders, .triceps],
            pattern: .horizontalPush
        )
        let targets: [MuscleGroup] = [.chest, .shoulders, .triceps]
        let scored = WorkoutGenerationAlgorithms.scoreExercises(
            [dipsLike, benchLike],
            targetMuscles: targets,
            experience: .intermediate,
            stats: [],
            recoveryBias: false
        )
        let dipsScore = scored.first { $0.0.id == "dips_like" }?.1 ?? 0
        let benchScore = scored.first { $0.0.id == "bench_like" }?.1 ?? 0
        XCTAssertLessThanOrEqual(dipsScore, benchScore)
        XCTAssertEqual(dipsScore, benchScore, accuracy: 0.001)
    }

    func testMovementPatternUniqueFromSecondPick() {
        let dips = makeTestExercise(
            id: "dips",
            primaryMuscles: [.chest],
            pattern: .verticalPush
        )
        let landmine = makeTestExercise(
            id: "landmine",
            primaryMuscles: [.shoulders],
            pattern: .verticalPush
        )
        let lateral = makeTestExercise(
            id: "lateral_raise",
            primaryMuscles: [.shoulders],
            pattern: .isolation,
            mechanics: .isolation
        )
        let pushdown = makeTestExercise(
            id: "pushdown",
            primaryMuscles: [.triceps],
            pattern: .isolation,
            mechanics: .isolation
        )
        // Rank dips and landmine first so pattern uniqueness is the deciding factor.
        let ranked: [(Exercise, Double)] = [
            (dips, 20),
            (landmine, 19),
            (lateral, 12),
            (pushdown, 11)
        ]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders, .triceps],
            maxExercises: 3,
            minExercises: 3
        )
        let verticalPushCount = result.exercises.filter { $0.movementPattern == .verticalPush }.count
        XCTAssertEqual(verticalPushCount, 1)
        XCTAssertTrue(result.exercises.contains { $0.id == "dips" })
        XCTAssertFalse(result.exercises.contains { $0.id == "landmine" })
        XCTAssertTrue(result.exercises.contains { $0.id == "lateral_raise" })
        XCTAssertTrue(result.exercises.contains { $0.id == "pushdown" })
    }
}
