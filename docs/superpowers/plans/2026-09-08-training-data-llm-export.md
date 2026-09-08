# Training Data LLM Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user copy or share a markdown dump of all completed workouts, protein daily totals, and current recovery from Settings, for pasting into an external LLM.

**Architecture:** A pure `TrainingDataMarkdownExporter.render` turns a `TrainingDataExportSnapshot` into markdown. `AppEnvironment.makeTrainingDataExport()` loads repositories, strips the profile name, writes a temp `.md` file, and returns `{ markdown, fileURL, filename }`. Settings presents the existing `ShareSheet` with the string then the file URL.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen (`xcodegen generate` after new `HotBod/` files), `HotBod.xctestplan` configuration **PR**.

**Spec:** `docs/superpowers/specs/2026-09-08-training-data-llm-export-design.md`

## Global Constraints

- iOS 26+ / Swift 6; local-first; no backend; no secrets.
- Markdown only. No JSON/CSV. No date-range UI. No preview screen.
- Free for everyone. Do **not** call `canAccess(.workoutExport)` or change `ProFeature`.
- Never include profile `name`, profile/session UUIDs, photos, physique assessments, or medical/body-fat claims.
- Header third line is exactly: `Not medical advice. Paste into an LLM if you want coaching on this log.`
- Empty sections still appear as `None logged.`
- Multiplication sign in set rows is `×` (U+00D7). Session headings use em dash `—` (U+2014).
- Weekday labels use `Weekday.shortName` (`Mon`), because `Weekday` has no `displayName`.
- Protein fetch uses existing `fetchEntries(from:to:)`. Pass `to: Date().addingTimeInterval(1)` because `InMemoryNutritionRepository` (and local) uses a half-open range `date < end`.
- After new Swift files under `HotBod/`, run `xcodegen generate`. If `objectVersion` / `DEVELOPMENT_TEAM` churn, restore those baselines.
- Do not commit unrelated dirty `HotBod/Resources/Localizable.xcstrings` hunks (pre-existing split-suggestion keys). Add only the four export keys.
- Simulator: `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0`. If missing, run `xcodebuild -scheme HotBod -showdestinations` and substitute an installed iPhone 26.x simulator.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Algorithms/TrainingDataMarkdownExporter.swift` | `TrainingDataExportSnapshot` + pure markdown renderer + filename helper |
| `HotBod/App/AppEnvironment+TrainingExport.swift` | Gather repos, write temp file, `TrainingDataExport` / `TrainingDataExportError` |
| `HotBod/Features/Settings/SettingsView.swift` | Export `@State` + share sheet |
| `HotBod/Features/Settings/SettingsView+Profile.swift` | App-section Export row |
| `HotBod/Core/Localization/L10n.swift` | Settings export strings |
| `HotBod/Resources/Localizable.xcstrings` | Four `settings.exportTrainingData*` keys |
| `HotBod/Tests/UnitTests/TrainingDataMarkdownExporterTests.swift` | Markdown contract |
| `HotBod/Tests/Integration/TrainingDataExportIntegrationTests.swift` | `makeTrainingDataExport()` |
| `HotBod/Tests/UITests/SettingsUITests.swift` | Row exists |
| `HotBod.xctestplan` | Add UI test to PR selectedTests |

Do not modify `ForgeSubscriptionProducts`, `SettingsErrorMessages.swift`, or HealthKit export.

---

### Task 1: Markdown exporter (TDD)

**Files:**
- Create: `HotBod/Tests/UnitTests/TrainingDataMarkdownExporterTests.swift`
- Create: `HotBod/Domain/Algorithms/TrainingDataMarkdownExporter.swift`

**Interfaces:**
- Consumes: existing `UserProfile`, `WorkoutSession`, `WorkoutExercise`, `CompletedSet`, `UserExerciseStats`, `ProteinEntry`, `MuscleRecoveryState`, domain `displayName` / `shortName`
- Produces:
  ```swift
  struct TrainingDataExportSnapshot: Equatable {
      var profile: UserProfile?
      var sessions: [WorkoutSession]
      var exerciseStats: [UserExerciseStats]
      var proteinEntries: [ProteinEntry]
      var recovery: [MuscleRecoveryState]
      var exerciseNames: [String: String]
      var proteinGoalGrams: Double
  }

  enum TrainingDataMarkdownExporter {
      static let disclaimer = "Not medical advice. Paste into an LLM if you want coaching on this log."
      static let noneLogged = "None logged."

      static func render(
          _ snapshot: TrainingDataExportSnapshot,
          generatedAt: Date = Date(),
          calendar: Calendar = .current
      ) -> String

      static func filename(generatedAt: Date = Date(), calendar: Calendar = .current) -> String
  }
  ```

- [ ] **Step 1: Write the failing unit tests**

Create `HotBod/Tests/UnitTests/TrainingDataMarkdownExporterTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/TrainingDataMarkdownExporterTests
```

Expected: FAIL — `TrainingDataMarkdownExporter` / `TrainingDataExportSnapshot` not found.

- [ ] **Step 3: Write the exporter**

Create `HotBod/Domain/Algorithms/TrainingDataMarkdownExporter.swift`:

```swift
import Foundation

