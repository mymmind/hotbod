# HotBod Component Manifest

**Generated:** 2026-07-07  
**Total components:** 28  
**States per component:** default | pressed | disabled | focused | selected | loading | error | success | empty

## State Matrix Legend

- ✓ = must be specified
- — = N/A (justified)
- ? = gap in current implementation

---

## Core Components (`HotBod/Core/Components/`)

### C-001 `ForgeButton`

**File:** `ForgeButton.swift`  
**Variants:** `.primary`, `.inverse`, `.secondary`, `.accent`  
**Used on:** Onboarding, Today, Train, Session, Completion, EmptyState

| State | Current | Spec required |
|---|---|---|
| default | ✓ | ✓ |
| pressed | scale 0.97 (`ForgePressButtonStyle`) | ✓ |
| disabled | `isLoading` only | ✓ (add explicit disabled) |
| focused | — | ✓ (keyboard/external) |
| selected | — | — |
| loading | `ProgressView` inline | ✓ |
| error | — | — |
| success | — | — |
| empty | — | — |

**Measured:** V-pad 16pt (18 accent), H full-width, radius 0 (32 accent), shadow accent only (12 blur, y 6).

---

### C-002 `ForgeCard`

**File:** `ForgeCard.swift`  
**Props:** `inverted`, `animated`

| State | Current |
|---|---|
| default | ✓ padding 16, spacing 12, 1pt border |
| pressed | — |
| disabled | — |
| focused | — |
| selected | — |
| loading | — |
| error | — |
| success | — |
| empty | — |

---

### C-003 `ForgeHeroCard`

**File:** `ForgeHeroCard.swift`  
**Used on:** Today, Train, Protein hero sections

| State | Current |
|---|---|
| default | ✓ |
| pressed | CTA uses `ForgeButton` |
| disabled | — |
| focused | title accessory button |
| selected | — |
| loading | `loadingSecondaryTitle` |
| error | — |
| success | `completed` variant |
| empty | — |

---

### C-004 `ForgeScreenHeader`

**File:** `ForgeScreenHeader.swift`  
**Styles:** `.root`, `.compact`

| State | Current |
|---|---|
| default | ✓ |
| pressed | trailing actions |
| disabled | — |
| focused | — |
| selected | — |
| loading | — |
| error | — |
| success | — |
| empty | — |

---

### C-005 `ForgeHeaderBackButton`

**File:** `ForgeScreenHeader.swift`  
**Measured:** 36×36 circle — **below 44pt minimum**

| State | Current |
|---|---|
| default | ✓ |
| pressed | plain button (no visual) |
| disabled | — |
| focused | ? |
| selected | — |
| loading | — |
| error | — |
| success | — |
| empty | — |

---

### C-006 `ForgeSectionHeader`

**File:** `ForgeSectionHeader.swift`

| State | All N/A except default ✓ |

---

### C-007 `ForgePill`

**File:** `ForgePill.swift`  
**Measured:** H-pad 12, V-pad 8, Capsule, 12% fill

| State | default ✓ only |

---

### C-008 `ForgeProgressBar`

**File:** `ForgeProgressBar.swift`  
**Measured:** height 4pt default

| State | default ✓, animated fill on change |

---

### C-009 `MetricCard`

**File:** `MetricCard.swift`  
**Measured:** minHeight 88, 3pt left accent bar

| State | default ✓, value pulse (Pow) |

---

### C-010 `ForgeFloatingTabBar`

**File:** `ForgeFloatingTabBar.swift`  
**Measured:** outer pad H8 V8, icon 18pt, label 10pt, selected capsule 44×32

| State | default ✓, selected ✓, pressed ? |

---

### C-011 `ForgeTabBarMetrics`

**File:** `ForgeFloatingTabBar.swift`  
**Constant:** `scrollClearance = 104`

---

### C-012 `ExerciseThumbnailView`

**File:** `ExerciseThumbnailView.swift`  
**Measured:** 72×72, radius 14, badge radius 6

| State | default ✓, play overlay |

---

### C-013 `WorkoutExerciseTimelineRow`

**File:** `WorkoutExerciseTimelineRow.swift`

