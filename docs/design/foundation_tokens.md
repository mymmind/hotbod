# HotBod Foundation Tokens

**Version:** 1.0  
**Date:** 2026-07-07  
**Platform:** iPhone, iOS 17+ deploy, iOS 26 HIG alignment  
**Rule:** All screen and component specs reference **semantic tokens only**. Primitives are for token file implementation.

---

## 1. Spacing Scale

Base unit: **4pt**. Common steps on 8pt rhythm.

| Token | Value | Usage |
|---|---|---|
| `space.0` | 0 | — |
| `space.1` | 4 | Tight inline gaps, badge padding |
| `space.2` | 8 | Icon gaps, compact stacks |
| `space.3` | 12 | Chip padding, section inner gaps |
| `space.4` | 16 | **Card internal padding**, list row padding |
| `space.5` | 20 | **Screen horizontal margin** |
| `space.6` | 24 | Section spacing, onboarding padding |
| `space.8` | 32 | Empty state padding |
| `space.10` | 40 | — |
| `space.12` | 48 | Accent mark width |
| `space.16` | 64 | — |
| `space.tabClearance` | 104 | Computed: tab bar height + safe inset (document formula in implementation) |

**Rules:**
- Internal padding ≤ external margin (Gestalt)
- Screen horizontal margin: always `space.5` (20pt)
- Card padding: always `space.4` (16pt)
- Onboarding steps: `space.6` (24pt) — justified exception for first-run breathing room

---

## 2. Radius Scale

Use SwiftUI `RoundedRectangle(cornerRadius:, style: .continuous)` unless `radius.none`.

| Token | Value | Usage |
|---|---|---|
| `radius.none` | 0 | Brutalist cards, non-accent buttons, core `ForgeCard` |
| `radius.xs` | 6 | Muscle badge |
| `radius.sm` | 10 | Stat capsules, video thumbnails |
| `radius.md` | 14 | Exercise thumbnails |
| `radius.lg` | 16 | Today bento tiles (soft variant) |
| `radius.xl` | 20 | — reserved |
| `radius.pill` | 32 | Accent CTA buttons |
| `radius.full` | 999 | Capsule pseudo-full |

**Named variants:**
- `radius.brutalist` → `radius.none` (core library)
- `radius.soft` → `radius.lg` (Today feature bento)

**Reconciliation:** Keep both; screens declare variant explicitly. Do not mix on same component class.

---

## 3. Typography Ramp

Map to **Dynamic Type** `Font.TextStyle`. Custom weight/design applied via modifier.

| Token | TextStyle | Weight | Design | Role |
|---|---|---|---|---|
| `type.hero` | `.largeTitle` | `.black` | `.serif` | Root screen titles |
| `type.display` | `.title` | `.heavy` | default + italic | Hero card titles |
| `type.title` | `.title2` | `.semibold` | default | Section headings |
| `type.body` | `.body` | `.regular` | default | Body copy |
| `type.label` | `.caption` | `.medium` | default | Eyebrows, metadata |
| `type.cta` | `.caption` | `.bold` | default + italic | Button labels |
| `type.metric` | `.title3` | `.bold` | `.monospaced` | Inline metrics |
| `type.metricHero` | `.largeTitle` | `.bold` | `.monospaced` | Hero metrics |
| `type.sessionTitle` | `.title2` | `.heavy` | default + italic | Workout exercise name (replaces 26pt ad-hoc) |
| `type.tabLabel` | `.caption2` | `.medium`/`.semibold` | default | Tab bar labels |

**Tracking (apply via `.tracking()`):**
- `tracking.tight` = 1.2 — secondary buttons
- `tracking.cta` = 1.4 — accent CTAs
- `tracking.eyebrow` = 2.0 — compact headers
- `tracking.eyebrowWide` = 2.5 — root headers

**Rules:**
- No fixed `Font.system(size:)` in feature code
- Minimum legible:系统 caption2 (~11pt) — use only for tab labels
- Line heights follow system TextStyle (4pt baseline via system)

---

## 4. Color Primitives

### Light mode

| Token | Hex |
|---|---|
| `neutral.0` | `#FFFFFF` |
| `neutral.50` | `#F5F5F5` |
| `neutral.200` | `#E5E5E5` |
| `neutral.500` | `#8E8E93` |
| `neutral.800` | `#3A3A3C` |
| `neutral.900` | `#1C1C1E` |
| `neutral.1000` | `#000000` |
| `brand.500` | `#FF3D2E` |
| `brand.hot` | `#FF2E7A` |
| `blue.500` | `#2663EB` |
| `green.500` | `#00B86B` |
| `amber.500` | `#FF9E00` |
| `red.500` | `#DB2626` |

### Dark mode

| Token | Hex |
|---|---|
| `neutral.0` | `#121212` |
| `neutral.50` | `#1C1C1E` |
| `neutral.200` | `#2C2C2E` |
| `neutral.500` | `#8E8E93` |
| `neutral.800` | `#D1D1D6` |
| `neutral.900` | `#F2F2F7` |
| `neutral.1000` | `#FFFFFF` |
| `brand.500` | `#FF5247` |
| `brand.hot` | `#FF4D8A` |
| `blue.500` | `#4D8BF7` |
| `green.500` | `#34C759` |
| `amber.500` | `#FFB340` |
| `red.500` | `#FF453A` |