struct TrainingDataExportSnapshot: Equatable {
    var profile: UserProfile?
    var sessions: [WorkoutSession]
    var exerciseStats: [UserExerciseStats]
    var proteinEntries: [ProteinEntry]
    var recovery: [MuscleRecoveryState]
    var exerciseNames: [String: String]
    var proteinGoalGrams: Double
}

enum TrainingDataMarkdownExporter {
    static let disclaimer = "Not medical advice. Paste into an LLM if you want coaching on this log."
    static let noneLogged = "None logged."

    static func render(
        _ snapshot: TrainingDataExportSnapshot,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        var profile = snapshot.profile
        profile?.name = nil
        let body = [
            "# HotBod training export",
            "Generated: \(isoDate(generatedAt, calendar: calendar))",
            disclaimer,
            "",
            "## Profile",
            renderProfile(profile),
            "",
            "## Recovery (current)",
            renderRecovery(snapshot.recovery, calendar: calendar),
            "",
            "## Exercise stats",
            renderStats(snapshot.exerciseStats, names: snapshot.exerciseNames, generatedAt: generatedAt),
            "",
            "## Workouts",
            renderWorkouts(snapshot.sessions, names: snapshot.exerciseNames, calendar: calendar),
            "",
            "## Protein",
            renderProtein(
                snapshot.proteinEntries,
                goalGrams: snapshot.proteinGoalGrams,
                calendar: calendar
            )
        ]
        return body.joined(separator: "\n") + "\n"
    }

    static func filename(generatedAt: Date = Date(), calendar: Calendar = .current) -> String {
        "hotbod-training-\(isoDate(generatedAt, calendar: calendar)).md"
    }

    private static func renderProfile(_ profile: UserProfile?) -> String {
        guard let profile else { return noneLogged }
        var lines: [String] = [
            "- Goal: \(profile.goal.displayName) | Experience: \(profile.experienceLevel.displayName)",
            "- Location: \(profile.trainingLocation.displayName) | Split: \(profile.preferredSplit.displayName) | Session: \(profile.preferredSessionLengthMinutes) min",
            "- Days: \(profile.reminderTrainingDays.map(\.shortName).joined(separator: ", "))",
            "- Equipment: \(profile.availableEquipment.map(\.displayName).joined(separator: ", "))",
            "- Limitations: \(profile.limitations.map(\.displayName).joined(separator: ", "))"
        ]
        if let notes = profile.limitationNotes, !notes.isEmpty {
            lines.append("- Notes: \(notes)")
        }
        if let preferred = profile.preferredMuscleGroups, !preferred.isEmpty {
            lines.append("- Preferred: \(preferred.map(\.displayName).joined(separator: ", "))")
        }
        if let avoided = profile.avoidedMuscleGroups, !avoided.isEmpty {
            lines.append("- Avoided: \(avoided.map(\.displayName).joined(separator: ", "))")
        }
        lines.append("- Protein goal: \(Int(profile.proteinGoalGrams.rounded())) g")
        if let body = bodyLine(profile) {
            lines.append(body)
        }
        return lines.joined(separator: "\n")
    }

