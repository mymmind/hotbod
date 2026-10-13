# Workout Generator P0 Design

**Date:** 2026-10-13
**Source:** `docs/HotBod_Training_Audit_Dev_Brief_2026-10-13.md` (Release 1)
**Scope:** P0-1 double progression, P0-2 untrusted effort, P0-3 full-session duration

## Goal

Make the next workout a pure reading of decisions that were already made. Logging owns load progression. Explicit effort is the only effort that can change a load or start a high-effort deload. The duration estimate is taken after warmups, rest, transitions, conditioning, core, and cooldown are all present, and optional work is removed until the session fits the target or the remaining priority work is explained.

## Constraints

- iOS 26+, SwiftUI, SwiftData, MVVM + Services + Repositories.
- Local-first. The new profile, completed-set, and session-mode fields sync through the existing Supabase tables.
- No change to exercise selection, weekly set allocation, stimulus tags, family load transfer, strength-versus-volume trends, anchor blocks, provenance export, or the recovery fatigue model.
- Generated exercises and manually added exercises share one load planner.
- Session modifiers (deload, recovery, return-from-break, rounding, ceilings) are applied to the planned weight and are not written back onto `suggestedNextWeightKg`.
- Every defect gets a `testRegression_<issue>` test.
- The RIR sheet and the two new settings rows keep their behavior in domain functions. UI tests for those controls are exempt; the exemption comment lives in the new unit-test file. The existing Skip identifier `workout.rir.skip` stays.

## 1. Load planner

Add `SessionLoadPlanner` in `HotBod/Domain/Algorithms/SessionLoadPlanner.swift`.

```swift
enum SessionLoadPlanner {
    struct Input {
        var suggestedNextWeightKg: Double?
        var lastWeightKg: Double?
        var sessionMode: SessionMode
        var isInDeloadWeek: Bool
        var returningFromBreak: Bool
        var equipment: [Equipment]
        var ceilings: [Equipment: Double]
        var fallbackWeightKg: Double
    }

    static func plannedWeightKg(_ input: Input) -> Double
}
```

Base weight, in order:

1. `suggestedNextWeightKg` when it is non-nil.
2. Otherwise `lastWeightKg` when it is non-nil. This logged weight is not incremented.
3. Otherwise `fallbackWeightKg`, which callers fill with the existing `defaultWeight` / `suggestedStartWeight` path.

One session modifier, then stop:

1. `sessionMode == .recovery`: multiply by `GenerationConstants.RecoverySession.weightMultiplier` (0.7).
2. Otherwise `isInDeloadWeek`: multiply by `GenerationConstants.Deload.loadMultiplier` (0.9, the factor `nextWeight(current:stats:)` uses today).
3. Otherwise `returningFromBreak`: multiply by `GenerationConstants.Deload.reEntryWeightMultiplier` (0.9).

Then `GenerationConstants.Weight.roundToAvailable` with the exercise equipment and the profile ceilings. Rounding and the ceiling are idempotent.

`WorkoutGenerationService.planExercise` and `SessionExercisePlanner.makeWorkoutExercise` both call this function. `makeWorkoutExercise` gains `sessionMode: SessionMode = .standard`. `appendExercise` passes the active session's mode. `WorkoutSession` gains `sessionMode`, default `.standard`, copied from `GeneratedWorkout` when the session starts. Missing Codable keys and a null `workout_sessions.session_mode` decode as `.standard`. The external-load gate stays outside the planner: `.none` still plans no weight, and `.optional` still plans external load only after the user has a stored `planningWeightKg`. Deload set-count reduction stays in `deloadAdjustment` and is not written back onto stats.

`planExercise` stops calling `ProgressiveOverload.nextWeight(current:stats:)`. Remove that overload when it has no remaining production callers. Keep `nextWeight(currentWeight:completedAllSetsAtTopRange:...)`, which `updateStats` uses at log time. Volume-trend increments and the high weekly-completion 5% cut leave the planning path.

A stored 67.5 kg plans at 67.5 kg on every generate. During a deload week the base is multiplied by 0.9 once (60.75 kg) and then rounded. On a 2.5 kg barbell increment that is 60 kg, and `suggestedNextWeightKg` stays 67.5 kg. A second generate still plans 60 kg.

## 2. Effort status

Add `EffortFeedbackStatus` with raw values `explicit`, `skipped`, and `unknown`. `CompletedSet` stores `effortFeedbackStatus`. A missing Codable key decodes as `unknown`.

`EffortFeedbackMapping` gains:

- `trustedEffectiveRPE(rpe:rir:status:trustHistoric:) -> Double?`
  - `explicit`: existing `effectiveRPE` (RIR wins when both are present).
  - `skipped`: nil.
  - `unknown`: existing `effectiveRPE` only when `trustHistoric` is true.
