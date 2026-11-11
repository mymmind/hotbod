# Kettlebell Circuit Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an explicit Today “Kettlebell Circuit” CTA that generates a 5×5×5 kettlebell group session with 15s in-round / 60s between-round rest, without advancing the main training-day split.

**Architecture:** Add `SessionMode.kettlebellCircuit` and a pure `KettlebellCircuitPlanner`. Extend `SetAdvancePlanner` with mode-aware rest seconds. Wire `AppEnvironment` to generate/start a circuit without clobbering a standard `todayWorkout`, and skip program completion markers on circuit finish. Today shows a secondary CTA when kettlebells are available.

**Tech Stack:** Swift 6, SwiftUI, SwiftData/local repos, XCTest / XCUITest, `HotBod.xctestplan` PR config.

**Spec:** `docs/superpowers/specs/2026-11-11-kettlebell-circuit-design.md`

## Global Constraints

- Explicit CTA only — no auto-offer on non-training days.
- Hard-coded scheme: 5 exercises, 5 reps, 5 rounds, 15s transition, 60s round rest.
- Gym Generate / Circuits preference behavior unchanged.
- Completing a circuit must not set `todayCompletedOn` or advance split rotation.
- Standard supersets/circuits keep 15s for all in-group advances.
- Minimum 2 eligible kettlebell exercises to generate; hide CTA without kettlebell equipment.
- Do not add Settings for scheme parameters.
- Prefer stable `accessibilityIdentifier` `today.kettlebellCircuit`.
- App must compile after each task; unit tests for planner + rest helper required.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Models/DomainModels.swift` | Add `SessionMode.kettlebellCircuit` |
| `HotBod/Domain/Algorithms/GenerationConstants.swift` | `KettlebellCircuit` constants |
| `HotBod/Domain/Algorithms/KettlebellCircuitPlanner.swift` | Pure planner |
| `HotBod/Domain/Algorithms/CompleteSetRouter.swift` | `SetAdvancePlanner` rest helper |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` | Use rest helper with `session.sessionMode` |
| `HotBod/App/AppEnvironment+Workout.swift` | Generate/start circuit without overwriting gym `todayWorkout` |
| `HotBod/App/AppEnvironment+WorkoutSession.swift` | Skip completion markers for circuit mode |
| `HotBod/Features/Today/TodayView.swift` (+ helpers if needed) | CTA + empty/disabled states |
| `HotBod/Tests/UnitTests/KettlebellCircuitPlannerTests.swift` | Planner coverage |
| `HotBod/Tests/UnitTests/CompleteSetRouterTests.swift` | Rest timing regressions |
| `HotBod/Tests/UnitTests/AppEnvironment…` or integration | Circuit finish does not mark today complete |
| `HotBod/Tests/UITests/…` | CTA identifier (or explicit exemption comment) |

---

### Task 1: SessionMode + rest helper (TDD)

**Files:**
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`SessionMode`)
- Modify: `HotBod/Domain/Algorithms/GenerationConstants.swift`
- Modify: `HotBod/Domain/Algorithms/CompleteSetRouter.swift`
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift`
- Modify: `HotBod/Tests/UnitTests/CompleteSetRouterTests.swift`

**Interfaces:**
- Produces: `SessionMode.kettlebellCircuit`
- Produces:
```swift
enum GenerationConstants {
  enum KettlebellCircuit {
    static let exerciseCount = 5
    static let reps = 5
    static let rounds = 5
    static let transitionRestSeconds = 15
    static let roundRestSeconds = 60
    static let rpeTarget = 7.0
  }
}
```
- Produces:
```swift
extension SetAdvancePlanner {
  /// - Returns: rest before advancing to `partnerIndex` after completing `completedSetIndex`.
  static func restSeconds(
    exercises: [WorkoutExercise],
    exerciseIndex: Int,
    completedSetIndex: Int,
    partnerIndex: Int,
    sessionMode: SessionMode
  ) -> Int
}
```
- Semantics: if partner still missing `completedSetIndex` → `transitionRestSeconds` (15). If partner is owed `completedSetIndex + 1` → `roundRestSeconds` (60) when `sessionMode == .kettlebellCircuit`, else 15.

- [ ] **Step 1: Write failing rest tests**

Append to `CompleteSetRouterTests.swift`:

```swift
func testRegression_kettlebellCircuitSameRoundUsesTransitionRest() {
    let group = UUID()
    let set = PlannedSet(targetRepsMin: 5, targetRepsMax: 5)
    let done = CompletedSet(setIndex: 0, weightKg: 16, reps: 5)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: Array(repeating: set, count: 5), completedSets: [done], groupId: group),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: Array(repeating: set, count: 5), completedSets: [], groupId: group)
    ]
    let partner = SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 0, completedSetIndex: 0)!
    let seconds = SetAdvancePlanner.restSeconds(
        exercises: exercises,
        exerciseIndex: 0,
        completedSetIndex: 0,
        partnerIndex: partner,
        sessionMode: .kettlebellCircuit
    )
    XCTAssertEqual(seconds, GenerationConstants.KettlebellCircuit.transitionRestSeconds)
}

