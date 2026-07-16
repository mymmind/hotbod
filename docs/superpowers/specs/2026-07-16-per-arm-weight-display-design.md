# Per-Arm Weight Display

Date: 2026-07-16  
Status: Approved for planning

## Problem

Dual-dumbbell exercises such as Incline Dumbbell Press show load as plain `KG` / `10kg × 5–8`. Lifters cannot tell whether the number is per dumbbell or total. The app already has `WeightDisplaySemantics.perHand` (`KG EACH` / `kg each`), but classification misses many bilateral presses (e.g. `incline_dumbbell_press`, `seated_dumbbell_press`), and “each” is weaker copy than “per arm.”

## Goals

- Dual handheld loads clearly read as **weight per arm** in the active session SETS table.
- Hybrid classification: broad dumbbell/kettlebell push/pull (+ existing lunge/carry/isolation) defaults, with ID overrides for edge cases.
- Consistent “per arm” wording on secondary surfaces that already format load (best set, workout preview).
- Keep stored weight as per-implement; do not change volume math.

## Non-goals

- Renaming the Codable case `perHand` → `perArm`.
- Doubling volume or treating logged weight as total of both implements.
- Backfilling or rewriting historical log strings in persistence.
- Full Localizable catalog migration for every weight string (only touch strings in scope).
- Pattern-specific alternate wording (e.g. “per hand” for carries); product choice is **per arm** for all `.perHand` surfaces.

## Design

### Copy

Keep internal case `WeightDisplaySemantics.perHand`.

| Surface | Before | After |
|--------|--------|--------|
| Session column (`sessionWeightLabel`) | `KG EACH` | `KG / ARM` |
| Target / timed weight suffix | `kg each` | `kg per arm` |
| Settings max-load helper | `kg per dumbbell` / `dumbbell (kg each)` | `kg per arm` / `dumbbell (kg per arm)` |

Example session target: `Warm-up · 10kg per arm × 5–8`.

### Classification

Resolve in `ExerciseMetadataResolver.resolvedWeightDisplaySemantics` in this order:

1. Explicit `exercise.weightDisplaySemantics` (seed / prescription overrides win).
2. Force-total ID set — single-implement exceptions. Initial membership: `goblet_squat`.
3. Force-per-hand ID set — retain the current allowlist for edge cases (`single_leg_rdl`, etc.).
4. Heuristic — equipment contains `.dumbbell` or `.kettlebell` **and** `movementPattern` is one of:
   - `horizontalPush`, `verticalPush`, `horizontalPull`, `verticalPull`
   - `lunge`, `carry`, `isolation`
   → `.perHand`
5. Else → `.total`

Expected outcomes:

| Exercise | Result | Why |
|----------|--------|-----|
| `incline_dumbbell_press` | `.perHand` | dumbbell + horizontalPush |
| `seated_dumbbell_press` | `.perHand` | dumbbell + verticalPush |
| `goblet_squat` | `.total` | force-total override |
| Barbell bench | `.total` | not dumbbell/KB path |
| Machine stack | `.total` | not dumbbell/KB path |

### Secondary surfaces

When formatting a load for an exercise resolved as `.perHand`:

- Exercise-complete best set: use `kg per arm` (not bare `kg`).
- `WorkoutPreviewSetFormatter` load / summary lines: same unit convention.

### Data & math

- Logged `weightKg` remains the value entered in the session field (one dumbbell / one arm).
- Volume stays `weightKg × reps` (no ×2 for two arms).

## Implementation touchpoints

| Area | Change |
|------|--------|
| `DomainEnums.swift` | `sessionWeightLabel` / `settingsWeightLabel` copy |
| `ExerciseMetadataResolver.swift` | force-total set; expand push/pull heuristic; keep force-per-hand IDs |
| `WorkoutSessionView+Metrics.swift` | `kg per arm` in target/suffix; best-set description |
| `SettingsView+SessionStructure.swift` | max dumbbell helper copy |
| `WorkoutPreviewViews.swift` (`WorkoutPreviewSetFormatter`) | per-arm unit when semantics are `.perHand` |
| Unit tests | resolver cases + label strings; update any snapshot/string assertions |

## Testing

- Resolver: incline DB press → `.perHand`; goblet squat → `.total`; barbell compound → `.total`; explicit override wins over heuristic.
- Labels: `.perHand` → `KG / ARM` and `kg per arm`.
- Regression: existing allowlisted IDs (e.g. `dumbbell_press`, `farmers_carry`) still resolve `.perHand`.
- Preview / best-set formatters include `per arm` when semantics are `.perHand`.

## Success criteria

On Incline Dumbbell Press in an active session, the weight column reads **KG / ARM** and TARGET shows **…kg per arm × …**.
