# Exercise Complete Full-Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Exercise Complete a true full-screen session state and never start rest after the last planned set of an exercise.

**Architecture:** Extract last-set / between-set post-action decisions into a pure `PostSetActionPlanner` in Domain (testable). Present `ExerciseCompleteInterstitial` as a top-level branch in `WorkoutSessionView` (same pattern as `showCompletion`), and tighten the interstitial layout for a solid full-screen surface.

**Tech Stack:** Swift 6, SwiftUI, XCTest / XCUITest, `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-07-16-exercise-complete-fullscreen-design.md`

## Global Constraints

- iOS 17+.
- Preserve local-first architecture; no backend dependency.
- Keep accessibility IDs `session.exerciseComplete` and `session.exerciseComplete.continue`.
- Do not redesign metrics or switch to `ForgeHeroCard`.
- Do not change between-set rest for non-final sets.
- Regression tests use the `testRegression_` prefix.
- UI test launches with `-UITesting -ResetState -MockAI -MockFoodSearch -SkipOnboarding`.
- Final verification uses the `PR` configuration in `HotBod.xctestplan`.
- Do not alter unrelated uncommitted changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Algorithms/PostSetActionPlanner.swift` | Owns `PendingPostSetAction` + pure planner for post-set next action |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+Feedback.swift` | Rest timer / execute action; no longer defines `PendingPostSetAction` |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` | Calls planner when a set is completed |
| `HotBod/Features/WorkoutSession/WorkoutSessionView.swift` | Top-level `showExerciseComplete` branch; removes footer interstitial |
| `HotBod/Features/WorkoutSession/ExerciseCompleteInterstitial.swift` | Full-screen layout (solid bg, centered content, bottom CTA) |
| `HotBod/Core/DesignSystem/ForgeFeedback.swift` | Rest Skip accessibility ID for reliable UI tests |
| `HotBod/Tests/UnitTests/PostSetActionPlannerTests.swift` | Domain regression coverage |
| `HotBod/Tests/UITests/Pages/TodayPage.swift` | Page-object accessors for exercise complete / rest skip |
| `HotBod/Tests/UITests/WorkoutSessionUITests.swift` | Full-screen UI assertion |
| `HotBod.xcodeproj/xcshareddata/xctestplans/HotBod.xctestplan` | PR selected UI test entry |
| `HotBod.xctestplan` | Keep in sync if this root copy is used |

---

### Task 1: Extract `PostSetActionPlanner` (TDD)

**Files:**
- Create: `HotBod/Domain/Algorithms/PostSetActionPlanner.swift`
- Create: `HotBod/Tests/UnitTests/PostSetActionPlannerTests.swift`
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+Feedback.swift` (remove enum definition only)

**Interfaces:**
- Produces: `enum PendingPostSetAction: Equatable { case rest(seconds: Int, advanceAfter: Bool); case exerciseComplete }`
- Produces: `PostSetActionPlanner.action(allSetsDone:isWarmup:isCooldown:exerciseRestSeconds:) -> PendingPostSetAction`
- Consumes: `GenerationConstants.Warmup.restSeconds`, `GenerationConstants.Cooldown.restSeconds`

- [ ] **Step 1: Write failing unit tests**

Create `HotBod/Tests/UnitTests/PostSetActionPlannerTests.swift`:

```swift
import XCTest
@testable import HotBod

final class PostSetActionPlannerTests: XCTestCase {
    func testRegression_lastPlannedSetNeverStartsRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: true,
            isWarmup: false,
            isCooldown: false,
            exerciseRestSeconds: 120
        )
        XCTAssertEqual(action, .exerciseComplete)
    }

    func testRegression_lastWarmupSetNeverStartsRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: true,
            isWarmup: true,
            isCooldown: false,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .exerciseComplete)
    }

    func testBetweenSetsUsesExerciseRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: false,
            isWarmup: false,
            isCooldown: false,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .rest(seconds: 90, advanceAfter: false))
    }

    func testBetweenWarmupSetsUsesWarmupRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: false,
            isWarmup: true,
            isCooldown: false,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .rest(seconds: GenerationConstants.Warmup.restSeconds, advanceAfter: false))
    }

    func testBetweenCooldownSetsUsesCooldownRest() {
        let action = PostSetActionPlanner.action(
            allSetsDone: false,
            isWarmup: false,
            isCooldown: true,
            exerciseRestSeconds: 90
        )
        XCTAssertEqual(action, .rest(seconds: GenerationConstants.Cooldown.restSeconds, advanceAfter: false))
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PostSetActionPlannerTests test
```

