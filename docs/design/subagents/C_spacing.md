# Subagent C — Spacing, Grid & Layout Auditor

**Date:** 2026-07-07  
**Inputs:** `foundation_tokens.md`, `current_tokens.md`, `screen_manifest.md`, SwiftUI source grep (`padding`, `spacing`, `ForgeTabBarMetrics`, `contentMargins`)

---

## Coverage

- **Screens audited:** 54 of 54 (all manifest entries visited via file/trace; tab-root scroll layouts measured in code)
- **Components audited:** 28 of 28 (spacing-relevant props measured on all `Core/Components` + feature-local layout wrappers)
- **States audited per component:** default ✓ | pressed — | disabled — | focused — | selected — | loading — | error — | success — | empty ✓ (where layout differs)

---

## Tools / references used

- **HIG section(s):** Layout — margins and layout margins; Tab bars — scrollable content inset; Safe area — respect system insets
- **WCAG 2.2 criteria:** §2.5.8 Target Size (Minimum) — touch targets affected by cramped padding (cross-ref only)
- **Measurements sourced from:** code (`HotBod/**/*.swift`), token docs

---

## Summary counts

| Severity | Count |
|---|---|
| **critical** | **1** |
| high | 4 |
| medium | 6 |
| low | 2 |
| nit | 1 |
| **Total findings** | **14** |

**Theme breakdown (requested focus areas):**

| Theme | Findings |
|---|---|
| 16 vs 20 horizontal drift (`space.4` vs `space.5`) | SC-002, SC-003, SC-004, SC-005, SC-012 |
| Tab clearance 104 (`space.tabClearance`) | SC-001, SC-006, SC-007, SC-008 |
| Internal ≤ external (Gestalt) violations | SC-009, SC-010, SC-012, SC-013 |
| Off-scale / split-pixel spacing | SC-011, SC-014 |

---

## Findings

### Finding SC-001

- **Smell:** Token drift
- **Severity:** critical
- **Location:** `Coach/Tab/ScrollView` (S-061–S-065)
- **Current value(s):** `ScrollView` content has no bottom inset; only the input `HStack` receives `.padding(.bottom, ForgeTabBarMetrics.scrollClearance)` (104pt). Other tab roots use `.forgeFloatingTabBarClearance()` on the `ScrollView`.
- **Recommended value(s):** Apply `.forgeFloatingTabBarClearance()` to the `ScrollView` (or equivalent `contentMargins(.bottom, space.tabClearance, for: .scrollContent)`). Remove duplicate 104pt padding from input bar; use `space.3` (12pt) internal input chrome padding only.
- **Rationale:** Coach is the only tab root where scrollable message history does not reserve `space.tabClearance`. Last messages and suggestion chips render underneath the floating tab bar, making content unreadable and tappable targets unreachable. HIG expects scroll content to extend behind chrome with explicit content inset — not ad-hoc padding on a sibling.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-002

- **Smell:** Token drift
- **Severity:** high
- **Location:** `Today/WorkoutReady`, `Train/WithWorkout`, `Protein/MealsPopulated`, `Progress/Dashboard` — scroll body sections (S-033, S-040, S-051, S-056)
- **Current value(s):** `ForgeScreenHeader` horizontal padding = **20pt** (`space.5`). Scroll body uses `.padding()` default = **16pt** (`space.4`) on `VStack` below header.
- **Recommended value(s):** Screen horizontal margin = `space.5` (20pt) on all tab-root scroll bodies. Card internals remain `space.4` (16pt) via `ForgeCard` / explicit `.padding(16)`.
- **Rationale:** Foundation rule: screen horizontal margin is always `space.5`. Four of five tab roots pair a 20pt header with a 16pt body, producing a visible 4pt left-edge jog between header copy and section content. Typography no longer hangs on a single vertical grid line.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-003

- **Smell:** Token drift
- **Severity:** high
- **Location:** `Settings/Default` scroll body (S-090)
- **Current value(s):** `ForgeScreenHeader` compact style `.padding(.horizontal, 20)`; `ScrollView` inner `VStack` `.padding(.horizontal, 16)`.
- **Recommended value(s):** Scroll body horizontal = `space.5` (20pt). Section cards (`ForgeCard`, settings rows) keep `space.4` (16pt) internal.
- **Rationale:** Same 16 vs 20 drift as tab roots. Settings is a sheet but uses the same header component — misalignment is especially noticeable because section labels should align with the header title's leading edge.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-004

