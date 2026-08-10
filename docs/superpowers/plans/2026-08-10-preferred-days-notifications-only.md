# Preferred Days Notifications-Only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop preferred training days from blocking workout generation; keep them for soft Recovery UI and future reminders while auto-building the next rotation session any day.

**Architecture:** Remove `allowsUnscheduledDay` / rest-day generation overrides from `AppEnvironment`. Treat `TrainingSchedule.isTrainingDay` as a preference/UI helper only. Bootstrap and regenerate always follow split rotation. Today composes Recovery hero + secondary plan on non-preferred days.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-10-preferred-days-notifications-only-design.md`

## Global Constraints

- iOS 17+.
- Local-first; no backend dependency or schema migration.
- Preferred days never block generation, restart, split-switch, readiness refresh, or bootstrap.
- Soft Recovery framing remains on non-preferred days; no medical claims.
- User-initiated regenerate keeps the same Pro / free-quota rules as preferred days (no rest-day free-regenerate loophole).
- Do not implement local notification scheduling in this plan.
- Do not rename persisted profile fields or remove `trainingDaysPerWeek`.
- Regression tests use the `testRegression_` prefix.
- Final verification uses the `PR` configuration in `HotBod.xctestplan`.
- Do not alter unrelated uncommitted changes (e.g. incidental `project.pbxproj` noise).

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/App/AppEnvironment+Workout.swift` | Generation APIs without calendar gates; delete rest-day override path |
| `HotBod/App/AppEnvironment.swift` | `revalidateTodayPlanForCurrentDay` auto-generates every day; keep `isRestDay` as preference flag |
| `HotBod/App/AppEnvironment+Profile.swift` | Onboarding ensures a plan on non-preferred days without auto-starting |
| `HotBod/Features/Today/TodayView.swift` | Soft Recovery + secondary plan; `today.generate` |
| `HotBod/Features/WorkoutSession/WorkoutHeroRefresh.swift` | Drop `.trainAnyway` refresh kind |
| `HotBod/Features/WorkoutSession/TrainViews.swift` | Drop `.trainAnyway` switch arm |
| `HotBod/Services/AI/CoachModificationSafety.swift` | Soft rest-day coach copy |
| `HotBod/Features/Settings/SettingsView+Training.swift` | Reminder-oriented schedule copy |
| `HotBod/Features/Onboarding/OnboardingViews.swift` | Reminder-oriented preferred-days copy |
| `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` | Flipped/new generation regressions |
| `HotBod/Tests/UnitTests/CoachDomainTests.swift` | Soft coach copy assertions |
| `HotBod/Tests/UITests/TodayWorkoutUITests.swift` | Recovery + plan UI regression |
| `HotBod/Tests/UITests/Pages/TodayPage.swift` | `today.generate` page object |
| `HotBod/Tests/UITests/BaseUITestCase.swift` | Wait helpers without `today.trainAnyway` |
| `HotBod.xctestplan` | Update selected UI test name if renamed |

---

### Task 1: Unblock generation APIs (TDD)

