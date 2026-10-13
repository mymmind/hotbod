# Workout Generator P0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the generator from progressing a stored suggestion a second time, ignore skipped or untrusted effort, and fit the full session — warmups, rest, transitions, conditioning, core, and cooldown — inside the duration target or say when priority work cannot.

**Architecture:** `SessionLoadPlanner` is the only planning read of `suggestedNextWeightKg`. `EffortFeedbackMapping` decides which RIR or RPE counts. `SessionDurationBudget` sheds optional blocks after the full session is assembled. Logging still owns progression through `ProgressiveOverload.updateStats`.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen (`xcodegen generate` after new `HotBod/` files), `HotBod.xctestplan` configuration **PR**.

**Spec:** `docs/superpowers/specs/2026-10-13-workout-generator-p0-design.md`

## Global Constraints

- iOS 26+, SwiftUI, SwiftData, MVVM + Services + Repositories.
- Local-first. The new profile, completed-set, and session-mode fields sync through the existing Supabase tables.
- No change to exercise selection, weekly set allocation, stimulus tags, family load transfer, strength-versus-volume trends, anchor blocks, provenance export, or the recovery fatigue model.
- Generated exercises and manually added exercises share one load planner.
- Session modifiers (deload, recovery, return-from-break, rounding, ceilings) are applied to the planned weight and are not written back onto `suggestedNextWeightKg`.
- Every defect gets a `testRegression_<issue>` test.
- The RIR sheet and the two new settings rows keep their behavior in domain functions. UI tests for those controls are exempt; the exemption comment lives in `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`. The existing Skip identifier `workout.rir.skip` stays.
- Simulator: `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0`. If that destination is missing, run `xcodebuild -scheme HotBod -showdestinations` and substitute an installed iPhone 26.x simulator.
- After new Swift files under `HotBod/`, run `xcodegen generate`. If `objectVersion` or `DEVELOPMENT_TEAM` churn, restore those baselines.
- Do not commit unrelated dirty files (`HotBod/Resources/Localizable.xcstrings`, `HotBod.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `docs/superpowers/plans/2026-09-08-personal-use-full-access.md`, `docs/superpowers/specs/2026-09-08-personal-use-full-access-design.md`).
- Do not delete `ProgressiveOverload.nextWeight(current:stats:)`. Unit tests still call it. Production planning must not.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Algorithms/SessionLoadPlanner.swift` | One read of stored weight plus one session modifier and one round |
| `HotBod/Domain/Algorithms/SessionDurationBudget.swift` | Shed optional blocks and build the rationale suffix |
| `HotBod/Domain/Algorithms/EffortFeedbackMapping.swift` | Status, trusted RPE, mark skipped / explicit |
| `HotBod/Domain/Algorithms/Algorithms.swift` | Pass the trust flag through `updateStats` and `reapplyEffortTrust` |
| `HotBod/Domain/Algorithms/Phase2Algorithms.swift` | High-effort deload reads trusted RPE only |
| `HotBod/Domain/Algorithms/GenerationConstants.swift` | `Deload.loadMultiplier = 0.9`; stop using the flat warmup pad |
| `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift` | Duration estimate is work + rest + transitions |
| `HotBod/Domain/Algorithms/SessionExercisePlanner.swift` | Manual adds call `SessionLoadPlanner` |
| `HotBod/Domain/Algorithms/CoreFinisherPlanner.swift` | Return the appended finisher id |
| `HotBod/Domain/Algorithms/SessionStructurePlanner.swift` | Return the appended conditioning id |
| `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` | Planner + budget replace the second progression and `trimToDuration` |
| `HotBod/Domain/Models/DomainModels.swift` | Effort status, profile flags, session mode |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` | Skip / dismiss / prompt-off write `skipped` |
| `HotBod/Features/Settings/SettingsView+SessionStructure.swift` | Two effort toggles |
| `HotBod/Features/Settings/SettingsDraftEditing.swift` | Trust-flag change refreshes today's workout |
| `HotBod/App/AppEnvironment+Profile.swift` | Reapply suggestions before saving the trust flag |
| `HotBod/App/AppEnvironment+WorkoutSession.swift` | Pass the trust flag into `updateStats`; copy `sessionMode` |
| `HotBod/Data/Remote/SupabaseDTOs.swift` | Sync the new columns |
| `HotBod/Data/Remote/SupabaseCloudSyncService+Pull.swift` | Decode null status as `unknown`, null mode as `standard` |
| `supabase/migrations/20261013120000_effort_feedback_status.sql` | Columns |
| `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift` | Three regression tests |
| `HotBod/Tests/Integration/IntegrationFlowTests.swift` | `testRegression_untrustedHistoricEffort` |

---

### Task 1: SessionLoadPlanner

**Files:**
- Create: `HotBod/Domain/Algorithms/SessionLoadPlanner.swift`
- Create: `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`
- Modify: `HotBod/Domain/Algorithms/GenerationConstants.swift` (`Deload` enum)

**Interfaces:**
- Consumes: `GenerationConstants.RecoverySession.weightMultiplier`, `GenerationConstants.Deload.reEntryWeightMultiplier`, `GenerationConstants.Weight.roundToAvailable`
- Produces: `GenerationConstants.Deload.loadMultiplier: Double`, `SessionLoadPlanner.Input`, `SessionLoadPlanner.plannedWeightKg(_:) -> Double`

- [ ] **Step 1: Write the failing test**

Create `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`:

```swift
import XCTest
@testable import HotBod

// UI exemption: the RIR sheet and the two settings rows are user-facing.
// Their programming effects are covered by testRegression_skippedEffort and
// testRegression_untrustedHistoricEffort. No new UI test is added in this release.
// The Skip control keeps accessibility identifier workout.rir.skip.

final class WorkoutGeneratorP0Tests: XCTestCase {
    func testRegression_doubleProgression() {
        let stored = SessionLoadPlanner.Input(
            suggestedNextWeightKg: 67.5,
            lastWeightKg: 65,
            sessionMode: .standard,
            isInDeloadWeek: false,
            returningFromBreak: false,
            equipment: [.barbell],
            ceilings: [:],
            fallbackWeightKg: 20
        )
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)

        for trend in [TrendDirection.stable, .increasing, .decreasing] {
            _ = trend
            XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(stored), 67.5)
        }

        var deload = stored
        deload.isInDeloadWeek = true
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(deload), 60)
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(deload), 60)

        var recovery = stored
        recovery.sessionMode = .recovery
        let recoveryOnce = SessionLoadPlanner.plannedWeightKg(recovery)
        XCTAssertEqual(recoveryOnce, SessionLoadPlanner.plannedWeightKg(recovery))
        XCTAssertEqual(
            recoveryOnce,
            GenerationConstants.Weight.roundToAvailable(67.5 * 0.7, equipment: [.barbell])
        )

        var reentry = stored
        reentry.returningFromBreak = true
        let reentryOnce = SessionLoadPlanner.plannedWeightKg(reentry)
        XCTAssertEqual(reentryOnce, SessionLoadPlanner.plannedWeightKg(reentry))
        XCTAssertEqual(
            reentryOnce,
            GenerationConstants.Weight.roundToAvailable(
                67.5 * GenerationConstants.Deload.reEntryWeightMultiplier,
                equipment: [.barbell]
            )
        )

        var loggedOnly = stored
        loggedOnly.suggestedNextWeightKg = nil
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(loggedOnly), 65)

        var cold = stored
        cold.suggestedNextWeightKg = nil
        cold.lastWeightKg = nil
        XCTAssertEqual(SessionLoadPlanner.plannedWeightKg(cold), 20)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_doubleProgression
