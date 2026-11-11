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

    func testRegression_kettlebellCircuitSameRoundUsesTransitionRest() throws {
        let group = UUID()
        let set = PlannedSet(targetRepsMin: 5, targetRepsMax: 5)
        let done = CompletedSet(setIndex: 0, weightKg: 16, reps: 5)
        let exercises = [
            WorkoutExercise(
                exerciseId: "a",
                orderIndex: 0,
                plannedSets: Array(repeating: set, count: 5),
                completedSets: [done],
                groupId: group
            ),
            WorkoutExercise(
                exerciseId: "b",
                orderIndex: 1,
                plannedSets: Array(repeating: set, count: 5),
                completedSets: [],
                groupId: group
            )
        ]
        let partner = try XCTUnwrap(
            SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 0, completedSetIndex: 0)
        )
        let seconds = SetAdvancePlanner.restSeconds(
            exercises: exercises,
            exerciseIndex: 0,
            completedSetIndex: 0,
            partnerIndex: partner,
            sessionMode: .kettlebellCircuit,
            kettlebellScheme: .default
        )
        XCTAssertEqual(seconds, GenerationConstants.KettlebellCircuit.transitionRestSeconds)
    }

    func testRegression_kettlebellCircuitHonorsCustomSchemeRests() throws {
        let group = UUID()
        let set = PlannedSet(targetRepsMin: 4, targetRepsMax: 4)
        let done = CompletedSet(setIndex: 0, weightKg: 16, reps: 4)
        let exercises = [
            WorkoutExercise(
                exerciseId: "a",
                orderIndex: 0,
                plannedSets: Array(repeating: set, count: 6),
                completedSets: [done],
                groupId: group
            ),
            WorkoutExercise(
                exerciseId: "b",
                orderIndex: 1,
                plannedSets: Array(repeating: set, count: 6),
                completedSets: [done],
                groupId: group
            )
        ]
        let scheme = KettlebellCircuitScheme(
            exerciseCount: 3,
            reps: 4,
            rounds: 6,
            transitionRestSeconds: 20,
            roundRestSeconds: 90
        )
        let sameRoundPartner = try XCTUnwrap(
            SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 0, completedSetIndex: 0)
        )
        // Partner still missing set 0? Wait — both have done set 0, so this advances to next round.
        let nextRoundSeconds = SetAdvancePlanner.restSeconds(
            exercises: exercises,
            exerciseIndex: 1,
            completedSetIndex: 0,
            partnerIndex: 0,
            sessionMode: .kettlebellCircuit,
            kettlebellScheme: scheme
        )
        XCTAssertEqual(nextRoundSeconds, 90)

        var midRound = exercises
        midRound[1].completedSets = []
        let transitionSeconds = SetAdvancePlanner.restSeconds(
            exercises: midRound,
            exerciseIndex: 0,
            completedSetIndex: 0,
            partnerIndex: sameRoundPartner,
            sessionMode: .kettlebellCircuit,
            kettlebellScheme: scheme
        )
        XCTAssertEqual(transitionSeconds, 20)
    }

    func testRegression_kettlebellCircuitNextRoundUsesRoundRest() throws {
        let group = UUID()
        let set = PlannedSet(targetRepsMin: 5, targetRepsMax: 5)
        let done = CompletedSet(setIndex: 0, weightKg: 16, reps: 5)
        let exercises = [
            WorkoutExercise(
                exerciseId: "a",
                orderIndex: 0,
                plannedSets: Array(repeating: set, count: 5),
                completedSets: [done],
                groupId: group
            ),
            WorkoutExercise(
                exerciseId: "b",
                orderIndex: 1,
                plannedSets: Array(repeating: set, count: 5),
                completedSets: [done],
                groupId: group
            )
        ]
        let partner = try XCTUnwrap(
            SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 1, completedSetIndex: 0)
        )
        XCTAssertEqual(partner, 0)
        let seconds = SetAdvancePlanner.restSeconds(
            exercises: exercises,
            exerciseIndex: 1,
            completedSetIndex: 0,
            partnerIndex: partner,
            sessionMode: .kettlebellCircuit
        )
        XCTAssertEqual(seconds, GenerationConstants.KettlebellCircuit.roundRestSeconds)
    }

    func testRegression_standardSupersetNextRoundStaysTransitionRest() throws {
        let group = UUID()
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 40, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set, set], completedSets: [done], groupId: group),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set, set], completedSets: [done], groupId: group)
        ]
        let partner = try XCTUnwrap(
            SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 1, completedSetIndex: 0)
        )
        let seconds = SetAdvancePlanner.restSeconds(
            exercises: exercises,
            exerciseIndex: 1,
            completedSetIndex: 0,
            partnerIndex: partner,
            sessionMode: .standard
        )
        XCTAssertEqual(seconds, GenerationConstants.Grouping.transitionRestSeconds)
    }
}
