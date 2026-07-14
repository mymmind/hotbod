# P0 Functionality Repairs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix audit findings #1–#5 so schedules remain consistent, unscheduled-day training is possible, cloud coach responses decode, and soreness never compounds persisted recovery penalties.

**Architecture:** Keep `preferredTrainingDays` as the editable schedule source while retaining the derived compatibility field `trainingDaysPerWeek`. Reuse the existing workout regeneration pipeline behind an explicit unscheduled-day override. Keep soreness transient by applying it once to generation input, and make edge validation decoding backward-compatible.

**Tech Stack:** Swift 6, SwiftUI, Foundation Codable, OSLog, XCTest/XCUITest, Xcode test plans.

## Global Constraints

- iOS 17+.
- Preserve local-first repositories and current validation, subscription, persistence, and safety gates.
- Do not add a backend dependency or Supabase schema migration.
- Do not alter unrelated uncommitted changes.
- Regression tests use the `testRegression_` prefix.
- UI test launches with `-UITesting -ResetState -MockAI -MockFoodSearch -SkipOnboarding`.
- Final verification uses the `PR` configuration in `HotBod.xctestplan`.

---

### Task 1: Make Weekday Selection the Schedule Source of Truth

**Files:**
- Modify: `HotBod/Features/Settings/SettingsDraftEditing.swift`
- Modify: `HotBod/Features/Settings/SettingsView+Training.swift`
- Modify: `HotBod/Features/Settings/SettingsView+Profile.swift`
- Modify: `HotBod/Features/Onboarding/OnboardingProfileEditing.swift`
- Modify: `HotBod/Features/Onboarding/OnboardingViews.swift`
- Test: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`
- Test: `HotBod/Tests/UnitTests/OnboardingProfileEditingTests.swift`

**Interfaces:**
- Produces: `SettingsDraftEditing.reconcileSchedule(_:)`
- Produces: `SettingsDraftEditing.hasValidSchedule(_:) -> Bool`
- Produces: `SettingsDraftEditing.toggleTrainingDay(_:in:) -> Bool`
- Produces: `OnboardingProfileEditing.hasValidSchedule(_:) -> Bool`
- Produces: `OnboardingProfileEditing.toggleTrainingDay(_:in:) -> Bool`
- Removes: `OnboardingProfileEditing.trimTrainingDays(to:in:)`

- [ ] **Step 1: Write failing Settings schedule regression tests**

Add a `SettingsDraftEditingScheduleTests` test class:

```swift
@MainActor
final class SettingsDraftEditingScheduleTests: XCTestCase {
    func testRegression_settingsScheduleAlwaysDerivesFrequencyFromSelectedDays() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [.monday, .wednesday, .friday]
        profile.trainingDaysPerWeek = 6

        SettingsDraftEditing.reconcileSchedule(&profile)

        XCTAssertEqual(profile.preferredTrainingDays, [.monday, .wednesday, .friday])
        XCTAssertEqual(profile.trainingDaysPerWeek, 3)
    }

    func testRegression_settingsScheduleCannotDropBelowTwoDays() {
        var profile = UserProfile.empty()
        profile.preferredTrainingDays = [.monday, .wednesday]
        profile.trainingDaysPerWeek = 2

        let changed = SettingsDraftEditing.toggleTrainingDay(.monday, in: &profile)

        XCTAssertFalse(changed)
        XCTAssertEqual(profile.preferredTrainingDays, [.monday, .wednesday])
        XCTAssertEqual(profile.trainingDaysPerWeek, 2)
    }
}
```

- [ ] **Step 2: Run the Settings tests and verify failure**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HotBodTests/SettingsDraftEditingScheduleTests test
```

Expected: FAIL because the reconciliation API is absent and `toggleTrainingDay` does not return or derive the count.

- [ ] **Step 3: Implement Settings schedule reconciliation**

Add to `SettingsDraftEditing`:

```swift
static func reconcileSchedule(_ draft: inout UserProfile) {
    let selected = Set(draft.preferredTrainingDays)
    draft.preferredTrainingDays = Weekday.allCases.filter(selected.contains)
    draft.trainingDaysPerWeek = draft.preferredTrainingDays.count
}

static func hasValidSchedule(_ draft: UserProfile) -> Bool {
    Set(draft.preferredTrainingDays).count >= 2
}

@discardableResult
static func toggleTrainingDay(_ day: Weekday, in draft: inout UserProfile) -> Bool {
    if draft.preferredTrainingDays.contains(day) {
        guard Set(draft.preferredTrainingDays).count > 2 else { return false }
        draft.preferredTrainingDays.removeAll { $0 == day }
    } else {
        draft.preferredTrainingDays.append(day)
    }
    reconcileSchedule(&draft)
    return true
}
```

Remove the old void-returning `toggleTrainingDay`.

In `SettingsView+Training.swift`, remove the independent Stepper and replace it with derived copy:

```swift
Text("\(draft.preferredTrainingDays.count) days per week")
    .font(ForgeTypography.body)
```

In `loadDraft()`, reconcile immediately after copying the profile:

```swift
draft = profile
SettingsDraftEditing.reconcileSchedule(&draft)
```

In `finish()`, reconcile and validate before comparing/saving:

```swift
SettingsDraftEditing.reconcileSchedule(&draft)
guard SettingsDraftEditing.hasValidSchedule(draft) else {
    saveError = "Select at least two training days."
    return
}
```

- [ ] **Step 4: Write failing onboarding schedule regression tests**

Replace the obsolete trim-stepper test with:

```swift
func testRegression_onboardingScheduleDerivesFrequencyFromSelectedDays() {
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = [.friday, .monday, .wednesday, .monday]
    profile.trainingDaysPerWeek = 7

    OnboardingProfileEditing.reconcileSchedule(&profile)

    XCTAssertEqual(profile.preferredTrainingDays, [.monday, .wednesday, .friday])
    XCTAssertEqual(profile.trainingDaysPerWeek, 3)
}

func testRegression_onboardingScheduleCannotDropBelowTwoDays() {
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = [.monday, .wednesday]
    profile.trainingDaysPerWeek = 2

    let changed = OnboardingProfileEditing.toggleTrainingDay(.monday, in: &profile)

    XCTAssertFalse(changed)
    XCTAssertEqual(profile.preferredTrainingDays, [.monday, .wednesday])
}
```

- [ ] **Step 5: Implement onboarding chip-only scheduling**

Change onboarding schedule editing to mirror Settings:

```swift
static func reconcileSchedule(_ profile: inout UserProfile) {
    let selected = Set(profile.preferredTrainingDays)
    profile.preferredTrainingDays = Weekday.allCases.filter(selected.contains)
    profile.trainingDaysPerWeek = profile.preferredTrainingDays.count
}

static func hasValidSchedule(_ profile: UserProfile) -> Bool {
    Set(profile.preferredTrainingDays).count >= 2
}

@discardableResult
static func toggleTrainingDay(_ day: Weekday, in profile: inout UserProfile) -> Bool {
    if profile.preferredTrainingDays.contains(day) {
        guard Set(profile.preferredTrainingDays).count > 2 else { return false }
        profile.preferredTrainingDays.removeAll { $0 == day }
    } else {
        profile.preferredTrainingDays.append(day)
    }
    reconcileSchedule(&profile)
    return true
}
```

Delete `trimTrainingDays(to:in:)`. Remove the onboarding Stepper and its `onChange`. Replace it with:

```swift
Text("\(viewModel.profile.preferredTrainingDays.count) days per week")
    .font(ForgeTypography.body)
```

Keep `applyAutomaticSplitIfNeeded()` after successful weekday toggles so split recommendations use the newly derived count.

- [ ] **Step 6: Run schedule tests**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/SettingsDraftEditingScheduleTests \
  -only-testing:HotBodTests/OnboardingProfileEditingTests test
