# Kettlebell Catalog Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 11 kettlebell exercises with real content, swap groups, selective prescriptions, and YouTube demos where available.

**Architecture:** Extend `ExerciseSeed.json` + `ExerciseContent.json` (including two new substitution groups). Add TGU/halo overrides. Merge YouTube URLs via the existing script. Add a focused unit test that asserts the new ids load with expected metadata.

**Tech Stack:** JSON catalogs, Swift XCTest, `Scripts/merge_youtube_exercise_videos.py`

**Spec:** `docs/superpowers/specs/2026-11-11-kettlebell-catalog-design.md`

## Global Constraints

- No new MovementPattern / Equipment enum cases.
- No circuit / off-day session logic.
- Goblet lunge equipment is kettlebell-only (`allSatisfy` filter).
- Missing demos do not block seed+content ship.
- Do not rewrite the four existing kettlebell entries unless required.
- Work in `.worktrees/kettlebell-catalog` on `feat/kettlebell-catalog`.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Resources/ExerciseSeed.json` | 11 new seed rows |
| `HotBod/Resources/ExerciseContent.json` | Groups + content blocks |
| `HotBod/Resources/ExercisePrescriptionOverrides.json` | TGU + halo |
| `HotBod/Resources/YouTubeExerciseVideos.json` | Demo URLs (via merge script) |
| `docs/exercise-video-handoff.md` | Regenerated report |
| `HotBod/Tests/UnitTests/KettlebellCatalogTests.swift` | Load/metadata assertions |

---

### Task 1: Failing catalog test

**Files:**
- Create: `HotBod/Tests/UnitTests/KettlebellCatalogTests.swift`

- [ ] **Step 1: Write failing test** asserting these ids exist with equipment containing `.kettlebell` and the patterns from the spec:  
  `kettlebell_clean`, `kettlebell_press`, `kettlebell_row`, `kettlebell_snatch`, `turkish_get_up`, `kettlebell_halo`, `kettlebell_windmill`, `kettlebell_thruster`, `kettlebell_goblet_lunge`, `kettlebell_deadlift`, `kettlebell_sumo_deadlift_high_pull`

- [ ] **Step 2: Run test — expect FAIL** (ids missing)

- [ ] **Step 3: Commit** `test: add kettlebell catalog coverage`

---

### Task 2: Seed + content + groups + prescriptions

**Files:**
- Modify: `ExerciseSeed.json`, `ExerciseContent.json`, `ExercisePrescriptionOverrides.json`

- [ ] **Step 1: Append 11 seed rows** matching the spec table (real instructions/cues/mistakes in seed; content overlay is source of truth for library copy)

- [ ] **Step 2: Update substitution groups** per spec; add `kettlebell_getup_complex` and `kettlebell_halo_mobility`

- [ ] **Step 3: Add content blocks** for all 11

- [ ] **Step 4: Prescription overrides** — TGU low reps / longer rest; halo higher-rep lighter RPE

- [ ] **Step 5: Run `KettlebellCatalogTests` — expect PASS**

- [ ] **Step 6: Commit** `Add eleven kettlebell catalog exercises with content and swaps`

---

### Task 3: YouTube demos + handoff

- [ ] **Step 1: Source public YouTube URLs** for as many of the 11 as practical

- [ ] **Step 2: Merge via script**; regenerate handoff

- [ ] **Step 3: Run `YouTubeExerciseCatalogTests`**

- [ ] **Step 4: Commit** demos + handoff (unsourced ids OK)

---

### Task 4: Verify and finish

- [ ] **Step 1: Self-check script + unit tests green**

- [ ] **Step 2: Merge to main** (or PR per user choice)
