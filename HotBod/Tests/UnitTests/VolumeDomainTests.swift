import XCTest
@testable import HotBod

final class VolumeTrackingTests: XCTestCase {
    func testVolumeTrendFromWeeklyHistory() {
        let trend = VolumeTracker.computeTrend(from: [40, 50, 60, 70])
        XCTAssertEqual(trend, .increasing)
    }

    func testWeeklyMaxSetsFromRecentSets() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        VolumeTracker.recordSession(on: &stats)
        XCTAssertGreaterThanOrEqual(stats.weeklyMaxSets, 0)
    }
}

final class VolumeCapCalculatorTests: XCTestCase {
    func testBaseWeeklySetCap() {
        XCTAssertEqual(VolumeCapCalculator.baseWeeklySetCap(experience: .beginner), 70)
        XCTAssertEqual(VolumeCapCalculator.baseWeeklySetCap(experience: .intermediate), 100)
        XCTAssertEqual(VolumeCapCalculator.baseWeeklySetCap(experience: .advanced), 130)
        XCTAssertGreaterThan(
            VolumeCapCalculator.baseWeeklySetCap(experience: .advanced),
            VolumeCapCalculator.baseWeeklySetCap(experience: .beginner)
        )
    }

    func testAdjustedWeeklySetCapWithSoreness() {
        let capNone = VolumeCapCalculator.adjustedWeeklySetCap(experience: .intermediate, soreness: .none)
        let capMild = VolumeCapCalculator.adjustedWeeklySetCap(experience: .intermediate, soreness: .mild)
        let capModerate = VolumeCapCalculator.adjustedWeeklySetCap(experience: .intermediate, soreness: .moderate)
        let capSevere = VolumeCapCalculator.adjustedWeeklySetCap(experience: .intermediate, soreness: .severe)

        XCTAssertEqual(capNone, 100)
        XCTAssertGreaterThan(capNone, capMild)
        XCTAssertGreaterThan(capMild, capModerate)
        XCTAssertGreaterThan(capModerate, capSevere)
    }