- **Smell:** Token drift
- **Severity:** medium
- **Location:** `Today/WorkoutReady/editorialLayout` (S-033)
- **Current value(s):** `ForgeHeroCard` content inset `.padding(.horizontal, 20)`. Editorial `VStack` below hero `.padding(.horizontal, 16)`.
- **Recommended value(s):** Editorial outer horizontal = `space.5` (20pt) to match hero text column. Cards inside (`TodayExerciseStrip`, bento) keep `space.4` (16pt) internal — total content inset becomes 36pt from screen edge, which is correct (external 20 + internal 16).
- **Rationale:** On Today, hero title and bento card edges sit on different vertical guides. User perceives the hero as "full width" and bento as "wider" by 4pt per side — undermines the editorial grid.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-005

- **Smell:** Token drift
- **Severity:** medium
- **Location:** `App/MainTabView` shell (S-003)
- **Current value(s):** `ForgeFloatingTabBar` `.padding(.horizontal, 16)` + `.padding(.bottom, 6)`.
- **Recommended value(s):** Tab bar horizontal inset = `space.5` (20pt). Bottom float gap = `space.2` (8pt) or document as part of `space.tabClearance` formula.
- **Rationale:** Floating tab bar leading/trailing edges align to 16pt while headers use 20pt — chrome and content columns diverge. The 6pt bottom float is off-scale (not on 4pt rhythm) and is excluded from the 104pt clearance constant.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-006

- **Smell:** Magic number
- **Severity:** high
- **Location:** `ForgeFloatingTabBar.swift` / `ForgeTabBarMetrics` (S-003, all tab roots)
- **Current value(s):** `static let scrollClearance: CGFloat = 104` with comment only; no computed formula in code.
- **Recommended value(s):** Implement documented formula per `foundation_tokens.md`:  
  `space.tabClearance = tabBarContentHeight + tabBarVerticalPadding + tabBarBottomFloat + safeAreaBottomInset`  
  Expose as computed property on `ForgeTabBarMetrics`, not a magic literal. Current measured components ≈ 48 (icon+label) + 16 (capsule V-pad) + 6 (MainTabView bottom) + 34 (home indicator) ≈ 104.
- **Rationale:** A single hardcoded 104pt will silently break when tab bar typography, icon size, or float gap changes. Foundation tokens require the formula in implementation so clearance stays coupled to chrome metrics.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-007

- **Smell:** Token drift
- **Severity:** high
- **Location:** `Coach/Tab` clearance strategy vs other tabs (S-061–S-065)
- **Current value(s):** Coach: manual `padding(.bottom, 104)` on input bar only. Today/Train/Protein/Progress: `.forgeFloatingTabBarClearance()` → `contentMargins(.bottom, 104, for: .scrollContent)`.
- **Recommended value(s):** Unify on `forgeFloatingTabBarClearance()` at scroll-container level for all tab roots. Input bar uses standard `space.4` padding without clearance duplication.
- **Rationale:** Two different APIs for the same semantic token create maintenance drift (already caused SC-001). `contentMargins` is the correct scroll-content primitive; sibling padding does not inset scrollable content.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-008

- **Smell:** Magic number
- **Severity:** medium
- **Location:** `MainTabView` + `ForgeTabBarMetrics` coupling (S-003)
- **Current value(s):** `MainTabView` `.padding(.bottom, 6)` on tab bar; `scrollClearance = 104` does not reference this 6pt in code.
- **Recommended value(s):** Include `tabBarBottomFloat = space.2` (8pt, rounded from current 6) as named constant inside `ForgeTabBarMetrics` and add to clearance sum.
- **Rationale:** If designer increases float gap without updating 104, scroll content will clip under tab bar. The 6pt value is also off the 4pt scale (Split-pixel smell).
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-009

