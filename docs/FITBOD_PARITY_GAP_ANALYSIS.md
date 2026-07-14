# HotBod vs. Fitbod — Missing Functionality Dev Doc

**Date:** 2026-07-13
**Status:** ✅ **Parity build complete** (2026-07-13) — all P0–P3 items implemented or explicitly deferred below.
**Purpose:** Translate the attached Fitbod deep-research report into a concrete build list for HotBod. Every gap below was verified against the current HotBod codebase (not assumed) — each entry states exactly what exists today, with file references, so nothing is "rebuilt" that's already there.
**Companion doc:** see [`FUNCTIONALITY_AUDIT_2026-07.md`](FUNCTIONALITY_AUDIT_2026-07.md) for bugs in *existing* functionality. This doc is about functionality that doesn't exist yet.

---

## How to read this doc

For each feature area: **Fitbod does** (from the research report) → **HotBod has today** (verified in code) → **Gap** → **Suggested approach** → **Priority** → **Status**.

Priority is about user-facing impact for a strength app, not effort:
- **P0** — core loop feature power users will notice missing immediately (workout structure, logging fidelity).
- **P1** — meaningfully improves personalization or trust.
- **P2** — real feature, smaller audience or lower frequency of use.
- **P3** — platform/compliance hygiene, not a training feature.

---

## Feature parity matrix

| Area | Fitbod | HotBod today | Priority | Status |
|---|---|---|---|---|
| Adaptive workout generation | ✅ Exercise Selector + Capability Recommender | ✅ Equivalent exists (`WorkoutGenerationService`, `Phase2Algorithms`) | — | ✅ |
| Muscle recovery tracking | ✅ | ✅ (`RecoveryCalculator`, per-muscle state) | — | ✅ |
| Progressive overload | ✅ | ✅ (`ProgressiveOverload` in `Algorithms.swift`) | — | ✅ |
| Equipment-aware selection | ✅ | ✅ (`Equipment` enum, `EquipmentFilter`) | — | ✅ |
| Exercise swap / edit / reorder | ✅ | ✅ (`SwapExerciseSheet`, `WorkoutPlanEditor`) | — | ✅ |
| Workout streaks | ✅ | ✅ (`TrainingStreakCalculator`) | — | ✅ |
| Supersets / circuits | ✅ | ✅ `groupId` on `PlannedExercise`/`WorkoutExercise`, `ExerciseGroupPlanner`, session group/ungroup | **P0** | ✅ |
| Timed intervals | ✅ | ❌ Deferred — needs block model (shared with future interval placement) | P2 | ⏸️ Deferred |
| Cardio block placement | ✅ | ✅ `CardioBlockPlacement` + `SessionStructurePlanner` | P2 | ✅ |
| Cooldown | ✅ | ✅ `includeCooldown` + `CooldownSetPlanner` | P2 | ✅ |
| Exercise variability control | ✅ (user-facing slider) | ✅ `ExerciseVariabilityLevel` on `UserProfile`, Settings UI | P1 | ✅ |
| Custom exercise creation | ✅ | ✅ `CreateExerciseView`, `isCustom`, `createCustomExercise` | P1 | ✅ |
| Persistent "recommend less / never show" | ✅ (more/less/exclude) | ✅ `ExercisePreference` (`.excluded`, `.less`, `.neutral`, `.favorite`) | **P0** | ✅ |
| Logged RiR/RPE feeding future recommendations | ✅ | ✅ `CompletedSet.rpe`, `ForgeRPEPicker`, `ProgressiveOverload` + `DeloadDetector` | **P0** | ✅ |
| Max Effort / AMRAP recalibration | ✅ | ✅ `PlannedSet.isMaxEffort`, `MaxEffortPlanner` | P1 | ✅ |
| Strength Score (per-muscle) | ✅ | ✅ `StrengthHistory.muscleGroupScores`, Progress dashboard card | P1 | ✅ |
| Equipment max-load ceilings (e.g. max dumbbell) | ✅ (user complaint area for Fitbod too) | ✅ `maxAvailableWeightKg`, `Weight.applyCeilings` | P2 | ✅ |
| Apple Watch companion | ✅ | ✅ `HotBodWatch` target + `AppGroupSessionStore` (embed disabled until watchOS SDK on CI) | P1 | ✅ Partial |
| HealthKit integration | ✅ | ✅ Read: `HealthKitReadinessService`; Write: `HealthKitWorkoutExportService` | P2/P3 | ✅ |
| Strava integration | ✅ | ⚠️ `StravaIntegrationService` protocol + Settings "Coming soon" stub | P3 | ⚠️ Stub |
| Offline-capable generation | ✅ (local algorithm) | ✅ Already fully on-device/local | — | ✅ |
| Account deletion (GDPR-style self-service) | ✅ | ✅ `SettingsView+Account.swift`, `AppEnvironment+Account.swift` | **P0** (compliance) | ✅ |
| Accessibility declarations / VoiceOver | ⚠️ Fitbod itself under-discloses this | ✅ Core component pass (`ForgeButton`, `ForgeRPEPicker`, `ForgeCard`, etc.) | P2 | ✅ |
| Localization | ⚠️ Fitbod: EN/PT/ES in-app | ✅ `Localizable.xcstrings` + `L10n` (foundation; migrate strings incrementally) | P3 | ✅ Foundation |
| Recommendation explainability ("why this exercise") | ⚠️ Fitbod itself flags this as a gap/roadmap item | ✅ `GeneratedWorkout.selectionRationale`, `WorkoutExplanationSheet` | P1 (differentiation opportunity) | ✅ |
| Employer/B2B tier | ✅ | N/A | Not recommended (see below) | — |
| Wear OS | ✅ | N/A (iOS-only app) | Not applicable | — |

