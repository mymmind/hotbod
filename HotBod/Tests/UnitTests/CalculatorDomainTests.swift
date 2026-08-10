import XCTest
@testable import HotBod

final class IntensityCalculatorTests: XCTestCase {
    func testEstimateRPELowReps() {
        let rpe = IntensityCalculator.estimateRPE(reps: 3)
        XCTAssertEqual(rpe, 9.0)
    }

    func testEstimateRPEModerateReps() {
        let rpe = IntensityCalculator.estimateRPE(reps: 10)
        XCTAssertEqual(rpe, 7.5)
    }

    func testVolumeIntensity() {
        let intense = IntensityCalculator.volumeIntensity(setCount: 5, targetRepsMax: 5)
        let light = IntensityCalculator.volumeIntensity(setCount: 2, targetRepsMax: 15)
        XCTAssertGreaterThan(intense, light)
    }

    func testFatigueAdjustedIntensity() {
        let base = 0.8
        let highRecovery = IntensityCalculator.fatigueAdjustedIntensity(baseIntensity: base, recoveryPercent: 80)
        let lowRecovery = IntensityCalculator.fatigueAdjustedIntensity(baseIntensity: base, recoveryPercent: 20)
        XCTAssertEqual(highRecovery, base)
        XCTAssertLessThan(lowRecovery, highRecovery)
    }
}

final class WorkoutSessionCalculatorTests: XCTestCase {
    func testEstimatedCaloriesBurned() {
        // 80kg, 60 min at MET 5.0 → 400 kcal
        let calories = WorkoutSessionCalculator.estimatedCaloriesBurned(elapsedSeconds: 3600, bodyWeightKg: 80)
        XCTAssertEqual(calories, 400)
    }

    func testEstimatedCaloriesZeroWhenNoElapsedTime() {
        XCTAssertEqual(WorkoutSessionCalculator.estimatedCaloriesBurned(elapsedSeconds: 0, bodyWeightKg: 80), 0)
    }

    func testExerciseProgress() {
        XCTAssertEqual(WorkoutSessionCalculator.exerciseProgress(currentIndex: 0, exerciseCount: 4), 0.25)
        XCTAssertEqual(WorkoutSessionCalculator.exerciseProgress(currentIndex: 3, exerciseCount: 4), 1.0)
    }

    func testFormattedElapsed() {
        XCTAssertEqual(WorkoutSessionCalculator.formattedElapsed(seconds: 125), "2:05")
        XCTAssertEqual(WorkoutSessionCalculator.formattedElapsed(seconds: 45), "0:45")
    }

    func testCurrentExerciseIndexResumesMidWorkout() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let completed = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [completed]),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set])
        ]
        let session = WorkoutSession(userId: UUID(), title: "Test", estimatedDurationMinutes: 45, exercises: exercises, status: .inProgress)
        XCTAssertEqual(WorkoutSessionCalculator.currentExerciseIndex(for: session), 1)

        var midFirst = exercises
        midFirst[0].completedSets = []
        let midSession = WorkoutSession(userId: UUID(), title: "Test", estimatedDurationMinutes: 45, exercises: midFirst, status: .inProgress)
        XCTAssertEqual(WorkoutSessionCalculator.currentExerciseIndex(for: midSession), 0)
    }

    func testIsSessionFullyLoggedOutOfOrder() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [done]),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done]),
            WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], completedSets: [done])
        ]
        let session = WorkoutSession(
            userId: UUID(),
            title: "Test",
            estimatedDurationMinutes: 45,
            exercises: exercises,
            status: .inProgress
        )
        XCTAssertTrue(WorkoutSessionCalculator.isSessionFullyLogged(session))
        XCTAssertEqual(WorkoutSessionCalculator.incompleteExerciseCount(in: session), 0)
        XCTAssertNil(WorkoutSessionCalculator.firstIncompleteExerciseIndex(in: session))
    }

    func testIncompleteCountIgnoresSkipped() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: []),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done], wasSkipped: true),
            WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], completedSets: [done])
        ]
        let session = WorkoutSession(
            userId: UUID(),
            title: "Test",
            estimatedDurationMinutes: 45,
            exercises: exercises,
            status: .inProgress
        )
        XCTAssertFalse(WorkoutSessionCalculator.isSessionFullyLogged(session))
        XCTAssertEqual(WorkoutSessionCalculator.incompleteExerciseCount(in: session), 1)
        XCTAssertEqual(WorkoutSessionCalculator.firstIncompleteExerciseIndex(in: session), 0)
    }

    func testRegression_finishingLastIndexWithEarlierIncompleteDoesNotAutoComplete() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: []),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done])
        ]
        let session = WorkoutSession(
            userId: UUID(),
            title: "Test",
            estimatedDurationMinutes: 45,
            exercises: exercises,
            status: .inProgress
        )
        let decision = WorkoutSessionCalculator.advanceDecision(session: session, currentExerciseIndex: 1)
        XCTAssertEqual(decision, .confirmEnd)
        XCTAssertFalse(WorkoutSessionCalculator.isSessionFullyLogged(session))
        XCTAssertEqual(WorkoutSessionCalculator.firstIncompleteExerciseIndex(in: session), 0)
    }

    func testAdvanceDecisionFullyLoggedPromptsConfirmEvenMidList() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [done]),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done]),
            WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], completedSets: [done])
        ]
        let session = WorkoutSession(
            userId: UUID(),
            title: "Test",
            estimatedDurationMinutes: 45,
            exercises: exercises,
            status: .inProgress
        )
        let decision = WorkoutSessionCalculator.advanceDecision(session: session, currentExerciseIndex: 1)
        XCTAssertEqual(decision, .confirmEnd)
    }

    func testAdvanceDecisionGoesToNextIndexWhenWorkRemains() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
        let exercises = [
            WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [done]),
            WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [])
        ]
        let session = WorkoutSession(
            userId: UUID(),
            title: "Test",
            estimatedDurationMinutes: 45,
            exercises: exercises,
            status: .inProgress
        )
        let decision = WorkoutSessionCalculator.advanceDecision(session: session, currentExerciseIndex: 0)
        XCTAssertEqual(decision, .goToExercise(index: 1))
    }

    func testEndConfirmationCopyIncompleteVsComplete() {
        let incomplete = WorkoutSessionCalculator.endConfirmationCopy(incompleteExerciseCount: 2)
        XCTAssertEqual(incomplete.title, "End Workout?")
        XCTAssertEqual(incomplete.message, "2 exercises still incomplete. Logged sets will be saved.")

        let singular = WorkoutSessionCalculator.endConfirmationCopy(incompleteExerciseCount: 1)
        XCTAssertEqual(singular.title, "End Workout?")
        XCTAssertEqual(singular.message, "1 exercise still incomplete. Logged sets will be saved.")

        let complete = WorkoutSessionCalculator.endConfirmationCopy(incompleteExerciseCount: 0)
        XCTAssertEqual(complete.title, "Finish Workout?")
        XCTAssertEqual(complete.message, "All sets logged. Ready to end this session?")
    }
}
