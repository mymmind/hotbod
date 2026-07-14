import XCTest
@testable import HotBod

final class ProgressiveOverloadTests: XCTestCase {
    func testIncreaseWeightWhenHittingTopRange() {
        let next = ProgressiveOverload.nextWeight(currentWeight: 100, completedAllSetsAtTopRange: true, missedMinimumReps: false)
        XCTAssertEqual(next, 102.5)
    }

    func testDecreaseWeightWhenMissingReps() {
        let next = ProgressiveOverload.nextWeight(currentWeight: 100, completedAllSetsAtTopRange: false, missedMinimumReps: true)
        XCTAssertLessThan(next, 100)
    }

    func testLowLoggedRPEIncreasesWeightMoreAggressively() {
        let baseline = ProgressiveOverload.nextWeight(
            currentWeight: 100,
            completedAllSetsAtTopRange: true,
            missedMinimumReps: false
        )
        let withEasyRPE = ProgressiveOverload.nextWeight(
            currentWeight: 100,
            completedAllSetsAtTopRange: true,
            missedMinimumReps: false,
            averageLoggedRPE: 7.0
        )
        XCTAssertGreaterThan(withEasyRPE, baseline)
    }

    func testHighLoggedRPEHoldsWeightWhenHittingTopRange() {
        let next = ProgressiveOverload.nextWeight(
            currentWeight: 100,
            completedAllSetsAtTopRange: true,
            missedMinimumReps: false,
            averageLoggedRPE: 9.5
        )
        XCTAssertEqual(next, 100, accuracy: 0.1)
    }

    func testAverageLoggedRPEIgnoresWarmups() {
        let sets = [
            CompletedSet(setIndex: 0, weightKg: 40, reps: 10, rpe: 5, isWarmup: true),
            CompletedSet(setIndex: 1, weightKg: 100, reps: 8, rpe: 8),
            CompletedSet(setIndex: 2, weightKg: 100, reps: 8, rpe: 10)
        ]
        XCTAssertEqual(ProgressiveOverload.averageLoggedRPE(from: sets)!, 9.0, accuracy: 0.01)
    }

    func testUpdateStatsSeparatesLastAndSuggestedWeight() {
        let sets = [
            CompletedSet(setIndex: 0, weightKg: 100, reps: 10),
            CompletedSet(setIndex: 1, weightKg: 100, reps: 10),
            CompletedSet(setIndex: 2, weightKg: 100, reps: 10)
        ]
        let planned = [
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        ]
        let stats = ProgressiveOverload.updateStats(existing: nil, exerciseId: "bench_press", completedSets: sets, plannedSets: planned)
        XCTAssertEqual(stats.lastWeightKg, 100)
        XCTAssertEqual(stats.suggestedNextWeightKg, 102.5)
    }

    func testUpdateStatsIgnoresWarmupSetsForProgression() {
        let sets = [
            CompletedSet(setIndex: 0, weightKg: 40, reps: 8, isWarmup: true),
            CompletedSet(setIndex: 1, weightKg: 60, reps: 8, isWarmup: true),
            CompletedSet(setIndex: 2, weightKg: 100, reps: 10),
            CompletedSet(setIndex: 3, weightKg: 100, reps: 10),
            CompletedSet(setIndex: 4, weightKg: 100, reps: 10)
        ]
        let planned = [
            PlannedSet(targetRepsMin: 5, targetRepsMax: 8, targetWeightKg: 40, isWarmup: true),
            PlannedSet(targetRepsMin: 5, targetRepsMax: 8, targetWeightKg: 60, isWarmup: true),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 100),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 100),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 100)
        ]
        let stats = ProgressiveOverload.updateStats(
            existing: nil,
            exerciseId: "bench_press",
            completedSets: sets,
            plannedSets: planned
        )
        XCTAssertEqual(stats.lastWeightKg, 100)
        XCTAssertEqual(stats.suggestedNextWeightKg, 102.5)
    }

    func testUpdateStatsWiresVolumeTrendAndDeload() {
        var existing = UserExerciseStats(
            exerciseId: "squat",
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        existing.weeklyVolume = [100, 100, 100]

        let sets = (0..<3).map {
            CompletedSet(setIndex: $0, weightKg: 100, reps: 10, completedAt: Date())
        }
        let planned = (0..<3).map { _ in PlannedSet(targetRepsMin: 8, targetRepsMax: 10) }

        let stats = ProgressiveOverload.updateStats(
            existing: existing,
            exerciseId: "squat",
            completedSets: sets,
            plannedSets: planned
        )

        XCTAssertFalse(stats.weeklyVolume.isEmpty)
        XCTAssertEqual(stats.weeklyVolume.last, 30)
        XCTAssertGreaterThan(stats.weeklyMaxSets, 0)
        XCTAssertTrue(stats.volumeTrend == .stable || stats.volumeTrend == .decreasing)
    }

    func testUpdateStatsTriggersReturningFromBreakOnGapWeek() {
        let now = Date()
        let previousWindowSets = (0..<10).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 80,
                reps: 5,
                completedAt: now.addingTimeInterval(-9 * 24 * 3600)
            )
        }
        var existing = UserExerciseStats(
            exerciseId: "squat",
            recentSets: previousWindowSets,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        existing.weeklyVolume = [100, 100, 100]

        let sets = [CompletedSet(setIndex: 0, weightKg: 80, reps: 5, completedAt: now)]
        let planned = [PlannedSet(targetRepsMin: 5, targetRepsMax: 8)]

        let stats = ProgressiveOverload.updateStats(
            existing: existing,
            exerciseId: "squat",
            completedSets: sets,
            plannedSets: planned
        )

        XCTAssertTrue(stats.returningFromBreak)
        XCTAssertFalse(stats.isInDeloadWeek)
    }
}

