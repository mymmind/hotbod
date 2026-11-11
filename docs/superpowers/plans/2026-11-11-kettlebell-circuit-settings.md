# Kettlebell Circuit Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users configure kettlebell circuit exercises/reps/rounds/rests in Settings; new circuits and their rest timers honor those prefs without affecting gym days.

**Architecture:** Codable `KettlebellCircuitScheme` on `UserProfile` (defaults = current 5×5×5 / 15 / 60). Planner takes `scheme`. On circuit session start, snapshot scheme onto `WorkoutSession`. `SetAdvancePlanner.restSeconds` reads transition/round rest from that snapshot. Settings section appears only when equipment includes `.kettlebell`.

**Tech Stack:** SwiftUI, SwiftData/Codable models, XCTest, existing Settings draft pattern.

## Global Constraints

- iOS 26+ / SwiftUI / local-first MVP; no new backend dependency.
- Black/white brutalist Settings via existing `SettingsComponents`.
- Do not regenerate gym `todayWorkout` for scheme-only changes.
- Mid-session Settings edits must not alter active circuit rest.
- App must compile after each task.

---

### Task 1: Scheme model + Codable wiring

**Files:**
- Create: `HotBod/Domain/Models/KettlebellCircuitScheme.swift`
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`UserProfile`, `WorkoutSession`, `empty`/`realigned`/CodingKeys)
- Test: `HotBod/Tests/UnitTests/KettlebellCircuitSchemeTests.swift`
- Run `xcodegen generate` after adding the test file

**Steps:**

- [ ] **Step 1: Write failing tests** for `.default`, `clamped`, and decode-missing → default on a minimal profile JSON fixture if practical (or encode/decode round-trip with omitted key via custom decoder test).

- [ ] **Step 2: Implement** `KettlebellCircuitScheme` with allowed option sets, `default` from `GenerationConstants.KettlebellCircuit`, `clamped`.

- [ ] **Step 3: Wire** `UserProfile.kettlebellCircuitScheme` and optional `WorkoutSession.kettlebellCircuitScheme`; decodeIfPresent defaults.

- [ ] **Step 4: Tests PASS** + `xcodegen generate` if needed.

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Add kettlebell circuit scheme model on profile and session.

Persists discrete prefs with safe defaults for older profiles.
EOF
)"
```

---

### Task 2: Planner + generate

**Files:**
- Modify: `HotBod/Domain/Algorithms/KettlebellCircuitPlanner.swift`
- Modify: `HotBod/App/AppEnvironment+Workout.swift`
- Modify: `HotBod/Tests/UnitTests/KettlebellCircuitPlannerTests.swift`

**Steps:**

- [ ] **Step 1: Failing test** — plan with scheme exerciseCount=3, reps=4, rounds=6 asserts those values.

- [ ] **Step 2: Implement** `scheme:` parameter (default `.default`); use it for picks/sets/duration/rationale; stop reading hard-coded count/reps/rounds from constants except via scheme defaults.

- [ ] **Step 3: Pass** `profile.kettlebellCircuitScheme.clamped` from `generateKettlebellCircuit`.

- [ ] **Step 4: Tests PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Generate kettlebell circuits from the user's scheme prefs.

Planner and Today start path honor clamped profile settings.
EOF
)"
```

---

### Task 3: Rest helper + session snapshot

**Files:**
- Modify: `HotBod/Domain/Algorithms/CompleteSetRouter.swift` (`SetAdvancePlanner.restSeconds`)
- Modify: `HotBod/App/AppEnvironment+WorkoutSession.swift` (`resumeOrStartWorkout`)
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+ExerciseActions.swift`
- Modify: `HotBod/Tests/UnitTests/CompleteSetRouterTests.swift`
- Test: extend `KettlebellCircuitSessionTests` or add snapshot rest regression

**Steps:**

- [ ] **Step 1: Failing tests** — restSeconds with custom transition/round; gym path unchanged; session holds snapshot independent of later profile edits (environment-level if needed).

- [ ] **Step 2: Change** `restSeconds` to accept transition/round (or scheme); kettlebell next-round uses round rest; same-round uses transition.

- [ ] **Step 3: Snapshot** clamped profile scheme onto session when `sessionMode == .kettlebellCircuit`.

- [ ] **Step 4: Wire** ExerciseActions to pass session snapshot rests (fallback to defaults if nil).

- [ ] **Step 5: Tests PASS**

- [ ] **Step 6: Commit**

```bash
git commit -m "$(cat <<'EOF'
Snapshot kettlebell scheme onto sessions for stable rest timing.

Live rest reads the session copy, not live Settings edits.
EOF
)"
```

---

### Task 4: Settings UI + refresh exclusion

**Files:**
- Modify: `HotBod/Features/Settings/SettingsView.swift`
- Create or extend: `HotBod/Features/Settings/SettingsView+KettlebellCircuit.swift` (or SessionStructure)
- Modify: `HotBod/Features/Settings/SettingsDraftEditing.swift`
- Test: unit for `shouldRefreshWorkout` scheme-only false; UITest exemption comment on Settings UITests if needed

**Steps:**

- [ ] **Step 1: Ensure** `shouldRefreshWorkout` ignores scheme-only diffs (add unit assertion).

- [ ] **Step 2: Add** kettlebell-gated section with five `menuRow` pickers bound to `draft.kettlebellCircuitScheme`.

- [ ] **Step 3: Caption** about Today CTA / gym day isolation.

- [ ] **Step 4: Build** + unit tests PASS.

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Expose kettlebell circuit scheme pickers in Settings.

Shown only when kettlebells are in equipment; saves with profile.
EOF
)"
```

---

### Task 5: Verify

- [ ] Run `KettlebellCircuitSchemeTests`, `KettlebellCircuitPlannerTests`, `CompleteSetRouterTests`, `KettlebellCircuitSessionTests`, Settings draft unit coverage if added
- [ ] `xcodebuild build` for HotBod
- [ ] Merge to main / push when green

## Spec coverage

| Spec item | Task |
|-----------|------|
| Scheme model + Codable | 1 |
| Planner / generate | 2 |
| Snapshot + rest | 3 |
| Settings UI + no gym refresh | 4 |
| Verification | 5 |
