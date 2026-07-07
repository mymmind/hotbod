# Subagent D — Component & Touch Target Audit

**Agent:** D (Components)  
**Date:** 2026-07-07  
**Scope:** `ForgeButton`, `ForgeHeaderBackButton`, `ForgeFloatingTabBar`  
**Sources:** `component_manifest.md`, `foundation_tokens.md`, `ForgeButton.swift`, `ForgeScreenHeader.swift`, `ForgeFloatingTabBar.swift`

---

## Executive Summary

| Metric | Value |
|---|---|
| Components audited | 3 |
| Total findings | 14 |
| **Critical** | **4** |
| High | 4 |
| Medium | 4 |
| Low | 2 |

**Critical count: 4**

Primary blockers before redesign sign-off:
1. `ForgeHeaderBackButton` ships a 36×36 visible control with no hit-area expansion (violates `target.min`).
2. `ForgeButton` has no explicit `disabled` state — only `isLoading` disables interaction.
3. `ForgeFloatingTabBar` tab items lack pressed-state feedback and use sub-minimum selected capsule height (32pt).
4. `ForgeFloatingTabBar` hardcodes `Font.system(size: 10)` — bypasses Dynamic Type and fails caption contrast guidance.

---

## C-001 `ForgeButton`

**File:** `HotBod/Core/Components/ForgeButton.swift`  
**Manifest ID:** C-001  
**API:** `title: String`, `style: ForgeButtonStyle`, `isLoading: Bool`, `action: () -> Void`

### Shared Anatomy

| Property | Token / Value | Implementation |
|---|---|---|
| Layout | Full-width (`frame(maxWidth: .infinity)`) | ✓ matches |
| Label casing | Uppercased | ✓ |
| Press feedback | `scaleEffect(0.97)` via `ForgePressButtonStyle` | ✓ |
| Press animation | `ForgeMotion.quick` (220ms smooth) | ⚠ drift from `motion.fast` (150ms) |
| Hit area (intrinsic height) | ≥ `target.min` (44pt) | ✓ ~45pt (non-accent), ~49pt (accent) |
| Interaction lock | `.disabled(isLoading)` only | ✗ no `isDisabled` prop |

### Variant Matrix — Default State

| Token | `.primary` | `.inverse` | `.secondary` | `.accent` |
|---|---|---|---|---|
| **Semantic role** | `Button.PrimarySolid` | `Button.Inverse` | `Button.Secondary` | `Button.Primary` (CTA) |
| **Background** | `color.surface.inverse` | `color.surface` | `color.surface` | `gradient.action.primary` |
| **Foreground** | `color.text.onInverse` | `color.text.primary` | `color.text.primary` | `color.text.onInverse` |
| **Typography** | `type.cta` → `ForgeTypography.caption` | `type.cta` → caption | `type.cta` → caption | `type.cta` → `ForgeTypography.ctaLabel` (bold italic) |
| **Tracking** | `tracking.tight` (1.2) | 1.2 | 1.2 | `tracking.cta` (1.4) |
| **V-padding** | `space.4` (16pt) | 16pt | 16pt | 18pt (non-token; between space.4–5) |
| **H-padding** | implicit via full-width | implicit | implicit | implicit |
| **Radius** | `radius.none` (0) | `radius.none` | `radius.none` | `radius.pill` (32) |
| **Border** | none | none | `border.hairline` (1pt) `color.text.primary`* | none |
| **Shadow** | `elevation.0` | `elevation.0` | `elevation.0` | `elevation.2` (brand 35% / blur 12 / y 6) |
| **Min height (est.)** | ~45pt | ~45pt | ~45pt | ~49pt |

\*Implementation uses `ForgeColors.foreground` (hard black) instead of `color.border.subtle`.

### State Specifications

#### Default
- All four variants render as above.
- Label visible; no spinner.

#### Pressed
| Property | All variants |
|---|---|
| Transform | `scale(0.97)` |
| Duration | 220ms smooth (`ForgeMotion.quick`) |
| Opacity | unchanged |
| Shadow | unchanged (accent shadow persists while pressed) |
| Reduce Motion | Should snap to `motion.instant` or opacity-only — **not implemented** |

#### Disabled (SPEC REQUIRED — NOT IMPLEMENTED)
| Property | Spec |
|---|---|
| Interaction | `.disabled(true)` — no action fired |
| Opacity | 0.4 (recommended; align with system) |
| Background | desaturated / flat (accent → flat `color.action.primary` @ 40%) |
| Border (secondary) | `color.border.subtle` @ 40% |
| Shadow | `elevation.0` (remove accent shadow) |
| Label | unchanged casing; `color.text.secondary` |
| **Current** | Only `isLoading` disables; no visual disabled state |