Expected: FAIL — `PostSetActionPlanner` is undefined.

- [ ] **Step 3: Implement planner and move enum**

Create `HotBod/Domain/Algorithms/PostSetActionPlanner.swift`:

```swift
import Foundation

enum PendingPostSetAction: Equatable {
    case rest(seconds: Int, advanceAfter: Bool)
    case exerciseComplete
}

enum PostSetActionPlanner {
    static func action(
        allSetsDone: Bool,
        isWarmup: Bool,
        isCooldown: Bool,
        exerciseRestSeconds: Int
    ) -> PendingPostSetAction {
        if allSetsDone {
            return .exerciseComplete
        }

        let restSeconds: Int
        if isWarmup {
            restSeconds = GenerationConstants.Warmup.restSeconds
        } else if isCooldown {
            restSeconds = GenerationConstants.Cooldown.restSeconds
        } else {
            restSeconds = exerciseRestSeconds
        }
        return .rest(seconds: restSeconds, advanceAfter: false)
    }
}
```

In `HotBod/Features/WorkoutSession/WorkoutSessionView+Feedback.swift`, delete the local enum:

```swift
enum PendingPostSetAction: Equatable {
    case rest(seconds: Int, advanceAfter: Bool)
    case exerciseComplete
}
```

Leave the rest of that file unchanged. Domain sources under `HotBod/` are already included via `project.yml` (`path: HotBod`).

- [ ] **Step 4: Run tests and verify pass**

Run the same `xcodebuild` command as Step 2.

Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/PostSetActionPlanner.swift \
  HotBod/Tests/UnitTests/PostSetActionPlannerTests.swift \
  HotBod/Features/WorkoutSession/WorkoutSessionView+Feedback.swift
git commit -m "$(cat <<'EOF'
Extract PostSetActionPlanner so last sets never start rest.

EOF
)"
```

---

### Task 2: Wire planner into set completion

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` (the `allSetsDone` / `postAction` block in `completeCurrentSet`)

**Interfaces:**
- Consumes: `PostSetActionPlanner.action(allSetsDone:isWarmup:isCooldown:exerciseRestSeconds:)`
- Removes call site use of `ExerciseGroupPlanner.restBeforeAdvancing` for last-set completion

- [ ] **Step 1: Replace inline post-action decision**

In `completeCurrentSet`, replace:

```swift
let allSetsDone = session.exercises[idx].completedSets.count >= session.exercises[idx].plannedSets.count
let postAction: PendingPostSetAction
if allSetsDone {
    let transitionRest = ExerciseGroupPlanner.restBeforeAdvancing(from: idx, exercises: session.exercises)
    if transitionRest > 0 {
        postAction = .rest(seconds: transitionRest, advanceAfter: true)
    } else {
        postAction = .exerciseComplete
    }
} else {
    let restSeconds: Int
    if planned.isWarmup {
        restSeconds = GenerationConstants.Warmup.restSeconds
    } else if planned.isCooldown {
        restSeconds = GenerationConstants.Cooldown.restSeconds
    } else {
        restSeconds = session.exercises[idx].restSeconds
    }
    postAction = .rest(seconds: restSeconds, advanceAfter: false)
}
```

with:

```swift
let allSetsDone = session.exercises[idx].completedSets.count >= session.exercises[idx].plannedSets.count
let postAction = PostSetActionPlanner.action(
    allSetsDone: allSetsDone,
    isWarmup: planned.isWarmup,
    isCooldown: planned.isCooldown,
    exerciseRestSeconds: session.exercises[idx].restSeconds
)
```

