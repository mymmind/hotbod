# P0 Functionality Repairs Design

**Date:** 2026-07-13
**Source:** `docs/FUNCTIONALITY_AUDIT_2026-07.md`
**Scope:** Audit findings #1–#5

## Goal

Restore predictable workout scheduling, let users train on unscheduled days without changing their preferences, restore cloud-coach response decoding, and prevent soreness from compounding recovery penalties.

## Constraints

- iOS 17+, SwiftUI, SwiftData, MVVM + Services + Repositories.
- Preserve the local-first architecture and existing subscription, validation, persistence, and safety gates.
- Do not add a backend dependency or schema migration.
- Preserve unrelated uncommitted work.
- Every defect receives a `testRegression_<issue>` regression test.
- The new user-facing flow receives UI coverage and stable accessibility identifiers.

## 1. Schedule Source of Truth

`UserProfile.preferredTrainingDays` is the editable source of truth. `trainingDaysPerWeek` remains in the model for compatibility with progress, split suggestion, persistence, and cloud DTO code, but editing and normalization always derive it from the selected weekday count.

Settings and onboarding remove the independent frequency stepper. Users select weekdays directly. The UI prevents removing a selected day when doing so would leave fewer than two training days. Each successful toggle immediately sets:

```swift
profile.trainingDaysPerWeek = profile.preferredTrainingDays.count
```

Completion normalization deduplicates selected days, preserves their weekday order, derives the count, and then derives an unlocked suggested split from that count. It never invents weekdays to satisfy a separately selected number. If legacy or malformed data contains fewer than two selected days, Settings and onboarding block saving/completion and ask the user to select at least two days.

Existing persisted profiles may already contain mismatched values. Settings reconciles its draft when it is created, and onboarding reconciles during completion normalization: the selected weekday list wins and repairs `trainingDaysPerWeek`. This is intentionally a compatibility repair, not a model migration.

## 2. Train Anyway

The Rest Day hero gains a primary `Train anyway` action with accessibility identifier `today.trainAnyway`.

The action calls a dedicated `AppEnvironment` operation for unscheduled-day generation. The operation shares the existing regeneration pipeline but bypasses only `TrainingSchedule.isTrainingDay(profile:)`. It continues to enforce:

- no already-completed workout for today;
- no concurrent generation;
- subscription/regeneration entitlement;
- active-workout cancellation behavior;
- workout validation;
- persistence;
- fallback generation behavior; and
- regeneration usage accounting.

On success, Today re-renders with the generated plan so the user can review it. It does not start a workout session automatically. On failure, the rest-day hero remains visible and the existing generation failure/paywall state remains authoritative.

Normal regeneration, restart, and split-switch operations retain their scheduled-day guards. The override is explicit and limited to the Rest Day action.

## 3. Onboarding Schedule Preservation

Onboarding completion removes `ensureTodayIncludedInTrainingDays`. The exact selected weekday set is saved after normalization; finishing onboarding on an unselected weekday does not mutate the schedule.

If onboarding is completed on an unscheduled day, the user lands on Today's Rest Day state and can choose `Train anyway`. Schedule preferences remain unchanged.

The onboarding frequency display, where needed for split recommendations or summary copy, is derived from the selected weekday count rather than independently edited.

## 4. Cloud Coach Response Decoding and Diagnostics

`WorkoutValidationResult` receives custom `Decodable` behavior that treats a missing `suggestions` key as an empty array. Encoding continues to include all four fields. A fixture matching the edge-function response below must decode successfully:

```json
{
  "isValid": true,
  "errors": [],
  "warnings": []
}
```

The edge function does not need to change for compatibility, though returning `suggestions` remains allowed.

`RemoteAIWorkoutService` preserves its safe offline fallback. Its catch path distinguishes at least:

- response decoding failures;
- transport/function invocation failures; and
- uncategorized failures.

Failures are recorded through structured system logging with the category and safe error metadata. Logs must not include coach message text, authentication tokens, email addresses, or full response bodies. User-facing fallback copy remains concise and does not expose internal error details.

## 5. Non-Compounding Soreness

Persisted `MuscleRecoveryState` represents objective workout fatigue and time-based recovery. Subjective soreness is not permanently subtracted from these states.

`applyRecoveryDecay` performs time decay and persistence only. Calling it repeatedly at the same timestamp is idempotent with respect to soreness. `setSoreness` updates the current readiness selection and may trigger a workout refresh, but it does not reduce persisted recovery.

Workout generation applies soreness exactly once to an in-memory recovery map. It uses the existing scoped penalty:

- full penalty for muscles present in the most recent two workout summaries;
- half/systemic penalty for other muscles; and
- no penalty for `.none`.

The current flat severe/moderate subtraction in `WorkoutGenerationService.selectTargetMuscles` is removed. Changing the soreness selection recalculates from the same persisted recovery baseline, so moving between levels neither stacks penalties nor requires reversing prior mutations.

## Data Flow

### Scheduled day

Profile weekdays → `TrainingSchedule.isTrainingDay` → normal regeneration pipeline → validated persisted workout.

### Unscheduled day

Rest Day hero → explicit override operation → normal regeneration internals without calendar guard → validated persisted workout → plan review.

### Recovery

Persisted recovery → time decay and save → copy to generation input → one scoped soreness adjustment in memory → target-muscle selection.

### Cloud coach

Edge response → tolerant validation decoding → mapped coach result. Any decode or invocation failure → categorized private log → offline fallback.

## Error Handling

- Schedule normalization never silently adds a weekday.
- A profile cannot be edited below two selected weekdays.
- Train-anyway failures do not alter the schedule or erase the current persisted workout.
- Missing validation suggestions are valid and become `[]`; malformed required fields still fail decoding.
- Cloud failures never bypass coach safety validation.
- Recovery persistence failures retain the existing best-effort behavior and do not cause additional soreness subtraction.

## Test Strategy

### Unit tests

- `testRegression_settingsScheduleAlwaysDerivesFrequencyFromSelectedDays`
- `testRegression_settingsScheduleCannotDropBelowTwoDays`
- `testRegression_onboardingCompletionDoesNotAddToday`
- `testRegression_onboardingScheduleDerivesFrequencyFromSelectedDays`
- `testRegression_validationDecodesWithoutSuggestions`
- `testRegression_generationAppliesScopedSorenessOnce`
- `testRegression_generationDoesNotApplyLegacyFlatSorenessPenalty`

### App environment / integration tests

- `testRegression_trainAnywayGeneratesOnUnscheduledDay`
- `testRegression_normalRegenerationRemainsBlockedOnUnscheduledDay`
- `testRegression_repeatedRecoveryDecayDoesNotCompoundSoreness`
- `testRegression_changingSorenessDoesNotMutatePersistedRecovery`

### UI test

Launch with `-UITesting -ResetState -MockAI -MockFoodSearch -SkipOnboarding` in a deterministic rest-day fixture. Assert `today.trainAnyway` exists, tap it, and assert the workout-plan primary action becomes visible.

## Verification

Run focused regression tests first, then the `PR` configuration in `HotBod.xctestplan`, then build the app. Confirm Today navigation for scheduled and unscheduled days, Settings and onboarding minimum-day behavior, profile persistence after relaunch, and cloud-shaped JSON decoding.

## Out of Scope

- P1–P3 audit findings.
- Removing `trainingDaysPerWeek` from persisted models or remote DTOs.
- Supabase schema changes.
- Persisting soreness across app launches.
- Automatically starting a workout after `Train anyway`.
- Redesigning recovery visualization or general coach fallback copy.