```

Expected: FAIL — `SessionLoadPlanner` not found.

- [ ] **Step 3: Add the deload multiplier and planner**

In `GenerationConstants.Deload`, add:

```swift
static let loadMultiplier = 0.9
```

Create `HotBod/Domain/Algorithms/SessionLoadPlanner.swift`:

```swift
import Foundation

enum SessionLoadPlanner {
    struct Input {
        var suggestedNextWeightKg: Double?
        var lastWeightKg: Double?
        var sessionMode: SessionMode
        var isInDeloadWeek: Bool
        var returningFromBreak: Bool
        var equipment: [Equipment]
        var ceilings: [Equipment: Double]
        var fallbackWeightKg: Double
    }

    static func plannedWeightKg(_ input: Input) -> Double {
        let base = input.suggestedNextWeightKg ?? input.lastWeightKg ?? input.fallbackWeightKg
        let scaled: Double
        if input.sessionMode == .recovery {
            scaled = base * GenerationConstants.RecoverySession.weightMultiplier
        } else if input.isInDeloadWeek {
            scaled = base * GenerationConstants.Deload.loadMultiplier
        } else if input.returningFromBreak {
            scaled = base * GenerationConstants.Deload.reEntryWeightMultiplier
        } else {
            scaled = base
        }
        return GenerationConstants.Weight.roundToAvailable(
            scaled,
            equipment: input.equipment,
            ceilings: input.ceilings
        )
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_doubleProgression
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/SessionLoadPlanner.swift \
  HotBod/Domain/Algorithms/GenerationConstants.swift \
  HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift \
  docs/superpowers/specs/2026-10-13-workout-generator-p0-design.md \
  docs/superpowers/plans/2026-10-13-workout-generator-p0.md
git commit -m "$(cat <<'EOF'
Add a single session load planner so a stored suggestion is not progressed twice.

EOF
)"
```

---

### Task 2: Use the planner for generated and manual exercises

**Files:**
- Modify: `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` (`planExercise`, about lines 596–627)
- Modify: `HotBod/Domain/Algorithms/SessionExercisePlanner.swift` (`makeWorkoutExercise`)
- Modify: `HotBod/Domain/Algorithms/Algorithms.swift` (comment above `nextWeight(current:stats:)`)
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`WorkoutSession`)
- Modify: `HotBod/App/AppEnvironment+WorkoutSession.swift` (session start)
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` (`appendExercise`)
- Test: `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`

**Interfaces:**
- Consumes: `SessionLoadPlanner.plannedWeightKg(_:)`
- Produces: `WorkoutSession.sessionMode: SessionMode`, `SessionExercisePlanner.makeWorkoutExercise(..., sessionMode: SessionMode = .standard, ...)`

- [ ] **Step 1: Write the failing service test**

Append to `WorkoutGeneratorP0Tests`:

```swift
func testRegression_doubleProgressionGeneratedWorkoutMatchesPlanner() async throws {
    let catalog = try await LocalExerciseRepository().fetchAll()
    let stats = catalog.map { exercise in
        var stat = UserExerciseStats(
            exerciseId: exercise.id,
            lastWeightKg: 65,
            suggestedNextWeightKg: 67.5,
            preferredRepRangeMin: 8,
            preferredRepRangeMax: 12
        )
        stat.volumeTrend = .increasing
        return stat
    }
    let profile = UserProfile.empty()
    let input = WorkoutGenerationInput(
        userProfile: profile,
        goal: profile.goal,
        experienceLevel: profile.experienceLevel,
        availableEquipment: profile.availableEquipment,
        targetDurationMinutes: 45,
        preferredMuscleGroups: [],
        avoidedMuscleGroups: [],
        injuries: [],
        recentWorkouts: [],
        muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 100.0) }),
        exerciseStats: stats,
        userPreferences: WorkoutPreferences(),
        readiness: ReadinessInput(soreness: .none),
        splitDayFocus: .push
    )
    let service = RulesWorkoutGenerationService()
    let first = try await service.generate(input: input)
    let second = try await service.generate(input: input)
    let map = ExerciseCatalog.indexedById(catalog)

    func assertMatchesPlanner(_ workout: GeneratedWorkout) {
        for planned in workout.exercises {
            guard let exercise = map[planned.exerciseId],
                  let stat = stats.first(where: { $0.exerciseId == exercise.id }) else { continue }
            let expected = SessionLoadPlanner.plannedWeightKg(
                SessionLoadPlanner.Input(
                    suggestedNextWeightKg: stat.suggestedNextWeightKg,
                    lastWeightKg: stat.lastWeightKg,
                    sessionMode: workout.sessionMode,
                    isInDeloadWeek: stat.isInDeloadWeek,
                    returningFromBreak: stat.returningFromBreak,
                    equipment: exercise.equipment,
                    ceilings: profile.maxAvailableWeightKg,
                    fallbackWeightKg: 0
                )
            )
            for set in planned.targetSets where !set.isWarmup && !set.isCooldown {
                guard let weight = set.targetWeightKg else { continue }
                XCTAssertEqual(weight, expected, accuracy: 0.01, "\(exercise.id)")
            }
        }
    }

    assertMatchesPlanner(first)
    assertMatchesPlanner(second)
    let firstWeights = first.exercises.flatMap { $0.targetSets.compactMap(\.targetWeightKg) }
    let secondWeights = second.exercises.flatMap { $0.targetSets.compactMap(\.targetWeightKg) }
    XCTAssertEqual(firstWeights, secondWeights)

    let bench = try XCTUnwrap(map["bench_press"])
    let benchStats = try XCTUnwrap(stats.first { $0.exerciseId == "bench_press" })
    let manual = SessionExercisePlanner.makeWorkoutExercise(
        exercise: bench,
        orderIndex: 0,
        experience: .intermediate,
        goal: .buildMuscle,
        bodyWeightKg: 80,
        stats: benchStats,
        sessionMode: .standard
    )
    let manualWeight = try XCTUnwrap(manual.plannedSets.first { !$0.isWarmup }?.targetWeightKg)
    let expected = SessionLoadPlanner.plannedWeightKg(
        SessionLoadPlanner.Input(
            suggestedNextWeightKg: 67.5,
            lastWeightKg: 65,
            sessionMode: .standard,
            isInDeloadWeek: false,
            returningFromBreak: false,
            equipment: bench.equipment,
            ceilings: [:],
            fallbackWeightKg: 0
        )
    )
    XCTAssertEqual(manualWeight, expected, accuracy: 0.01)
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_doubleProgressionGeneratedWorkoutMatchesPlanner
```

Expected: FAIL — at least one planned weight is above the planner output (the second increment).

- [ ] **Step 3: Wire the planner**

Above `nextWeight(current:stats:)` in `Algorithms.swift`, add:

```swift
/// Historical volume-trend formula. Workout planning uses SessionLoadPlanner.
```

In `planExercise`, replace the `var weight` branch that calls `ProgressiveOverload.nextWeight(current:stats:)` and the following `roundToAvailable` with:

```swift
let weight = SessionLoadPlanner.plannedWeightKg(
    SessionLoadPlanner.Input(
        suggestedNextWeightKg: stats?.suggestedNextWeightKg,
        lastWeightKg: stats?.lastWeightKg,
        sessionMode: sessionMode,
        isInDeloadWeek: stats?.isInDeloadWeek == true,
        returningFromBreak: stats?.returningFromBreak == true,
        equipment: exercise.equipment,
        ceilings: input.userProfile.maxAvailableWeightKg,
        fallbackWeightKg: defaultWeight(
            for: exercise,
            experience: input.experienceLevel,
            bodyweightKg: input.userProfile.weightKg
        )
    )
)
```

Keep the existing `canPlanExternalLoad` gate. Warmups keep using this `weight`.

Add `sessionMode: SessionMode = .standard` to `makeWorkoutExercise`, placed before `weightCeilings`. Pass it through `makePlannedExercise`. Replace the `planningWeightKg` / `suggestedStartWeight` / `roundToAvailable` block with `SessionLoadPlanner.plannedWeightKg` using that mode, `stats?.isInDeloadWeek == true`, `stats?.returningFromBreak == true`, and `suggestedStartWeight` as `fallbackWeightKg`.

On `WorkoutSession`, add `var sessionMode: SessionMode = .standard` to the stored properties, `CodingKeys`, the memberwise init (default `.standard`), decode (`decodeIfPresent` default `.standard`), and encode.

In `resumeOrStartWorkout`, pass `sessionMode: workout.sessionMode` into `WorkoutSession(...)`.

In `appendExercise`, pass `sessionMode: session.sessionMode` into `makeWorkoutExercise`.

- [ ] **Step 4: Run the planner tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests
```

Expected: PASS. `xcodebuild build` must also succeed so the new `WorkoutSession` parameter did not break call sites. Defaults cover existing inits.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift \
  HotBod/Domain/Algorithms/SessionExercisePlanner.swift \
  HotBod/Domain/Algorithms/Algorithms.swift \
  HotBod/Domain/Models/DomainModels.swift \
  HotBod/App/AppEnvironment+WorkoutSession.swift \
  HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift \
  HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift
git commit -m "$(cat <<'EOF'
Plan generated and manual loads from the stored suggestion without a second increment.

EOF
)"
```

---

### Task 3: Effort status and trusted RPE

**Files:**
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`CompletedSet`)
- Modify: `HotBod/Domain/Algorithms/EffortFeedbackMapping.swift`
- Modify: `HotBod/Domain/Algorithms/Algorithms.swift` (`averageLoggedRPE`, `applyProgressionPolicy`, `updateStats`)
- Modify: `HotBod/Domain/Algorithms/Phase2Algorithms.swift` (`analyzeDeloadNeed`, `updateDeloadState`)
- Test: `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`

