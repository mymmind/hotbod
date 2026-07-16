# Logged Weight Sanity Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate absurd logged weights in live workout sessions with a hard block above 400 kg and a soft “Edit / Save anyway” warning for large jumps vs last or planned load.

**Architecture:** Add a pure domain helper `LoggedWeightSanity.evaluate` that returns `.ok` / `.softWarning` / `.hardBlock`. Call it before persisting weight from `completeCurrentSet` and from completed-set weight edits. Session UI shows alert (hard) or confirmationDialog (soft); Save anyway commits once with a bypass flag.

**Tech Stack:** Swift 6, SwiftUI, SwiftData session persistence (unchanged), XCTest, XcodeGen (`xcodegen generate` after adding source files under `HotBod/`).

**Spec:** `docs/superpowers/specs/2026-07-16-logged-weight-sanity-design.md`

## Global Constraints

- iOS 17+.
- Local-first; no backend dependency.
- kg-only; no lb conversion.
- Reuse `GenerationConstants.Validation.maxPlannedWeightKg` (400.0) and `.weightJumpWarningMultiplier` (1.5).
- Hard block: `proposedKg < 0` or `proposedKg > 400` — no override.
- Soft warning: `proposedKg > baseline * 1.5` where baseline is lastWeightKg (>0) else plannedWeightKg (>0); skip soft if neither.
- Hard wins over soft.
- Skip when weight UI is hidden / no weight to persist.
- Do not clamp or auto-correct weights.
- Typed value stays in the field on Edit / hard dismiss.
- Brutalist copy; no emoji; strings via `L10n` + `Localizable.xcstrings`.
- New algorithm → unit tests required; regression name `testRegression_absurdLoggedWeight` for the 800 kg hard-block path.
- Final verification: `xcodegen generate` (if needed) + `xcodebuild` build/test.
- Do not alter unrelated uncommitted changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Algorithms/LoggedWeightSanity.swift` | Pure evaluate + Outcome / HardBlockReason |
| `HotBod/Tests/UnitTests/LoggedWeightSanityTests.swift` | Domain unit + regression tests |
| `HotBod/Core/Localization/L10n.swift` | `L10n.Workout` keys for soft/hard dialogs |
| `HotBod/Resources/Localizable.xcstrings` | English strings for those keys |
| `HotBod/Features/WorkoutSession/WorkoutSessionView.swift` | Pending sanity state + alert / confirmationDialog |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` | Gate `completeCurrentSet`; commit helper with bypass |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+SetTable.swift` | Gate completed-set weight edits in `bindingWeight` |

After creating new Swift files under `HotBod/`, run `xcodegen generate` so they join the app/test targets (sources are path-based in `project.yml`).

---

### Task 1: Domain gate `LoggedWeightSanity` (TDD)

**Files:**
- Create: `HotBod/Domain/Algorithms/LoggedWeightSanity.swift`
- Create: `HotBod/Tests/UnitTests/LoggedWeightSanityTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum LoggedWeightSanity {
      enum HardBlockReason: Equatable {
          case negative
          case aboveAbsoluteMax
      }
      enum Outcome: Equatable {
          case ok
          case softWarning(baselineKg: Double)
          case hardBlock(HardBlockReason)
      }
      static func evaluate(
          proposedKg: Double,
          lastWeightKg: Double?,
          plannedWeightKg: Double?
      ) -> Outcome
  }
  ```
- Consumes: `GenerationConstants.Validation.maxPlannedWeightKg`, `.weightJumpWarningMultiplier`

- [ ] **Step 1: Write the failing tests**

Create `HotBod/Tests/UnitTests/LoggedWeightSanityTests.swift`:

```swift
import XCTest
@testable import HotBod

