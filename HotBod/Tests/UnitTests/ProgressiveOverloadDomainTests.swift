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

    func testRegression_assistedMissAddsAssistance() {
        let next = ProgressiveOverload.nextWeight(
            currentWeight: -20,
            completedAllSetsAtTopRange: false,
            missedMinimumReps: true
        )
        XCTAssertEqual(next, -22.5, accuracy: 0.01)
    }

    func testRegression_assistedTopOfRangeReducesAssistance() {
        let next = ProgressiveOverload.nextWeight(
            currentWeight: -20,
            completedAllSetsAtTopRange: true,
            missedMinimumReps: false
        )
        XCTAssertEqual(next, -17.5, accuracy: 0.01)
    }

    func testRegression_assistedDeloadAddsAssistance() {
        var stats = UserExerciseStats(
            exerciseId: "assisted_pull_up",
            lastWeightKg: -20,
            recentSets: [],
            preferredRepRangeMin: 6,
            preferredRepRangeMax: 10
        )
        stats.deloadStartedAt = Date()
        let next = ProgressiveOverload.nextWeight(
            current: -20,
            stats: stats,
            volumeCap: 20,
            setCountThisWeek: 10,
            bodyweight: 80
        )
        XCTAssertEqual(next, -22.5, accuracy: 0.01)
    }

    func testRegression_nonPositiveLoadDoesNotReplaceEstimatedMax() {
        let existing = UserExerciseStats(
            exerciseId: "assisted_pull_up",
            estimatedOneRepMax: 40,
            bestVolumeSet: 480,
            preferredRepRangeMin: 6,
            preferredRepRangeMax: 10
        )
        let set = CompletedSet(setIndex: 0, weightKg: -20, reps: 8, completedAt: Date())
        let stats = ProgressiveOverload.updateStats(
            existing: existing,
            exerciseId: "assisted_pull_up",
            completedSets: [set],
            plannedSets: [PlannedSet(targetRepsMin: 6, targetRepsMax: 10, targetWeightKg: -20)]
        )
        XCTAssertEqual(stats.estimatedOneRepMax, 40)
        XCTAssertEqual(stats.bestVolumeSet, 480)
        XCTAssertEqual(ProgressiveOverload.estimateOneRepMax(weight: -20, reps: 8), 0)
    }

    func testRegression_resistanceLevelDoesNotProgressAsKilograms() {
        let existing = UserExerciseStats(
            exerciseId: "rower",
            lastWeightKg: 40,
            estimatedOneRepMax: 80,
            preferredRepRangeMin: 1,
            preferredRepRangeMax: 1
        )
        let set = CompletedSet(setIndex: 0, weightKg: 6, reps: 0, durationSeconds: 300, completedAt: Date())
        let stats = ProgressiveOverload.updateStats(
            existing: existing,
            exerciseId: "rower",
            completedSets: [set],
            plannedSets: [PlannedSet(targetRepsMin: 1, targetRepsMax: 1, targetDurationSeconds: 300)],
            countsExternalKilograms: false
        )
        XCTAssertEqual(stats.estimatedOneRepMax, 80)
        XCTAssertEqual(stats.lastWeightKg, 40)
        XCTAssertNil(stats.suggestedNextWeightKg)
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

    func testRegression_holdLoadIncreaseRepsBumpsPreferredRepMin() {
        let sets = [
            CompletedSet(setIndex: 0, weightKg: 100, reps: 8),
            CompletedSet(setIndex: 1, weightKg: 100, reps: 8),
            CompletedSet(setIndex: 2, weightKg: 100, reps: 8)
        ]
        let planned = [
            PlannedSet(targetRepsMin: 8, targetRepsMax: 12),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 12),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 12)
        ]
        let stats = ProgressiveOverload.updateStats(
            existing: nil,
            exerciseId: "bench_press",
            completedSets: sets,
            plannedSets: planned,
            goal: .buildMuscle
        )
        XCTAssertEqual(stats.suggestedNextWeightKg ?? -1, 100, accuracy: 0.1)
        XCTAssertEqual(stats.preferredRepRangeMin, 9)
        XCTAssertEqual(stats.preferredRepRangeMax, 12)
        XCTAssertFalse(stats.preferVariation)
    }

    func testRegression_loadIncreaseReopensRepRange() {
        let existing = UserExerciseStats(
            exerciseId: "bench_press",
            lastWeightKg: 100,
            lastReps: 10,
            suggestedNextWeightKg: 100,
            preferredRepRangeMin: 10,
            preferredRepRangeMax: 10
        )
        let updated = ProgressiveOverload.updateStats(
            existing: existing,
            exerciseId: "bench_press",
            completedSets: [CompletedSet(setIndex: 0, weightKg: 100, reps: 10)],
            plannedSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 10)],
            experienceLevel: .intermediate,
            goal: .buildMuscle,
            equipment: [.barbell]
        )
        let range = GenerationConstants.Prescription.repRange(for: .buildMuscle, experience: .intermediate)
        XCTAssertEqual(updated.preferredRepRangeMin, range.min)
        XCTAssertEqual(updated.preferredRepRangeMax, range.max)
        XCTAssertEqual(updated.suggestedNextWeightKg, 102.5)
    }

    func testRegression_preferVariationSetsFlagOnStall() {
        let now = Date()
        let day: TimeInterval = 24 * 3600
        var prior: [CompletedSet] = []
        for session in 0..<3 {
            let base = now.addingTimeInterval(-Double(3 - session) * day)
            prior.append(CompletedSet(setIndex: 0, weightKg: 100, reps: 8, completedAt: base))
            prior.append(CompletedSet(setIndex: 1, weightKg: 100, reps: 8, completedAt: base.addingTimeInterval(90)))
        }
        let existing = UserExerciseStats(
            exerciseId: "bench_press",
            recentSets: prior,
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10
        )
        let sets = [
            CompletedSet(setIndex: 0, weightKg: 100, reps: 8, completedAt: now),
            CompletedSet(setIndex: 1, weightKg: 100, reps: 8, completedAt: now.addingTimeInterval(90))
        ]
        let planned = [
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        ]
        let stats = ProgressiveOverload.updateStats(
            existing: existing,
            exerciseId: "bench_press",
            completedSets: sets,
            plannedSets: planned,
            goal: .buildMuscle
        )
        XCTAssertTrue(stats.preferVariation)
        XCTAssertEqual(stats.suggestedNextWeightKg ?? -1, 100, accuracy: 0.1)
    }

    func testRegression_recentSetsRetainFullRollingWeek() {
        let now = Date()
        let prior = (0..<20).map { index in
            CompletedSet(
                setIndex: index % 5,
                weightKg: 80,
                reps: 8,
                completedAt: now.addingTimeInterval(-Double(index) * 6 * 3600)
            )
        }
        let existing = UserExerciseStats(
            exerciseId: "squat",
            recentSets: prior,
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        let sets = [CompletedSet(setIndex: 0, weightKg: 80, reps: 8, completedAt: now)]
        let planned = [PlannedSet(targetRepsMin: 5, targetRepsMax: 8)]
        let stats = ProgressiveOverload.updateStats(
            existing: existing,
            exerciseId: "squat",
            completedSets: sets,
            plannedSets: planned
        )
        XCTAssertGreaterThan(stats.recentSets.count, 12)
        let weekCount = VolumeTracker.rollingSetCount(from: stats.recentSets, endingAt: now)
        XCTAssertGreaterThan(weekCount, 12)
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
