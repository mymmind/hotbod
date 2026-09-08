import XCTest
@testable import HotBod

final class TrainingDataMarkdownExporterTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var generatedAt: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 12))!
    }

    func testEmptySnapshotHasHeaderDisclaimerAndFiveEmptySections() {
        let markdown = TrainingDataMarkdownExporter.render(
            emptySnapshot(),
            generatedAt: generatedAt,
            calendar: calendar
        )
        let expected = """
        # HotBod training export
        Generated: 2026-09-08
        Not medical advice. Paste into an LLM if you want coaching on this log.

        ## Profile
        None logged.

        ## Recovery (current)
        None logged.

        ## Exercise stats
        None logged.

        ## Workouts
        None logged.

        ## Protein
        None logged.

        """
        XCTAssertEqual(markdown, expected)
        XCTAssertEqual(
            TrainingDataMarkdownExporter.filename(generatedAt: generatedAt, calendar: calendar),
            "hotbod-training-2026-09-08.md"
        )
    }

    func testOmitsProfileNameAndIds() {
        var profile = UserProfile.empty()
        profile.name = "Zara Export"
        profile.availableEquipment = [.barbell, .dumbbell]
        let snapshot = TrainingDataExportSnapshot(
            profile: profile,
            sessions: [],
            exerciseStats: [],
            proteinEntries: [],
            recovery: [],
            exerciseNames: [:],
            proteinGoalGrams: profile.proteinGoalGrams
        )
        let markdown = TrainingDataMarkdownExporter.render(
            snapshot,
            generatedAt: generatedAt,
            calendar: calendar
        )
        XCTAssertFalse(markdown.contains("Zara Export"))
        XCTAssertFalse(markdown.contains(profile.id.uuidString))
        XCTAssertTrue(markdown.contains("- Goal: Build Muscle | Experience: Intermediate"))
        XCTAssertTrue(markdown.contains("- Location: Commercial Gym | Split: Upper / Lower | Session: 45 min"))
        XCTAssertTrue(markdown.contains("- Days: Mon, Tue, Thu, Fri"))
        XCTAssertTrue(markdown.contains("- Equipment: Barbell, Dumbbells"))
        XCTAssertTrue(markdown.contains("- Limitations: None"))
        XCTAssertTrue(markdown.contains("- Protein goal: 145 g"))
        XCTAssertFalse(markdown.contains("photoTracking"))
        XCTAssertFalse(markdown.contains("HealthKit"))
    }

    func testIncludesBodyLineWhenPresent() {
        var profile = UserProfile.empty()
        profile.name = "Hidden"
        profile.age = 28
        profile.heightCm = 178
        profile.weightKg = 82
        profile.availableEquipment = [.barbell]
        let markdown = TrainingDataMarkdownExporter.render(
            TrainingDataExportSnapshot(
                profile: profile,
                sessions: [],
                exerciseStats: [],
                proteinEntries: [],
                recovery: [],
                exerciseNames: [:],
                proteinGoalGrams: 145
            ),
            generatedAt: generatedAt,
            calendar: calendar
        )
        XCTAssertTrue(markdown.contains("- Body: 28y, 178 cm, 82 kg"))
        XCTAssertFalse(markdown.contains("Hidden"))
    }

    func testRecoveryTableSortedAndDashesMissingDates() {
        let trained = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 10))!
        let recovery = [
            MuscleRecoveryState(muscleGroup: .chest, recoveryPercentage: 72.4, lastTrainedAt: trained),
            MuscleRecoveryState(muscleGroup: .back, recoveryPercentage: 40, lastTrainedAt: nil)
        ]
        let markdown = TrainingDataMarkdownExporter.render(
            TrainingDataExportSnapshot(
                profile: nil,
                sessions: [],
                exerciseStats: [],
                proteinEntries: [],
                recovery: recovery,
                exerciseNames: [:],
                proteinGoalGrams: 145
            ),
            generatedAt: generatedAt,
            calendar: calendar
        )
        XCTAssertTrue(markdown.contains("| Muscle | Preparedness | Last trained |"))
        let backIndex = markdown.range(of: "| Back | 40 | — |")!.lowerBound
        let chestIndex = markdown.range(of: "| Chest | 72 | 2026-09-06 |")!.lowerBound
        XCTAssertTrue(backIndex < chestIndex)
    }

    func testExerciseStatsQualifyingOnlyNewestFormatting() {
        let stats = [
            UserExerciseStats(
                exerciseId: "bench_press",
                lastWeightKg: 80,
                lastReps: 5,
                estimatedOneRepMax: 95.4,
                preferredRepRangeMin: 5,
                preferredRepRangeMax: 8,
                preferVariation: true
            ),
            UserExerciseStats(
                exerciseId: "empty_shell",
                preferredRepRangeMin: 8,
                preferredRepRangeMax: 10
            ),
            UserExerciseStats(
                exerciseId: "squat",
                lastWeightKg: 100,
                lastReps: 5,
                preferredRepRangeMin: 5,
                preferredRepRangeMax: 8,
                deloadStartedAt: generatedAt.addingTimeInterval(-3600)
            )
        ]
        let markdown = TrainingDataMarkdownExporter.render(
            TrainingDataExportSnapshot(
                profile: nil,
                sessions: [],
                exerciseStats: stats,
                proteinEntries: [],
                recovery: [],
                exerciseNames: ["bench_press": "Bench press", "squat": "Back squat"],
                proteinGoalGrams: 145
            ),
            generatedAt: generatedAt,
            calendar: calendar
        )
        XCTAssertTrue(markdown.contains("- Back squat: last 100 kg × 5, trend Stable; in deload"))
        XCTAssertTrue(markdown.contains("- Bench press: last 80 kg × 5, e1RM 95, trend Stable; prefer variation"))
        XCTAssertFalse(markdown.contains("empty_shell"))
    }

    func testWorkoutsCompletedOnlyNewestFirstWarmupTag() {
        let olderDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 18))!
        let newerDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 18))!
        let planned = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 80)
        let completed = WorkoutSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            title: "Upper",
            startedAt: newerDate.addingTimeInterval(-48 * 60),
            completedAt: newerDate,
            estimatedDurationMinutes: 45,
            exercises: [
                WorkoutExercise(
                    exerciseId: "bench_press",
                    orderIndex: 0,
                    plannedSets: [planned, planned],
                    completedSets: [
                        CompletedSet(setIndex: 0, weightKg: 80, reps: 8, isWarmup: true),
                        CompletedSet(setIndex: 1, weightKg: 77.5, reps: 6, rpe: 8)
                    ]
                ),
                WorkoutExercise(
                    exerciseId: "unused",
                    orderIndex: 1,
                    plannedSets: [planned],
                    completedSets: []
                ),
                WorkoutExercise(
                    exerciseId: "face_pull",
                    orderIndex: 2,
                    plannedSets: [planned],
                    completedSets: [],
                    wasSkipped: true,
                    skipReason: "shoulder"
                )
            ],
            notes: "Felt strong",
            perceivedDifficulty: 7,
            status: .completed,
            splitDayFocus: .upper
        )
        let older = WorkoutSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            title: "Lower",
            startedAt: olderDate,
            completedAt: olderDate,
            estimatedDurationMinutes: 40,
            exercises: [
                WorkoutExercise(
                    exerciseId: "squat",
                    orderIndex: 0,
                    plannedSets: [planned],
                    completedSets: [CompletedSet(setIndex: 0, weightKg: nil, reps: 12)]
                )
            ],
            status: .completed
        )
        let plannedOnly = WorkoutSession(
            userId: UUID(),
            title: "Should not appear",
            estimatedDurationMinutes: 30,
            exercises: [],
            status: .planned
        )
        let markdown = TrainingDataMarkdownExporter.render(
            TrainingDataExportSnapshot(
                profile: nil,
                sessions: [older, plannedOnly, completed],
                exerciseStats: [],
                proteinEntries: [],
                recovery: [],
                exerciseNames: [
                    "bench_press": "Bench press",
                    "squat": "Back squat",
                    "face_pull": "Face pull"
                ],
                proteinGoalGrams: 145
            ),
            generatedAt: generatedAt,
            calendar: calendar
        )
        XCTAssertTrue(markdown.contains("### 2026-09-07 — Upper"))
        XCTAssertTrue(markdown.contains("Duration 48m | Difficulty 7/10 | Focus: Upper"))
        XCTAssertTrue(markdown.contains("Notes: Felt strong"))
        XCTAssertTrue(markdown.contains("- Bench press: 80×8 (wu), 77.5×6 @ RPE 8"))
        XCTAssertTrue(markdown.contains("- Face pull: skipped — shoulder"))
        XCTAssertFalse(markdown.contains("unused"))
        XCTAssertTrue(markdown.contains("### 2026-09-01 — Lower"))
        XCTAssertTrue(markdown.contains("- Back squat: BW×12"))
        XCTAssertFalse(markdown.contains("Should not appear"))
        XCTAssertFalse(markdown.contains("00000000-0000-0000-0000-000000000099"))
        let upperRange = markdown.range(of: "### 2026-09-07 — Upper")!
        let lowerRange = markdown.range(of: "### 2026-09-01 — Lower")!
        XCTAssertTrue(upperRange.lowerBound < lowerRange.lowerBound)
    }

    func testProteinDailyTotalsNewestFirstNoEmptyDays() {
        let day7 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12))!
        let day6 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 8))!
        let day6Later = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 20))!
        let entries = [
            FixtureBuilders.makeProteinEntry(grams: 40, date: day7, foodName: "Chicken"),
            FixtureBuilders.makeProteinEntry(grams: 50, date: day6, foodName: "Eggs"),
            FixtureBuilders.makeProteinEntry(grams: 88.4, date: day6Later, foodName: "Yogurt")
        ]
        let markdown = TrainingDataMarkdownExporter.render(
            TrainingDataExportSnapshot(
                profile: nil,
                sessions: [],
                exerciseStats: [],
                proteinEntries: entries,
                recovery: [],
                exerciseNames: [:],
                proteinGoalGrams: 145
            ),
            generatedAt: generatedAt,
            calendar: calendar
        )
        XCTAssertTrue(markdown.contains("- 2026-09-07: 40 g (goal 145)"))
        XCTAssertTrue(markdown.contains("- 2026-09-06: 138 g (goal 145)"))
        XCTAssertFalse(markdown.contains("2026-09-05"))
        XCTAssertFalse(markdown.contains("Chicken"))
        let day7Range = markdown.range(of: "- 2026-09-07: 40 g (goal 145)")!
        let day6Range = markdown.range(of: "- 2026-09-06: 138 g (goal 145)")!
        XCTAssertTrue(day7Range.lowerBound < day6Range.lowerBound)
    }

    private func emptySnapshot() -> TrainingDataExportSnapshot {
        TrainingDataExportSnapshot(
            profile: nil,
            sessions: [],
            exerciseStats: [],
            proteinEntries: [],
            recovery: [],
            exerciseNames: [:],
            proteinGoalGrams: 145
        )
    }
}
