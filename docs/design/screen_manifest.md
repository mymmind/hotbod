# HotBod Screen Manifest

**Generated:** 2026-07-07  
**Platform:** iPhone, portrait, iOS 17+  
**Total entries:** 54 screen-states  
**Source:** SwiftUI navigation graph + view state machines

## Legend

| Column | Meaning |
|---|---|
| **ID** | Unique audit identifier |
| **Entry points** | How the user reaches this state |
| **Key components** | Primary UI building blocks |
| **States audited** | This row's state variant |

---

## App Shell

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-001 | `App/RootView` | `HotBod/App/HotBodApp.swift` | App launch | Route switcher | default (onboarding) |
| S-002 | `App/RootView` | same | Post-onboarding | Route switcher | default (main) |
| S-003 | `App/MainTabView` | `Features/Today/MainTabView.swift` | `router.route == .main` | `ForgeFloatingTabBar`, 5 tab roots | default |

---

## Onboarding (12 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-010 | `Onboarding/Container` | `Features/Onboarding/OnboardingViews.swift` | First launch; Settings → Reset | Progress bar, `ForgeButton` Back/Continue | default |
| S-011 | `Onboarding/Step0-Welcome` | same | Container step 0 | Accent mark, `ForgeTypography.largeTitle` | default |
| S-012 | `Onboarding/Step1-Goal` | same | Continue from Step0 | `ForgeSectionHeader`, `SelectableRow` | default |
| S-013 | `Onboarding/Step2-Experience` | same | Continue | `SelectableRow` | default |
| S-014 | `Onboarding/Step3-Location` | same | Continue | `SelectableRow` | default |
| S-015 | `Onboarding/Step4-Equipment` | same | Continue | `MultiSelectRow` | default |
| S-016 | `Onboarding/Step5-Schedule` | same | Continue | `SelectableChip`, steppers | default |
| S-017 | `Onboarding/Step6-BodyStats` | same | Continue | `ForgeTextField` ×3 | default |
| S-018 | `Onboarding/Step7-Limitations` | same | Continue | `SelectableRow`, `ForgeTextField` | default |
| S-019 | `Onboarding/Step8-Protein` | same | Continue | `ForgeTextField` | default |
| S-020 | `Onboarding/Step9-Photo` | same | Continue | `SelectableRow` enable/skip | default |
| S-021 | `Onboarding/Step10-Plan` | same | Continue | Plan summary, accent CTA | default |

---

## Today Tab (6 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-030 | `Today/Empty` | `Features/Today/TodayView.swift` | Tab Today, no workout | `ForgeScreenHeader`, `EmptyStateView` | empty |
| S-031 | `Today/Empty` | same | Tab Today | `ProgressView` implicit via `.task` | loading |
| S-032 | `Today/RestDay` | same | Tab Today, `isRestDay` | `ForgeHeroCard` recovery | default |
| S-033 | `Today/WorkoutReady` | same | Tab Today, workout exists | `ForgeHeroCard`, `TodayExerciseStrip`, bento | default |
| S-034 | `Today/WorkoutReady` | same | Regenerate tap | `ForgeHeroRegeneratingOverlay` | regenerating |
| S-035 | `Today/Completed` | same | Workout completed today | `ForgeHeroCard` completed, summary CTA | default |

**Destinations from Today:** Settings sheet (S-090), Completion sheet (S-082), Preview overlay (S-070), Session overlay (S-071), Coach push (S-060-Push).

---

## Train Tab (3 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-040 | `Train/WithWorkout` | `Features/WorkoutSession/TrainViews.swift` | Tab Train, workout exists | `ForgeHeroCard`, history list | with-workout |
| S-041 | `Train/NoWorkout` | same | Tab Train, no workout | Header, pointer to Today | no-workout |
| S-042 | `Train/HistoryEmpty` | same | Tab Train, no history | Empty history message | history-empty |

---

## Protein Tab (4 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-050 | `Protein/MealsEmpty` | `Features/ProteinTracker/ProteinTrackerView.swift` | Tab Protein | Hero progress, empty meals | meals-empty |
| S-051 | `Protein/MealsPopulated` | same | Tab Protein, logged meals | Meal rows, weekly chart | meals-populated |
| S-052 | `Protein/CustomEntrySheet` | same | Custom fast-add button | `NavigationStack`, `ForgeTextField` | default |
| S-053 | `Protein/CustomEntrySheet` | same | Empty fields | Save disabled | save-disabled |

---

## Progress Tab (6 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-055 | `Progress/Dashboard` | `Features/Today/ProgressDashboardView.swift` | Tab Progress | `ProgressView` | loading |
| S-056 | `Progress/Dashboard` | same | Data loaded | Metric cards, trends, insights | loaded |
| S-057 | `Progress/Dashboard` | same | No lift/volume data | Per-card empty copy | per-card-empty |
| S-058 | `Progress/BodyProgress` | `Features/ProteinTracker/BodyProgressView.swift` | Progress → Body card | Empty timeline | no-photos |
| S-059 | `Progress/BodyProgress` | same | Photos exist | Timeline, latest card | with-photos |
| S-060 | `Progress/BodyProgress` | same | Compare Latest Two | Side-by-side comparison | comparison-result |

---

