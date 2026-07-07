# Subagent B — Color & Contrast Auditor

**Date:** 2026-07-07  
**Scope:** `ForgeColors.swift`, `HotBodApp.swift`, all SwiftUI feature/component color usage (27 files)  
**Appearance audited:** Light mode only (as shipped)  
**WCAG target:** AA — 4.5:1 normal text, 3:1 large text (≥18pt regular or ≥14pt bold) / UI components  
**Critical findings:** 6

---

## Coverage

| Area | Files scanned | Color refs | Status |
|---|---|---|---|
| Design tokens (spec) | `foundation_tokens.md` | 28 primitives + 17 semantic | ✓ Read |
| Design tokens (impl) | `ForgeColors.swift` | 13 static + 2 gradients + 1 fn | ✓ Read |
| App shell | `HotBodApp.swift` | `.preferredColorScheme(.light)`, `.tint(accent)` | ✓ Audited |
| Core components | 15 files | ~120 refs | ✓ Audited |
| Feature screens | 12 files | ~150 refs | ✓ Audited |
| Dark mode | — | 0 implementations | ✗ Not present |
| Semantic token layer | — | 0 `ColorScheme`-aware APIs | ✗ Not present |

**Key pairs computed:** 30 foreground/background combinations across primitives, opacity stacks, and gradient stops.

---

## Tools / references used

| Tool / reference | Purpose |
|---|---|
| `foundation_tokens.md` §4–5, §12 | Target primitives, semantic mapping, pre-check baselines |
| `current_tokens.md` | Implementation inventory cross-check |
| `ForgeColors.swift` | Source-of-truth color values |
| `rg` (ripgrep) across `HotBod/**/*.swift` | Usage frequency and spill detection |
| Python WCAG 2.1 relative-luminance script | Contrast ratio computation (sRGB, alpha compositing) |
| `screen_manifest.md` | Per-screen semantic mapping targets |
| AGENTS.md UI rules | Accent domain: training/CTAs; blue=protein; green/amber=readiness |

**Computation notes:**
- `ForgeColors.muted` = `Color.gray.opacity(0.6)` composited over `#FFFFFF` → effective `#BBBBBE` (RGB 187, 187, 190).
- `ForgeColors.border` = `#000000` @ 15% over white → effective `#D9D9D9`.
- Opacity stacks computed via alpha compositing onto stated background.
- Gradient text (`focusGradient`) ratio reported at worst-case stop (amber end).

---

## Findings (SB-001…)

### Summary by severity

| Severity | Count | IDs |
|---|---|---|
| **Critical** | **6** | SB-001, SB-002, SB-003, SB-004, SB-005, SB-011 |
| High | 5 | SB-006, SB-008, SB-009, SB-012, SB-016 |
| Medium | 5 | SB-007, SB-010, SB-013, SB-014, SB-015 |
| Low | 2 | SB-017, SB-018 |

---

### SB-001 — `ForgeColors.muted` systemic contrast failure **(Critical)**

| | |
|---|---|
| **Pair** | `muted` on `background` (`#BBBBBE` on `#FFFFFF`) |
| **Ratio** | **1.92:1** — fails normal, large, and UI AA |
| **Usage** | **84 references** across 22 files — captions, metadata, empty states, tab labels, section subtitles |
| **Spec drift** | Foundation defines `color.text.muted` as `neutral.500` @ 85% (`#9F9FA3`, ~2.64:1). Implementation uses `gray @ 60%`, which is **worse**. |
| **Fix** | Replace with `color.text.secondary` (`neutral.500` `#8E8E93`, 3.26:1) for captions; reserve muted for ≥18pt decorative only. Implement as named semantic token. |

**Affected hotspots:** `SettingsView` (10×), `ProgressDashboardView` (11×), `TodayView` (8×), `BodyProgressView` (7×), `OnboardingViews` (6×), `ForgeFloatingTabBar` (1× unselected tabs).

---

### SB-002 — No dark mode; light scheme forced app-wide **(Critical)**

