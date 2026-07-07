# Subagent G — Motion, State & Interaction Audit

**Agent:** G (Motion)  
**Date:** 2026-07-07  
**Scope:** `ForgeMotion.swift`, all `withAnimation` / `.transition` / `changeEffect` usage in `HotBod/`  
**Sources:** `foundation_tokens.md` §7, `current_tokens.md` §7, `ForgeMotion.swift`, 18 consumer files

---

## Executive Summary

| Metric | Value |
|---|---|
| Files with motion calls | 18 |
| `ForgeMotion` token definitions | 5 durations + 5 transitions + 3 Pow effects |
| `reduceMotion` checks | **0** |
| Haptic call sites | 3 (2 via Pow, 1 raw UIKit) |
| Total findings | 12 |
| **Critical** | **2** |
| High | 4 |
| Medium | 4 |
| Low | 2 |

**Critical count: 2**

Primary blockers before redesign sign-off:
1. No `accessibilityReduceMotion` handling anywhere — Pow effects, transitions, and timed animations always run at full fidelity.
2. Haptic policy violated in the core workout loop — success feedback fires per set, not only on workout completion.

---

## Token Inventory (`ForgeMotion.swift`)

| Implementation | Value | Foundation token | Match? |
|---|---|---|---|
| `standard` | smooth 350ms | `motion.base` 250ms | ✗ +100ms |
| `quick` | smooth 220ms | `motion.fast` 150ms | ✗ +70ms |
| `exercise` | smooth 480ms | *(none)* | ✗ orphan |
| `regenerate` | smooth 550ms | *(none)* | ✗ orphan |
| `regenerateMinimum` | 720ms | *(none)* | ✗ orphan |
| `staggerDelay` | index × 70ms | `motion.stagger` 70ms × index | ✓ |
| `appear` | Pow `movingParts.move(top)` + opacity | `transition.appear` | ✓ intent |
| `rise` | Pow `movingParts.move(bottom)` | `transition.rise` | ✓ intent |
| `exerciseChange` | opacity + offset y 20/−12 | `transition.exercise` | ✓ |
| `disclosureExpand` | opacity + offset y −8/−4 | `transition.disclosure` | ✓ |
| `slideUp` | Pow `movingParts.move(bottom)` | *(none)* | — |

**Pow dependency:** `ForgeMotion.swift` and `MetricCard.swift` import Pow for transitions (`movingParts`) and `changeEffect` modifiers.

---

## Consumer Map

| Pattern | Count | Key files |
|---|---|---|
| `.animation(ForgeMotion.*)` | 22 | `WorkoutSessionView`, `WorkoutSessionHeaderView`, `OnboardingViews`, `TodayView` |
| `withAnimation(ForgeMotion.*)` | 14 | `WorkoutSessionView`, `TodayView`, `SettingsView`, `OnboardingViews` |
| `.transition(ForgeMotion.*)` | 14 | `WorkoutSessionView`, `CoachView`, `SettingsView`, `ForgeCard` |
| `changeEffect` (via extensions) | 3 types | `forgeMetricPulse`, `forgeValidationShake`, `forgeSuccessHaptic` |
| Untokenized animation/transition | 6 | `CoachView` scroll, `ExerciseDemoPlayerView`, `TodayView` overlay |
| Raw UIKit haptic | 1 | `WorkoutSessionView` rest timer |

---

## Findings

### G-001 · CRITICAL · Global `reduceMotion` absent

**Files:** All 18 motion consumers; root gap in `ForgeMotion.swift`  
**Spec:** `foundation_tokens.md` §7 — *"Reduce Motion: All → `motion.instant` or opacity-only cross-fade."*  
**Handoff note:** `ForgeMotion.swift` explicitly listed to *"update durations + reduceMotion"*.

**Evidence:**
```bash
rg "reduceMotion|accessibilityReduceMotion|isReduceMotionEnabled" HotBod/  # 0 matches
```

Every animation path — `Animation.smooth`, Pow `movingParts`, `changeEffect(.jump)`, `changeEffect(.shake)`, infinite spinner — runs unconditionally. Users with vestibular disorders receive full motion including fast shakes and continuous rotation.

**Remediation:** Add `@Environment(\.accessibilityReduceMotion)` helpers on `ForgeMotion` (instant/opacity-only animation resolver, opacity-only transition resolver, Pow effect no-op). Apply at the extension layer so consumers inherit behavior without per-view edits.

---

### G-002 · CRITICAL · Haptic policy violated in workout loop

**Files:** `WorkoutSessionView.swift:128`, `TodayView.swift:247`  
**Spec:** `foundation_tokens.md` §7 — *"Haptics: Success notification only on workout completion — not per button tap."*

