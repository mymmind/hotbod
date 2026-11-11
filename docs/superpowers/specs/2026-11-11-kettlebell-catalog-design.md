# Kettlebell Catalog Expansion

Date: 2026-11-11  
Status: Approved for planning

## Problem

HotBod only has four kettlebell-capable seed exercises (swing, goblet squat, farmer’s carry, single-leg RDL). That is too thin for a real home kettlebell day and blocks the planned off-day circuit feature.

## Goals

- Expand the home-bell library to ~15 total movements (4 existing + 11 new).
- Ship real form copy in `ExerciseContent.json` for every new id.
- Attach public embeddable YouTube demos where findable; leave gaps on the handoff list.
- Keep generator/library eligibility normal (equipment filter only). No circuit scheduling in this pass.

## Non-goals

- Off-day / circuit session type (separate design next).
- New `MovementPattern` or `Equipment` enum cases.
- Bundled MP4 production.
- Special generator ranking or “kettlebell day” logic.
- Rewriting the four existing kettlebell entries unless a sibling requires a fix.

## Existing keepers

| id | name |
| --- | --- |
| `kettlebell_swing` | Kettlebell Swing |
| `goblet_squat` | Goblet Squat |
| `farmers_carry` | Farmer's Carry |
| `single_leg_rdl` | Single Leg RDL |

## New exercises

| id | name | pattern | mechanics | equipment | difficulty |
| --- | --- | --- | --- | --- | --- |
| `kettlebell_clean` | Kettlebell Clean | hinge | compound | kettlebell | intermediate |
| `kettlebell_press` | Kettlebell Press | verticalPush | compound | kettlebell | intermediate |
| `kettlebell_row` | Kettlebell Row | horizontalPull | compound | kettlebell | beginner |
| `kettlebell_snatch` | Kettlebell Snatch | hinge | compound | kettlebell | advanced |
| `turkish_get_up` | Turkish Get-Up | antiRotation | compound | kettlebell | advanced |
| `kettlebell_halo` | Kettlebell Halo | mobility | isolation | kettlebell | beginner |
| `kettlebell_windmill` | Kettlebell Windmill | hinge | compound | kettlebell | intermediate |
| `kettlebell_thruster` | Kettlebell Thruster | squat | compound | kettlebell | intermediate |
| `kettlebell_goblet_lunge` | Goblet Lunge | lunge | compound | kettlebell | beginner |
| `kettlebell_deadlift` | Kettlebell Deadlift | hinge | compound | kettlebell | beginner |
| `kettlebell_sumo_deadlift_high_pull` | Sumo Deadlift High Pull | hinge | compound | kettlebell | intermediate |

Primary/secondary muscles and force type follow existing peers (press ≈ overhead press peers, row ≈ dumbbell row, TGU biased to abs + shoulders, halo as light mobility, etc.). Kettlebell equipment already resolves to per-hand weight display via `ExerciseMetadataResolver`.

Equipment filter uses `allSatisfy`, so new rows list only the gear they truly require. `kettlebell_goblet_lunge` is kettlebell-only (unlike legacy `goblet_squat`, which lists both kettlebell and dumbbell). Content may note a dumbbell can substitute in freeform coaching copy, but the seed does not require dumbbells.

## Content

Each new id gets an `ExerciseContent.json` entry with:

- description
- aliases
- substitutionGroupId
- instructions (real, not template fillers)
- formCues
- commonMistakes

Quality bar: match `kettlebell_swing` / `goblet_squat`, not the seed template strings.

## Substitution groups

| Group | Change |
| --- | --- |
| `hip_hinge_pattern` | Add clean, snatch, deadlift, windmill, sumo DLHP |
| `quad_squat_pattern` | Add thruster |
| `single_leg_quad_glute` | Add goblet lunge |
| `back_horizontal_pull` | Add kettlebell row |
| `shoulder_vertical_push` | Add kettlebell press |
| `kettlebell_getup_complex` (new) | `turkish_get_up` only — do not swap for presses |
| `kettlebell_halo_mobility` (new) | `kettlebell_halo` only |

## Prescriptions

Defaults (goal × mechanics) apply unless overridden in `ExercisePrescriptionOverrides.json`:

| id | Override intent |
| --- | --- |
| `turkish_get_up` | Low reps (about 1–3 per side), longer rest |
| `kettlebell_halo` | Higher-rep / lighter RPE isolation |

No override required for the other nine unless implementation discovers a peer inconsistency.

## Videos

- Source public embeddable YouTube watch URLs for as many of the 11 as practical.
- Merge with `Scripts/merge_youtube_exercise_videos.py`.
- Regenerate `docs/exercise-video-handoff.md`.
- Unsourced ids may ship without demos; they remain on the Missing handoff list. Missing demos do not block seed + content.

## Generation / UI

No session or Today changes. New rows appear in the exercise library and become selectable by the generator when the athlete’s `availableEquipment` includes `kettlebell`.

## Verification

1. Catalog loads all 11 new ids with expected equipment, pattern, and mechanics.
2. Each new id has content + substitution group membership.
3. `YouTubeExerciseCatalogTests` pass for every linked URL.
4. `--report` reflects remaining Missing demos accurately.
5. App builds; library lists the new names when kettlebells are available.

## Follow-up

Off-day / home kettlebell circuit session type (e.g. 5 exercises × 5 reps × 5 rounds, rest between rounds) — separate design after this catalog lands.