**Files:**
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`
- Modify: `HotBod/App/AppEnvironment+Workout.swift`

**Interfaces:**
- Consumes: `AppEnvironment.makeForTests`, `FixedMockWorkoutGenerationService`, `TrainingSchedule.weekday()`, `UserProfile.empty()`
- Produces (public surface after this task):
  ```swift
  // AppEnvironment
  @discardableResult
  func regenerateTodayWorkout(
      profile: UserProfile,
      options: WorkoutGenerationOptions = WorkoutGenerationOptions()
  ) async -> Bool

  @discardableResult
  func ensureTodayWorkoutOnLaunch(profile: UserProfile) async -> Bool

  @discardableResult
  func refreshTodayWorkoutForReadinessChange(profile: UserProfile) async -> Bool

  @discardableResult
  func restartTodayWorkout(
      profile: UserProfile,
      options: WorkoutGenerationOptions = WorkoutGenerationOptions()
  ) async -> Bool

  @discardableResult
  func switchTodaySplitFocus() async -> Bool

  @discardableResult
  func generateLighterWorkoutAfterFatigue(profile: UserProfile) async -> Bool
  ```
- Removes: `generateTodayWorkoutOnRestDay`, private `allowsUnscheduledDay` parameter on regenerate
- `isRestDay` remains as `!TrainingSchedule.isTrainingDay(profile:)` for UI only

- [ ] **Step 1: Write failing / flipped tests**

In `AppEnvironmentOrchestrationTests` (or the existing workout-generation test class in that file):

1. Replace `testRegression_normalRegenerationRemainsBlockedOnUnscheduledDay` with:

```swift
func testRegression_regenerateSucceedsOnNonPreferredDayWithoutExistingPlan() async {
    let workout = FixtureBuilders.makeGeneratedWorkout()
    let generator = FixedMockWorkoutGenerationService(workout: workout)
    let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
    let today = TrainingSchedule.weekday()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2
    env.userProfile = profile
    env.recoveryStates = RecoveryCalculator.defaultStates()

    let generated = await env.regenerateTodayWorkout(profile: profile)

    XCTAssertTrue(generated)
    XCTAssertEqual(env.todayWorkout?.id, workout.id)
}
```

2. Update `testRegression_trainAnywayGeneratesOnUnscheduledDay` to call `regenerateTodayWorkout` instead of `generateTodayWorkoutOnRestDay`, and rename to `testRegression_regenerateOnNonPreferredDay`.

3. Replace `testRegression_readinessRefreshSkipsBareRestDay` with:

```swift
func testRegression_readinessRefreshGeneratesOnBareNonPreferredDay() async {
    let workout = FixtureBuilders.makeGeneratedWorkout()
    let generator = FixedMockWorkoutGenerationService(workout: workout)
    let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
    let today = TrainingSchedule.weekday()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2
    env.userProfile = profile
    env.recoveryStates = RecoveryCalculator.defaultStates()

    let refreshed = await env.refreshTodayWorkoutForReadinessChange(profile: profile)

    XCTAssertTrue(refreshed)
    XCTAssertEqual(env.todayWorkout?.id, workout.id)
}
```

4. Update every remaining `generateTodayWorkoutOnRestDay` call in this file to `regenerateTodayWorkout` (or `ensureTodayWorkoutOnLaunch` when the test is about free/initial generation). Keep quota tests’ intent: rest/non-preferred must not create a free unlimited regenerate loophole for user-initiated regenerate.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentWorkoutGenerationTests/testRegression_regenerateSucceedsOnNonPreferredDayWithoutExistingPlan \
  test
```

If the class name differs, find it with:

```bash
rg -n "testRegression_normalRegenerationRemainsBlocked|class AppEnvironment" HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
```

Expected: FAIL because regenerate still returns `false` on non-preferred days with no plan, or `generateTodayWorkoutOnRestDay` still referenced.

- [ ] **Step 3: Simplify `AppEnvironment+Workout.swift`**

Replace the public regenerate entry points and delete the rest-day override:

```swift
@discardableResult
func regenerateTodayWorkout(
    profile: UserProfile,
    options: WorkoutGenerationOptions = WorkoutGenerationOptions()
) async -> Bool {
    await regenerateTodayWorkout(
        profile: profile,
        options: options,
        requiresProAccess: SubscriptionConfig.unrestrictedAccess ? false : true
    )
}

@discardableResult
func ensureTodayWorkoutOnLaunch(profile: UserProfile) async -> Bool {
    await regenerateTodayWorkout(
        profile: profile,
        options: WorkoutGenerationOptions(),
        requiresProAccess: false
    )
}

@discardableResult
func refreshTodayWorkoutForReadinessChange(profile: UserProfile) async -> Bool {
    guard !isTodayWorkoutCompleted else { return false }
    return await regenerateTodayWorkout(profile: profile)
}

private func regenerateTodayWorkout(
    profile: UserProfile,
    options: WorkoutGenerationOptions,
    requiresProAccess: Bool
) async -> Bool {
    guard !isTodayWorkoutCompleted else { return false }
    cancelWorkoutGenerationIfNeeded()
    guard reserveWorkoutGeneration() else { return false }
    defer { releaseWorkoutGenerationReservation() }

    if requiresProAccess {
        guard canAccess(.unlimitedGeneration) else {
            presentPaywall(for: .unlimitedGeneration)
            return false
        }
    }

    await cancelActiveWorkoutIfNeeded()
    await applyRecoveryDecay()

    let splitFocus = TrainingSchedule.currentSplitFocus(state: programState, split: profile.preferredSplit)
    var effectiveOptions = options
    if effectiveOptions.excludeExerciseIds.isEmpty, let current = todayWorkout {
        effectiveOptions.excludeExerciseIds = current.exercises.map(\.exerciseId)
        effectiveOptions.preferVariation = true
    }

    if await persistRegeneratedWorkoutWithFallback(
        profile: profile,
        splitDayFocus: splitFocus,
        options: effectiveOptions
    ) {
        if requiresProAccess, !isPro { await recordRegenerationUsage() }
        return true
    }
    return false
}
```

