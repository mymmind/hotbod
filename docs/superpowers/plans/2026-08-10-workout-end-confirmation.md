# Workout End Confirmation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Never auto-end a workout; confirm before finish, and treat completion as “all non-skipped sets logged,” not “last list index.”

**Architecture:** Add pure `WorkoutSessionCalculator` helpers for fully-logged / incomplete-count / advance decision / end-confirmation copy. `advanceExercise()` follows that decision (advance index or present confirmation) and never calls `finishWorkout()` directly. Keep Training jumps to the first incomplete exercise.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-10-workout-end-confirmation-design.md`

## Global Constraints

- iOS 17+.
- Preserve local-first architecture; no backend dependency.
- Never call `finishWorkout()` from `advanceExercise()`.
- Skipped exercises (`wasSkipped == true`) do not count as remaining work.
- Confirmation copy differs for incomplete vs all-logged.
- Keep Training with incomplete work → first incomplete exercise index.
- `session.ui.endWorkout` stays a direct-finish UITest affordance.
- Regression tests use the `testRegression_` prefix.
- Final verification uses the `PR` configuration in `HotBod.xctestplan`.
- Do not alter unrelated uncommitted changes (e.g. incidental `project.pbxproj` noise).

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Algorithms/Algorithms.swift` (`WorkoutSessionCalculator`) | Pure session-completion queries, advance decision, confirmation copy |
| `HotBod/Tests/UnitTests/CalculatorDomainTests.swift` | Unit + regression coverage for calculator helpers |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` | `advanceExercise()` uses decision; never auto-finishes |
| `HotBod/Features/WorkoutSession/WorkoutSessionView.swift` | Dynamic confirmation dialog + Keep Training navigation |

---

### Task 1: Domain completion helpers (TDD)

**Files:**
- Modify: `HotBod/Domain/Algorithms/Algorithms.swift` (`WorkoutSessionCalculator`, ~712+)
- Modify: `HotBod/Tests/UnitTests/CalculatorDomainTests.swift` (`WorkoutSessionCalculatorTests`)

**Interfaces:**
- Produces:
  ```swift
  enum WorkoutAdvanceDecision: Equatable {
      case goToExercise(index: Int)
      case confirmEnd
  }

  struct WorkoutEndConfirmationCopy: Equatable {
      let title: String
      let message: String
  }

  // on WorkoutSessionCalculator:
  static func isExerciseComplete(_ exercise: WorkoutExercise) -> Bool
  static func isSessionFullyLogged(_ session: WorkoutSession) -> Bool
  static func incompleteExerciseCount(in session: WorkoutSession) -> Int
  static func firstIncompleteExerciseIndex(in session: WorkoutSession) -> Int?
  static func advanceDecision(
      session: WorkoutSession,
      currentExerciseIndex: Int
  ) -> WorkoutAdvanceDecision
  static func endConfirmationCopy(incompleteExerciseCount: Int) -> WorkoutEndConfirmationCopy
  ```
- Notes:
  - `isExerciseComplete`: `!wasSkipped && completedSets.count >= plannedSets.count`
  - `isSessionFullyLogged`: every exercise is either skipped or complete
  - `firstIncompleteExerciseIndex`: first non-skipped with open sets (same predicate as `currentExerciseIndex`, but returns `nil` when none)
  - `advanceDecision`: (1) fully logged → `.confirmEnd` (2) else if `currentExerciseIndex + 1 < count` → `.goToExercise(current + 1)` (3) else → `.confirmEnd`
  - Copy: incomplete → title `"End Workout?"`, message `"\(n) exercises still incomplete. Logged sets will be saved."` (use singular `"1 exercise still incomplete..."` when `n == 1`); all logged (`n == 0`) → title `"Finish Workout?"`, message `"All sets logged. Ready to end this session?"`

- [ ] **Step 1: Write failing unit tests**

Append to `WorkoutSessionCalculatorTests` in `HotBod/Tests/UnitTests/CalculatorDomainTests.swift`:

```swift
func testIsSessionFullyLoggedOutOfOrder() {
    let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
    let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [done]),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done]),
        WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], completedSets: [done])
    ]
    let session = WorkoutSession(
        userId: UUID(),
        title: "Test",
        estimatedDurationMinutes: 45,
        exercises: exercises,
        status: .inProgress
    )
    XCTAssertTrue(WorkoutSessionCalculator.isSessionFullyLogged(session))
    XCTAssertEqual(WorkoutSessionCalculator.incompleteExerciseCount(in: session), 0)
    XCTAssertNil(WorkoutSessionCalculator.firstIncompleteExerciseIndex(in: session))
}

