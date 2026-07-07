# Subagent E — Accessibility Auditor

**Audit date:** 2026-07-07  
**Scope:** 54 screen-states (`screen_manifest.md`), 28 components (`component_manifest.md`), `foundation_tokens.md` §7 Motion & §9 Touch Targets, all `accessibility*` call sites in `HotBod/`  
**Standard:** WCAG 2.2 Level AA (mapped to iOS 17+ / VoiceOver / Dynamic Type / Reduce Motion)

---

## Executive Summary

| Metric | Value |
|---|---|
| Screen-states reviewed | 54 |
| Components reviewed | 28 |
| WCAG 2.2 AA criteria evaluated | 22 |
| **Pass** | 6 |
| **Partial** | 4 |
| **Fail** | 12 |
| Total findings | **16** |
| **Critical** | **7** |
| High | 6 |
| Medium | 3 |

**Critical count: 7**

Primary blockers before redesign sign-off:
1. Typography system uses fixed point sizes — Dynamic Type unsupported (1.4.4).
2. VoiceOver labels/traits absent on most interactive controls (1.1.1, 4.1.2).
3. No Reduce Motion handling anywhere in `ForgeMotion` or animation call sites (2.3.3 / Apple HIG).
4. Multiple navigation and session controls below 44pt hit area with no `contentShape` expansion (2.5.8).

---

## Tools / References Used

| Tool / reference | Purpose |
|---|---|
| `docs/design/screen_manifest.md` | Screen-state inventory (54 entries) |
| `docs/design/component_manifest.md` | Component inventory; C-005/C-010 touch-target notes |
| `docs/design/foundation_tokens.md` | §3 Typography (Dynamic Type), §7 Motion (Reduce Motion), §9 Touch Targets, §12 Contrast |
| `rg -i accessibility HotBod/` | 11 `accessibilityLabel` call sites across 6 files |
| `rg 'reduceMotion\|accessibilityReduceMotion\|dynamicTypeSize' HotBod/` | **0 matches** |
| `rg 'Font\.system\(size:' HotBod/` | 10 token + 22 inline fixed sizes |
| `rg '\.frame\(width: (28\|30\|32\|36\|40)' HotBod/` | Sub-44pt interactive controls |
| `ForgeMotion.swift` | Animation tokens; no reduce-motion branch |
| Subagent D (`D_components.md`) | Cross-check on C-001, C-005, C-010 |

---

## WCAG 2.2 AA Conformance Table