---

## P0 — Core loop gaps

### 1. Supersets and circuits — ✅ Done
**Fitbod:** supersets (2 exercises back-to-back) and circuits (3+ exercises, minimal rest) can be toggled globally at generation time, or built manually mid-session by grouping exercises, normalizing weights across the group, duplicating, or unbundling.

**HotBod today:** `groupId: UUID?` on `PlannedExercise` and `WorkoutExercise` (`DomainModels.swift`). `ExerciseGroupingPreference` + `ExerciseGroupPlanner` apply supersets/circuits at generation (`WorkoutGenerationService.swift`). `preferredExerciseGrouping` in Settings. Session UI groups exercises with shared rest (`WorkoutSessionView.swift` — group/ungroup, `ExerciseGroupPlanner.restBeforeAdvancing`). Tests: `ExerciseGroupPlannerTests`.

### 2. Persistent negative exercise preference ("recommend less" / "never show") — ✅ Done
**Fitbod:** three-way feedback — recommend more, recommend less, exclude — persists and shapes all future generations.

**HotBod today:** `ExercisePreference` enum (`.excluded`, `.less`, `.neutral`, `.favorite`) on `Exercise` (`DomainModels.swift`). Persisted via `LocalExerciseRepository.updatePreference`. `.excluded` hard-filtered in generation; `.less` penalized in scoring (`ExerciseSubstitution`, `WorkoutGenerationAlgorithms`). Three-way control on `ExerciseDetailView.swift`.

### 3. Logged RPE/RiR actually feeding recommendations — ✅ Done
**Fitbod:** users log reps-in-reserve after sets; that signal directly adjusts future weight/rep targets.

**HotBod today:** `CompletedSet.rpe` captures logged effort. `ForgeRPEPicker` in `WorkoutSessionView.swift`. Logged RPE feeds `ProgressiveOverload.updateStats` / `nextWeight` and high-RPE deload detection in `DeloadDetector` (`Phase2Algorithms.swift`).

### 4. Account deletion (self-service) — ✅ Done
**Fitbod:** explicitly documented GDPR-compliant deletion — deleting the account permanently removes all associated data.

**HotBod today:** "Delete Account" / "Delete All Data" in `SettingsView+Account.swift` with confirmation dialog. Cascades through all repositories via `AppEnvironment+Account.deleteAccount()` plus Supabase `authService.deleteAccount()`. Tests: `AppEnvironmentOrchestrationTests`.

---

## P1 — Meaningfully improves personalization/trust

### 5. User-facing exercise variability control — ✅ Done
**HotBod today:** `ExerciseVariabilityLevel` on `UserProfile`, exposed in `SettingsView+Training.swift`, threaded into `WorkoutGenerationInput` as default (not only transient `preferVariation`).

### 6. Custom exercise creation — ✅ Done
**HotBod today:** `CreateExerciseView.swift`, library **+** button, `Exercise.isCustom`, `createCustomExercise` / `deleteCustomExercise` on repository + `AppEnvironment+Coach`. Custom exercises route through the same generation pipeline.

### 7. Max Effort Day / AMRAP recalibration — ✅ Done
**HotBod today:** `PlannedSet.isMaxEffort`, `UserExerciseStats.sessionsSinceMaxEffort` / `lastMaxEffortAt`, `MaxEffortPlanner.swift` (cadence every 5 sessions, e1RM recalibration). Session UI: "Max effort · AMRAP" badge.