Do not change RIR prompt gating or `executePostSetAction` call sites.

- [ ] **Step 2: Build to confirm compile**

Run:

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Re-run planner unit tests**

Run:

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PostSetActionPlannerTests test
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift
git commit -m "$(cat <<'EOF'
Route set completion through PostSetActionPlanner.

EOF
)"
```

---

### Task 3: Full-screen presentation + interstitial layout

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView.swift`
- Modify: `HotBod/Features/WorkoutSession/ExerciseCompleteInterstitial.swift`

**Interfaces:**
- Consumes: `showExerciseComplete`, `exerciseCompleteSummary(for:meta:)`, `advanceExercise()`
- Produces: top-level branch that replaces session content when `showExerciseComplete` is true

- [ ] **Step 1: Move interstitial to top-level branch**

In `WorkoutSessionView.body`, change the `Group` so exercise complete is a sibling of workout completion / session (not nested in `sessionContent`):

```swift
var body: some View {
    Group {
        if showCompletion {
            Group {
                if UITestConfiguration.isUITesting {
                    uitestCompletionView
                } else {
                    WorkoutCompletionView(
                        session: session,
                        progressionNotes: progressionNotes,
                        workoutStreak: completionWorkoutStreak,
                        exerciseMap: exerciseMap
                    ) {
                        Task {
                            await environment.refreshWorkoutAfterSession(session)
                            router.dismissToMain()
                        }
                    }
                }
            }
            .transition(ForgeMotion.rise)
            .id("completion")
        } else if showExerciseComplete,
                  let exercise = currentExercise,
                  let meta = exerciseMap[exercise.exerciseId] {
            let summary = exerciseCompleteSummary(for: exercise, meta: meta)
            ExerciseCompleteInterstitial(
                exerciseName: meta.name,
                setsCompleted: summary.setsCompleted,
                volumeKg: summary.volumeKg,
                bestSetDescription: summary.bestSetDescription,
                averageRPE: summary.averageRPE,
                onContinue: {
                    showExerciseComplete = false
                    advanceExercise()
                }
            )
            .transition(ForgeMotion.rise)
            .id("exerciseComplete")
        } else if let exercise = currentExercise, let meta = exerciseMap[exercise.exerciseId] {
            sessionContent(exercise: exercise, meta: meta)
                .transition(UITestConfiguration.isUITesting ? .identity : ForgeMotion.appear)
                .id("session")
        } else {
            ProgressView()
                .accessibilityIdentifier("session.loading")
                .id("loading")
        }
    }
    .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.standard, value: showCompletion)
    .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.standard, value: showExerciseComplete)
    .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.exercise, value: currentExerciseIndex)
    // ... keep existing overlay / sheets unchanged
}
```

- [ ] **Step 2: Remove footer interstitial from `sessionContent`**

Delete this block from the bottom of `sessionContent`’s `VStack` (after the rest timer):

```swift
if showExerciseComplete, let exercise = currentExercise, let meta = exerciseMap[exercise.exerciseId] {
    let summary = exerciseCompleteSummary(for: exercise, meta: meta)
    ExerciseCompleteInterstitial(
        exerciseName: meta.name,
        setsCompleted: summary.setsCompleted,
        volumeKg: summary.volumeKg,
        bestSetDescription: summary.bestSetDescription,
        averageRPE: summary.averageRPE,
        onContinue: {
            showExerciseComplete = false
            advanceExercise()
        }
    )
    .transition(ForgeMotion.rise)
}
```

Leave the rest timer block in `sessionContent` as-is.

- [ ] **Step 3: Update interstitial layout for true full screen**

Replace `ExerciseCompleteInterstitial.body` with:

```swift
var body: some View {
    VStack(spacing: 0) {
        Spacer(minLength: ForgeSpacing.s6)

        VStack(spacing: ForgeSpacing.s5) {
            Text("EXERCISE COMPLETE")
                .font(ForgeTypography.label)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accentGreen)

            Text(exerciseName)
                .font(ForgeTypography.display)
                .foregroundStyle(ForgeColors.textPrimary)
                .multilineTextAlignment(.center)

            ForgeCard {
                VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
                    statRow(label: "Sets logged", value: "\(setsCompleted)")
                    statRow(label: "Volume", value: "\(Int(volumeKg))kg")
                    if let bestSetDescription {
                        statRow(label: "Best set", value: bestSetDescription)
                    }
                    if let averageRPE {
                        statRow(label: "Avg effort", value: String(format: "RPE %.1f", averageRPE))
                    }
                }
            }
        }
        .padding(.horizontal, ForgeSpacing.s5)

        Spacer(minLength: ForgeSpacing.s6)

        ForgeButton(
            title: "Next Exercise",
            style: .accent,
            accessibilityIdentifier: "session.exerciseComplete.continue",
            action: onContinue
        )
        .padding(.horizontal, ForgeSpacing.s5)
        .padding(.bottom, ForgeSpacing.s6)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ForgeColors.background)
    .accessibilityIdentifier("session.exerciseComplete")
}
```

Keep `statRow` and the `#Preview` unchanged aside from compiling against the new body.

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutSessionView.swift \
  HotBod/Features/WorkoutSession/ExerciseCompleteInterstitial.swift
git commit -m "$(cat <<'EOF'
Present Exercise Complete as a full-screen session state.

EOF
)"
```

---

### Task 4: UI coverage for full-screen takeover

**Files:**
- Modify: `HotBod/Core/DesignSystem/ForgeFeedback.swift` (`ForgeRestTimerBar` Skip button)
- Modify: `HotBod/Tests/UITests/Pages/TodayPage.swift` (`WorkoutSessionPage`)
- Modify: `HotBod/Tests/UITests/WorkoutSessionUITests.swift`
- Modify: `HotBod.xcodeproj/xcshareddata/xctestplans/HotBod.xctestplan`
- Modify: `HotBod.xctestplan` (if present and used; keep selectedTests in sync)

**Interfaces:**
- Produces: rest skip ID `session.rest.skip`
- Produces: `WorkoutSessionPage.exerciseComplete` / `exerciseCompleteContinue` / `restSkipButton`
- Produces: `testRegression_exerciseCompleteIsFullScreen`

- [ ] **Step 1: Add rest Skip accessibility ID**

In `ForgeRestTimerBar`, update the Skip button:

```swift
Button("Skip", action: onSkip)
    .font(ForgeTypography.label.weight(.semibold))
    .accessibilityIdentifier("session.rest.skip")
```

- [ ] **Step 2: Extend `WorkoutSessionPage`**

In `HotBod/Tests/UITests/Pages/TodayPage.swift`, add to `WorkoutSessionPage`:

```swift
var exerciseComplete: XCUIElement {
    app.descendants(matching: .any)["session.exerciseComplete"]
}

var exerciseCompleteContinue: XCUIElement {
    let byId = app.buttons["session.exerciseComplete.continue"]
    if byId.exists { return byId }
    return app.buttons["Next Exercise"]
}

var restSkipButton: XCUIElement {
    app.buttons["session.rest.skip"]
}

var rirSkipButton: XCUIElement {
    app.buttons["workout.rir.skip"]
}