final class LoggedWeightSanityTests: XCTestCase {
    func testOkWithinJumpMultiplierVsLast() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 100,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testSoftWarningVsLastWeight() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 150,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .softWarning(baselineKg: 80))
    }

    func testSoftWarningUsesPlannedWhenNoLast() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 150,
            lastWeightKg: nil,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .softWarning(baselineKg: 80))
    }

    func testPrefersLastOverPlannedForBaseline() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 200,
            lastWeightKg: 100,
            plannedWeightKg: 50
        )
        // 200 > 100 * 1.5 → soft vs last (not vs planned 50)
        XCTAssertEqual(outcome, .softWarning(baselineKg: 100))
    }

    func testNoSoftWarningWithoutBaseline() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 300,
            lastWeightKg: nil,
            plannedWeightKg: nil
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testIgnoresNonPositiveBaselines() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 300,
            lastWeightKg: 0,
            plannedWeightKg: -10
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testHardBlockNegative() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: -5,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .hardBlock(.negative))
    }

    func testHardBlockAboveAbsoluteMax() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 400.1,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .hardBlock(.aboveAbsoluteMax))
    }

    func testExactMaxIsOk() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 400,
            lastWeightKg: nil,
            plannedWeightKg: nil
        )
        XCTAssertEqual(outcome, .ok)
    }

    func testHardWinsOverSoft() {
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 800,
            lastWeightKg: 80,
            plannedWeightKg: 80
        )
        XCTAssertEqual(outcome, .hardBlock(.aboveAbsoluteMax))
    }

    func testRegression_absurdLoggedWeight() {
        // Fat-finger 800 kg must never be soft-overrideable.
        let outcome = LoggedWeightSanity.evaluate(
            proposedKg: 800,
            lastWeightKg: 60,
            plannedWeightKg: 60
        )
        guard case .hardBlock(.aboveAbsoluteMax) = outcome else {
            return XCTFail("Expected hard block for 800 kg, got \(outcome)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/asgrimbeek/Projects/hotbod
xcodegen generate
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/LoggedWeightSanityTests \
  test
```

Expected: FAIL — `LoggedWeightSanity` type not found (or tests not in target until generate).

- [ ] **Step 3: Implement minimal domain helper**

Create `HotBod/Domain/Algorithms/LoggedWeightSanity.swift`:

```swift
import Foundation

enum LoggedWeightSanity {
    enum HardBlockReason: Equatable {
        case negative
        case aboveAbsoluteMax
    }

    enum Outcome: Equatable {
        case ok
        case softWarning(baselineKg: Double)
        case hardBlock(HardBlockReason)
    }

    static func evaluate(
        proposedKg: Double,
        lastWeightKg: Double?,
        plannedWeightKg: Double?
    ) -> Outcome {
        if proposedKg < 0 {
            return .hardBlock(.negative)
        }
        if proposedKg > GenerationConstants.Validation.maxPlannedWeightKg {
            return .hardBlock(.aboveAbsoluteMax)
        }

        let baseline: Double?
        if let last = lastWeightKg, last > 0 {
            baseline = last
        } else if let planned = plannedWeightKg, planned > 0 {
            baseline = planned
        } else {
            baseline = nil
        }

        if let baseline,
           proposedKg > baseline * GenerationConstants.Validation.weightJumpWarningMultiplier {
            return .softWarning(baselineKg: baseline)
        }
        return .ok
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/LoggedWeightSanityTests \
  test
```

Expected: PASS — all `LoggedWeightSanityTests` green.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/LoggedWeightSanity.swift \
  HotBod/Tests/UnitTests/LoggedWeightSanityTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Add LoggedWeightSanity domain gate for absurd loads.

EOF
)"
```

---

### Task 2: Localization strings for soft/hard dialogs

**Files:**
- Modify: `HotBod/Core/Localization/L10n.swift`
- Modify: `HotBod/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces:
  ```swift
  // L10n.Workout
  static let weightHardBlockTitle = String(localized: "workout.weightSanity.hard.title")
  static let weightHardBlockMessage = String(localized: "workout.weightSanity.hard.message")
  static let weightSoftWarningTitle = String(localized: "workout.weightSanity.soft.title")
  static func weightSoftWarningMessage(enteredKg: String, baselineKg: String) -> String
  static let weightSanityEdit = String(localized: "workout.weightSanity.edit")
  static let weightSanitySaveAnyway = String(localized: "workout.weightSanity.saveAnyway")
  ```
- Soft message format key: `workout.weightSanity.soft.message` value  
  `"%@ kg is far above your usual %@ kg. Edit or save anyway?"`

- [ ] **Step 1: Add L10n keys**

In `HotBod/Core/Localization/L10n.swift`, expand `enum Workout`:

```swift
enum Workout {
    static let completeTitle = String(localized: "workout.complete.title")

    static let weightHardBlockTitle = String(localized: "workout.weightSanity.hard.title")
    static let weightHardBlockMessage = String(localized: "workout.weightSanity.hard.message")
    static let weightSoftWarningTitle = String(localized: "workout.weightSanity.soft.title")
    static let weightSanityEdit = String(localized: "workout.weightSanity.edit")
    static let weightSanitySaveAnyway = String(localized: "workout.weightSanity.saveAnyway")

    static func weightSoftWarningMessage(enteredKg: String, baselineKg: String) -> String {
        String(
            format: String(localized: "workout.weightSanity.soft.message"),
            locale: .current,
            enteredKg,
            baselineKg
        )
    }
}
```

- [ ] **Step 2: Add xcstrings entries**

In `HotBod/Resources/Localizable.xcstrings` under `"strings"`, add (alphabetical-ish near other `workout.*` keys):

```json
"workout.weightSanity.edit" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Edit"
      }
    }
  }
},
"workout.weightSanity.hard.message" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "That load is beyond a sane maximum (400 kg). Fix the weight before logging."
      }
    }
  }
},
"workout.weightSanity.hard.title" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Invalid Weight"
      }
    }
  }
},
"workout.weightSanity.saveAnyway" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Save Anyway"
      }
    }
  }
},
"workout.weightSanity.soft.message" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "%@ kg is far above your usual %@ kg. Edit or save anyway?"
      }
    }
  }
},
"workout.weightSanity.soft.title" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Unusual Weight"
      }
    }
  }
}
```

- [ ] **Step 3: Build to verify strings compile**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Core/Localization/L10n.swift HotBod/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
Add copy for logged weight sanity dialogs.

EOF
)"
```