    private static func bodyLine(_ profile: UserProfile) -> String? {
        var parts: [String] = []
        if let age = profile.age {
            parts.append("\(age)y")
        }
        if let height = profile.heightCm {
            parts.append("\(formatNumber(height)) cm")
        }
        if let weight = profile.weightKg {
            parts.append("\(formatNumber(weight)) kg")
        }
        guard !parts.isEmpty else { return nil }
        return "- Body: \(parts.joined(separator: ", "))"
    }

    private static func renderRecovery(_ recovery: [MuscleRecoveryState], calendar: Calendar) -> String {
        guard !recovery.isEmpty else { return noneLogged }
        let rows = recovery.sorted { $0.muscleGroup.rawValue < $1.muscleGroup.rawValue }.map { state in
            let last = state.lastTrainedAt.map { isoDate($0, calendar: calendar) } ?? "—"
            let preparedness = Int(state.recoveryPercentage.rounded())
            return "| \(state.muscleGroup.displayName) | \(preparedness) | \(last) |"
        }
        return (["| Muscle | Preparedness | Last trained |"] + rows).joined(separator: "\n")
    }

    private static func renderStats(
        _ stats: [UserExerciseStats],
        names: [String: String],
        generatedAt: Date
    ) -> String {
        let lines = stats.compactMap { statsLine($0, names: names, generatedAt: generatedAt) }
            .sorted()
        return lines.isEmpty ? noneLogged : lines.joined(separator: "\n")
    }

    private static func statsLine(
        _ stats: UserExerciseStats,
        names: [String: String],
        generatedAt: Date
    ) -> String? {
        let hasSignal = stats.lastWeightKg != nil
            || stats.lastReps != nil
            || stats.estimatedOneRepMax != nil
            || !stats.recentSets.isEmpty
        guard hasSignal else { return nil }
        let name = names[stats.exerciseId] ?? stats.exerciseId
        var parts: [String] = []
        switch (stats.lastWeightKg, stats.lastReps) {
        case let (weight?, reps?):
            parts.append("last \(formatNumber(weight)) kg × \(reps)")
        case let (weight?, nil):
            parts.append("last \(formatNumber(weight)) kg")
        case let (nil, reps?):
            parts.append("last \(reps) reps")
        default:
            break
        }
        if let e1RM = stats.estimatedOneRepMax {
            parts.append("e1RM \(Int(e1RM.rounded()))")
        }
        parts.append("trend \(stats.volumeTrend.displayName)")
        var line = "- \(name): \(parts.joined(separator: ", "))"
        if stats.preferVariation {
            line += "; prefer variation"
        }
        if stats.isInDeloadWeek(at: generatedAt) {
            line += "; in deload"
        }
        return line
    }

    private static func renderWorkouts(
        _ sessions: [WorkoutSession],
        names: [String: String],
        calendar: Calendar
    ) -> String {
        let completed = sessions.filter { $0.status == .completed }.sorted { lhs, rhs in
            let left = lhs.completedAt ?? lhs.startedAt ?? .distantPast
            let right = rhs.completedAt ?? rhs.startedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.id.uuidString > rhs.id.uuidString
        }
        guard !completed.isEmpty else { return noneLogged }
        return completed.map { sessionBlock($0, names: names, calendar: calendar) }
            .joined(separator: "\n")
    }