**Interfaces:**
- Consumes: `EffortFeedbackMapping.effectiveRPE(rpe:rir:)`
- Produces: `EffortFeedbackStatus`, `CompletedSet.effortFeedbackStatus`, `EffortFeedbackMapping.trustedEffectiveRPE(rpe:rir:status:trustHistoric:) -> Double?`, `EffortFeedbackMapping.markSkipped(_:)`, `EffortFeedbackMapping.markExplicit(_:rir:)`, `ProgressiveOverload.updateStats(..., trustHistoricEffortFeedback: Bool = true)`, `ProgressiveOverload.reapplyEffortTrust(stats:trustHistoric:)`, `DeloadDetector.analyzeDeloadNeed(..., trustHistoricEffortFeedback: Bool = true)`, `DeloadDetector.updateDeloadState(stats:trustHistoricEffortFeedback:now:)`

- [ ] **Step 1: Write the failing test**

Append to `WorkoutGeneratorP0Tests`:

```swift
func testRegression_skippedEffort() {
    var skipped = CompletedSet(setIndex: 0, weightKg: 65, reps: 10, rpe: 10, rir: 0, isFailure: true)
    EffortFeedbackMapping.markSkipped(&skipped)
    XCTAssertEqual(skipped.effortFeedbackStatus, .skipped)
    XCTAssertNil(skipped.rpe)
    XCTAssertNil(skipped.rir)
    XCTAssertFalse(skipped.isFailure)

    var explicit = CompletedSet(setIndex: 0, weightKg: 65, reps: 10)
    EffortFeedbackMapping.markExplicit(&explicit, rir: 0)
    XCTAssertEqual(explicit.effortFeedbackStatus, .explicit)
    XCTAssertEqual(explicit.rir, 0)
    XCTAssertEqual(explicit.rpe, 10)
    XCTAssertTrue(explicit.isFailure)

    var easy = explicit
    EffortFeedbackMapping.markExplicit(&easy, rir: 2)
    XCTAssertFalse(easy.isFailure)

    let planned = [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
    let skippedSets = [CompletedSet(setIndex: 0, weightKg: 100, reps: 10, effortFeedbackStatus: .skipped)]
    let silentSets = [CompletedSet(setIndex: 0, weightKg: 100, reps: 10)]
    let skippedStats = ProgressiveOverload.updateStats(
        existing: nil, exerciseId: "bench_press", completedSets: skippedSets,
        plannedSets: planned, trustHistoricEffortFeedback: false
    )
    let silentStats = ProgressiveOverload.updateStats(
        existing: nil, exerciseId: "bench_press", completedSets: silentSets,
        plannedSets: planned, trustHistoricEffortFeedback: false
    )
    XCTAssertEqual(skippedStats.suggestedNextWeightKg, silentStats.suggestedNextWeightKg)
    XCTAssertEqual(skippedStats.suggestedNextWeightKg, 102.5)

    let hardSets = [
        CompletedSet(setIndex: 0, weightKg: 100, reps: 10, rpe: 10, rir: 0, effortFeedbackStatus: .explicit)
    ]
    let hardStats = ProgressiveOverload.updateStats(
        existing: nil, exerciseId: "bench_press", completedSets: hardSets,
        plannedSets: planned, trustHistoricEffortFeedback: false
    )
    XCTAssertEqual(hardStats.suggestedNextWeightKg, 100, accuracy: 0.1)

    var historic = UserExerciseStats(
        exerciseId: "bench_press", lastWeightKg: 100, lastReps: 10,
        suggestedNextWeightKg: 100, preferredRepRangeMin: 8, preferredRepRangeMax: 10
    )
    historic.recentSets = [
        CompletedSet(setIndex: 0, weightKg: 100, reps: 10, rir: 0, effortFeedbackStatus: .unknown)
    ]
    historic.deloadStartedAt = Date()
    let trusted = EffortFeedbackMapping.trustedEffectiveRPE(
        rpe: nil, rir: 0, status: .unknown, trustHistoric: true
    )
    let ignored = EffortFeedbackMapping.trustedEffectiveRPE(
        rpe: nil, rir: 0, status: .unknown, trustHistoric: false
    )
    XCTAssertEqual(trusted, 10)
    XCTAssertNil(ignored)

    var untrusted = historic
    ProgressiveOverload.reapplyEffortTrust(stats: &untrusted, trustHistoric: false)
    XCTAssertEqual(untrusted.lastWeightKg, 100)
    XCTAssertEqual(untrusted.lastReps, 10)
    XCTAssertNotNil(untrusted.deloadStartedAt)
    XCTAssertEqual(untrusted.suggestedNextWeightKg, 102.5)

    let legacySet = #"{"id":"00000000-0000-0000-0000-000000000001","setIndex":0,"reps":8,"completedAt":"2026-10-13T12:00:00Z","isWarmup":false,"isFailure":false}"#
    let decoded = try! JSONDecoder().decode(CompletedSet.self, from: Data(legacySet.utf8))
    XCTAssertEqual(decoded.effortFeedbackStatus, .unknown)
}
```