| | |
|---|---|
| **Evidence** | `HotBodApp.swift:13` — `.preferredColorScheme(.light)` |
| **Impact** | Users with dark mode preference, low vision, or OLED battery preference get blinding white UI. Foundation tokens define full dark primitive set (§4) — unused. |
| **Contrast at risk** | Spec dark `text.primary on background` = 15.8:1; current impl would invert incorrectly if dark mode enabled without token work. |
| **Fix** | Remove forced light; extend `ForgeColors` with `ColorScheme`-aware semantic accessors per `foundation_tokens.md` §5. |

---

### SB-003 — Tab bar unselected labels fail at 10pt **(Critical)**

| | |
|---|---|
| **File** | `ForgeFloatingTabBar.swift:41–43` |
| **Pair** | `muted` on `surface` at **10pt medium** |
| **Ratio** | **1.92:1** — fails all WCAG text levels |
| **Fix** | Unselected tab label → `color.text.secondary`; bump to `type.tabLabel` (caption2, ~11pt) minimum per foundation §3. |

---

### SB-004 — `accentGreen` used as readable text on white **(Critical)**

| | |
|---|---|
| **Pair** | `#00B86B` on `#FFFFFF` |
| **Ratio** | **2.60:1** — fails normal and large text AA |
| **Usage** | Readiness %, completed badges, chart positive deltas, session stat labels |
| **Files** | `ProgressDashboardView`, `WorkoutSessionView`, `ForgeHeroCard`, `WorkoutSessionHeaderView` |
| **Fix** | Readiness high → `color.status.success` only on inverse/dark surfaces, or darken to `#007A47` (~4.5:1 on white). On white cards use `foreground` text + green icon/dot. |

---

### SB-005 — `accentAmber` used as readable text on white **(Critical)**

| | |
|---|---|
| **Pair** | `#FF9E00` on `#FFFFFF` |
| **Ratio** | **2.07:1** — fails all text levels |
| **Usage** | `ExerciseLibraryView` filter chips, duration metric labels, readiness mid-state |
| **Fix** | Amber for icons/bars only on white; text labels use `foreground` or darken to `#9A6200`. |

---

### SB-011 — Opacity-compounded muted failures **(Critical)**

| | |
|---|---|
| **Pairs** | `muted.opacity(0.85)` → **1.73:1**; `muted.opacity(0.4)` → **1.27:1**; `muted.opacity(0.3)` → **1.18:1** |
| **Files** | `WorkoutExerciseTimelineRow`, `ProteinTrackerView` (weekly chart), `ProgressDashboardView` (sparkline grid) |
| **Impact** | Chart axes, secondary muscle lines, and missed-goal indicators become illegible |
| **Fix** | Never stack opacity on already-failing muted; use `text.secondary` at full opacity or `border.subtle` for decorative lines |

---

### SB-006 — `focusGradient` applied as caption text fill **(High)**

| | |
|---|---|
| **File** | `WorkoutExerciseTimelineRow.swift:40` |
| **Pair** | Gradient stop `accentAmber` on white (worst case) |
| **Ratio** | **2.07:1** at amber end; hot end 3.55:1 |
| **Rule violation** | AGENTS.md: gradient only on primary CTAs — not text labels |
| **Fix** | "FOCUS EXERCISE" label → `color.action.primary` solid or `text.secondary` + amber 3pt accent bar |

---

### SB-008 — Brand accent spill beyond training/CTA domain **(High)**

| | |
|---|---|
| **Rule** | `accent` reserved for workouts, CTAs, tab bar per AGENTS.md |
| **Violations** | **85 total `ForgeColors.accent` refs**; ~30 outside core training flows |
| **Spill map** | |

