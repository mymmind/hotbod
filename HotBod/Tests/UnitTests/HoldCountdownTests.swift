import XCTest
@testable import HotBod

final class HoldCountdownTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func countdown(seconds: Int, at start: Date) -> HoldCountdown {
        HoldCountdown.starting(
            plannedSetId: UUID(),
            workoutExerciseId: UUID(),
            setIndex: 0,
            targetSeconds: seconds,
            at: start
        )
    }

    func testRemainingMatchesRestSeconds() {
        let hold = countdown(seconds: 30, at: now)
        let later = now.addingTimeInterval(10.2)
        XCTAssertEqual(
            hold.remaining(at: later),
            WorkoutSessionCalculator.restSecondsRemaining(until: hold.endsAt, at: later)
        )
    }

    func testAtEndCommitsTarget() {
        let hold = countdown(seconds: 30, at: now)
        XCTAssertEqual(hold.outcome(at: hold.endsAt), .commit(seconds: 30))
    }

    func testStopAfterOneSecondCommitsElapsed() {
        let hold = countdown(seconds: 30, at: now)
        XCTAssertEqual(hold.outcome(at: now.addingTimeInterval(1)), .commit(seconds: 1))
    }

    func testStopBeforeOneSecondCancels() {
        let hold = countdown(seconds: 30, at: now)
        XCTAssertEqual(hold.outcome(at: now.addingTimeInterval(0.4)), .cancel)
    }

    func testTypedDraftWins() {
        XCTAssertEqual(
            HoldCountdownTarget.resolve(draft: "20", plannedSeconds: 30, exerciseDefault: 45),
            .seconds(20)
        )
    }

    func testEmptyDraftUsesPlannedThenDefault() {
        XCTAssertEqual(
            HoldCountdownTarget.resolve(draft: "  ", plannedSeconds: 30, exerciseDefault: 45),
            .seconds(30)
        )
        XCTAssertEqual(
            HoldCountdownTarget.resolve(draft: nil, plannedSeconds: nil, exerciseDefault: 45),
            .seconds(45)
        )
        XCTAssertEqual(
            HoldCountdownTarget.resolve(draft: "", plannedSeconds: 0, exerciseDefault: 45),
            .seconds(45)
        )
    }

    func testInvalidDraftBlocksStart() {
        XCTAssertEqual(
            HoldCountdownTarget.resolve(draft: "abc", plannedSeconds: 30, exerciseDefault: 45),
            .blocked
        )
        XCTAssertEqual(
            HoldCountdownTarget.resolve(draft: "0", plannedSeconds: 30, exerciseDefault: 45),
            .blocked
        )
    }

    func testDeadHangCatalogEntry() {
        let exercises = ExerciseCatalogLoader.loadExercises()
        let hang = exercises.first { $0.id == "dead_hang" }
        XCTAssertNotNil(hang)
        guard let hang else { return }
        XCTAssertEqual(hang.equipment, [.pullUpBar])
        XCTAssertEqual(hang.movementPattern, .isolation)
        XCTAssertEqual(hang.mechanics, .isolation)
        XCTAssertEqual(hang.forceType, .staticHold)
        XCTAssertEqual(hang.difficulty, .beginner)
        XCTAssertEqual(hang.resolvedPrescriptionType, .time)
        XCTAssertEqual(ExerciseMetadataResolver.defaultDurationSeconds(for: hang), 30)
        XCTAssertEqual(hang.resolvedLoadTrackingMode, .optional)
        XCTAssertEqual(hang.primaryMuscles, [.back, .forearms, .abs])
        XCTAssertEqual(hang.secondaryMuscles, [.traps])
        XCTAssertEqual(hang.substitutionGroupId, "grip_hang")
        XCTAssertFalse(CoreFinisherPlanner.allowlist.contains("dead_hang"))

        let groups = ExerciseCatalogLoader.loadSubstitutionGroups()
        let grip = groups.first { $0.id == "grip_hang" }
        XCTAssertEqual(grip?.exerciseIds, ["dead_hang"])
        let vertical = groups.first { $0.id == "back_vertical_pull" }
        XCTAssertFalse(vertical?.exerciseIds.contains("dead_hang") ?? false)
    }

    func testSessionWithoutHoldKeysDecodesAsNoHold() throws {
        let session = WorkoutSession(
            userId: UUID(),
            title: "Hold",
            estimatedDurationMinutes: 20,
            exercises: [],
            status: .planned
        )
        let encoded = try JSONEncoder().encode(session)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            return XCTFail("Expected session JSON object")
        }
        for key in [
            "activeHoldEndsAt",
            "activeHoldTargetSeconds",
            "activeHoldPlannedSetId",
            "activeHoldExerciseId",
            "activeHoldSetIndex"
        ] {
            object.removeValue(forKey: key)
        }
        let decoded = try JSONDecoder().decode(
            WorkoutSession.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(decoded.activeHoldEndsAt)
        XCTAssertNil(decoded.activeHoldTargetSeconds)
        XCTAssertNil(decoded.activeHoldPlannedSetId)
        XCTAssertNil(decoded.activeHoldExerciseId)
        XCTAssertNil(decoded.activeHoldSetIndex)
    }
}

