import XCTest
@testable import HotBod

final class SessionStructurePlannerTests: XCTestCase {
    func testAppendCooldownSetsAddsToEachExercise() {
        var planned = [
            PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [
                PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)
            ]),
            PlannedExercise(exerciseId: "row", orderIndex: 1, targetSets: [
                PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 50)
            ])
        ]
        SessionStructurePlanner.appendCooldownSets(
            to: &planned,
            exerciseMap: [
                "bench_press": makeStubExercise(id: "bench_press", muscles: [.chest], pattern: .horizontalPush, equipment: [.barbell]),
                "row": makeStubExercise(id: "row", muscles: [.back], pattern: .horizontalPull, equipment: [.barbell])
            ]
        )
        XCTAssertEqual(planned[0].targetSets.count, 2)
        XCTAssertTrue(planned[0].targetSets.last?.isCooldown == true)
        XCTAssertTrue(planned[1].targetSets.last?.isCooldown == true)
    }

    func testPrependWarmupStretchesInsertsMobilityBeforeLifts() {
        let bench = makeStubExercise(id: "bench_press", muscles: [.chest], pattern: .horizontalPush, equipment: [.barbell])
        let hip = makeStubExercise(id: "hip_opener_stretch", muscles: [.glutes], pattern: .mobility)
        let shoulder = makeStubExercise(id: "shoulder_opener_stretch", muscles: [.shoulders], pattern: .mobility)
        let thoracic = makeStubExercise(id: "thoracic_rotation_stretch", muscles: [.back], pattern: .mobility)
        var planned = [
            PlannedExercise(
                exerciseId: "bench_press",
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
            )
        ]
        SessionStructurePlanner.prependWarmupStretches(
            to: &planned,
            exercises: [bench, hip, shoulder, thoracic],
            enabled: true
        )
        XCTAssertEqual(
            planned.map(\.exerciseId),
            ["hip_opener_stretch", "shoulder_opener_stretch", "thoracic_rotation_stretch", "bench_press"]
        )
        XCTAssertEqual(planned.map(\.orderIndex), [0, 1, 2, 3])
        XCTAssertTrue(planned[0].targetSets[0].isWarmup)
        XCTAssertEqual(planned[0].targetSets[0].targetDurationSeconds, 30)

        var unchanged = planned
        SessionStructurePlanner.prependWarmupStretches(
            to: &unchanged,
            exercises: [bench, hip, shoulder, thoracic],
            enabled: false
        )
        XCTAssertEqual(unchanged.map(\.exerciseId), planned.map(\.exerciseId))
    }

    func testApplyCardioBlockAtEnd() {
        let cardio = makeStubExercise(
            id: "rower",
            muscles: [.back],
            pattern: .cardio,
            equipment: [.cardioMachine]
        )
        let strength = makeStubExercise(id: "bench_press", muscles: [.chest], pattern: .horizontalPush, equipment: [.barbell])
        var planned = [
            PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)])
        ]
        SessionStructurePlanner.applyCardioBlock(
            to: &planned,
            placement: .end,
            exercises: [strength, cardio],
            availableEquipment: [.barbell, .cardioMachine]
        )
        XCTAssertEqual(planned.count, 2)
        XCTAssertEqual(planned.last?.exerciseId, "rower")
    }

    func testApplyCardioBlockSkipsWhenNone() {
        var planned = [
            PlannedExercise(exerciseId: "bench_press", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)])
        ]
        SessionStructurePlanner.applyCardioBlock(
            to: &planned,
            placement: .none,
            exercises: [],
            availableEquipment: Equipment.allCases
        )
        XCTAssertEqual(planned.count, 1)
    }
}

final class EquipmentWeightCeilingTests: XCTestCase {
    func testRoundToAvailableClampsToDumbbellCeiling() {
        let rounded = GenerationConstants.Weight.roundToAvailable(
            24,
            equipment: [.dumbbell],
            ceilings: [.dumbbell: 22]
        )
        XCTAssertEqual(rounded, 22)
    }

    func testApplyCeilingsUsesLowestApplicableLimit() {
        let capped = GenerationConstants.Weight.applyCeilings(
            to: 100,
            equipment: [.dumbbell, .barbell],
            ceilings: [.dumbbell: 30, .barbell: 80]
        )
        XCTAssertEqual(capped, 30)
    }
}

final class CooldownSetPlannerTests: XCTestCase {
    func testProducesSingleCooldownSet() {
        let sets = CooldownSetPlanner.cooldownSets()
        XCTAssertEqual(sets.count, 1)
        XCTAssertTrue(sets[0].isCooldown)
        XCTAssertEqual(sets[0].targetRepsMin, GenerationConstants.Cooldown.repsMin)
    }
}
