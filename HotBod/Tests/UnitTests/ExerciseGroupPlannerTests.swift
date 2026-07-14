import XCTest
@testable import HotBod

final class ExerciseGroupPlannerTests: XCTestCase {
    func testApplyGroupingCreatesSupersetPairs() {
        var planned = [
            makePlanned(id: "bench_press", order: 0),
            makePlanned(id: "cable_fly", order: 1),
            makePlanned(id: "squat", order: 2),
            makePlanned(id: "leg_curl", order: 3)
        ]
        let map = exerciseMap(for: ["bench_press", "cable_fly", "squat", "leg_curl"])

        ExerciseGroupPlanner.applyGrouping(
            to: &planned,
            preference: .supersets,
            exerciseMap: map
        )

        let grouped = planned.filter { $0.groupId != nil }
        XCTAssertEqual(grouped.count, 4)
        XCTAssertEqual(Set(grouped.map(\.groupId)).count, 2)
    }

    func testApplyGroupingSkipsWhenPreferenceIsNone() {
        var planned = [
            makePlanned(id: "bench_press", order: 0),
            makePlanned(id: "cable_fly", order: 1)
        ]
        let map = exerciseMap(for: ["bench_press", "cable_fly"])

        ExerciseGroupPlanner.applyGrouping(
            to: &planned,
            preference: .none,
            exerciseMap: map
        )

        XCTAssertTrue(planned.allSatisfy { $0.groupId == nil })
    }

    func testRestBeforeAdvancingUsesTransitionRestInsideGroup() {
        let groupId = UUID()
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], restSeconds: 120, groupId: groupId),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], restSeconds: 90, groupId: groupId),
            WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], restSeconds: 90)
        ]

        XCTAssertEqual(
            ExerciseGroupPlanner.restBeforeAdvancing(from: 0, exercises: exercises),
            GenerationConstants.Grouping.transitionRestSeconds
        )
    }

    func testRestBeforeAdvancingUsesGroupRestAfterLastMember() {
        let groupId = UUID()
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], restSeconds: 120, groupId: groupId),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], restSeconds: 90, groupId: groupId),
            WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], restSeconds: 90)
        ]

        XCTAssertEqual(
            ExerciseGroupPlanner.restBeforeAdvancing(from: 1, exercises: exercises),
            120
        )
    }

    func testManualGroupAdjacentAssignsSharedGroupId() {
        var exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set]),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set])
        ]

        ExerciseGroupPlanner.groupAdjacent(in: &exercises, at: 0)

        XCTAssertNotNil(exercises[0].groupId)
        XCTAssertEqual(exercises[0].groupId, exercises[1].groupId)
    }

    func testUngroupClearsAllMembers() {
        let groupId = UUID()
        var exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], groupId: groupId),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], groupId: groupId)
        ]

        ExerciseGroupPlanner.ungroup(in: &exercises, at: 0)

        XCTAssertTrue(exercises.allSatisfy { $0.groupId == nil })
    }

    func testApplyGroupingCircuitsCreatesGroupsOfThree() {
        var planned = [
            makePlanned(id: "bench_press", order: 0),
            makePlanned(id: "cable_fly", order: 1),
            makePlanned(id: "dumbbell_shoulder_press", order: 2),
            makePlanned(id: "squat", order: 3)
        ]
        let map = exerciseMap(for: ["bench_press", "cable_fly", "dumbbell_shoulder_press", "squat"])

        ExerciseGroupPlanner.applyGrouping(
            to: &planned,
            preference: .circuits,
            exerciseMap: map
        )

        let grouped = planned.filter { $0.groupId != nil }
        XCTAssertGreaterThanOrEqual(grouped.count, 3)
        let largestGroup = Dictionary(grouping: grouped, by: \.groupId!).values.map(\.count).max() ?? 0
        XCTAssertGreaterThanOrEqual(largestGroup, 3)
    }

    private let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)

    private func makePlanned(id: String, order: Int) -> PlannedExercise {
        PlannedExercise(exerciseId: id, orderIndex: order, targetSets: [set])
    }

    private func exerciseMap(for ids: [String]) -> [String: Exercise] {
        Dictionary(uniqueKeysWithValues: ids.map { id in
            let muscles: [MuscleGroup]
            let pattern: MovementPattern
            let mechanics: MechanicsType?
            switch id {
            case "bench_press":
                muscles = [.chest]; pattern = .horizontalPush; mechanics = .compound
            case "cable_fly":
                muscles = [.chest]; pattern = .isolation; mechanics = .isolation
            case "squat":
                muscles = [.quads]; pattern = .squat; mechanics = .compound
            case "leg_curl":
                muscles = [.hamstrings]; pattern = .isolation; mechanics = .isolation
            default:
                muscles = [.chest]; pattern = .horizontalPush; mechanics = .compound
            }
            return (id, makeTestExercise(id: id, primaryMuscles: muscles, pattern: pattern, mechanics: mechanics))
        })
    }
}
