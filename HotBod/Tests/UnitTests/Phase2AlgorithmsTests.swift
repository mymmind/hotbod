import XCTest
@testable import HotBod

// MARK: - ProteinComplianceCalculator

final class ProteinComplianceCalculatorPhase2Tests: XCTestCase {
    private let goal = 100.0

    func testDailyTotalsReturnsRequestedDayCount() {
        let totals = ProteinComplianceCalculator.dailyTotals(entries: [], days: 7, goalGrams: goal)
        XCTAssertEqual(totals.count, 7)
    }

    func testDailyTotalsMarksHitGoalAtNinetyPercent() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = [FixtureBuilders.makeProteinEntry(grams: 90, date: today)]
        let totals = ProteinComplianceCalculator.dailyTotals(entries: entries, days: 1, goalGrams: goal)
        XCTAssertTrue(totals.first?.hitGoal == true)
    }

    func testDailyTotalsMissesBelowThreshold() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = [FixtureBuilders.makeProteinEntry(grams: 80, date: today)]
        let totals = ProteinComplianceCalculator.dailyTotals(entries: entries, days: 1, goalGrams: goal)
        XCTAssertFalse(totals.first?.hitGoal == true)
        XCTAssertEqual(totals.first?.grams ?? 0, 80, accuracy: 0.01)
    }

    func testWeeklyCompliancePercentAllDaysHit() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return FixtureBuilders.makeProteinEntry(grams: 100, date: date)
        }
        XCTAssertEqual(ProteinComplianceCalculator.weeklyCompliancePercent(entries: entries, goalGrams: goal), 100)
    }

    func testWeeklyCompliancePercentPartialHits() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<7).enumerated().map { index, offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let grams = index < 3 ? 100.0 : 50.0
            return FixtureBuilders.makeProteinEntry(grams: grams, date: date)
        }
        XCTAssertEqual(ProteinComplianceCalculator.weeklyCompliancePercent(entries: entries, goalGrams: goal), 3.0 / 7.0 * 100, accuracy: 0.1)
    }

    func testWeeklyCompliancePercentZeroWhenNoEntries() {
        XCTAssertEqual(ProteinComplianceCalculator.weeklyCompliancePercent(entries: [], goalGrams: goal), 0)
    }

    func testStreakCountsConsecutiveCompliantDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<4).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return FixtureBuilders.makeProteinEntry(grams: 100, date: date)
        }
        let summary = ProteinComplianceCalculator.summary(entries: entries, goalGrams: goal, asOf: today)
        XCTAssertEqual(summary.streakDays, 4)
    }

    func testStreakBreaksOnMissedDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let entries = [
            FixtureBuilders.makeProteinEntry(grams: 100, date: today),
            FixtureBuilders.makeProteinEntry(grams: 50, date: yesterday),
            FixtureBuilders.makeProteinEntry(grams: 100, date: twoDaysAgo)
        ]
        let summary = ProteinComplianceCalculator.summary(entries: entries, goalGrams: goal, asOf: today)
        XCTAssertEqual(summary.streakDays, 1)
    }

    func testSummaryTodayGrams() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = [
            FixtureBuilders.makeProteinEntry(grams: 30, date: today),
            FixtureBuilders.makeProteinEntry(grams: 45, date: today)
        ]
        let summary = ProteinComplianceCalculator.summary(entries: entries, goalGrams: goal, asOf: today)
        XCTAssertEqual(summary.todayGrams, 75, accuracy: 0.01)
        XCTAssertEqual(summary.goalGrams, goal)
    }
}

// MARK: - StrengthHistory

final class StrengthHistoryTests: XCTestCase {
    func testE1rmTrendEmptyForMissingExercise() {
        let trend = StrengthHistory.e1rmTrend(for: "missing", stats: [])
        XCTAssertTrue(trend.isEmpty)
    }

