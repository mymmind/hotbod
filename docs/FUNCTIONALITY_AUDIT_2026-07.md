# HotBod Functionality Audit — Dev Doc

**Date:** 2026-07-13
**Scope:** Full-app logic review triggered by report: *"the algo seems shoddy, app functionality doesn't make much sense — e.g. opening on a random day gives a rest day when I just want to train."*
**Method:** Root-cause trace of the rest-day complaint, followed by a full read-through audit of workout generation, recovery/deload, program-state/scheduling, and AI coach/cloud sync subsystems. All findings below are sourced to specific file:line locations — no speculation.

This doc does not prescribe exact code changes; it documents defects precisely enough for a developer to fix them, and gives a suggested fix direction for each.

---

## TL;DR — why the app "feels shoddy"

Three independent bugs compound into the exact symptom reported:

1. **Settings lets `trainingDaysPerWeek` and `preferredTrainingDays` drift apart**, and only `preferredTrainingDays` gates whether today is a training day. A user can be told they train "6 days/week" while the actual weekday list only has 2 days checked — 5 out of 7 days silently become "Rest Day."
2. **There is no "train anyway" affordance anywhere in the app.** Once `isTrainingDay` returns false, the user is fully locked out of training that day through the UI, regardless of why it returned false.
3. **Onboarding silently rewrites the user's chosen schedule** (auto-adds "today" to their day list, and force-overwrites `trainingDaysPerWeek` to match at completion) with no confirmation — so the schedule the user thinks they picked isn't the one saved.

Beyond the rest-day complaint, the audit found that **the real cloud AI coach is very likely dead in production** (silently falls back to a crude offline responder due to a JSON schema mismatch), and that **recovery/soreness values can be double- or triple-penalized** by re-entrant decay calls, which independently explains why generated workouts feel arbitrary or muscles seem to never recover.

---

## Severity legend

- **P0** — directly causes the reported "doesn't make sense" symptom, or silently destroys user data / disables a paid feature.
- **P1** — clear correctness bug with a plausible, reachable failure scenario.
- **P2** — real defect, lower user-visible frequency or impact.
- **P3** — cleanup (dead code, imprecision) — no user-visible symptom by itself.

---

## P0 — Fix first

### 1. `trainingDaysPerWeek` and `preferredTrainingDays` are independent, unreconciled fields
**Files:** `HotBod/Features/Settings/SettingsView+Training.swift:95-127`, `HotBod/Features/Settings/SettingsDraftEditing.swift:43-49`, `HotBod/Domain/Algorithms/TrainingSchedule.swift:121-128`

The Settings "Days per week" `Stepper` writes only `trainingDaysPerWeek`. The weekday chip toggles write only `preferredTrainingDays`. Nothing reconciles them before saving. `TrainingSchedule.isTrainingDay` — the single source of truth for rest-day rendering — reads **only** `preferredTrainingDays`.

**Failure scenario:** user sets the stepper to 6 but only 2 weekday chips are checked (e.g. left over from an earlier edit, or they just never touched the chips). The app shows "6" as their configured cadence (also read by `ProgressDashboardView.swift:82-85,306,335` for the "X/6 workouts this week" ring) but only trains them 2 days out of 7.