`CompletedSet` date decoding uses the project's decoder strategy. If this JSON fails on the date, build the legacy payload with `JSONEncoder().encode` of a set, strip the `effortFeedbackStatus` key from the JSON object, and decode that.

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_skippedEffort
```

Expected: FAIL — `effortFeedbackStatus` or `markSkipped` is missing.

- [ ] **Step 3: Implement status and trust**

Add:

```swift
enum EffortFeedbackStatus: String, Codable, Hashable {
    case explicit
    case skipped
    case unknown
}
```

On `CompletedSet`, add `var effortFeedbackStatus: EffortFeedbackStatus = .unknown`. Include it in `CodingKeys`, the memberwise init (default `.unknown`), encode, and decode with `decodeIfPresent` default `.unknown`.

Add to `EffortFeedbackMapping`:

```swift
static func trustedEffectiveRPE(
    rpe: Double?,
    rir: Int?,
    status: EffortFeedbackStatus,
    trustHistoric: Bool
) -> Double? {
    switch status {
    case .explicit:
        return effectiveRPE(rpe: rpe, rir: rir)
    case .skipped:
        return nil
    case .unknown:
        guard trustHistoric else { return nil }
        return effectiveRPE(rpe: rpe, rir: rir)
    }
}

static func markSkipped(_ set: inout CompletedSet) {
    set.effortFeedbackStatus = .skipped
    set.rir = nil
    set.rpe = nil
    set.isFailure = false
}

static func markExplicit(_ set: inout CompletedSet, rir: Int) {
    set.effortFeedbackStatus = .explicit
    set.rir = rir
    set.rpe = rpe(fromRIR: rir)
    set.isFailure = rir == 0
}
```

Change `averageEffectiveRPE` to:

```swift
static func averageEffectiveRPE(
    from sets: [CompletedSet],
    trustHistoric: Bool = true
) -> Double? {
    let working = sets.filter(isWorkingSet)
    guard !working.isEmpty else { return nil }
    let values = working.compactMap {
        trustedEffectiveRPE(rpe: $0.rpe, rir: $0.rir, status: $0.effortFeedbackStatus, trustHistoric: trustHistoric)
    }
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}
```

`averageLoggedRPE(from:trustHistoric:)` forwards that flag. Default `true` keeps existing callers compiling.

`updateStats` gains `trustHistoricEffortFeedback: Bool = true` and passes it to `averageLoggedRPE` inside `applyProgressionPolicy` and to both `DeloadDetector.updateDeloadState` calls.

`applyProgressionPolicy` gains `trustHistoric: Bool` and uses it when reading RPE. Do not change the action rules.

`analyzeDeloadNeed` gains `trustHistoricEffortFeedback: Bool = true`. The high-effort filter uses `trustedEffectiveRPE` and `averageLoggedRPE(from:trustHistoric:)`. `updateDeloadState(stats:trustHistoricEffortFeedback:now:)` passes the flag through. Default `true`.

Add:

```swift
static func reapplyEffortTrust(stats: inout UserExerciseStats, trustHistoric: Bool) {
    guard let lastWeight = stats.lastWeightKg, let lastReps = stats.lastReps else { return }
    applyProgressionPolicy(
        to: &stats,
        lastWeight: lastWeight,
        workingSets: stats.recentSets.filter(EffortFeedbackMapping.isWorkingSet),
        hitTopOfRepRange: lastReps >= stats.preferredRepRangeMax,
        missedMinimumReps: lastReps < stats.preferredRepRangeMin,
        goal: stats.goalAtLastUpdate ?? .buildMuscle,
        equipment: [],
        weightCeilings: [:],
        trustHistoric: trustHistoric
    )
}
```

`reapplyEffortTrust` must not assign `deloadStartedAt`, `returningFromBreak`, `lastWeightKg`, or `lastReps`.

- [ ] **Step 4: Run effort and existing progression tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_skippedEffort \
  -only-testing:HotBodTests/ProgressiveOverloadTests \
  -only-testing:HotBodTests/WorkoutFeedbackDomainTests
```

Expected: PASS. Existing sets with RPE and the default `.unknown` status still count because `trustHistoric` defaults to true.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/DomainModels.swift \
  HotBod/Domain/Algorithms/EffortFeedbackMapping.swift \
  HotBod/Domain/Algorithms/Algorithms.swift \
  HotBod/Domain/Algorithms/Phase2Algorithms.swift \
  HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift
git commit -m "$(cat <<'EOF'
Ignore skipped effort and recompute load from reps when historic RIR is untrusted.

EOF
)"
```

---

### Task 4: Prompt, settings, and profile save

**Files:**
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`UserProfile`)
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` (`logSet`, `applyRIRSelection`)
- Modify: `HotBod/Features/Settings/SettingsView+SessionStructure.swift`
- Modify: `HotBod/Features/Settings/SettingsDraftEditing.swift`
- Modify: `HotBod/App/AppEnvironment+Profile.swift`
- Modify: `HotBod/App/AppEnvironment+WorkoutSession.swift` (`updateStats` call)
- Test: `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`

**Interfaces:**
- Consumes: `EffortFeedbackMapping.markSkipped`, `EffortFeedbackMapping.markExplicit`, `ProgressiveOverload.reapplyEffortTrust`, `ProgressiveOverload.updateStats(..., trustHistoricEffortFeedback:)`
- Produces: `UserProfile.promptForEffortFeedback: Bool`, `UserProfile.trustHistoricEffortFeedback: Bool`

- [ ] **Step 1: Write the failing profile test**

Append to `WorkoutGeneratorP0Tests`:

```swift
func testRegression_skippedEffortProfileDefaults() throws {
    let legacy = #"{"id":"00000000-0000-0000-0000-000000000002","goal":"buildMuscle","experienceLevel":"intermediate","trainingLocation":"commercialGym","availableEquipment":["barbell"],"preferredSessionLengthMinutes":45,"preferredSplit":"pushPullLegs","timeOfDayPreference":"flexible","limitations":["none"],"proteinGoalGrams":145,"photoTrackingEnabled":false,"createdAt":"2026-10-13T12:00:00Z","updatedAt":"2026-10-13T12:00:00Z"}"#
    let decoded = try JSONDecoder().decode(UserProfile.self, from: Data(legacy.utf8))
    XCTAssertTrue(decoded.promptForEffortFeedback)
    XCTAssertTrue(decoded.trustHistoricEffortFeedback)

    let original = UserProfile.empty()
    var draft = original
    draft.trustHistoricEffortFeedback = false
    XCTAssertTrue(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
    draft = original
    draft.promptForEffortFeedback = false
    XCTAssertFalse(SettingsDraftEditing.shouldRefreshWorkout(draft: draft, comparedTo: original))
}
```