    private static func sessionBlock(
        _ session: WorkoutSession,
        names: [String: String],
        calendar: Calendar
    ) -> String {
        let dateText: String
        if let date = session.completedAt ?? session.startedAt {
            dateText = isoDate(date, calendar: calendar)
        } else {
            dateText = "Unknown date"
        }
        let title = session.title.isEmpty ? "Workout" : session.title
        var lines = ["### \(dateText) — \(title)"]
        var meta: [String] = []
        meta.append("Duration \(durationMinutes(session))m")
        if let difficulty = session.perceivedDifficulty {
            meta.append("Difficulty \(difficulty)/10")
        }
        if let focus = session.splitDayFocus {
            meta.append("Focus: \(focus.displayName)")
        }
        if !meta.isEmpty {
            lines.append(meta.joined(separator: " | "))
        }
        if let notes = session.notes, !notes.isEmpty {
            lines.append("Notes: \(notes)")
        }
        let exercises = session.exercises.sorted { $0.orderIndex < $1.orderIndex }
        for exercise in exercises {
            let name = names[exercise.exerciseId] ?? exercise.exerciseId
            if exercise.wasSkipped {
                if let reason = exercise.skipReason, !reason.isEmpty {
                    lines.append("- \(name): skipped — \(reason)")
                } else {
                    lines.append("- \(name): skipped")
                }
                continue
            }
            guard !exercise.completedSets.isEmpty else { continue }
            let sets = exercise.completedSets.sorted { $0.setIndex < $1.setIndex }
                .map(setToken)
                .joined(separator: ", ")
            lines.append("- \(name): \(sets)")
        }
        return lines.joined(separator: "\n")
    }

    private static func durationMinutes(_ session: WorkoutSession) -> Int {
        if let start = session.startedAt, let end = session.completedAt {
            return Int((end.timeIntervalSince(start) / 60).rounded())
        }
        return session.estimatedDurationMinutes
    }

    private static func setToken(_ set: CompletedSet) -> String {
        let core: String
        if set.reps > 0 {
            let load = set.weightKg.map(formatNumber) ?? "BW"
            core = "\(load)×\(set.reps)"
        } else if let duration = set.durationSeconds {
            if let weight = set.weightKg {
                core = "\(formatNumber(weight))×\(duration)s"
            } else {
                core = "\(duration)s"
            }
        } else if let distance = set.distanceMeters {
            core = "\(formatNumber(distance))m"
        } else {
            let load = set.weightKg.map(formatNumber) ?? "BW"
            core = "\(load)×0"
        }
        var token = core
        if let rpe = set.rpe {
            token += " @ RPE \(formatNumber(rpe))"
        }
        if let rir = set.rir {
            token += " RIR \(rir)"
        }
        if set.isWarmup { token += " (wu)" }
        if set.isCooldown { token += " (cd)" }
        if set.isFailure { token += " (fail)" }
        return token
    }

    private static func renderProtein(
        _ entries: [ProteinEntry],
        goalGrams: Double,
        calendar: Calendar
    ) -> String {
        guard !entries.isEmpty else { return noneLogged }
        var totals: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            totals[day, default: 0] += entry.proteinGrams
        }
        let goal = Int(goalGrams.rounded())
        let lines = totals.keys.sorted(by: >).map { day in
            let grams = Int((totals[day] ?? 0).rounded())
            return "- \(isoDate(day, calendar: calendar)): \(grams) g (goal \(goal))"
        }
        return lines.joined(separator: "\n")
    }

    static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func formatNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return String(Int(rounded))
        }
        var text = String(format: "%.2f", value)
        while text.contains("."), text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }
}
```

`isoDate` / `formatNumber` may be `private` if tests do not need them; keep them file-private unless a test requires otherwise. Stats sort is lexicographic on the full line, which sorts by display name then the rest of the line (stable enough; ids only appear when names are missing).

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/TrainingDataMarkdownExporterTests
```

Expected: PASS. If `empty_shell` still appears, the qualifying-stats guard is wrong. If Upper is not before Lower, sort is ascending.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/TrainingDataMarkdownExporter.swift \
  HotBod/Tests/UnitTests/TrainingDataMarkdownExporterTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: add training-data markdown exporter