### 8. Strength Score (surfaced, per-muscle-group) — ✅ Done
**HotBod today:** `StrengthHistory.muscleGroupScores` aggregates e1RM trends per `MuscleGroup`. Card in `ProgressDashboardView.swift`.

### 9. Recommendation explainability — ✅ Done
**HotBod today:** `GeneratedWorkout.selectionRationale: [String]` populated by `WorkoutSelectionRationale.swift` during generation. `WorkoutExplanationSheet` / rationale block in `WorkoutPreviewViews.swift`. Validator errors removed from `safetyNotes`.

### 10. Apple Watch companion — ✅ Partial
**HotBod today:** `HotBodWatch` target, `HotBodShared/AppGroupSessionStore.swift`, `PhoneWatchSessionBridge.swift`, minimal session UI (complete set, skip rest). Watch embed removed from `project.yml` until watchOS 26.5 simulator is available on CI — re-enable `embed: true` when SDK is installed.

---

## P2 — Real but lower-frequency/impact

### 11. Timed intervals, cardio block placement, cooldown — ✅ Partial (intervals deferred)
**HotBod today:**
- ✅ Cooldown: `includeCooldown` on `UserProfile`, `CooldownSetPlanner`, session UI cooldown sets.
- ✅ Cardio block: `CardioBlockPlacement` (Off/Start/End), `SessionStructurePlanner.applyCardioBlock`.
- ⏸️ Timed intervals: deferred — needs a "block" abstraction (shared with future interval placement throughout session).

### 12. Equipment max-load ceilings — ✅ Done
**HotBod today:** `maxAvailableWeightKg: [Equipment: Double]` on `UserProfile`. Settings → Equipment limits. `GenerationConstants.Weight.roundToAvailable` / `applyCeilings` wired through generation and swap replanning. Tests: `P2ParityFeatureTests`.

### 13. Accessibility (VoiceOver / Dynamic Type) — ✅ Done (core pass)
**HotBod today:** Incremental pass on `Core/Components/*` — `ForgeButton`, `ForgeRPEPicker`, `ForgeCard`, `ForgePill`, `ForgeSectionHeader`, `ForgeFloatingTabBar`, `ForgeSetMetricField` (labels, traits, selected states). App Store accessibility declaration still manual at submit time.

---

## P3 — Compliance/platform hygiene, not training features

### 14. Localization — ✅ Foundation
**HotBod today:** `HotBod/Resources/Localizable.xcstrings` + `L10n.swift`. Integration strings and workout-complete title migrated. Remaining hardcoded UI strings can migrate incrementally to the catalog.

### 15. Strava integration — ⚠️ Stub
**HotBod today:** `StravaIntegrationService` protocol + `NoOpStravaIntegrationService`. Settings shows "Strava — Coming soon". Full OAuth + activity upload requires credentials and token storage (future work).

### 16. HealthKit — extend, don't rebuild — ✅ Done
**HotBod today:** Read unchanged (`HealthKitReadinessService`). Write added: `HealthKitWorkoutExportService` saves completed sessions as traditional strength training workouts. `UserProfile.exportWorkoutsToHealthKit` toggle in Settings → Integrations. HealthKit entitlement + `NSHealthUpdateUsageDescription`. Tests: `P3ParityFeatureTests`.

---

## Not recommended

- **Employer/B2B licensing tier** — a monetization/sales-channel feature, not app functionality; irrelevant unless there's an explicit business decision to pursue B2B distribution.
- **Wear OS** — HotBod is an iOS-only codebase (confirmed: no Android project, no Kotlin/Java source anywhere in the repo). Not applicable unless there's a decision to build a separate Android app.
- **Copying Fitbod's SKU/legacy-pricing sprawl** — the research report flags Fitbod's own store listings as confusingly inconsistent (multiple legacy price points coexisting). Nothing to replicate here; if anything, HotBod should actively avoid this pattern when its own pricing evolves.

---

## Build order (completed)

1. **P0** — account deletion → exercise preference → logged RPE → supersets/circuits ✅
2. **P1** — variability, strength score, custom exercises, max effort, explainability, Watch (partial) ✅
3. **P2** — cooldown, cardio blocks, equipment ceilings, accessibility ✅ (timed intervals deferred)
4. **P3** — HealthKit write, localization foundation, Strava stub ✅

### Remaining follow-ups (outside this doc's scope)

- **Timed intervals** — implement when block model is introduced for session structure.
- **Strava OAuth + upload** — wire real credentials and backend token storage.
- **Watch embed** — re-enable in `project.yml` when watchOS SDK available on build machines.
- **Localization** — migrate remaining hardcoded strings to `Localizable.xcstrings`.
- **App Store accessibility declaration** — file at submit time after VoiceOver QA pass on device.