If `UserProfile` date decoding rejects the ISO string, encode `UserProfile.empty()`, remove the two new keys, and decode that.

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_skippedEffortProfileDefaults
```

Expected: FAIL — the properties do not exist.

- [ ] **Step 3: Add the flags, the sheet writes, and the save hook**

On `UserProfile`, add `promptForEffortFeedback: Bool = true` and `trustHistoricEffortFeedback: Bool = true` to properties, `CodingKeys`, the memberwise init, `empty()`, `realigned(to:)`, encode, and decode (`decodeIfPresent` default `true`).

In `logSet`, `needsRIRPrompt` also requires `environment.userProfile?.promptForEffortFeedback != false`. After appending the completed set, call `EffortFeedbackMapping.markSkipped` on that set. `applyRIRSelection` replaces its RIR/RPE/`isFailure` writes with `EffortFeedbackMapping.markExplicit`. Skip and dismiss stay on `finishRIRPromptFlow` and do not write RIR.

Settings session-structure section, after the core finisher toggle:

```swift
SettingsComponents.divider
SettingsComponents.toggleRow(title: "Ask for reps in reserve", isOn: $draft.promptForEffortFeedback)
SettingsComponents.divider
SettingsComponents.toggleRow(title: "Use older effort entries", isOn: $draft.trustHistoricEffortFeedback)
```

`shouldRefreshWorkout` ORs `draft.trustHistoricEffortFeedback != original.trustHistoricEffortFeedback` and does not mention `promptForEffortFeedback`.

`updateUserProfile` reads the previous flag from `userProfile`. When it differs from the incoming profile:

1. `let stats = (try? await exerciseStatsRepository.fetchStats()) ?? []`
2. Map `reapplyEffortTrust(stats:trustHistoric: profile.trustHistoricEffortFeedback)` over them.
3. `try await exerciseStatsRepository.saveStats(...)`. On failure, set `syncMessage` and return `false` without saving the profile.
4. Save the profile as today.
5. Regenerate only when the caller passes `refreshWorkout: true`.

When the flag is unchanged, keep the current save-then-refresh order.

The completion path in `AppEnvironment+WorkoutSession` passes `trustHistoricEffortFeedback: userProfile?.trustHistoricEffortFeedback ?? true` into `updateStats`.

- [ ] **Step 4: Run the profile test and build**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_skippedEffortProfileDefaults
```

Expected: PASS, and the app target builds.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/DomainModels.swift \
  HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift \
  HotBod/Features/Settings/SettingsView+SessionStructure.swift \
  HotBod/Features/Settings/SettingsDraftEditing.swift \
  HotBod/App/AppEnvironment+Profile.swift \
  HotBod/App/AppEnvironment+WorkoutSession.swift \
  HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift
git commit -m "$(cat <<'EOF'
Treat skipped RIR as missing and let the profile ignore older effort entries.

EOF
)"
```

---

### Task 5: Sync the new columns

**Files:**
- Create: `supabase/migrations/20261013120000_effort_feedback_status.sql`
- Modify: `HotBod/Data/Remote/SupabaseDTOs.swift` (`ProfileRow`, `WorkoutSessionRow`, `CompletedSetRow`)
- Modify: `HotBod/Data/Remote/SupabaseCloudSyncService+Pull.swift`
- Test: `HotBod/Tests/UnitTests/SupabaseDTOTests.swift`

**Interfaces:**
- Consumes: `UserProfile.promptForEffortFeedback`, `UserProfile.trustHistoricEffortFeedback`, `CompletedSet.effortFeedbackStatus`, `WorkoutSession.sessionMode`
- Produces: SQL columns `prompt_for_effort_feedback`, `trust_historic_effort_feedback`, `effort_feedback_status`, `session_mode`

- [ ] **Step 1: Write the failing DTO test**

In `SupabaseDTOTests`, add:

```swift
func testEffortFieldsRoundTripAndDefault() throws {
    var profile = UserProfile.empty()
    profile.promptForEffortFeedback = false
    profile.trustHistoricEffortFeedback = false
    let row = ProfileRow(profile: profile)
    let restored = row.toUserProfile(fallback: nil)
    XCTAssertFalse(restored.promptForEffortFeedback)
    XCTAssertFalse(restored.trustHistoricEffortFeedback)

    let set = CompletedSet(
        setIndex: 1, weightKg: 40, reps: 8, effortFeedbackStatus: .skipped
    )
    let setRow = CompletedSetRow(set: set, workoutExerciseId: UUID())
    let data = try JSONEncoder().encode(setRow)
    let decoded = try JSONDecoder().decode(CompletedSetRow.self, from: data)
    XCTAssertEqual(decoded.effortFeedbackStatus, .skipped)

    var session = WorkoutSession(
        userId: UUID(), title: "Push", estimatedDurationMinutes: 45,
        exercises: [], status: .inProgress, sessionMode: .recovery
    )
    session = WorkoutSession(
        id: session.id, userId: session.userId, title: session.title,
        estimatedDurationMinutes: 45, exercises: [], status: .inProgress,
        sessionMode: .recovery
    )
    let sessionRow = WorkoutSessionRow(session: session)
    XCTAssertEqual(sessionRow.sessionMode, SessionMode.recovery.rawValue)
}
```

`CompletedSetRow.effortFeedbackStatus` is `String?`. `WorkoutSessionRow.sessionMode` is `String?`. The `WorkoutSession` call uses the memberwise labels from Task 2, including `sessionMode`.

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/SupabaseDTOTests/testEffortFieldsRoundTripAndDefault
```

Expected: FAIL — the DTO properties are missing.

- [ ] **Step 3: Add the migration and DTO fields**

Create `supabase/migrations/20261013120000_effort_feedback_status.sql`:

```sql
alter table public.profiles
  add column if not exists prompt_for_effort_feedback boolean not null default true,
  add column if not exists trust_historic_effort_feedback boolean not null default true;

alter table public.completed_sets
  add column if not exists effort_feedback_status text;

alter table public.workout_sessions
  add column if not exists session_mode text;
```

`ProfileRow` stores both bools as optional, coding keys `prompt_for_effort_feedback` and `trust_historic_effort_feedback`. Init from `UserProfile` copies them. `toUserProfile` uses `?? fallback?.promptForEffortFeedback ?? true` and the same for trust.

`CompletedSetRow.effortFeedbackStatus: String?` uses coding key `effort_feedback_status`. Init copies `set.effortFeedbackStatus.rawValue`. Decode with `decodeIfPresent`. Pull builds `CompletedSet` with `effortFeedbackStatus: EffortFeedbackStatus(rawValue: row.effortFeedbackStatus ?? "") ?? .unknown`.