```

Expected: PASS.

- [ ] **Step 7: Commit the schedule repair**

```bash
git add HotBod/Features/Settings/SettingsDraftEditing.swift HotBod/Features/Settings/SettingsView+Training.swift HotBod/Features/Settings/SettingsView+Profile.swift HotBod/Features/Onboarding/OnboardingProfileEditing.swift HotBod/Features/Onboarding/OnboardingViews.swift HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift HotBod/Tests/UnitTests/OnboardingProfileEditingTests.swift
git commit -m "fix: keep selected training days authoritative"
```

---

### Task 2: Preserve the Onboarding Schedule on Off-Days

**Files:**
- Modify: `HotBod/App/AppEnvironment+Profile.swift`
- Modify: `HotBod/Features/Onboarding/OnboardingViews.swift`
- Test: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`

**Interfaces:**
- Consumes: `OnboardingProfileEditing.hasValidSchedule(_:)`
- Removes: `AppEnvironment.ensureTodayIncludedInTrainingDays(_:)`

- [ ] **Step 1: Write the failing onboarding completion regression test**

Add an environment test that chooses two weekdays excluding today:

```swift
func testRegression_onboardingCompletionDoesNotAddToday() async {
    let env = AppEnvironment.makeForTests()
    let today = TrainingSchedule.weekday()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2

    _ = await env.finishOnboardingAndStartTodayWorkout(profile: profile)

    XCTAssertEqual(env.userProfile?.preferredTrainingDays, profile.preferredTrainingDays)
    XCTAssertFalse(env.userProfile?.preferredTrainingDays.contains(today) ?? true)
    XCTAssertTrue(env.hasCompletedOnboarding)
}
```

- [ ] **Step 2: Run the test and verify failure**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HotBodTests/AppEnvironmentOnboardingAndCoachTests/testRegression_onboardingCompletionDoesNotAddToday test
```

Expected: FAIL because completion appends today.

- [ ] **Step 3: Remove silent schedule mutation and handle valid off-day completion**

In `finishOnboardingAndStartTodayWorkout`:

```swift
OnboardingProfileEditing.normalizeForCompletion(&updated, lockSplit: lockSplit)
guard OnboardingProfileEditing.hasValidSchedule(updated) else {
    syncMessage = "Select at least two training days."
    return nil
}
```

Delete the call to `ensureTodayIncludedInTrainingDays`, delete that helper, and after onboarding persistence add:

```swift
guard TrainingSchedule.isTrainingDay(profile: updated) else {
    syncMessage = nil
    return nil
}
```

In `completeOnboarding()`, route a successfully completed off-day profile to main:

```swift
if environment.hasCompletedOnboarding,
   let profile = environment.userProfile,
   !TrainingSchedule.isTrainingDay(profile: profile) {
    router.showMain()
    return
}
```

Keep scheduled-day generation failures on the existing error path.

- [ ] **Step 4: Run onboarding tests**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentOnboardingAndCoachTests/testRegression_onboardingCompletionDoesNotAddToday \
  -only-testing:HotBodTests/OnboardingProfileEditingTests test
```

Expected: PASS.

- [ ] **Step 5: Commit onboarding preservation**

```bash
git add HotBod/App/AppEnvironment+Profile.swift HotBod/Features/Onboarding/OnboardingViews.swift HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
git commit -m "fix: preserve onboarding weekday choices"
```

---

### Task 3: Add an Explicit Train-Anyway Path

**Files:**
- Modify: `HotBod/App/AppEnvironment+Workout.swift`
- Modify: `HotBod/Features/Today/TodayView.swift`
- Modify: `HotBod/App/UITestConfiguration.swift`
- Modify: `HotBod/Tests/UITests/Pages/TodayPage.swift`
- Modify: `HotBod/Tests/UITests/TodayWorkoutUITests.swift`
- Modify: `HotBod.xctestplan`
- Test: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`

**Interfaces:**
- Produces: `AppEnvironment.generateTodayWorkoutOnRestDay(profile:options:) async -> Bool`
- Produces: accessibility identifier `today.trainAnyway`
- Produces: UI launch argument `-ForceRestDay`

- [ ] **Step 1: Write failing environment override tests**

Add:

```swift
func testRegression_trainAnywayGeneratesOnUnscheduledDay() async {
    let workout = FixtureBuilders.makeGeneratedWorkout()
    let generator = FixedMockWorkoutGenerationService(workout: workout)
    let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
    let today = TrainingSchedule.weekday()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2
    env.userProfile = profile
    env.recoveryStates = RecoveryCalculator.defaultStates()

    let generated = await env.generateTodayWorkoutOnRestDay(profile: profile)

    XCTAssertTrue(generated)
    XCTAssertEqual(env.todayWorkout?.id, workout.id)
}