**Fix direction:** make one field the source of truth (recommend `preferredTrainingDays`, since it's what the scheduler actually uses) and derive the other, or reconcile on every edit the way `OnboardingProfileEditing.toggleTrainingDay` already does for onboarding. Add a test asserting Settings can't produce a state where `trainingDaysPerWeek != preferredTrainingDays.count`.

### 2. No "train anyway" escape hatch on the Rest Day screen
**File:** `HotBod/Features/Today/TodayView.swift` (`restDayHero`, ~line 221; `primaryTodayContent`, ~line 137)

Once `environment.isRestDay` is true, `TodayView` renders a dead-end hero card with no button to generate/start a workout regardless. This is true no matter *why* it's a rest day — misconfigured schedule (#1), a day the user genuinely didn't pick, or any future scheduling bug.

**Fix direction:** add an explicit "Train anyway" action on the rest-day hero that calls `regenerateTodayWorkout(profile:)` directly (same call already used by the "No workout yet" empty state at `TodayView.swift:157-159`), bypassing the `isTrainingDay` gate for that one generation call. This single change would immediately neutralize the worst effect of #1, #3, and any other scheduling bug.

### 3. Onboarding silently rewrites the user's chosen schedule
**Files:** `HotBod/App/AppEnvironment+Profile.swift:63-68` (`ensureTodayIncludedInTrainingDays`), `HotBod/Features/Onboarding/OnboardingProfileEditing.swift:94-106` (`trimTrainingDays`, `reconcileSchedule`)

- `ensureTodayIncludedInTrainingDays` is called unconditionally from `finishOnboardingAndStartTodayWorkout` and appends today's weekday to `preferredTrainingDays` if missing — permanently, with no confirmation. A user who picks Mon/Wed/Fri but finishes onboarding on a Tuesday ends up with Mon/Tue/Wed/Fri saved forever.
- Separately, `trimTrainingDays` only ever *shrinks* the day list when the stepper goes down; raising the stepper doesn't grow it. `reconcileSchedule` then force-overwrites `trainingDaysPerWeek` back down to `preferredTrainingDays.count` at completion, silently discarding whatever number the user last saw on the stepper.

**Fix direction:** drop the silent "add today" mutation — if the goal is "let them train today anyway," that's what fix #2 is for, and it doesn't require corrupting their stated schedule. For the stepper/chip mismatch, either grow the day list when the stepper increases (prompt to pick which days) or disable the stepper independent-editing entirely in favor of chip-only selection.

### 4. The real cloud AI coach is very likely dead in production
**Files:** `supabase/functions/_shared/validate.ts:56`, `HotBod/Domain/Models/DomainModels.swift:674` (`WorkoutValidationResult`), `HotBod/Services/AI/RemoteAIWorkoutService.swift:47-51,76-80`

The edge function's `validateWorkout` returns `{isValid, errors, warnings}` — no `suggestions` key. The Swift `WorkoutValidationResult` declares `suggestions: [String]` as a required, non-optional field with no default and no custom decoding. Every response where the coach actually proposes a workout change includes a `validation` object missing `suggestions`, so `JSONDecoder` throws. The catch-all at `RemoteAIWorkoutService.swift:76` swallows this and **silently falls back to `MockAIWorkoutService`**, appending "(Cloud coach unavailable — using offline responses.)" — easy to miss in a chat transcript.

**Impact:** every "modify my workout" request to the real AI silently fails and the user gets the crude keyword-based offline responder instead, indefinitely. This is plausibly the single biggest contributor to "the algo seems shoddy" — the actual AI is never running.

**Fix direction:** make `suggestions` optional with a default (`[]`) in `WorkoutValidationResult`, or add it to the edge function's response. Then split the generic catch in `RemoteAIWorkoutService.swift:76` into distinguishable failure modes (decode error vs. network vs. HTTP error vs. auth) and log/report decode errors — right now this class of bug is invisible to any monitoring.

### 5. Recovery/soreness values are double- and triple-penalized
**Files:** `HotBod/App/AppEnvironment+Recovery.swift:16-20,40`, `HotBod/App/AppEnvironment+Workout.swift:14,56,96`, `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift:252-256`, `HotBod/Domain/Algorithms/GenerationConstants.swift:58-59`

`applyRecoveryDecay()` persists a soreness penalty (`RecoveryCalculator.applySoreness`) every time it's called — and it's called on nearly every user action (`regenerateTodayWorkout`, `restartTodayWorkout`, `switchTodaySplitFocus`, `setSoreness`, app launch), with no flag tracking "already applied for this rating." A single "severe" soreness rating can be subtracted repeatedly as the user browses.

On top of that, `WorkoutGenerationService.swift:252-256` re-subtracts a *second*, flat soreness penalty at generation time from a recovery value that already had the (possibly repeated) scoped penalty baked in.

**Failure scenario:** user sets soreness to "severe," then taps around (switch split focus, restart workout) — 3 decay calls × 30-point scoped penalty = 90 points off one muscle's recovery from a single rating, then generation subtracts another flat 20 on top, easily flooring recovery to 0 and silently excluding that muscle from the day's workout or forcing an unwanted "recovery session."

**Fix direction:** track whether the current soreness rating has already been applied to persisted recovery state (e.g. store the soreness value + timestamp it was applied at, and no-op `applySoreness` if unchanged), and remove the redundant flat penalty in `WorkoutGenerationService` since the persisted `recoveryStates` already reflects soreness.

---

## P1 — Fix soon

### 6. Stale (yesterday's) workout can be shown as today's plan
**Files:** `HotBod/App/AppEnvironment.swift:115-177` (`bootstrap()`), `HotBod/App/HotBodApp.swift:14-25`

Staleness checks (`WorkoutStaleness.shouldRegenerate`) only run inside `bootstrap()`, which fires once from a root `.task`. There's no `scenePhase`/`willEnterForeground` handling anywhere in the codebase. If the app is backgrounded (not force-quit) overnight and resumed the next day, `isRestDay` correctly reflects the new day (it's a live computed property), but `todayWorkout` is never re-validated — the previous day's workout renders as if it's today's plan.

**Fix direction:** add a `scenePhase` observer that re-runs the staleness check (or the relevant slice of `bootstrap()`) on `.active` transitions, not just cold launch.