#### Focused (SPEC REQUIRED — NOT IMPLEMENTED)
| Property | Spec |
|---|---|
| Trigger | Keyboard Tab / Switch Control / external keyboard |
| Ring | 2pt `color.action.primary` offset 2pt (or system `focusEffect`) |
| Radius | Match variant (`radius.none` or `radius.pill`) |
| **Current** | No focus ring |

#### Loading
| Property | `.primary` / `.accent` | `.inverse` / `.secondary` |
|---|---|---|
| Spinner | `ProgressView` inline, leading | same |
| Spinner tint | `color.text.onInverse` | `color.text.primary` |
| Label | title remains visible beside spinner | same |
| Interaction | disabled | disabled |
| Press scale | suppressed via `.disabled` | suppressed |

#### Selected / Error / Success / Empty
N/A per manifest — justified.

### Per-Variant Usage Guidance

| Style | Surface context | Example screens |
|---|---|---|
| `.accent` | Light `color.background.primary` — primary CTA | Today hero, Session complete, Onboarding continue |
| `.primary` | Light surfaces — high-contrast solid | Rare; black fill on white |
| `.inverse` | `color.surface.inverse` heroes | `ForgeHeroCard` on black |
| `.secondary` | Paired with accent — cancel / alternate | Empty state retry pair, onboarding back |

### Accessibility

| Requirement | Status |
|---|---|
| Minimum touch height 44pt | ✓ (intrinsic) |
| `accessibilityLabel` | ✗ not set (relies on title text — OK if title is descriptive) |
| `accessibilityAddTraits(.isButton)` | implicit via `Button` |
| Loading announces progress | ✗ no `accessibilityValue` / `accessibilityHint` |
| Disabled announces state | ✗ not implemented |

---

## C-005 `ForgeHeaderBackButton`

**File:** `HotBod/Core/Components/ForgeScreenHeader.swift` (lines 140–154)  
**Manifest ID:** C-005  
**API:** `action: () -> Void`

### Anatomy — Default State

| Property | Token / Value | Implementation |
|---|---|---|
| Icon | `chevron.left` SF Symbol | ✓ |
| Icon font | `type.body` weight `.bold` (~16pt) | ✓ |
| Icon color | `color.text.primary` | ✓ `ForgeColors.foreground` |
| Visible frame | 36×36pt circle | ✗ below `target.compact` max without expansion |
| Background | Circle fill `color.text.primary` @ 6% | ✓ subtle |
| Button style | `.plain` | ✓ |
| Accessibility label | `"Back"` | ✓ |
| Hit area | **should be 44×44** | ✗ **36×36 only — CRITICAL** |

### State Specifications

#### Default
As anatomy table above.

#### Pressed
| Property | Spec | Current |
|---|---|---|
| Background | Circle fill → 12% opacity | ✗ no visual change |
| Scale | optional `0.95` | ✗ none |
| Haptic | none (per motion tokens) | ✓ |

#### Disabled
N/A — back is always available in current usage. If needed: 40% opacity, no action.

#### Focused
| Property | Spec | Current |
|---|---|---|
| Focus ring | 2pt accent ring outside 44pt hit area | ✗ not implemented |

#### Selected / Loading / Error / Success / Empty
N/A.

### Required Fix (Critical)

```swift
// Spec: expand hit area without changing visible 36pt circle
.frame(width: 44, height: 44)
.contentShape(Circle())
// OR: .padding(4) around 36pt content inside 44pt frame
```

Visible circle may remain 36pt (`target.compact`); interactive bounds must be 44×44 (`target.min`).

### Usage Context

- `ForgeScreenHeader` `.compact` style — `leading` slot.
- Appears on pushed screens: Exercise Library, settings sub-flows, detail views.

---

## C-010 `ForgeFloatingTabBar`

**File:** `HotBod/Core/Components/ForgeFloatingTabBar.swift`  
**Manifest ID:** C-010  
**Related:** C-011 `ForgeTabBarMetrics.scrollClearance = 104`

### Container Anatomy — Default