func testRegression_kettlebellCircuitNextRoundUsesRoundRest() {
    let group = UUID()
    let set = PlannedSet(targetRepsMin: 5, targetRepsMax: 5)
    let done = CompletedSet(setIndex: 0, weightKg: 16, reps: 5)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: Array(repeating: set, count: 5), completedSets: [done], groupId: group),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: Array(repeating: set, count: 5), completedSets: [done], groupId: group)
    ]
    let partner = SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 1, completedSetIndex: 0)!
    XCTAssertEqual(partner, 0)
    let seconds = SetAdvancePlanner.restSeconds(
        exercises: exercises,
        exerciseIndex: 1,
        completedSetIndex: 0,
        partnerIndex: partner,
        sessionMode: .kettlebellCircuit
    )
    XCTAssertEqual(seconds, GenerationConstants.KettlebellCircuit.roundRestSeconds)
}

func testRegression_standardSupersetNextRoundStaysTransitionRest() {
    let group = UUID()
    let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
    let done = CompletedSet(setIndex: 0, weightKg: 40, reps: 8)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set, set], completedSets: [done], groupId: group),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set, set], completedSets: [done], groupId: group)
    ]
    let partner = SetAdvancePlanner.partnerIndex(exercises: exercises, exerciseIndex: 1, completedSetIndex: 0)!
    let seconds = SetAdvancePlanner.restSeconds(
        exercises: exercises,
        exerciseIndex: 1,
        completedSetIndex: 0,
        partnerIndex: partner,
        sessionMode: .standard
    )
    XCTAssertEqual(seconds, GenerationConstants.Grouping.transitionRestSeconds)
}
```

- [ ] **Step 2: Run tests — expect FAIL** (helper / enum case missing)

Run:
```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=<available-iphone>' \
  -only-testing:HotBodTests/CompleteSetRouterTests
```

- [ ] **Step 3: Implement `SessionMode.kettlebellCircuit`, constants, and `restSeconds`**

Detect next-round vs same-round by whether `exercises[partnerIndex]` is missing `completedSetIndex` (same round) vs only missing `completedSetIndex + 1` (next round).

- [ ] **Step 4: Wire session logging**

In `WorkoutSessionView+ExerciseActions` partner branch, replace hard-coded `transitionRestSeconds` with:

```swift
seconds: SetAdvancePlanner.restSeconds(
    exercises: session.exercises,
    exerciseIndex: idx,
    completedSetIndex: setIndex,
    partnerIndex: partner,
    sessionMode: session.sessionMode
)
```

- [ ] **Step 5: Run CompleteSetRouterTests — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add HotBod/Domain/Models/DomainModels.swift \
  HotBod/Domain/Algorithms/GenerationConstants.swift \
  HotBod/Domain/Algorithms/CompleteSetRouter.swift \
  HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift \
  HotBod/Tests/UnitTests/CompleteSetRouterTests.swift
git commit -m "$(cat <<'EOF'
Add kettlebell-circuit round rest without changing gym supersets.

Same-round advances stay at 15s; only kettlebellCircuit next-round jumps use 60s.
EOF
)"
```

---

### Task 2: KettlebellCircuitPlanner (TDD)

**Files:**
- Create: `HotBod/Domain/Algorithms/KettlebellCircuitPlanner.swift`
- Create: `HotBod/Tests/UnitTests/KettlebellCircuitPlannerTests.swift`

**Interfaces:**
```swift
enum KettlebellCircuitPlanner {
  struct Result: Equatable {
    var workout: GeneratedWorkout
  }

  static func plan(
    exercises: [Exercise],
    availableEquipment: [Equipment],
    injuries: [BodyLimitation],
    experience: ExperienceLevel,
    recentExerciseIds: [String],
    now: Date = Date()
  ) -> GeneratedWorkout?
}
```

