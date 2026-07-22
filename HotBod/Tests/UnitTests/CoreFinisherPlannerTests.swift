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

    func testPushPrefersAntiExtension() {
        let catalog = [
            makeTestExercise(id: "bench_press"),
            core("crunch"), // flexion
            core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate),
            core("pallof_press", muscles: [.obliques], pattern: .antiRotation, equipment: [.cable])
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
        XCTAssertEqual(planned.last?.exerciseId, "ab_wheel_rollout")
    }

    func testPullPrefersFlexion() {
        let catalog = [
            makeTestExercise(id: "barbell_row", primaryMuscles: [.back], pattern: .horizontalPull),
            core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate),
            core("hanging_knee_raise", equipment: [.pullUpBar], difficulty: .beginner),
            core("plank", pattern: .antiRotation)
        ]
        var planned = [
            PlannedExercise(
                exerciseId: "barbell_row",
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
            )
        ]
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: catalog,
            availableEquipment: Equipment.allCases,
            experience: .intermediate,
            splitDayFocus: .pull,
            exerciseStats: []
        )
        XCTAssertEqual(planned.last?.exerciseId, "hanging_knee_raise")
    }

    func testDeadliftInSessionPenalizesLowerBackFinisher() {
        let catalog = [
            makeTestExercise(id: "deadlift", primaryMuscles: [.hamstrings, .glutes, .lowerBack], pattern: .hinge),
            core("back_extension", muscles: [.lowerBack], pattern: .hinge, difficulty: .beginner),
            core("dead_bug", pattern: .antiRotation)
        ]
        var planned = [
            PlannedExercise(
                exerciseId: "deadlift",
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 5, targetRepsMax: 5)]
            )
        ]
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: catalog,
            availableEquipment: [.bodyweight],
            experience: .intermediate,
            splitDayFocus: .legs,
            exerciseStats: []
        )
        XCTAssertEqual(planned.last?.exerciseId, "dead_bug")
    }

    func testBeginnerPrefersEasierDifficultyWhenTiedOnRole() {
        let catalog = [
            makeTestExercise(id: "bench_press"),
            core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .advanced),
            core("plank", pattern: .antiRotation, difficulty: .beginner)
        ]
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: catalog,
            availableEquipment: [.bodyweight],
            experience: .beginner,
            splitDayFocus: .push,
            exerciseStats: []
        )
        XCTAssertEqual(planned.last?.exerciseId, "plank")
    }

    func testRecentlyLoggedFinisherIsDemoted() {
        let catalog = [
            makeTestExercise(id: "bench_press"),
            core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate),
            core("plank", pattern: .antiRotation, difficulty: .beginner)
        ]
        let recent = UserExerciseStats(
            exerciseId: "ab_wheel_rollout",
            recentSets: [
                CompletedSet(setIndex: 0, reps: 10, completedAt: Date())
            ],
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 12
        )
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: catalog,
            availableEquipment: [.bodyweight],
            experience: .intermediate,
            splitDayFocus: .push,
            exerciseStats: [recent]
        )
        XCTAssertEqual(planned.last?.exerciseId, "plank")
    }

    func testRegression_plankNotAlwaysSelectedWhenFresherOptionsExist() {
        let catalog = [
            makeTestExercise(id: "bench_press"),
            core("plank", pattern: .antiRotation),
            core("dead_bug", pattern: .antiRotation),
            core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate)
        ]
        let stalePlank = UserExerciseStats(
            exerciseId: "plank",
            recentSets: [CompletedSet(setIndex: 0, reps: 0, durationSeconds: 45, completedAt: Date())],
            preferredRepRangeMin: 1,
            preferredRepRangeMax: 1
        )
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: catalog,
            availableEquipment: [.bodyweight],
            experience: .intermediate,
            splitDayFocus: .push,
            exerciseStats: [stalePlank]
        )
        XCTAssertEqual(planned.last?.exerciseId, "ab_wheel_rollout")
    }
}