final class ProgressiveOverloadEnhancedTests: XCTestCase {
    func testEstimateOneRepMax() {
        let e1rm = ProgressiveOverload.estimateOneRepMax(weight: 100, reps: 5)
        let expected = 100 * (1.0 + 5.0 / 30.0) // ~116.67
        XCTAssertEqual(e1rm, expected, accuracy: 0.1)
    }

    func testEstimateOneRepMaxZeroReps() {
        let e1rm = ProgressiveOverload.estimateOneRepMax(weight: 100, reps: 0)
        XCTAssertEqual(e1rm, 100)
    }

    func testNextWeightDuringDeload() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            lastWeightKg: 100,
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.deloadStartedAt = Date()
        
        let nextWeight = ProgressiveOverload.nextWeight(
            current: 100,
            stats: stats,
            volumeCap: 20,
            setCountThisWeek: 10,
            bodyweight: 80
        )
        
        XCTAssertEqual(nextWeight, 90, accuracy: 0.1) // 10% reduction
    }

    func testNextWeightWithIncreasingVolume() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            lastWeightKg: 100,
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.volumeTrend = .increasing
        stats.weeklyMaxSets = 8
        
        let nextWeight = ProgressiveOverload.nextWeight(
            current: 100,
            stats: stats,
            volumeCap: 20,
            setCountThisWeek: 8,
            bodyweight: 80
        )
        
        XCTAssertGreaterThan(nextWeight, 100) // Should increment
    }

    func testNextWeightAtVolumeCap() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            lastWeightKg: 100,
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.volumeTrend = .stable
        
        let nextWeight = ProgressiveOverload.nextWeight(
            current: 100,
            stats: stats,
            volumeCap: 12,
            setCountThisWeek: 12, // At cap
            bodyweight: 80
        )
        
        XCTAssertEqual(nextWeight, 95, accuracy: 0.1) // 5% reduction
    }

    func testSuggestedStartWeightForSquat() {
        let weight = ProgressiveOverload.suggestedStartWeight(
            for: makeExerciseWithPattern(.squat),
            bodyweight: 80,
            experience: .intermediate
        )
        
        XCTAssertGreaterThan(weight, 40)
        XCTAssertLessThan(weight, 80)
    }

    func testSuggestedStartWeightAdvancedVsBeginnerDifference() {
        let exercise = makeExerciseWithPattern(.squat)
        let advancedWeight = ProgressiveOverload.suggestedStartWeight(
            for: exercise,
            bodyweight: 80,
            experience: .advanced
        )
        let beginnerWeight = ProgressiveOverload.suggestedStartWeight(
            for: exercise,
            bodyweight: 80,
            experience: .beginner
        )
        
        XCTAssertGreaterThan(advancedWeight, beginnerWeight)
    }
}