Rules from spec:
- Pool = kettlebell equipment + equipment filter + injury filter
- Slots: hinge; squat|lunge; verticalPush; horizontalPull; core/carry/antiRotation (mobility fallback)
- Demote ids in `recentExerciseIds`
- Prefer non-advanced for beginners when peers exist
- Shared `groupId`; each exercise gets `rounds` sets of `reps`…`reps`
- `sessionMode: .kettlebellCircuit`, title `"Kettlebell Circuit"`, `generatedBy: .rulesEngine`
- Return nil if fewer than 2 eligible

- [ ] **Step 1: Write failing planner tests** (5 picks when catalog allows; all kettlebell; shared groupId; 5 sets × 5 reps; nil when empty pool)

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement planner**

Estimated duration:
```swift
let work = exerciseCount * rounds * 20 // rough seconds per set
let transitions = exerciseCount * rounds * transitionRestSeconds - rounds * transitionRestSeconds
// simpler: (exerciseCount - 1) * transitionRestSeconds * rounds + (rounds - 1) * roundRestSeconds + work
```
Convert to minutes with ceiling.

- [ ] **Step 4: Run planner tests — PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Add kettlebell circuit planner for 5x5x5 sessions.

Picks pattern-balanced kettlebell moves into one shared group for round-robin logging.
EOF
)"
```

---

### Task 3: Environment generate/start + skip program completion

**Files:**
- Modify: `HotBod/App/AppEnvironment+Workout.swift` (or new `AppEnvironment+KettlebellCircuit.swift` if file size warrants)
- Modify: `HotBod/App/AppEnvironment+WorkoutSession.swift` (`refreshWorkoutAfterSession`)
- Test: unit/integration asserting circuit finish does not set `todayCompletedOn` / does not advance rotation

**Behavior:**
- `generateKettlebellCircuit(profile:)` → `GeneratedWorkout?` via planner + catalog/stats; **does not** assign `todayWorkout` when existing `todayWorkout?.sessionMode == .standard` (leave gym plan intact). Prefer returning the workout for immediate start/preview.
- `startKettlebellCircuit(profile:)` creates session from circuit workout (`sessionMode` + nil or circuit-only `splitDayFocus`), starts it like other starts.
- In `refreshWorkoutAfterSession`:
```swift
if session.sessionMode == .kettlebellCircuit {
  // clear activeSessionId only; do NOT set todayCompleted*; do NOT advanceRotation
  …
  return
}
```

- [ ] **Step 1: Write failing test** `testRegression_kettlebellCircuitFinishDoesNotMarkTodayComplete`

- [ ] **Step 2: Implement environment methods + completion branch**

- [ ] **Step 3: Tests PASS**

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
Start kettlebell circuits without burning the gym training day.

Circuit sessions save history but skip today-complete markers and split rotation.
EOF
)"
```

---

### Task 4: Today CTA

**Files:**
- Modify: `HotBod/Features/Today/TodayView.swift` (and small extracted helper if needed)
- UITest or exemption comment in the UI test file

**UI:**
- Secondary `ForgeButton` title `Kettlebell Circuit`, id `today.kettlebellCircuit`
- Visible when `userProfile.availableEquipment` contains `.kettlebell` and no blocking active-session rules for generate
- Action: generate + start (or generate then preview — match primary Generate-and-start pattern used elsewhere)
- If generate returns nil: brief error / empty copy (“Need more kettlebell exercises in the catalog for your equipment.”)

- [ ] **Step 1: Add CTA + wiring**

- [ ] **Step 2: UI test launch with kettlebell equipment **or** add exemption comment citing this plan task

- [ ] **Step 3: Manual/build check — app compiles**

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
Expose Kettlebell Circuit on Today when bells are available.

Gives a one-tap home session beside the main gym generate path.
EOF
)"
```

---

### Task 5: Verify

- [ ] Run:
  - `KettlebellCircuitPlannerTests`
  - `CompleteSetRouterTests` (rest regressions)
  - circuit completion regression test
- [ ] `xcodebuild build` for HotBod scheme
- [ ] Confirm gym generate path untouched (spot-check existing generation unit test if quick)

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| `SessionMode.kettlebellCircuit` | 1 |
| 15s / 60s rest helper | 1 |
| Planner 5×5×5 slots | 2 |
| No overwrite / no today-complete | 3 |
| Today CTA | 4 |
| Tests | 1–5 |

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-11-11-kettlebell-circuit.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task  
2. **Inline Execution** — run in this session with checkpoints  

Which approach?
