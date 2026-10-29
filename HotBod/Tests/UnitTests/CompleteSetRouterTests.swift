import XCTest
@testable import HotBod

final class CompleteSetRouterTests: XCTestCase {
    func testRegression_editingCompletedSetUpdatesInsteadOfAdvancing() {
        // Accidental complete on set 0, user focuses that row.
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 0
        )
        XCTAssertEqual(target, .updateCompleted(setIndex: 0))
        XCTAssertEqual(CompleteSetRouter.buttonTitle(for: target), "Update Set")
    }

    func testCompletesActiveWhenFocusNil() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: nil
        )
        XCTAssertEqual(target, .completeActive(setIndex: 1))
        XCTAssertEqual(CompleteSetRouter.buttonTitle(for: target), "Complete Set")
    }

    func testCompletesActiveWhenFocusOnActiveSet() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 1
        )
        XCTAssertEqual(target, .completeActive(setIndex: 1))
    }

    func testCompletesFirstSetWhenNothingCompleted() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [],
            focusedSetIndex: nil
        )
        XCTAssertEqual(target, .completeActive(setIndex: 0))
    }

    func testNoneWhenAllSetsDoneAndNoFocus() {
        let target = CompleteSetRouter.target(
            plannedCount: 2,
            completedSetIndexes: [0, 1],
            focusedSetIndex: nil
        )
        XCTAssertEqual(target, .none)
    }

    func testUpdatesCompletedWhenAllSetsDoneButPastFocused() {
        let target = CompleteSetRouter.target(
            plannedCount: 2,
            completedSetIndexes: [0, 1],
            focusedSetIndex: 1
        )
        XCTAssertEqual(target, .updateCompleted(setIndex: 1))
    }

    func testUpdatesPlannedFutureSetWithoutCompleting() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 2
        )
        XCTAssertEqual(target, .updatePlanned(setIndex: 2))
        XCTAssertEqual(CompleteSetRouter.buttonTitle(for: target), "Update Set")
    }

    func testIgnoresOutOfRangeFocus() {
        let target = CompleteSetRouter.target(
            plannedCount: 3,
            completedSetIndexes: [0],
            focusedSetIndex: 9
        )
        XCTAssertEqual(target, .completeActive(setIndex: 1))
    }

    func testRegression_supersetAdvancesToPartnerMissingTheSameSet() {
        let group = UUID()
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 40, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set, set], completedSets: [done], groupId: group),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set, set], completedSets: [], groupId: group)
        ]
        XCTAssertEqual(SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 0, completedSetIndex: 0), 1)
    }

    func testRegression_supersetStartsNextRoundOnEarlierPartner() {
        let group = UUID()
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 40, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set, set], completedSets: [done], groupId: group),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set, set], completedSets: [done], groupId: group)
        ]
        XCTAssertEqual(SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 1, completedSetIndex: 0), 0)
    }

    func testRegression_nextRoundSkipsSelfWhenCurrentIsFirstMember() {
        let group = UUID()
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 40, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set, set], completedSets: [done], groupId: group),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set, set], completedSets: [done], groupId: group)
        ]
        XCTAssertEqual(SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 0, completedSetIndex: 0), 1)
    }

    func testPartnerIndexNilWithoutGroup() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [])
        ]
        XCTAssertNil(SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 0, completedSetIndex: 0))
    }
}