    func testE1rmTrendMapsCompletedSets() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)
        let stats = UserExerciseStats(
            exerciseId: "bench_press",
            recentSets: [
                CompletedSet(setIndex: 0, weightKg: 100, reps: 5, completedAt: earlier),
                CompletedSet(setIndex: 1, weightKg: 90, reps: 8, completedAt: now)
            ],
            preferredRepRangeMin: 5,
            preferredRepRangeMax: 8
        )
        let trend = StrengthHistory.e1rmTrend(for: "bench_press", stats: [stats])
        XCTAssertEqual(trend.count, 2)
        XCTAssertEqual(trend.last?.e1rm ?? 0, ProgressiveOverload.estimateOneRepMax(weight: 90, reps: 8), accuracy: 0.01)
    }

    func testE1rmTrendSkipsSetsWithoutWeight() {
        let stats = UserExerciseStats(
            exerciseId: "push_up",
            recentSets: [CompletedSet(setIndex: 0, reps: 15)],
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 12
        )
        XCTAssertTrue(StrengthHistory.e1rmTrend(for: "push_up", stats: [stats]).isEmpty)
    }

    func testTopLiftsRanksByEstimatedOneRepMax() {
        let exercises = [
            makeTestExercise(id: "bench_press"),
            makeTestExercise(id: "squat", primaryMuscles: [.quads], pattern: .squat)
        ]
        let stats = [
            UserExerciseStats(exerciseId: "bench_press", estimatedOneRepMax: 120, preferredRepRangeMin: 5, preferredRepRangeMax: 8),
            UserExerciseStats(exerciseId: "squat", estimatedOneRepMax: 180, preferredRepRangeMin: 5, preferredRepRangeMax: 8)
        ]
        let top = StrengthHistory.topLifts(stats: stats, exercises: exercises, limit: 2)
        XCTAssertEqual(top.map(\.exercise.id), ["squat", "bench_press"])
        XCTAssertEqual(top.first?.e1rm, 180)
    }

    func testTopLiftsRespectsLimit() {
        let exercises = (1...4).map { makeTestExercise(id: "lift_\($0)") }
        let stats = exercises.enumerated().map { index, exercise in
            UserExerciseStats(
                exerciseId: exercise.id,
                estimatedOneRepMax: Double(index + 1) * 10,
                preferredRepRangeMin: 5,
                preferredRepRangeMax: 8
            )
        }
        XCTAssertEqual(StrengthHistory.topLifts(stats: stats, exercises: exercises, limit: 2).count, 2)
    }

    func testTopLiftsExcludesStatsWithoutCatalogExercise() {
        let stats = [UserExerciseStats(exerciseId: "ghost_lift", estimatedOneRepMax: 500, preferredRepRangeMin: 5, preferredRepRangeMax: 8)]
        XCTAssertTrue(StrengthHistory.topLifts(stats: stats, exercises: [], limit: 3).isEmpty)
    }

    func testMuscleGroupScoresNormalizesAgainstBodyweight() {
        let exercises = [
            makeTestExercise(id: "bench_press", primaryMuscles: [.chest]),
            makeTestExercise(id: "squat", primaryMuscles: [.quads])
        ]
        let stats = [
            UserExerciseStats(exerciseId: "bench_press", estimatedOneRepMax: 100, preferredRepRangeMin: 5, preferredRepRangeMax: 8),
            UserExerciseStats(exerciseId: "squat", estimatedOneRepMax: 160, preferredRepRangeMin: 5, preferredRepRangeMax: 8)
        ]
        let scores = StrengthHistory.muscleGroupScores(stats: stats, exercises: exercises, bodyweightKg: 80)
        XCTAssertEqual(scores.first(where: { $0.muscleGroup == .chest })?.score, 100)
        XCTAssertEqual(scores.first(where: { $0.muscleGroup == .quads })?.score, 100)
    }

    func testMuscleGroupScoresEmptyWithoutBodyweight() {
        let exercises = [makeTestExercise(id: "bench_press", primaryMuscles: [.chest])]
        let stats = [UserExerciseStats(exerciseId: "bench_press", estimatedOneRepMax: 100, preferredRepRangeMin: 5, preferredRepRangeMax: 8)]
        XCTAssertTrue(StrengthHistory.muscleGroupScores(stats: stats, exercises: exercises, bodyweightKg: 0).isEmpty)
    }

    func testNormalizedStrengthScoreClampsToHundred() {
        XCTAssertEqual(StrengthHistory.normalizedStrengthScore(e1rm: 200, muscle: .chest, bodyweightKg: 80), 100)
    }
}

