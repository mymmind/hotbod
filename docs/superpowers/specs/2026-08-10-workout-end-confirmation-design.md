# Workout End Confirmation

Date: 2026-08-10  
Status: Approved for planning

## Problem

During an active workout, jumping ahead to a later exercise (e.g. abs for a superset) and finishing that exercise can end the entire session even when earlier exercises still have unfinished sets.

Root cause: `advanceExercise()` treats “no next exercise by list index” as “workout finished” and calls `finishWorkout()` immediately. Completion is index-based, not set-completion-based. Manual End Workout already shows a confirmation dialog; the auto-advance path does not.

## Goals

- Never auto-end a workout without confirmation.
- Prompt confirmation when:
  1. User finishes the last set of the last list exercise (Continue on exercise-complete with no next index).
  2. User finishes all planned sets across all non-skipped exercises, regardless of order.
  3. User manually chooses End Workout (existing menu path).
- Confirmation copy differs when work remains vs when all sets are logged.
- Keep Training with incomplete work navigates to the first incomplete exercise.
- Fix supersets / out-of-order logging so finishing the last slot does not mark the session completed.

## Non-goals

- Redesigning `WorkoutCompletionView` or post-finish progression UI.
- Changing rest timer, RIR prompt, or exercise-complete interstitial content (only the action after Continue when finish would be implied).
- Changing skip / swap / group semantics beyond treating skipped exercises as not requiring remaining sets.
- Requiring confirmation for mid-workout advance to the next exercise.

## Design

### Domain: completion queries

Extend `WorkoutSessionCalculator` (alongside `currentExerciseIndex(for:)`) with pure helpers, for example:

| Query | Rule |
|--------|------|
| Exercise complete | `!wasSkipped` and `completedSets.count >= plannedSets.count` |
| Session fully logged | Every non-skipped exercise is complete |
| First incomplete index | First non-skipped exercise with open sets (align with / reuse `currentExerciseIndex` semantics) |
| Incomplete exercise count | Count of non-skipped exercises that still have open sets |

**Hard rule:** Being on the last list index never means the workout is finished. Only “all non-skipped exercises fully logged” or an explicit End Workout action counts as finish *intent* — and confirmation is still required before `finishWorkout()`.

Skipped exercises do not count as remaining work.

### UI flow

Reuse the existing `showEndConfirmation` confirmation dialog path. Do not call `finishWorkout()` from `advanceExercise()`.

`advanceExercise()` / Continue decision order:

```
1. Session fully logged (all non-skipped exercises complete, any order)
   → present end confirmation (never auto-finish)
2. Else if currentExerciseIndex + 1 < exercise count
   → advance to next list index
3. Else
   → present end confirmation (last list slot; earlier work may remain)
```

```
Menu End Workout → present end confirmation (unchanged trigger)

Confirm (End & Save / finish action) → finishWorkout()
Keep Training
  → if incomplete work exists → goToExercise(at: firstIncompleteIndex)
  → if all sets already logged → dismiss and stay on current exercise
```

Step 1 covers out-of-order completion: finishing the last remaining exercise mid-list prompts confirmation immediately instead of walking through already-completed later exercises. Any path that previously called `finishWorkout()` from advance must present confirmation instead.

### Confirmation copy

| State | Title | Message (direction) |
|--------|--------|----------------------|
| Incomplete exercises remain | End Workout? | “N exercises still incomplete. Logged sets will be saved.” |
| All non-skipped sets logged | Finish Workout? | “All sets logged. Ready to end this session?” |

Primary action remains save-and-end (existing “End & Save Progress” or equivalent). Cancel / Keep Training dismisses without completing.

Menu End Workout uses the same dialog and the same copy rules based on current session state.

### UITest affordance

Keep `session.ui.endWorkout` as a direct finish path for UI test speed unless existing helpers already go through the menu confirmation; prefer not breaking current UITest flows. Production menu and advance paths always confirm.

### Implementation touchpoints

- `HotBod/Domain/Algorithms/Algorithms.swift` — `WorkoutSessionCalculator` helpers
- `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift` — `advanceExercise()`
- `HotBod/Features/WorkoutSession/WorkoutSessionView.swift` — confirmation dialog title/message + Keep Training navigation
- Unit tests for calculator / gate helpers
- Regression test: finishing last index with earlier incomplete work must not auto-complete the session
- UI tests only if they assume auto-finish without confirmation

## Testing

### Unit

- Incomplete exercise count with mixed complete / incomplete / skipped
- Session fully logged when completed out of order
- First incomplete index after completing the last list exercise while earlier work remains
- Skipped exercises ignored for remaining-work queries

### Regression

- `testRegression_finishingLastIndexWithEarlierIncompleteDoesNotAutoComplete` (or equivalent naming): advancing from the last index with earlier open sets must not set `session.status = .completed` / must not invoke finish without confirmation intent

### UI (as needed)

- Update only if flows currently complete the workout by finishing the last exercise without tapping through confirmation

## Success criteria

- Jumping to abs (last exercise), finishing it, and continuing never silently completes the whole workout.
- Ending always requires an explicit confirmation action.
- Keep Training returns the user to the first incomplete exercise when work remains.
- Dialog copy clearly distinguishes incomplete vs all-logged states.
