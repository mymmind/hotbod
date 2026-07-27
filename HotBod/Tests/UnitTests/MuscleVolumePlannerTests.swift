import XCTest
@testable import HotBod

final class MuscleVolumePlannerTests: XCTestCase {
    func testHardSetCreditsPrimaryAndSecondary() {
        let exercise = makeTestExercise(
            id: "bench",
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps, .shoulders]
        )
        let credits = MuscleVolumePlanner.hardSetCredits(for: exercise)
        XCTAssertEqual(credits[.chest], 1.0)
        XCTAssertEqual(credits[.triceps], 0.5)
        XCTAssertEqual(credits[.shoulders], 0.5)
    }

    func testWeeklyLandingByExperienceAndGoal() {
        XCTAssertEqual(
            GenerationConstants.Volume.weeklyLandingSets(experience: .beginner, goal: .buildMuscle),
            10
        )
        XCTAssertEqual(
            GenerationConstants.Volume.weeklyLandingSets(experience: .intermediate, goal: .gainStrength),
            10
        )
        XCTAssertEqual(
            GenerationConstants.Volume.weeklyLandingSets(experience: .advanced, goal: .buildMuscle),
            18
        )
        XCTAssertEqual(
            GenerationConstants.Volume.weeklyLandingSets(experience: .advanced, goal: .loseFat),
            14
        )
    }

    func testCompletedHardSetsFromRollingStats() {
        let now = Date()
        let exercise = makeTestExercise(
            id: "row",
            primaryMuscles: [.back],
            secondaryMuscles: [.biceps],
            pattern: .horizontalPull
        )
        var stats = UserExerciseStats(exerciseId: "row", preferredRepRangeMin: 8, preferredRepRangeMax: 10)
        stats.recentSets = (0..<4).map { index in
            CompletedSet(setIndex: index, weightKg: 60, reps: 8, completedAt: now.addingTimeInterval(-3600))
        }
        let completed = MuscleVolumePlanner.completedHardSets(
            stats: [stats],
            exerciseMap: ["row": exercise],
            endingAt: now
        )
        XCTAssertEqual(completed[.back], 4.0)
        XCTAssertEqual(completed[.biceps], 2.0)
    }

    func testSessionAllocationRespectsRemainingBudget() {
        let press = makeTestExercise(id: "press", primaryMuscles: [.chest], secondaryMuscles: [.triceps])
        let fly = makeTestExercise(
            id: "fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation,
            equipment: [.dumbbell]
        )
        let allocated = MuscleVolumePlanner.allocateSessionSetCounts(
            exercises: [press, fly],
            baseSetCounts: [4, 3],
            remaining: [.chest: 3]
        )
        XCTAssertEqual(allocated.reduce(0, +), 3)
        XCTAssertLessThanOrEqual(allocated[0], 4)
        XCTAssertLessThanOrEqual(allocated[1], 3)
    }

    func testPrimaryCompletionFractionAtLandingHoldsOverload() {
        let exercise = makeTestExercise(
            id: "squat",
            primaryMuscles: [.quads],
            secondaryMuscles: [.glutes],
            pattern: .squat
        )
        let landing = MuscleVolumePlanner.weeklyLanding(experience: .intermediate, goal: .buildMuscle)
        let fraction = MuscleVolumePlanner.primaryCompletionFraction(
            exercise: exercise,
            completed: [.quads: landing],
            experience: .intermediate,
            goal: .buildMuscle
        )
        XCTAssertEqual(fraction, 1.0, accuracy: 0.001)

        var stats = UserExerciseStats(exerciseId: "squat", preferredRepRangeMin: 5, preferredRepRangeMax: 8)
        stats.volumeTrend = .stable
        let held = ProgressiveOverload.nextWeight(
            current: 100,
            stats: stats,
            muscleVolumeCompletion: fraction,
            bodyweight: 80,
            equipment: [.barbell]
        )
        XCTAssertEqual(held, 95)
    }
}