Pure renderer so LLM-facing markdown can be unit-tested without Settings or ShareSheet.
EOF
)"
```

---

### Task 2: AppEnvironment gather + temp file

**Files:**
- Create: `HotBod/App/AppEnvironment+TrainingExport.swift`
- Create: `HotBod/Tests/Integration/TrainingDataExportIntegrationTests.swift`

**Interfaces:**
- Consumes: `TrainingDataMarkdownExporter.render`, `TrainingDataMarkdownExporter.filename`, `TrainingDataExportSnapshot`
- Produces:
  ```swift
  struct TrainingDataExport: Equatable {
      var markdown: String
      var fileURL: URL
      var filename: String
  }

  enum TrainingDataExportError: Error, Equatable {
      case fileWriteFailed
  }

  extension AppEnvironment {
      func makeTrainingDataExport(
          generatedAt: Date = Date(),
          calendar: Calendar = .current,
          fileManager: FileManager = .default
      ) async throws -> TrainingDataExport
  }
  ```

  Gathering rules:
  - `var profile = userProfile; profile?.name = nil`
  - Sessions: `workoutRepository.fetchSessions()`, keep `.completed` only (exporter also filters).
  - Protein: `nutritionRepository.fetchEntries(from: .distantPast, to: Date().addingTimeInterval(1))`
  - Recovery: `recoveryRepository.fetchRecoveryStates()`; if the array is empty, use `recoveryStates`.
  - Stats: `exerciseStatsRepository.fetchStats()`
  - Names: `Dictionary(uniqueKeysWithValues: (try await exerciseRepository.fetchAll()).map { ($0.id, $0.name) })`
  - `proteinGoalGrams`: `userProfile?.proteinGoalGrams ?? 145`
  - Temp dir: `fileManager.temporaryDirectory`
  - Delete existing `hotbod-training-*.md` in that directory before write
  - Write UTF-8; on write failure throw `TrainingDataExportError.fileWriteFailed`

Passing `fileManager` / `generatedAt` / `calendar` is a test seam. Production Settings calls `makeTrainingDataExport()` with defaults.

- [ ] **Step 1: Write the failing integration tests**

Create `HotBod/Tests/Integration/TrainingDataExportIntegrationTests.swift`:

```swift
import XCTest
@testable import HotBod