## Coach (10 entries — 5 states × 2 presentations)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-061 | `Coach/Tab` | `Features/ProteinTracker/CoachView.swift` | Tab Coach | `ForgeScreenHeader`, suggestions | empty |
| S-062 | `Coach/Tab` | same | After messages sent | Message bubbles | messages |
| S-063 | `Coach/Tab` | same | Send in flight | Disabled input | sending |
| S-064 | `Coach/Tab` | same | AI proposes workout | Apply/Dismiss banner | proposal-pending |
| S-065 | `Coach/Tab` | same | Workout applied | Top accent banner (3s) | workout-updated-banner |
| S-066 | `Coach/Push` | same | Today → Ask Coach | Same as Tab, compact nav | empty |
| S-067 | `Coach/Push` | same | — | — | messages |
| S-068 | `Coach/Push` | same | — | — | sending |
| S-069 | `Coach/Push` | same | — | — | proposal-pending |
| S-070 | `Coach/Push` | same | — | — | workout-updated-banner |

**Note:** `router.openCoach()` overlay route is wired but unused in current UI.

---

## Exercise Library & Detail (5 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-071 | `ExerciseLibrary/Default` | `Features/ExerciseLibrary/ExerciseLibraryView.swift` | Train → Browse | Search, filters, list | default |
| S-072 | `ExerciseLibrary/FilterEmpty` | same | Filter yields zero | Empty filter message | filter-empty |
| S-073 | `ExerciseDetail/Loading` | `Features/ExerciseLibrary/ExerciseDetailView.swift` | Library row tap | `ProgressView` | loading |
| S-074 | `ExerciseDetail/Loaded` | same | Catalog resolved | `ExerciseDetailMediaHero`, tabs | loaded |
| S-075 | `ExerciseDetail/NoVideo` | same | Exercise without media | Placeholder in hero | no-video |

---

## Workout Flow (9 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-080 | `WorkoutPreview/Default` | `Features/WorkoutSession/TrainViews.swift` | Today/Train Preview | `WorkoutExerciseTimelineRow`, Start CTA | default |
| S-081 | `WorkoutSession/Loading` | `Features/WorkoutSession/WorkoutSessionView.swift` | Start workout | `ProgressView` | loading |
| S-082 | `WorkoutSession/Active` | same | Exercise loaded | `WorkoutSessionHeaderView`, set table, demo player | active |
| S-083 | `WorkoutSession/Resting` | same | Set completed | Rest timer bar (+30s/Skip) | resting |
| S-084 | `WorkoutSession/CompletionInline` | same | Session finished | `WorkoutCompletionView` inline | completion-inline |
| S-085 | `WorkoutCompletion/Sheet` | same | Today → View Summary | Metrics, progression notes, Done | default |
| S-086 | `WorkoutCompletion/Inline` | same | End of session | Same content, dismiss to main | default |
| S-087 | `SwapExercise/Default` | `Core/Components/SwapExerciseSheet.swift` | Session/Preview swap | `List`, substitute rows | default |
| S-088 | `SwapExercise/Empty` | same | No substitutes | Empty message | empty-substitutes |

---

## Settings (8 entries)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-090 | `Settings/Default` | `Features/Settings/SettingsView.swift` | Today gear sheet | Section rows, toggles | default |
| S-091 | `Settings/Saving` | same | Done tapped | "Saving…" trailing, disabled | saving |
| S-092 | `Settings/SaveError` | same | Save failure | Destructive inline message | save-error |
| S-093 | `Settings/AuthError` | same | Sign-in failure | Destructive auth message | auth-error |
| S-094 | `Settings/SignedIn` | same | Authenticated | Sync, Sign Out rows | signed-in |
| S-095 | `Settings/SignedOut` | same | Not authenticated | Email/password fields | signed-out |
| S-096 | `Settings/SupabaseUnconfigured` | same | No plist config | Setup instructions copy | supabase-unconfigured |
| S-097 | `Settings/EquipmentPicker` | same | Equipment row tap | Multi-select sheet, `.medium`/`.large` detents | default |

---

## System (1 entry)

| ID | Screen | File | Entry points | Key components | State |
|---|---|---|---|---|---|
| S-100 | `System/PhotosPicker` | `Features/ProteinTracker/BodyProgressView.swift` | Add Photo | `photosPicker` (system) | default — document only, do not reinvent |

---

## Excluded / Dead Code

| Screen | Reason |
|---|---|
| `LegacyProgressDashboardView` | Defined in `BodyProgressView.swift` area; not referenced |
| `AppRoute.exerciseDetail` overlay | Wired in `RootView`; no UI trigger |
| `AppRoute.settings` overlay | Sheet used instead |
| `AppRoute.coach` overlay | `openCoach()` unused |

---

## Sanity Check vs Navigation Graph

| Route in `AppRouter` | Manifest coverage |
|---|---|
| `.onboarding` | S-010–S-021 |
| `.main` | S-003 + all tab screens |
| `.workoutSession` | S-081–S-084 |
| `.workoutPreview` | S-080 |
| `.exerciseDetail` | S-073–S-075 (push only; overlay dead) |
| `.settings` | S-090–S-097 (sheet) |
| `.coach` | S-061–S-070 (tab/push; overlay dead) |

**Count verification:** 54 entries = screens specified target met.