func testRegression_normalRegenerationRemainsBlockedOnUnscheduledDay() async {
    let generator = FixedMockWorkoutGenerationService(workout: FixtureBuilders.makeGeneratedWorkout())
    let env = AppEnvironment.makeForTests(workoutGenerationService: generator)
    let today = TrainingSchedule.weekday()
    var profile = UserProfile.empty()
    profile.preferredTrainingDays = Array(Weekday.allCases.filter { $0 != today }.prefix(2))
    profile.trainingDaysPerWeek = 2

    let generated = await env.regenerateTodayWorkout(profile: profile)

    XCTAssertFalse(generated)
    XCTAssertNil(env.todayWorkout)
}
```

- [ ] **Step 2: Run override tests and verify failure**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HotBodTests/AppEnvironmentWorkoutGenerationTests test
```

Expected: FAIL because `generateTodayWorkoutOnRestDay` does not exist.

- [ ] **Step 3: Extract the shared regeneration pipeline**

Keep the existing API and add the explicit override:

```swift
@discardableResult
func regenerateTodayWorkout(
    profile: UserProfile,
    options: WorkoutGenerationOptions = WorkoutGenerationOptions()
) async -> Bool {
    await regenerateTodayWorkout(profile: profile, options: options, allowsUnscheduledDay: false)
}

@discardableResult
func generateTodayWorkoutOnRestDay(
    profile: UserProfile,
    options: WorkoutGenerationOptions = WorkoutGenerationOptions()
) async -> Bool {
    await regenerateTodayWorkout(profile: profile, options: options, allowsUnscheduledDay: true)
}

private func regenerateTodayWorkout(
    profile: UserProfile,
    options: WorkoutGenerationOptions,
    allowsUnscheduledDay: Bool
) async -> Bool {
    guard allowsUnscheduledDay || TrainingSchedule.isTrainingDay(profile: profile) else { return false }
    guard !isTodayWorkoutCompleted else { return false }
    guard !isWorkoutGenerationInFlight else { return false }
    guard canAccess(.unlimitedGeneration) else {
        presentPaywall(for: .unlimitedGeneration)
        return false
    }

    await cancelActiveWorkoutIfNeeded()
    await applyRecoveryDecay()

    let splitFocus = TrainingSchedule.currentSplitFocus(
        state: programState,
        split: profile.preferredSplit
    )
    var effectiveOptions = options
    if effectiveOptions.excludeExerciseIds.isEmpty, let current = todayWorkout {
        effectiveOptions.excludeExerciseIds = current.exercises.map(\.exerciseId)
        effectiveOptions.preferVariation = true
    }

    if await persistRegeneratedWorkout(
        profile: profile,
        splitDayFocus: splitFocus,
        options: effectiveOptions
    ) {
        if !isPro { await recordRegenerationUsage() }
        return true
    }

    guard !effectiveOptions.excludeExerciseIds.isEmpty else { return false }
    var fallbackOptions = options
    fallbackOptions.excludeExerciseIds = []
    fallbackOptions.preferVariation = true
    if await persistRegeneratedWorkout(
        profile: profile,
        splitDayFocus: splitFocus,
        options: fallbackOptions
    ) {
        if !isPro { await recordRegenerationUsage() }
        return true
    }
    return false
}
```

The private helper replaces the original implementation body so the pipeline remains single-source.

- [ ] **Step 4: Add the Rest Day action and render its generated plan**

In `primaryTodayContent`, prioritize a generated workout before the calendar rest state:

```swift
if let workout = environment.todayWorkout {
    editorialLayout(
        workout: workout,
        hero: {
            workoutHero(workout, completed: environment.isTodayWorkoutCompleted, session: completedSession)
        },
        secondary: {
            if !environment.isTodayWorkoutCompleted {
                secondarySections(workout: workout)
            }
        }
    )
} else if environment.isRestDay {
    editorialLayout(hero: { restDayHero })
} else {
    // Existing empty state.
}
```

Add the action to `restDayHero`:

```swift
primaryAction: (
    title: "Train anyway",
    action: {
        guard let profile = environment.userProfile else { return }
        Task { await environment.generateTodayWorkoutOnRestDay(profile: profile) }
    }
),
primaryAccessibilityIdentifier: "today.trainAnyway",
```

- [ ] **Step 5: Add deterministic rest-day UI configuration and test**

In `UITestConfiguration`:

```swift
static var shouldForceRestDay: Bool {
    ProcessInfo.processInfo.arguments.contains("-ForceRestDay")
}
```

In `defaultOnboardedProfile()`, when forced, select two weekdays excluding today and derive the count.

In `TodayPage`:

```swift
var trainAnywayButton: XCUIElement { app.buttons["today.trainAnyway"] }
```

Add the UI regression:

```swift
func testRegression_trainAnywayReplacesRestHeroWithPlan() {
    app.terminate()
    app.launchArguments.append("-ForceRestDay")
    app.launch()

    XCTAssertTrue(waitForTabBar())
    XCTAssertTrue(today.trainAnywayButton.waitForExistence(timeout: 8))
    today.trainAnywayButton.tap()
    XCTAssertTrue(today.startWorkoutButton.waitForExistence(timeout: 15))
}
```

Add this selector to the PR configuration's `selectedTests` in `HotBod.xctestplan`.

- [ ] **Step 6: Run override unit and UI tests**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentWorkoutGenerationTests \
  -only-testing:HotBodUITests/TodayWorkoutUITests/testRegression_trainAnywayReplacesRestHeroWithPlan test
```

Expected: PASS.

- [ ] **Step 7: Commit train-anyway flow**

```bash
git add HotBod/App/AppEnvironment+Workout.swift HotBod/Features/Today/TodayView.swift HotBod/App/UITestConfiguration.swift HotBod/Tests/UITests/Pages/TodayPage.swift HotBod/Tests/UITests/TodayWorkoutUITests.swift HotBod.xctestplan HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
git commit -m "feat: allow explicit training on rest days"
```

---

### Task 4: Restore Cloud Coach Validation Decoding

**Files:**
- Modify: `HotBod/Domain/Models/DomainModels.swift`
- Modify: `HotBod/Services/AI/RemoteAIWorkoutService.swift`
- Test: `HotBod/Tests/UnitTests/CoachDomainTests.swift`

**Interfaces:**
- Produces: backward-compatible `WorkoutValidationResult.init(from:)`
- Preserves: `WorkoutValidationResult` encoding with `suggestions`

- [ ] **Step 1: Write the missing-suggestions regression test**

Add:

```swift
func testRegression_validationDecodesWithoutSuggestions() throws {
    let json = """
    {
      "intent": "modifyWorkout",
      "content": "Adjusted safely.",
      "proposedWorkout": null,
      "safetyNotes": [],
      "validation": {
        "isValid": true,
        "errors": [],
        "warnings": []
      }
    }
    """

    let response = try JSONDecoder().decode(RemoteCoachResponse.self, from: Data(json.utf8))

    XCTAssertEqual(response.validation?.suggestions, [])
    XCTAssertEqual(response.validation?.isValid, true)
}
```

- [ ] **Step 2: Run the coach test and verify failure**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HotBodTests/CoachDomainTests/testRegression_validationDecodesWithoutSuggestions test
```

Expected: FAIL with `keyNotFound` for `suggestions`.

- [ ] **Step 3: Add tolerant decoding**

Add explicit coding keys and decoding:

