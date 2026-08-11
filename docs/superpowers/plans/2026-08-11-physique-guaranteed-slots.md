# Physique Soft-Reserve Exercise Slots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Soft-reserve N on-focus Physique-primary exercises at the start of daily selection (2 standard / 1 recovery), then fill remaining slots as today — never fail thin catalogs.

**Architecture:** Extend `WorkoutGenerationAlgorithms.selectExercises` with optional `physiquePreferredMuscles` + `reservedPhysiqueSlots`. Prefill eligible ranked picks (physique ∩ targets ∩ primary, pattern rules), then existing coverage/fill/backfill. `RulesWorkoutGenerationService` passes constants; no new input fields or UI.

**Tech Stack:** Swift 6, XCTest, existing `makeTestExercise` fixtures.

**Spec:** `docs/superpowers/specs/2026-08-11-physique-guaranteed-slots-design.md`

## Global Constraints

- iOS 17+, local-first; single generator.
- Soft reserve only — never violate injury / equipment / avoided (already filtered before rank).
- Must intersect today’s `targetMuscles` (no off-focus reserve).
- Prefer: “focus,” “emphasized”; avoid guarantee/optimal/destiny copy (no new UI copy in this slice).
- Simulator: `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed.
- Do not alter unrelated uncommitted local changes (e.g. stray `Localizable.xcstrings`).

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Algorithms/GenerationConstants.swift` | `Session.physiqueReservedSlots = 2`, `RecoverySession.physiqueReservedSlots = 1` |
| `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift` | Prefill reserve in `selectExercises` |
| `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` | Pass reserve counts on standard + recovery paths |
| `HotBod/Tests/UnitTests/PhysiqueReserveSlotsTests.swift` | Unit coverage for reserve behavior |
| `HotBod/Tests/UnitTests/ExerciseVarietyScoringTests.swift` | Existing `selectExercises` call sites keep default args |

---

### Task 1: Constants + selectExercises prefill + unit tests

**Files:**
- Modify: `HotBod/Domain/Algorithms/GenerationConstants.swift`
- Modify: `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueReserveSlotsTests.swift`
- Touch if compile breaks: existing `selectExercises(` call sites (defaults keep them green)

**Interfaces:**
- Produces:
  ```swift
  // GenerationConstants.Session
  static let physiqueReservedSlots = 2
  // GenerationConstants.RecoverySession
  static let physiqueReservedSlots = 1

  // WorkoutGenerationAlgorithms
  static func selectExercises(
      ranked: [(Exercise, Double)],
      targetMuscles: [MuscleGroup],
      maxExercises: Int,
      minExercises: Int,
      physiquePreferredMuscles: [MuscleGroup] = [],
      reservedPhysiqueSlots: Int = 0
  ) -> ExerciseSelectionResult
  ```

- [ ] **Step 1: Write failing unit tests**

