# Kettlebell Circuit Settings

Date: 2026-11-11  
Status: Approved for planning

## Problem

The kettlebell circuit session ships with a hard-coded 5×5×5 scheme (5 exercises, 5 reps, 5 rounds, 15s in-round transition, 60s between rounds). Athletes want to adjust that scheme without changing gym Generate behavior or burning the training day.

## Goals

- Editable full scheme in Settings when kettlebells are available.
- Discrete allowed values with safe defaults matching today’s constants.
- Planner and live rest timers honor the user’s scheme for **new** circuits.
- Mid-session Settings edits must not change rest for an in-progress circuit.
- Scheme-only Settings saves must not regenerate the gym `todayWorkout`.

## Non-goals

- Auto-offer on non-training days.
- Today pre-start override sheet.
- Editing the scheme of an active session.
- User-facing RPE / work-seconds estimate knobs.
- Freestyle circuit builder / exercise picker.

## Product surface

### Settings

- Section title: **Kettlebell circuit**.
- Visible only when `draft.availableEquipment` contains `.kettlebell`.
- Five discrete menu pickers:

| Control | Allowed values | Default |
|---------|----------------|---------|
| Exercises | 3…6 | 5 |
| Reps | 3…8 | 5 |
| Rounds | 3…8 | 5 |
| In-round rest | 10, 15, 20 seconds | 15 |
| Between-round rest | 45, 60, 90, 120 seconds | 60 |

- Caption: used when starting Kettlebell Circuit from Today; does not change the gym day.
- Saves with the normal Settings draft → profile save path.
- Changing only the scheme must **not** trigger gym workout refresh (`shouldRefreshWorkout` ignores scheme).

### Today

- Existing `today.kettlebellCircuit` CTA unchanged in visibility rules.
- Generate uses the saved (clamped) profile scheme.

## Data model

```swift
struct KettlebellCircuitScheme: Codable, Hashable {
    var exerciseCount: Int
    var reps: Int
    var rounds: Int
    var transitionRestSeconds: Int
    var roundRestSeconds: Int
}
```

- `UserProfile.kettlebellCircuitScheme` — decode-if-present → `.default`.
- `WorkoutSession.kettlebellCircuitScheme: KettlebellCircuitScheme?` — nil for non-circuit sessions; set on circuit start as a **snapshot**.
- `clamped` maps unknown/out-of-range values onto the nearest allowed option (or defaults).
- `GenerationConstants.KettlebellCircuit` remains the source of `.default` and of non-user-facing constants (`rpeTarget`, `workSecondsPerSet`).

## Generation + rest

```text
Settings → UserProfile.scheme
        → KettlebellCircuitPlanner.plan(..., scheme:)
        → GeneratedWorkout
        → resumeOrStartWorkout snapshots scheme onto WorkoutSession
        → SetAdvancePlanner.restSeconds uses snapshot transition/round rests
```

- Planner uses scheme for exercise count, reps, rounds, planned `restSeconds` (round rest), duration estimate, and rationale copy (actual N×R×rounds, not hard-coded “5×5×5”).
- Live rest:
  - Same-round partner advance → scheme `transitionRestSeconds`
  - Next-round partner advance when `sessionMode == .kettlebellCircuit` → scheme `roundRestSeconds`
  - Gym supersets/circuits → unchanged `Grouping.transitionRestSeconds` (15)
- Rest values come from the **session snapshot**, not the live profile.

## Verification

1. Scheme clamp / missing-key decode defaults.
2. Planner honors a non-default scheme.
3. Rest helper: same-round transition / next-round round rest from scheme; gym groups stay 15.
4. Session snapshot: profile scheme change after start does not change that session’s rest.
5. `shouldRefreshWorkout` false for scheme-only draft diffs.
6. Build succeeds; Settings UI gated on kettlebell equipment (UITest exemption if no fixture).

## Follow-ups

- Auto-suggest on non-training days.
- Manual exercise swap inside a generated circuit.