Also:

- Delete `generateTodayWorkoutOnRestDay`.
- In `restartTodayWorkout`, remove `guard TrainingSchedule.isTrainingDay(profile: profile) else { return false }`.
- In `switchTodaySplitFocus`, remove the `TrainingSchedule.isTrainingDay` guard (keep `userProfile` guard).
- In `generateLighterWorkoutAfterFatigue`, remove the `isRestDay` branch; call regenerate/restart with `requiresProAccess: false` via `ensure`-style path or a direct private call that does not charge quota (preserve existing free lighter-workout semantics).

- [ ] **Step 4: Run focused tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentWorkoutGenerationTests \
  test
```

Expected: PASS for the flipped regenerate/readiness tests. Fix any compile errors from deleted `generateTodayWorkoutOnRestDay` references in unit tests first.

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment+Workout.swift HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
git commit -m "$(cat <<'EOF'
fix: allow workout generation on non-preferred days

Preferred days no longer gate regenerate, restart, or split switch.
EOF
)"
```

---

### Task 2: Bootstrap, day rollover, onboarding

**Files:**
- Modify: `HotBod/App/AppEnvironment.swift` (`revalidateTodayPlanForCurrentDay`, UITest bootstrap branch)
- Modify: `HotBod/App/AppEnvironment+Profile.swift` (`finishOnboardingAndStartTodayWorkout`)
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` (`AppEnvironmentDayRolloverTests` / onboarding tests)

**Interfaces:**
- Consumes: `ensureTodayWorkoutOnLaunch(profile:)` from Task 1
- Produces: same method names; behavior change only
  ```swift
  func revalidateTodayPlanForCurrentDay() async
  func finishOnboardingAndStartTodayWorkout(
      profile: UserProfile,
      lockSplit: Bool = false
  ) async -> WorkoutSession?
  ```

- [ ] **Step 1: Write failing tests**

Add to day-rollover / orchestration tests:

```swift
func testRegression_bootstrapAutoGeneratesOnNonPreferredDay() async {
    let workout = FixtureBuilders.makeGeneratedWorkout()
    let generator = FixedMockWorkoutGenerationService(workout: workout)
    let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
    let today = TrainingSchedule.weekday()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2
    env.userProfile = profile
    env.hasCompletedOnboarding = true
    env.recoveryStates = RecoveryCalculator.defaultStates()

    await env.revalidateTodayPlanForCurrentDay()

    XCTAssertEqual(env.todayWorkout?.id, workout.id)
    XCTAssertTrue(env.isRestDay)
}

func testRegression_revalidateDoesNotClearFreshPlanOnNonPreferredDay() async throws {
    let fresh = FixtureBuilders.makeGeneratedWorkout(createdAt: Date())
    var repos = TestRepositories.empty()
    try await repos.workout.saveTodayWorkout(fresh)
    let env = AppEnvironment.makeForTests(repos: repos)
    let today = TrainingSchedule.weekday()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2
    env.userProfile = profile
    env.hasCompletedOnboarding = true
    env.todayWorkout = fresh

    await env.revalidateTodayPlanForCurrentDay()

    XCTAssertEqual(env.todayWorkout?.id, fresh.id)
}
```

Update onboarding regression that currently expects no generation on unscheduled completion day: after finish, `todayWorkout` must be non-nil while `preferredTrainingDays` still excludes today, and the returned session may be `nil` (no auto-start on non-preferred day).

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentDayRolloverTests/testRegression_bootstrapAutoGeneratesOnNonPreferredDay \
  test
```