| Criterion | Level | Status | Finding(s) | Notes |
|---|---|---|---|---|
| **1.1.1** Non-text Content | A | **Fail** | SE-003, SE-004, SE-007 | Decorative vs functional icons not distinguished; gear, tabs, disclosure chevron unlabeled |
| **1.3.1** Info and Relationships | A | **Fail** | SE-008, SE-012 | Disclosure expanded state not exposed; set inputs lack semantic grouping |
| **1.3.4** Orientation | AA | Pass | — | Portrait-only; no orientation lock observed |
| **1.3.5** Identify Input Purpose | AA | Partial | SE-012 | Settings auth fields lack `textContentType`; onboarding body fields unscoped |
| **1.4.3** Contrast (Minimum) | AA | **Fail** | SE-013, SE-014 | `ForgeColors.muted` @ 13pt fails AA; hero secondary text at 55–70% opacity on black |
| **1.4.4** Resize Text | AA | **Fail** | SE-001, SE-002 | All `ForgeTypography` fixed sizes; session header 8–11pt ad-hoc |
| **1.4.10** Reflow | AA | Partial | SE-001 | No horizontal scroll trap observed at default size; untested at AX5 |
| **1.4.11** Non-text Contrast | AA | Partial | SE-015 | 4pt progress bar and 3pt segment indicators may fail 3:1 on subtle tracks |
| **2.1.1** Keyboard | A | Partial | SE-016 | SwiftUI defaults cover basics; no visible focus on custom controls |
| **2.4.3** Focus Order | A | Pass | — | Linear navigation stacks; no focus traps in sheets |
| **2.4.4** Link Purpose (In Context) | A | Partial | SE-004 | Tab labels visible but not announced to VoiceOver |
| **2.4.6** Headings and Labels | AA | **Fail** | SE-003, SE-011 | Rest timer actions, settings gear, hero secondary CTAs lack accessible names |
| **2.4.7** Focus Visible | AA | **Fail** | SE-016 | `ForgeButton`, `SelectableRow`, tab bar — no focused state in component manifest |
| **2.4.11** Focus Not Obscured (Minimum) | AA | Pass | — | Floating tab bar uses `scrollClearance`; no observed focus clipping |
| **2.5.1** Pointer Gestures | A | Pass | — | No path-only or multi-finger gestures required |
| **2.5.2** Pointer Cancellation | A | Pass | — | Standard `Button` up-inside activation |
| **2.5.3** Label in Name | A | Partial | SE-004 | Visible tab text not in accessibility label |
| **2.5.4** Motion Actuation | A | Pass | — | No shake/tilt actuation |
| **2.5.7** Dragging Movements | AA | Pass | — | No drag-only interactions in audited flows |
| **2.5.8** Target Size (Minimum) | AA | **Fail** | SE-006, SE-009, SE-010 | Multiple controls < 44pt (iOS HIG) / some < 24pt (WCAG minimum) |
| **2.3.3** Animation from Interactions | AAA | **Fail** | SE-005 | Maps to Apple Reduce Motion; all Pow/offset/scale animations unconditional |
| **3.2.3** Consistent Navigation | AA | Pass | — | Tab bar + back buttons consistent per flow |
| **3.2.4** Consistent Identification | AA | Partial | SE-003 | Back labeled "Back" in headers but "Exit workout" in session |
| **3.3.2** Labels or Instructions | A | Partial | SE-012 | `ForgeTextField` has visual label; set `TextField` placeholders only |
| **4.1.2** Name, Role, Value | A | **Fail** | SE-003, SE-004, SE-008 | Missing names, selected traits, and values on tabs, disclosure, angle picker |

**Conformance score:** 6 Pass · 4 Partial · 12 Fail (of 22 evaluated criteria)

---

## Theme Coverage

| Theme | Findings | Critical | Pass criteria blocked |
|---|---|---|---|
| **Dynamic Type** | SE-001, SE-002 | 2 | 1.4.4, 1.4.10 |
| **VoiceOver** | SE-003, SE-004, SE-007, SE-008, SE-011, SE-012 | 2 | 1.1.1, 4.1.2, 2.4.6 |
| **Reduce Motion** | SE-005 | 1 | 2.3.3 (AAA; Apple HIG required) |
| **44pt targets** | SE-006, SE-009, SE-010 | 2 | 2.5.8 |
| **Contrast** | SE-013, SE-014, SE-015 | 0 | 1.4.3, 1.4.11 |
| **Focus / keyboard** | SE-016 | 0 | 2.4.7 |

---

## Findings

### SE-001 — Fixed-point typography system-wide

| Field | Value |
|---|---|
| **WCAG** | 1.4.4 Resize Text — **Fail** |
| **Severity** | **Critical** |
| **Theme** | Dynamic Type |
| **Location** | `ForgeTypography.swift` (all 10 tokens); propagates to 54 screens |
| **Current** | `Font.system(size: N, …)` for every token (e.g. `body` = 16pt, `caption` = 13pt) |
| **Evidence** | Foundation §3 mandates `Font.TextStyle` mapping; `rg 'dynamicTypeSize'` → 0 |
| **Recommended** | Replace with `Font.system(.body)`, `.largeTitle`, etc.; add `@ScaledMetric` only for layout caps |
| **Screens** | S-011–S-021 (onboarding), S-030–S-035 (Today), S-082 (session), all C-001–C-028 |
| **Verification** | Settings → Larger Text → AX5: no clipping on S-033 hero, S-082 set table |

---

### SE-002 — Session header ad-hoc sub-minimum text