### 7. Exercise selection can silently drop a target muscle while duplicating another
**File:** `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift:81-137`

First pass skips a target muscle if its only candidate shares a movement pattern already used twice. Second pass fills remaining slots from *any* target-muscle match with no "already covered" check, so it can duplicate a muscle already hit instead of retrying the skipped one. The backfill-warning logic (`uncoveredMuscleWarning`) only checks whether *any* candidate exists, not whether one was actually selected — so this never surfaces a warning.

**Fix direction:** track selected muscle coverage explicitly through all three passes; only backfill for genuinely uncovered muscles, and make `uncoveredMuscleWarning` check the final `selected` set, not candidate availability.

### 8. Failed workout validation still ships the broken workout
**File:** `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift:201-222`

When `WorkoutValidator.validate` fails (duplicate exercise, invalid weight, exceeds safe volume threshold), `buildWorkout` appends the raw internal error strings to `workout.safetyNotes` and returns the workout anyway — it does not reject or repair it. Two current callers happen to re-validate and discard client-side; that's incidental, not guaranteed by the service's contract.

**Fix direction:** `generate()`/`buildWorkout` should treat validation failure as a genuine failure path (retry with adjusted parameters, or throw `GenerationFailure`), not a cosmetic note. `safetyNotes` should never contain raw validator error strings.

### 9. Coach doesn't actually adjust exercises for reported injuries/soreness
**Files:** `HotBod/Services/AI/CoachOfflineWorkoutProposer.swift:67-82` (`softenForSoreness`), `supabase/functions/_shared/validate.ts:9-13` (`RISKY_LIMITATIONS`)

`RISKY_LIMITATIONS` (mapping e.g. shoulder/lower-back/knee to risky movement patterns) is declared server-side but never referenced by `validateWorkout`. Client-side, `softenForSoreness` only trims set counts / adds rest — it never filters exercises against `context.limitations`.

**Failure scenario:** the app's own suggested coach prompt "Shoulder discomfort - adjust exercises" triggers a soreness-only softening — the same shoulder-loading presses stay in the plan with fewer sets, not swapped out.

**Fix direction:** wire `RISKY_LIMITATIONS` into `validateWorkout`, and have `softenForSoreness`/its Swift equivalent call the existing `ExerciseSubstitution.candidates(...)` path when `context.limitations` intersects an exercise's risk profile, not just reduce volume.

### 10. Sign-in can silently overwrite cloud profile data with local defaults
**Files:** `HotBod/Data/Remote/SupabaseDTOs.swift:5-79` (`ProfileRow`), `HotBod/Data/Remote/SupabaseCloudSyncService.swift:22-38,75-78`, `HotBod/App/AppEnvironment+Auth.swift:9-17`

`ProfileRow` has no columns for `availableEquipment`, `preferredTrainingDays`, `timeOfDayPreference`, `limitations`, `limitationNotes`, `includeWarmupSets` — they're never pushed to Supabase, and `toUserProfile(fallback:)` always takes them from the local device. `signIn` calls `pullFromCloud()` then immediately `pushToCloud()`.

**Failure scenario:** signing into an existing account on a new/reinstalled device pulls the real profile, but keeps that fresh install's default equipment/limitations, then immediately pushes — overwriting the cloud copy's real equipment list and injury notes, on every device.

**Fix direction:** add the missing columns to the sync schema and DTO round-trip, or explicitly document these fields as local-only (and never push them) to stop the silent overwrite.

---

## P2 — Real defects, lower impact

### 11. Split-day recovery-aware rotation branch is unreachable
**Files:** `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift:297-315`, `HotBod/Domain/Algorithms/TrainingSchedule.swift:157-162`

A branch that picks whichever body half has higher recovery only runs when `splitDayFocus == nil`. But `currentSplitFocus` only returns `nil` for `.adaptive` splits — for Upper/Lower and PPL (the common cases) it's always non-nil, so this recovery-aware logic never executes. Actual rotation is the blind `splitDayIndex % count` counter, which can still target muscles below 40% recovery if fewer than 2 clear the readiness bar (with only a warning, not a block).

**Fix direction:** either remove the dead branch, or change the calling condition so recovery-aware selection actually runs for non-adaptive splits too.

### 12. Per-exercise "deload" triggers on normal exercise variation, not real fatigue
**File:** `HotBod/Domain/Algorithms/Phase2Algorithms.swift:206-234,262-282`

Deload detection operates per exercise ID, disconnected from `MuscleRecoveryState`. If a user swaps Barbell Bench for Incline DB Press for a couple of sessions (normal variation), Bench's tracked 7-day set count drops >30% and gets auto-flagged "in deload" — next time they do bench, weight is cut 10% and sets reduced, even though the muscle was trained harder via the substitute.

