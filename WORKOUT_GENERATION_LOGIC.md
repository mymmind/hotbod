# HotBod — Exercise & Workout Generation Logic

This document describes how exercises enter the app and how daily workouts are built. It is intended for critique of the current rules engine, validation layer, and supporting algorithms.

**Primary source files:**

| Area | File |
|------|------|
| Rules engine | `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` |
| Validator | `HotBod/Services/WorkoutGeneration/WorkoutValidator.swift` |
| Orchestration | `HotBod/App/AppEnvironment.swift` |
| Split / schedule | `HotBod/Domain/Algorithms/TrainingSchedule.swift` |
| Recovery, overload | `HotBod/Domain/Algorithms/Algorithms.swift` |
| Muscle volume landings | `HotBod/Domain/Algorithms/MuscleVolumePlanner.swift` |
| Effort / progression | `HotBod/Domain/Algorithms/EffortPolicy.swift` |
| Deload / volume caps | `HotBod/Domain/Algorithms/Phase2Algorithms.swift` |
| Constants | `HotBod/Domain/Algorithms/GenerationConstants.swift` |
| Exercise catalog & swaps | `HotBod/Domain/Algorithms/ExerciseCatalog.swift` |
| Seed loading | `HotBod/Data/Local/ExerciseCatalogLoader.swift`, `LocalExerciseRepository.swift` |
| AI coach (optional) | `HotBod/Services/AI/GeminiAIWorkoutService.swift`, `RemoteAIWorkoutService.swift` |
| Server validation | `supabase/functions/_shared/validate.ts` |


---

## 1. High-level architecture

```mermaid
flowchart TD
    A[App bootstrap / Regenerate] --> B[AppEnvironment.generateWorkout]
    B --> C[Assemble WorkoutGenerationInput]
    C --> D[RulesWorkoutGenerationService.generate]
    D --> E[WorkoutValidator.validate]
    E -->|isValid| F[Save todayWorkout]
    E -->|errors| G[Reject — return nil]

    H[AI Coach] --> I[Gemini / Supabase edge]
    I --> J[AIWorkoutPayloadMapper]
    J --> K[applyAIWorkout]
    K --> E
```

**Key design choice:** The **rules engine** (`RulesWorkoutGenerationService`) owns the default daily plan. AI proposals are optional overlays that must pass the same client-side `WorkoutValidator` (plus server validation when using Supabase).

From `AppEnvironment`:

```5:8:HotBod/App/AppEnvironment.swift
    // Architecture: RulesWorkoutGenerationService owns the daily plan (bootstrap + regenerate).
    // Cloud coach (RemoteAIWorkoutService + Supabase edge) proposes changes; server + client
    // validation gate every apply. Safe modifyWorkout proposals auto-apply; generateWorkout and
    // failed validation keep the manual Apply flow. HealthKit sleep/resting HR inform readiness hints.
```

---

## 2. Exercises are not algorithmically generated

Exercises are **curated and seeded**, not invented at runtime.

### 2.1 Data sources

1. **`ExerciseSeed.json`** — canonical exercise list (~100+ entries): id, muscles, equipment, movement pattern, difficulty, instructions, seeded substitution links, demo videos.
2. **`ExerciseContent.json`** — overlays: substitution groups, aliases, extra instructions, explicit `substitutionGroupId`.

### 2.2 Merge pipeline

```3:8:HotBod/Data/Local/ExerciseCatalogLoader.swift
enum ExerciseCatalogLoader {
    static func loadExercises() -> [Exercise] {
        let seed = ExerciseSeedLoader.loadSeed()
        let content = loadContentBundle()
        return seed.map { merge($0, content: content.exercises[$0.id], groups: content.substitutionGroups) }
    }
```

Each seed exercise is converted via `ExerciseSeedDTO.toExercise()`. Notable: **`mechanics` and `forceType` are always `nil`** in the DTO mapper:

```120:131:HotBod/Data/Local/LocalExerciseRepository.swift
    func toExercise() -> Exercise {
        Exercise(
            id: id,
            name: name,
            ...
            forceType: nil,
            mechanics: nil,
            ...
        )
    }
```

If no `substitutionGroupId` is provided in content, one is auto-derived:

```4:7:HotBod/Domain/Algorithms/ExerciseCatalog.swift
    static func autoGroupId(for exercise: Exercise) -> String {
        let muscle = exercise.primaryMuscles.first?.rawValue ?? "general"
        return "\(muscle)_\(exercise.movementPattern.rawValue)"
    }
```

### 2.3 Example seed entry

```json
{
  "id": "bench_press",
  "name": "Bench Press",
  "primaryMuscles": ["chest"],
  "secondaryMuscles": ["shoulders", "triceps"],
  "equipment": ["barbell", "bench"],
  "movementPattern": "horizontalPush",
  "difficulty": "intermediate",
  "substitutions": ["dumbbell_press", "machine_chest_press", "push_up"]
}
```

### 2.4 User-driven exercise filtering

At runtime, exercises can be excluded via:

- `isAvoided` flag (user marked avoid in library)
- Equipment mismatch
- Injury / limitation movement-pattern blocklist
- `avoidExerciseIds` in generation options (used on regenerate for variation)

---

## 3. When workouts are generated

| Trigger | Behavior |
|---------|----------|
| App `bootstrap()` | On a training day, if no workout or workout is stale (not created today), calls `regenerateTodayWorkout` |
| User taps Regenerate | Excludes current exercise IDs, sets `preferVariation = true`; falls back without exclusions if validation fails |
| User switches split focus | Toggles `splitDayIndex`, regenerates with variation |
| Session completed | Advances split rotation, may pregenerate next day's workout |
| AI coach Apply | Runs same validator before saving |

Input assembly in `AppEnvironment.generateWorkout`:

```360:398:HotBod/App/AppEnvironment.swift
    private func generateWorkout(
        profile: UserProfile,
        splitDayFocus: SplitDayFocus,
        options: WorkoutGenerationOptions = WorkoutGenerationOptions()
    ) async -> GeneratedWorkout? {
        let summaries = (try? await workoutRepository.fetchSessionSummaries()) ?? []
        let stats = (try? await exerciseStatsRepository.fetchStats()) ?? []
        let recovery = Dictionary(uniqueKeysWithValues: recoveryStates.map { ($0.muscleGroup, $0.recoveryPercentage) })
        let soreness = options.soreness ?? sorenessLevel
        let duration = options.targetDurationMinutes ?? profile.preferredSessionLengthMinutes

        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: duration,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: profile.limitations,
            recentWorkouts: summaries,
            muscleRecovery: recovery,
            exerciseStats: stats,
            userPreferences: WorkoutPreferences(
                avoidExerciseIds: options.excludeExerciseIds,
                preferVariation: options.preferVariation
            ),
            readiness: ReadinessInput(
                sleepScore: healthReadiness.sleepScore,
                soreness: soreness
            ),
            splitDayFocus: splitDayFocus
        )

        guard let workout = try? await workoutGenerationService.generate(input: input) else { return nil }
        let validation = workoutGenerationService.validate(workout: input, input: input)
        lastValidation = validation
        guard validation.isValid else { return nil }
        return workout
    }
```

**Update note:** `preferredMuscleGroups` / `avoidedMuscleGroups` are now populated from profile and applied by the rules engine.

---

## 4. Rules engine pipeline (`RulesWorkoutGenerationService`)

### Step 1 — Filter available exercises

```7:13:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
        let allExercises = try await exerciseRepo.fetchAll()
        let available = allExercises.filter { exercise in
            !exercise.isAvoided &&
            exercise.equipment.allSatisfy { input.availableEquipment.contains($0) || $0 == .bodyweight } &&
            exercise.equipment.contains(where: { input.availableEquipment.contains($0) }) &&
            !violatesInjuries(exercise, injuries: input.injuries)
        }
```

**Equipment rule:** Every required piece must be available (bodyweight is always allowed). At least one equipment tag must match user inventory.

**Injury blocklist** (movement-pattern + contraindication text checks):

