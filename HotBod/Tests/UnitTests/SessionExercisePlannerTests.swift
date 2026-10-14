import XCTest
@testable import HotBod

final class SessionExercisePlannerTests: XCTestCase {
    func testInsertPlacesExerciseImmediatelyAfterCurrentIndex() {
        var exercises = [
            workoutExercise(id: "a", order: 0),
            workoutExercise(id: "b", order: 1),
            workoutExercise(id: "c", order: 2)
        ]

        SessionExercisePlanner.insert(
            workoutExercise(id: "new", order: 99),
            into: &exercises,
            afterIndex: 0
        )

        XCTAssertEqual(exercises.map(\.exerciseId), ["a", "new", "b", "c"])
        XCTAssertEqual(exercises.map(\.orderIndex), [0, 1, 2, 3])
    }

    func testInsertAfterLastAppends() {
        var exercises = [
            workoutExercise(id: "a", order: 0),
            workoutExercise(id: "b", order: 1)
        ]

        SessionExercisePlanner.insert(
            workoutExercise(id: "new", order: 0),
            into: &exercises,
            afterIndex: 1
        )

        XCTAssertEqual(exercises.map(\.exerciseId), ["a", "b", "new"])
        XCTAssertEqual(exercises.map(\.orderIndex), [0, 1, 2])
    }

    func testInsertIntoEmptySession() {
        var exercises: [WorkoutExercise] = []

        SessionExercisePlanner.insert(
            workoutExercise(id: "solo", order: 5),
            into: &exercises,
            afterIndex: 0
        )

        XCTAssertEqual(exercises.map(\.exerciseId), ["solo"])
        XCTAssertEqual(exercises.first?.orderIndex, 0)
    }

    func testRegression_makeWorkoutExerciseUsesEffortPolicyRPE() {
        let isolation = makeTestExercise(
            id: "cable_fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let planned = SessionExercisePlanner.makeWorkoutExercise(
            exercise: isolation,
            orderIndex: 0,
            experience: .intermediate,
            goal: .buildMuscle,
            bodyWeightKg: 80,
            stats: nil
        )
        let expected = EffortPolicy.targetRPE(for: .isolationFinisher)
        XCTAssertEqual(planned.plannedSets.first?.rpeTarget, expected)
    }

    func testRegression_optionalLoadPlansLoggedWeight() {
        var dip = makeTestExercise(
            id: "weighted_dip",
            primaryMuscles: [.chest],
            pattern: .verticalPush,
            equipment: [.bodyweight]
        )
        dip.loadTrackingMode = .optional
        let withHistory = SessionExercisePlanner.makeWorkoutExercise(
            exercise: dip,
            orderIndex: 0,
            experience: .intermediate,
            goal: .buildMuscle,
            bodyWeightKg: 80,
            stats: UserExerciseStats(
                exerciseId: "weighted_dip",
                lastWeightKg: 20,
                suggestedNextWeightKg: 20,
                preferredRepRangeMin: 6,
                preferredRepRangeMax: 10
            )
        )
        XCTAssertEqual(withHistory.plannedSets.first?.targetWeightKg, 20)

        let withoutHistory = SessionExercisePlanner.makeWorkoutExercise(
            exercise: dip,
            orderIndex: 0,
            experience: .intermediate,
            goal: .buildMuscle,
            bodyWeightKg: 80,
            stats: nil
        )
        XCTAssertNil(withoutHistory.plannedSets.first?.targetWeightKg)
    }

    func testRegression_manualAddUsesSessionEffortTarget() {
        let isolation = makeTestExercise(
            id: "cable_fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let planned = SessionExercisePlanner.makeWorkoutExercise(
            exercise: isolation,
            orderIndex: 0,
            experience: .intermediate,
            goal: .buildMuscle,
            bodyWeightKg: 80,
            stats: nil,
            sessionMode: .recovery
        )
        XCTAssertEqual(
            planned.plannedSets.first?.rpeTarget,
            EffortPolicy.targetRPE(for: .recovery)
        )
    }

    private func workoutExercise(id: String, order: Int) -> WorkoutExercise {
        WorkoutExercise(
            exerciseId: id,
            orderIndex: order,
            plannedSets: [
                PlannedSet(targetRepsMin: 8, targetRepsMax: 12, targetWeightKg: 40, rpeTarget: 8)
            ]
        )
    }
}