- `markSkipped(_:)` sets status `skipped`, and sets RIR, RPE, and `isFailure` to empty / false.
- `markExplicit(_:rir:)` sets status `explicit`, stores that RIR, stores `rpe(fromRIR:)`, and sets `isFailure` only when RIR is 0.

`averageEffectiveRPE` and the high-effort branch in `DeloadDetector.analyzeDeloadNeed` take `trustHistoricEffortFeedback: Bool = true` and read effort only through `trustedEffectiveRPE`. `updateStats` takes the same flag, defaulting to true, and passes it into progression and deload detection. A nil trusted RPE leaves `rpeProgressionMultiplier` at 1.0, so a completed top of the rep range still increases the load. `isFailure` remains a log/export flag and does not choose the next weight.

Logging order in `WorkoutSessionView+ExerciseActions`:

1. Append the completed set.
2. Warmup sets, cooldown sets, and any set logged while `promptForEffortFeedback` is false are `markSkipped` and do not present the sheet.
3. Otherwise `markSkipped`, then present the sheet.
4. A selection calls `markExplicit`.
5. Skip and swipe-dismiss leave the set `skipped`.

`UserProfile` gains `promptForEffortFeedback: Bool = true` and `trustHistoricEffortFeedback: Bool = true`. Both appear in Codable, `empty()`, `realigned(to:)`, and the profile sync DTO. Missing keys decode as true.

Settings, Session structure, gains two rows:

- "Ask for reps in reserve" binds `promptForEffortFeedback`.
- "Use older effort entries" binds `trustHistoricEffortFeedback`.

`shouldRefreshWorkout` includes `trustHistoricEffortFeedback` and does not include `promptForEffortFeedback`. `UserProfile` equality already sees both fields, so the save guard stays correct.

`ProgressiveOverload.reapplyEffortTrust(stats:trustHistoric:)` recomputes `suggestedNextWeightKg` from the stored last weight and last reps. It does not append sets. Hit-top means `lastReps >= preferredRepRangeMax`. Missed-min means `lastReps < preferredRepRangeMin`. The RPE passed into the existing progression policy is the trusted average of `recentSets`. It does not change `lastWeightKg`, `lastReps`, `deloadStartedAt`, or `returningFromBreak`.

An in-progress deload week is left in place when the switch flips. The detector does not store why a deload started, so replay cannot separate a volume deload from an effort deload without also clearing legitimate deloads whose counters were reset at the start of the week. After the switch is off, unknown RIR cannot start a new high-effort deload. Explicit sets still can.

`updateUserProfile` keeps its current order when the trust flag is unchanged. When `trustHistoricEffortFeedback` changes:

1. Load exercise stats and run `reapplyEffortTrust` in memory.
2. Save the stats.
3. Save the profile.
4. Regenerate today's workout when `shouldRefreshWorkout` is true.

If the stats save fails, the profile flag is not saved and the in-memory profile stays on the previous value. Other profile edits in that same save are held back with it.

Recovery fatigue continues to read stored RPE through `RecoveryCalculator.effortMultiplier`. This release does not change that model. New skipped sets have nil RPE, so they fall through to the existing missing-RPE multiplier. Historic sets that already stored an RPE still contribute until a later release.

## 3. Duration budget

Add `SessionDurationBudget` in `HotBod/Domain/Algorithms/SessionDurationBudget.swift`.

`WorkoutGenerationAlgorithms.estimateDurationMinutes` becomes the sum of planned set work, rest between sets, and transitions between exercises, rounded up to the next minute. It no longer adds `durationWarmupSeconds`. Delete that constant if nothing else reads it. Per-set work stays `durationWorkSecondsPerSet` unless the set has `targetDurationSeconds`. Warmup rest stays on warmup sets. Transition time stays `transitionSecondsPerExercise` between exercises.

Generation order for a standard session:

1. Plan exercises, including warmup sets.
2. Apply grouping.
3. Append conditioning when the profile asks for it. Record the appended exercise id.
4. Append the core finisher when the profile asks for it. Record the appended exercise id.
5. Append cooldown sets (`isCooldown == true` on each rep-based exercise).
6. Run the budget.
7. Clear `groupId` on the survivors and apply grouping again.
8. Set `estimatedDurationMinutes` from the post-regroup estimate.

`appendCoreFinisher` and `applyCardioBlock` return the optional appended exercise id so the budget does not detect those blocks by reason text. Recovery sessions use the same budget. `trimToDuration` is no longer called from generation. The 10% over-target allowance and the stop at four exercises are not part of this pass. `WorkoutValidator`'s existing over-target warning stays.

While the estimate is above `targetDurationMinutes`, shed in this order, recomputing the estimate after each step, and stop as soon as the estimate fits:

1. Remove every set with `isCooldown == true`.
2. Remove the conditioning exercise, when one was appended.
3. Remove one set from the end of the core finisher. Repeat until that exercise has no sets, then remove the exercise.
4. Keep warmup sets on the first exercise that has any. Remove warmup sets from every later exercise in one step.
5. Remove the lowest-scored isolation that still leaves another selected exercise for each of its target muscles. Use the same coverage rule as today's `indexOfLowestScoredIsolationToDrop`. Skip the core-finisher id and the conditioning id. Compound exercises are not removed. Repeat.

