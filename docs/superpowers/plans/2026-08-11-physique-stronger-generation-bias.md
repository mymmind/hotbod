# Physique Stronger Generation Bias Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give active Physique assessment muscle groups a stronger same-day generation tilt (selection + volume) than Settings preferred muscles, without a second program engine.

**Architecture:** Add `physiquePreferredMuscleGroups` on `WorkoutGenerationInput` (assessment bias − avoided). Wire from `makeWorkoutGenerationInput`. Raise `MuscleVolumePlanner` boost to +4 for Physique groups (keep +2 for profile/merged preferred). Add scoring bonus when exercise primary intersects Physique list. Prefer Physique list for recovery-sort bonus when non-empty.

**Tech Stack:** Swift 6, XCTest, XcodeGen only if new files appear (prefer none).

**Spec:** `docs/superpowers/specs/2026-08-11-physique-stronger-generation-bias-design.md`

## Global Constraints

- iOS 17+.
- Prefer: “emphasized,” “focus bias,” “why today’s training.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims.
- Soft tilt only — no second program engine, no auto split remap, no guaranteed exercise slots.
- Avoided muscles / injuries / recovery / validation still win.
- Simulator: `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed.
- Regression tests use `testRegression_` where applicable.
- Do not alter unrelated uncommitted local changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Models/DomainModels.swift` | `WorkoutGenerationInput.physiquePreferredMuscleGroups` |
| `HotBod/Domain/Algorithms/GenerationConstants.swift` | Boost + scoring constants |
| `HotBod/Domain/Physique/PhysiqueTrainingBiasMerger.swift` | Optional helper to filter assessment bias by avoided |
| `HotBod/App/AppEnvironment+Workout.swift` | Populate dual lists |
| `HotBod/Domain/Algorithms/MuscleVolumePlanner.swift` | Dual boost in `remainingBudget` |
| `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift` | Scoring bonus |
| `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` | Thread physique list into volume/score/recovery sort |
| `HotBod/Tests/Support/FixtureBuilders.swift` / `PropertyTestHelpers.swift` | Default `[]` |
| `HotBod/Tests/UnitTests/MuscleVolumePlannerTests.swift` | Volume boost cases |
| `HotBod/Tests/UnitTests/ExerciseVarietyScoringTests.swift` or new | Scoring bonus case |
| `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` | Input wiring + regression |

---

### Task 1: Input field + AppEnvironment wiring

**Files:**
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`WorkoutGenerationInput`)
- Modify: `HotBod/Domain/Physique/PhysiqueTrainingBiasMerger.swift` (optional pure helper)
- Modify: `HotBod/App/AppEnvironment+Workout.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift`, `PropertyTestHelpers.swift` (and any init call sites that break)
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  // WorkoutGenerationInput
  let physiquePreferredMuscleGroups: [MuscleGroup] // default []

  init(..., preferredMuscleGroups: ..., physiquePreferredMuscleGroups: [MuscleGroup] = [], ...)

  // decodeIfPresent → []

  enum PhysiqueTrainingBiasMerger {
      static func physiquePreferredMuscleGroups(
          assessmentBias: [MuscleGroup],
          avoided: [MuscleGroup]
      ) -> [MuscleGroup]  // filter avoided, preserve order, dedupe
  }
  ```

- [ ] **Step 1: Write failing orchestration tests**

```swift
@MainActor
func testMakeWorkoutGenerationInputSetsPhysiquePreferredFromActiveAssessment() async throws {
    let repos = InMemoryRepositories() // match existing test style
    var profile = UserProfile.empty()
    profile.preferredMuscleGroups = [.quads]
    profile.avoidedMuscleGroups = [.chest]
    // env with profile + active assessment bias [.shoulders, .chest, .back]
    var assessment = FixtureBuilders.makePhysiqueAssessment()
    assessment.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.shoulders, .chest, .back],
        rationale: "test"
    )
    await env.saveActivePhysiqueAssessment(assessment) // or set active + repo

    let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
    XCTAssertEqual(input.physiquePreferredMuscleGroups, [.shoulders, .back]) // chest avoided
    XCTAssertTrue(input.preferredMuscleGroups.contains(.shoulders))
    XCTAssertTrue(input.preferredMuscleGroups.contains(.quads))
    XCTAssertFalse(input.physiquePreferredMuscleGroups.contains(.chest))
    XCTAssertFalse(input.physiquePreferredMuscleGroups.contains(.quads))
}

