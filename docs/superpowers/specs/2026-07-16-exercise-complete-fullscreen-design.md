# Exercise Complete Full-Screen Takeover

Date: 2026-07-16  
Status: Approved for planning

## Problem

`ExerciseCompleteInterstitial` is appended at the bottom of the active session `VStack` (under the set table, Complete Set action bar, and rest timer). Completing an exercise therefore stacks two UI states at once and looks broken. Separately, finishing the last planned set of an exercise can start a transition rest (`advanceAfter: true`) before the interstitial appears, which reinforces the stacked/broken feel.

## Goals

- Exercise Complete is a true full-screen moment: active session UI is not visible.
- Keep existing interstitial content and accessibility identifiers.
- Last planned set of an exercise never starts rest; go straight to Exercise Complete.
- Between-set rest for non-final sets is unchanged.

## Non-goals

- Redesigning metrics or matching `WorkoutCompletionView` / `ForgeHeroCard` styling.
- Changing CTA copy on the last exercise of a workout (stays “Next Exercise”).
- Removing or rewriting `ExerciseGroupPlanner.restBeforeAdvancing` for other callers.

## Design

### Presentation

Mirror the existing `showCompletion` branch in `WorkoutSessionView`:

```
showCompletion          → WorkoutCompletionView
showExerciseComplete    → ExerciseCompleteInterstitial (full screen)
else                    → active session UI
```

Remove the interstitial from the bottom of `sessionContent`. When `showExerciseComplete` is true, set table, Complete Set, and rest bar are not in the view hierarchy.

### Layout

Keep current content:

- Eyebrow: “EXERCISE COMPLETE”
- Exercise name
- Stats card: sets logged, volume, best set, avg effort
- Primary CTA: “Next Exercise”

Layout adjustments for a real full-screen surface:

- Solid `ForgeColors.background` (not translucent)
- Content vertically centered
- CTA pinned near the bottom safe area

Accessibility IDs unchanged:

- `session.exerciseComplete`
- `session.exerciseComplete.continue`

### Flow

When the last planned set of the current exercise is logged:

1. Play existing exercise-complete feedback (after any RIR prompt flow, as today).
2. Set `showExerciseComplete = true` — never `.rest(..., advanceAfter: true)`.
3. User taps Next Exercise → clear flag and call `advanceExercise()` (finish workout if last exercise).

Between-set rest for incomplete exercises stays as today. Skip / swap / jump exercise continue to clear `showExerciseComplete`.

`ExerciseGroupPlanner.restBeforeAdvancing` may remain for other uses; the session last-set path must not call it.

## Implementation touchpoints

| Area | Change |
|------|--------|
| `WorkoutSessionView.swift` | Top-level branch for `showExerciseComplete`; remove footer interstitial from `sessionContent` |
| `ExerciseCompleteInterstitial.swift` | Solid background; center content; pin CTA to bottom |
| `WorkoutSessionView+ExerciseActions.swift` | On `allSetsDone`, always `.exerciseComplete` |

## Testing

- Regression: completing the last planned set yields exercise-complete presentation, not rest.
- UI: with exercise complete shown, `session.completeSet` is absent; `session.exerciseComplete` / continue are present.
- Existing IDs remain stable for UI tests.

## Success criteria

- Completing an exercise shows only the Exercise Complete surface.
- No rest timer appears after the final set of an exercise.
- Between-set rest still works for non-final sets.
- App builds; relevant unit/UI coverage passes.