Expected: FAIL — rest-day branch clears or skips generation.

- [ ] **Step 3: Implement bootstrap / onboarding behavior**

In `revalidateTodayPlanForCurrentDay()` replace the training-day / rest-day split with one path:

```swift
func revalidateTodayPlanForCurrentDay() async {
    guard hasCompletedOnboarding, let profile = userProfile else { return }
    await normalizeProgramStateForToday(profile: profile)
    let generationBlocked = isWorkoutGenerationInFlight
        || isWorkoutGenerationReserved
        || isStartingWorkoutSession
    let now = Date()
    let calendar = Calendar.current
    if todayWorkout == nil, !isTodayWorkoutCompleted, !generationBlocked {
        await ensureTodayWorkoutOnLaunch(profile: profile)
    } else if let workout = todayWorkout,
              !generationBlocked,
              await shouldRegenerateStaleTodayWorkout(workout, now: now, calendar: calendar),
              !isTodayWorkoutCompleted {
        await ensureTodayWorkoutOnLaunch(profile: profile)
    }
}
```

Also update the UITest bootstrap branch in `bootstrap()` that currently gates `ensureTodayWorkoutOnLaunch` on `isTrainingDay` — call ensure whenever UI tests are not forcing a special start/preview path, including `-ForceRestDay`, so rest-day fixtures get a plan.

In `finishOnboardingAndStartTodayWorkout`:

```swift
await normalizeProgramStateForToday(profile: updated)
guard await ensureTodayWorkoutOnLaunch(profile: updated),
      let workout = todayWorkout else {
    if todayWorkout == nil {
        syncMessage = "Onboarding saved, but today's workout could not be generated. Open Today to regenerate."
    }
    return nil
}

// Preferred day: auto-start. Non-preferred: leave plan ready under Recovery UI.
guard TrainingSchedule.isTrainingDay(profile: updated) else {
    syncMessage = nil
    return nil
}

return await resumeOrStartWorkout(
    from: workout,
    deferStartTimestamp: !UITestConfiguration.isUITesting
)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentDayRolloverTests \
  -only-testing:HotBodTests/AppEnvironmentOnboardingAndCoachTests \
  test
```

Expected: PASS (adjust class names if the local suite differs).

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment.swift HotBod/App/AppEnvironment+Profile.swift HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
git commit -m "$(cat <<'EOF'
fix: auto-generate today's plan on non-preferred days

Bootstrap and onboarding ensure the next rotation session even when
today is outside preferred training days.
EOF
)"
```

---

### Task 3: Rotation focus across a non-preferred day

**Files:**
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` and/or `HotBod/Tests/UnitTests/TrainingScheduleDomainTests.swift`

**Interfaces:**
- Consumes: `TrainingSchedule.advanceRotation`, `TrainingSchedule.currentSplitFocus`, `ensureTodayWorkoutOnLaunch`
- Produces: no new API — regression coverage only

- [ ] **Step 1: Write failing test**

Prefer a pure schedule assertion if generation wiring is already covered; otherwise orchestration:

```swift
func testRegression_nextFocusFollowsLastSessionAcrossNonPreferredDay() {
    var profile = UserProfile.empty()
    profile.preferredSplit = .pushPullLegs
    let today = TrainingSchedule.weekday()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2

    var state = TrainingProgramState(splitDayIndex: 0) // push
    XCTAssertEqual(TrainingSchedule.currentSplitFocus(state: state, split: .pushPullLegs), .push)

    TrainingSchedule.advanceRotation(state: &state, split: .pushPullLegs) // -> pull
    TrainingSchedule.advanceRotation(state: &state, split: .pushPullLegs) // -> legs
    XCTAssertEqual(TrainingSchedule.currentSplitFocus(state: state, split: .pushPullLegs), .legs)

    // Non-preferred calendar day must still read the next focus (push).
    TrainingSchedule.advanceRotation(state: &state, split: .pushPullLegs)
    XCTAssertEqual(TrainingSchedule.currentSplitFocus(state: state, split: .pushPullLegs), .push)
    XCTAssertFalse(TrainingSchedule.isTrainingDay(profile: profile))
}
```

