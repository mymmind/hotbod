import XCTest
@testable import HotBod

final class KettlebellCircuitPlannerTests: XCTestCase {
    func testPlansFiveKettlebellExercisesWithSharedGroupAndFiveByFive() throws {
        let catalog = ExerciseCatalogLoader.loadExercises()
        let workout = try XCTUnwrap(
            KettlebellCircuitPlanner.plan(
                exercises: catalog,
                availableEquipment: [.kettlebell, .bodyweight],
                injuries: [],
                experience: .intermediate,
                recentExerciseIds: []
            )
        )

        XCTAssertEqual(workout.sessionMode, .kettlebellCircuit)
        XCTAssertEqual(workout.title, "Kettlebell Circuit")
        XCTAssertEqual(workout.exercises.count, GenerationConstants.KettlebellCircuit.exerciseCount)
        XCTAssertEqual(workout.generatedBy, .rulesEngine)

        let groupIds = Set(workout.exercises.compactMap(\.groupId))
        XCTAssertEqual(groupIds.count, 1)

        let byId = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        for planned in workout.exercises {
            let meta = try XCTUnwrap(byId[planned.exerciseId])
            XCTAssertTrue(meta.equipment.contains(.kettlebell), planned.exerciseId)
            XCTAssertEqual(planned.targetSets.count, GenerationConstants.KettlebellCircuit.rounds)
            for set in planned.targetSets {
                XCTAssertEqual(set.targetRepsMin, GenerationConstants.KettlebellCircuit.reps)
                XCTAssertEqual(set.targetRepsMax, GenerationConstants.KettlebellCircuit.reps)
            }
        }
    }

    func testReturnsNilWhenFewerThanTwoEligible() {
        let workout = KettlebellCircuitPlanner.plan(
            exercises: [],
            availableEquipment: [.kettlebell],
            injuries: [],
            experience: .beginner,
            recentExerciseIds: []
        )
        XCTAssertNil(workout)
    }

    func testDemotesRecentlyLoggedExercises() throws {
        let catalog = ExerciseCatalogLoader.loadExercises()
        let first = try XCTUnwrap(
            KettlebellCircuitPlanner.plan(
                exercises: catalog,
                availableEquipment: [.kettlebell, .bodyweight],
                injuries: [],
                experience: .intermediate,
                recentExerciseIds: []
            )
        )
        let recent = first.exercises.map(\.exerciseId)
        let second = try XCTUnwrap(
            KettlebellCircuitPlanner.plan(
                exercises: catalog,
                availableEquipment: [.kettlebell, .bodyweight],
                injuries: [],
                experience: .intermediate,
                recentExerciseIds: recent
            )
        )
        let overlap = Set(second.exercises.map(\.exerciseId)).intersection(Set(recent))
        XCTAssertLessThan(overlap.count, recent.count)
    }

    func testRequiresKettlebellEquipmentAvailability() {
        let catalog = ExerciseCatalogLoader.loadExercises()
        let workout = KettlebellCircuitPlanner.plan(
            exercises: catalog,
            availableEquipment: [.dumbbell, .bodyweight],
            injuries: [],
            experience: .intermediate,
            recentExerciseIds: []
        )
        XCTAssertNil(workout)
    }

    func testHonorsCustomSchemeCountsAndRests() throws {
        let catalog = ExerciseCatalogLoader.loadExercises()
        let scheme = KettlebellCircuitScheme(
            exerciseCount: 3,
            reps: 4,
            rounds: 6,
            transitionRestSeconds: 20,
            roundRestSeconds: 90
        )
        let workout = try XCTUnwrap(
            KettlebellCircuitPlanner.plan(
                exercises: catalog,
                availableEquipment: [.kettlebell, .bodyweight],
                injuries: [],
                experience: .intermediate,
                recentExerciseIds: [],
                scheme: scheme
            )
        )

        XCTAssertEqual(workout.exercises.count, 3)
        for planned in workout.exercises {
            XCTAssertEqual(planned.targetSets.count, 6)
            XCTAssertEqual(planned.restSeconds, 90)
            for set in planned.targetSets {
                XCTAssertEqual(set.targetRepsMin, 4)
                XCTAssertEqual(set.targetRepsMax, 4)
            }
        }
        XCTAssertTrue(workout.rationale.contains("3"))
        XCTAssertTrue(workout.selectionRationale.contains { $0.contains("6 rounds") && $0.contains("4 reps") })
        XCTAssertTrue(workout.selectionRationale.contains { $0.contains("20s") && $0.contains("90s") })
    }
}