```184:196:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
    private func violatesInjuries(_ exercise: Exercise, injuries: [BodyLimitation]) -> Bool {
        guard !injuries.contains(.none) else { return false }
        let risky: [BodyLimitation: [MovementPattern]] = [
            .shoulder: [.verticalPush, .horizontalPush],
            .lowerBack: [.hinge, .squat],
            .knee: [.squat, .lunge]
        ]
        for injury in injuries {
            if let patterns = risky[injury], patterns.contains(exercise.movementPattern) {
                return true
            }
        }
        return false
    }
```

**Update note:** Elbow, wrist, hip, ankle, and neck are mapped in `GenerationConstants`, and contraindication text contributes to exclusion.

---

### Step 2 — Select target muscles (`selectTargetMuscles`)

Logic branches:

#### A. Soreness penalty on recovery map

```99:104:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
        if input.readiness?.soreness == .severe {
            recovery = recovery.mapValues { max(0, $0 - 20) }
        } else if input.readiness?.soreness == .moderate {
            recovery = recovery.mapValues { max(0, $0 - 10) }
        }
```

#### B. If split day focus is set (normal path)

Uses `TrainingSchedule.muscles(for:)`:

```52:60:HotBod/Domain/Algorithms/TrainingSchedule.swift
    static func muscles(for focus: SplitDayFocus) -> [MuscleGroup] {
        switch focus {
        case .upper: [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower: [.quads, .hamstrings, .glutes, .calves]
        case .push: [.chest, .shoulders, .triceps]
        case .pull: [.back, .biceps]
        case .legs: [.quads, .hamstrings, .glutes, .calves]
        case .fullBody: MuscleGroup.allCases
        }
    }
```

From those split muscles, pick up to 4 with recovery ≥ 40%, sorted by recovery %. If fewer than 2 qualify, fall back to top 4 by recovery regardless of threshold.

#### C. If no split focus (fallback)

1. Exclude muscles trained in last 2 workouts
2. Require recovery ≥ 50%
3. If ≥ 3 ready muscles:
   - For `upperLower` or `pushPullLegs`: compare average upper vs lower recovery, return top 3 from the fresher half
   - Else: top 4 ready muscles
4. Ultimate fallback: top 4 muscles by recovery across all groups

**Update notes:**
- `sleepScore` is used as a recovery penalty signal in generator sorting/intensity constraints.
- `preferredMuscleGroups` / `avoidedMuscleGroups` are applied during target and candidate selection.

---

### Step 3 — Select exercises (`selectExercises`)

**Exercise count from duration:**

```swift
let maxExercises = min(8, max(4, durationMinutes / 8))
// 32 min → 4 exercises, 45 min → 5, 60 min → 7, 64+ min → 8
```

**Scoring** (see `WorkoutGenerationAlgorithms.scoreExercises`):

- First matching primary muscle: `+10`
- Each additional matching primary: `+4` (same as secondary — avoids dual-primary domination)
- Each matching secondary: `+4`
- History familiarity: `+2` if any `UserExerciseStats` exist
- Favorite: `+3`; less-preferred: `-4`
- Beginner + advanced exercise: `-5`
- Recent use demotion: `-6` if last logged set < 3 days, `-3` if < 7 days

**Variation ranking** (regenerate / prefer variation / non-consistent variability):

Scored exercises get small score jitter (`±1.5` × variability multiplier), then sort descending. Deterministic when a `variationSeed` is supplied.

**Selection constraints:**

- From the **second** pick onward, duplicate **compound** movement patterns are skipped (`selected.count >= 1`). Isolation/cardio/mobility accessories may repeat.
- Must match at least one target primary muscle during coverage/fill.
- If still under the minimum exercise count, backfill from ranked list without pattern constraints.

---

### Step 4 — Plan sets, reps, weight, rest

For each selected exercise:

#### Rep ranges (goal + experience, overridden by history)

```207:212:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
    private func repRange(for goal: TrainingGoal, experience: ExperienceLevel) -> (Int, Int) {
        switch goal {
        case .gainStrength: (4, 6)
        case .loseFat: (12, 15)
        default: experience == .beginner ? (10, 12) : (8, 10)
        }
    }
```

If user has `UserExerciseStats` for the exercise, `preferredRepRangeMin/Max` from prior sessions win.

#### Set count

