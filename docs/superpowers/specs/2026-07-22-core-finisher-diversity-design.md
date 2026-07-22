# Core Finisher Diversity

Date: 2026-07-22  
Status: Approved for planning

## Problem

HotBod’s core finisher always feels the same: `CoreFinisherPlanner` hard-ranks a tiny preferred list (`plank` → `dead_bug` → …) and appends the top 1–2 exercises with a weak prescription (often a single timed set, 45s rest). The abs catalog is also thin, so even without the preference list there is little real variety.

Fitbod typically ends a session with **one** proper core or lower-back exercise — 3–5 sets, ~30s rest — drawn from a diverse pool (knee raises, rollouts, crunches, etc.).

## Goals

- Append **exactly one** core/lower-back finisher when `includeCoreFinisher` is enabled (standard sessions).
- Prescription: **3 / 4 / 5 sets** by experience (beginner / intermediate / advanced), **30s rest**, Fitbod-shaped volume.
- Selection is **session-aware** (preferred core role from today’s focus) then **rotates** away from recently used finishers/roles.
- Expand the core catalog so rotation has real options.
- Keep the existing Settings toggle and append-at-end structure (Approach 1).

## Non-goals

- Folding core into the main exercise selection pool.
- Adding `coreRole` (or similar) to the `Exercise` schema — roles live in a planner-local map for now.
- UI redesign of the finisher row.
- Using cardio abs (e.g. mountain climbers) as finishers.
- Changing recovery-session behavior (finishers remain standard-session only).

## Design

### Behavior

When `userProfile.includeCoreFinisher` is true and session mode is `.standard`:

1. Build a candidate pool from the catalog.
2. Score candidates (role match → recency → experience fit).
3. Append the single highest-scoring exercise as a finisher.
4. Reindex `orderIndex` on the planned list.

If the pool is empty (no equipment / all already planned), append nothing.

### Prescription

| Experience   | Sets | Rest | Intensity (`PlannedExercise.intensity`) |
|--------------|------|------|-----------------------------------------|
| Beginner     | 3    | 30s  | `.light`                                |
| Intermediate | 4    | 30s  | `.moderate`                             |
| Advanced     | 5    | 30s  | `.moderate`                             |

- **Reps** exercises: use metadata defaults when present; otherwise ~10–15 reps, RPE ~7.
- **Timed holds** (plank, side plank): keep timed prescription type, but still **3–5 sets** of the hold with 30s rest between (not a single set).
- Reason example: `Core finisher — anti-extension for today’s push session.`

### Candidate pool

Gate on a curated **finisher allowlist** (existing keep-list + new IDs below). Include if all of:

- ID is on the allowlist
- Equipment available
- Not already in the planned session
- `movementPattern != .cardio`

Pallof / side plank stay eligible via allowlist even when primary muscle is obliques.

**Hard excludes (never allowlist):** `mountain_climber`, `deadlift`, `good_morning`, `medicine_ball_slam` (power/conditioning, not a controlled core finisher).

### Core roles (planner-local)

```
flexion | antiExtension | antiRotation | lateral | lowerBack
```

Map curated exercise IDs → role. Unmapped candidates fall back to a coarse heuristic from `movementPattern` / primary muscle (e.g. `.rotation` → lateral, `.lowerBack` primary → lowerBack, else antiRotation).

### Session → preferred role

| Session signal                         | Prefer |
|----------------------------------------|--------|
| Push / chest-heavy focus               | antiExtension |
| Pull / back-heavy focus                | flexion |
| Legs / hinge-heavy focus               | antiRotation (fallback: lowerBack if no anti-rotation candidates) |
| Full body / mixed / unknown            | least-recently-used role across the five, from `recentWorkouts` finishers |
| Session already plans heavy lowerBack (e.g. deadlift in `planned`) | apply a strong penalty to `lowerBack` role candidates |

Use `splitDayFocus` as the primary session signal; inspect already-planned exercise IDs/muscles only for the lowerBack-volume penalty.

### Scoring

Highest score wins (deterministic for tests):

1. **Role match** — preferred role for session (largest boost); secondary boost for compatible adjacent roles
2. **Recency penalty** — same exercise ID in `recentWorkouts` (strong); same role recently (moderate)
3. **Experience fit** — penalize advanced-difficulty finishers for beginners when easier candidates exist
4. **Tie-break** — stable by `id`

### Catalog expansion

Add seed + content entries (high-quality finishers):

| Role           | New IDs                                      |
|----------------|----------------------------------------------|
| Flexion        | `crunch`, `reverse_crunch`, `lying_leg_raise`, `hanging_knee_raise` |
| Lateral        | `bicycle_crunch`                             |
| Lower back     | `back_extension`                             |

Keep / use existing: `plank`, `dead_bug`, `bird_dog`, `side_plank`, `russian_twist`, `ab_wheel_rollout`, `hanging_leg_raise`, `cable_crunch`, `pallof_press`.

Enrich stubby instructions/cues/prescription metadata on key finishers so they feel proper in-session.

### API / wiring

```swift
CoreFinisherPlanner.appendCoreFinisher(
    to: &planned,
    exercises: allExercises,
    availableEquipment: ...,
    experience: ...,
    splitDayFocus: ...,          // new
    recentWorkouts: ...          // new
)
```

Update the call site in `WorkoutGenerationService` (already has focus + recent workouts). No Settings UI change.

## Implementation touchpoints

| Area | Change |
|------|--------|
| `CoreFinisherPlanner.swift` | Role map, scoring, single-finisher prescription |
| `WorkoutGenerationService.swift` | Pass focus + recent workouts into planner |
| `ExerciseSeed.json` / `ExerciseContent.json` | New core exercises + content enrichment |
| `project.pbxproj` / catalog loaders | Only if new assets require explicit membership (follow existing seed patterns) |
| Unit tests (`CoreFinisherPlannerTests` / feedback domain) | Selection, prescription, rotation, equipment, toggle |

## Testing

- Enabled → exactly **one** finisher appended; disabled → none.
- Sets/rest by experience: 3/4/5 × 30s.
- Push-biased session prefers anti-extension family when available.
- Pull-biased session prefers flexion family when available.
- Recently used finisher ID is demoted on the next generate.
- Equipment filter respected (no pull-up-bar raises without bar).
- Timed holds still produce multi-set timed prescriptions.
- Regression: existing generation tests that disable core finisher still pass.

## Success criteria

- Consecutive generated workouts (same equipment, core on) do not repeatedly end on plank + dead bug.
- Finisher looks like a real working set block (multi-set, short rest), not a token hold.
- Catalog covers flexion, anti-extension, anti-rotation, lateral, and lower back with equipment-gated options.