| Screen / component | Accent usage | Should be |
|---|---|---|
| `ProgressDashboardView` | 11× — chart lines, compliance bars, section headers, E1RM trend | `accentBlue` (protein), `foreground` (neutral charts), section accent per domain |
| `SettingsView` | 4× — nav links, toggles, action text | `foreground` / `text.secondary` for nav; accent only on destructive-adjacent CTAs |
| `CoachView` | 4× — banner, send button, user bubbles | Acceptable for CTA; banner could be `surfaceInverse` |
| `ForgeScreenHeader` | Default `accent` param | Per-tab: Today=accent, Protein=blue, Progress=green |
| `ExerciseThumbnailView` | Play icon + gradient tint | Acceptable (training) |
| `ExerciseDetailView` | Tab indicator dot | `foreground` |
| Global `.tint(accent)` | All `Toggle`, `Picker`, `ProgressView` | Per-context tint or `foreground` |

---

### SB-009 — No semantic color layer; flat aliases only **(High)**

| | |
|---|---|
| **Spec** | `foundation_tokens.md` §5 — 17 semantic tokens with light/dark primitives |
| **Impl** | `ForgeColors` exposes 13 flat `static let` values; no `ColorScheme` parameter |
| **Drift examples** | `foreground` ≠ `color.text.primary`; `muted` ≠ `color.text.muted`; `surfaceInverse` ≠ `color.surface.inverse` |
| **Fix** | Refactor to `ForgeColors.textPrimary(_:)` / `SemanticColor` enum per handoff §11 |

---

### SB-012 — Global accent tint pollutes non-training controls **(High)**

| | |
|---|---|
| **File** | `HotBodApp.swift:63` — `.tint(ForgeColors.accent)` on `RootView` |
| **Impact** | Onboarding `Toggle`, Settings `Picker`, Protein `Stepper`, chart `ProgressView` all render in brand red |
| **Fix** | Scope tint per feature; default tint → `foreground`; accent tint only on training tab root |

---

### SB-016 — No Increase Contrast / Bold Text adaptation **(High)**

| | |
|---|---|
| **Evidence** | No `@Environment(\.colorSchemeContrast)` or `accessibilityContrast` checks anywhere |
| **Risk** | iOS Increase Contrast mode won't boost failing muted/border pairs |
| **Fix** | In semantic layer, bump `text.secondary` → `text.primary` when `colorSchemeContrast == .increased` |

---

### SB-007 — White on accent CTA gradient borderline for caption size **(Medium)**

| | |
|---|---|
| **Pair** | `#FFFFFF` on `#FF3D2E` (accent) / `#FF2E7A` (accentHot) |
| **Ratio** | **3.52:1** / **3.55:1** — passes large+bold (≥14pt bold), **fails normal** |
| **Context** | `ForgeButton.accent` uses 13pt bold italic (`ctaLabel`) — qualifies as large text ✓ |
| **Risk** | If CTA label size drops or non-bold variant added, fails immediately |
| **Fix** | Darken gradient end stops by 5% luminance or use `neutral.1000` off-white for 4.5:1 headroom |

---

### SB-010 — Border color insufficient as sole separator **(Medium)**

| | |
|---|---|
| **Pair** | `border` (`#D9D9D9`) on `background` |
| **Ratio** | **1.41:1** — fails UI component AA (3:1) |
| **Usage** | Card strokes, dividers, timeline connectors — 40+ instances |
| **Mitigation** | Paired with layout whitespace; still fails for low-vision users relying on edges |
| **Fix** | Spec `border.subtle` @ 15% black is same; bump to 25% (`#BFBFBF`, ~2.0:1) or 2pt `border.emphasis` on interactive cards |

---

### SB-013 — `accentBlue.opacity(0.5)` chart labels fail **(Medium)**

| | |
|---|---|
| **File** | `ProteinTrackerView.swift:123` |
| **Pair** | 50% blue on white |
| **Ratio** | **2.14:1** |
| **Fix** | Full-opacity `accentBlue` for data labels; 50% only for non-text grid lines |

---

### SB-014 — Session header secondary labels at 35–55% white on black **(Medium)**

| | |
|---|---|
| **File** | `WorkoutSessionHeaderView.swift:57–63, 168, 202` |
| **Pairs** | White @ 35% on inverse → **3.00:1** (borderline UI); @ 55% → 6.25:1 ✓ |
| **Risk** | Set/rep metadata at lowest opacity fails UI AA |
| **Fix** | Floor inverse secondary text at `surface.opacity(0.55)` minimum |