- **Smell:** Split-pixel value
- **Severity:** high
- **Location:** `ForgeHeroCard` bottom padding → `Today/WorkoutReady` hero-to-bento gap (S-032, S-033, S-040)
- **Current value(s):** Hero internal bottom padding = **28pt** (off-scale; between `space.6` 24 and `space.8` 32). Editorial section top margin = **20pt** (`space.5`). **28 > 20** — internal padding exceeds external section gap (Gestalt violation).
- **Recommended value(s):** Hero bottom internal = `space.6` (24pt) max, or reduce to `space.5` (20pt) so internal ≤ external. Section gap remains `space.5` (20pt).
- **Rationale:** Foundation rule: internal padding ≤ external margin. When hero content breathes more at its bottom edge (28pt) than the gap to the next section (20pt), the bento block reads detached from the hero rather than as a continuation of the same screen hierarchy.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-010

- **Smell:** Split-pixel value
- **Severity:** medium
- **Location:** `TodayMetricTile` in `Today/bentoRow` (S-033)
- **Current value(s):** Tile internal padding = **14pt** (not on 4pt scale). Bento `HStack` inter-tile gap = **12pt** (`space.3`). **14 > 12** — internal > external between adjacent tiles.
- **Recommended value(s):** Tile internal = `space.4` (16pt). Inter-tile gap = `space.3` (12pt) or `space.4` (16pt) if tiles need more separation. Maintain internal ≤ gap.
- **Rationale:** 14pt is a split-pixel value absent from the spacing ramp. Tiles feel individually padded more than they are spaced apart, weakening the bento grid pairing.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-011

- **Smell:** Split-pixel value
- **Severity:** medium
- **Location:** `TodayDisclosureSection` header row (S-033)
- **Current value(s):** `.padding(.vertical, 14)` on disclosure header button.
- **Recommended value(s):** `space.3` (12pt) or `space.4` (16pt) vertical padding.
- **Rationale:** 14pt is not on the 4pt base grid. Composes with 16pt horizontal to produce non-rhythm vertical tap height (~42pt visible + label).
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-012

- **Smell:** Token drift
- **Severity:** medium
- **Location:** `Today/sorenessStrip` nested in `editorialLayout` (S-033)
- **Current value(s):** Outer editorial margin = 16pt. Soreness card internal `.padding(16)`. Effective content inset from screen edge = **32pt**. Hero title inset = **20pt**.
- **Recommended value(s):** Outer margin = `space.5` (20pt). Card internal = `space.4` (16pt). Document stacked inset pattern (36pt total) as intentional for nested cards. Alternatively, soreness strip uses 12pt internal when outer is 20pt to keep total at 32pt and match hero column.
- **Rationale:** Gestalt: nested card with same internal and external token (16+16) creates accidental double-margin — soreness content sits 12pt further inset than hero title without semantic reason (not a deeper hierarchy level).
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-013

- **Smell:** Split-pixel value
- **Severity:** low
- **Location:** `ForgeScreenHeader` root + compact styles (all tab headers)
- **Current value(s):** Inter-element `VStack` spacing = **10pt** (not on 4pt scale).
- **Recommended value(s):** `space.2` (8pt) for tight header stacks or `space.3` (12pt) for root headers with eyebrow + title + subtitle.
- **Rationale:** 10pt breaks vertical rhythm alignment with the 4pt/8pt baseline grid used elsewhere (section gaps of 12, 16, 20, 24).
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

### Finding SC-014

- **Smell:** Magic number
- **Severity:** nit
- **Location:** App-wide `.padding()` without explicit token (18 files, 30+ call sites)
- **Current value(s):** Bare `.padding()` / `.padding(.horizontal)` resolves to system default **16pt** — used interchangeably with explicit `16` and conflicting `20` margins.
- **Recommended value(s):** Replace all bare `.padding()` with named `ForgeSpacing` accessors: `.forgeScreenMargin()`, `.forgeCardPadding()`, etc. Ban implicit defaults in feature code per AGENTS.md token rule.
- **Rationale:** Implicit 16pt is the root cause of 16 vs 20 drift — developers assume "padding()" is correct screen margin when it is actually card-level `space.4`.
- **Verification checklist (tick when done):**
  - [ ] Value resolves to an existing token (or new token proposed)
  - [ ] Change verified in Light Mode
  - [ ] Change verified in Dark Mode
  - [ ] Change verified at `xxxLarge` Dynamic Type
  - [ ] Change verified at `AX5` Dynamic Type
  - [ ] Contrast recomputed (if color)
  - [ ] Touch target recomputed (if interactive)
  - [ ] VoiceOver label verified (if interactive)