```215:217:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
    private func setCountFor(experience: ExperienceLevel, pattern: MovementPattern) -> Int {
        let base = experience == .beginner ? 2 : 3
        return [.squat, .hinge, .horizontalPush, .horizontalPull].contains(pattern) ? base + 1 : base
    }
```

#### Weight

- **With history:** `ProgressiveOverload.nextWeight` using `stats.planningWeightKg` (`suggestedNextWeightKg ?? lastWeightKg`)
- **Without history:** flat defaults by experience + barbell flag:

```199:204:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
    private func defaultWeight(for exercise: Exercise, experience: ExperienceLevel) -> Double {
        switch experience {
        case .beginner: exercise.equipment.contains(.barbell) ? 40 : 12
        case .intermediate: exercise.equipment.contains(.barbell) ? 60 : 20
        case .advanced: exercise.equipment.contains(.barbell) ? 80 : 28
        }
    }
```

**Note:** `ProgressiveOverload.suggestedStartWeight` (bodyweight × movement pattern × experience) exists in `Algorithms.swift` but is **not used** by the rules engine — only the flat defaults above.

#### Deload adjustment

```248:258:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
    private func deloadAdjustment(
        baseSetCount: Int,
        stats: UserExerciseStats?
    ) -> (intensity: IntensityTarget, setCount: Int) {
        guard let stats = stats, stats.isInDeloadWeek else {
            return (.moderate, baseSetCount)
        }
        let reducedSets = max(1, Int(Double(baseSetCount) * 0.6))
        return (.light, reducedSets)
    }
```

Weight is also reduced 10% in `ProgressiveOverload.nextWeight` when `isInDeloadWeek`.

#### Rest periods

```swift
restSeconds: exercise.mechanics == .compound ? 120 : 90
```

Because seeded exercises have `mechanics: nil`, this almost always resolves to **90s** unless mechanics are set elsewhere.

#### Every set gets RPE target 8

```60:61:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
                targetSets: (0..<adjustedSetCount).map { _ in
                    PlannedSet(targetRepsMin: minReps, targetRepsMax: maxReps, targetWeightKg: weight, rpeTarget: 8)
```

---

### Step 5 — Metadata

**Title** — from split focus, or inferred upper/lower/full, or PPL label:

```220:230:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
    private func workoutTitle(for muscles: [MuscleGroup], split: TrainingSplit, focus: SplitDayFocus?) -> String {
        if let focus {
            return "\(focus.displayName) Strength"
        }
        let lower = Set([MuscleGroup.quads, .hamstrings, .glutes, .calves])
        if muscles.allSatisfy({ lower.contains($0) }) { return "Lower Body Strength" }
        if muscles.allSatisfy({ !lower.contains($0) }) { return "Upper Body Strength" }
        switch split {
        case .pushPullLegs: return "Push Day Hypertrophy"
        default: return "Full Body Strength"
        }
    }
```

**Duration estimate:**

```233:236:HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
    private func estimateDuration(exercises: [PlannedExercise]) -> Int {
        let totalSets = exercises.reduce(0) { $0 + $1.targetSets.count }
        let restMinutes = exercises.reduce(0) { $0 + ($1.restSeconds * max(0, $1.targetSets.count - 1)) } / 60
        return totalSets * 2 + restMinutes + 5
    }
```

Assumes ~2 min per set (work time) + inter-set rest + 5 min buffer.

---

## 5. Progressive overload & volume tracking

Updated after each completed session via `ProgressiveOverload.updateStats` in `Algorithms.swift`.

### Per-muscle weekly landings (primary)

`MuscleVolumePlanner` owns programming volume:

- Each working set credits **1.0** to primary muscles and **0.5** to secondary muscles.
- Weekly landings (sets/muscle/week) by experience × goal (e.g. intermediate hypertrophy **14**, advanced **18**; strength lower).
- Soft ceiling **24** sets/muscle/week; global experience caps (70/100/130) are **warnings only**.
- Session set counts are allocated from remaining weekly budget per target muscle.

### Overload gate

Generation-time `ProgressiveOverload.nextWeight` keys off **muscle weekly completion fraction** vs landing. At ≥100% completion, load is held/reduced (`×0.95`).

### Effort & progression policy