func dismissTransientPromptsIfNeeded() {
    if rirSkipButton.waitForExistence(timeout: 1) {
        rirSkipButton.tap()
    }
    if restSkipButton.waitForExistence(timeout: 1) {
        restSkipButton.tap()
    }
}
```

- [ ] **Step 3: Add failing/asserting UI regression test**

Add to `WorkoutSessionUITests`:

```swift
func testRegression_exerciseCompleteIsFullScreen() {
    XCTAssertTrue(session.waitForSession())

    var sawExerciseComplete = false
    for _ in 0..<24 {
        session.dismissTransientPromptsIfNeeded()

        if session.exerciseComplete.waitForExistence(timeout: 1) {
            sawExerciseComplete = true
            break
        }

        if session.completeSetButton.waitForExistence(timeout: 2) {
            if session.completeSetButton.isHittable {
                session.completeSetButton.tap()
            } else {
                session.completeSetButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            session.dismissTransientPromptsIfNeeded()
            continue
        }

        session.dismissTransientPromptsIfNeeded()
    }

    XCTAssertTrue(sawExerciseComplete, "Expected Exercise Complete after finishing an exercise")
    XCTAssertTrue(session.exerciseComplete.waitForExistence(timeout: 2))
    XCTAssertTrue(session.exerciseCompleteContinue.waitForExistence(timeout: 2))
    XCTAssertFalse(session.completeSetButton.exists, "Active session Complete Set must not remain visible")
}
```

- [ ] **Step 4: Add test to PR selectedTests**

In both `HotBod.xcodeproj/xcshareddata/xctestplans/HotBod.xctestplan` and root `HotBod.xctestplan` (if it mirrors), add to the PR configuration `selectedTests` array:

```text
"WorkoutSessionUITests/testRegression_exerciseCompleteIsFullScreen"
```

- [ ] **Step 5: Run the UI test**

Run:

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodUITests/WorkoutSessionUITests/testRegression_exerciseCompleteIsFullScreen \
  test
```

Expected: PASS. If RIR/rest timing flakes, tighten `dismissTransientPromptsIfNeeded` waits before changing product behavior.

- [ ] **Step 6: Commit**

```bash
git add HotBod/Core/DesignSystem/ForgeFeedback.swift \
  HotBod/Tests/UITests/Pages/TodayPage.swift \
  HotBod/Tests/UITests/WorkoutSessionUITests.swift \
  HotBod.xcodeproj/xcshareddata/xctestplans/HotBod.xctestplan \
  HotBod.xctestplan
git commit -m "$(cat <<'EOF'
Add UI regression for full-screen Exercise Complete.

EOF
)"
```

---

### Task 5: Final verification

**Files:**
- None (verification only), unless build/test failures require fixes in files from Tasks 1–4

- [ ] **Step 1: Build**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Run planner unit tests + PR config sample**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PostSetActionPlannerTests \
  -only-testing:HotBodUITests/WorkoutSessionUITests/testRegression_exerciseCompleteIsFullScreen \
  test
```

Expected: all listed tests PASS.

- [ ] **Step 3: Manual smoke (Simulator)**

1. Start a workout.
2. Complete all sets of the first exercise (skip RIR if prompted).
3. Confirm: full-screen Exercise Complete only — no set table, no Complete Set, no rest bar.
4. Tap Next Exercise → next exercise active session appears.
5. Complete a non-final set → rest bar still appears.

- [ ] **Step 4: Commit docs if not already committed**

```bash
git add docs/superpowers/specs/2026-07-16-exercise-complete-fullscreen-design.md \
  docs/superpowers/plans/2026-07-16-exercise-complete-fullscreen.md
git commit -m "$(cat <<'EOF'
Document Exercise Complete full-screen design and plan.

EOF
)"
```

---

## Spec Coverage Self-Review

| Spec requirement | Task |
|------------------|------|
| Top-level branch like workout completion | Task 3 |
| Remove footer interstitial from session VStack | Task 3 |
| Solid background, centered content, bottom CTA | Task 3 |
| Last set → never rest / always exercise complete | Tasks 1–2 |
| Between-set rest unchanged | Tasks 1–2 |
| Keep accessibility IDs | Tasks 3–4 |
| Regression + UI full-screen assertion | Tasks 1, 4 |
| Leave `restBeforeAdvancing` for other callers | Task 2 (call site removed only) |

## Placeholder / consistency check

- No TBD/TODO placeholders.
- `PendingPostSetAction` lives in Domain after Task 1; Feedback/ExerciseActions consume the same type name.
- `advanceAfter: true` is intentionally unused by the new planner; restored in-flight rests with `activeRestAdvancesExercise` may still advance via existing rest-end path — out of scope to delete that restore path in this plan.