func testIncompleteCountIgnoresSkipped() {
    let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
    let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: []),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done], wasSkipped: true),
        WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], completedSets: [done])
    ]
    let session = WorkoutSession(
        userId: UUID(),
        title: "Test",
        estimatedDurationMinutes: 45,
        exercises: exercises,
        status: .inProgress
    )
    XCTAssertFalse(WorkoutSessionCalculator.isSessionFullyLogged(session))
    XCTAssertEqual(WorkoutSessionCalculator.incompleteExerciseCount(in: session), 1)
    XCTAssertEqual(WorkoutSessionCalculator.firstIncompleteExerciseIndex(in: session), 0)
}

func testRegression_finishingLastIndexWithEarlierIncompleteDoesNotAutoComplete() {
    let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
    let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: []),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done])
    ]
    let session = WorkoutSession(
        userId: UUID(),
        title: "Test",
        estimatedDurationMinutes: 45,
        exercises: exercises,
        status: .inProgress
    )
    let decision = WorkoutSessionCalculator.advanceDecision(session: session, currentExerciseIndex: 1)
    XCTAssertEqual(decision, .confirmEnd)
    XCTAssertFalse(WorkoutSessionCalculator.isSessionFullyLogged(session))
    XCTAssertEqual(WorkoutSessionCalculator.firstIncompleteExerciseIndex(in: session), 0)
}

func testAdvanceDecisionFullyLoggedPromptsConfirmEvenMidList() {
    let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
    let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [done]),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [done]),
        WorkoutExercise(exerciseId: "c", orderIndex: 2, plannedSets: [set], completedSets: [done])
    ]
    let session = WorkoutSession(
        userId: UUID(),
        title: "Test",
        estimatedDurationMinutes: 45,
        exercises: exercises,
        status: .inProgress
    )
    let decision = WorkoutSessionCalculator.advanceDecision(session: session, currentExerciseIndex: 1)
    XCTAssertEqual(decision, .confirmEnd)
}

func testAdvanceDecisionGoesToNextIndexWhenWorkRemains() {
    let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
    let done = CompletedSet(setIndex: 0, weightKg: 50, reps: 8)
    let exercises = [
        WorkoutExercise(exerciseId: "a", orderIndex: 0, plannedSets: [set], completedSets: [done]),
        WorkoutExercise(exerciseId: "b", orderIndex: 1, plannedSets: [set], completedSets: [])
    ]
    let session = WorkoutSession(
        userId: UUID(),
        title: "Test",
        estimatedDurationMinutes: 45,
        exercises: exercises,
        status: .inProgress
    )
    let decision = WorkoutSessionCalculator.advanceDecision(session: session, currentExerciseIndex: 0)
    XCTAssertEqual(decision, .goToExercise(index: 1))
}

