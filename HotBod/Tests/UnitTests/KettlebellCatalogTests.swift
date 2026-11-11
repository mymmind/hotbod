import XCTest
@testable import HotBod

final class KettlebellCatalogTests: XCTestCase {
    private struct ExpectedExercise {
        let id: String
        let pattern: MovementPattern
        let mechanics: MechanicsType
        let difficulty: ExerciseDifficulty
    }

    private let expected: [ExpectedExercise] = [
        .init(id: "kettlebell_clean", pattern: .hinge, mechanics: .compound, difficulty: .intermediate),
        .init(id: "kettlebell_press", pattern: .verticalPush, mechanics: .compound, difficulty: .intermediate),
        .init(id: "kettlebell_row", pattern: .horizontalPull, mechanics: .compound, difficulty: .beginner),
        .init(id: "kettlebell_snatch", pattern: .hinge, mechanics: .compound, difficulty: .advanced),
        .init(id: "turkish_get_up", pattern: .antiRotation, mechanics: .compound, difficulty: .advanced),
        .init(id: "kettlebell_halo", pattern: .mobility, mechanics: .isolation, difficulty: .beginner),
        .init(id: "kettlebell_windmill", pattern: .hinge, mechanics: .compound, difficulty: .intermediate),
        .init(id: "kettlebell_thruster", pattern: .squat, mechanics: .compound, difficulty: .intermediate),
        .init(id: "kettlebell_goblet_lunge", pattern: .lunge, mechanics: .compound, difficulty: .beginner),
        .init(id: "kettlebell_deadlift", pattern: .hinge, mechanics: .compound, difficulty: .beginner),
        .init(id: "kettlebell_sumo_deadlift_high_pull", pattern: .hinge, mechanics: .compound, difficulty: .intermediate)
    ]

    private let expectedGroup: [String: String] = [
        "kettlebell_clean": "hip_hinge_pattern",
        "kettlebell_press": "shoulder_vertical_push",
        "kettlebell_row": "back_horizontal_pull",
        "kettlebell_snatch": "hip_hinge_pattern",
        "turkish_get_up": "kettlebell_getup_complex",
        "kettlebell_halo": "kettlebell_halo_mobility",
        "kettlebell_windmill": "hip_hinge_pattern",
        "kettlebell_thruster": "quad_squat_pattern",
        "kettlebell_goblet_lunge": "single_leg_quad_glute",
        "kettlebell_deadlift": "hip_hinge_pattern",
        "kettlebell_sumo_deadlift_high_pull": "hip_hinge_pattern"
    ]

    func testNewKettlebellExercisesLoadWithExpectedMetadata() throws {
        let byId = Dictionary(uniqueKeysWithValues: ExerciseCatalogLoader.loadExercises().map { ($0.id, $0) })

        for row in expected {
            let exercise = try XCTUnwrap(byId[row.id], "missing \(row.id)")
            XCTAssertEqual(exercise.equipment, [.kettlebell], row.id)
            XCTAssertEqual(exercise.movementPattern, row.pattern, row.id)
            XCTAssertEqual(exercise.mechanics, row.mechanics, row.id)
            XCTAssertEqual(exercise.difficulty, row.difficulty, row.id)
            XCTAssertFalse(exercise.instructions.isEmpty, row.id)
            XCTAssertEqual(exercise.substitutionGroupId, expectedGroup[row.id], row.id)
        }
    }

    func testNewKettlebellExercisesAreInSubstitutionGroups() throws {
        let groups = Dictionary(uniqueKeysWithValues: ExerciseCatalogLoader.loadSubstitutionGroups().map { ($0.id, $0) })

        for (id, groupId) in expectedGroup {
            let group = try XCTUnwrap(groups[groupId], "missing group \(groupId)")
            XCTAssertTrue(group.exerciseIds.contains(id), "\(id) not in \(groupId)")
        }
    }

    func testTurkishGetUpAndHaloHavePrescriptionOverrides() {
        let tguRange = ExercisePrescriptionOverrides.effectiveRepRange(
            exerciseId: "turkish_get_up",
            stats: nil,
            goal: .buildMuscle,
            experience: .intermediate
        )
        XCTAssertEqual(tguRange.min, 1)
        XCTAssertEqual(tguRange.max, 3)

        let haloRest = ExercisePrescriptionOverrides.effectiveRestSeconds(
            exerciseId: "kettlebell_halo",
            goal: .buildMuscle,
            mechanics: .isolation
        )
        XCTAssertEqual(haloRest, 45)

        let haloRPE = ExercisePrescriptionOverrides.effectiveRPETarget(
            exerciseId: "kettlebell_halo",
            fallback: 8
        )
        XCTAssertEqual(haloRPE, 6)
    }
}
