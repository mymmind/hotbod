import XCTest
@testable import HotBod

final class ExerciseVarietyScoringTests: XCTestCase {
    func testPhysiquePreferredPrimaryBonusRaisesScore() {
        let exercise = makeTestExercise(
            id: "ohp",
            primaryMuscles: [.shoulders],
            pattern: .verticalPush
        )
        let base = WorkoutGenerationAlgorithms.scoreExercises(
            [exercise],
            targetMuscles: [.shoulders],
            experience: .intermediate,
            stats: [],
            recoveryBias: false,
            physiquePreferredMuscles: []
        )[0].1
        let boosted = WorkoutGenerationAlgorithms.scoreExercises(
            [exercise],
            targetMuscles: [.shoulders],
            experience: .intermediate,
            stats: [],
            recoveryBias: false,
            physiquePreferredMuscles: [.shoulders]
        )[0].1
        XCTAssertEqual(
            boosted - base,
            GenerationConstants.Scoring.physiquePreferredPrimaryBonus,
            accuracy: 0.001
        )
    }

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
        let exercise = makeTestExercise(
            id: "cable_fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let recentStats = [
            UserExerciseStats(
                exerciseId: "cable_fly",
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
                exerciseId: "cable_fly",
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

    func testRegression_anchorCompoundSkipsRecentUsePenalty() {
        let bench = makeTestExercise(id: "bench_press", primaryMuscles: [.chest], pattern: .horizontalPush)
        let recent = UserExerciseStats(
            exerciseId: "bench_press",
            recentSets: [CompletedSet(setIndex: 0, weightKg: 80, reps: 8, completedAt: Date().addingTimeInterval(-86_400))],
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10
        )
        let stale = UserExerciseStats(
            exerciseId: "bench_press",
            recentSets: [CompletedSet(setIndex: 0, weightKg: 80, reps: 8, completedAt: Date().addingTimeInterval(-30 * 86_400))],
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10
        )
        let recentScore = WorkoutGenerationAlgorithms.scoreExercises(
            [bench], targetMuscles: [.chest], experience: .intermediate, stats: [recent], recoveryBias: false
        ).first?.1
        let staleScore = WorkoutGenerationAlgorithms.scoreExercises(
            [bench], targetMuscles: [.chest], experience: .intermediate, stats: [stale], recoveryBias: false
        ).first?.1
        XCTAssertEqual(recentScore, staleScore)
    }

    func testRegression_legDayKeepsKneeFlexion() {
        let squat = makeTestExercise(id: "squat", primaryMuscles: [.quads, .glutes], pattern: .squat)
        let rdl = makeTestExercise(id: "romanian_deadlift", primaryMuscles: [.hamstrings, .glutes], pattern: .hinge)
        let curl = makeTestExercise(
            id: "leg_curl", primaryMuscles: [.hamstrings], pattern: .isolation, mechanics: .isolation
        )
        let ranked: [(Exercise, Double)] = [(squat, 20), (rdl, 18), (curl, 8)]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.quads, .hamstrings, .glutes],
            maxExercises: 4,
            minExercises: 2,
            focus: .legs
        )
        XCTAssertTrue(result.exercises.contains { $0.id == "leg_curl" })
        XCTAssertTrue(result.exercises.contains { $0.id == "romanian_deadlift" })
    }

    func testRegression_pullKeepsOneRearDeltAndOneCurl() {
        let row = makeTestExercise(id: "row", primaryMuscles: [.back], pattern: .horizontalPull)
        let curl = makeTestExercise(id: "barbell_curl", primaryMuscles: [.biceps], pattern: .isolation, mechanics: .isolation)
        let hammer = makeTestExercise(id: "hammer_curl", primaryMuscles: [.biceps], pattern: .isolation, mechanics: .isolation)
        let rear = makeTestExercise(id: "rear_delt_fly", primaryMuscles: [.shoulders], pattern: .isolation, mechanics: .isolation)
        let ranked: [(Exercise, Double)] = [(row, 20), (curl, 12), (hammer, 11), (rear, 4)]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.back, .biceps],
            maxExercises: 4,
            minExercises: 2,
            focus: .pull
        )
        XCTAssertTrue(result.exercises.contains { $0.id == "rear_delt_fly" })
        XCTAssertEqual(result.exercises.filter(SessionSlot.isCurl).count, 1)
    }

    func testRegression_durationBudgetKeepsKneeFlexion() {
        let curl = makeTestExercise(id: "leg_curl", primaryMuscles: [.hamstrings], pattern: .isolation, mechanics: .isolation)
        let rdl = makeTestExercise(id: "romanian_deadlift", primaryMuscles: [.hamstrings, .glutes], pattern: .hinge)
        let planned = [
            PlannedExercise(exerciseId: "romanian_deadlift", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
            PlannedExercise(exerciseId: "leg_curl", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 12)])
        ]
        let drop = WorkoutGenerationAlgorithms.indexOfLowestScoredIsolationToDrop(
            planned: planned,
            scores: ["leg_curl": 1, "romanian_deadlift": 10],
            targetMuscles: [.hamstrings, .glutes],
            exerciseMap: ["leg_curl": curl, "romanian_deadlift": rdl]
        )
        XCTAssertNil(drop)
    }

    func testRegression_sledPushRequiresSled() {
        let sled = makeTestExercise(
            id: "sled_push",
            primaryMuscles: [.quads, .glutes],
            pattern: .carry,
            equipment: [.sled]
        )
        XCTAssertFalse(EquipmentFilter.isExerciseAvailable(sled, availableEquipment: [.barbell, .dumbbell, .machine, .bodyweight]))
        XCTAssertTrue(EquipmentFilter.isExerciseAvailable(sled, availableEquipment: [.sled]))
    }
}