| State | default ✓, focus gradient label |

---

### C-014 `WorkoutSessionHeaderView`

**File:** `WorkoutSessionHeaderView.swift`  
**Measured:** pad H16 V12, progress ring 52×52, stat capsule radius 10

| State | default ✓, resting timer variant |

---

### C-015 `ExerciseDemoPlayerView`

**File:** `ExerciseDemoPlayerView.swift`  
**Measured:** embedded height 180pt

| State | default, no-video placeholder |

---

### C-016 `ExerciseDetailMediaHero`

**File:** `ExerciseDemoPlayerView.swift`  
**Measured:** hero 340pt, back 40×40, angle thumb 52×52 radius 10

| State | default, selected angle, no-video |

---

### C-017 `SwapExerciseSheet`

**File:** `SwapExerciseSheet.swift`

| State | default ✓, empty ✓ |

---

## Feature Components

### C-018 `TodayMetricTile`

**File:** `Features/Today/TodayMetricTile.swift`  
**Measured:** pad 14, minH 120, radius 16, shadow accent 0.08/16/6

| State | default ✓, pressed scale 0.97 |

---

### C-019 `TodayDisclosureSection`

**File:** `Features/Today/TodayDisclosureSection.swift`  
**Measured:** radius 16, chevron circle 28×28

| State | default, expanded (selected) |

---

### C-020 `TodayExerciseStrip`

**File:** `Features/Today/TodayExerciseStrip.swift`  
**Measured:** chip width 72, radius 16 container

| State | default ✓ |

---

### C-021 `EmptyStateView`

**File:** `Features/Today/TodayView.swift`  
**Measured:** pad 32

| State | default ✓, with Retry CTA |

---

### C-022 `ForgeHeroRegeneratingOverlay`

**File:** `Features/Today/TodayView.swift`  
**Measured:** 82% black overlay, tracking 3

| State | loading only |

---

### C-023 `SelectableRow`

**File:** `Features/Onboarding/OnboardingViews.swift`  
**Measured:** pad 16, border 1pt (2pt selected)

| State | default, selected ✓, pressed ? |

---

### C-024 `SelectableChip`

**File:** `Features/Onboarding/OnboardingViews.swift`

| State | default, selected (gradient), pressed scale 1.02 |

---

### C-025 `ForgeTextField`

**File:** `Features/Onboarding/OnboardingViews.swift`  
**Measured:** pad 12, 1pt border, mono metric input

| State | default, focused ? |

---

### C-026 `SettingsSection` (composite)

**File:** `Features/Settings/SettingsView.swift`  
**Private helpers:** `settingsSection`, `settingsValueRow`, `settingsMenuRow`, `settingsActionRow`, `settingsToggleRow`, `settingsDivider`

| State | default; destructive row variant |

---

### C-027 `CoachMessageBubble` (inline)

**File:** `Features/ProteinTracker/CoachView.swift`  
**Not extracted** — spec as `CoachBubble` component

| State | user, assistant |

---

### C-028 `ProgressStatCard` (inline)

**File:** `Features/Today/ProgressDashboardView.swift`  
**Inline cards** — promote to `ForgeStatCard`

| State | default, empty data |

---

## Component Count Verification

| Category | Count |
|---|---|
| Core | 17 |
| Feature | 11 |
| **Total** | **28** |

## Cross-Reference: Primary Button Variants

| Semantic role | Current implementation | Canonical name |
|---|---|---|
| Primary CTA | `ForgeButton.accent` | `Button.Primary` |
| Secondary action | `ForgeButton.secondary` | `Button.Secondary` |
| On dark hero | `ForgeButton.inverse` | `Button.Inverse` |
| On light surface | `ForgeButton.primary` | `Button.PrimarySolid` |
| Destructive | Settings `settingsActionRow(destructive:)` | `Button.Destructive` (new) |
| System bordered | Coach Apply Workout | `Button.SystemProminent` (keep system) |

**Token drift smell:** 4 `ForgeButton` styles + system `.borderedProminent` + plain `Button` in Coach/Settings = 6 button patterns to collapse to 5 named variants.