If this already passes without code changes, keep it as a lock. If generation ignores `programState.splitDayIndex`, fix the generator call site — do not invent a parallel focus picker.

- [ ] **Step 2: Run test**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/TrainingScheduleDomainTests/testRegression_nextFocusFollowsLastSessionAcrossNonPreferredDay \
  test
```

Expected: PASS (lock) or FAIL only if focus is calendar-coupled (then fix).

- [ ] **Step 3: Commit**

```bash
git add HotBod/Tests/UnitTests/TrainingScheduleDomainTests.swift
git commit -m "$(cat <<'EOF'
test: lock split rotation across non-preferred days

EOF
)"
```

---

### Task 4: Today soft Recovery UI

**Files:**
- Modify: `HotBod/Features/Today/TodayView.swift`
- Modify: `HotBod/Features/WorkoutSession/WorkoutHeroRefresh.swift`
- Modify: `HotBod/Features/WorkoutSession/TrainViews.swift`

**Interfaces:**
- Consumes: `environment.isRestDay`, `environment.todayWorkout`, `regenerateTodayWorkout`
- Produces:
  - Accessibility id `today.generate` (replaces `today.trainAnyway`)
  - Removes `WorkoutHeroRefreshKind.trainAnyway`

- [ ] **Step 1: Restructure `primaryTodayContent` for non-preferred days**

When `environment.isRestDay && !environment.isTodayWorkoutCompleted`:

```swift
editorialLayout(
    workout: environment.todayWorkout,
    hero: { restDayHero },
    secondary: {
        if let workout = environment.todayWorkout {
            // Keep existing strip via editorialLayout's workout path OR
            // explicitly render Start / Regenerate / Preview controls here
            restDayPlanActions(workout)
        }
    }
)
```

Concrete behavior:

| State | Hero primary | Secondary |
|-------|--------------|-----------|
| No plan | `"Generate"` → `regenerateTodayWorkout`, id `today.generate` | none |
| Plan ready | no Start on hero (Recovery stays the frame) | exercise strip (existing) + Start (`today.startWorkout`) + Regenerate (`today.regenerate`) + Preview (`today.preview`) |
| Completed | fall through to normal completed workout hero | — |

Implement `restDayHero` updates:

```swift
primaryAction: (
    title: environment.todayWorkout == nil ? "Generate" : "Start Workout",
    action: {
        if let workout = environment.todayWorkout {
            startWorkout(workout)
        } else {
            regenerateWorkout()
        }
    }
),
primaryAccessibilityIdentifier: environment.todayWorkout == nil
    ? "today.generate"
    : (activeSession != nil ? "today.resumeWorkout" : "today.startWorkout")
```

Spec wants Start in the secondary plan area when a plan exists. Prefer:

- No plan: hero primary `Generate` / `today.generate`
- Plan exists: hero has **no** primary Start; put Start / Regenerate / Preview in `secondary` using the same identifiers as the workout hero (`today.startWorkout`, `today.regenerate`, `today.preview`). If `ForgeHeroCard` requires a primary action, use a low-emphasis primary `"Start Workout"` only when secondary actions cannot host the CTA — but keep Recovery eyebrow/title.

Update footer copy from `"Next session:"` to reminder-oriented wording, e.g. `"Usual days resume \(nextDay)"`, and keep `"Up next: \(focus)"`.

- [ ] **Step 2: Remove Train Anyway plumbing**

In `WorkoutHeroRefresh.swift`, delete `case trainAnyway` and its feedback mapping.

In `TodayView.performWorkoutRefresh` and `TrainViews` switch, delete `.trainAnyway` arms.

Delete `trainAnyway()` helper; empty-plan Generate uses `.regenerate`.

Relax soreness guard that skipped refresh on bare rest days:

```swift
guard !environment.isTodayWorkoutCompleted else { return }
// remove: guard !environment.isRestDay || environment.todayWorkout != nil else { return }
```

- [ ] **Step 3: Build to verify compile**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Features/Today/TodayView.swift HotBod/Features/WorkoutSession/WorkoutHeroRefresh.swift HotBod/Features/WorkoutSession/TrainViews.swift
git commit -m "$(cat <<'EOF'
feat: soft Recovery Today with always-available plan actions

Non-preferred days keep Recovery framing while Start/Regenerate work
without a Train anyway bypass.
EOF
)"
```