| Field | Value |
|---|---|
| **WCAG** | 1.4.4 Resize Text — **Fail** |
| **Severity** | **Critical** |
| **Theme** | Dynamic Type |
| **Location** | `WorkoutSessionHeaderView.swift` (C-014); S-082, S-083 |
| **Current** | 10 inline `.font(.system(size:))` including **8pt** stat labels, **9pt** ring denominator, **11pt** metadata |
| **Evidence** | Foundation minimum legible = caption2 (~11pt); 8–9pt fails at default and cannot scale |
| **Recommended** | Map to `type.sessionTitle`, `type.label`, `type.metric`; retire 8–9pt sizes |
| **Verification** | Zero `.system(size:` in file; readable at 200% text size |

---

### SE-003 — App-wide VoiceOver label coverage gap

| Field | Value |
|---|---|
| **WCAG** | 1.1.1, 4.1.2 — **Fail** |
| **Severity** | **Critical** |
| **Theme** | VoiceOver |
| **Location** | Codebase-wide |
| **Current** | Only **11** `accessibilityLabel` usages in 6 files; **0** `accessibilityHint`, `accessibilityValue`, `accessibilityAddTraits`, `accessibilityElement` |
| **Evidence** | `rg accessibility HotBod/` → labels in `WorkoutSessionHeaderView`, `ExerciseDemoPlayerView`, `ForgeScreenHeader`, `ForgeHeroCard` (accessory only), `ExerciseThumbnailView`, `TodayView` (split toggle only) |
| **Unlabeled interactives** | Settings gear (S-033), tab bar (S-003), disclosure sections (S-033), rest +30/Skip (S-083), `SelectableRow`/`SelectableChip` (S-012–S-016), metric tiles, exercise strip chips |
| **Recommended** | Accessibility pass per screen manifest row; minimum viable: name + role + value on every `Button`, `Toggle`, `TextField`, custom hit target |
| **Verification** | VoiceOver rotor → Controls lists every tappable on S-003, S-033, S-082 with meaningful names |

---

### SE-004 — Floating tab bar items unlabeled for VoiceOver

| Field | Value |
|---|---|
| **WCAG** | 4.1.2, 2.5.3 — **Fail** |
| **Severity** | **Critical** |
| **Theme** | VoiceOver |
| **Location** | `ForgeFloatingTabBar.swift` (C-010); S-003 + all tab roots |
| **Current** | `Button` contains `Image` + `Text(tab.title)` but no `.accessibilityLabel`; selected state not exposed via `.accessibilityAddTraits(.isSelected)` |
| **Evidence** | VoiceOver may announce icon glyph name ("house", "dumbbell") inconsistently |
| **Recommended** | `.accessibilityLabel(tab.title)` + `.accessibilityAddTraits(isSelected ? .isSelected : [])` + `.accessibilityHint("Tab \(index + 1) of 5")` optional |
| **Verification** | VoiceOver swipe through tabs announces "Today, tab, selected" etc. |

---

### SE-005 — No Reduce Motion support

| Field | Value |
|---|---|
| **WCAG** | 2.3.3 Animation from Interactions — **Fail** (AAA; Apple HIG mandatory) |
| **Severity** | **Critical** |
| **Theme** | Reduce Motion |
| **Location** | `ForgeMotion.swift`; 20+ `withAnimation` / `.animation` / `.transition` call sites |
| **Current** | Fixed durations (150–550ms); Pow `movingParts` wipes, `.jump`, `.shake`; staggered offset appears; regenerate scale/blur |
| **Evidence** | `rg 'reduceMotion\|accessibilityReduceMotion' HotBod/` → **0**; foundation §7 specifies "All → motion.instant or opacity-only" |
| **Recommended** | `@Environment(\.accessibilityReduceMotion)` in `ForgeMotion`; branch to `.opacity` transitions; disable Pow effects; gate haptics |
| **Screens** | S-034 regenerate overlay, S-082 exercise transitions, S-010 onboarding step animation, S-056 dashboard stagger |
| **Verification** | Settings → Accessibility → Reduce Motion ON: no positional animation; opacity cross-fade only |

---

### SE-006 — Back button below 44pt minimum