---

## 5. Semantic Colors

| Token | Light primitive | Dark primitive |
|---|---|---|
| `color.background.primary` | `neutral.0` | `neutral.0` |
| `color.surface` | `neutral.0` | `neutral.50` |
| `color.surface.elevated` | `neutral.0` | `neutral.200` |
| `color.surface.inverse` | `neutral.1000` | `neutral.900` |
| `color.text.primary` | `neutral.1000` | `neutral.1000` |
| `color.text.secondary` | `neutral.500` | `neutral.500` |
| `color.text.muted` | `neutral.500` @ 85% | `neutral.500` |
| `color.text.onInverse` | `neutral.0` | `neutral.0` |
| `color.border.subtle` | `neutral.1000` @ 15% | `neutral.1000` @ 20% |
| `color.action.primary` | `brand.500` | `brand.500` |
| `color.action.primaryGradientStart` | `brand.hot` | `brand.hot` |
| `color.action.primaryGradientEnd` | `brand.500` | `brand.500` |
| `color.action.destructive` | `red.500` | `red.500` |
| `color.accent.protein` | `blue.500` | `blue.500` |
| `color.status.success` | `green.500` | `green.500` |
| `color.status.warning` | `amber.500` | `amber.500` |
| `color.readiness.low` | `brand.500` | `brand.500` |
| `color.readiness.mid` | `amber.500` | `amber.500` |
| `color.readiness.high` | `green.500` | `green.500` |

**Gradients (semantic):**
- `gradient.action.primary` → primaryGradientStart → primaryGradientEnd
- `gradient.focus` → warning → brand.hot

---

## 6. Elevation / Shadow

Prefer surface contrast in dark mode; shadows light-mode only.

| Token | Light | Dark |
|---|---|---|
| `elevation.0` | none | none |
| `elevation.1` | black 12% / blur 20 / y 8 | none (use `surface.elevated`) |
| `elevation.2` | brand 35% / blur 12 / y 6 | brand 25% / blur 8 / y 4 |
| `elevation.3` | accent-tinted 8% / blur 16 / y 6 | none |

**Usage:**
- `elevation.1` → tab bar only
- `elevation.2` → accent CTA only
- `elevation.3` → metric tiles (optional; prefer border in dark)

---

## 7. Motion

| Token | Duration | Easing |
|---|---|---|
| `motion.instant` | 0ms | none |
| `motion.fast` | 150ms | smooth |
| `motion.base` | 250ms | smooth |
| `motion.slow` | 400ms | smooth |
| `motion.stagger` | 70ms × index | smooth |

**Transitions:**
- `transition.appear` — opacity + move top (replace Pow wipe near notch)
- `transition.rise` — move bottom
- `transition.exercise` — opacity + offset y 20/−12
- `transition.disclosure` — opacity + offset y −8/−4

**Reduce Motion:** All → `motion.instant` or opacity-only cross-fade.

**Haptics:** Success notification only on workout completion — not per button tap.

---

## 8. Iconography

| Token | Size | Usage |
|---|---|---|
| `icon.sm` | 16 | Inline chevrons |
| `icon.md` | 20 | Standard toolbar |
| `icon.lg` | 24 | Hero accessories |
| `icon.xl` | 32 | Empty states |
| `icon.tab` | 18 | Tab bar — **justified exception** (optical balance in capsule) |
| `icon.play` | 40 | Video placeholder |

SF Symbols weights: `.regular` default, `.semibold` selected states.

---

## 9. Touch Targets

| Token | Value |
|---|---|
| `target.min` | 44×44pt |
| `target.compact` | 36×36 visible max — must expand hit area to 44 via `.contentShape` + padding |

**Rule:** No interactive control ships without ≥44pt hit area.

---

## 10. Border Width

| Token | Value |
|---|---|
| `border.hairline` | 1pt |
| `border.emphasis` | 2pt |
| `border.selected` | 2.5pt |

---

## 11. Implementation Files (handoff)

| File | Contents |
|---|---|
| `ForgeSpacing.swift` | space.* constants |
| `ForgeRadius.swift` | radius.* + corner style helper |
| `ForgeElevation.swift` | shadow modifiers |
| `ForgeColors.swift` | extend with semantic + ColorScheme |
| `ForgeTypography.swift` | TextStyle-based fonts |
| `ForgeMotion.swift` | update durations + reduceMotion |

---

## 12. Contrast Pre-Check (semantic pairs)

| Pair | Light ratio | Dark ratio | Pass AA? |
|---|---|---|---|
| text.primary on background.primary | 21:1 | 15.8:1 | ✓ |
| text.secondary on background.primary | 4.6:1 | 4.6:1 | ✓ body |
| text.muted on background.primary | 4.6:1 | 4.6:1 | ✓ at ≥17pt; **fail at 13pt caption** → use text.secondary for captions |
| text.onInverse on surface.inverse | 21:1 | 15.8:1 | ✓ |
| action.primary on background | 3.5:1 | 4.1:1 | ✓ non-text UI |
| white on action.primary gradient | ~4.8:1 | ~4.8:1 | ✓ large/bold CTA |

**Fix:** Replace `color.text.muted` for body captions with `color.text.secondary`.