final class DeloadDetectionTests: XCTestCase {
    func testDeloadDetectionVolumeDropRequiresMeaningfulCurrentVolume() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let previousWindowSets = (0..<10).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-8 * 24 * 3600)
            )
        }
        let currentWindowSets = (0..<6).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-2 * 24 * 3600)
            )
        }

        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: previousWindowSets + currentWindowSets,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [100, 100, 100, 60]

        let analysis = DeloadDetector.analyzeDeloadNeed(
            stats: stats,
            volumeHistory: stats.weeklyVolume,
            now: now
        )

        XCTAssertTrue(analysis.isDeloadRecommended)
        XCTAssertEqual(analysis.severity, .severe)
    }

    func testDeloadDetectionGapWeekSuggestsReturningFromBreak() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let previousWindowSets = (0..<10).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-8 * 24 * 3600)
            )
        }
        let currentWindowSets = (0..<3).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-2 * 24 * 3600)
            )
        }

        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: previousWindowSets + currentWindowSets,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [100, 100, 100, 60]

        let analysis = DeloadDetector.analyzeDeloadNeed(
            stats: stats,
            volumeHistory: stats.weeklyVolume,
            now: now
        )

        XCTAssertFalse(analysis.isDeloadRecommended)
        XCTAssertTrue(analysis.suggestsReturningFromBreak)
    }

    func testDeloadDetectionConsecutiveHighVolume() {
        var stats = UserExerciseStats(
            exerciseId: "bench_press",
            recentSets: [],
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10
        )
        stats.weeklyVolume = [50, 60, 70, 85] // 3 weeks of 20%+ increases
        stats.consecutiveHighVolumeWeeks = 3
        
        let analysis = DeloadDetector.analyzeDeloadNeed(
            stats: stats,
            volumeHistory: stats.weeklyVolume,
            consecutiveWeeks: 3
        )
        
        XCTAssertTrue(analysis.isDeloadRecommended)
        XCTAssertEqual(analysis.severity, .moderate)
    }

    func testNoDeloadNeededStableVolume() {
        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: [],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [70, 70, 72, 71]
        
        let analysis = DeloadDetector.analyzeDeloadNeed(
            stats: stats,
            volumeHistory: stats.weeklyVolume
        )
        
        XCTAssertFalse(analysis.isDeloadRecommended)
        XCTAssertEqual(analysis.severity, .none)
    }

    func testDeloadRecommendedFromConsistentlyHighLoggedRPE() {
        let recentSets = [
            CompletedSet(setIndex: 0, weightKg: 100, reps: 8, rpe: 9.5),
            CompletedSet(setIndex: 1, weightKg: 100, reps: 8, rpe: 10),
            CompletedSet(setIndex: 2, weightKg: 100, reps: 7, rpe: 9.5)
        ]
        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: recentSets,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )

        let analysis = DeloadDetector.analyzeDeloadNeed(
            stats: stats,
            volumeHistory: stats.weeklyVolume
        )

        XCTAssertTrue(analysis.isDeloadRecommended)
        XCTAssertEqual(analysis.severity, .mild)
    }

    func testUpdateDeloadStateSetsReturningFromBreakForGapWeek() {
        let now = Date()
        let previousWindowSets = (0..<10).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-9 * 24 * 3600)
            )
        }
        let currentWindowSets = (0..<2).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-1 * 24 * 3600)
            )
        }

        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: previousWindowSets + currentWindowSets,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [100, 100, 100, 50]

        DeloadDetector.updateDeloadState(stats: &stats, now: now)

        XCTAssertTrue(stats.returningFromBreak)
        XCTAssertFalse(stats.isInDeloadWeek)
    }

    func testUpdateDeloadStateSetsDeloadStartedAt() {
        let now = Date()
        let previousWindowSets = (0..<10).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-9 * 24 * 3600)
            )
        }
        let currentWindowSets = (0..<6).map { index in
            CompletedSet(
                setIndex: index,
                weightKg: 100,
                reps: 5,
                completedAt: now.addingTimeInterval(-1 * 24 * 3600)
            )
        }

        var stats = UserExerciseStats(
            exerciseId: "squat",
            recentSets: previousWindowSets + currentWindowSets,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        stats.weeklyVolume = [100, 100, 100, 50]

        DeloadDetector.updateDeloadState(stats: &stats, now: now)

        XCTAssertTrue(stats.isInDeloadWeek)
        XCTAssertNotNil(stats.deloadStartedAt)
    }
}