// MARK: - ExerciseIdResolver

final class ExerciseIdResolverTests: XCTestCase {
    func testNormalizeLowercases() {
        XCTAssertEqual(ExerciseIdResolver.normalize("Bench_Press"), "bench_press")
    }

    func testNormalizeReplacesHyphens() {
        XCTAssertEqual(ExerciseIdResolver.normalize("barbell-back-squat"), "barbell_back_squat")
    }

    func testNormalizeTrimsWhitespace() {
        XCTAssertEqual(ExerciseIdResolver.normalize("  push_up  "), "push_up")
    }

    func testCanonicalIdMatchesCatalogDirectly() {
        let catalog: Set<String> = ["bench_press", "squat"]
        XCTAssertEqual(ExerciseIdResolver.canonicalId("Bench-Press", catalog: catalog, aliasIndex: [:]), "bench_press")
    }

    func testCanonicalIdResolvesAliasIndex() {
        let catalog: Set<String> = ["barbell_back_squat"]
        let aliases = ["back_squat": "barbell_back_squat"]
        XCTAssertEqual(ExerciseIdResolver.canonicalId("back_squat", catalog: catalog, aliasIndex: aliases), "barbell_back_squat")
    }

    func testCanonicalIdNilForUnknownExercise() {
        XCTAssertNil(ExerciseIdResolver.canonicalId("unknown_move", catalog: ["bench_press"], aliasIndex: [:]))
    }
}

// MARK: - ExerciseSwapResolver

final class ExerciseSwapResolverTests: XCTestCase {
    private var bench: Exercise!
    private var dumbbell: Exercise!
    private var profile: UserProfile!

    override func setUp() {
        super.setUp()
        bench = makeStubExercise(
            id: "bench_press",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell, .bench]
        )
        dumbbell = makeStubExercise(
            id: "dumbbell_press",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.dumbbell, .bench]
        )
        profile = UserProfile.empty()
        profile.availableEquipment = [.dumbbell, .barbell, .bench]
    }

    func testSwapCandidatesFindsSubstitute() {
        let resolver = ExerciseSwapResolver(
            allExercises: [bench, dumbbell],
            substitutionGroups: [],
            profile: profile,
            usedExerciseIds: ["bench_press"]
        )
        let candidates = resolver.swapCandidates(for: "bench_press", workoutExerciseIds: ["bench_press"])
        XCTAssertEqual(candidates.first?.id, "dumbbell_press")
    }

    func testSwapCandidatesExcludeWorkoutExerciseIds() {
        let incline = makeStubExercise(
            id: "incline_press",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell, .bench]
        )
        let resolver = ExerciseSwapResolver(
            allExercises: [bench, dumbbell, incline],
            substitutionGroups: [],
            profile: profile,
            usedExerciseIds: ["bench_press"]
        )
        let candidates = resolver.swapCandidates(
            for: "bench_press",
            workoutExerciseIds: ["bench_press", "dumbbell_press", "incline_press"]
        )
        XCTAssertTrue(candidates.isEmpty)
    }

    func testSwapCandidatesRespectAvailableEquipment() {
        profile.availableEquipment = [.bodyweight]
        let bodyweightPress = makeStubExercise(
            id: "push_up",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.bodyweight]
        )
        let resolver = ExerciseSwapResolver(
            allExercises: [bench, bodyweightPress],
            substitutionGroups: [],
            profile: profile,
            usedExerciseIds: []
        )
        let candidates = resolver.swapCandidates(for: "bench_press")
        XCTAssertEqual(candidates.map(\.id), ["push_up"])
    }

    func testSubstitutionGroupLookup() {
        var groupedBench = bench!
        groupedBench.substitutionGroupId = "chest_horizontal_push"
        var groupedDumbbell = dumbbell!
        groupedDumbbell.substitutionGroupId = "chest_horizontal_push"
        let group = ExerciseSubstitutionGroup(
            id: "chest_horizontal_push",
            name: "Chest Press",
            primaryMuscles: [.chest],
            movementPattern: .horizontalPush
        )
        let resolver = ExerciseSwapResolver(
            allExercises: [groupedBench, groupedDumbbell],
            substitutionGroups: [group],
            profile: profile,
            usedExerciseIds: []
        )
        XCTAssertEqual(resolver.substitutionGroup(for: "bench_press")?.id, "chest_horizontal_push")
    }
}

