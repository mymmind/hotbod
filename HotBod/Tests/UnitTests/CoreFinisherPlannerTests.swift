import XCTest
@testable import HotBod

final class CoreFinisherPlannerTests: XCTestCase {
    private func core(
        _ id: String,
        muscles: [MuscleGroup] = [.abs],
        pattern: MovementPattern = .isolation,
        equipment: [Equipment] = [.bodyweight],
        difficulty: ExerciseDifficulty = .beginner
    ) -> Exercise {
        var exercise = makeTestExercise(id: id, primaryMuscles: muscles, pattern: pattern, equipment: equipment)
        exercise.difficulty = difficulty
        return exercise
    }

    private func benchPlanned() -> [PlannedExercise] {
        [
            PlannedExercise(
                exerciseId: "bench_press",
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
            )
        ]
    }

    func testAppendsExactlyOneFinisher() {
        let catalog = [
            makeTestExercise(id: "bench_press"),
            core("plank", pattern: .antiRotation),
            core("dead_bug", pattern: .antiRotation),
            core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate)
        ]
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: catalog,
            availableEquipment: Equipment.allCases,
            experience: .intermediate,
            splitDayFocus: .push,
            exerciseStats: []
        )
        XCTAssertEqual(planned.count, 2)
        XCTAssertTrue(CoreFinisherPlanner.allowlist.contains(planned[1].exerciseId))
    }

    func testPrescriptionMatchesExperience() {
        let cases: [(ExperienceLevel, Int)] = [(.beginner, 3), (.intermediate, 4), (.advanced, 5)]
        for (experience, expectedSets) in cases {
            var planned = benchPlanned()
            CoreFinisherPlanner.appendCoreFinisher(
                to: &planned,
                exercises: [makeTestExercise(id: "bench_press"), core("crunch")],
                availableEquipment: [.bodyweight],
                experience: experience,
                splitDayFocus: .pull,
                exerciseStats: []
            )
            let finisher = planned.last!
            XCTAssertEqual(finisher.targetSets.count, expectedSets, "\(experience)")
            XCTAssertEqual(finisher.restSeconds, 30, "\(experience)")
            XCTAssertEqual(finisher.intensity, experience == .beginner ? .light : .moderate, "\(experience)")
        }
    }

    func testTimedHoldGetsMultipleTimedSets() {
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: [makeTestExercise(id: "bench_press"), core("plank", pattern: .antiRotation)],
            availableEquipment: [.bodyweight],
            experience: .beginner,
            splitDayFocus: .fullBody,
            exerciseStats: []
        )
        let finisher = planned.last!
        XCTAssertEqual(finisher.exerciseId, "plank")
        XCTAssertEqual(finisher.targetSets.count, 3)
        XCTAssertTrue(finisher.targetSets.allSatisfy { ($0.targetDurationSeconds ?? 0) > 0 })
    }

    func testEmptyPoolAppendsNothing() {
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: [makeTestExercise(id: "bench_press")],
            availableEquipment: [.bodyweight],
            experience: .intermediate,
            splitDayFocus: .push,
            exerciseStats: []
        )
        XCTAssertEqual(planned.count, 1)
    }
}