**Fix direction:** aggregate deload volume checks at the muscle-group level (or at least across recognized substitute exercises), not raw exercise ID.

### 13. Generator doesn't respect its own weekly volume cap until after the fact
**File:** `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift:449-452,469,781-797`

The weekly set cap is computed and fed into weight-progression decisions, but never used to reduce set count during exercise planning. `validateWeeklyVolume` then treats exceeding it as a hard validation error — which per #8 doesn't actually stop a bad workout from shipping.

**Fix direction:** feed the cap into `planExercise`'s set-count decision, not just weight progression.

### 14. Warmup sets never generated for bodyweight/no-load exercises
**Files:** `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift:483-493,542-553`, `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift:332-346`

Warmups are gated by `canPlanExternalLoad`, false for `.none`-tracking (push-ups, pull-ups) and `.optional` exercises with no logged weight. `WarmupSetPlanner` already has a bodyweight-rep-based warmup path, but every call site always passes a non-nil default weight, so that path is dead.

**Fix direction:** call the existing bodyweight warmup path when `canPlanExternalLoad` is false, instead of skipping warmups entirely.

### 15. `trimToDuration` can't shorten all-compound sessions
**File:** `HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift:244-278`

Only isolation exercises can be dropped to shorten an over-length workout. A 4-exercise, all-compound session (squat/bench/row/deadlift) that overshoots 110% of target duration just breaks out of the loop with a soft warning and stays over-length.

**Fix direction:** allow dropping/shortening compound exercises (e.g. reduce sets before dropping) as a fallback when no isolation exercises remain.

### 16. Cloud sync is upsert-only with no reconciliation for cleared remote data
**File:** `HotBod/Data/Remote/SupabaseCloudSyncService+Pull.swift:7-15,17-25`

`pullRecoveryStates`/`pullExerciseStats` treat an empty remote result as "nothing to do," not "remote is empty." No delete/reconciliation path exists anywhere in sync.

**Fix direction:** distinguish "no rows because nothing was ever synced" from "no rows because remote was cleared" (e.g. via a sync-version/tombstone marker), or accept this as a known limitation and document it.

---

## P3 — Cleanup (no direct user-visible symptom)

- `SorenessLevel.recoveryPenalty` (`HotBod/Domain/Enums/DomainEnums.swift:311-317`) — dead, unscoped penalty value; only `scopedRecoveryPenalty` is actually used. Remove or document why both exist.
- `GenerationConstants.Session.durationWorkMinutesPerSet` / `durationWarmupMinutes` (`GenerationConstants.swift:120-121`) — unused; the real duration model uses separate seconds-based constants. Tuning these has no effect — remove or wire them in.
- Recovery decay (`HotBod/Domain/Algorithms/Algorithms.swift:58-67`) applies the same global elapsed-time decay to every muscle regardless of `lastTrainedAt`, which is written but never read post-bootstrap. Minor over/under-counting around workout boundaries; not a headline bug but worth tightening if the P0/P1 recovery fixes touch this code anyway.

---

## What already checks out fine (don't re-litigate these)

- Split rotation advancement (`advanceRotationIfMatchingFocus`) is completion-driven, not calendar-driven, and correctly guards against double-advancing per day. Mismatched cadence (e.g. 5 training days vs. a 3-day PPL cycle) does not desync or skip muscle groups.
- `RecoveryCalculator.normalizeStates` correctly backfills missing muscles and dedupes to the lowest value.
- Recovery values are genuinely read by workout generation when selecting target muscles — not orphaned.
- `MockAIWorkoutService` is not wrongly wired into production by default; it's only reached as the (over-firing, see #4) fallback path.
- `CoachModificationSafety.isSafeModification`'s coarse duration/exercise-allowlist/set-count gate works as designed — its gap is narrower (no injury-awareness, see #9), not a total bypass.

---

## Suggested fix order

1. **#2** (train-anyway button) — smallest change, immediately unblocks users regardless of any other scheduling bug.
2. **#1 + #3** (schedule field desync + silent onboarding rewrite) — same subsystem, fix together.
3. **#4** (dead cloud AI path) — one-line decode fix (`suggestions` optional) plausibly restores the app's core AI feature.
4. **#5** (recovery double-penalty) — directly affects whether generated workouts feel sensible session to session.
5. Remaining P1s (#6–#10), then P2/P3 as capacity allows.

Each fix should land with a regression test — most of these subsystems already have unit test scaffolding (`Tests/UnitTests/`), but none of the tests found during this audit exercise the specific interactions that produced these bugs (e.g. no test constructs a `trainingDaysPerWeek`/`preferredTrainingDays` mismatch, no test calls `applyRecoveryDecay` twice in a row, no test decodes a real edge-function-shaped JSON payload against `WorkoutValidationResult`).