`WorkoutSessionRow.sessionMode: String?` uses coding key `session_mode`. Init copies `session.sessionMode.rawValue`. Pull passes `sessionMode: SessionMode(rawValue: row.sessionMode ?? "") ?? .standard`.

- [ ] **Step 4: Run the DTO test**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/SupabaseDTOTests/testEffortFieldsRoundTripAndDefault
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261013120000_effort_feedback_status.sql \
  HotBod/Data/Remote/SupabaseDTOs.swift \
  HotBod/Data/Remote/SupabaseCloudSyncService+Pull.swift \
  HotBod/Tests/UnitTests/SupabaseDTOTests.swift
git commit -m "$(cat <<'EOF'
Sync effort-feedback status, effort trust, and session mode.

EOF
)"
```

---

### Task 6: Session duration budget

**Files:**
- Create: `HotBod/Domain/Algorithms/SessionDurationBudget.swift`
- Modify: `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift` (`estimateDurationMinutes`, and make `indexOfLowestScoredIsolationToDrop` internal)
- Modify: `HotBod/Domain/Algorithms/GenerationConstants.swift` (delete `durationWarmupSeconds` if unused)
- Test: `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`

**Interfaces:**
- Consumes: `WorkoutGenerationAlgorithms.estimateDurationMinutes(planned:) -> Int`, `WorkoutGenerationAlgorithms.indexOfLowestScoredIsolationToDrop(...)`
- Produces: `SessionDurationBudget.Result`, `SessionDurationBudget.apply(_:) -> Result`, `SessionDurationBudget.rationaleSuffix(...) -> String?`

- [ ] **Step 1: Write the failing test**

Append to `WorkoutGeneratorP0Tests`:

```swift
func testRegression_durationBudget() {
    let squatA = makeTestExercise(id: "squat_a", primaryMuscles: [.quads], pattern: .squat, mechanics: .compound, equipment: [.barbell])
    let squatB = makeTestExercise(id: "squat_b", primaryMuscles: [.quads], pattern: .squat, mechanics: .compound, equipment: [.barbell])
    let curl = makeTestExercise(id: "leg_curl", primaryMuscles: [.hamstrings], pattern: .isolation, mechanics: .isolation, equipment: [.machine])
    let core = makeTestExercise(id: "plank", primaryMuscles: [.abs], pattern: .isolation, mechanics: .isolation, equipment: [.bodyweight])
    let map = [squatA.id: squatA, squatB.id: squatB, curl.id: curl, core.id: core]

    func workingSets(_ count: Int, warmup: Bool) -> [PlannedSet] {
        var sets: [PlannedSet] = []
        if warmup {
            sets.append(PlannedSet(targetRepsMin: 5, targetRepsMax: 8, isWarmup: true))
        }
        sets.append(contentsOf: (0..<count).map { _ in
            PlannedSet(targetRepsMin: 8, targetRepsMax: 12)
        })
        return sets
    }

    var full: [PlannedExercise] = [
        PlannedExercise(exerciseId: squatA.id, orderIndex: 0, targetSets: workingSets(4, warmup: true), restSeconds: 120),
        PlannedExercise(exerciseId: squatB.id, orderIndex: 1, targetSets: workingSets(4, warmup: true), restSeconds: 120),
        PlannedExercise(exerciseId: curl.id, orderIndex: 2, targetSets: workingSets(3, warmup: true), restSeconds: 75)
    ]
    let beforeOptional = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: full)
    XCTAssertGreaterThanOrEqual(beforeOptional, 45)

    full.append(PlannedExercise(
        exerciseId: core.id, orderIndex: 3,
        targetSets: (0..<4).map { _ in PlannedSet(targetRepsMin: 10, targetRepsMax: 15) },
        restSeconds: 30
    ))
    full[0].targetSets.append(PlannedSet(targetRepsMin: 10, targetRepsMax: 15, isCooldown: true))

    let result = SessionDurationBudget.apply(
        SessionDurationBudget.Input(
            planned: full,
            scores: [squatA.id: 10, squatB.id: 10, curl.id: 4, core.id: 1],
            targetMuscles: [.quads, .hamstrings],
            exerciseMap: map,
            targetDurationMinutes: 45,
            coreFinisherExerciseId: core.id,
            conditioningExerciseId: nil
        )
    )
    XCTAssertFalse(result.planned.contains(where: { $0.exerciseId == core.id }))
    XCTAssertFalse(result.planned.contains(where: { $0.targetSets.contains(where: \.isCooldown) }))
    let firstWarmups = result.planned[0].targetSets.filter(\.isWarmup).count
    XCTAssertGreaterThan(firstWarmups, 0)
    if result.planned.count > 1 {
        XCTAssertFalse(result.planned[1].targetSets.contains(where: \.isWarmup))
    }
    let minutes = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: result.planned)
    let suffix = SessionDurationBudget.rationaleSuffix(
        removedCooldown: result.removedCooldown,
        removedConditioning: result.removedConditioning,
        removedCore: result.removedCore,
        removedExtraWarmups: result.removedExtraWarmups,
        removedAccessory: result.removedAccessory,
        targetMinutes: 45,
        estimatedMinutes: minutes
    )
    if minutes > 45 {
        XCTAssertTrue(suffix?.contains("Priority work exceeds the 45 min target.") == true)
    } else {
        XCTAssertLessThanOrEqual(minutes, 45)
    }
    XCTAssertTrue(suffix?.contains("core finisher") == true)

    let again = SessionDurationBudget.apply(
        SessionDurationBudget.Input(
            planned: result.planned,
            scores: [squatA.id: 10, squatB.id: 10, curl.id: 4],
            targetMuscles: [.quads, .hamstrings],
            exerciseMap: map,
            targetDurationMinutes: 45,
            coreFinisherExerciseId: nil,
            conditioningExerciseId: nil
        )
    )
    XCTAssertEqual(again.planned.map(\.exerciseId), result.planned.map(\.exerciseId))
    XCTAssertFalse(again.removedCooldown)
    XCTAssertFalse(again.removedCore)

    var oneSet = [PlannedExercise(
        exerciseId: squatA.id, orderIndex: 0,
        targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 12, isWarmup: true)],
        restSeconds: 30
    )]
    let withPad = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: oneSet)
    oneSet[0].targetSets.removeAll(where: \.isWarmup)
    let without = WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: oneSet)
    XCTAssertLessThan(without, withPad)

    XCTAssertEqual(
        SessionDurationBudget.rationaleSuffix(
            removedCooldown: true, removedConditioning: false, removedCore: false,
            removedExtraWarmups: false, removedAccessory: false,
            targetMinutes: 45, estimatedMinutes: 40
        ),
        "Adjusted to fit 45 min by removing cooldown."
    )
    XCTAssertEqual(
        SessionDurationBudget.rationaleSuffix(
            removedCooldown: true, removedConditioning: true, removedCore: true,
            removedExtraWarmups: false, removedAccessory: false,
            targetMinutes: 45, estimatedMinutes: 40
        ),
        "Adjusted to fit 45 min by removing cooldown, conditioning, and core finisher."
    )
    XCTAssertEqual(
        SessionDurationBudget.rationaleSuffix(
            removedCooldown: false, removedConditioning: false, removedCore: false,
            removedExtraWarmups: false, removedAccessory: false,
            targetMinutes: 45, estimatedMinutes: 52
        ),
        "Estimated 52 min. Priority work exceeds the 45 min target."
    )
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_durationBudget
```

Expected: FAIL — `SessionDurationBudget` is missing. The warmup-removal assertion on the estimate can also fail while the flat 300 seconds is still added, because both sides include it.

- [ ] **Step 3: Implement the estimate and the budget**

In `estimateDurationMinutes`, delete `+ GenerationConstants.Session.durationWarmupSeconds`. Delete `durationWarmupSeconds` if nothing else reads it. Leave `durationWarmupMinutes` if it already has no readers; do not start using it.

Remove `private` from `indexOfLowestScoredIsolationToDrop`.

Create `HotBod/Domain/Algorithms/SessionDurationBudget.swift`:

```swift
import Foundation