---

### SB-015 — Implementation hex drift from foundation primitives **(Medium)**

| | |
|---|---|
| **Token** | Spec vs impl |
| `brand.500` | `#FF3D2E` vs `rgb(1.0, 0.24, 0.18)` = `#FF3D2E` ✓ |
| `brand.hot` | `#FF2E7A` vs `rgb(1.0, 0.18, 0.48)` = `#FF2E7A` ✓ |
| `blue.500` | `#2663EB` vs `rgb(0.15, 0.39, 0.92)` = `#2663EB` ✓ |
| `green.500` | `#00B86B` vs `rgb(0, 0.72, 0.42)` = `#00B86B` ✓ |
| `red.500` | `#DB2626` vs `rgb(0.86, 0.15, 0.15)` = `#DB2626` ✓ |
| `text.muted` | `neutral.500@85%` vs `gray@60%` | **✗ Mismatch** |
| `text.secondary` | `neutral.500` full | Not implemented as named token |

---

### SB-017 — Shadows use hardcoded black opacity **(Low)**

| | |
|---|---|
| **Files** | `ForgeFloatingTabBar`, `TodayView`, `TodayDisclosureSection`, `TodayExerciseStrip` |
| **Values** | `black @ 4–12%` — not from `elevation.*` tokens |
| **Dark risk** | Foundation says shadows light-mode only; dark uses `surface.elevated` — moot until dark mode ships |

---

### SB-018 — `destructive` only on Settings; no error surface token **(Low)**

| | |
|---|---|
| **Pair** | `#DB2626` on white = **4.86:1** ✓ |
| **Gap** | No `color.text.error` or `color.surface.error` for inline validation states |

---

## Contrast ratio table (computed)

| Pair | Ratio | Normal AA | Large AA | UI AA | Notes |
|---|---|---|---|---|---|
| `foreground` on `background` | 21.00:1 | ✓ | ✓ | ✓ | Primary text |
| `neutral.500` on `background` | 3.26:1 | ✗ | ✓ | ✓ | Spec `text.secondary` |
| `neutral.500@85%` on `background` | 2.64:1 | ✗ | ✗ | ✗ | Spec `text.muted` |
| **`muted` (impl) on `background`** | **1.92:1** | **✗** | **✗** | **✗** | **84 usages** |
| `surface` on `surfaceInverse` | 21.00:1 | ✓ | ✓ | ✓ | CTA inverse |
| `accent` on `background` | 3.52:1 | ✗ | ✓ | ✓ | Icon/UI only |
| `white` on `accent` | 3.52:1 | ✗ | ✓ | ✓ | CTA label (13pt bold) |
| `accentBlue` on `background` | 5.16:1 | ✓ | ✓ | ✓ | Protein domain ✓ |
| **`accentGreen` on `background`** | **2.60:1** | **✗** | **✗** | **✗** | Readiness text |
| **`accentAmber` on `background`** | **2.07:1** | **✗** | **✗** | **✗** | Warning text |
| `destructive` on `background` | 4.86:1 | ✓ | ✓ | ✓ | |
| `border` on `background` | 1.41:1 | ✗ | ✗ | ✗ | Decorative only |
| `accent` on `surfaceInverse` | 5.96:1 | ✓ | ✓ | ✓ | Hero eyebrow |
| `white@55%` on inverse | 6.25:1 | ✓ | ✓ | ✓ | Session metadata |
| `white@35%` on inverse | 3.00:1 | ✗ | ✗ | ✓ | Borderline |
| `accentBlue@50%` on white | 2.14:1 | ✗ | ✗ | ✗ | Chart labels |
| `muted@40%` on white | 1.27:1 | ✗ | ✗ | ✗ | Chart fallback |

---

## Specs produced (semantic color mapping per screen)

Mappings use **target** semantic tokens from `foundation_tokens.md`. ✗ = current violation.

### App shell

| Screen ID | Background | Primary text | Secondary text | Accent | Surface | Notes |
|---|---|---|---|---|---|---|
| S-001–003 | `color.background.primary` | `color.text.primary` | `color.text.secondary` | — | `color.surface` | ✗ forced light |