@MainActor
final class TrainingDataExportIntegrationTests: XCTestCase {
    func testMakeTrainingDataExportWritesFileOmitsNameAndSkipsIncomplete() async throws {
        let repos = TestRepositories.withCatalog()
        let env = AppEnvironment.makeForTests(repos: repos)

        var profile = UserProfile.empty()
        profile.name = "Zara Export"
        try await env.seedOnboardedProfile(profile)

        let completedAt = Date().addingTimeInterval(-3600)
        var completed = FixtureBuilders.makeWorkoutSession(status: .completed)
        completed.title = "Export Upper"
        completed.completedAt = completedAt
        completed.startedAt = completedAt.addingTimeInterval(-2400)
        completed.exercises[0].completedSets = [
            CompletedSet(setIndex: 0, weightKg: 60, reps: 8, completedAt: completedAt)
        ]
        try await env.workoutRepository.saveSession(completed)

        var incomplete = FixtureBuilders.makeWorkoutSession(status: .inProgress)
        incomplete.title = "Ghost Session"
        try await env.workoutRepository.saveSession(incomplete)

        try await env.nutritionRepository.saveEntry(
            FixtureBuilders.makeProteinEntry(grams: 40, date: Date().addingTimeInterval(-60))
        )

        let export = try await env.makeTrainingDataExport()

        XCTAssertTrue(export.markdown.contains("Export Upper"))
        XCTAssertFalse(export.markdown.contains("Zara Export"))
        XCTAssertFalse(export.markdown.contains("Ghost Session"))
        XCTAssertTrue(export.filename.hasPrefix("hotbod-training-"))
        XCTAssertTrue(export.filename.hasSuffix(".md"))
        XCTAssertEqual(export.fileURL.lastPathComponent, export.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: export.fileURL.path))
        let disk = try String(contentsOf: export.fileURL, encoding: .utf8)
        XCTAssertEqual(disk, export.markdown)
        XCTAssertTrue(export.markdown.contains("Not medical advice."))
    }

    func testEmptyHistoryStillExportsValidMarkdownFile() async throws {
        let env = AppEnvironment.makeForTests(repos: TestRepositories.empty())
        try await env.seedOnboardedProfile()
        let export = try await env.makeTrainingDataExport()
        XCTAssertTrue(export.markdown.contains("## Workouts"))
        XCTAssertTrue(export.markdown.contains("None logged."))
        XCTAssertTrue(FileManager.default.fileExists(atPath: export.fileURL.path))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/TrainingDataExportIntegrationTests
```

Expected: FAIL — `makeTrainingDataExport` not found.

- [ ] **Step 3: Implement gather + file write**

Create `HotBod/App/AppEnvironment+TrainingExport.swift`:

```swift
import Foundation

struct TrainingDataExport: Equatable {
    var markdown: String
    var fileURL: URL
    var filename: String
}

enum TrainingDataExportError: Error, Equatable {
    case fileWriteFailed
}

extension AppEnvironment {
    func makeTrainingDataExport(
        generatedAt: Date = Date(),
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) async throws -> TrainingDataExport {
        var profile = userProfile
        profile?.name = nil

        let sessions = ((try? await workoutRepository.fetchSessions()) ?? [])
            .filter { $0.status == .completed }
        let proteinEntries = (try? await nutritionRepository.fetchEntries(
            from: .distantPast,
            to: Date().addingTimeInterval(1)
        )) ?? []
        let fetchedRecovery = (try? await recoveryRepository.fetchRecoveryStates()) ?? []
        let recovery = fetchedRecovery.isEmpty ? recoveryStates : fetchedRecovery
        let exerciseStats = (try? await exerciseStatsRepository.fetchStats()) ?? []
        let exercises = (try? await exerciseRepository.fetchAll()) ?? []
        let exerciseNames = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })

        let snapshot = TrainingDataExportSnapshot(
            profile: profile,
            sessions: sessions,
            exerciseStats: exerciseStats,
            proteinEntries: proteinEntries,
            recovery: recovery,
            exerciseNames: exerciseNames,
            proteinGoalGrams: userProfile?.proteinGoalGrams ?? 145
        )
        let markdown = TrainingDataMarkdownExporter.render(
            snapshot,
            generatedAt: generatedAt,
            calendar: calendar
        )
        let filename = TrainingDataMarkdownExporter.filename(
            generatedAt: generatedAt,
            calendar: calendar
        )
        let directory = fileManager.temporaryDirectory
        try removePreviousTrainingExports(in: directory, fileManager: fileManager)
        let fileURL = directory.appendingPathComponent(filename)
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw TrainingDataExportError.fileWriteFailed
        }
        return TrainingDataExport(markdown: markdown, fileURL: fileURL, filename: filename)
    }

    private func removePreviousTrainingExports(in directory: URL, fileManager: FileManager) throws {
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.lastPathComponent.hasPrefix("hotbod-training-")
            && url.pathExtension == "md" {
            try? fileManager.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/TrainingDataExportIntegrationTests \
  -only-testing:HotBodTests/TrainingDataMarkdownExporterTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment+TrainingExport.swift \
  HotBod/Tests/Integration/TrainingDataExportIntegrationTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: gather training data export from AppEnvironment

Load completed sessions, protein, recovery, and stats, then write a temp markdown file for sharing.
EOF
)"
```

---

### Task 3: Settings Export row + share sheet

**Files:**
- Modify: `HotBod/Core/Localization/L10n.swift`
- Modify: `HotBod/Resources/Localizable.xcstrings` (add four keys only)
- Modify: `HotBod/Features/Settings/SettingsView.swift`
- Modify: `HotBod/Features/Settings/SettingsView+Profile.swift`

**Interfaces:**
- Consumes: `AppEnvironment.makeTrainingDataExport() async throws -> TrainingDataExport`
- Produces: Settings App section action `settings.exportTrainingData`; share items `[export.markdown, export.fileURL]` in that order
- Copy:
  - `settings.exportTrainingData` → `Export training data`
  - `settings.exportTrainingData.hint` → `Workouts, protein, and recovery as markdown. Copy or share the file.`
  - `settings.exportTrainingData.exporting` → `Exporting…`
  - `settings.exportTrainingData.failed` → `Export could not be created. Try again.`

- [ ] **Step 1: Add L10n keys**

In `HotBod/Core/Localization/L10n.swift`, inside `enum Settings`, after the existing integration keys:

```swift
static let exportTrainingData = String(localized: "settings.exportTrainingData")
static let exportTrainingDataHint = String(localized: "settings.exportTrainingData.hint")
static let exportTrainingDataExporting = String(localized: "settings.exportTrainingData.exporting")
static let exportTrainingDataFailed = String(localized: "settings.exportTrainingData.failed")
```

In `HotBod/Resources/Localizable.xcstrings`, insert **before** `"settings.integrations.healthExport"` (keep valid JSON commas). Each key:

```json
    "settings.exportTrainingData" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Export training data"
          }
        }
      }
    },
    "settings.exportTrainingData.exporting" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Exporting…"
          }
        }
      }
    },
    "settings.exportTrainingData.failed" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Export could not be created. Try again."
          }
        }
      }
    },
    "settings.exportTrainingData.hint" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Workouts, protein, and recovery as markdown. Copy or share the file."
          }
        }
      }
    },
