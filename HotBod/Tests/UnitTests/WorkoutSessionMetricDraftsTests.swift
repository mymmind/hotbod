import XCTest
@testable import HotBod

final class WorkoutSessionMetricDraftsTests: XCTestCase {
    func testRegression_appliesHalfKgWeightDraftToIncompletePlannedSet() {
        let planned = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)
        let session = makeSession(plannedSets: [planned], completedCount: 0)

        let updated = WorkoutSessionMetricDrafts.applying(
            to: session,
            weightTexts: [planned.id: "62.5"],
            repsTexts: [:]
        )

        XCTAssertEqual(updated.exercises[0].plannedSets[0].targetWeightKg, 62.5)
    }

    func testAppliesRepsDraftToIncompletePlannedSet() {
        let planned = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)
        let session = makeSession(plannedSets: [planned], completedCount: 0)

        let updated = WorkoutSessionMetricDrafts.applying(
            to: session,
            weightTexts: [:],
            repsTexts: [planned.id: "12"]
        )

        let set = updated.exercises[0].plannedSets[0]
        XCTAssertEqual(set.targetRepsMin, 12)
        XCTAssertGreaterThanOrEqual(set.targetRepsMax, set.targetRepsMin)
    }

    func testSkipsCompletedPlannedSets() {
        let first = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)
        let second = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)
        let session = makeSession(plannedSets: [first, second], completedCount: 1)

        let updated = WorkoutSessionMetricDrafts.applying(
            to: session,
            weightTexts: [
                first.id: "99",
                second.id: "62.5"
            ],
            repsTexts: [
                first.id: "1",
                second.id: "12"
            ]
        )

        XCTAssertEqual(updated.exercises[0].plannedSets[0].targetWeightKg, 60)
        XCTAssertEqual(updated.exercises[0].plannedSets[0].targetRepsMin, 8)
        XCTAssertEqual(updated.exercises[0].plannedSets[1].targetWeightKg, 62.5)
        XCTAssertEqual(updated.exercises[0].plannedSets[1].targetRepsMin, 12)
    }

    func testIgnoresInvalidDraftsWithoutClearingTargets() {
        let planned = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)
        let session = makeSession(plannedSets: [planned], completedCount: 0)

        let updated = WorkoutSessionMetricDrafts.applying(
            to: session,
            weightTexts: [planned.id: "abc"],
            repsTexts: [planned.id: ""]
        )

        XCTAssertEqual(updated.exercises[0].plannedSets[0].targetWeightKg, 60)
        XCTAssertEqual(updated.exercises[0].plannedSets[0].targetRepsMin, 8)
    }

    func testAppliesDurationAndDistanceDrafts() {
        let planned = PlannedSet(
            targetRepsMin: 0,
            targetRepsMax: 0,
            targetDurationSeconds: 30,
            targetDistanceMeters: 100
        )
        let session = makeSession(plannedSets: [planned], completedCount: 0)

        let updated = WorkoutSessionMetricDrafts.applying(
            to: session,
            weightTexts: [:],
            repsTexts: [:],
            durationTexts: [planned.id: "45"],
            distanceTexts: [planned.id: "200"]
        )

        XCTAssertEqual(updated.exercises[0].plannedSets[0].targetDurationSeconds, 45)
        XCTAssertEqual(updated.exercises[0].plannedSets[0].targetDistanceMeters, 200)
    }

    func testFormatWeightKgPreservesHalfKilograms() {
        XCTAssertEqual(WorkoutSessionMetricDrafts.formatWeightKg(62.5), "62.5")
        XCTAssertEqual(WorkoutSessionMetricDrafts.formatWeightKg(60), "60")
    }

    /// Editing set 2 must not make set 1 fall back to the planned default when
    /// set 1 already has a completed (or drafted) higher value.
    func testRegression_multiSetDisplayPersistence() {
        // Set 1 completed at the prepopulated higher load; draft map empty/cleared.
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedWeightText(
                draft: nil,
                completedKg: 82.5,
                plannedKg: 80
            ),
            "82.5"
        )
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedRepsText(
                draft: nil,
                completedReps: 10,
                plannedRepsMin: 8
            ),
            "10"
        )

        // Blank draft must not wipe completed/planned values (?? does not skip "").
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedWeightText(
                draft: "",
                completedKg: 82.5,
                plannedKg: 80
            ),
            "82.5"
        )
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedRepsText(
                draft: "",
                completedReps: 10,
                plannedRepsMin: 8
            ),
            "10"
        )

        // Active typed draft still wins (soft-warning edits before confirm).
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedWeightText(
                draft: "90",
                completedKg: 82.5,
                plannedKg: 80
            ),
            "90"
        )

        // Incomplete set: draft wins, else planned prepopulation.
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedWeightText(
                draft: "85",
                completedKg: nil,
                plannedKg: 80
            ),
            "85"
        )
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedWeightText(
                draft: nil,
                completedKg: nil,
                plannedKg: 80
            ),
            "80"
        )
        XCTAssertEqual(
            WorkoutSessionMetricDrafts.displayedRepsText(
                draft: nil,
                completedReps: nil,
                plannedRepsMin: 8
            ),
            "8"
        )
    }

    private func makeSession(plannedSets: [PlannedSet], completedCount: Int) -> WorkoutSession {
        let completed = (0..<completedCount).map { index in
            CompletedSet(setIndex: index, weightKg: 60, reps: 8)
        }
        return WorkoutSession(
            userId: UUID(),
            title: "Draft flush",
            estimatedDurationMinutes: 45,
            exercises: [
                WorkoutExercise(
                    exerciseId: "bench_press",
                    orderIndex: 0,
                    plannedSets: plannedSets,
                    completedSets: completed
                )
            ],
            status: .inProgress
        )
    }
}
