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
}