| Site | Trigger | Policy |
|---|---|---|
| `WorkoutSessionView` `.forgeSuccessHaptic(value: completedSetsCount)` | Every set logged | ✗ fires 10–30× per session |
| `TodayView` `.forgeSuccessHaptic(value: workout.id)` | Workout card identity change (regenerate/split switch) | ✗ not workout completion |
| `WorkoutSessionView` `UIImpactFeedbackGenerator(.heavy)` | Rest timer reaches 0 | ⚠ untyped; heavy impact ≠ success |

`forgeSuccessHaptic` is wired to `changeEffect(.feedback(hapticNotification: .success))` in `ForgeMotion.swift:80–81`. Because `completedSetsCount` increments on each set, users receive success haptics throughout the session — opposite of the "completion only" rule and likely fatiguing.

**Remediation:** Move success haptic to `WorkoutCompletionView` appearance only. Use `.light` impact or no haptic for set logging. Tokenize rest-end feedback through `ForgeMotion` with reduceMotion guard.

---

### G-003 · HIGH · Duration tokens drift from foundation scale

**File:** `ForgeMotion.swift:5–9`  
**Spec:** `motion.fast` 150ms, `motion.base` 250ms, `motion.slow` 400ms

| Token | Actual | Delta |
|---|---|---|
| `quick` → should be `fast` | 220ms | +70ms (47% slower) |
| `standard` → should be `base` | 350ms | +100ms (40% slower) |
| `exercise` | 480ms | +80ms above `slow` |
| `regenerate` | 550ms | +150ms above `slow` |

Subagent D already flagged `ForgeButton` press at 220ms vs 150ms (F-12). The drift originates in `ForgeMotion.quick` itself — renaming alone won't fix durations.

**Remediation:** Align to foundation scale. Map `exercise` → `motion.slow` (400ms) or add `motion.exercise` to foundation. Collapse `regenerate` into `motion.slow` + `regenerateMinimum` choreography constant.

---

### G-004 · HIGH · Raw UIKit haptic bypasses design system

**File:** `WorkoutSessionView.swift:245`

```swift
UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
```

Issues:
- Instantiates a new generator on every rest-end fire (no `prepare()`)
- Bypasses `ForgeMotion` abstraction — no central haptic registry
- `.heavy` impact is aggressive for a recurring timer event
- No reduceMotion / haptic-preference check

**Remediation:** Add `ForgeMotion.restTimerEnd()` (or similar) using a prepared, reused generator. Respect system haptic settings.

---

### G-005 · HIGH · Infinite spinner without reduceMotion fallback

**File:** `TodayView.swift:628–630` (`ForgeHeroRegeneratingOverlay`)

```swift
.animation(
    isSpinning ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
    value: isSpinning
)
```

Continuous 0.9s rotation loop during regenerate. Combined with blur (1.5pt) and scale (0.97) on the hero card, this is a high-motion loading state with no static alternative.

**Remediation:** When `accessibilityReduceMotion`, show static icon or opacity pulse (non-rotating). Tie minimum display time to `regenerateMinimum` consistently.

---

### G-006 · HIGH · Pow `changeEffect` effects ignore motion preferences

**File:** `ForgeMotion.swift:72–81`

| Modifier | Effect | Consumers |
|---|---|---|
| `forgeMetricPulse` | `jump(height: 4)` | `WorkoutSessionHeaderView`, `ForgeHeroCard`, `TodayMetricTile`, `MetricCard` |
| `forgeValidationShake` | `shake(rate: .fast)` | `CoachView` |
| `forgeSuccessHaptic` | `feedback(.success)` | `WorkoutSessionView`, `TodayView` |

Shake is the highest-risk effect for vestibular accessibility. Jump fires on every metric value change (exercise index, tile values, hero stats). None gate on reduceMotion.

**Remediation:** Wrap each `changeEffect` in a reduceMotion branch (opacity flash or no-op).

---

### G-007 · MEDIUM · Stacked `.animation` modifiers on `WorkoutSessionView`

**File:** `WorkoutSessionView.swift:57–58, 105–106`

```swift
// body
.animation(ForgeMotion.standard, value: showCompletion)
.animation(ForgeMotion.exercise, value: currentExerciseIndex)
// sessionContent
.animation(ForgeMotion.exercise, value: currentExerciseIndex)  // duplicate
.animation(ForgeMotion.standard, value: isResting)
```

`currentExerciseIndex` is animated twice with the same curve. SwiftUI applies multiple `.animation` modifiers in declaration order — last matching modifier wins, but the duplication signals unclear ownership and risks regression when editing.

**Remediation:** Consolidate to one animation modifier per scope; use `withAnimation` at state-change sites for explicit control.

---

### G-008 · MEDIUM · Untokenized `withAnimation` in `CoachView`

**File:** `CoachView.swift:87`

```swift
withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
```

Uses SwiftUI's implicit default animation (≈350ms spring) instead of `ForgeMotion.quick` or `ForgeMotion.standard`. Message list scroll and proposal card (`.transition(ForgeMotion.rise)` + `.animation(ForgeMotion.standard, ...)`) are on different curves.