func testEndConfirmationCopyIncompleteVsComplete() {
    let incomplete = WorkoutSessionCalculator.endConfirmationCopy(incompleteExerciseCount: 2)
    XCTAssertEqual(incomplete.title, "End Workout?")
    XCTAssertEqual(incomplete.message, "2 exercises still incomplete. Logged sets will be saved.")

    let singular = WorkoutSessionCalculator.endConfirmationCopy(incompleteExerciseCount: 1)
    XCTAssertEqual(singular.title, "End Workout?")
    XCTAssertEqual(singular.message, "1 exercise still incomplete. Logged sets will be saved.")

    let complete = WorkoutSessionCalculator.endConfirmationCopy(incompleteExerciseCount: 0)
    XCTAssertEqual(complete.title, "Finish Workout?")
    XCTAssertEqual(complete.message, "All sets logged. Ready to end this session?")
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/WorkoutSessionCalculatorTests test
```

Expected: FAIL — new symbols / methods not found.

If the simulator name differs on the machine, list available destinations with `xcodebuild -scheme HotBod -showdestinations` and substitute an installed iPhone simulator.

- [ ] **Step 3: Implement helpers on `WorkoutSessionCalculator`**

Near the end of `WorkoutSessionCalculator` in `HotBod/Domain/Algorithms/Algorithms.swift`, add:

```swift
static func isExerciseComplete(_ exercise: WorkoutExercise) -> Bool {
    !exercise.wasSkipped && exercise.completedSets.count >= exercise.plannedSets.count
}

static func isSessionFullyLogged(_ session: WorkoutSession) -> Bool {
    session.exercises.allSatisfy { $0.wasSkipped || isExerciseComplete($0) }
}

static func incompleteExerciseCount(in session: WorkoutSession) -> Int {
    session.exercises.filter { !$0.wasSkipped && $0.completedSets.count < $0.plannedSets.count }.count
}

static func firstIncompleteExerciseIndex(in session: WorkoutSession) -> Int? {
    session.exercises.firstIndex(where: {
        !$0.wasSkipped && $0.completedSets.count < $0.plannedSets.count
    })
}

static func advanceDecision(
    session: WorkoutSession,
    currentExerciseIndex: Int
) -> WorkoutAdvanceDecision {
    if isSessionFullyLogged(session) {
        return .confirmEnd
    }
    if currentExerciseIndex + 1 < session.exercises.count {
        return .goToExercise(index: currentExerciseIndex + 1)
    }
    return .confirmEnd
}

static func endConfirmationCopy(incompleteExerciseCount: Int) -> WorkoutEndConfirmationCopy {
    if incompleteExerciseCount <= 0 {
        return WorkoutEndConfirmationCopy(
            title: "Finish Workout?",
            message: "All sets logged. Ready to end this session?"
        )
    }
    let noun = incompleteExerciseCount == 1 ? "exercise" : "exercises"
    return WorkoutEndConfirmationCopy(
        title: "End Workout?",
        message: "\(incompleteExerciseCount) \(noun) still incomplete. Logged sets will be saved."
    )
}
```

Define the supporting types in the same file (just above `WorkoutSessionCalculator` is fine):

```swift
enum WorkoutAdvanceDecision: Equatable {
    case goToExercise(index: Int)
    case confirmEnd
}

struct WorkoutEndConfirmationCopy: Equatable {
    let title: String
    let message: String
}
```

- [ ] **Step 4: Re-run tests and verify they pass**

Run the same `xcodebuild` command as Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/Algorithms.swift HotBod/Tests/UnitTests/CalculatorDomainTests.swift
git commit -m "$(cat <<'EOF'
feat: add workout session completion and advance decision helpers

EOF
)"
```

Only commit if the user has asked for commits in this session; otherwise stop after tests pass and note the commit message for later.

---

### Task 2: Gate `advanceExercise()` behind confirmation

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` (`advanceExercise`, ~467–479)
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView.swift` (ensure `showEndConfirmation` is accessible from the extension — change `private` to `internal`/`var` if needed)

**Interfaces:**
- Consumes: `WorkoutSessionCalculator.advanceDecision(session:currentExerciseIndex:)`
- Consumes: existing `showEndConfirmation`, `goToExercise(at:)`, `finishWorkout()` (finish only via dialog confirm, not here)
- Produces: `advanceExercise()` never calls `finishWorkout()`

- [ ] **Step 1: Expose confirmation state to the extension**

In `WorkoutSessionView.swift`, change:

```swift
@State private var showEndConfirmation = false
```

to:

```swift
@State var showEndConfirmation = false
```

so `WorkoutSessionView+ExerciseActions` can set it.

- [ ] **Step 2: Replace `advanceExercise()` body**

In `WorkoutSessionView+ExerciseActions.swift`, replace `advanceExercise()` with:

```swift
func advanceExercise() {
    showExerciseComplete = false
    pendingPostSetAction = nil
    clearPersistedRestState()

    switch WorkoutSessionCalculator.advanceDecision(
        session: session,
        currentExerciseIndex: currentExerciseIndex
    ) {
    case .goToExercise(let index):
        withAnimation(ForgeMotion.exercise) {
            currentExerciseIndex = index
            furthestExerciseIndex = max(furthestExerciseIndex, index)
        }
    case .confirmEnd:
        showEndConfirmation = true
    }
}
```

Do **not** call `finishWorkout()` in this function.

- [ ] **Step 3: Build to verify compile**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutSessionView.swift \
  HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift
git commit -m "$(cat <<'EOF'
fix: stop auto-finishing workout when advancing past last exercise

EOF
)"
```

Only commit if the user has asked for commits; otherwise note for later.

---

### Task 3: Dynamic confirmation copy + Keep Training navigation

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView.swift` (confirmation dialog ~217–223, menu `.endWorkout` handler ~502–507)

**Interfaces:**
- Consumes: `WorkoutSessionCalculator.incompleteExerciseCount(in:)`, `endConfirmationCopy(incompleteExerciseCount:)`, `firstIncompleteExerciseIndex(in:)`, `goToExercise(at:)`, `finishWorkout()`
- Produces: context-aware dialog; Keep Training navigates to first incomplete when present