| Field | Value |
|---|---|
| **WCAG** | 2.5.8 Target Size — **Fail** |
| **Severity** | **Critical** |
| **Theme** | 44pt targets |
| **Location** | `ForgeHeaderBackButton` in `ForgeScreenHeader.swift` (C-005) |
| **Current** | Visible `36×36` circle; no `.contentShape` or padding expansion to 44pt |
| **Evidence** | Component manifest flags "below 44pt minimum"; foundation `target.min` = 44×44 |
| **Screens** | S-071 (library), S-066–S-070 (coach push), S-073–S-075 (exercise detail compact header) |
| **Recommended** | `frame(minWidth: 44, minHeight: 44)` + `contentShape(Rectangle())` or invisible padding |
| **Verification** | Xcode Accessibility Inspector → hit region ≥ 44×44 |

---

### SE-007 — Settings gear button unlabeled

| Field | Value |
|---|---|
| **WCAG** | 1.1.1, 2.4.6 — **Fail** |
| **Severity** | High |
| **Theme** | VoiceOver |
| **Location** | `TodayView.swift` `settingsButton`; S-030–S-035 |
| **Current** | `Image(systemName: "gearshape")` in 40×40 button; no `accessibilityLabel` |
| **Recommended** | `.accessibilityLabel("Settings")` |
| **Verification** | VoiceOver announces "Settings, button" on S-033 |

---

### SE-008 — Disclosure section missing expanded state

| Field | Value |
|---|---|
| **WCAG** | 4.1.2, 1.3.1 — **Fail** |
| **Severity** | High |
| **Theme** | VoiceOver |
| **Location** | `TodayDisclosureSection.swift` (C-019); S-033 soreness strip |
| **Current** | Toggle button with chevron; no `.accessibilityAddTraits(.isButton)` / expanded trait; no hint |
| **Recommended** | `.accessibilityLabel(title)` + `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")` or use `DisclosureGroup` |
| **Verification** | VoiceOver announces expanded/collapsed state on toggle |

---

### SE-009 — Tab bar selected capsule height 32pt

| Field | Value |
|---|---|
| **WCAG** | 2.5.8 Target Size — **Fail** |
| **Severity** | High |
| **Theme** | 44pt targets |
| **Location** | `ForgeFloatingTabBar.swift` (C-010) |
| **Current** | Icon `.frame(width: 44, height: 32)` — width OK, **height 32pt** |
| **Evidence** | Full row tappable via `frame(maxWidth: .infinity)` but visual target misleads; subagent D aligned |
| **Recommended** | Icon frame `44×44`; or explicit `contentShape` on full `VStack` with `minHeight: 44` |
| **Verification** | Hit region per tab ≥ 44pt tall in Accessibility Inspector |

---

### SE-010 — Workout session exit control 30×30

| Field | Value |
|---|---|
| **WCAG** | 2.5.8 Target Size — **Fail** |
| **Severity** | **Critical** |
| **Theme** | 44pt targets |
| **Location** | `WorkoutSessionHeaderView.swift` `topBar`; S-082, S-083 |
| **Current** | Exit chevron `30×30`; has `accessibilityLabel("Exit workout")` but undersized for one-handed logging |
| **Recommended** | Expand to 44×44; consider destructive confirmation for accidental exit |
| **Verification** | Hit region ≥ 44×44 during active session |

---

### SE-011 — Rest timer actions lack accessible names

| Field | Value |
|---|---|
| **WCAG** | 2.4.6, 4.1.2 — **Fail** |
| **Severity** | High |
| **Theme** | VoiceOver |
| **Location** | `WorkoutSessionView.swift` `restTimerBar`; S-083 |
| **Current** | `Button("+30")` and `Button("Skip")` — text visible but no hints; timer not announced as live region |
| **Recommended** | `.accessibilityLabel("Add 30 seconds to rest")` / `"Skip rest"`; `.accessibilityAddTraits(.updatesFrequently)` on timer text |
| **Verification** | VoiceOver reads countdown and action purposes during rest |

---

### SE-012 — Set logging fields lack semantic labels

| Field | Value |
|---|---|
| **WCAG** | 1.3.1, 3.3.2 — **Fail** |
| **Severity** | High |
| **Theme** | VoiceOver |
| **Location** | `WorkoutSessionView.swift` `setField`; S-082 |
| **Current** | `TextField("—", …)` width 48/36pt; no `accessibilityLabel` for weight vs reps per set number |
| **Recommended** | `.accessibilityLabel("Set \(n), weight in kilograms")` / `"Set \(n), reps"` |
| **Verification** | VoiceOver navigates set table with per-field context |

