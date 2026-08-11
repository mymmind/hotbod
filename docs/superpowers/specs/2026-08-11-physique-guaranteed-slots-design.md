# Physique Guaranteed (Soft-Reserve) Slots Design

**Date:** 2026-08-11  
**Status:** Approved for planning  
**Depends on:** `docs/superpowers/specs/2026-08-11-physique-stronger-generation-bias-design.md`  
**Supersedes (partially):** stronger-bias out-of-scope “Guaranteed Physique exercise slots” — this slice adds a **soft reserve** only (best-effort), not a hard floor.

## Goal

When an active Physique assessment supplies preferred muscle groups, daily generation **tries to place N on-focus Physique-primary exercises** into the workout by pre-filling selection from the already safety-filtered ranked list, then filling remaining slots as today. Thin catalogs never fail generation.

## Constraints

- iOS 17+, SwiftUI, local-first; single generator (`RulesWorkoutGenerationService` + `WorkoutGenerationAlgorithms`).
- Prefer: “focus,” “emphasized,” “why today’s training.”
- Avoid: medical claims, genetic destiny, lookalike claims, “guaranteed results” / “optimal program” product copy.
- Soft reserve only — never violate injury / equipment / avoided filters; never auto-change split.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- Hard floor that relaxes safety or equipment rules to force N
- Off-focus Physique picks (must intersect today’s target muscles)
- New UI (Today chip, badges, Settings)
- Changing volume boosts or scoring bonus magnitudes
- Cloud changes

## Decisions

| Topic | Choice |
|-------|--------|
| Strength | Soft reserve (best-effort) |
| N | 2 standard / 1 recovery |
| Focus | Physique primary ∩ target muscles |
| Hook | Prefill-then-fill in `selectExercises` |
| UI | None |

## 1. Product Behavior

### When active

`input.physiquePreferredMuscleGroups` non-empty (assessment bias − avoided, already wired).

### Reserve size

| Session | `reservedPhysiqueSlots` |
|---------|-------------------------|
| Standard | `2` (`GenerationConstants.Session.physiqueReservedSlots`) |
| Recovery | `1` (`GenerationConstants.RecoverySession.physiqueReservedSlots`) |

Effective reserve: `min(reservedPhysiqueSlots, maxExercises)`.

### Eligibility (reserved pick)

Exercise must:

1. Appear in the safety-filtered `ranked` list (injuries, equipment, avoided already applied upstream).
2. Have `primaryMuscles` intersecting `physiquePreferredMuscles`.
3. Have `primaryMuscles` intersecting today’s `targetMuscles`.
4. Respect existing pattern-duplicate rules (`blocksDuplicatePattern`) and unique exercise ids while seeding.

### Selection flow

1. Prefill up to effective reserve from `ranked` order (already includes Physique scoring bonus).
2. Run existing coverage → fill → min backfill for remaining slots, skipping used ids.
3. If fewer than N eligible candidates exist, keep whatever prefilled (0…N−1) and continue — **never** fail or underfill below `minExercises` because of reserve.

### When inactive

Empty physique list or `reservedPhysiqueSlots == 0` → identical to current `selectExercises` behavior.

## 2. Architecture

### Algorithms

Extend:

```text
WorkoutGenerationAlgorithms.selectExercises(
  ranked: [(Exercise, Double)],
  targetMuscles: [MuscleGroup],
  maxExercises: Int,
  minExercises: Int,
  physiquePreferredMuscles: [MuscleGroup] = [],
  reservedPhysiqueSlots: Int = 0
) -> ExerciseSelectionResult
```

Optional pure helper (unit-test friendly):

```text
eligiblePhysiqueReservePicks(
  ranked:,
  physiquePreferredMuscles:,
  targetMuscles:,
  limit:,
  // pattern state as needed
) -> [(Exercise, Double)]
```

### Constants

```text
GenerationConstants.Session.physiqueReservedSlots = 2
GenerationConstants.RecoverySession.physiqueReservedSlots = 1
```

### Service

`RulesWorkoutGenerationService` standard `selectExercises` passes `reservedPhysiqueSlots: Session.physiqueReservedSlots` and `physiquePreferredMuscles: input.physiquePreferredMuscleGroups`.  
Recovery path passes `RecoverySession.physiqueReservedSlots`.

No new `WorkoutGenerationInput` fields.

### UI

None in this slice.

## 3. Testing

- Unit: ample eligible ranked → ≥2 Physique∩target primaries when reserve=2.
- Unit: recovery reserve=1 → ≥1 when eligible exist.
- Unit: empty physique / reserve=0 → no prefill behavior change.
- Unit: Physique-only off-focus candidates → not reserved.
- Unit: thin catalog (0–1 eligible) → still ≥ `minExercises`; no crash.
- Unit: unique ids; pattern rules applied on prefill.
- Optional: service threads constants 2 / 1.

## 4. Out of Scope Follow-ups

- Today “Physique emphasized” chip / count hint
- Hard floor / equipment ladder extensions for Physique
- Off-focus reserve fallback
- User-tunable N
