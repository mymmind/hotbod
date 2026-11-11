# Kettlebell Circuit Session

Date: 2026-11-11  
Status: Approved for planning

## Problem

Athletes want a short home kettlebell session on non-gym days: five exercises, five reps, five rounds, about 60 seconds between rounds. Fitbod-style supersets are the mental model, but HotBod’s grouping today caps auto circuits at three moves and always uses a 15-second in-group transition — including between rounds. The expanded kettlebell catalog exists; the session type does not.

## Goals

- Explicit Today CTA: “Kettlebell Circuit” (not auto-scheduled).
- Generate a 5×5×5 kettlebell circuit with pattern-balanced, exposure-aware picks.
- Round-robin logging via one shared `groupId`.
- Rest: ~15s between exercises in a round; 60s before the next round.
- Completing a circuit must not advance the main split / training-day completion.

## Non-goals

- Settings to edit reps / rounds / rest.
- Auto-offer on non-training days.
- Changing gym Generate / Circuits preference behavior.
- Freestyle circuit builder.
- Watch-specific circuit UI.
- Warm-up, cooldown, or cardio blocks on this session.

## Product surface

### Today

- Secondary CTA labeled **Kettlebell Circuit**, accessibility id `today.kettlebellCircuit`.
- Shown only when `availableEquipment` includes `.kettlebell`.
- Hidden (or inert with a short equipment hint) when kettlebells are unavailable.
- Respects the same “no clobber active session” rules as Generate.
- Does not replace the primary Generate / Start Workout path.

### Program impact

- Circuit sessions save as normal completed workouts for history/volume.
- They do **not** toggle `TrainingSchedule` split-focus / “today’s workout completed” for the main program.

## Session model

Extend `SessionMode`:

```swift
enum SessionMode: String, Codable, Hashable {
    case standard, recovery, kettlebellCircuit
}
```

Generated workout:

| Field | Value |
| --- | --- |
| `title` | `Kettlebell Circuit` |
| `sessionMode` | `.kettlebellCircuit` |
| `generatedBy` | `.rulesEngine` |
| `exercises` | 5 planned exercises, one shared `groupId` |
| `rationale` / selection lines | Name the 5×5×5 scheme and 60s round rest |

## Constants

`GenerationConstants.KettlebellCircuit`:

| Constant | Value |
| --- | --- |
| `exerciseCount` | 5 |
| `reps` | 5 |
| `rounds` | 5 |
| `transitionRestSeconds` | 15 |
| `roundRestSeconds` | 60 |
| `rpeTarget` | 7.0 |

## Planner

New pure planner: `KettlebellCircuitPlanner`.

**Pool**

- Exercises whose equipment includes `.kettlebell`.
- Pass equipment filter + injury filter.
- Prefer beginner/intermediate for beginner profiles when peers exist.

**Slots (fill in order; demote recent exposures)**

1. Hinge  
2. Squat or lunge  
3. Vertical push  
4. Horizontal pull  
5. Core / carry / anti-rotation (mobility fallback)

If a slot has no candidate, fill from remaining kettlebell moves. Generate with whatever is available if fewer than 5 eligible (minimum 2). Below 2 → fail soft with UI empty state (“Add kettlebells in Equipment” / need more kettlebell exercises).

**Emission**

- One `groupId` for all members.
- Each exercise: `rounds` planned working sets, `reps` target, no warm-up/cooldown sets.
- Estimated duration ≈ work + `(exerciseCount - 1) * transitionRest * rounds` + `(rounds - 1) * roundRest`.

## Rest timing

Today every grouped partner advance uses `GenerationConstants.Grouping.transitionRestSeconds` (15).

Introduce a pure helper (e.g. on `SetAdvancePlanner`):

```text
restSeconds(afterCompleting setIndex, advancingTo partnerIndex, …) -> Int
```

| Situation | Rest |
| --- | --- |
| Partner still owes the **same** `setIndex` (same round) | 15s |
| Partner owes the **next** round (`setIndex + 1`) | **60s** if `sessionMode == .kettlebellCircuit`, else **15s** (unchanged for gym supersets/circuits) |
| No partner / exercise complete | Existing exercise-complete path |

Standard gym supersets and circuits remain 15s for all in-group advances (regression required).

## Session UI

- Reuse existing set table + rest bar; no new timer chrome.
- Circuit context label via grouping label path (Circuit · names).
- Weight fields follow existing kettlebell / per-hand rules.

## Verification

1. Planner unit tests: kettlebell-only, shared groupId, 5×5 sets when pool allows, slot coverage.
2. Rest helper tests: same-round 15; next-round 60 for kettlebellCircuit; standard groups stay 15.
3. Integration: generating a circuit does not mark main today-workout completion / split toggle.
4. UI test (or exemption): CTA visible with kettlebell equipment under UITesting flags.

## Follow-ups

- Optional Settings for scheme parameters.
- Auto-suggest on non-training days.
- Manual exercise swap inside a generated circuit.