---

## Specs produced (positive output)

### Layout primitive: Tab-root scroll screen

- **Anatomy:** `NavigationStack` → `ScrollView` → `VStack(spacing: 0)` → [`ForgeScreenHeader`] → [section `VStack(spacing: space.5)`] → `.forgeFloatingTabBarClearance()`
- **Tokens used:**
  - Screen horizontal margin: `space.5` (20pt)
  - Section vertical gap: `space.5` (20pt)
  - Card internal: `space.4` (16pt)
  - Scroll bottom inset: `space.tabClearance` (104pt computed)
- **Sizes:** Full width iPhone portrait; no iPad `regular` size-class branching (gap — see Open Questions)
- **States:** Empty/loading sections use `space.8` (32pt) empty-state padding
- **Accessibility:** Clearance ensures last content + CTAs sit above tab bar hit targets
- **Motion:** N/A for spacing

### Layout primitive: `ForgeCard` / nested card on screen

- **Anatomy:** [screen margin `space.5`] → card border → [internal `space.4`] → content
- **Tokens used:** External `space.5`, internal `space.4`, inter-card `space.5`
- **Gestalt rule:** internal (`space.4` = 16) ≤ external (`space.5` = 20) ✓
- **Violation pattern to avoid:** outer 16 + inner 16 (SC-012)

### Layout primitive: `ForgeHeroCard` (full-bleed)

- **Anatomy:** Ignores safe area top → content column at `space.5` horizontal → bottom internal ≤ `space.5`
- **Tokens used:** H-pad `space.5`, top `space.5` (fullBleed) / `space.6` (inset), bottom ≤ `space.5` (fix SC-009)
- **States:** Completed variant same spacing tokens

### Layout primitive: `ForgeFloatingTabBar` + clearance

- **Anatomy:** `ZStack(alignment: .bottom)` → tab content full bleed → bar with `space.5` H-inset, `space.2` bottom float
- **Tokens used:** `space.tabClearance` on scroll content via `contentMargins`
- **Formula (proposed):**  
  `clearance = iconColumnHeight(32) + labelHeight(~12) + vStackGap(4) + capsuleVPad(16) + bottomFloat(8) + safeAreaBottom`

### Component: `ForgeScreenHeader`

- **Tokens used:** H-margin `space.5`, top `space.2`, bottom `space.1` (root) / `space.3` (compact), inter-item `space.3`
- **Alignment rule:** Leading edge of title must match scroll body leading edge (both `space.5`)

---

## Coverage log (no additional findings)

Screens/components audited with spacing conformant or N/A:

- **Onboarding S-010–S-021:** `space.6` (24pt) padding — documented exception ✓
- **WorkoutSession S-081–S-084:** Full-screen overlay; no tab clearance needed ✓
- **WorkoutPreview S-080:** Push overlay; uses `space.5` horizontal in timeline ✓
- **ExerciseDetail S-074:** `space.5` horizontal margin ✓
- **BodyProgress S-058–S-060:** Push navigation; `.padding()` acceptable at 16 for non-tab context ✓
- **SwapExercise S-087–S-088:** System `List` insets ✓
- **ForgeCard, ForgeButton, ForgePill:** Internal padding matches `space.4` / chip `space.3` ✓
- **EmptyStateView:** `space.8` (32pt) ✓

---

## Open questions for orchestrator

1. **Hero full-bleed vs editorial column:** Should hero text column (20pt) be the single screen grid line, with all below-hero cards at 20pt outer + 16pt inner (36pt content)? Or should cards extend to 20pt outer with 0 additional margin (content at 36pt only for `ForgeCard` wrappers)?
2. **iPad / `regular` size class:** No `readableContentGuide` or max-width constraint found. Defer to Subagent F (IA) or specify `space.16` (64pt) side margins on iPad?
3. **`ForgeSpacing.swift` not yet implemented** (listed in foundation handoff). Orchestrator should prioritize creation before feature migration.
4. **Onboarding `space.6` (24pt) vs tab `space.5` (20pt):** Confirm 24pt remains the only justified screen-margin exception.

---

## Critical count

**1 critical** (SC-001 — Coach scroll content obscured by floating tab bar due to missing `space.tabClearance` on `ScrollView`).