    func testValidatorAndCalculatorShareVolumeCap() {
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: .intermediate,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: [:],
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(soreness: .moderate),
            splitDayFocus: nil
        )
        XCTAssertEqual(
            WorkoutValidator.adjustedWeeklySetCap(for: input),
            VolumeCapCalculator.adjustedWeeklySetCap(experience: .intermediate, soreness: .moderate)
        )
    }

    func testVolumeCapValidationThresholds() {
        let profile = UserProfile.empty()
        var profileIntermediate = profile
        profileIntermediate.experienceLevel = .intermediate

        func validate(projectedSets: Int) -> WorkoutValidationResult {
            let input = WorkoutGenerationInput(
                userProfile: profileIntermediate,
                goal: profile.goal,
                experienceLevel: .intermediate,
                availableEquipment: profile.availableEquipment,
                targetDurationMinutes: 45,
                preferredMuscleGroups: [],
                avoidedMuscleGroups: [],
                injuries: [],
                recentWorkouts: [WorkoutSessionSummary(
                    id: UUID(), title: "Prior", completedAt: Date(),
                    totalVolumeKg: 0, totalSets: projectedSets - 4, durationMinutes: 45,
                    muscleGroups: [.chest]
                )],
                muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
                exerciseStats: [],
                userPreferences: WorkoutPreferences(),
                readiness: ReadinessInput(soreness: .none),
                splitDayFocus: nil
            )
            let workout = GeneratedWorkout(
                id: UUID(), title: "Test", estimatedDurationMinutes: 45,
                focus: [.chest],
                exercises: chestWorkoutExercises.enumerated().map { index, exercise in
                    PlannedExercise(
                        exerciseId: exercise.id, orderIndex: index,
                        targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
                    )
                },
                rationale: "", safetyNotes: [], generatedBy: .rulesEngine, createdAt: Date()
            )
            return WorkoutValidator.validate(workout: workout, input: input, exercises: chestWorkoutExercises)
        }

        XCTAssertFalse(validate(projectedSets: 101).isValid)
        XCTAssertTrue(validate(projectedSets: 90).warnings.contains(where: { $0.contains("Weekly volume") }))
        XCTAssertTrue(validate(projectedSets: 80).warnings.isEmpty && validate(projectedSets: 80).errors.isEmpty)
    }

    func testRecommendedWeeklyRepsStableVolume() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [60, 60, 60]
        stats.volumeTrend = .stable
        
        let recommended = VolumeCapCalculator.recommendedWeeklyReps(
            exerciseId: "squat",
            stats: stats,
            primaryMuscles: [.quads],
            targetRepsMin: 5,
            targetRepsMax: 8
        )
        
        XCTAssertEqual(recommended, 60)
    }

    func testRecommendedWeeklyRepsIncreasingVolume() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [50, 55, 60]
        stats.volumeTrend = .increasing
        
        let recommended = VolumeCapCalculator.recommendedWeeklyReps(
            exerciseId: "squat",
            stats: stats,
            primaryMuscles: [.quads],
            targetRepsMin: 5,
            targetRepsMax: 8
        )
        
        // avg(50,55,60)=55; increasing adds 10 but caps at avgReps(6)×8=48
        XCTAssertEqual(recommended, 48)
    }

    func testWeeklyVolumeCompletionPercent() {
        let percent100 = VolumeCapCalculator.weeklyVolumeCompletionPercent(actual: 60, recommended: 60)
        let percent50 = VolumeCapCalculator.weeklyVolumeCompletionPercent(actual: 30, recommended: 60)
        let percent150 = VolumeCapCalculator.weeklyVolumeCompletionPercent(actual: 90, recommended: 60)
        
        XCTAssertEqual(percent100, 100, accuracy: 0.1)
        XCTAssertEqual(percent50, 50, accuracy: 0.1)
        XCTAssertEqual(percent150, 100, accuracy: 0.1) // Capped at 100%
    }
}

final class VolumeCalculatorTests: XCTestCase {
    func testTotalSetsSum() {
        let exercises = [
            PlannedExercise(
                exerciseId: "ex1",
                orderIndex: 0,
                targetSets: [
                    PlannedSet(targetRepsMin: 8, targetRepsMax: 10),
                    PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
                ]
            ),
            PlannedExercise(
                exerciseId: "ex2",
                orderIndex: 1,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
            )
        ]
        let total = VolumeCalculator.totalSets(exercises: exercises)
        XCTAssertEqual(total, 3)
    }

    func testSorenessVolumeFactor() {
        let none = VolumeCalculator.sorenessVolumeFactor(soreness: .none)
        let mild = VolumeCalculator.sorenessVolumeFactor(soreness: .mild)
        let moderate = VolumeCalculator.sorenessVolumeFactor(soreness: .moderate)
        let severe = VolumeCalculator.sorenessVolumeFactor(soreness: .severe)
        XCTAssertEqual(none, 1.0)
        XCTAssertEqual(mild, 0.9)
        XCTAssertEqual(moderate, 0.80)
        XCTAssertEqual(severe, 0.60)
    }

    func testWeeklyVolumeEstimate() {
        let calendar = Calendar.current
        let today = Date()
        let workouts = [
            WorkoutSessionSummary(
                id: UUID(), title: "A", completedAt: today,
                totalVolumeKg: 1000, totalSets: 20, durationMinutes: 45, muscleGroups: []
            ),
            WorkoutSessionSummary(
                id: UUID(), title: "B",
                completedAt: calendar.date(byAdding: .day, value: -2, to: today)!,
                totalVolumeKg: 1000, totalSets: 18, durationMinutes: 45, muscleGroups: []
            )
        ]
        let volume = VolumeCalculator.weeklyVolumeEstimate(recentWorkouts: workouts, endingAt: today)
        XCTAssertEqual(volume, 38)
    }
}