```swift
import XCTest
@testable import HotBod

final class PhysiqueReserveSlotsTests: XCTestCase {
    func testReserveTwoOnFocusPhysiquePrimariesWhenEligible() {
        // Ranked: two shoulders/back Physique∩target isolations first would be
        // skipped by coverage if we only relied on soft score — force lower
        // scores but still eligible; also include non-physique fillers.
        let facePull = makeTestExercise(
            id: "face_pull",
            primaryMuscles: [.shoulders],
            pattern: .isolation,
            mechanics: .isolation
        )
        let chestSupportedRow = makeTestExercise(
            id: "chest_supported_row",
            primaryMuscles: [.back],
            pattern: .isolation,
            mechanics: .isolation
        )
        let bench = makeTestExercise(
            id: "bench",
            primaryMuscles: [.chest],
            pattern: .horizontalPush
        )
        let squat = makeTestExercise(
            id: "squat",
            primaryMuscles: [.quads],
            pattern: .squat
        )
        let ranked: [(Exercise, Double)] = [
            (bench, 30),
            (squat, 29),
            (facePull, 5),
            (chestSupportedRow, 4)
        ]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders, .back, .quads],
            maxExercises: 4,
            minExercises: 4,
            physiquePreferredMuscles: [.shoulders, .back],
            reservedPhysiqueSlots: 2
        )
        let ids = Set(result.exercises.map(\.id))
        XCTAssertTrue(ids.contains("face_pull"))
        XCTAssertTrue(ids.contains("chest_supported_row"))
        XCTAssertEqual(result.exercises.count, 4)
    }

    func testReserveZeroWhenPhysiqueEmptyMatchesBaselineIds() {
        let a = makeTestExercise(id: "a", primaryMuscles: [.chest], pattern: .horizontalPush)
        let b = makeTestExercise(id: "b", primaryMuscles: [.shoulders], pattern: .isolation, mechanics: .isolation)
        let ranked: [(Exercise, Double)] = [(a, 10), (b, 9)]
        let baseline = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders],
            maxExercises: 2,
            minExercises: 2
        )
        let withEmpty = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders],
            maxExercises: 2,
            minExercises: 2,
            physiquePreferredMuscles: [],
            reservedPhysiqueSlots: 2
        )
        XCTAssertEqual(baseline.exercises.map(\.id), withEmpty.exercises.map(\.id))
    }

    func testOffFocusPhysiqueCandidateNotReserved() {
        let legCurl = makeTestExercise(
            id: "leg_curl",
            primaryMuscles: [.hamstrings],
            pattern: .isolation,
            mechanics: .isolation
        )
        let bench = makeTestExercise(
            id: "bench",
            primaryMuscles: [.chest],
            pattern: .horizontalPush
        )
        let fly = makeTestExercise(
            id: "fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let ranked: [(Exercise, Double)] = [(legCurl, 100), (bench, 10), (fly, 9)]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest],
            maxExercises: 2,
            minExercises: 2,
            physiquePreferredMuscles: [.hamstrings],
            reservedPhysiqueSlots: 2
        )
        XCTAssertFalse(result.exercises.contains { $0.id == "leg_curl" })
        XCTAssertEqual(Set(result.exercises.map(\.id)), Set(["bench", "fly"]))
    }

    func testThinCatalogStillMeetsMinExercises() {
        let bench = makeTestExercise(id: "bench", primaryMuscles: [.chest], pattern: .horizontalPush)
        let fly = makeTestExercise(
            id: "fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let pushdown = makeTestExercise(
            id: "pushdown",
            primaryMuscles: [.triceps],
            pattern: .isolation,
            mechanics: .isolation
        )
        let lateral = makeTestExercise(
            id: "lateral",
            primaryMuscles: [.shoulders],
            pattern: .isolation,
            mechanics: .isolation
        )
        let ranked: [(Exercise, Double)] = [
            (bench, 10), (fly, 9), (pushdown, 8), (lateral, 7)
        ]
        // Only one Physique∩target eligible (lateral); reserve asks for 2.
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .triceps, .shoulders],
            maxExercises: 4,
            minExercises: 3,
            physiquePreferredMuscles: [.shoulders],
            reservedPhysiqueSlots: 2
        )
        XCTAssertGreaterThanOrEqual(result.exercises.count, 3)
        XCTAssertTrue(result.exercises.contains { $0.id == "lateral" })
    }

    func testRecoveryReserveOne() {
        let facePull = makeTestExercise(
            id: "face_pull",
            primaryMuscles: [.shoulders],
            pattern: .isolation,
            mechanics: .isolation
        )
        let bench = makeTestExercise(id: "bench", primaryMuscles: [.chest], pattern: .horizontalPush)
        let fly = makeTestExercise(
            id: "fly",
            primaryMuscles: [.chest],
            pattern: .isolation,
            mechanics: .isolation
        )
        let ranked: [(Exercise, Double)] = [(bench, 20), (fly, 19), (facePull, 1)]
        let result = WorkoutGenerationAlgorithms.selectExercises(
            ranked: ranked,
            targetMuscles: [.chest, .shoulders],
            maxExercises: GenerationConstants.RecoverySession.maxExercises,
            minExercises: GenerationConstants.RecoverySession.minExercises,
            physiquePreferredMuscles: [.shoulders],
            reservedPhysiqueSlots: GenerationConstants.RecoverySession.physiqueReservedSlots
        )
        XCTAssertTrue(result.exercises.contains { $0.id == "face_pull" })
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReserveSlotsTests
```

Expected: compile error (missing params/constants) or failing assertions.

- [ ] **Step 3: Implement constants + prefill**

In `GenerationConstants.Session` add:

```swift
static let physiqueReservedSlots = 2
```

In `GenerationConstants.RecoverySession` add:

```swift
static let physiqueReservedSlots = 1
```

In `WorkoutGenerationAlgorithms.selectExercises`, add defaulted params and **before** the coverage loop:

