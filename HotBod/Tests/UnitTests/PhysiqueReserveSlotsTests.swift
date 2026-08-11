import XCTest
@testable import HotBod

final class PhysiqueReserveSlotsTests: XCTestCase {
    func testReserveTwoOnFocusPhysiquePrimariesWhenEligible() {
        // Ranked: two shoulders/back Physique∩target isolations first would be
        // skipped by coverage if we only relied on soft score — force lower
        // scores but still eligible; also include non-physique fillers.
        let facePull = makeTestExercise(
            id: "face_pull",
            primaryMuscles: [.shoulders],
            pattern: .isolation,
            mechanics: .isolation
        )
        let chestSupportedRow = makeTestExercise(
            id: "chest_supported_row",
            primaryMuscles: [.back],
            pattern: .isolation,
            mechanics: .isolation
        )
        let bench = makeTestExercise(
            id: "bench",
            primaryMuscles: [.chest],
            pattern: .horizontalPush
        )
        let squat = makeTestExercise(
            id: "squat",
            primaryMuscles: [.quads],
            pattern: .squat
        )
        let ranked: [(Exercise, Double)] = [
            (bench, 30),
            (squat, 29),
            (facePull, 5),
            (chestSupportedRow, 4)
        ]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders, .back, .quads],
            maxExercises: 4,
            minExercises: 4,
            physiquePreferredMuscles: [.shoulders, .back],
            reservedPhysiqueSlots: 2
        )
        let ids = Set(result.exercises.map(\.id))
        XCTAssertTrue(ids.contains("face_pull"))
        XCTAssertTrue(ids.contains("chest_supported_row"))
        XCTAssertEqual(result.exercises.count, 4)
    }

    func testReserveZeroWhenPhysiqueEmptyMatchesBaselineIds() {
        let a = makeTestExercise(id: "a", primaryMuscles: [.chest], pattern: .horizontalPush)
        let b = makeTestExercise(id: "b", primaryMuscles: [.shoulders], pattern: .isolation, mechanics: .isolation)
        let ranked: [(Exercise, Double)] = [(a, 10), (b, 9)]
        let baseline = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders],
            maxExercises: 2,
            minExercises: 2
        )
        let withEmpty = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders],
            maxExercises: 2,
            minExercises: 2,
            physiquePreferredMuscles: [],
            reservedPhysiqueSlots: 2
        )
        XCTAssertEqual(baseline.exercises.map(\.id), withEmpty.exercises.map(\.id))
    }

    func testOffFocusPhysiqueCandidateNotReserved() {
        let legCurl = makeTestExercise(
            id: "leg_curl",
            primaryMuscles: [.hamstrings],
            pattern: .isolation,
            mechanics: .isolation
        )
        let bench = makeTestExercise(
            id: "bench",
            primaryMuscles: [.chest],
            pattern: .horizontalPush
        )
        let fly = makeTestExercise(
            id: "fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let ranked: [(Exercise, Double)] = [(legCurl, 100), (bench, 10), (fly, 9)]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest],
            maxExercises: 2,
            minExercises: 2,
            physiquePreferredMuscles: [.hamstrings],
            reservedPhysiqueSlots: 2
        )
        XCTAssertFalse(result.exercises.contains { $0.id == "leg_curl" })
        XCTAssertEqual(Set(result.exercises.map(\.id)), Set(["bench", "fly"]))
    }

    func testThinCatalogStillMeetsMinExercises() {
        let bench = makeTestExercise(id: "bench", primaryMuscles: [.chest], pattern: .horizontalPush)
        let fly = makeTestExercise(
            id: "fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let pushdown = makeTestExercise(
            id: "pushdown",
            primaryMuscles: [.triceps],
            pattern: .isolation,
            mechanics: .isolation
        )
        let lateral = makeTestExercise(
            id: "lateral",
            primaryMuscles: [.shoulders],
            pattern: .isolation,
            mechanics: .isolation
        )
        let ranked: [(Exercise, Double)] = [
            (bench, 10), (fly, 9), (pushdown, 8), (lateral, 7)
        ]
        // Only one Physique∩target eligible (lateral); reserve asks for 2.
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .triceps, .shoulders],
            maxExercises: 4,
            minExercises: 3,
            physiquePreferredMuscles: [.shoulders],
            reservedPhysiqueSlots: 2
        )
        XCTAssertGreaterThanOrEqual(result.exercises.count, 3)
        XCTAssertTrue(result.exercises.contains { $0.id == "lateral" })
    }

    func testRecoveryReserveOne() {
        let facePull = makeTestExercise(
            id: "face_pull",
            primaryMuscles: [.shoulders],
            pattern: .isolation,
            mechanics: .isolation
        )
        let bench = makeTestExercise(id: "bench", primaryMuscles: [.chest], pattern: .horizontalPush)
        let fly = makeTestExercise(
            id: "fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let ranked: [(Exercise, Double)] = [(bench, 20), (fly, 19), (facePull, 1)]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders],
            maxExercises: GenerationConstants.RecoverySession.maxExercises,
            minExercises: GenerationConstants.RecoverySession.minExercises,
            physiquePreferredMuscles: [.shoulders],
            reservedPhysiqueSlots: GenerationConstants.RecoverySession.physiqueReservedSlots
        )
        XCTAssertTrue(result.exercises.contains { $0.id == "face_pull" })
    }
}