---

### Task 5: Coach + settings/onboarding copy

**Files:**
- Modify: `HotBod/Services/AI/CoachModificationSafety.swift`
- Modify: `HotBod/Tests/UnitTests/CoachDomainTests.swift`
- Modify: `HotBod/Features/Settings/SettingsView+Training.swift`
- Modify: `HotBod/Features/Onboarding/OnboardingViews.swift`

**Interfaces:**
- Produces:
  ```swift
  // CoachOfflineModify
  static func restDayMessage(profile: UserProfile) -> String?
  ```
  Soft copy example when next preferred day exists:
  `"Optional recovery day. Usual training days resume \(next)."`
  When no next label:
  `"Optional recovery day — you can still train if you want."`

- [ ] **Step 1: Write failing coach test**

```swift
func testRestDayMessageIncludesNextTrainingDay() {
    var profile = UserProfile.empty()
    let today = TrainingSchedule.weekday()
    profile.preferredTrainingDays = Weekday.allCases.filter { $0 != today }
    let message = CoachOfflineModify.restDayMessage(profile: profile)
    XCTAssertNotNil(message)
    XCTAssertFalse(message?.lowercased().contains("cannot") == true)
    XCTAssertTrue(
        message?.lowercased().contains("recovery") == true
        || message?.lowercased().contains("optional") == true
    )
    if let next = TrainingSchedule.nextTrainingDayLabel(profile: profile) {
        XCTAssertTrue(message?.contains(next) == true)
    }
}
```

- [ ] **Step 2: Run to verify fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoachOfflineModifyTests/testRestDayMessageIncludesNextTrainingDay \
  test
```

Expected: FAIL on old “Today is a rest day…” hard wording assertions / new soft assertions.

- [ ] **Step 3: Implement soft coach copy + settings/onboarding helper text**

Update `restDayMessage` to the soft strings above (still return `nil` on preferred days).

Settings schedule section (`SettingsView+Training.swift`):

- Subtitle: `"Preferred days for reminders"` (or `"Usual training days"`)
- Caption under chips: `"Used for reminders and Recovery framing. You can train any day."`

Onboarding schedule (`OnboardingViews.swift`):

- Near Preferred days: caption `"Pick your usual days. You can still train on others."`

Do not change min-two-days validation or `trainingDaysPerWeek` derivation.

- [ ] **Step 4: Run coach tests**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoachOfflineModifyTests \
  test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/AI/CoachModificationSafety.swift HotBod/Tests/UnitTests/CoachDomainTests.swift HotBod/Features/Settings/SettingsView+Training.swift HotBod/Features/Onboarding/OnboardingViews.swift
git commit -m "$(cat <<'EOF'
copy: frame preferred days as reminders, not locks

Soften coach rest-day messaging and settings/onboarding schedule copy.
EOF
)"
```

---

### Task 6: UI tests + xctestplan

**Files:**
- Modify: `HotBod/Tests/UITests/TodayWorkoutUITests.swift`
- Modify: `HotBod/Tests/UITests/Pages/TodayPage.swift`
- Modify: `HotBod/Tests/UITests/BaseUITestCase.swift`
- Modify: `HotBod.xctestplan`

**Interfaces:**
- Produces: page object `generateButton` → `app.buttons["today.generate"]`
- UI regression name: `testRegression_nonPreferredDayShowsRecoveryWithStart`

- [ ] **Step 1: Update page object and wait helpers**

`TodayPage.swift`:

```swift
var generateButton: XCUIElement { app.buttons["today.generate"] }
// Remove or keep trainAnywayButton only if temporarily aliased — prefer delete.
```

In `BaseUITestCase`, replace waits on `today.trainAnyway` with `today.startWorkout` / `today.generate` / existing hero waits so ForceRestDay launches still become ready.