enum SessionDurationBudget {
    struct Input {
        var planned: [PlannedExercise]
        var scores: [String: Double]
        var targetMuscles: [MuscleGroup]
        var exerciseMap: [String: Exercise]
        var targetDurationMinutes: Int
        var coreFinisherExerciseId: String?
        var conditioningExerciseId: String?
    }

    struct Result {
        var planned: [PlannedExercise]
        var removedCooldown: Bool
        var removedConditioning: Bool
        var removedCore: Bool
        var removedExtraWarmups: Bool
        var removedAccessory: Bool
    }

    static func apply(_ input: Input) -> Result {
        var planned = input.planned
        var removedCooldown = false
        var removedConditioning = false
        var removedCore = false
        var removedExtraWarmups = false
        var removedAccessory = false

        func over() -> Bool {
            WorkoutGenerationAlgorithms.estimateDurationMinutes(planned: planned) > input.targetDurationMinutes
        }
        func reindex() {
            for index in planned.indices { planned[index].orderIndex = index }
        }

        if over() {
            for index in planned.indices {
                let before = planned[index].targetSets.count
                planned[index].targetSets.removeAll(where: \.isCooldown)
                if planned[index].targetSets.count != before { removedCooldown = true }
            }
        }
        if over(), let conditioningId = input.conditioningExerciseId,
           let index = planned.firstIndex(where: { $0.exerciseId == conditioningId }) {
            planned.remove(at: index)
            removedConditioning = true
            reindex()
        }
        if over(), let coreId = input.coreFinisherExerciseId {
            while over(), let index = planned.firstIndex(where: { $0.exerciseId == coreId }) {
                if planned[index].targetSets.isEmpty {
                    planned.remove(at: index)
                    removedCore = true
                    reindex()
                    break
                }
                planned[index].targetSets.removeLast()
                removedCore = true
                if planned[index].targetSets.isEmpty {
                    planned.remove(at: index)
                    reindex()
                }
            }
        }
        if over(), let keeper = planned.firstIndex(where: { $0.targetSets.contains(where: \.isWarmup) }) {
            for index in planned.indices where index != keeper {
                let before = planned[index].targetSets.count
                planned[index].targetSets.removeAll(where: \.isWarmup)
                if planned[index].targetSets.count != before { removedExtraWarmups = true }
            }
        }
        while over() {
            guard let drop = WorkoutGenerationAlgorithms.indexOfLowestScoredIsolationToDrop(
                planned: planned,
                scores: input.scores,
                targetMuscles: input.targetMuscles,
                exerciseMap: input.exerciseMap
            ) else { break }
            let exerciseId = planned[drop].exerciseId
            if exerciseId == input.coreFinisherExerciseId || exerciseId == input.conditioningExerciseId {
                break
            }
            guard input.exerciseMap[exerciseId]?.resolvedMechanics != .compound else { break }
            planned.remove(at: drop)
            removedAccessory = true
            reindex()
        }

        return Result(
            planned: planned,
            removedCooldown: removedCooldown,
            removedConditioning: removedConditioning,
            removedCore: removedCore,
            removedExtraWarmups: removedExtraWarmups,
            removedAccessory: removedAccessory
        )
    }

    static func rationaleSuffix(
        removedCooldown: Bool,
        removedConditioning: Bool,
        removedCore: Bool,
        removedExtraWarmups: Bool,
        removedAccessory: Bool,
        targetMinutes: Int,
        estimatedMinutes: Int
    ) -> String? {
        var parts: [String] = []
        if removedCooldown { parts.append("cooldown") }
        if removedConditioning { parts.append("conditioning") }
        if removedCore { parts.append("core finisher") }
        if removedExtraWarmups { parts.append("extra warm-ups") }
        if removedAccessory { parts.append("accessory work") }
        var sentences: [String] = []
        if !parts.isEmpty {
            sentences.append("Adjusted to fit \(targetMinutes) min by removing \(joined(parts)).")
        }
        if estimatedMinutes > targetMinutes {
            sentences.append("Estimated \(estimatedMinutes) min. Priority work exceeds the \(targetMinutes) min target.")
        }
        guard !sentences.isEmpty else { return nil }
        return sentences.joined(separator: " ")
    }

    private static func joined(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        case 2: return "\(parts[0]) and \(parts[1])"
        default:
            let head = parts.dropLast().joined(separator: ", ")
            return "\(head), and \(parts.last ?? "")"
        }
    }
}
```

Confirm `Exercise.resolvedMechanics` exists (it is already used by `indexOfLowestScoredIsolationToDrop`). If the drop helper skips the finisher because it is the last coverage for abs, the explicit core-id loop above already removed it before the accessory loop.

- [ ] **Step 4: Run the duration test and the existing trim test**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_durationBudget \
  -only-testing:HotBodTests/WorkoutGenerationTests/testTrimToDurationRespectsOverTargetFraction
```

Expected: PASS. The trim test calls `trimToDuration` directly and its fixture still estimates above 49 minutes without the flat pad.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/SessionDurationBudget.swift \
  HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift \
  HotBod/Domain/Algorithms/GenerationConstants.swift \
  HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift
git commit -m "$(cat <<'EOF'
Budget session duration from the sets that will actually be performed.

EOF
)"
```

---

### Task 7: Run the budget on the full session

**Files:**
- Modify: `HotBod/Domain/Algorithms/CoreFinisherPlanner.swift` (`appendCoreFinisher` returns `String?`)
- Modify: `HotBod/Domain/Algorithms/SessionStructurePlanner.swift` (`applyCardioBlock` returns `String?`)
- Modify: `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` (assembly order around lines 244–307)
- Test: `HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`

**Interfaces:**
- Consumes: `SessionDurationBudget.apply`, `SessionDurationBudget.rationaleSuffix`, `WorkoutGenerationAlgorithms.estimateDurationMinutes`
- Produces: `CoreFinisherPlanner.appendCoreFinisher(...) -> String?`, `SessionStructurePlanner.applyCardioBlock(...) -> String?`

- [ ] **Step 1: Write the failing generation test**

Append to `WorkoutGeneratorP0Tests`:

```swift
func testRegression_durationBudgetGeneratedSessionFitsOrExplains() async throws {
    var profile = UserProfile.empty()
    profile.preferredSessionLengthMinutes = 45
    profile.includeWarmupSets = true
    profile.includeCoreFinisher = true
    profile.includeCooldown = true
    profile.preferredSplit = .pushPullLegs
    let input = WorkoutGenerationInput(
        userProfile: profile,
        goal: .buildMuscle,
        experienceLevel: .intermediate,
        availableEquipment: profile.availableEquipment,
        targetDurationMinutes: 45,
        preferredMuscleGroups: [],
        avoidedMuscleGroups: [],
        injuries: [],
        recentWorkouts: [],
        muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 100.0) }),
        exerciseStats: [],
        userPreferences: WorkoutPreferences(),
        readiness: ReadinessInput(soreness: .none),
        splitDayFocus: .push
    )
    let workout = try await RulesWorkoutGenerationService().generate(input: input)
    let fits = workout.estimatedDurationMinutes <= 45
    let explains = workout.rationale.contains("Priority work exceeds the \(45) min target.")
    XCTAssertTrue(fits || explains)
    if !fits {
        XCTAssertEqual(workout.estimatedDurationMinutes, minutes(in: workout.rationale))
    }
}