**Remediation:** `withAnimation(ForgeMotion.quick) { ... }` or instant scroll when reduceMotion.

---

### G-009 · MEDIUM · Inconsistent stagger timing

**Files:** `ForgeMotion.swift:46–47`, `WorkoutSessionHeaderView.swift:136`

| Source | Formula |
|---|---|
| `forgeStaggeredAppear` / `staggerDelay` | index × **70ms** |
| Exercise segment capsules | index × **30ms** |

Today tab entrance cascade (5 tiles at 70ms steps = 350ms total spread) feels slower than header segment ripple (30ms steps). Neither is documented as intentional.

**Remediation:** Use `ForgeMotion.staggerDelay(for:)` everywhere or add `motion.staggerCompact` (30ms) to foundation if deliberate.

---

### G-010 · MEDIUM · Ad-hoc transitions outside `ForgeMotion`

| File | Transition | Issue |
|---|---|---|
| `ExerciseDemoPlayerView.swift:18–26` | `.opacity` only | No directional cue; inconsistent with `forgeExerciseContent` |
| `TodayView.swift:244` | `.opacity + .scale(0.98)` | Bespoke regenerate overlay; not in token set |
| `CoachView.swift:87` | implicit scroll | See G-008 |

**Remediation:** Add `ForgeMotion.crossfade` (opacity-only) for media swaps; `ForgeMotion.overlayAppear` for loading overlays.

---

### G-011 · LOW · Regenerate timing uses magic numbers

**File:** `TodayView.swift:305, 311`

```swift
try? await Task.sleep(for: ForgeMotion.regenerateMinimum)  // 720ms
// ...
try? await Task.sleep(for: .milliseconds(180))              // hardcoded tail
```

`regenerateMinimum` (720ms) ≠ `regenerate` animation duration (550ms). The extra 180ms tail has no named constant or comment tying it to animation settle time. Choreography is fragile if durations change.

**Remediation:** Derive minimum hold from `regenerate` duration + one frame, or name `regenerateSettleDelay`.

---

### G-012 · LOW · `ForgeProgressBar` hardcoded delay

**File:** `ForgeProgressBar.swift:23`

```swift
withAnimation(ForgeMotion.standard.delay(0.2)) { ... }
```

200ms delay is not a foundation token (`motion.stagger` is 70ms × index). Minor drift but should be `ForgeMotion.staggerDelay(for: 2)` ≈ 140ms or a named `motion.barEntranceDelay`.

---

## Haptics Summary

| Location | Type | Trigger frequency | Compliant? |
|---|---|---|---|
| `forgeSuccessHaptic` → `WorkoutSessionView` | Pow success | Per set | ✗ |
| `forgeSuccessHaptic` → `TodayView` | Pow success | Per workout id change | ✗ |
| `UIImpactFeedbackGenerator(.heavy)` → rest timer | UIKit impact | Per rest period end | ⚠ untyped |
| `WorkoutCompletionView` | — | — | ✗ missing |

---

## Reduce Motion Coverage Matrix

| Category | Sites | reduceMotion handled? |
|---|---|---|
| `Animation.smooth` durations | 22 `.animation` + 14 `withAnimation` | ✗ |
| Pow `movingParts` transitions | `appear`, `rise`, `slideUp` | ✗ |
| Offset transitions | `exerciseChange`, `disclosureExpand` | ✗ |
| Pow `changeEffect` | jump, shake, haptic | ✗ |
| Infinite rotation | `ForgeHeroRegeneratingOverlay` | ✗ |
| Press `scaleEffect(0.97)` | `ForgeButton`, `TodayMetricTile` | ✗ |

---

## Recommended `ForgeMotion` API Additions

```swift
enum ForgeMotion {
  static func resolved(_ base: Animation, reduceMotion: Bool) -> Animation
  static func resolvedTransition(_ base: AnyTransition, reduceMotion: Bool) -> AnyTransition
  static func workoutCompleted()  // sole success haptic entry point
  static func restTimerEnded()    // light impact, prepared generator
}
```

---

## Priority Fix Order

1. **G-001 + G-006** — `reduceMotion` resolver at `ForgeMotion` layer (unblocks accessibility sign-off)
2. **G-002 + G-004** — Haptic policy: remove per-set success, add completion-only, tokenize rest timer
3. **G-003** — Duration alignment to foundation tokens
4. **G-005** — Static regenerate overlay for reduceMotion
5. **G-007–G-012** — Consistency cleanup (stacked modifiers, stagger, ad-hoc transitions)

---

## Cross-References

| Related finding | Agent | ID |
|---|---|---|
| Button press 220ms vs 150ms | D (Components) | F-12 |
| Reduce motion on press not implemented | D (Components) | C-001 pressed state |
| `ForgeMotion.swift` handoff item | Foundation | §11 |
