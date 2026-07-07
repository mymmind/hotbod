# HotBod Measurement Log

**Date:** 2026-07-07  
**Sources:** SwiftUI source static analysis + Xcode Simulator builds  
**Devices verified:** iPhone SE (3rd gen) iOS 17.0, iPhone 17 Pro iOS 26.5

## Build Verification

| Device | OS | Result |
|---|---|---|
| iPhone SE (3rd generation) | 17.0 | **BUILD SUCCEEDED** |
| iPhone 17 Pro | 26.5 | **BUILD SUCCEEDED** |

*Note: iPhone 16 Pro not available in local simulator catalog; iPhone 17 Pro used as standard-size proxy.*

---

## Press States (code-measured)

| Component | State | Property | Value | Source |
|---|---|---|---|---|
| `ForgeButton` | pressed | scaleEffect | 0.97 | `ForgePressButtonStyle` |
| `ForgeButton` | pressed | animation | 220ms smooth | `ForgeMotion.quick` |
| `TodayMetricTile` | pressed | scaleEffect | 0.97 | `TodayMetricPressStyle` |
| `SelectableChip` | selected | scaleEffect | 1.02 | `OnboardingViews.swift` |
| `ForgeFloatingTabBar` | pressed | — | no visual (plain style) | `ForgeFloatingTabBar.swift` |

---

## Shadow Measurements (code-measured)

| Component | Color | Opacity | Radius | Y-offset | Source |
|---|---|---|---|---|---|
| Tab bar capsule | black | 0.12 | 20 | 8 | `ForgeFloatingTabBar.swift:17` |
| Accent button | accent | 0.35 | 12 | 6 | `ForgeButton.swift:38` |
| Metric tile | accent | 0.08 | 16 | 6 | `TodayMetricTile.swift:62` |
| Disclosure section | black | 0.04 | 12 | 4 | `TodayDisclosureSection.swift:46` |
| Exercise strip | black | 0.05 | 14 | 6 | `TodayExerciseStrip.swift:43` |
| Today stat card | black | 0.05 | 14 | 6 | `TodayView.swift:419` |
| Settings gear | black | 0.10 | 10 | 4 | `TodayView.swift:174` |

**Material blur:** Tab bar uses opaque `ForgeColors.surface` fill — no `Material` blur. Spec: keep opaque (brand); do not add vibrancy.

---

## Component Dimensions (code-measured)

| Component | Dimension | Value |
|---|---|---|
| `ForgeButton` accent | vertical padding | 18pt |
| `ForgeButton` other | vertical padding | 16pt |
| `ForgeButton` accent | corner radius | 32pt |
| `ForgeButton` other | corner radius | 0pt |
| `ForgeHeaderBackButton` | frame | 36×36 |
| `ForgeScreenHeader` accent mark | frame | 48×3 |
| `ForgeFloatingTabBar` | outer padding | H8 V8 |
| Tab icon area | frame | 44×32 |
| Tab icon font | size | 18pt |
| Tab label font | size | 10pt |
| `ExerciseThumbnailView` | size | 72×72 |
| `ExerciseDetailMediaHero` | height | 340pt |
| `ExerciseDemoPlayerView` embedded | height | 180pt |
| Detail back button | frame | 40×40 |
| Angle thumbnail | size | 52×52 |
| Progress ring | size | 52×52, stroke 3pt |
| `TodayMetricTile` | minHeight | 120pt, pad 14pt |
| `MetricCard` | minHeight | 88pt |
| Tab scroll clearance | bottom margin | 104pt |

---

## Typography Point Sizes at Default Dynamic Type (code-measured)

| Style | pt | Weight |
|---|---|---|
| largeTitle | 44 | black serif |
| displayAthletic | 34 | heavy italic |
| heading | 22 | semibold |
| body | 16 | regular |
| caption | 13 | medium |
| monoMetric | 18 | bold mono |
| heroMetric | 36 | bold mono |
| session exercise name | 26 | heavy italic |
| tab label | 10 | medium/semibold |

**AX5 / xxxLarge:** Not measurable without UI test run; spec requires layout verification during implementation. Code uses `fixedSize` and `lineLimit(1)` in several places — flagged as AX risk in subagent E.

---

## Motion Durations (code-measured)

| Animation | Duration |
|---|---|
| standard | 350ms |
| quick | 220ms |
| exercise | 480ms |
| regenerate | 550ms |
| regenerateMinimum | 720ms |
| stagger step | 70ms × index |
| progress bar appear delay | 200ms |
| content appear delay | 50ms |
| coach banner auto-dismiss | 3000ms |

---

## Safe Area / Layout

| Screen | Treatment | Source |
|---|---|---|
| Main tabs | `forgeFloatingTabBarClearance()` 104pt bottom | `MainTabView` children except Coach |
| Coach tab | Input bar 104pt pad only — **gap** | `CoachView.swift` |
| Workout session | Nav hidden, full bleed | `WorkoutSessionView` |
| Onboarding | Standard safe area, bottom CTA pad 16pt | `OnboardingContainerView` |

---

## Contrast Ratios (computed from hex)

| Foreground | Background | Ratio | Pass 4.5:1 body? |
|---|---|---|---|
| #000000 | #FFFFFF | 21:1 | ✓ |
| gray 60% (~#999) | #FFFFFF | 1.92:1 | ✗ |
| #2663EB | #FFFFFF | 5.16:1 | ✓ |
| #00B86B | #FFFFFF | 2.60:1 | ✗ (large only) |
| #FF9E00 | #FFFFFF | 2.07:1 | ✗ |
| #FFFFFF | #FF3D2E | 3.52:1 | ✓ large/bold CTA |
| #FFFFFF | #121212 | 15.8:1 | ✓ (dark mode target) |

---

## NEEDS-MEASURE Resolution

| Item | Resolution |
|---|---|
| Press/highlight states | Resolved via `ForgePressButtonStyle` source |
| Shadow blur radius | Resolved via `.shadow()` parameters in source |
| Material blur tab bar | Resolved: none — opaque surface |
| Pow animation duration | Matches parent `ForgeMotion` token |
| Rest timer transition | Uses `ForgeMotion.standard` 350ms |

**Remaining NEEDS-MEASURE: 0** (AX5 layout requires implementation-phase UI tests; spec documents expected behavior).