private func minutes(in rationale: String) -> Int? {
    guard let range = rationale.range(of: #"Estimated (\d+) min"#, options: .regularExpression) else { return nil }
    let text = rationale[range]
    return Int(text.filter(\.isNumber))
}
```

Put `minutes(in:)` in the test class.

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_durationBudgetGeneratedSessionFitsOrExplains
```

Expected: FAIL — estimated duration is above 45 and the rationale has no overrun sentence. Core is still appended after the old trim.

- [ ] **Step 3: Assemble the full session, then budget**

`appendCoreFinisher` returns `String?`: the id it appended, or nil when it appends nothing. `applyCardioBlock` returns the cardio exercise id it inserted, or nil.

In `WorkoutGenerationService` standard-session assembly, delete the `trimToDuration` call. Keep grouping, then:

```swift
let conditioningId = SessionStructurePlanner.applyCardioBlock(...)
var coreId: String?
if input.userProfile.includeCoreFinisher {
    coreId = CoreFinisherPlanner.appendCoreFinisher(...)
}
if input.userProfile.includeCooldown {
    SessionStructurePlanner.appendCooldownSets(to: &planned, exerciseMap: exerciseMap)
}
let budgeted = SessionDurationBudget.apply(
    SessionDurationBudget.Input(
        planned: planned,
        scores: selection.scores,
        targetMuscles: targetMuscles,
        exerciseMap: exerciseMap,
        targetDurationMinutes: input.targetDurationMinutes,
        coreFinisherExerciseId: coreId,
        conditioningExerciseId: conditioningId
    )
)
planned = budgeted.planned
for index in planned.indices { planned[index].groupId = nil }
ExerciseGroupPlanner.applyGrouping(
    to: &planned,
    preference: input.userProfile.preferredExerciseGrouping,
    exerciseMap: exerciseMap
)
```

Run the same budget for `.recovery` with nil optional ids and without the second grouping pass. `estimatedDurationMinutes` is `estimateDurationMinutes` after that. `buildRationale` stays. If `rationaleSuffix(...)` is non-nil, append it after a space.

Existing callers of `appendCoreFinisher` and `applyCardioBlock` may ignore the new return value.

- [ ] **Step 4: Run the generation duration test**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests/testRegression_durationBudgetGeneratedSessionFitsOrExplains \
  -only-testing:HotBodTests/CoreFinisherPlannerTests \
  -only-testing:HotBodTests/WorkoutGenerationTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/CoreFinisherPlanner.swift \
  HotBod/Domain/Algorithms/SessionStructurePlanner.swift \
  HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift \
  HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift
git commit -m "$(cat <<'EOF'
Trim optional finishers only after the full session is on the clock.

EOF
)"
```

---

### Task 8: Historic-effort integration

**Files:**
- Test: `HotBod/Tests/Integration/IntegrationFlowTests.swift`
- Modify: none, unless the test shows `updateUserProfile` does not reapply. Then fix `HotBod/App/AppEnvironment+Profile.swift` only.

**Interfaces:**
- Consumes: `AppEnvironment.updateUserProfile(_:refreshWorkout:)`, `ProgressiveOverload.reapplyEffortTrust`, `SessionLoadPlanner.plannedWeightKg`

- [ ] **Step 1: Write the failing integration test**

Append to `IntegrationFlowTests`:

```swift
func testRegression_untrustedHistoricEffort() async throws {
    let env = makeEnvironment()
    var profile = UserProfile.empty()
    profile.trustHistoricEffortFeedback = true
    profile.reminderTrainingDays = Weekday.allCases
    try await env.seedOnboardedProfile(profile)

    var stats = UserExerciseStats(
        exerciseId: "bench_press",
        lastWeightKg: 100,
        lastReps: 10,
        suggestedNextWeightKg: 100,
        preferredRepRangeMin: 8,
        preferredRepRangeMax: 10
    )
    stats.recentSets = [
        CompletedSet(setIndex: 0, weightKg: 100, reps: 10, rir: 0, effortFeedbackStatus: .unknown)
    ]
    try await env.exerciseStatsRepository.saveStats([stats])

    profile.trustHistoricEffortFeedback = false
    let saved = await env.updateUserProfile(profile, refreshWorkout: true)
    XCTAssertTrue(saved)

    let stored = try await env.exerciseStatsRepository.fetchStats()
    let bench = try XCTUnwrap(stored.first { $0.exerciseId == "bench_press" })
    XCTAssertEqual(bench.lastWeightKg, 100)
    XCTAssertEqual(bench.suggestedNextWeightKg, 102.5)

    let planned = SessionLoadPlanner.plannedWeightKg(
        SessionLoadPlanner.Input(
            suggestedNextWeightKg: bench.suggestedNextWeightKg,
            lastWeightKg: bench.lastWeightKg,
            sessionMode: .standard,
            isInDeloadWeek: bench.isInDeloadWeek,
            returningFromBreak: bench.returningFromBreak,
            equipment: [.barbell],
            ceilings: [:],
            fallbackWeightKg: 20
        )
    )
    XCTAssertEqual(planned, 102.5)
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/IntegrationFlowTests/testRegression_untrustedHistoricEffort
```

Expected: FAIL if Task 4's save hook is wrong (`suggestedNextWeightKg` stays 100). PASS if Task 4 already reapplied. Do not weaken the assertion.

- [ ] **Step 3: Fix only a failed save hook**

If the test fails, `updateUserProfile` must reapply and save stats before it saves the profile when `trustHistoricEffortFeedback` changes. Do not clear `deloadStartedAt`.

- [ ] **Step 4: Run the P0 tests together**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/WorkoutGeneratorP0Tests \
  -only-testing:HotBodTests/IntegrationFlowTests/testRegression_untrustedHistoricEffort \
  -only-testing:HotBodTests/SupabaseDTOTests/testEffortFieldsRoundTripAndDefault
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Tests/Integration/IntegrationFlowTests.swift \
  HotBod/App/AppEnvironment+Profile.swift
git commit -m "$(cat <<'EOF'
Recompute stored loads when historic effort is marked untrusted.

EOF
)"
```

Omit `AppEnvironment+Profile.swift` from the commit if this task did not change it.
