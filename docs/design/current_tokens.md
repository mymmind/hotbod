# HotBod Current Tokens (Implicit)

**Extracted from:** SwiftUI source code  
**Date:** 2026-07-07  
**Appearance:** Light mode only (`.preferredColorScheme(.light)`)

---

## 1. Colors (`ForgeColors.swift`)

| Token name | Value | Usage |
|---|---|---|
| `background` | `#FFFFFF` | Screen backgrounds |
| `foreground` | `#000000` | Primary text |
| `surface` | `#FFFFFF` | Cards, tab bar |
| `surfaceInverse` | `#000000` | Hero cards, primary button fill |
| `border` | `black @ 15%` | Strokes, dividers |
| `muted` | `gray @ 60%` | Secondary text |
| `accent` | `#FF3D2E` rgb(1.0, 0.24, 0.18) | CTAs, tab selected |
| `accentHot` | `#FF2E7A` | Gradient start |
| `accentBlue` | `#2663EB` | Protein |
| `accentGreen` | `#00B86B` | Readiness high |
| `accentAmber` | `#FF9E00` | Readiness moderate |
| `destructive` | `#DB2626` | Errors |
| `success` | alias `accentGreen` | — |

**Gradients:**
- `accentGradient`: accentHot → accent, leading→trailing
- `focusGradient`: accentAmber → accentHot

**Function:** `readiness(%)` → green ≥70, amber ≥50, else accent

**Gaps:** No dark mode values. No semantic layer. No asset catalog colors.

---

## 2. Typography (`ForgeTypography.swift`)

| Token | Size | Weight | Design | Tracking (inline) |
|---|---|---|---|---|
| `largeTitle` | 44pt | black | serif | 2–2.5 (headers) |
| `displayTitle` | 34pt | black | serif | rarely used |
| `displayAthletic` | 34pt | heavy italic | default | — |
| `title` | 30pt | bold | serif | rarely used |
| `heading` | 22pt | semibold | default | — |
| `body` | 16pt | regular | default | — |
| `caption` | 13pt | medium | default | 1.2–3.0 |
| `ctaLabel` | 13pt | bold italic | default | 1.4 |
| `monoMetric` | 18pt | bold | monospaced | — |
| `heroMetric` | 36pt | bold | monospaced | — |

### Ad-hoc font sizes (not in ramp)

| Location | Size | Weight |
|---|---|---|
| `WorkoutSessionHeaderView` exercise name | 26pt | heavy italic |
| `WorkoutSessionHeaderView` labels | 8–14pt | various |
| `ForgeFloatingTabBar` icon | 18pt | regular/semibold |
| `ForgeFloatingTabBar` label | 10pt | medium/semibold |
| `ForgeHeroCard` accessory icon | 18pt | bold |
| `ExerciseThumbnailView` badge | 9pt | bold |
| `ExerciseDemoPlayerView` play icon | 40–44pt | — |
| `TodayView` regenerating icon | 28pt | semibold |
| `TodayExerciseStrip` set count | 11pt | semibold mono |

**Gaps:** No Dynamic Type. No `TextStyle` mapping. SF Pro Text/Display rules not applied.

---

## 3. Spacing (inline — no token file)

| Value (pt) | Locations |
|---|---|
| 4 | Hero badge V-pad, disclosure offsets, pill spacing |
| 5 | Thumbnail badge H-pad |
| 6 | Header H-spacing, coach banner V-pad |
| 8 | Onboarding progress top, header top, pill H-spacing |
| 10 | Hero title spacing, metric tile internal, coach banner |
| 12 | Onboarding footer, section spacing, text field pad |
| 14 | Metric tile pad, timeline row spacing |
| 16 | Card pad, session header H-pad, settings H-pad, coach pad |
| 18 | Accent button V-pad |
| 20 | Screen header H-pad, hero H-pad, settings V-pad |
| 24 | Onboarding step pad |
| 28 | Hero bottom pad |
| 32 | Empty state pad |
| 104 | Tab bar scroll clearance |

**Conflicts:**
- Screen margin **20pt** vs card padding **16pt**
- Onboarding padding **24pt** vs screen **20pt**