| Property | Token / Value | Implementation |
|---|---|---|
| Shape | `Capsule` | ✓ |
| Fill | `color.surface` | ✓ |
| Border | `border.hairline` `color.border.subtle` | ✓ `ForgeColors.border` |
| Shadow | `elevation.1` (black 12% / blur 20 / y 8) | ✓ light; ✗ always on (dark should be `elevation.0`) |
| Outer padding H | `space.2` (8pt) | ✓ |
| Outer padding V | `space.2` (8pt) | ✓ |
| Tab distribution | `HStack(spacing: 0)`, equal `maxWidth` | ✓ |
| Tab count | 4 (`AppRouter.MainTab.allCases`) | ✓ |

### Tab Item Anatomy

| Property | Unselected | Selected |
|---|---|---|
| Icon size | `icon.tab` (18pt) | 18pt |
| Icon weight | `.regular` | `.semibold` |
| Icon frame | 44×32pt | 44×32pt |
| Selection capsule | none | `color.action.primary` @ 12% fill, `Capsule` |
| Label font | **should be `type.tabLabel`** | semibold variant |
| Label size | `type.tabLabel` (`.caption2` ~11pt) | same |
| Label color | `color.text.secondary` | `color.action.primary` |
| Item layout | `VStack(spacing: space.1)` (4pt) | same |
| Button style | `.plain` | `.plain` |
| Selection animation | `ForgeMotion.quick` | ✓ |

**Implementation drift:** label uses `Font.system(size: 10, weight:)` — fixed 10pt, not Dynamic Type. Unselected color uses `ForgeColors.muted` (gray 60%) — fails `text.muted` AA at caption sizes per foundation contrast pre-check.

### Estimated Tab Item Touch Target

| Dimension | Calculation | Meets 44pt? |
|---|---|---|
| Width | `screenWidth / 4` inside capsule | ✓ |
| Height | 32 (icon frame) + 4 (spacing) + ~10–12 (label) ≈ 46–48pt | ✓ (full `VStack` is tappable) |
| Icon-only sub-target | 44×32 selected capsule | ✗ **32pt height — CRITICAL** if user taps icon band only |

The full `Button` label includes text, so the effective hit area likely clears 44pt vertically. The **selected capsule visual** at 32pt is below minimum and misleads perceived tap zone.

### State Specifications

#### Default (Unselected)
- Icon + label as unselected column above.
- Foreground: `color.text.secondary` (spec); current `ForgeColors.muted`.

#### Selected
| Property | Spec | Current |
|---|---|---|
| Icon weight | `.semibold` | ✓ |
| Label weight | `.semibold` | ✓ |
| Capsule | 44×**44**pt (expand to `target.min`) | ✗ 44×32 |
| Color | `color.action.primary` | ✓ |
| Animation | `motion.fast` cross-fade | ✓ `ForgeMotion.quick` |

#### Pressed (SPEC REQUIRED — NOT IMPLEMENTED)
| Property | Spec | Current |
|---|---|---|
| Icon scale | `0.92` or capsule fill → 20% | ✗ `.plain` — no feedback |
| Label | no change | ✓ |
| Duration | `motion.fast` (150ms) | — |

#### Disabled / Focused / Loading / Error / Success / Empty
N/A per manifest.

### Scroll Clearance (C-011)

| Property | Value |
|---|---|
| `ForgeTabBarMetrics.scrollClearance` | 104pt |
| Applied via | `.forgeFloatingTabBarClearance()` → `contentMargins(.bottom, 104, for: .scrollContent)` |
| Formula (document) | tab bar intrinsic height + safe area inset + `space.2` breathing room |

Intrinsic bar height estimate: 8 + 32 + 4 + ~12 + 8 ≈ **64pt** + safe area bottom (~34pt on Face ID) ≈ 98pt. 104pt provides ~6pt buffer — acceptable.

### Accessibility

| Requirement | Status |
|---|---|
| `accessibilityLabel` per tab | ✗ not set (relies on `Text(tab.title)`) |
| `accessibilityAddTraits(.isSelected)` | ✗ not set on selected tab |
| Tab bar container trait | ✗ should be `.tabBar` or `TabView` semantics |
| Reduce Motion | selection animation should respect `@Environment(\.accessibilityReduceMotion)` |

---

## Findings Register

