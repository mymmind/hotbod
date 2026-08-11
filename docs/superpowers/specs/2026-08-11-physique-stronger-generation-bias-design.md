# Physique Stronger Generation Bias Design

**Date:** 2026-08-11  
**Status:** Approved for planning  
**Depends on:** `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`  
**Supersedes (partially):** soft-only merge of assessment `preferredMuscleGroups` — Physique groups now get a stronger same-day tilt than Settings preferred muscles.

## Goal

Make active Physique training bias **noticeably stronger** on today’s generated workout via selection scoring and weekly volume targets, while keeping a single generator, unchanged split rotation, and safety gates (avoided / injury / recovery) as hard winners.

## Constraints

- iOS 17+, SwiftUI, local-first; extend `WorkoutGenerationInput` + existing algorithms.
- Prefer: “emphasized,” “focus bias,” “why today’s training.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims.
- Soft tilt only — no second program engine, no auto split remap, no guaranteed exercise slots.
- Avoided muscles / injuries / recovery / validation still win.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- User-confirm split override / temporary program templates
- Auto-changing which split day fires
- New Settings toggles
- Changing assess pipeline or Physique report structure (beyond optional copy if already covered)
- Cloud changes

## Decisions

| Topic | Choice |
|-------|--------|
| Job | Stronger same-day bias (selection + volume) |
| Physique vs Settings | Physique-weighted (harder tilt for assessment groups) |
| Architecture | Dual lists on `WorkoutGenerationInput` |
| Split engine | Unchanged |
| UI | No new surface required |

## 1. Product Behavior

### When active assessment exists

- `physiquePreferredMuscleGroups` = assessment `trainingBias.preferredMuscleGroups` minus avoided (order preserved).
- Those groups receive:
  - **Volume:** +4 hard-set weekly landing boost (vs +2 for profile/merged preferred only).
  - **Selection:** +`physiquePreferredPrimaryBonus` when an exercise’s primary muscles intersect the Physique list.
  - **Recovery sort:** use Physique list for `preferredMuscleRecoveryBonus` when non-empty; else merged preferred (today).

### When no active assessment

- `physiquePreferredMuscleGroups = []`.
- Behavior identical to current soft merge (+2 volume for merged preferred; no Physique selection bonus).

### Safety

| Conflict | Winner |
|----------|--------|
| Physique group ∈ avoided / injured | Stripped from both lists; not boosted |
| Low recovery / force recovery session | Existing recovery paths unchanged |
| Validation / equipment | Unchanged |

## 2. Architecture

### Input

```text
WorkoutGenerationInput
  preferredMuscleGroups: [MuscleGroup]                 // merged assessment ∪ profile − avoided
  physiquePreferredMuscleGroups: [MuscleGroup] = []    // assessment − avoided; empty if none
```

`AppEnvironment.makeWorkoutGenerationInput`:
1. Merge via existing `PhysiqueTrainingBiasMerger.mergePreferredMuscleGroups`.
2. Build physique list from `activePhysiqueAssessment?.trainingBias.preferredMuscleGroups` filtered by avoided.
3. Pass both fields.

Codable: decode missing `physiquePreferredMuscleGroups` as `[]`.

### Constants

```text
GenerationConstants.MuscleVolume.profilePreferredBoost = 2.0   // existing
GenerationConstants.MuscleVolume.physiquePreferredBoost = 4.0  // new
GenerationConstants.Scoring.physiquePreferredPrimaryBonus = 6.0 // new
```

Place volume boosts next to related planner constants (or under a small nested enum); scoring bonus beside `favoriteBonus` / `primaryMuscleWeight`.

### Volume — `MuscleVolumePlanner.remainingBudget`

```text
remainingBudget(
  ...,
  preferredMuscles: [MuscleGroup] = [],
  physiquePreferredMuscles: [MuscleGroup] = []
)
```

Per target muscle: `boost = physique ? 4 : (preferred ? 2 : 0)` (Physique wins if both).  
Call site: pass merged preferred + physique lists from input.

### Selection — `WorkoutGenerationAlgorithms.scoreExercises`

Add `physiquePreferredMuscles: [MuscleGroup] = []`.  
If any `exercise.primaryMuscles` ∈ physique set → add `physiquePreferredPrimaryBonus`.  
Thread from `RulesWorkoutGenerationService` standard + recovery selection paths.

### Recovery sort

When `input.physiquePreferredMuscleGroups` non-empty, pass that list into `recoverySortKey`’s preferred argument; otherwise pass `input.preferredMuscleGroups`.

## 3. UI

- No new Settings or Today chrome required.
- Existing Physique “why today’s training” / focus bias copy remains the explanation surface.
- Optional (non-blocking): leave copy unchanged in v1 of this slice.

## 4. Testing

- Unit volume: Physique muscle remaining uses +4 landing; profile-only preferred +2; muscle in neither → base landing; avoided never present in lists under test.
- Unit scoring: identical exercises differ only by Physique primary match → Physique-matched scores higher by the bonus.
- Unit/integration: `makeWorkoutGenerationInput` populates physique list from active assessment; empty without assessment; avoided stripped from physique list.
- Regression: `testRegression_trainingBiasUsesNewestAssessmentOnly` still holds; extend or add assert on `physiquePreferredMuscleGroups` == newest bias (minus avoided).
- Update fixtures constructing `WorkoutGenerationInput` with default `physiquePreferredMuscleGroups: []`.

## 5. Out of Scope Follow-ups

- Guaranteed Physique exercise slots
- Split suggestion / apply dialog
- User-tunable boost magnitudes
- Today chip showing “Physique emphasized”