---

### Task 3: Gate Complete Set with pending dialogs

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView.swift`
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift`

**Interfaces:**
- Consumes: `LoggedWeightSanity.evaluate`, `L10n.Workout` soft/hard strings, `exerciseStatsById[exerciseId]?.lastWeightKg`, planned `targetWeightKg`
- Produces session state:
  ```swift
  enum PendingWeightSanityCommit: Equatable {
      case completeSet(bypassSanity: Bool)
      case editWeight(exerciseId: UUID, setIndex: Int, weightKg: Double)
  }
  // @State var weightSanityOutcome: LoggedWeightSanity.Outcome?
  // @State var pendingWeightSanityCommit: PendingWeightSanityCommit?
  // @State var weightSanityEnteredKg: Double = 0
  // @State var weightSanityBaselineKg: Double = 0
  ```
- Refactor: extract body of today’s `completeCurrentSet` into  
  `commitCurrentSet(exercise:meta:showWeightInput:bypassSanity:)`  
  Public `completeCurrentSet` evaluates (unless bypass) then either commits or stashes pending + shows UI.

**Pending complete-set stash:** When soft/hard fires, also stash the `exercise`, `meta`, `showWeightInput` needed to resume. Prefer storing:

```swift
struct PendingCompleteSetRequest: Equatable {
    let exerciseId: UUID
    let showWeightInput: Bool
}
```

Resolve `exercise` / `meta` from `session` + `exerciseMap` on confirm (ids are enough).

