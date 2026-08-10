# Preferred Days Notifications-Only Design

**Date:** 2026-08-10  
**Status:** Approved for planning  
**Supersedes (partially):** `docs/superpowers/specs/2026-07-13-p0-functionality-repairs-design.md` §2 “Train Anyway” — calendar gates for generation are removed; soft Recovery framing remains.

## Goal

Preferred training days must stop blocking workouts. Life happens; if the user is in the gym on a non-preferred day, HotBod accommodates them. Preferred days become a preference signal for soft Recovery framing and future workout reminders — not a generation or logging gate. Workout focus continues to follow split rotation from the last completed session (e.g. pull → legs → push).

## Constraints

- iOS 17+, SwiftUI, SwiftData, MVVM + Services + Repositories.
- Local-first; no backend dependency or schema migration.
- Preserve validation, subscription/regeneration quota, persistence, and safety gates.
- No medical claims; Recovery copy is a nudge, not a hard stop.
- Do not build the notification scheduler in this change (keep preferred-day data ready for it).
- App must compile; add `testRegression_*` coverage for the new behavior.

## 1. Core Rule — Schedule vs Generation

`UserProfile.preferredTrainingDays` never blocks:

- bootstrap / `ensureTodayWorkoutOnLaunch`
- `revalidateTodayPlanForCurrentDay` (day rollover)
- `regenerateTodayWorkout`
- `restartTodayWorkout`
- `switchTodaySplitFocus`
- readiness-driven refresh
- coach-driven regeneration that already goes through the normal pipeline

Those paths always use the existing generation pipeline and pick focus via `TrainingSchedule.currentSplitFocus` / split rotation advanced on session completion.

### What preferred days still mean

| Use | Behavior |
|-----|----------|
| Soft Recovery UI | Today uses Recovery framing when today ∉ preferred days |
| Future reminders | Preferred days remain the source for workout-notification scheduling (scheduler out of scope) |
| Progress frequency | `trainingDaysPerWeek` stays derived from selected weekday count |

### What goes away

- `allowsUnscheduledDay` / `generateTodayWorkoutOnRestDay` as special generation overrides
- Clearing a stale today plan on non-preferred days without regenerating
- Hard coach rest-day messaging that implies training is unavailable
- “Train anyway” as a separate generation bypass

`TrainingSchedule.isTrainingDay` remains a **preference helper** (is today a preferred training day?). Call sites must not treat it as “may the user train / generate today.”

## 2. Bootstrap and Day Rollover

On any calendar day after onboarding — including immediately after onboarding completion on a non-preferred day:

1. If there is no today plan and today’s workout is not completed → auto-generate the next rotation session (same pipeline as preferred days).
2. If today’s plan is stale from a prior calendar day and no session is in flight → regenerate; do **not** wipe to empty solely because the day is non-preferred.
3. Completing a session still advances split rotation so the next open generates the next focus.

Onboarding still saves the exact preferred weekday set (no forcing today into the list). It no longer skips plan creation when completion falls on a non-preferred day; the user lands on soft Recovery + plan instead of a locked Rest Day.

Quota: initial launch/ensure generation remains non-quota-consuming (`requiresProAccess: false` for ensure-on-launch). User-initiated regenerate continues to use the same entitlement rules as on preferred days — no rest-day free-regenerate loophole.

## 3. Today UI

### Preferred day

Unchanged: workout hero with Start / Regenerate / Preview (and completed state when finished).

### Non-preferred day (“soft Recovery”)

| State | UI |
|-------|-----|
| No plan yet (brief load / failure) | Recovery hero; primary CTA **Generate** (not “Train anyway”) |
| Plan ready, not completed | Recovery hero stays primary; plan secondary (exercise strip + Start / Regenerate / Preview) |
| Completed | Same completed treatment as preferred days; Recovery eyebrow optional |

Copy:

- Keep “Rest Day” / “Recovery” as a nudge.
- Footer may show next preferred day for reminder context (e.g. “Usual days resume Thu”) without blocking actions.
- Accessibility: primary generate action uses `today.generate`. Migrate UI tests off `today.trainAnyway`.

### Settings / onboarding

Day chips remain. Helper copy shifts toward preferred / reminder days, not “only train on these days.” Toggling days does not force schedule mutations for generation. Minimum two selected days and `trainingDaysPerWeek = preferredTrainingDays.count` stay as today.

## 4. Coach Softening

`CoachOfflineModify.restDayMessage` (and any equivalent) must not imply the user cannot train. Prefer optional Recovery framing plus next usual preferred day when available. Coach modification paths must not refuse regeneration solely because `!isTrainingDay`.

## 5. Data Flow

```text
Preferred day:
  bootstrap → ensure plan (rotation focus) → workout hero → Start / Regenerate

Non-preferred day:
  bootstrap → ensure plan (rotation focus) → Recovery hero + secondary plan → Start / Regenerate

Preferred days data:
  Settings/Onboarding → profile.preferredTrainingDays
                      → UI Recovery framing
                      → (future) notification scheduler
                      → derived trainingDaysPerWeek for progress
```

## Error Handling

- Still block regenerate when today’s workout is already completed (restart remains the redo path).
- Still enforce subscription / free regeneration quota on user-initiated regenerate.
- Still cancel an in-flight session when regenerating; validation and persistence unchanged.
- Soft Recovery UI never claims medical necessity.
- Generation failures surface through existing failure/paywall state; Recovery hero remains if no plan exists.

## Test Strategy

### Replace / flip

- Remove expectation that normal regeneration is blocked on unscheduled days (`testRegression_normalRegenerationRemainsBlockedOnUnscheduledDay`).
- Add `testRegression_regenerateSucceedsOnNonPreferredDayWithoutExistingPlan`.

### Add / update

- `testRegression_bootstrapAutoGeneratesOnNonPreferredDay`
- `testRegression_revalidateDoesNotClearFreshPlanOnNonPreferredDay` (stale plans regenerate; fresh plans stay)
- `testRegression_nextFocusFollowsLastSessionAcrossNonPreferredDay`
- UI: Recovery hero + secondary plan + Start; no dependency on `today.trainAnyway`
- Keep schedule editing regressions (min two days, derive frequency from selected days)

### Coach

- Rest-day message tests updated so copy does not claim training is unavailable when a plan path exists.

## Verification

1. Focused unit/orchestration regressions above.
2. `HotBod.xctestplan` configuration **PR**.
3. Build the app.
4. Manual: non-preferred day with empty plan → auto or Generate works; Regenerate works without Settings changes; completing pull then opening on a non-preferred day suggests the next rotation focus.

## Out of Scope

- Implementing local notification scheduling
- Renaming persisted profile fields or Supabase DTO keys
- Removing `trainingDaysPerWeek` from models/DTOs
- Changing recovery math or split sequence algorithms beyond using them every day
- Auto-starting a workout session after generation