---

## 4. Radii (inline)

| Value | Shape | Locations |
|---|---|---|
| 0 | Rectangle | `ForgeCard`, `ForgeButton` non-accent, demo player |
| 2 | RoundedRect | Exercise detail tab indicator |
| 6 | RoundedRect | Thumbnail muscle badge |
| 10 | RoundedRect | Session stat capsule, video angle thumb |
| 12 | RoundedRect | Today progress stat clip |
| 14 | RoundedRect | `ExerciseThumbnailView` |
| 16 | RoundedRect | Today bento tiles, disclosure, exercise strip |
| 32 | RoundedRect | `ForgeButton.accent` only |
| Capsule | — | Pills, chips, tab bar, timer |
| Circle | — | Back button, hero accessory, play overlay |

---

## 5. Borders

| Width | Usage |
|---|---|
| 1pt | Default stroke (`ForgeCard`, rows, tiles) |
| 2pt | `SelectableRow` selected |
| 2.5pt | Video angle selected |
| 3pt | Progress ring, metric accent bar, accent mark height |

---

## 6. Shadows

| Recipe | Location |
|---|---|
| `black 12% / r20 / y8` | `ForgeFloatingTabBar` |
| `accent 35% / r12 / y6` | `ForgeButton.accent` |
| `accent 8% / r16 / y6` | `TodayMetricTile` |
| `black 4% / r12 / y4` | `TodayDisclosureSection` |
| `black 5% / r14 / y6` | `TodayExerciseStrip`, Today cards |
| `black 10% / r10 / y4` | Settings gear button |

---

## 7. Motion (`ForgeMotion.swift`)

| Token | Value |
|---|---|
| `standard` | smooth 350ms |
| `quick` | smooth 220ms |
| `exercise` | smooth 480ms |
| `regenerate` | smooth 550ms |
| `regenerateMinimum` | 720ms |
| `staggerDelay` | index × 70ms |

**Press feedback:** scale 0.97 (`ForgeButton`, `TodayMetricTile`)

**Pow effects:** jump(4), shake(fast), success haptic

**Gaps:** No `accessibilityReduceMotion` checks.

---

## 8. Icons

| Context | Size |
|---|---|
| Tab bar SF Symbol | 18pt |
| Tab label | 10pt (text, not icon) |
| Thumbnail play | caption |
| Hero accessory | 18pt |
| Settings gear | body.semibold |

---

## 9. Touch Targets (measured)

| Control | Visible | Hit area | Meets 44pt? |
|---|---|---|---|
| `ForgeButton` | full width × ~50pt | full frame | ✓ height |
| `ForgeHeaderBackButton` | 36×36 | 36×36 | ✗ |
| Tab bar item | 44×32 icon area | maxWidth infinity | ✓ width, ? height |
| Exercise angle thumb | 52×52 | 52×52 | ✓ |
| Detail back button | 40×40 | 40×40 | ✗ |
| Coach suggestion buttons | text height | intrinsic | ✗ likely |
| `SelectableRow` | variable | full row | ✓ if row tall enough |

---

## 10. Accessibility (current)

| Feature | Status |
|---|---|
| Dynamic Type | Not supported |
| Dark Mode | Forced light |
| VoiceOver labels | ~10 total |
| Reduce Motion | Not handled |
| Increase Contrast | Not handled |
| Bold Text | Inherits system on labels only |

---

## 11. Design Smells Summary

| Smell | Count | Examples |
|---|---|---|
| Magic number | 40+ | spacing 14, 18, 28 |
| Token drift | 6 | horizontal 16 vs 20 |
| Ramp bloat | 15+ ad-hoc sizes | session header 8–26pt |
| One-off type | 15 | tab 10pt, badge 9pt |
| Inconsistent corner radius | 5 tiers | 0, 14, 16, 32 |
| Small tap target | 4+ | back 36pt, detail back 40pt |
| Missing state | many | no disabled button style |
| Pure-black dark mode | N/A | not implemented |
| No dark mode at all | 1 | app-wide |