- [ ] **Step 1: Add pending state + dialogs on `WorkoutSessionView`**

Near other `@State` flags in `WorkoutSessionView.swift`, add:

```swift
@State var weightSanityOutcome: LoggedWeightSanity.Outcome?
@State var pendingWeightSanityCommit: PendingWeightSanityCommit?
@State var pendingCompleteSetRequest: PendingCompleteSetRequest?
@State var weightSanityEnteredKg: Double = 0
@State var weightSanityBaselineKg: Double = 0

private var showWeightSoftWarning: Binding<Bool> {
    Binding(
        get: {
            if case .softWarning = weightSanityOutcome { return true }
            return false
        },
        set: { if !$0 { clearWeightSanityPrompt(commit: false) } }
    )
}

private var showWeightHardBlock: Binding<Bool> {
    Binding(
        get: {
            if case .hardBlock = weightSanityOutcome { return true }
            return false
        },
        set: { if !$0 { clearWeightSanityPrompt(commit: false) } }
    )
}
```

Define supporting types in the same file (or a small extension file if preferred — keep next to session view):

```swift
enum PendingWeightSanityCommit: Equatable {
    case completeSet
    case editWeight(exerciseId: UUID, setIndex: Int, weightKg: Double)
}

struct PendingCompleteSetRequest: Equatable {
    let exerciseId: UUID
    let showWeightInput: Bool
}
```

On `body` (chain after existing confirmationDialogs), add:

```swift
.confirmationDialog(
    L10n.Workout.weightSoftWarningTitle,
    isPresented: showWeightSoftWarning,
    titleVisibility: .visible
) {
    Button(L10n.Workout.weightSanitySaveAnyway) {
        confirmWeightSanitySaveAnyway()
    }
    Button(L10n.Workout.weightSanityEdit, role: .cancel) {
        clearWeightSanityPrompt(commit: false)
    }
} message: {
    Text(
        L10n.Workout.weightSoftWarningMessage(
            enteredKg: WorkoutSessionMetricDrafts.formatWeightKg(weightSanityEnteredKg),
            baselineKg: WorkoutSessionMetricDrafts.formatWeightKg(weightSanityBaselineKg)
        )
    )
}
.alert(
    L10n.Workout.weightHardBlockTitle,
    isPresented: showWeightHardBlock
) {
    Button(L10n.Workout.weightSanityEdit, role: .cancel) {
        clearWeightSanityPrompt(commit: false)
    }
} message: {
    Text(L10n.Workout.weightHardBlockMessage)
}
```

Implement helpers on the view (new private methods in `WorkoutSessionView` or `+ExerciseActions`):

```swift
func presentWeightSanity(
    outcome: LoggedWeightSanity.Outcome,
    enteredKg: Double,
    commit: PendingWeightSanityCommit,
    completeRequest: PendingCompleteSetRequest? = nil
) {
    weightSanityEnteredKg = enteredKg
    if case .softWarning(let baseline) = outcome {
        weightSanityBaselineKg = baseline
    }
    pendingWeightSanityCommit = commit
    pendingCompleteSetRequest = completeRequest
    weightSanityOutcome = outcome
}

func clearWeightSanityPrompt(commit: Bool) {
    if !commit {
        pendingWeightSanityCommit = nil
        pendingCompleteSetRequest = nil
    }
    weightSanityOutcome = nil
}

func confirmWeightSanitySaveAnyway() {
    guard let commit = pendingWeightSanityCommit else {
        clearWeightSanityPrompt(commit: false)
        return
    }
    clearWeightSanityPrompt(commit: true)
    switch commit {
    case .completeSet:
        guard let request = pendingCompleteSetRequest,
              let exercise = session.exercises.first(where: { $0.id == request.exerciseId }),
              let meta = exerciseMap[exercise.exerciseId]
        else {
            pendingCompleteSetRequest = nil
            return
        }
        pendingCompleteSetRequest = nil
        commitCurrentSet(
            exercise: exercise,
            meta: meta,
            showWeightInput: request.showWeightInput,
            bypassSanity: true
        )
    case .editWeight(let exerciseId, let setIndex, let weightKg):
        pendingCompleteSetRequest = nil
        updateCompletedSet(exerciseId: exerciseId, setIndex: setIndex, weightKg: weightKg)
    }
}
```