@MainActor
func testMakeWorkoutGenerationInputPhysiquePreferredEmptyWithoutAssessment() async {
    // onboarded profile, no active assessment
    let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
    XCTAssertEqual(input.physiquePreferredMuscleGroups, [])
}

@MainActor
func testRegression_physiquePreferredUsesNewestAssessmentOnly() async throws {
    // mirror testRegression_trainingBiasUsesNewestAssessmentOnly
    // assert input.physiquePreferredMuscleGroups == newer.trainingBias.preferredMuscleGroups
}
```

Also add decode test (can live in PhysiqueDomainTests or WorkoutGenerationDomainTests):

```swift
func testWorkoutGenerationInputDecodesMissingPhysiquePreferredAsEmpty() throws {
    // encode a fixture input, strip key physiquePreferredMuscleGroups, decode → []
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests/testMakeWorkoutGenerationInputSetsPhysiquePreferredFromActiveAssessment \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests/testMakeWorkoutGenerationInputPhysiquePreferredEmptyWithoutAssessment \
  test
```

Expected: FAIL (property / compile missing)

- [ ] **Step 3: Implement input + wiring**

1. Add `physiquePreferredMuscleGroups` to `WorkoutGenerationInput` with default `[]` in memberwise init; `CodingKeys` + `decodeIfPresent`.
2. Add `PhysiqueTrainingBiasMerger.physiquePreferredMuscleGroups(assessmentBias:avoided:)` (same filter loop as merge but only assessment list).
3. In `makeWorkoutGenerationInput` after merged preferred:

```swift
let avoided = profile.avoidedMuscleGroups ?? []
let assessmentBias = activePhysiqueAssessment?.trainingBias.preferredMuscleGroups ?? []
let physiquePreferred = PhysiqueTrainingBiasMerger.physiquePreferredMuscleGroups(
    assessmentBias: assessmentBias,
    avoided: avoided
)
// pass physiquePreferredMuscleGroups: physiquePreferred
```

4. Fix all `WorkoutGenerationInput(` call sites — default param should cover most; update synthesized Codable encode if custom encode exists (memberwise encode is fine if CodingKeys includes the new key — add encode if custom).

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests \
  -only-testing:HotBodTests/PhysiqueTrainingBiasMergerTests \
  test
```

Expected: PASS (add small unit tests for the new merger helper in `PhysiqueTrainingBiasMergerTests` if present)

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/DomainModels.swift \
  HotBod/Domain/Physique/PhysiqueTrainingBiasMerger.swift \
  HotBod/App/AppEnvironment+Workout.swift \
  HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod/Tests/Support/PropertyTestHelpers.swift \
  HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift
git commit -m "feat: plumb physiquePreferredMuscleGroups into generation input"
```

---

### Task 2: Volume + selection + recovery sort tilt

**Files:**
- Modify: `HotBod/Domain/Algorithms/GenerationConstants.swift`
- Modify: `HotBod/Domain/Algorithms/MuscleVolumePlanner.swift`
- Modify: `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift`
- Modify: `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift`
- Modify: `HotBod/Tests/UnitTests/MuscleVolumePlannerTests.swift`
- Modify: `HotBod/Tests/UnitTests/ExerciseVarietyScoringTests.swift` (or `WorkoutGenerationDomainTests.swift`)

**Interfaces:**
- Consumes: `input.physiquePreferredMuscleGroups`
- Produces:
  ```swift
  // GenerationConstants.Volume:
  static let profilePreferredBoost = 2.0
  static let physiquePreferredBoost = 4.0

  // GenerationConstants.Scoring:
  static let physiquePreferredPrimaryBonus = 6.0

  // MuscleVolumePlanner.remainingBudget(..., preferredMuscles:, physiquePreferredMuscles: [])
  // boost = physiqueContains ? physiquePreferredBoost : (preferredContains ? profilePreferredBoost : 0)

  // scoreExercises(..., physiquePreferredMuscles: [MuscleGroup] = [])
  // if primary intersects physique set → +physiquePreferredPrimaryBonus
  ```

- [ ] **Step 1: Write failing unit tests**

```swift
// MuscleVolumePlannerTests
func testPhysiquePreferredGetsLargerLandingBoostThanProfilePreferred() {
    let landing = MuscleVolumePlanner.weeklyLanding(
        experience: .intermediate, goal: .buildMuscle, soreness: .none
    )
    let remaining = MuscleVolumePlanner.remainingBudget(
        targetMuscles: [.shoulders, .quads, .chest],
        completed: [:],
        experience: .intermediate,
        goal: .buildMuscle,
        preferredMuscles: [.quads, .shoulders],
        physiquePreferredMuscles: [.shoulders]
    )
    XCTAssertEqual(remaining[.shoulders], landing + 4) // physique wins
    XCTAssertEqual(remaining[.quads], landing + 2)     // profile only
    XCTAssertEqual(remaining[.chest], landing)         // neither
}

// Scoring — ExerciseVarietyScoringTests or new test in WorkoutGenerationDomainTests
func testPhysiquePreferredPrimaryBonusRaisesScore() {
    let exercise = /* fixture with primary .shoulders */
    let base = WorkoutGenerationAlgorithms.scoreExercises(
        [exercise], targetMuscles: [.shoulders], experience: .intermediate,
        stats: [], recoveryBias: false, physiquePreferredMuscles: []
    )[0].1
    let boosted = WorkoutGenerationAlgorithms.scoreExercises(
        [exercise], targetMuscles: [.shoulders], experience: .intermediate,
        stats: [], recoveryBias: false, physiquePreferredMuscles: [.shoulders]
    )[0].1
    XCTAssertEqual(
        boosted - base,
        GenerationConstants.Scoring.physiquePreferredPrimaryBonus,
        accuracy: 0.001
    )
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/MuscleVolumePlannerTests/testPhysiquePreferredGetsLargerLandingBoostThanProfilePreferred \
  -only-testing:HotBodTests/ExerciseVarietyScoringTests/testPhysiquePreferredPrimaryBonusRaisesScore \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement algorithms + wire service**

1. Add constants (replace hardcoded `2.0` in `MuscleVolumePlanner` with `GenerationConstants.Volume.profilePreferredBoost`).
2. Update `remainingBudget` dual lists + max boost logic.
3. Update `scoreExercises` with physique bonus.
4. `WorkoutGenerationService`:
   - `remainingBudget(..., preferredMuscles: input.preferredMuscleGroups, physiquePreferredMuscles: input.physiquePreferredMuscleGroups)`
   - Pass `physiquePreferredMuscles` into both `scoreExercises` call sites.
   - Recovery sort preferred argument:

```swift
let recoveryPreferred = input.physiquePreferredMuscleGroups.isEmpty
    ? input.preferredMuscleGroups
    : input.physiquePreferredMuscleGroups
```

Use `recoveryPreferred` in all `recoverySortKey(..., preferred:)` call sites in that file.

- [ ] **Step 4: Run focused suites**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/MuscleVolumePlannerTests \
  -only-testing:HotBodTests/ExerciseVarietyScoringTests \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests \
  -only-testing:HotBodTests/WorkoutGenerationDomainTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/GenerationConstants.swift \
  HotBod/Domain/Algorithms/MuscleVolumePlanner.swift \
  HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift \
  HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift \
  HotBod/Tests/UnitTests/MuscleVolumePlannerTests.swift \
  HotBod/Tests/UnitTests/ExerciseVarietyScoringTests.swift
git commit -m "feat: stronger physique volume and selection bias"
```

---

## Spec Coverage Checklist

| Spec requirement | Task |
|------------------|------|
| Dual list on input + decode default | 1 |
| makeWorkoutGenerationInput wiring | 1 |
| Avoided stripped from physique list | 1 |
| Newest assessment only | 1 |
| Volume +4 / +2 | 2 |
| Selection bonus 6.0 | 2 |
| Recovery sort prefers physique list | 2 |
| No assessment → unchanged soft behavior | 1+2 |

## Out of Scope

- Guaranteed slots, split remap, Settings toggles, Today chip, cloud