### Onboarding (S-010–021)

| Screen ID | Background | Primary text | Secondary text | CTA | Accent marks |
|---|---|---|---|---|---|
| S-010 Welcome | `background.primary` | `text.primary` | `text.secondary` | `gradient.action.primary` + `text.onInverse` | `action.primary` 48×3 mark |
| S-011–019 Steps | same | same | `text.secondary` (not muted) | — | Selected row: `action.primary` stroke |
| S-020 Photo | same | same | `text.secondary` | — | — |
| S-021 Plan | same | same | `text.secondary` | `gradient.action.primary` | ✗ `.tint(accent)` on toggles |

### Today tab (S-030–035)

| Screen ID | Background | Hero | Metrics | Section accent | Status |
|---|---|---|---|---|---|
| S-030 Empty | `background.primary` | — | — | `action.primary` | ✗ muted empty copy |
| S-032 Rest day | same | `surface.inverse` + `text.onInverse` | `readiness.high` bar only | `readiness.*` | ✓ hero inverse |
| S-033 Workout ready | same | `surface.inverse` + `accent` eyebrow | `accent.protein` tile, `readiness.*` tile | `action.primary` | ✗ accent on gear btn |
| S-034 Regenerating | same | inverse + `action.primary` spinner | — | `action.primary` | ✓ |
| S-035 Completed | same | inverse + `status.success` badge | `text.secondary` | `status.success` | ✗ green text on white in badge |

### Train tab (S-040–042)

| Element | Token |
|---|---|
| Background | `background.primary` |
| Hero card | `surface.inverse`, eyebrow `action.primary` |
| Section header | `action.primary` |
| History metadata | `text.secondary` |
| Exercise library header | `action.primary` |

### Protein tab (S-050–053)

| Element | Token | Current |
|---|---|---|
| Background | `background.primary` | ✓ |
| Hero / progress | `accent.protein` | ✓ `accentBlue` |
| Section headers | `accent.protein` | ✓ |
| Fast-add chips | `accent.protein` stroke | ✓ |
| Meal metadata | `text.secondary` | ✗ `muted` |
| Chart miss indicator | `text.secondary` | ✗ `muted@40%` |

### Coach (S-060)

| Element | Token | Current |
|---|---|---|
| Banner | `surface.inverse` | ✗ `accent` fill |
| User bubble | `action.primary` | ✓ |
| Assistant bubble | `surface` + `text.primary` | ✓ |
| Input placeholder | `text.secondary` | ✗ `muted` |

### Workout session (S-070–082)

| Element | Token | Current |
|---|---|---|
| Header bg | `surface.inverse` | ✓ |
| Progress ring | `gradient.action.primary` | ✓ |
| Focus label | `action.primary` solid | ✗ `focusGradient` text |
| Set metadata | `text.onInverse` @ ≥55% | ✗ some @ 35% |
| Complete CTA | `action.primary` | ✓ |
| Summary metrics | `action.primary` / `status.success` / `status.warning` as **bars only** | ✗ colored label text |

### Progress dashboard (S-055)

| Element | Token | Current |
|---|---|---|
| Background | `background.primary` | ✓ |
| Compliance protein | `accent.protein` | ✗ shared with `accent` in places |
| Compliance workouts | `action.primary` | ✓ |
| E1RM chart | `foreground` line | ✗ `accent` line |
| Volume chart | `foreground` + `text.secondary` | ✗ `accent@85%` |
| Recovery bars | `readiness.*` fill | ✓ tint |
| Recovery % text | `text.primary` | ✗ `readiness()` color on white |

### Settings (S-090–095)

| Element | Token | Current |
|---|---|---|
| Background | `background.primary` | ✓ |
| Section labels | `text.secondary` | ✗ `muted` |
| Nav action text | `text.primary` | ✗ `accent` |
| Destructive | `action.destructive` | ✓ |
| Toggle tint | `foreground` | ✗ global `accent` tint |