Note: `clearWeightSanityPrompt(commit: true)` must not nil `pendingWeightSanityCommit` before `confirmWeightSanitySaveAnyway` reads it — either read into locals first (as above: `guard let commit` then clear outcome only) or clear outcome/flags after switch. Prefer:

```swift
func confirmWeightSanitySaveAnyway() {
    let commit = pendingWeightSanityCommit
    let request = pendingCompleteSetRequest
    weightSanityOutcome = nil
    pendingWeightSanityCommit = nil
    pendingCompleteSetRequest = nil
    // then switch on commit / request
}
```

- [ ] **Step 2: Refactor `completeCurrentSet` to evaluate then commit**

In `WorkoutSessionView+ExerciseActions.swift`, replace `completeCurrentSet` with:

```swift
func completeCurrentSet(
    exercise: WorkoutExercise,
    meta: Exercise,
    showWeightInput: Bool
) {
    dismissKeyboard()
    guard let idx = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
    let setIndex = session.exercises[idx].completedSets.count
    guard setIndex < session.exercises[idx].plannedSets.count else { return }
    let planned = session.exercises[idx].plannedSets[setIndex]

    if showWeightInput {
        let proposed = Double(weightTexts[planned.id] ?? "") ?? planned.targetWeightKg
        if let proposed {
            let outcome = LoggedWeightSanity.evaluate(
                proposedKg: proposed,
                lastWeightKg: exerciseStatsById[exercise.exerciseId]?.lastWeightKg,
                plannedWeightKg: planned.targetWeightKg
            )
            switch outcome {
            case .ok:
                break
            case .softWarning, .hardBlock:
                presentWeightSanity(
                    outcome: outcome,
                    enteredKg: proposed,
                    commit: .completeSet,
                    completeRequest: PendingCompleteSetRequest(
                        exerciseId: exercise.id,
                        showWeightInput: showWeightInput
                    )
                )
                return
            }
        }
    }

    commitCurrentSet(
        exercise: exercise,
        meta: meta,
        showWeightInput: showWeightInput,
        bypassSanity: false
    )
}

func commitCurrentSet(
    exercise: WorkoutExercise,
    meta: Exercise,
    showWeightInput: Bool,
    bypassSanity: Bool
) {
    // Move the existing completeCurrentSet body here unchanged
    // (append CompletedSet, flash, rest/RIR, syncWatchSnapshot).
    // `bypassSanity` is unused inside the body; it documents that
    // the caller already confirmed. Do not re-evaluate here.
    _ = bypassSanity
    // ... existing implementation from line ~87 onward ...
}
```

Watch path already calls `completeCurrentSet` — it automatically gets the gate.

- [ ] **Step 3: Build**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutSessionView.swift \
  HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift
git commit -m "$(cat <<'EOF'
Gate Complete Set behind logged weight sanity prompts.

EOF
)"
```

---

### Task 4: Gate completed-set weight edits

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+SetTable.swift`

**Interfaces:**
- Consumes: `LoggedWeightSanity.evaluate`, `presentWeightSanity`, `exerciseStatsById`, planned target
- Behavior:
  - Always write `weightTexts[planned.id] = newValue` (typed value preserved).
  - If set not completed yet, return (unchanged).
  - If `showWeightInput` is false, do not persist weight (unchanged).
  - If `Double(newValue)` is nil, do not call `updateCompletedSet` with a weight (avoid clearing on partial input).
  - If parsed weight evaluates `.ok` → `updateCompletedSet(...)`.
  - If `.softWarning` / `.hardBlock` → `presentWeightSanity(..., commit: .editWeight(...))` and **do not** call `updateCompletedSet` until Save anyway.