final class TimedSetLoggingTests: XCTestCase {
    func testTimedKilogramExercisesAlwaysShowWeight() {
        XCTAssertTrue(TimedSetLogging.showsAlwaysVisibleWeightField(for: catalog("plank")))
        XCTAssertTrue(TimedSetLogging.showsAlwaysVisibleWeightField(for: catalog("side_plank")))
        XCTAssertTrue(TimedSetLogging.showsAlwaysVisibleWeightField(for: catalog("dead_hang")))
    }

    func testNoKilogramTimedWorkHidesWeight() {
        XCTAssertFalse(TimedSetLogging.showsAlwaysVisibleWeightField(for: catalog("battle_ropes")))
        var rower = makeTestExercise(id: "rower", pattern: .cardio, equipment: [.cardioMachine])
        rower.loadTrackingMode = LoadTrackingMode.supported
        rower.weightDisplaySemantics = WeightDisplaySemantics.resistanceLevel
        XCTAssertFalse(TimedSetLogging.showsAlwaysVisibleWeightField(for: rower))
    }

    func testInvertedRowKeepsOptionalRepLoad() {
        XCTAssertFalse(TimedSetLogging.showsAlwaysVisibleWeightField(for: catalog("inverted_row")))
    }

    func testMissingDraftUsesPlannedKilograms() {
        let committed = TimedSetLogging.committedAddedLoad(draft: nil, plannedKg: 12)
        XCTAssertEqual(committed.weight, 12)
        XCTAssertFalse(committed.blocked)
        XCTAssertEqual(
            TimedSetLogging.displayedAddedLoadText(draft: nil, completedKg: nil, plannedKg: 12),
            "12"
        )
    }

    func testEmptyDraftCommitsNilAndDisplaysEmpty() {
        let committed = TimedSetLogging.committedAddedLoad(draft: "  ", plannedKg: 12)
        XCTAssertNil(committed.weight)
        XCTAssertFalse(committed.blocked)
        XCTAssertEqual(
            TimedSetLogging.displayedAddedLoadText(draft: "", completedKg: nil, plannedKg: 12),
            ""
        )
    }

    func testIncompleteMissingDraftShowsPlan() {
        XCTAssertEqual(
            TimedSetLogging.displayedAddedLoadText(draft: nil, completedKg: nil, plannedKg: 12),
            "12"
        )
        XCTAssertEqual(
            TimedSetLogging.displayedAddedLoadText(draft: nil, completedKg: nil, plannedKg: nil),
            ""
        )
    }

    func testCompletedBodyweightDoesNotShowPlan() {
        // Completed sets pass completedKg as an Optional: .none means bodyweight.
        // The display helper needs a third state: completed with nil weight.
        // Spec: use an explicit completed flag or Optional wrapper.
        XCTAssertEqual(
            TimedSetLogging.displayedAddedLoadText(
                draft: nil,
                completedKg: nil,
                plannedKg: 12,
                isCompleted: true
            ),
            ""
        )
        XCTAssertEqual(
            TimedSetLogging.displayedAddedLoadText(
                draft: nil,
                completedKg: 8,
                plannedKg: 12,
                isCompleted: true
            ),
            "8"
        )
    }

    private func catalog(_ id: String) -> Exercise {
        if let exercise = ExerciseCatalogLoader.loadExercises().first(where: { $0.id == id }) {
            return exercise
        }
        return makeTestExercise(id: id)
    }
}