```

Do not revert or include the unrelated `%@ → %@` / split-suggestion entries if they are already in the working tree.

- [ ] **Step 2: Add Settings state + share sheet**

In `HotBod/Features/Settings/SettingsView.swift`, add with the other `@State` properties:

```swift
@State var isExporting = false
@State var exportError: String?
@State var showExportShareSheet = false
@State var exportShareItems: [Any] = []
```

On `settingsBody`, after `.confirmationDialog` (before `.onAppear`):

```swift
.sheet(isPresented: $showExportShareSheet) {
    ShareSheet(items: exportShareItems)
}
```

`ShareSheet` already exists in `HotBod/Core/Components/ShareSheet.swift`. Do not create a second representable. Do not wrap this in a paywall.

- [ ] **Step 3: Add the App section row and export action**

In `SettingsView+Profile.swift` `appSection`, after the Name value row and **before** the `if !environment.isSupabaseConfigured` delete block:

```swift
SettingsComponents.divider
SettingsComponents.actionRow(
    title: isExporting ? L10n.Settings.exportTrainingDataExporting : L10n.Settings.exportTrainingData
) {
    Task { await exportTrainingData() }
}
.disabled(isExporting)
.accessibilityIdentifier("settings.exportTrainingData")
Text(L10n.Settings.exportTrainingDataHint)
    .font(ForgeTypography.caption)
    .foregroundStyle(ForgeColors.muted)
if let exportError {
    Text(exportError)
        .font(ForgeTypography.caption)
        .foregroundStyle(ForgeColors.destructive)
}
```

Add this method on the same `SettingsView` extension (same file, after `dismissSettings()`):

```swift
func exportTrainingData() async {
    guard !isExporting else { return }
    exportError = nil
    isExporting = true
    defer { isExporting = false }
    do {
        let export = try await environment.makeTrainingDataExport()
        exportShareItems = [export.markdown, export.fileURL]
        showExportShareSheet = true
    } catch {
        exportError = L10n.Settings.exportTrainingDataFailed
    }
}
```

Empty history is success (Task 2 already returns a valid file). Failure is only thrown write errors.

- [ ] **Step 4: Build to verify compile**

```bash
xcodegen generate
xcodebuild build -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
```

Expected: BUILD SUCCEEDED. Settings preview still compiles.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Core/Localization/L10n.swift \
  HotBod/Resources/Localizable.xcstrings \
  HotBod/Features/Settings/SettingsView.swift \
  HotBod/Features/Settings/SettingsView+Profile.swift
git commit -m "$(cat <<'EOF'
feat: export training data from Settings

Add a free Settings action that builds markdown and opens the system share sheet for copy or file share.
EOF
)"
```