```swift
private enum CodingKeys: String, CodingKey {
    case isValid, errors, warnings, suggestions
}

init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isValid = try container.decode(Bool.self, forKey: .isValid)
    errors = try container.decode([String].self, forKey: .errors)
    warnings = try container.decode([String].self, forKey: .warnings)
    suggestions = try container.decodeIfPresent([String].self, forKey: .suggestions) ?? []
}
```

Keep `suggestions` non-optional and keep the existing memberwise initializer. Confirm encoding still emits `suggestions` with a round-trip assertion.

- [ ] **Step 4: Categorize remote failures without leaking request data**

Import `OSLog`, add a private logger, and split the catch path:

```swift
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "HotBod",
    category: "RemoteAIWorkoutService"
)
```

Use separate `DecodingError`, `URLError`, and generic catches. Log only the category and safe error type/description; never log the coach message, tokens, email, or response body. Route all catches through one helper:

```swift
private func offlineFallback(for message: String, context: CoachContext) async throws -> CoachAIResult {
    var offline = try await fallback.respond(to: message, context: context)
    offline.message.content += "\n\n(Cloud coach unavailable — using offline responses.)"
    return offline
}
```

- [ ] **Step 5: Run coach tests**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HotBodTests/CoachDomainTests test
```

Expected: PASS.

- [ ] **Step 6: Commit cloud decoding repair**

```bash
git add HotBod/Domain/Models/DomainModels.swift HotBod/Services/AI/RemoteAIWorkoutService.swift HotBod/Tests/UnitTests/CoachDomainTests.swift
git commit -m "fix: decode cloud coach validation responses"
```

---

### Task 5: Make Soreness a Single Transient Generation Adjustment

**Files:**
- Modify: `HotBod/App/AppEnvironment+Recovery.swift`
- Modify: `HotBod/App/AppEnvironment+Workout.swift`
- Modify: `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift`
- Test: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`
- Test: `HotBod/Tests/UnitTests/WorkoutGenerationDomainTests.swift`

**Interfaces:**
- Consumes: `RecoveryCalculator.applySoreness(states:level:recentlyTrainedMuscles:)`
- Changes: `applyRecoveryDecay(now:)` persists time decay only
- Changes: `makeWorkoutGenerationInput(...)` supplies once-adjusted recovery

- [ ] **Step 1: Write recovery persistence regression tests**

Add:

```swift
func testRegression_repeatedRecoveryDecayDoesNotCompoundSoreness() async {
    let env = AppEnvironment.makeForTests()
    var profile = UserProfile.empty()
    profile.experienceLevel = .intermediate
    env.userProfile = profile
    env.sorenessLevel = .severe
    env.recoveryStates = RecoveryCalculator.defaultStates()
    let now = Date()

    await env.applyRecoveryDecay(now: now)
    let first = env.recoveryStates
    await env.applyRecoveryDecay(now: now)

    XCTAssertEqual(env.recoveryStates, first)
    XCTAssertEqual(env.recoveryStates.first?.recoveryPercentage, 100)
}

func testRegression_changingSorenessDoesNotMutatePersistedRecovery() async {
    let env = AppEnvironment.makeForTests()
    env.userProfile = UserProfile.empty()
    env.recoveryStates = RecoveryCalculator.defaultStates()

    await env.setSoreness(.moderate)
    await env.setSoreness(.severe)

    XCTAssertEqual(env.recoveryStates.map(\.recoveryPercentage), Array(repeating: 100, count: MuscleGroup.allCases.count))
}
```

