# HotBod — Training Intelligence Audit & Developer Fix Brief
**Audit date:** 13 October 2026  
**Source revision:** [`mymmind/hotbod` at `7022b8ca791c475c99a8272d804cab4c0c0a325f`](https://github.com/mymmind/hotbod/tree/7022b8ca791c475c99a8272d804cab4c0c0a325f) (`main` as inspected)  
**User data:** `hotbod-training-2026-10-13.md` (47 sessions, 28 July–13 October 2026)  
**Goal/profile:** hypertrophy, intermediate, PPL, 45-minute target, commercial gym, 7 days selectable.  
**Important:** This user regards RIR entries as dismiss-to-close responses, **not reliable effort observations**. All findings below based on sets, repetitions, weights and exercise choice avoid treating RIR or failure tags as valid training intensity signals.

## Executive verdict
HotBod is producing genuine progress in several lifts, but the inspected rules engine is **not adequately optimized for an efficient, balanced hypertrophy plan**. The main shortcomings are *not* a lack of exercise names. They are failure to maintain pattern/subregion coverage, unsafe coupling between historical suggestions and newly generated load calculations, weak handling of noisy effort feedback, and failure to budget optional finishers and warmups inside the promised session duration.

**Confidence classifications**  
- **Confirmed implementation fault/limitation:** directly present in the inspected `main` source.  
- **Observed training outcome:** directly derived from the user's export.  
- **Possible causal explanation:** code behavior aligns with logged outcome but no provenance of each workout (generated, manual, AI-adjusted, swapped) exists in the export. *Do not claim current source caused every historic workout.*  
- **Proposed product behavior:** recommendation that must be validated through tests/user outcomes, not described as proven physiological optimum.

## 1. Reproducible log audit
Counting convention: every logged non-`(wu)` set is counted as a working set, including core, carries, and nonhypertrophy work, unless an exercise is marked `skipped`. Set counts are **exposures, not proven stimulus-equivalent hard sets**. RIR, RPE, and `fail` flags are ignored. Lifts reported as per-hand cannot be compared numerically with total-load exercises. A single erroneous rep value is noted below.

| Metric | Result | Interpretation |
|---|---:|---|
| Sessions | **47** (19 push / 16 pull / 12 legs) | Unequal split exposure across the logged period, including gaps |
| Total working sets | **725** | Includes 4-set core finishers, carries, and other low-specificity work |
| Warmup sets | **474** | ~40% of all logged sets (474 of 1,199) are warmups |
| Actual session duration | Mean **56.7 min**; median **53 min**; 43–98 min | Target is 45 min; **44/47** sessions exceed it, **12/47** exceed 60 min |
| Recent 7 Sep–12 Oct window | **33** sessions, 465 working sets, 324 warmups | Consistent recent audit window: **7 Sep–12 Oct** (five weeks + one day) |
| Recent direct knee-flexion work | **0** leg curl sets | Leg curl appears just once in complete export, **3 sets on 7 Aug** |
| Recent loaded hinge work | **19** sets over 11 exposures | Mostly conventional/trap/sumo deadlifts; does **not** substitute for knee-flexion programming |
| Recent direct lateral raises | **2** sets | Compared with **22 overhead-press/landmine/Arnold sets** and **21 rear-delt/face-pull sets** |
| Recent chest pressing vs fly/pec-deck | **38 vs 31 sets** | Significant chest allocation, not inherently wrong but should be intentional |
| Recent curls | **38 sets** | More isolated elbow flexion than direct knee flexion by a wide margin |
| Recent core sets | **128** | **27.5% of all working sets** in recent window; ~4 sets/session |
| Recent calf sets | **26** | Repeated calf exposure, mostly same standing raise |
| Recent hip thrust / glute bridge | **0** sets | Not a requirement by itself; user receives hinge/squat/lunge glute work |
| Recent leg extension | **0** sets | Not a requirement by itself; quads receive squat, leg-press, and lunge work |

**Representative logged improvements, not proof of hypertrophy:** box squat 80 × 10 (15 Sep) → 100 × 10 (12 Oct); dumbbell bench press 28 × 8 (13 Sep) → 30 × 10 (13 Oct); lat pulldown 60 × 8 (11 Sep) → 70 × 10 (5 Oct); standing calf raise 165 × 10 (15 Sep) → 180 × 10 (13 Oct). Different training conditions may partly account for some differences; no body measurements are in this export. 

**Example muscle-distribution problem:** 12 October leg session contains 1 box squat set, 1 sumo deadlift set, 1 walking lunge set, 2 calf sets, 3 farmer-carry sets and **4 bird-dog sets**. It supplies little direct knee-flexion work and substantial time for carries/core. The October 11 pull workout contains 1 chest-supported row, 1 chin-up, 1 front raise, 2 straight-arm pulldowns, 3 preacher curl, 4 cable crunch. Several single-set accessories weaken per-exercise progression and efficiency.

**Integrity flags:** 17 September hammer curl is exported as `22×83` on a working set, almost certainly a typo or malformed rep entry. Planks correctly log time (`45s`); rep-based e1RM must never be applied to them. Chin-ups with `0` kg external load are *not* zero total resistance. Exported `trend Increasing/Decreasing` is not a direct normalized strength trend (see code issue P1-4).

### Methodological caveats
The log doesn't say which exercises were auto-generated, manually added, or swapped; it also doesn't include target-vs-completed plan snapshots. Some observations (e.g., frequent farmer carries on legs or front raises on pull) would **not** be chosen under the inspected generator's current PPL primary-muscle filter, which is evidence that user choices, historical versions, substitutions or other paths may have participated. Do not misattribute those to the current default selector without generator decision logs.

## 2. Priority fixes (confirmed or strongly supported by code)

### P0-1 — Prevent a *second* load progression on an already-suggested weight [CONFIRMED CODE PATH]
**Files:** [`DomainModels.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Models/DomainModels.swift#L807-L815), [`Algorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/Algorithms.swift#L503-L580), [`WorkoutGenerationService.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift#L596-L627).

`updateStats` calculates and stores `suggestedNextWeightKg`. `UserExerciseStats.planningWeightKg` returns **suggestedNextWeightKg first**, else lastWeightKg. Normal workout generation passes that value into `ProgressiveOverload.nextWeight` *again*. In neutral/positive volume-trend branches it may add another increment before a new set has been completed. Unlike this path, `SessionExercisePlanner.makeWorkoutExercise` uses `planningWeightKg` directly. This creates two competing load-planning semantics.

**Fix:** Establish a single progression boundary. Once performance has been evaluated into `suggestedNextWeightKg`, the session planner should use it unchanged (apart from explicit deload, recovery, return-from-break, equipment increments and ceilings). Alternatively, calculate progression only at generation time *from last successful work*, never both. Progression must be **idempotent across app refreshes/regenerations**.

**Acceptance:** Given last completed 65 kg × target reps and an existing suggestion of 67.5 kg, generating the workout repeatedly must not silently advance 67.5 → 70/72.5 without intervening logged work. Unit tests for `.stable`, `.increasing`, `.decreasing`, deload, and all equipment increment modes. Generated and manually added exercises should share identical progression semantics.

### P0-2 — Stop trusting incidental RIR input as ground truth [CONFIRMED CODE PATH + USER INPUT]
**Files:** [`EffortFeedbackMapping.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/EffortFeedbackMapping.swift#L17-L35), [`Algorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/Algorithms.swift#L133-L139), [`Phase2Algorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/Phase2Algorithms.swift#L432-L444).

`effectiveRPE` gives RIR priority over RPE, then uses that result to adjust progression and to trigger mild deload recommendation. The user's RIR taps are sometimes made to dismiss the popup; they should be treated as **missing**, not RIR=0/RPE10. RIR and RPE also sometimes conflict in the export.

**Fix:** Add `effortFeedbackStatus` (`explicit`, `skipped`, `legacy/unknown`) to completed sets. Only explicit submissions count. Offer a *Skip / not sure* control; default to null with no inferred RPE/RIR; provide a profile opt-out from prompting. Do not infer failure from dismissing the sheet. For legacy data, disable effort-dependent progression for users selecting "my historic effort entries are unreliable", without discarding genuine rep/load data. Use reps + weight + plan adherence as the robust default signal.

**Acceptance:** Auto-dismiss / Skip causes no stored effort and no effort-triggered deload or load change. Logged mismatched RPE/RIR does not overwrite an explicit skip. Retroactive data-quality switch leaves weight/reps progression intact.

### P0-3 — Enforce actual 45-minute duration *after* every optional block [CONFIRMED CODE PATH + OBSERVED OUTCOME]
**Files:** [`WorkoutGenerationService.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift#L251-L303), [`WorkoutGenerationAlgorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift), [`CoreFinisherPlanner.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/CoreFinisherPlanner.swift#L200-L269), [`GenerationConstants.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/GenerationConstants.swift#L192-L243).

`trimToDuration` operates **before** cardio, core finisher and cooldown are appended. The core finisher is fixed at 4 sets for intermediate trainees, with rest 30 seconds. Warmups can be 2–3 sets per loaded exercise. The trim routine removes **only redundant isolation exercises**, never shortens optional finishers or consolidates warmup ramps. Its threshold allows 10% over target; validator only *warns* at >20 minutes above target.

**Fix:** Build candidate full sessions (including core, warming up, transition time, cooldown, grouping) and perform global feasibility + cost-aware optimization against a configurable **hard/soft** duration budget. Protect priority main sets; remove/reduce redundant warmups, optional core, duplicate accessories, and unnecessary transitions first. Make 45 minutes realistic rather than a cosmetic preference. Explain projected overrun when necessary, and offer one-tap "shorten this workout". If warmups are included, only first demanding lift generally needs the full ramp; use lightweight exercise-specific ramp as appropriate.

**Acceptance:** Benchmark 45-min PPL fixtures with warmups/core enabled: estimated duration within 45 min or a clearly surfaced, user-approved exception; generator still preserves major target muscle/pattern coverage. Never append 4 core sets to an already-full session without reallocating time. Record *planned vs actual* durations and tune model from measured sessions.

### P1-1 — Program pattern/subregion coverage rather than name-level variety [CONFIRMED DESIGN GAP + OBSERVED OUTCOME]
**Files:** [`WorkoutGenerationAlgorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift), [`TrainingSchedule.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/TrainingSchedule.swift#L146-L154), [`ExerciseSeed.json`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Resources/ExerciseSeed.json).

Current selector covers **muscle labels** and discourages duplicate **generic compound movement patterns**. It has no rolling-window requirements for distinct muscle functions: knee flexion vs hip hinge, lateral-delt abduction vs pressing, horizontal vs vertical pull, or exercise slots by target region. Its "uncoveredMuscles" warning checks *whether the ranked candidate catalog contains a muscle*, not whether **selected exercises** actually cover it. PPL split targets omit abductors, adductors, obliques and several smaller muscle labels as direct targets. The catalog contains leg curls, hip adduction/abduction, and other needed options, so absence is not explained by lack of exercises.

**Fix:** Add a curated, non-exclusive `stimulusTags` model per exercise (e.g. `kneeFlexion`, `hipHinge`, `kneeExtension`, `hipExtension`, `horizontalPress`, `verticalPress`, `horizontalRow`, `verticalPull`, `shoulderAbduction`, `rearDelt`, `elbowFlexion`, `elbowExtension`, `plantarFlexion`). Some movements may have multiple roles; tag quality matters more than tag count. Create weekly/rolling-14-day coverage targets and minimums for movement functions, within user preference/equipment constraints. Do not rigidly enforce every accessory in every workout. Reserve slots for unmet high-priority movement functions before filling by weighted score. Avoid pathological replacement of mechanically different exercises merely because their primary muscle matches. Missing selected coverage should show an explicit warning with reason.

**Acceptance:** Two consecutive leg days with machines available include at least one reasonable direct knee-flexion option **within the programming microcycle** unless disabled/injured; if a hip hinge is already present, that does not satisfy the knee-flexion slot. Across a normal microcycle, shoulders have dedicated lateral-delt stimulus when desired. The `uncovered` calculation reflects the selected plan, not catalog availability. If a movement cannot be trained because of equipment, expose why rather than silently substituting the wrong pattern.

### P1-2 — Replace "any 1 set per chosen exercise" with marginal-stimulus set allocation [CONFIRMED DESIGN GAP]
**Files:** [`MuscleVolumePlanner.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/MuscleVolumePlanner.swift), [`GenerationConstants.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/GenerationConstants.swift#L35-L65), [`WorkoutValidator.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Services/WorkoutGeneration/WorkoutValidator.swift#L190-L227).

`allocateSessionSetCounts` starts every selected exercise at one set and caps allocated sets by the **minimum remaining budget across all primary muscles**; if weekly budget is zero, it still assigns one set per exercise. Each working set receives +1 per primary muscle and +0.5 per secondary regardless of variation, biomechanics, rep execution and limiting tissue. Excess projected volume only emits warnings. This creates many one-set exposures and conflates nominal anatomy labels with useful hypertrophy dose.

**Fix:** Allocate session-level set budget *before selecting final exercises*. Distinguish primary/local and accessory stimulus with exercise-specific fractional coefficients and movement-function constraints; store as **approximate accounting model**, not scientific truth. Permit 0 sets/drop an optional exercise when marginal benefit low. Favor 2–3 meaningful working sets on prioritized moves instead of scattering nine isolated one-set appearances. Preserve minimum clinically/biomechanically appropriate variety; cap weekly target muscle volume using both primary and indirect stimulus estimates. Let user specify muscle emphasis.

**Acceptance:** No workout contains zero-value one-set filler simply to reach minimum exercise count. A depleted biceps budget plus adequate pulling work shouldn't require additional biceps curls. The selected plan complies with configured volume ranges or explicitly reports a reason and an actionable adjustment.

### P1-3 — Separate *exercise-specific load accuracy* from useful variation transfer [CONFIRMED DESIGN GAP]
**Files:** [`WorkoutGenerationService.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift#L563-L625), [`Algorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/Algorithms.swift#L583-L612), [`ExerciseCatalog.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/ExerciseCatalog.swift), [`ExerciseMetadataResolver.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Models/ExerciseMetadataResolver.swift).

Main workout planning looks up performance **by exact exercise ID**. No documented load bridge transfers within exercise variation families; unseen exercises fall back to crude bodyweight × broad movement-pattern coefficients or flat fallback weights. Substitution groups exist for swaps, but are not used to calibrate candidate load. This is safer than naively equating two machine stacks, but can misprescribe new variants and lose useful knowledge. Current load rounding uses **2 kg** dumbbell steps and **2.5 kg** for barbells/cables/machines by category, without gym-specific stack sizes. Rep-based e1RM uses the **last working set** (not best credible performance), and is inapplicable to non-rep modalities; its display should not be used to compare fundamentally different exercises.

**Fix:** Keep history per exact exercise as the gold standard. When a new variation is introduced, create an **uncertain first-load estimate** from exercise family/force type, equipment, per-hand vs total semantics, bodyweight + external load, repetition range and compatible prior performances. Do not transfer raw kg 1:1 between cable stacks, machines, flat and incline presses, or unilateral/bilateral moves. Use user-selectable equipment increments and one calibration set with rep outcome to correct; expose confidence. Use robust top credible sets and minimum sample sizes for e1RM. Maintain a stable anchor lift for each major movement family so fresh variations don't erase comparable long-term progression data.

**Acceptance:** Bench 65 kg must not imply incline DB press 65 kg per hand; a new machine variant gets a conservative calibration prompt, not a false precision. Persisted new-exercise load remains stable across regeneration absent new performed sets. Bodyweight pull-up progression includes bodyweight and external load distinctly. Cable stacks respect configured increments.

### P1-4 — Stop presenting weekly rep-volume trend as a strength trend or 12-week history [CONFIRMED CODE PATH]
**Files:** [`Algorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/Algorithms.swift#L209-L303), [`TrainingDataMarkdownExporter.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/TrainingDataMarkdownExporter.swift), [`GenerationConstants.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/GenerationConstants.swift#L43-L45).

`weeklyVolumeHistory` is actually **total reps across each rolling 7-day bin**, and `computeTrend` calls >10% rep-volume changes "Increasing", <-10% "Decreasing". This trend then influences load generation. `recentSets` is pruned to **14 days / 64 sets**, so the intended 12-week `weeklyVolume` history cannot be reliably recalculated from this short cache. Changing session frequency or set counts can change the trend without any increase or decrease in strength. `stalledSessionCount` scores *weight × reps*, also sensitive to the number of sets and missing bodyweight load.

**Fix:** Persist durable aggregates by session/exercise: actual top set, credible e1RM, reps at reference load, completed working sets, volume load, rep-volume, and period labels. Use distinct public terms: "Strength trend", "Repetition volume trend", "Weekly hard sets", "Adherence". Never use weekly rep counts as a proxy for performance without additional evidence. Keep caches for fast UX but separately retain summaries across at least 12 weeks, robust to training gaps.

**Acceptance:** 3 sets of 8 becoming 2 sets of 10 at same weight does not show a fabricated negative strength trend; missing a week doesn't erase historic summaries; weekly comparisons use consistent windows and equivalent set definitions. Protect against 83-rep anomaly entering best-lift estimates.

### P2-1 — Exercise variability should rotate *within planned roles*, not randomly across unrelated stimulus [CONFIRMED DESIGN GAP]
**Files:** [`WorkoutGenerationAlgorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/WorkoutGenerationAlgorithms.swift), [`ExerciseGroupPlanner.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/ExerciseGroupPlanner.swift), [`AppEnvironment+Workout.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/App/AppEnvironment+Workout.swift#L338-L361).

The `balanced`/`varied` setting mostly adds score **jitter**, ±1.5 scaled by variability. Recent-use penalties operate only on the **exact exercise ID** within 3/7 days. Stalling in one exercise can exclude its ID and turn the **whole workout** into `.varied` because `stats.contains(where: \.preferVariation)` flips the global setting. There are no persistent 4–8-week anchor blocks, slots or movement coverage guardrails.

**Fix:** Maintain 1–2 compound anchors per workout type for a selectable 4–8-week block (not a universal rigid rule). Rotate optional accessories within compatible stimulus role and prevent churn that reduces analyzable exercise exposure. Stall handling should first assess data sufficiency, total set changes, load increments, form, recovery, then optionally rotate **only the stalled slot**. Expose the choice explanation (e.g. "you haven't trained knee flexion this microcycle") and distinguish automatic selection from user-added movements.

**Acceptance:** A plateau in one curl does not randomize squat and bench variations. Turning variety up changes accessory choices without sacrificing coverage or anchor continuity. Same fixed random seed and same training state give reproducible plans; diversity is assessed over rolling weeks, not just one session.

### P2-2 — Correct workout provenance and data-entry validation [OBSERVED LOG AMBIGUITY]
**Files:** [`TrainingDataMarkdownExporter.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/TrainingDataMarkdownExporter.swift), [`WorkoutSessionView+Metrics.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Features/WorkoutSession/WorkoutSessionView+Metrics.swift).

The export lacks per-exercise source (`generated`, `user-added`, `swapped`, `AI-modified`), original target sets vs actual sets, generated estimate, selection rationale/score, decision inputs, and true completion state. It cannot establish whether odd exercises were the algorithm's responsibility. One `22×83` hammer curl illustrates lack of detection at export time.

**Fix:** Add optional audit-safe diagnostic export for at least 8 weeks, including generator revision, input profile, selected exercise ID, slot/stimulus roles, selection score and rationale, planned/actual sets/weights, replacement provenance, elapsed times, load-decision reason, fatigue/readiness and data-confidence flags. Sanity check set reps (e.g. prompt to confirm 83 reps on a heavy curl), load jumps, duplicate/unfinished sessions, weighted-bodyweight semantics, time vs reps.

**Acceptance:** Developer can reconstruct each session's reasoning without PII or raw health signals, identify manual vs generated exercises, and detect implausible values without deleting genuine unusual performances.

### P2-3 — Recovery and deload must be calibrated, not asserted as precise muscle biology [CONFIRMED MODEL SIMPLIFICATION]
**Files:** [`MuscleRecoveryState.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Models/MuscleRecoveryState.swift), [`Algorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/Algorithms.swift#L53-L149), [`Phase2Algorithms.swift`](https://github.com/mymmind/hotbod/blob/7022b8ca791c475c99a8272d804cab4c0c0a325f/HotBod/Domain/Algorithms/Phase2Algorithms.swift#L358-L476).

Readiness is `clamp(100 + fitness - fatigue)` with fixed set-level coefficients and time decay. RPE/RIR modifies fatigue; logged effort is unreliable for this user. It can show 100% despite nontrivial recent work because 100 is a model cap, not an independent physical measurement. A 30% drop in *observed set volume* can trigger "deload in progress" although the user may just have a schedule change.

**Fix:** Label readiness as *estimated*, use broader recent workload and personal exercise response, avoid numerical false precision, include rest/subjective soreness/actual performance as confidence-gated signals. Only schedule a deload when there's evidence of sustained overload, strain or actual declining capacity rather than missing workouts or noisy RIR. Make recommended rest day actionable for a seven-days-available schedule. Do not assume every available weekday is an instruction to train daily.

**Acceptance:** 7-day availability alone does not force seven consecutive hypertrophy sessions; low-confidence/no-RIR histories still produce sensible training; absence of new set data cannot by itself demand a deload; unsupported 100% recovery is not communicated as a proven physiological state.

## 3. Proposed programming engine (product specification)

**1. State:** Maintain a rolling microcycle including actual completed working sets, estimated indirect contributions, stimulus-function coverage, anchors and preferences. Include deliberate uncertainty (unknown effort, machine conversion, manually added work). 

**2. Priorities:** First satisfy injury/equipment/goal hard constraints; second identify undersupplied *movement functions*, important regional muscle targets and protected main lifts; third allocate working-set and time budget; fourth choose specific compatible exercises; fifth assign load from exact-exercise history with optional conservative calibration from similar exercises; sixth add optional warmup/core/conditioning only if total budget permits; finally validate *selected* actual coverage and volume.

**3. Variety:** Maintain major compound anchors 4–8 weeks when practical; vary complementary accessories as needed and upon informed preference. Allow variety levels to affect substitution freedom, not total loss of continuity. Similar exercise names aren't enough to infer equal muscle function or load.

**4. Template defaults for this user's 45-min PPL sessions (starting point, not universal medical/physiological mandate):**

| Session | Core slots | Typical working sets budget | Optional |
|---|---|---|---|
| Push A/B | 1 chest press, 1 shoulder press OR lateral raise, 1 chest/side-delt accessory, 1 triceps | ~9–14 sets spread across chosen moves | 0–2 short core sets if time remains |
| Pull A/B | 1 row, 1 vertical pull, rear-delt OR lat accessory, 1 curl | ~9–14 sets | 0–2 short core sets if time remains |
| Legs A/B | squat/leg press, hip hinge, **leg curl** across A/B, unilateral quad or knee extension, calves as needed | ~10–14 sets | carries/core only if within time budget |

Notes: No blanket requirement to use leg curls in *every* session, to fix an arbitrary weekly volume, or to copy kg from another exercise. Hamstrings require both knee-flexion and hip-extension consideration if the goal is balanced hypertrophy. Shoulder abduction deserves dedicated programming if lateral delts are a target. Modify based on equipment, user preference, discomfort, training frequency, session quality and feedback.

**5. Transparent progress signals:** `last exposure`, `planned load`, `calibrated load`, `successful rep improvement`, `estimated strength trend with confidence`, `completed sets per muscle / role`, `gaps in coverage`, and `planned vs actual minutes` — separated and user understandable.

## 4. Required regression test matrix

1. **Idempotent progression:** saved suggestion consumed once; creating/regenerating identical workout never increases prescribed load; test stable/increasing trend and fatigue override.
2. **Untrusted RIR:** skipped/default RIR doesn't affect progress/deload; retained historical RIR can be explicitly untrusted; rep-and-load still work.
3. **45-min full budget:** warmup + core + cooldown included before final trim. No hidden finishers beyond time. For hard constraints, surface exception rather than lying about estimate.
4. **Two-leg-day knee-flexion coverage:** with an available leg curl and no injury/avoidance, at least one selected within configured microcycle; hip hinge isn't falsely counted as the same movement function.
5. **Delt balancing:** lateral abduction cannot be repeatedly omitted solely because vertical pressing and front raises exist; selection reason is available.
6. **No filler sets:** depleted weekly budgets can drop accessories, reallocating time to undertrained functions or allowing shorter sessions.
7. **Exhausted budget/missing selected coverage:** `uncovered` checks final plan; warnings reflect actually selected exercise count and roles.
8. **Family load transfer:** per-hand, total, assisted/bodyweight and machine-specific constraints; avoid raw kg copy; first calibration conservative and user-confirmable.
9. **No fake trend:** reduced total sets at stable top-set performance doesn't say declining strength. Historic weeks survive 14-day recent-set pruning.
10. **Rep sanity:** detect `22 × 83` curl without silently autocorrecting valid endurance work; exclude invalid/anomalous data from trend estimates until confirmed.
11. **Manual vs generated attribution:** same completed log exports source/provenance and before/after prescription; trace previous version or user overrides.
12. **Deterministic simulation:** simulate 8 weeks for 20, 30, 45, 60-min modes, 3–7 availability days, equipment constraints, low/no effort signal, one stall, one missed session, optional core, 3 levels of variety. Enforce coverage, load stability and duration; report distributions rather than just test `isValid`.

## 5. Delivery phases / definition of done

**Release 1 — correctness patch (P0):** resolve double progression; neutral handling of missing RIR; duration budget includes all blocks. Add tests and log a before/after controlled scenario. No major UI redesign required beyond skip effort and truthful duration explanation.

**Release 2 — intelligence engine (P1):** implement structured movement/stimulus tags; redesigned session/weekly allocation; measured specific-exercise progression + uncertain family calibration; durable multiweek metrics. Run retrospective simulation with this user's log and a synthetic standard user cohort. Ensure minimum reasonable variety and no body-part gaps.

**Release 3 — personalization and observability (P2):** deliberate exercise blocks, provenance export, data sanity, readiness calibration; monitor user-facing metrics over weeks. Measure outcomes by execution and adherence, not algorithm score alone.

**Definition of done:** For a representative 45-minute intermediate PPL setup, generated sessions (a) fit the duration or clearly explain a tradeoff, (b) provide nonzero meaningful coverage of critical movement functions within a microcycle, (c) never increase loads twice per completed performance, (d) do not let skipped RIR drive load/deload, (e) show credible per-exercise progress, and (f) expose why an exercise was chosen or replaced. Existing completion, syncing, and user edit flows must remain functional.

## 6. Evidence / reading

- Export `hotbod-training-2026-10-13.md`, generated 13 Oct. Log values in this brief are calculated from it; no RIR/RPE weighting.
- Code snapshot: linked source files at inspected commit above; **static review**, not an executed iOS test run.
- Brad Schoenfeld, *Science and Development of Muscle Hypertrophy*, 2nd ed., ch. 4 (volume, frequency, exercise selection), ch. 8 (exercise selection strategies/program design). Text argues for exercise variety **alongside** preserving complex movement patterns and training both multi- and single-joint movements; offers ~10–20 hard sets per muscle/week as a general adjustable guideline, not a mandatory one-size-fits-all prescription.
- Verkhoshansky & Siff, *Supertraining*, 6th ed., especially specificity, adaptation, periodization, load management. More sports-strength focused than hypertrophy-specific, so do not use its periodization concepts as proof a particular bodybuilding split is optimal.
- *NSCA's Essentials of Training Special Populations* (uploaded EPUB): background resource, not a primary basis for this intermediate healthy-lifter diagnosis.

**Bottom line:** Preserve HotBod's meaningful progress and good equipment/rotation infrastructure. Stop randomizing movement functions, overallocating time to optional work, and relying on false-precision progression/recovery. Fix the model before polishing more exercise variety UI.