- [ ] **Step 2: Rewrite UI regression**

Because bootstrap now auto-generates on ForceRestDay:

```swift
func testRegression_nonPreferredDayShowsRecoveryWithStart() {
    app.terminate()
    app.launchArguments.append("-ForceRestDay")
    app.launch()
    XCTAssertTrue(waitForTabBar())

    XCTAssertTrue(
        app.staticTexts["Rest Day"].waitForExistence(timeout: 10)
        || app.staticTexts["Recovery"].waitForExistence(timeout: 2)
    )
    XCTAssertTrue(
        app.buttons["today.startWorkout"].waitForExistence(timeout: 20)
        || app.buttons["today.generate"].waitForExistence(timeout: 5)
    )
    if app.buttons["today.generate"].exists {
        app.buttons["today.generate"].tap()
        XCTAssertTrue(app.buttons["today.startWorkout"].waitForExistence(timeout: 20))
    }
}
```

Update `HotBod.xctestplan` selected test from `testRegression_trainAnywayReplacesRestHeroWithPlan` to `testRegression_nonPreferredDayShowsRecoveryWithStart`.

- [ ] **Step 3: Run UI test**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodUITests/TodayWorkoutUITests/testRegression_nonPreferredDayShowsRecoveryWithStart \
  test
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Tests/UITests/TodayWorkoutUITests.swift HotBod/Tests/UITests/Pages/TodayPage.swift HotBod/Tests/UITests/BaseUITestCase.swift HotBod.xctestplan
git commit -m "$(cat <<'EOF'
test: cover Recovery + Start on non-preferred days

EOF
)"
```

---

### Task 7: Final verification

**Files:**
- None intended (fix-only if PR suite surfaces leftovers)

- [ ] **Step 1: Grep for dead API**

```bash
rg -n "generateTodayWorkoutOnRestDay|allowsUnscheduledDay|today\\.trainAnyway|Train anyway|trainAnyway" HotBod docs
```

Expected: no production references; docs may mention historical Train Anyway in the July spec (leave historical specs; this plan/spec supersede behavior).

- [ ] **Step 2: Run PR test configuration**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -testPlan HotBod \
  -only-testing:HotBodTests \
  test
```

If the machine supports the full plan:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -testPlan HotBod \
  test
```

Use `-showdestinations` and substitute an installed iPhone simulator if `iPhone 16 Pro` is missing.

Expected: BUILD SUCCEEDED; PR tests green (or only pre-existing failures unrelated to this change).

- [ ] **Step 3: Manual smoke (simulator)**

1. Set preferred days excluding today in Settings → open Today → Recovery framing + plan/Start without changing days.
2. Tap Regenerate → new plan, no Settings trip.
3. Complete a Pull session → advance day / ForceRestDay → next focus is Legs (or next in rotation).

- [ ] **Step 4: Commit any verification fixes**

Only if Step 1–3 required code fixes; otherwise no empty commit.

---

## Spec Coverage Checklist

| Spec requirement | Task |
|------------------|------|
| Preferred days never block generation APIs | Task 1 |
| Remove `allowsUnscheduledDay` / `generateTodayWorkoutOnRestDay` / Train anyway bypass | Tasks 1, 4, 6 |
| Bootstrap / revalidate auto-generate every day; no wipe on non-preferred | Task 2 |
| Onboarding preserves schedule; ensures plan; no auto-start on non-preferred | Task 2 |
| Focus follows split rotation / last session | Task 3 |
| Soft Recovery UI + secondary plan actions | Task 4 |
| Soft coach + settings/onboarding copy | Task 5 |
| UI regression + accessibility ids | Task 6 |
| Quota rules unchanged for user regenerate | Task 1 (preserve `requiresProAccess`) |
| Notification scheduler out of scope | — (explicit non-goal) |

## Self-Review Notes

- No TBD/placeholder steps remain.
- Public API names are consistent across tasks (`regenerateTodayWorkout`, `ensureTodayWorkoutOnLaunch`, `today.generate`).
- Historical July design doc is intentionally left; behavior supersession is documented in the Aug 10 spec header.