Before committing, run `git diff --cached HotBod/Resources/Localizable.xcstrings`. The staged diff must contain **only** the four `settings.exportTrainingData*` keys. If unrelated keys are staged, edit the file so those keys stay uncommitted (leave them in the working tree if they were already dirty) and re-add the file.

---

### Task 4: Settings UI test + PR plan

**Files:**
- Modify: `HotBod/Tests/UITests/SettingsUITests.swift`
- Modify: `HotBod.xctestplan`

**Interfaces:**
- Consumes: accessibility id `settings.exportTrainingData`
- Produces: `testExportTrainingDataRowExists` on PR configuration

Do **not** assert the system share sheet.

- [ ] **Step 1: Add the UI test**

Append to `SettingsUITests`:

```swift
func testExportTrainingDataRowExists() {
    openSettings()
    let exportButton = app.buttons["settings.exportTrainingData"]
    for _ in 0..<8 where !exportButton.exists {
        app.swipeUp()
    }
    XCTAssertTrue(exportButton.waitForExistence(timeout: 8))
}
```

Leave existing `openSettings()` helper as-is.

- [ ] **Step 2: Add the test to the PR test plan**

In `HotBod.xctestplan`, under the PR configuration `HotBodUITests` `selectedTests` array, add:

```
"SettingsUITests/testExportTrainingDataRowExists"
```

Keep it JSON-valid (comma after the previous selected test). Nightly already runs all UI tests; no Nightly change.

- [ ] **Step 3: Run the UI test**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodUITests/SettingsUITests/testExportTrainingDataRowExists
```

Expected: PASS. If the button is missing, the identifier is not on the `Button` (must be on the `actionRow` result, not the caption `Text`).

- [ ] **Step 4: Commit**

```bash
git add HotBod/Tests/UITests/SettingsUITests.swift HotBod.xctestplan
git commit -m "$(cat <<'EOF'
test: cover Settings training data export row

Assert the export action is reachable in Settings and include it on the PR UI test list.
EOF
)"
```

---

### Task 5: Final verification

**Files:** none new

- [ ] **Step 1: Run exporter + integration tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/TrainingDataMarkdownExporterTests \
  -only-testing:HotBodTests/TrainingDataExportIntegrationTests
```

Expected: PASS.

- [ ] **Step 2: Build the app**

```bash
xcodebuild build -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke (if a simulator is available)**

Open Settings → App → Export training data. Confirm Exporting… then a share sheet. Copy should paste markdown starting with `# HotBod training export`. Save to Files should yield `hotbod-training-YYYY-MM-DD.md`. Profile name must not appear. Do not tap Delete All Data.

If no GUI simulator, skip this step and note it in the wrap-up.

No commit unless Steps 1–2 forced a fix; if they did, commit the fix as `fix: <what broke>` then re-run Steps 1–2.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Pure markdown renderer + snapshot types | 1 |
| Header, five sections, `None logged.`, disclaimer | 1 |
| Omit name / ids; completed sessions only; newest first | 1 |
| Warmup `(wu)`; protein daily totals; recovery table | 1 |
| Filename helper | 1 |
| `makeTrainingDataExport` gather + temp file | 2 |
| Empty history is success | 2 |
| Settings row, hint, exporting, error, ShareSheet `[String, URL]` | 3 |
| Not Pro-gated | 3 |
| UI test, no share-sheet assertion | 4 |
| L10n keys | 3 |
| `xcodegen` / pbxproj | 1–2 after new files |
| Build + tests | 5 |

No JSON export, no physique/photos, no `ProFeature` change, no `SettingsErrorMessages` change.