- [ ] **Step 1: Add a small computed helper on the view**

In `WorkoutSessionView` (private helpers section is fine):

```swift
private var endConfirmationCopy: WorkoutEndConfirmationCopy {
    WorkoutSessionCalculator.endConfirmationCopy(
        incompleteExerciseCount: WorkoutSessionCalculator.incompleteExerciseCount(in: session)
    )
}

private func keepTrainingAfterEndConfirmation() {
    if let index = WorkoutSessionCalculator.firstIncompleteExerciseIndex(in: session) {
        goToExercise(at: index)
    }
}
```

- [ ] **Step 2: Replace the static confirmation dialog**

Replace:

```swift
.confirmationDialog("End Workout?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
    Button("End & Save Progress") { finishWorkout() }
        .accessibilityIdentifier("session.endWorkout.save")
    Button("Keep Training", role: .cancel) {}
} message: {
    Text("Your logged sets will be saved and counted toward today's session.")
}
```

with:

```swift
.confirmationDialog(
    endConfirmationCopy.title,
    isPresented: $showEndConfirmation,
    titleVisibility: .visible
) {
    Button("End & Save Progress") { finishWorkout() }
        .accessibilityIdentifier("session.endWorkout.save")
    Button("Keep Training", role: .cancel) {
        keepTrainingAfterEndConfirmation()
    }
} message: {
    Text(endConfirmationCopy.message)
}
```

Menu `.endWorkout` already sets `showEndConfirmation = true` for production; leave that. UITest branch may still call `finishWorkout()` directly — leave as-is.

Keep `session.ui.endWorkout` as a direct finish path (no confirmation) per spec.

- [ ] **Step 3: Build + run calculator tests**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/WorkoutSessionCalculatorTests build test
```

Expected: BUILD SUCCEEDED and tests PASS.

- [ ] **Step 4: Manual smoke checklist (simulator)**

1. Start a workout with ≥3 exercises.
2. Jump to the last exercise via preview, complete all its sets, tap Continue on exercise-complete → confirmation appears (“End Workout?” / N incomplete); do **not** land on completion screen yet.
3. Tap Keep Training → lands on first incomplete exercise; session still in progress.
4. Complete remaining exercises in order until all sets logged → Continue → “Finish Workout?” copy.
5. Confirm → existing completion UI.
6. In a fresh session, menu End Workout mid-workout → same confirmation with incomplete copy.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "$(cat <<'EOF'
feat: confirm workout end with context-aware copy and keep-training jump

EOF
)"
```

Only commit if the user has asked for commits; otherwise note for later.

---

### Task 4: Final verification

**Files:**
- None expected (fix only). Update UI tests only if a PR UI test fails because it assumed auto-finish without confirmation.

- [ ] **Step 1: Run PR test plan configuration**

Prefer the project’s documented PR configuration (same pattern as other plans):

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -testPlan HotBod \
  -only-testing:HotBodTests/WorkoutSessionCalculatorTests test
```

If full PR plan is practical on this machine, run the full `PR` configuration from `HotBod.xctestplan` instead.

- [ ] **Step 2: If a WorkoutSession UI test fails on auto-finish**

Inspect `HotBod/Tests/UITests/WorkoutSessionUITests.swift` and page objects. If a flow completes the last exercise and expects `session.workoutComplete` without confirmation, update it to tap `session.endWorkout.save` (or the Keep Training path) after Continue. Prefer reusing existing `TodayPage.endWorkoutSavingProgress()` helpers when they already dismiss the confirmation.

- [ ] **Step 3: Confirm success criteria from the spec**

- Jumping to last exercise and finishing it does not silently complete the workout.
- Ending always requires confirmation (menu or advance-implied finish).
- Keep Training returns to first incomplete when work remains.
- Dialog copy distinguishes incomplete vs all-logged.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Domain completion queries | Task 1 |
| Never auto-finish from last index | Task 1 + 2 |
| Confirm when fully logged any order | Task 1 + 2 |
| Manual End Workout confirms | Task 3 (existing trigger + shared copy) |
| Incomplete vs all-logged copy | Task 1 + 3 |
| Keep Training → first incomplete | Task 3 |
| UITest direct end affordance preserved | Task 2/3 (leave `session.ui.endWorkout`) |
| Regression test | Task 1 |

## Self-review notes

- No placeholders left in task steps.
- `WorkoutAdvanceDecision` / `WorkoutEndConfirmationCopy` names are consistent across tasks.
- Singular/plural copy is specified so UI does not say “1 exercises.”
- Commits are optional pending explicit user request (user rule).
