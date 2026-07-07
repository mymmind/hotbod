# Phase 3 — Cross-Validation Report

**Date:** 2026-07-07  
**Orchestrator:** Lead Designer pass after Subagents A–H

---

## 1. Token Conflict Reconciliation

| Conflict | Subagents | Resolution |
|---|---|---|
| Horizontal margin 16 vs 20 | C, D | **Unified:** `space.5` (20pt) for screen margins; `space.4` (16pt) for card internals. Settings body changes from 16→20. |
| Caption color muted vs secondary | B, foundation | **Unified:** `color.text.secondary` for all 13pt metadata; deprecate `ForgeColors.muted` for text |
| Motion quick 220ms vs motion.fast 150ms | G, foundation | **Unified:** Implement `ForgeMotion.quick` → 150ms; rename old 220ms usages to `motion.base` if needed |
| Tab icon 18pt vs icon.md 20pt | D, foundation | **Justified exception:** `icon.tab` = 18pt documented in foundation |
| Radius 0 vs 16 vs 32 | C, D | **Named variants:** `radius.brutalist` (0), `radius.soft` (16), `radius.pill` (32) — no silent mixing |
| Coach scroll clearance | C, E | **Fix:** Apply `forgeFloatingTabBarClearance()` to Coach ScrollView; remove duplicate 104pt on input |

---

## 2. Component Reuse — Canonical Button Spec

| Variant | Maps from | Height | Radius | Fill | Label |
|---|---|---|---|---|---|
| `Button.Primary` | `ForgeButton.accent` | ≥50pt (18V pad) | `radius.pill` | `gradient.action.primary` | `type.cta`, uppercase |
| `Button.PrimarySolid` | `ForgeButton.primary` | ≥48pt | `radius.none` | `surface.inverse` | `type.cta` |
| `Button.Secondary` | `ForgeButton.secondary` | ≥48pt | `radius.none` | `surface` + border | `type.label` |
| `Button.Inverse` | `ForgeButton.inverse` | ≥48pt | `radius.none` | `surface` on dark | `type.label` |
| `Button.Destructive` | Settings destructive row | ≥44pt | `radius.none` | transparent | `type.body` + `action.destructive` |
| `Button.System` | Coach Apply | system | system | `.borderedProminent` | sentence case |

**Collapse rule:** No new button styles without orchestrator approval.

---

## 3. State Completeness

| Component | Missing states | Action |
|---|---|---|
| `ForgeButton` | disabled, focused | Add `.disabled()` opacity 0.4 + 3:1 contrast check |
| `ForgeHeaderBackButton` | pressed visual, 44pt hit | Expand hit area |
| `ForgeFloatingTabBar` | pressed, accessibility selected | Add traits + VO labels |
| `ForgeCard` | N/A for static container | Documented |
| `SelectableRow` | focused | Add focus ring on keyboard |
| `ForgeTextField` | error | Add error border `action.destructive` |

---

## 4. Accessibility Gate

| Gate | Status | Fix count |
|---|---|---|
| WCAG contrast body 4.5:1 | **FAIL** → **PASS after spec** | Replace muted text (84 usages) |
| Touch target 44pt | **FAIL** → **PASS after spec** | 6 controls expanded |
| Dynamic Type | **FAIL** → **PASS after spec** | Migrate ForgeTypography |
| VoiceOver labels | **FAIL** → **PASS after spec** | Label all interactives per screen spec |
| Reduce Motion | **FAIL** → **PASS after spec** | Gate ForgeMotion + Pow |
| Dark mode | **FAIL** → **PASS after spec** | Remove forced light; semantic colors |

---

## 5. Dark Mode Gate

All semantic tokens in `foundation_tokens.md` have dark primitives. Implementation removes `.preferredColorScheme(.light)`.

---

## 6. Dynamic Type Gate

Spec requires:
- Remove `lineLimit(1)` on subtitles without truncation alternative
- Replace `fixedSize` on titles with wrapping
- `minimumScaleFactor(0.8)` on hero metrics only

---

## 7. HIG Exceptions (Defended)

| Exception | Reason | Review date |
|---|---|---|
| Custom `ForgeFloatingTabBar` | Brand differentiation; 5-tab fitness app | Keep; add a11y |
| Brutalist `radius.none` cards | AGENTS.md brutalist UI | Keep in Core; Today uses `radius.soft` |
| Uppercase CTA labels | Brand voice | Keep; ensure contrast |
| No system `TabView` | Floating capsule brand | Keep |
| 11-step onboarding | Comprehensive profile for generation | Reduce to skippable sections in v2 |

---

## 8. Finding Severity Totals (All Subagents)

| Severity | Count |
|---|---|
| Critical | 28 |
| High | 33 |
| Medium | 34 |
| Low | 13 |
| **Total** | **108** |

---

## 9. Systemic Issues Resolved by Spec

1. Single spacing scale — no 16/20 drift
2. Single type ramp with Dynamic Type
3. Semantic colors with dark mode
4. One button component family
5. Universal 44pt touch targets

---

## 10. Cross-Validation Status

**PASS** — ready for `REDESIGN_SPEC.md` collation.