| # | Severity | Component | Finding | Spec / Token Reference | Recommendation |
|---|---|---|---|---|---|
| F-01 | **CRITICAL** | `ForgeHeaderBackButton` | Visible + hit area 36×36pt; no `.contentShape` or padding expansion | `target.min` = 44×44 | Wrap in 44×44 frame; keep 36pt visible circle centered |
| F-02 | **CRITICAL** | `ForgeButton` | No `isDisabled` prop or disabled visual state; only `isLoading` disables | Manifest C-001 disabled ✓ | Add `var isDisabled: Bool`; opacity 0.4; remove shadow when disabled |
| F-03 | **CRITICAL** | `ForgeFloatingTabBar` | Selected icon capsule 44×32pt — 32pt < `target.min` height | `target.min`, C-010 | Increase icon frame to 44×44 or add invisible 44pt hit padding |
| F-04 | **CRITICAL** | `ForgeFloatingTabBar` | `Font.system(size: 10)` hardcoded for labels — no Dynamic Type | `type.tabLabel`, typography rule §3 | Replace with `Font.caption2.weight(...)` or `ForgeTypography.tabLabel` |
| F-05 | HIGH | `ForgeButton` | No keyboard / Switch Control focus ring | Manifest C-001 focused ✓ | Add `@FocusState` or `.focusable()` with 2pt accent ring |
| F-06 | HIGH | `ForgeFloatingTabBar` | No pressed-state visual feedback (`.plain` button) | Manifest C-010 pressed ? | Add `ForgePressButtonStyle` or opacity/scale on `configuration.isPressed` |
| F-07 | HIGH | `ForgeHeaderBackButton` | No pressed-state visual feedback | Manifest C-005 pressed | Increase circle fill to 12% on press |
| F-08 | HIGH | `ForgeFloatingTabBar` | Unselected label uses `ForgeColors.muted` — fails AA at ≤13pt | Contrast pre-check §12 | Use `color.text.secondary` for unselected labels |
| F-09 | MEDIUM | `ForgeButton` | Secondary border uses `ForgeColors.foreground` not `color.border.subtle` | `color.border.subtle` | Map to semantic border token |
| F-10 | MEDIUM | `ForgeButton` | Accent V-padding 18pt is off-scale (between `space.4` and `space.5`) | Spacing scale §1 | Align to `space.5` (20pt) or document as `space.ctaVertical` |
| F-11 | MEDIUM | `ForgeFloatingTabBar` | Shadow always applied — dark mode should use `elevation.0` + `surface.elevated` | Elevation §6 | Gate shadow on `colorScheme == .light` |
| F-12 | MEDIUM | `ForgeButton` | `ForgeMotion.quick` = 220ms vs `motion.fast` = 150ms | Motion §7 | Rename or align duration to 150ms |
| F-13 | LOW | `ForgeButton` | Loading state lacks `accessibilityValue("Loading")` | a11y best practice | Add trait `.updatesFrequently` + label when `isLoading` |
| F-14 | LOW | `ForgeFloatingTabBar` | Selected tab missing `accessibilityAddTraits(.isSelected)` | a11y best practice | Add on selected `tabButton` |

---

## Implementation Priority

### P0 — Ship blockers (Critical)
1. Expand `ForgeHeaderBackButton` hit area to 44×44 (F-01).
2. Add `ForgeButton` disabled API + visuals (F-02).
3. Fix tab icon frame / capsule to 44pt min height (F-03).
4. Replace fixed 10pt tab label with `type.tabLabel` (F-04).

### P1 — Redesign parity (High)
5. Focus rings on `ForgeButton` (F-05).
6. Press feedback on tab bar + back button (F-06, F-07).
7. Tab label color → `color.text.secondary` (F-08).

### P2 — Token alignment (Medium / Low)
8. Border, spacing, motion, elevation token drift (F-09–F-12).
9. Accessibility polish (F-13, F-14).

---

## Verification Checklist

- [ ] `ForgeHeaderBackButton` — VoiceOver double-tap area ≥ 44×44 on device
- [ ] `ForgeButton` — all 4 styles × {default, pressed, disabled, loading} captured in preview catalog
- [ ] `ForgeButton` — Tab key shows focus ring on accent CTA
- [ ] `ForgeFloatingTabBar` — Dynamic Type XXL does not clip labels
- [ ] `ForgeFloatingTabBar` — selected capsule height ≥ 44pt
- [ ] Dark mode — tab bar shadow suppressed; surface contrast sufficient
- [ ] Reduce Motion — press scale disabled; opacity fallback only

---

## Cross-References

| Document | Relevance |
|---|---|
| `docs/design/foundation_tokens.md` | §9 Touch Targets, §3 Typography, §6 Elevation |
| `docs/design/component_manifest.md` | C-001, C-005, C-010, C-011 state matrices |
| `AGENTS.md` | Brutalist UI, `ForgeColors` semantic accents, no scattered gradients |

---

*End of Subagent D report. Critical count: **4**.*