// MARK: - ExerciseSwapReplanner

final class ExerciseSwapReplannerTests: XCTestCase {
    func testReplannedSetsUseSubstituteHistory() {
        let bench = makeStubExercise(
            id: "bench_press",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell, .bench]
        )
        let stats = UserExerciseStats(
            exerciseId: "dumbbell_press",
            lastWeightKg: 28,
            suggestedNextWeightKg: 30,
            recentSets: [],
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 10
        )
        let existing = [
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 80),
            PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 80)
        ]

        let replanned = ExerciseSwapReplanner.replannedSets(
            preservingStructureFrom: existing,
            for: bench,
            stats: stats,
            bodyweightKg: 80,
            experience: .intermediate
        )

        XCTAssertEqual(replanned.count, 2)
        XCTAssertEqual(replanned[0].targetWeightKg, 30)
        XCTAssertEqual(replanned[1].targetWeightKg, 30)
    }

    func testReplannedSetsClearWeightForBodyweightExercise() {
        var plank = makeStubExercise(
            id: "plank",
            muscles: [.abs],
            pattern: .antiRotation,
            equipment: [.bodyweight]
        )
        plank.loadTrackingMode = LoadTrackingMode.none
        let existing = [
            PlannedSet(targetRepsMin: 10, targetRepsMax: 12, targetWeightKg: 60)
        ]

        let replanned = ExerciseSwapReplanner.replannedSets(
            preservingStructureFrom: existing,
            for: plank,
            stats: nil,
            bodyweightKg: 80,
            experience: .intermediate
        )

        XCTAssertNil(replanned[0].targetWeightKg)
    }
}

// MARK: - WorkoutPlanEditor

final class WorkoutPlanEditorTests: XCTestCase {
    func testReorderedUpdatesOrderIndices() {
        let exercises = [
            PlannedExercise(exerciseId: "a", orderIndex: 0, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
            PlannedExercise(exerciseId: "b", orderIndex: 1, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]),
            PlannedExercise(exerciseId: "c", orderIndex: 2, targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)])
        ]

        let reordered = WorkoutPlanEditor.reordered(exercises, from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(reordered.map(\.exerciseId), ["b", "c", "a"])
        XCTAssertEqual(reordered.map(\.orderIndex), [0, 1, 2])
    }
}

// MARK: - WorkoutPreviewSetFormatter

final class WorkoutPreviewSetFormatterTests: XCTestCase {
    func testLoadLabelUsesRoundedWeight() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 82.4)
        let exercise = makeStubExercise(
            id: "bench_press",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell, .bench]
        )

        XCTAssertEqual(
            WorkoutPreviewSetFormatter.loadLabel(for: set, loadMode: exercise.resolvedLoadTrackingMode),
            "82kg"
        )
    }

    func testSummaryLineIncludesWarmupMarker() {
        let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 40, isWarmup: true)
        let exercise = makeStubExercise(
            id: "bench_press",
            muscles: [.chest],
            pattern: .horizontalPush,
            equipment: [.barbell, .bench]
        )

        XCTAssertEqual(
            WorkoutPreviewSetFormatter.summaryLine(for: set, exercise: exercise),
            "Warm-up · 40kg × 8–10"
        )
    }
}