---

### SE-013 — Muted caption contrast below AA at small sizes

| Field | Value |
|---|---|
| **WCAG** | 1.4.3 Contrast — **Fail** |
| **Severity** | High |
| **Theme** | Contrast |
| **Location** | `ForgeColors.muted` (`Color.gray.opacity(0.6)`); 20+ call sites |
| **Current** | ~3.5:1 on white at 13pt caption — below 4.5:1 for normal text |
| **Evidence** | `foundation_tokens.md` §12 pre-check flags fail at 13pt caption |
| **Recommended** | Use `color.text.secondary` (`neutral.500` #8E8E93 ≈ 4.6:1) for captions |
| **Screens** | S-033 exercise line, S-056 dashboard metadata, S-012–S-021 onboarding subtitles |

---

### SE-014 — Hero inverse secondary text low contrast

| Field | Value |
|---|---|
| **WCAG** | 1.4.3 Contrast — **Fail** |
| **Severity** | High |
| **Theme** | Contrast |
| **Location** | `WorkoutSessionHeaderView.swift`, `ForgeHeroCard.swift` |
| **Current** | White text at 55–70% opacity on black (`surface.opacity(0.55–0.7)`) for muscle line, stat labels |
| **Recommended** | Minimum `opacity(0.85)` for body-sized text on inverse; use `color.text.onInverse` token |
| **Screens** | S-082 session header, S-033 hero focus line |

---

### SE-015 — Thin progress indicators may fail non-text contrast

| Field | Value |
|---|---|
| **WCAG** | 1.4.11 Non-text Contrast — **Partial / Fail** |
| **Severity** | Medium |
| **Theme** | Contrast |
| **Location** | `ForgeProgressBar.swift` (4pt), `WorkoutSessionHeaderView` segments (3pt) |
| **Current** | Track `border` @ 15% black may not achieve 3:1 against adjacent surface |
| **Recommended** | Increase track to `neutral.200` or bar height to 6pt for graphical-object threshold |
| **Screens** | S-033 hero progress, S-082 exercise segments, S-010 onboarding progress |

---

### SE-016 — No visible focus indicator on custom controls

| Field | Value |
|---|---|
| **WCAG** | 2.4.7 Focus Visible — **Fail** |
| **Severity** | Medium |
| **Theme** | Focus / keyboard |
| **Location** | `ForgeButton`, `SelectableRow`, `SelectableChip`, `ForgeFloatingTabBar` |
| **Current** | Component manifest marks `focused` state as `?` or `—` for all custom buttons |
| **Recommended** | `.focusable()` + accent border ring on `@FocusState`; test with hardware keyboard / Switch Control |
| **Verification** | External keyboard Tab highlights every interactive on S-012 onboarding step |

---

## VoiceOver Inventory (current)

| File | Labels | Missing on same screen |
|---|---|---|
| `TodayView.swift` | Split toggle only | Settings gear, metric tiles, exercise strip, hero CTAs, disclosure |
| `WorkoutSessionHeaderView.swift` | Exit, segments, progress ring | Stat capsules (calories, sets, session %) |
| `ExerciseDemoPlayerView.swift` | Back, angle thumbs | Play/pause if added; selected angle trait |
| `ForgeScreenHeader.swift` | Back | Trailing actions (settings icon in preview) |
| `ForgeHeroCard.swift` | Title accessory only | Primary/secondary action buttons |
| `ExerciseThumbnailView.swift` | Muscle or exerciseId | Play affordance state |

**Coverage estimate:** ~8% of interactive elements have explicit accessibility metadata.

---

## Reduce Motion Inventory (sample)

| Animation | File | Reduce Motion fix |
|---|---|---|
| `ForgeMotion.appear` (Pow wipe) | `ForgeMotion.swift` | → `.opacity` only |
| `exerciseChange` offset y 20/−12 | Session header, session view | → opacity cross-fade |
| `forgeStaggeredAppear` offset y 18 | `TodayView` bento | → instant appear |
| `scaleEffect(0.97)` regenerate | `TodayView` hero | → remove scale |
| `forgeMetricPulse` / `.jump` | `MetricCard`, session header | → disable |
| `forgeValidationShake` | Onboarding (if used) | → disable |
| Rest timer haptic on expiry | `WorkoutSessionView` | → optional keep (non-motion) |

---

## 44pt Target Inventory

| Control | Size | File | Meets 44pt? |
|---|---|---|---|
| `ForgeHeaderBackButton` | 36×36 | `ForgeScreenHeader.swift` | **No** |
| Session exit | 30×30 | `WorkoutSessionHeaderView.swift` | **No** |
| Settings gear | 40×40 | `TodayView.swift` | **No** |
| Tab icon frame | 44×32 | `ForgeFloatingTabBar.swift` | **No** (height) |
| Disclosure chevron | 28×28 | `TodayDisclosureSection.swift` | **No** |
| Exercise detail back | 40×40 | `ExerciseDemoPlayerView.swift` | **No** |
| Angle thumbnail | 52×52 | `ExerciseDemoPlayerView.swift` | Yes |
| Hero title accessory | ~38×38 (18pt icon + 10 pad ×2) | `ForgeHeroCard.swift` | **No** |
| `ForgeButton` | ~45–49pt height | `ForgeButton.swift` | Yes |
| Rest +30 / Skip | Text-only, ~32pt est. | `WorkoutSessionView.swift` | **No** |

**Rule from foundation:** `target.compact` (36×36 visible) must expand hit area to 44 via `contentShape` — **not implemented anywhere** (`rg contentShape` → 0).

---

## Dynamic Type Inventory

| Source | Dynamic Type? | Notes |
|---|---|---|
| `ForgeTypography.*` | No | All 10 tokens fixed `size:` |
| `ForgeFloatingTabBar` tab label | No | `Font.system(size: 10)` |
| `WorkoutSessionHeaderView` | No | 8–26pt ad-hoc |
| `ExerciseDemoPlayerView` | No | 10–15pt ad-hoc |
| `TodayExerciseStrip` | No | 11pt monospaced |
| `.font(.body)` / `.font(.caption)` shortcuts | **Yes** | ~6 call sites only |
| `minimumScaleFactor` | Partial workaround | Session title 0.85; metric card 0.85 — shrinks instead of scaling up |

---

## Remediation Priority

| Priority | Finding IDs | Effort | Impact |
|---|---|---|---|
| P0 | SE-001, SE-005 | L | Unblocks Dynamic Type + motion compliance |
| P0 | SE-003, SE-004 | M | VoiceOver usable on primary navigation |
| P0 | SE-006, SE-010, SE-009 | S | Hit targets — localized frame changes |
| P1 | SE-002, SE-011, SE-012 | M | Session logging accessibility |
| P1 | SE-013, SE-014 | S | Token swap `muted` → `secondary` |
| P2 | SE-008, SE-015, SE-016 | S–M | Polish |

---

## Sign-off Checklist (pre-redesign)

- [ ] All `ForgeTypography` tokens use `Font.TextStyle` (SE-001)
- [ ] `ForgeMotion` respects `@Environment(\.accessibilityReduceMotion)` (SE-005)
- [ ] Every manifest screen-state VoiceOver walkthrough passes (SE-003)
- [ ] Tab bar, back, exit, settings, disclosure ≥ 44pt hit area (SE-006, SE-009, SE-010)
- [ ] Larger Text AX5 spot-check: S-011, S-033, S-082, S-056 (SE-001, SE-002)
- [ ] Contrast audit: no `muted` on captions < 17pt (SE-013)
- [ ] Reduce Motion on: S-034, S-082, S-010 show opacity-only transitions (SE-005)

---

## Cross-References

| Subagent | Overlap |
|---|---|
| A (Typography) | SE-001, SE-002 — shared Dynamic Type blockers |
| B (Color) | SE-013, SE-014 — contrast pairs |
| D (Components) | SE-006, SE-009, SE-016 — C-005, C-010 touch/focus gaps |

**Auditor:** Subagent E  
**Critical count: 7**