- `EffortPolicy` sets role-aware RPE (hypertrophy ~8, strength compounds ~7.5, isolation finishers ~9, beginners/deload/poor sleep lower). Mid-session adds via `SessionExercisePlanner` use the same policy.
- `ProgressionPolicy` on `updateStats`:
  - hypertrophy double-progression: hold load and bump `preferredRepRangeMin` until top of range, then increase load
  - strength: load-first (hold until top, then increase)
  - stall (≥3 flat **sessions**, clustered by completion time) sets `UserExerciseStats.preferVariation`; next generate merges those IDs into avoid list and raises variability
- `recentSets` retain up to 14 days / 64 sets so weekly hard-set counts are not truncated at 12.

### Deload detection

`DeloadDetector` flags deload when:

1. Volume drops >30% week-over-week after a productive prior window, OR
2. **Scheduled volume wave** after **4** consecutive high-volume weeks, OR
3. 3 consecutive weeks with >15% volume increases, OR
4. Recent logged RPE averages ≥9.5

Deload week = `now - deloadStartedAt < 7 days`. Effects: sets ×0.6, weight ×0.9, RPE target 6.

---

## 6. Muscle recovery model (fitness–fatigue)

`MuscleRecoveryState` tracks:

- `fitness` — positive residual (decays ~**3×** slower than fatigue)
- `fatigue` — residual fatigue load
- `recoveryPercentage` (preparedness) = `clamp(100 + fitness - fatigue)` for UI/generation compatibility

### Passive decay

Fatigue decays at `experience.recoveryRatePerHour`; fitness at that rate ÷ 3.

### Workout stimulus

```
fatigue += sets × mechanics × contribution × effort(RPE) × 6
fitness += sets × mechanics × contribution × 2
```

Compounds cost more than isolation; higher logged RPE increases fatigue. Low preparedness (<40%) soft-shrinks planned sets before validation.

### Sleep score

HealthKit emits **0…1**; generation thresholds use **0…100**. Normalization: `score <= 1 ? score * 100 : score` at input assembly and in consumers.

### Soreness / manual readiness

Soreness adds fatigue (scoped to recently trained muscles). Optional `manualReadiness` applies a global fatigue offset before generation.

---

## 7. Validation (`WorkoutValidator`)

Validation runs **after** generation. Hard errors block the workout (`isValid = errors.isEmpty`).

### Hard errors (examples)

| Check | Threshold |
|-------|-----------|
| Exercise count | < 4 (standard) / < 3 (recovery) |
| Duplicate / unknown exercise IDs | any |
| Injury / equipment conflict | blocklist + contraindications |
| Rep / set / rest / weight bounds | see `GenerationConstants.Validation` |
| Per-muscle recovery | < 15% for targeted primary (standard mode) |
| Severe soreness / critical fatigue | errors in standard; warnings in recovery |

### Soft warnings

- Global weekly set guardrail / warning thresholds (no longer hard-fail)
- Per-muscle landing soft ceiling / high volume
- Moderate/mild soreness, low recovery (15–30%)
- Duration exceeds target + 20 min
- Large weight jumps

Recovery override UX exists for critical-fatigue-only failures (`generateLighterWorkoutAfterFatigue`).

---

## 8. Exercise substitution (swap, not generation)

When user swaps an exercise mid-session, `ExerciseCatalog.substitutes` ranks alternatives:

1. Same `substitutionGroupId` (from content or auto `muscle_pattern`)
2. Seeded `substitutions` links on the exercise
3. Algorithmic: same primary muscle overlap + same movement pattern, scored by:

```54:59:HotBod/Domain/Algorithms/Phase2Algorithms.swift
    static func scoreSubstitute(_ source: Exercise, _ candidate: Exercise) -> Double {
        var score = 0.0
        score += Double(Set(source.primaryMuscles).intersection(Set(candidate.primaryMuscles)).count) * 10
        score += source.movementPattern == candidate.movementPattern ? 5 : 0
        score += source.difficulty == candidate.difficulty ? 2 : 0
        return score
    }
```

Same equipment/injury filters as generation.

---

## 9. Training split rotation