- [ ] **Step 1: Update `bindingWeight` setter**

Replace the `set:` closure in `bindingWeight` with:

```swift
set: { newValue in
    weightTexts[planned.id] = newValue
    guard completed != nil, showWeightInput else { return }
    guard let weight = Double(newValue) else { return }

    let exerciseIdString = session.exercises.first(where: { $0.id == exerciseId })?.exerciseId
    let last = exerciseIdString.flatMap { exerciseStatsById[$0]?.lastWeightKg }
    let outcome = LoggedWeightSanity.evaluate(
        proposedKg: weight,
        lastWeightKg: last,
        plannedWeightKg: planned.targetWeightKg
    )
    switch outcome {
    case .ok:
        updateCompletedSet(exerciseId: exerciseId, setIndex: setIndex, weightKg: weight)
    case .softWarning, .hardBlock:
        presentWeightSanity(
            outcome: outcome,
            enteredKg: weight,
            commit: .editWeight(
                exerciseId: exerciseId,
                setIndex: setIndex,
                weightKg: weight
            )
        )
    }
}
```

`confirmWeightSanitySaveAnyway` (Task 3) already handles `.editWeight` via `updateCompletedSet`.

- [ ] **Step 2: Build**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke (simulator)**

1. Start a workout with a loaded exercise that has a planned target (or prior stats).
2. Enter **800** on Complete Set → hard-block alert; set not logged; field still shows 800; fix to a normal load → completes.
3. Enter a jump under 400 but >1.5× baseline (e.g. 150 vs 80) → soft dialog; Edit aborts save; Save Anyway logs the set.
4. Complete a set normally, then edit completed weight to 800 → hard block; completed weight unchanged until fixed/confirmed path.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutSessionView+SetTable.swift
git commit -m "$(cat <<'EOF'
Gate completed-set weight edits with sanity checks.

EOF
)"
```

---

### Task 5: Final verification

**Files:** none new

- [ ] **Step 1: Run domain tests + build**

```bash
cd /Users/asgrimbeek/Projects/hotbod
xcodegen generate
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/LoggedWeightSanityTests \
  test
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

Expected: all `LoggedWeightSanityTests` PASS; BUILD SUCCEEDED.

- [ ] **Step 2: Spec checklist**

Confirm against `docs/superpowers/specs/2026-07-16-logged-weight-sanity-design.md`:

- [ ] Hard block >400 and <0
- [ ] Soft warning vs last then planned
- [ ] Hard wins over soft
- [ ] Complete Set gated
- [ ] Completed-set edit gated
- [ ] Save anyway once / Edit keeps typed value
- [ ] No-load exercises skipped
- [ ] Unit tests including `testRegression_absurdLoggedWeight`

- [ ] **Step 3: Commit plan checkbox updates only if you tracked them; otherwise done**

No further code commit required if Tasks 1–4 already committed cleanly.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Hard block >400 / <0 | Task 1 + 3 + 4 |
| Soft warning 1.5× last else planned | Task 1 + 3 + 4 |
| Hard wins over soft | Task 1 |
| Complete Set gate | Task 3 |
| Edit completed weight gate | Task 4 |
| Edit keeps typed value | Task 3/4 (`weightTexts` always set) |
| Save anyway once | Task 3 `bypassSanity` / edit commit |
| Skip no-load | Task 3 `showWeightInput` / Task 4 guard |
| Domain unit tests + regression | Task 1 |
| L10n copy | Task 2 |
| No schema change | All tasks |

## Placeholder / consistency check

- Types `PendingWeightSanityCommit`, `PendingCompleteSetRequest`, `LoggedWeightSanity.Outcome` named consistently across Tasks 1–4.
- No TBD / “add validation later” steps.
- Thresholds referenced only via `GenerationConstants.Validation`.