- [ ] **Step 2: Run recovery tests and verify failure**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HotBodTests/AppEnvironmentWorkoutGenerationTests test
```

Expected: FAIL because soreness is currently persisted on every decay.

- [ ] **Step 3: Remove soreness mutation from persisted recovery**

Delete the session-summary fetch and `RecoveryCalculator.applySoreness` call from `applyRecoveryDecay`. Keep time decay, recovery save, decay timestamp save, and cloud program-state push unchanged.

- [ ] **Step 4: Write the single scoped-adjustment input test**

Add:

```swift
func testRegression_generationAppliesScopedSorenessOnce() async {
    let env = AppEnvironment.makeForTests()
    env.recoveryStates = RecoveryCalculator.defaultStates()
    let recent = [
        WorkoutSessionSummary(
            id: UUID(),
            title: "Leg Day",
            completedAt: Date(),
            totalVolumeKg: 1_000,
            totalSets: 12,
            durationMinutes: 45,
            muscleGroups: [.quads]
        )
    ]

    let input = await env.makeWorkoutGenerationInput(
        profile: UserProfile.empty(),
        splitDayFocus: nil,
        recentWorkouts: recent,
        soreness: .severe
    )

    XCTAssertEqual(input.muscleRecovery[.quads], 70)
    XCTAssertEqual(input.muscleRecovery[.chest], 85)
    XCTAssertEqual(env.recoveryStates.first { $0.muscleGroup == .quads }?.recoveryPercentage, 100)
}
```

- [ ] **Step 5: Apply soreness once while building generation input**

Replace the recovery-map construction with:

```swift
let effectiveSoreness = soreness ?? sorenessLevel
let recentlyTrained = Set(summaries.prefix(2).flatMap(\.muscleGroups))
let adjustedRecoveryStates = RecoveryCalculator.applySoreness(
    states: recoveryStates,
    level: effectiveSoreness,
    recentlyTrainedMuscles: recentlyTrained
)
let recovery = RecoveryCalculator.recoveryMap(from: adjustedRecoveryStates)
```

Pass `effectiveSoreness` into `ReadinessInput`.

- [ ] **Step 6: Remove the legacy flat generator penalty and test it**

Delete the severe/moderate `mapValues` subtraction at the start of `selectTargetMuscles`. Add a focused regression that passes a pre-adjusted recovery map with moderate readiness and verifies target ordering reflects the supplied values without another 15-point global subtraction. Keep the sleep adjustment, because it is a separate readiness signal.

- [ ] **Step 7: Run recovery and generation tests**

Run:

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentWorkoutGenerationTests \
  -only-testing:HotBodTests/WorkoutGenerationDomainTests test
```

Expected: PASS.

- [ ] **Step 8: Commit soreness repair**

```bash
git add HotBod/App/AppEnvironment+Recovery.swift HotBod/App/AppEnvironment+Workout.swift HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift HotBod/Tests/UnitTests/WorkoutGenerationDomainTests.swift
git commit -m "fix: prevent compounding soreness penalties"
```

---

### Task 6: Full Verification

**Files:**
- Verify all modified files
- Do not modify unrelated files unless a test exposes a direct P0 regression

**Interfaces:**
- Consumes all prior task outputs
- Produces a buildable, PR-test-clean P0 repair set

- [ ] **Step 1: Check edited-file diagnostics**

Use IDE diagnostics on every modified Swift file. Fix only errors introduced by these tasks.

- [ ] **Step 2: Run focused P0 regression tests**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/SettingsDraftEditingScheduleTests \
  -only-testing:HotBodTests/OnboardingProfileEditingTests \
  -only-testing:HotBodTests/AppEnvironmentWorkoutGenerationTests \
  -only-testing:HotBodTests/CoachDomainTests \
  -only-testing:HotBodTests/WorkoutGenerationDomainTests \
  -only-testing:HotBodUITests/TodayWorkoutUITests/testRegression_trainAnywayReplacesRestHeroWithPlan test
```

Expected: PASS.

- [ ] **Step 3: Run the PR test plan**

```bash
RESULT_BUNDLE="/tmp/HotBod-P0-$(date +%s).xcresult"
xcodebuild -scheme HotBod -testPlan HotBod -only-test-configuration PR \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT_BUNDLE" test
```

Expected: PASS.

- [ ] **Step 4: Build the app**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Review the final diff**

```bash
git status --short
git diff -- HotBod docs/superpowers HotBod.xctestplan
```

Confirm no `.env`, result bundles, build output, or unrelated changes were staged.

- [ ] **Step 6: Commit verification-only adjustments if any**

If verification required code changes, stage only those files and create a new commit. Do not amend earlier commits.