```42:49:HotBod/Domain/Algorithms/TrainingSchedule.swift
    static func splitSequence(for split: TrainingSplit) -> [SplitDayFocus] {
        switch split {
        case .upperLower: [.upper, .lower]
        case .pushPullLegs: [.push, .pull, .legs]
        case .fullBody: [.fullBody]
        case .arnold: [.push, .pull, .legs]
        case .bodyPart, .custom, .adaptive: [.upper, .lower]
        }
    }
```

`splitDayIndex` advances after each completed session. `bodyPart`, `custom`, and `adaptive` splits currently behave like upper/lower.

---

## 10. AI generation path (secondary)

### Gemini (direct, if API key configured)

Prompt asks for JSON with 4–8 exercises. Exercise IDs use **hyphenated slugs** in the prompt (`"barbell-back-squat"`) but the seed catalog uses **underscores** (`bench_press`) — mapping depends on `AIWorkoutPayloadMapper`.

### Supabase cloud coach

Server system prompt restricts to `ALLOWED_EXERCISES` list and validates via `validate.ts` (simpler than client validator: no per-muscle recovery, no weekly volume projection).

AI workouts must pass `applyAIWorkout` → client `WorkoutValidator` before saving.

---

## 11. Known gaps & critique checklist

Use this section when reviewing the logic:

| Topic | Current behavior | Possible concern |
|-------|------------------|------------------|
| Exercise catalog | Static JSON seed | No runtime exercise creation; quality depends entirely on seed curation |
| `mechanics` | Seeded when available, inferred from movement pattern otherwise | Low risk; monitor coverage as seed expands |
| `preferredMuscleGroups` | Populated from profile | Confirm UX guidance so users understand bias behavior |
| `avoidedMuscleGroups` | Populated from profile | Ensure warning copy remains clear when override path triggers |
| `favoriteExerciseIds` | Applied in scoring bonus | Validate bonus weighting vs variation goals |
| Injury mapping | Pattern rules cover all current `BodyLimitation` values + contraindication text checks | Continue moving toward structured per-exercise contraindications |
| Sleep score | Normalized 0–1 → 0–100; poor sleep caps RPE/sets | Keep tuning thresholds as readiness data quality improves |
| Default weights | Uses movement-pattern and bodyweight-aware `suggestedStartWeight` | Track edge cases for missing bodyweight/equipment data |
| Exercise ordering | Compound-first after selection | Optional pre-fatigue remains open |
| Muscle coverage | Best-effort scoring | May under-train some target muscles |
| Variation shuffle | Random within score ties | Can feel arbitrary |
| Validator vs generator | Recovery mode + soft-shrink before validate | Critical fatigue still has recovery-override path |
| Weekly volume | Per-muscle landings + soft global guardrail | Tune landings per population; keep soft ceiling |
| PPL title | "Push Day Hypertrophy" even for strength goals | Naming mismatch |
| `bodyPart` / `custom` / `adaptive` splits | `bodyPart -> push/pull/legs`, `custom -> fullBody`, `adaptive -> dynamic focus` | Legacy-safe defaults now explicit; revisit when custom split builder ships |
| AI exercise IDs | Hyphen vs underscore risk | Potential validation failures for AI paths |

---

## 12. `WorkoutGenerationInput` reference

```399:414:HotBod/Domain/Models/DomainModels.swift
struct WorkoutGenerationInput: Codable {
    let userProfile: UserProfile
    let goal: TrainingGoal
    let experienceLevel: ExperienceLevel
    let availableEquipment: [Equipment]
    let targetDurationMinutes: Int
    let preferredMuscleGroups: [MuscleGroup]
    let avoidedMuscleGroups: [MuscleGroup]
    let injuries: [BodyLimitation]
    let recentWorkouts: [WorkoutSessionSummary]
    let muscleRecovery: [MuscleGroup: Double]
    let exerciseStats: [UserExerciseStats]
    let userPreferences: WorkoutPreferences
    let readiness: ReadinessInput?
    let splitDayFocus: SplitDayFocus?
}
```

---

## 13. Rules engine source

Generation: `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift`  
Validation: `HotBod/Services/WorkoutGeneration/WorkoutValidator.swift`

Unit tests: `HotBod/Tests/UnitTests/HotBodTests.swift` → `WorkoutGenerationTests`, `WorkoutValidator` tests, progressive overload tests.