The first loaded lift keeps its full ramp even when the session is still over. Compound working sets are not shortened.

After the final regroup, if the estimate is still above the target, keep the plan.

Rationale appends, only for what actually happened:

- Any successful shed uses the parts that were actually removed, in this order: `cooldown`, `conditioning`, `core finisher`, `extra warm-ups`, `accessory work`.
  - One part: `Adjusted to fit 45 min by removing cooldown.`
  - Two parts: `Adjusted to fit 45 min by removing cooldown and conditioning.`
  - Three or more: commas between parts, with `, and` before the last. `Adjusted to fit 45 min by removing cooldown, conditioning, and core finisher.`
- Still over after the budget: `Estimated 52 min. Priority work exceeds the 45 min target.` The numbers are the post-regroup estimate and the target.

Both sentences can appear. A session that already fits gets neither sentence. Running the budget twice on an already-fitting plan does not change it.

Regrouping happens once, after shedding. Superset rest is shorter than straight-set rest, so the final estimate can only stay the same or drop. This release does not shed again after that regroup. Shedding one extra accessory because the pre-regroup rest was longer is acceptable.

## 4. Sync

Migration `supabase/migrations/20261013120000_effort_feedback_status.sql`:

- `profiles.prompt_for_effort_feedback boolean not null default true`
- `profiles.trust_historic_effort_feedback boolean not null default true`
- `completed_sets.effort_feedback_status text` nullable
- `workout_sessions.session_mode text` nullable

A null effort status on pull decodes as `unknown`. That column has no default, so older rows are not marked explicit. A null `session_mode` decodes as `standard`. `CompletedSetRow`, the profile row, `WorkoutSessionRow`, and `SupabaseCloudSyncService+Pull` carry the new fields. Local decode of a pre-migration set, profile, or session uses those same defaults.

## 5. Tests

`HotBod/Tests/UnitTests/WorkoutGeneratorP0Tests.swift`

`testRegression_doubleProgression`

- A stored 67.5 kg stays 67.5 kg across two plans when volume trend is stable, increasing, and decreasing.
- Deload on barbell equipment plans 60 kg from a stored 67.5 kg and leaves the stored suggestion at 67.5 kg. A second plan repeats 60 kg.
- Recovery multiplies once by 0.7. Return-from-break multiplies once by 0.9.
- The same stats produce the same planned weight from `planExercise` and `makeWorkoutExercise`.
- Stats with `lastWeightKg` and a nil suggestion use that logged weight and do not add an increment.

`testRegression_skippedEffort`

- `markSkipped` clears RIR, RPE, and failure.
- `markExplicit` stores RIR, the mapped RPE, and failure only for RIR 0.
- A skipped set and a set with no effort produce the same next suggestion from reps and weight.
- An explicit very-hard RIR can withhold the load increase and can satisfy the high-effort deload branch.
- `unknown` RIR counts while `trustHistoricEffortFeedback` is true and is ignored while it is false. With the flag false, reps at the top of the preferred range still increase the load.
- `reapplyEffortTrust` keeps `lastWeightKg`, `lastReps`, and `deloadStartedAt`.
- A completed-set payload without `effortFeedbackStatus`, and a profile payload without the two new keys, decode as `unknown` and both switches on.

`testRegression_durationBudget`

- Build the fixture so working sets, warmups, rest, and transitions already estimate at or above 45 minutes before core and cooldown are added. After the budget, the estimate is at or under 45, or the rationale contains the overrun sentence. The 4-set core finisher is gone.
- The first loaded exercise keeps its warmup sets. A later loaded exercise loses them when that is required to fit.
- The estimate has no flat extra 5 minutes: removing a warmup set lowers it.
- A second budget pass on the result is a no-op.
- A protected plan that cannot fit carries `Estimated N min. Priority work exceeds the 45 min target.` and keeps its compound working sets.

`HotBod/Tests/Integration/IntegrationFlowTests.swift`

`testRegression_untrustedHistoricEffort` flips `trustHistoricEffortFeedback` through `updateUserProfile`, asserts the stored suggestion was recomputed from reps and weight, asserts `lastWeightKg` is unchanged, and asserts a following generate uses that recomputed suggestion.

The unit-test file carries this exemption: the RIR sheet and the two settings rows are user-facing, and their programming effects are covered by `testRegression_skippedEffort` and the integration test. No new UI test is added in this release.

## 6. Out of scope

P1 and P2 from the audit stay in later specs: stimulus-function coverage, marginal set allocation, family load calibration, durable strength-versus-volume history, anchor blocks, provenance export, rep-sanity prompts, and recovery-model confidence. The volume-drop deload branch is unchanged.
