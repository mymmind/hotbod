# Logged Weight Sanity Check

Date: 2026-07-16  
Status: Approved for planning

## Problem

Live workout logging accepts any parsed weight on Complete Set and when editing a completed set. There is no “are you sure?” gate. A fat-finger entry (e.g. 800 kg chest press) persists immediately, updates session state, and on workout finish can poison `UserExerciseStats` / e1RM / next-session suggestions via Progressive Overload.

Planned-workout generation already rejects loads above 400 kg and warns on 1.5× jumps vs last weight. Live logging does not reuse that protection.

## Goals

- Warn (soft) or block (hard) unrealistic logged weights before they are saved.
- Let the user fix the field without losing the typed value.
- Apply the same gate to Complete Set and edits of completed-set weight.
- Keep rules in a pure domain helper with unit tests.
- Reuse existing validation thresholds from `GenerationConstants.Validation`.

## Non-goals

- Exercise-specific world-record tables or movement-aware physiological models.
- Changing planned-workout `WorkoutValidator` behavior (except shared constants if already shared).
- Imperial / lb conversion (app remains kg-only).
- Silently clamping or auto-correcting weights.
- New UI tests beyond existing session dialog patterns (unit tests cover the gate; UI mirrors end/cancel confirmation style).

## Behavior

When a real weight is about to be saved (Complete Set with weight UI shown, or edit of a completed set’s `weightKg`):

### Hard block

Trigger if `weightKg < 0` or `weightKg > GenerationConstants.Validation.maxPlannedWeightKg` (400).

- Present an alert. No “Save anyway.”
- Dismiss only; leave the typed value in the field so the user can edit.
- Do not append/update the completed set and do not schedule a save.

### Soft warning

Trigger if not hard-blocked and `weightKg > baseline * weightJumpWarningMultiplier` (1.5), where baseline is:

1. `UserExerciseStats.lastWeightKg` for that exercise, if available and &gt; 0
2. Else `PlannedSet.targetWeightKg`, if available and &gt; 0
3. Else skip soft warning (hard block still applies)

Dialog actions:

- **Edit** — dismiss; keep typed value; do not save.
- **Save anyway** — commit that submission once; do not re-prompt for the same commit.

### Precedence

If both hard and soft would apply, hard wins.

### Skips

- Exercises with no weight input (`loadTrackingMode == .none` / weight UI hidden).
- Non-numeric empty field that already falls back to planned target (existing behavior); only gate the weight actually about to be persisted.

### Soft confirm once

After the user chooses Save anyway for a pending submission, commit without looping. A later different edit can warn again.

## Architecture

### Domain: `LoggedWeightSanity`

Pure function / small enum in Domain (alongside other algorithm helpers):

```text
evaluate(proposedKg:lastWeightKg:plannedWeightKg:) -> Outcome
Outcome: ok | softWarning(baselineKg:) | hardBlock(reason:)
```

Thresholds from `GenerationConstants.Validation.maxPlannedWeightKg` and `.weightJumpWarningMultiplier`.

### Session hooks

| Hook | Behavior |
|------|----------|
| `completeCurrentSet` | Evaluate before append / `scheduleWorkoutSessionSave`. On non-ok, stash pending complete + show dialog. |
| Completed-set weight edit (`bindingWeight` / `updateCompletedSet`) | Evaluate before update/save. On non-ok, hold pending edit + show dialog; revert field binding until confirmed or leave typed value without committing. |

### UI

Reuse `.alert` / `.confirmationDialog` patterns already used for end/cancel workout on `WorkoutSessionView`.

Copy guidelines (brutalist, no emoji, no cheerleading):

- Soft: state the entered load and that it is far above the usual/target baseline; actions Edit / Save anyway.
- Hard: state the load is invalid / beyond a sane max; single dismiss/edit action.

Exact strings via `Localizable.xcstrings`.

## Data flow

```text
User enters weight
  → parse proposed kg
  → LoggedWeightSanity.evaluate(...)
      → .ok → existing save path
      → .softWarning → dialog → Edit (abort) | Save anyway (save once)
      → .hardBlock → alert → dismiss (abort)
```

No change to `CompletedSet` / persistence schema.

## Testing

Unit tests (required) covering:

- Hard block above 400 kg and below 0
- Soft warning vs last weight (e.g. last 80 → 800 warns; last 80 → 100 ok)
- Soft warning vs planned when no last weight
- No soft warning when neither baseline exists
- Hard wins over soft (e.g. 800 with last 80)
- `.ok` within multiplier

Regression name pattern if fixing a reported bug path: `testRegression_absurdLoggedWeight`.

## Implementation touchpoints (expected)

| Area | Change |
|------|--------|
| New domain helper (e.g. under `Domain/Algorithms/`) | `LoggedWeightSanity` |
| `WorkoutSessionView+ExerciseActions.swift` | Gate `completeCurrentSet` |
| `WorkoutSessionView+SetTable.swift` (or weight binding) | Gate completed-set edits |
| `WorkoutSessionView.swift` | Pending state + alert/confirmationDialog |
| `Localizable.xcstrings` | Soft/hard copy |
| Unit tests | Domain gate coverage |

## Success criteria

- Entering 800 kg always hard-blocks (above 400 kg max) with no override; typed value stays so the user can fix it.
- Entering a large jump still under 400 kg (e.g. last 80 → 150) shows a soft warning with Edit / Save anyway.
- Confirming a soft warning once saves that set.
- Editing a completed set to an absurd weight hits the same gate.
- Domain unit tests pass; app builds.