```swift
let reserveCount = min(max(0, reservedPhysiqueSlots), maxExercises)
if reserveCount > 0, !physiquePreferredMuscles.isEmpty {
    let physiqueSet = Set(physiquePreferredMuscles)
    let targetSet = Set(targetMuscles)
    for item in ranked where selected.count < reserveCount {
        let exercise = item.0
        guard !usedIds.contains(exercise.id) else { continue }
        let primaries = Set(exercise.primaryMuscles)
        guard !primaries.isDisjoint(with: physiqueSet) else { continue }
        guard !primaries.isDisjoint(with: targetSet) else { continue }
        guard !blocksDuplicatePattern(
            exercise.movementPattern,
            used: usedPatterns,
            selectedCount: selected.count
        ) else { continue }
        selected.append(item)
        usedIds.insert(exercise.id)
        usedPatterns.insert(exercise.movementPattern)
    }
}
// then existing coverage / fill / backfill unchanged
```

Keep `blocksDuplicatePattern` private — prefill uses the same helper.

- [ ] **Step 4: Run unit tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReserveSlotsTests \
  -only-testing:HotBodTests/ExerciseVarietyScoringTests
```

Expected: PASS. If new test file missing from target, add pbxproj ref or `xcodegen generate` (restore objectVersion/DEVELOPMENT_TEAM churn).

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/GenerationConstants.swift \
  HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift \
  HotBod/Tests/UnitTests/PhysiqueReserveSlotsTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: soft-reserve on-focus physique exercise slots

EOF
)"
```

---

### Task 2: Wire RulesWorkoutGenerationService

**Files:**
- Modify: `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` (`selectExercises` + `selectRecoveryExercises` call sites into `WorkoutGenerationAlgorithms.selectExercises`)

**Interfaces:**
- Consumes: `GenerationConstants.Session.physiqueReservedSlots`, `RecoverySession.physiqueReservedSlots`, `input.physiquePreferredMuscleGroups`
- Produces: standard path passes reserve=2; recovery passes reserve=1

- [ ] **Step 1: Write a small failing service/integration assertion (or extend domain test)**

Prefer a focused unit that does not need full `RulesWorkoutGenerationService` if heavy — optional smoke:

```swift
func testConstantsMatchSpec() {
    XCTAssertEqual(GenerationConstants.Session.physiqueReservedSlots, 2)
    XCTAssertEqual(GenerationConstants.RecoverySession.physiqueReservedSlots, 1)
}
```

Add to `PhysiqueReserveSlotsTests`. Then change service call sites (step 3) so production uses them.

- [ ] **Step 2: Run — constants test should PASS once Task 1 landed; service still unwired until step 3**

- [ ] **Step 3: Wire service**

In private `selectExercises(...)` where it returns `WorkoutGenerationAlgorithms.selectExercises`:

```swift
return WorkoutGenerationAlgorithms.selectExercises(
    ranked: ranked,
    targetMuscles: targetMuscles,
    maxExercises: maxExercises,
    minExercises: GenerationConstants.Session.minStandardExercises,
    physiquePreferredMuscles: physiquePreferredMuscles,
    reservedPhysiqueSlots: GenerationConstants.Session.physiqueReservedSlots
)
```

In `selectRecoveryExercises`:

```swift
return WorkoutGenerationAlgorithms.selectExercises(
    ranked: ranked,
    targetMuscles: targetMuscles,
    maxExercises: GenerationConstants.RecoverySession.maxExercises,
    minExercises: GenerationConstants.RecoverySession.minExercises,
    physiquePreferredMuscles: physiquePreferredMuscles,
    reservedPhysiqueSlots: GenerationConstants.RecoverySession.physiqueReservedSlots
)
```

Ensure recovery path’s local `selectRecoveryExercises` already accepts/threads `physiquePreferredMuscles` into scoring (it should from stronger-bias); if recovery scoring call omits physique list, pass it through consistently — do **not** change bonus magnitudes.

- [ ] **Step 4: Run focused suites**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReserveSlotsTests \
  -only-testing:HotBodTests/ExerciseVarietyScoringTests \
  -only-testing:HotBodTests/WorkoutGenerationDomainTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift \
  HotBod/Tests/UnitTests/PhysiqueReserveSlotsTests.swift
git commit -m "$(cat <<'EOF'
feat: wire physique reserve slots into generation service

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Constants 2 / 1 | 1 (+ assert in 2) |
| Prefill eligibility (physique ∩ targets) | 1 |
| Soft / thin catalog | 1 |
| Empty physique no-op | 1 |
| Service wires standard + recovery | 2 |
| No UI / no input schema change | — (omitted) |

## Plan self-review notes

- Default args keep existing `selectExercises` call sites compiling.
- Prefill uses same `blocksDuplicatePattern` as coverage.
- No product copy claiming “guaranteed.”