### Exercise library / detail (S-100–103)

| Element | Token | Current |
|---|---|---|
| Background | `background.primary` | ✓ |
| Filter amber | `status.warning` icon only | ✗ amber text |
| Tab selected | `text.primary` | ✓ |
| Tab unselected | `text.secondary` | ✗ `muted` |
| Cues dot | `action.primary` | ✓ |

### Tab bar (S-003)

| State | Token | Current |
|---|---|---|
| Bar surface | `surface` + `elevation.1` | ✓ |
| Selected icon/label | `action.primary` | ✓ |
| Unselected icon/label | `text.secondary` | ✗ `muted` @ 10pt |
| Selected pill bg | `action.primary` @ 12% | ✓ |

---

## Coverage log

| Timestamp | Action | Result |
|---|---|---|
| T+0 | Read `foundation_tokens.md` | 28 primitives, 17 semantic, 9 pre-check pairs |
| T+1 | Read `ForgeColors.swift` | 13 colors, 2 gradients, no dark mode |
| T+2 | Read `HotBodApp.swift` | `.preferredColorScheme(.light)`, `.tint(accent)` |
| T+3 | `rg ForgeColors` across 27 Swift files | 85 accent, 84 muted, 19 accent-as-text |
| T+4 | Computed 30 contrast pairs (Python WCAG 2.1) | 6 critical failures |
| T+5 | Mapped 11 screen groups to semantic tokens | 38 violations flagged |
| T+6 | Cross-checked `current_tokens.md` | Confirmed gaps align |

**Files with highest color risk (muted + accent spill):**

1. `ProgressDashboardView.swift` — 11 muted, 11 accent
2. `SettingsView.swift` — 10 muted, 4 accent
3. `TodayView.swift` — 8 muted, 2 accent
4. `BodyProgressView.swift` — 7 muted
5. `OnboardingViews.swift` — 6 muted, 4 accent

---

## Open questions

1. **Muted intent:** Was `gray.opacity(0.6)` chosen for a softer aesthetic despite contrast cost, or is it an accidental drift from `neutral.500`? Decision affects whether fix is `text.secondary` or a new lighter token on `#F5F5F5` surfaces only.

2. **Readiness colors on white:** Should readiness % be **text** (needs darkened primitives) or **icon/bar-only** with neutral text? Foundation implies colored status tokens but doesn't specify text-vs-chrome.

3. **Dark mode priority:** Ship dark mode in MVP or post-MVP? Forced light is a hard blocker for App Store accessibility narrative — need product call.

4. **Chart palette:** Should analytics charts use monochromatic `foreground` + weight, or domain colors (blue=protein, red=training)? Current spill suggests no chart palette decision.

5. **Gradient scope:** Confirm `focusGradient` is retired except CTA backgrounds — currently leaks to timeline caption text.

6. **Increase Contrast:** Adopt automatic bump (secondary→primary) or design a dedicated high-contrast primitive ramp?

7. **Border visibility:** Accept 1.41:1 hairline as decorative (current) or enforce 2pt `border.emphasis` on all `ForgeCard` edges?

8. **Spec pre-check discrepancy:** Foundation claims `neutral.500` = 4.6:1; computed 3.26:1. Reconcile before implementation to avoid false confidence.

---

## Recommended fix priority

| Priority | Action | Findings |
|---|---|---|
| P0 | Replace `ForgeColors.muted` text usages with `text.secondary` | SB-001, SB-003, SB-011 |
| P0 | Remove `.preferredColorScheme(.light)`; add dark semantic tokens | SB-002 |
| P1 | Readiness/status colors → chrome only on white surfaces | SB-004, SB-005 |
| P1 | Remove `focusGradient` from text; restrict gradients to CTAs | SB-006 |
| P1 | Scope accent per feature; remove global tint | SB-008, SB-012 |
| P2 | Implement semantic `ForgeColors` API with `ColorScheme` | SB-009 |
| P2 | Add `accessibilityContrast` overrides | SB-016 |
| P3 | Elevation token file; border emphasis bump | SB-010, SB-017 |
