# Subagent A — Typography Auditor

**Audit date:** 2026-07-07  
**Scope:** 54 screen-states (screen_manifest.md), 28 components (component_manifest.md), `ForgeTypography.swift`, all `.font(` call sites in `HotBod/`  
**Baseline:** `foundation_tokens.md` §3 Typography Ramp

---

## Coverage

| Area | Target | Audited | Notes |
|---|---|---|---|
| Screen-states | 54 | 54 | All IDs S-001–S-100 from manifest; typography inferred from owning view files |
| Components | 28 | 28 | C-001–C-028; font-bearing vs inherited/system-only classified |
| Design tokens | 11 type + 4 tracking | 11 mapped, 0 implemented | `ForgeTypography.swift` predates semantic token schema |
| `.font(` call sites | 26 Swift files | 26 | 147 total `.font(` usages (grep, 2026-07-07) |
| Fixed `Font.system(size:)` | 0 in feature code (rule) | 22 inline + 10 in token file | **Rule violation** |
| Dynamic Type | Required | Not supported | All tokens use fixed point sizes |

**Adoption rate:** ~78% of `.font(` calls use `ForgeTypography.*`; ~22% use raw `.system(size:)` or SwiftUI `TextStyle` shortcuts.

**Severity summary:** 3 Critical · 4 High · 5 Medium · 2 Low = **14 findings**

---

## Tools / references used

| Tool / reference | Purpose |
|---|---|
| `docs/design/screen_manifest.md` | Screen-state inventory (54 entries) |
| `docs/design/component_manifest.md` | Component inventory (28 entries) |
| `docs/design/foundation_tokens.md` | Canonical `type.*` and `tracking.*` tokens |
| `HotBod/Core/DesignSystem/ForgeTypography.swift` | Current implementation |
| `rg '\.font\(' HotBod/` | 147 call sites across 26 files |
| `rg 'Font\.system\(size:|\.system\(size:' HotBod/` | Fixed-size drift (32 occurrences) |
| `rg '\.tracking\(' HotBod/` | Letter-spacing audit (18 call sites) |
| `rg 'ForgeTypography\.' HotBod/` | Token adoption count per file |
| WCAG AA contrast pre-check | `foundation_tokens.md` §12 — `text.muted` @ 13pt caption |

---

## Findings

### Finding SA-001

| Field | Value |
|---|---|
| **Smell** | Fixed-point typography system-wide — no Dynamic Type |
| **Severity** | **Critical** |
| **Location** | `ForgeTypography.swift` (all 10 static lets); propagates to every screen using `ForgeTypography.*` |
| **Current** | `Font.system(size: N, weight:, design:)` for all tokens (e.g. `largeTitle` = 44pt black serif, `body` = 16pt regular) |
| **Recommended** | `Font.system(.largeTitle, design: .serif).weight(.black)` etc., mapped 1:1 to `foundation_tokens.md` `type.*` TextStyle column; add `@ScaledMetric` only where layout requires hard caps |
| **Rationale** | Foundation rule: "Map to Dynamic Type `Font.TextStyle`." Fixed sizes break Accessibility → Larger Text, fail iOS 26 HIG alignment, and invalidate contrast assumptions at non-default content sizes. Affects onboarding titles (S-011), root headers (S-030–S-035), metrics (S-056), and all Forge components. |
| **Verification checklist** | - [ ] Settings → Accessibility → Larger Text → AX5: no clipping on S-011, S-033, S-082<br>- [ ] All `ForgeTypography` tokens use `Font.TextStyle`, not `size:`<br>- [ ] Snapshot tests at `.extraSmall` and `.accessibilityExtraExtraExtraLarge` |

---

### Finding SA-002

| Field | Value |
|---|---|
| **Smell** | Parallel ad-hoc type ramp in workout session header |
| **Severity** | **Critical** |
| **Location** | `WorkoutSessionHeaderView.swift` (C-014); screens S-082 (active), S-083 (resting) |
| **Current** | 10 inline `.font(.system(size: …))`: exercise name 26pt heavy italic; metadata 11pt; timer 14pt mono; ring 20/9pt mono; stat labels 8–10pt; stat values 13pt mono |
| **Recommended** | Exercise name → `type.sessionTitle` (`.title2` heavy italic); session eyebrow → `type.label` + `tracking.eyebrow`; timer → `type.metric` scaled; ring count → `type.metric`; stat label → `type.label` (min caption2); stat value → `type.metric`; retire 8pt/9pt sizes |
| **Rationale** | Largest typography smell in codebase. Foundation explicitly calls out "26pt ad-hoc" and replaces with `type.sessionTitle`. Sub-11pt sizes (8pt, 9pt) violate minimum legible rule and will fail under Dynamic Type. |
| **Verification checklist** | - [ ] Zero `.system(size:` in `WorkoutSessionHeaderView.swift`<br>- [ ] Exercise name uses `ForgeTypography.sessionTitle` (new token)<br>- [ ] No text rendered below `caption2` equivalent at default size<br>- [ ] S-082 header readable at 200% text size |

---

### Finding SA-003

| Field | Value |
|---|---|
| **Smell** | Token naming/schema drift between implementation and foundation |
| **Severity** | **High** |
| **Location** | `ForgeTypography.swift` vs `foundation_tokens.md` §3 |
| **Current** | `heading` (22pt semibold), `monoMetric` (18pt bold mono), `heroMetric` (36pt bold mono), `ctaLabel`, `displayAthletic`, `displayTitle` (unused) |
| **Recommended** | Rename/map: `heading` → `title` (`type.title`); `monoMetric` → `metric` (`type.metric`); `heroMetric` → `metricHero` (`type.metricHero`); `ctaLabel` → `cta` (`type.cta`); `displayAthletic` → `display` (`type.display`); add `sessionTitle`, `tabLabel`; deprecate unused `displayTitle` or alias to `display` |
| **Rationale** | Orchestrator and component specs reference semantic names; engineers grep for `ForgeTypography.heading` while design docs say `type.title`. Drift blocks automated token linting and cross-agent handoff. |
| **Verification checklist** | - [ ] `ForgeTypography` public API matches `type.*` table exactly<br>- [ ] No references to deprecated names after rename migration<br>- [ ] `displayTitle` either removed or aliased with comment |

---

### Finding SA-004

| Field | Value |
|---|---|
| **Smell** | `type.title` design mismatch — serif bold 30pt vs semibold default title2 |
| **Severity** | **High** |
| **Location** | `ForgeTypography.title` used in `TrainViews.swift` (S-040, S-080), `ProgressDashboardView.swift` (S-056), `MetricCard` value contexts; `ForgeTypography.heading` used for list row titles everywhere else |
| **Current** | `title` = 30pt **bold serif**; `heading` = 22pt semibold default — two competing "section/row title" tokens |
| **Recommended** | `type.title` = `.title2` semibold default (per foundation); reserve serif for `type.hero` / `type.display` only; consolidate row titles (library, meals, settings, swap) on `type.title`; use `type.display` for hero card athletic titles |
| **Rationale** | Inconsistent hierarchy: protein hero (S-051) uses `title` serif 30pt while meal rows use `heading` 22pt. Exercise library rows (S-071) use `heading` while train history dates use `title`. Users perceive arbitrary weight jumps. |
| **Verification checklist** | - [ ] Single row-title token across S-071, S-050, S-087, S-090<br>- [ ] Hero metrics on S-033, S-040 use `type.display` or `type.metricHero`, not serif `title`<br>- [ ] Visual diff Today + Train + Protein tabs for title consistency |

---

### Finding SA-005

| Field | Value |
|---|---|
| **Smell** | Raw SwiftUI `TextStyle` bypasses design tokens |
| **Severity** | **Medium** |
| **Location** | `CoachView.swift` L131 `.title2`; `TodayView.swift` L170 `.body`, L492 `.caption`; `SettingsView.swift` L442 `.caption`; `ForgeScreenHeader.swift` L146 `.body`; `TodayDisclosureSection.swift` L21 `.caption`; `TodayMetricTile.swift` L32 `.caption`; `WorkoutSessionHeaderView.swift` L89 `.caption`; `ExerciseThumbnailView.swift` L23 `.caption` |
| **Current** | 9 call sites use `.font(.body|.caption|.title2)` with ad-hoc `.weight()` |
| **Recommended** | Map to semantic tokens: `.body.weight(.semibold)` → `ForgeTypography.title` or new `type.bodyEmphasis`; `.caption.weight(.semibold/.bold)` → `ForgeTypography.label` with weight modifier encapsulated in token; `.title2` → `ForgeTypography.sessionTitle` or `title` |
| **Rationale** | Bypasses central ramp; Dynamic Type scaling path differs from fixed `ForgeTypography` (when migrated). Creates untracked variants (semibold caption appears in 4 components). |
| **Verification checklist** | - [ ] `rg '\.font\(\.(body|caption|title)' HotBod/` returns 0 in feature/component code<br>- [ ] Semibold caption variant exists as named token if still needed |

---

### Finding SA-006

| Field | Value |
|---|---|
| **Smell** | Letter-spacing values not tokenized; spec drift |
| **Severity** | **Medium** |
| **Location** | 18 `.tracking()` call sites: `ForgeButton` (1.4/1.2), `ForgeScreenHeader` (2.5/2), `ForgeHeroCard` (2/1.5), `MetricCard` (1.5), `WorkoutExerciseTimelineRow` (1.5), `TodayView` regenerating overlay (3), `WorkoutSessionHeaderView` (1.5/0.8), others |
| **Current** | Magic numbers: 0.8, 1.2, 1.4, 1.5, 2, 2.5, 3 |
| **Recommended** | `ForgeTracking` enum: `tight` = 1.2, `cta` = 1.4, `eyebrow` = 2.0, `eyebrowWide` = 2.5; map 1.5 → `eyebrow` (2.0) per spec or add `tracking.compact` = 1.5 with documented exception; overlay 3 → `tracking.loading` = 3.0 |
| **Rationale** | Foundation defines 4 tracking tokens; implementation uses 7 distinct values with no single source. `1.5` used 8× but not in spec table. |
| **Verification checklist** | - [ ] `ForgeTracking` (or extension) exists<br>- [ ] No raw numeric `.tracking()` outside `ForgeTypography.swift` / `ForgeTracking.swift`<br>- [ ] C-001, C-004, C-003 eyebrow tracking matches spec |

---

### Finding SA-007

| Field | Value |
|---|---|
| **Smell** | Tab bar labels use fixed 10pt system font, not `type.tabLabel` |
| **Severity** | **Medium** |
| **Location** | `ForgeFloatingTabBar.swift` (C-010); screen S-003 (`MainTabView`) |
| **Current** | Icon `.system(size: 18)`; label `.system(size: 10, weight: medium/semibold)` |
| **Recommended** | Label → `Font.system(.caption2).weight(isSelected ? .semibold : .medium)` via `ForgeTypography.tabLabel`; icon size stays `icon.tab` = 18pt (documented exception in foundation §8) |
| **Rationale** | Only sub-caption2 text in chrome; won't scale with Dynamic Type. Foundation defines `type.tabLabel` explicitly for this control. |
| **Verification checklist** | - [ ] Tab labels use `ForgeTypography.tabLabel`<br>- [ ] AX5: tab bar labels remain legible, no truncation on 5 tabs<br>- [ ] Selected/unselected weight contrast preserved |

---

### Finding SA-008

| Field | Value |
|---|---|
| **Smell** | Micro-type below minimum legible threshold |
| **Severity** | **Critical** |
| **Location** | `WorkoutSessionHeaderView.swift` L167 (9pt), L200 (8pt); `ExerciseThumbnailView.swift` L31 (9pt badge); `TodayExerciseStrip.swift` L67 (11pt mono) |
| **Current** | 8pt semibold stat label; 9pt mono ring denominator; 9pt bold muscle badge |
| **Recommended** | Floor all UI text at `caption2` (~11pt) via `type.label`; badge counts use `type.label` + tighter layout (wider capsule), not smaller type; ring denominator merges into single `metric` line e.g. "3/4" |
| **Rationale** | Foundation: "Minimum legible: caption2 (~11pt)." 8–9pt fails readability on device and WCAG targeting for small text. |
| **Verification checklist** | - [ ] `rg 'size: (8|9),' HotBod/` returns 0<br>- [ ] Muscle badge (C-012) readable on 72×72 thumb<br>- [ ] Stat capsules (C-014) pass visual review on iPhone SE |

---

### Finding SA-009

| Field | Value |
|---|---|
| **Smell** | `ForgeColors.muted` on 13pt caption text — contrast fail |
| **Severity** | **High** |
| **Location** | 20+ call sites pairing `ForgeTypography.caption` + `.foregroundStyle(ForgeColors.muted)` — onboarding (S-012–S-021), protein meals (S-050), body progress (S-058–S-060), settings (S-090), library (S-071), hero cards (S-033) |
| **Current** | 13pt medium caption @ `neutral.500` @ 85% opacity on white |
| **Recommended** | Metadata at caption size → `color.text.secondary` (`ForgeColors.secondary` or new semantic alias); reserve `text.muted` for ≥17pt only per foundation §12 fix note |
| **Rationale** | Foundation contrast pre-check explicitly flags **fail at 13pt caption** for muted text. Widespread pattern affects eyebrows, subtitles, timestamps. |
| **Verification checklist** | - [ ] Caption-sized metadata uses `text.secondary`<br>- [ ] Contrast ratio ≥4.5:1 for all caption metadata in light mode<br>- [ ] Spot-check S-012 selectable row subtitles, S-050 meal type labels |

---

### Finding SA-010

| Field | Value |
|---|---|
| **Smell** | Missing typography tokens for new semantic roles |
| **Severity** | **High** |
| **Location** | `ForgeTypography.swift`; gaps affect C-027 `CoachBubble`, C-022 overlay, C-016 hero, S-011 welcome mark |
| **Current** | No `sessionTitle`, `tabLabel`, `labelEmphasis` (semibold caption), `emptyStateIcon`, `coachBanner` |
| **Recommended** | Add: `sessionTitle` (type.sessionTitle), `tabLabel` (type.tabLabel), `labelEmphasis` (.caption.medium → semibold), `overlayStatus` (.title3.bold for regenerating "REGENERATING"), `coachProposal` (.title2.semibold for Apply banner) |
| **Rationale** | Raw `.title2` in CoachView (S-064–S-069) and `.system(size: 28)` in TodayView empty icon (S-030) exist because no token is defined. |
| **Verification checklist** | - [ ] Coach proposal banner (S-064) uses named token<br>- [ ] `ForgeHeroRegeneratingOverlay` (S-034) uses `overlayStatus` + `tracking.loading`<br>- [ ] Empty state icon (S-030) uses `icon.xl` text equivalent or SF Symbol sizing, not 28pt arbitrary text |

---

### Finding SA-011

| Field | Value |
|---|---|
| **Smell** | `displayTitle` dead token; serif/display split undocumented |
| **Severity** | **Medium** |
| **Location** | `ForgeTypography.displayTitle` (defined, 0 usages); `displayAthletic` used in `ForgeHeroCard`, `ExerciseDetailView` |
| **Current** | `displayTitle` = 34pt black **serif**; `displayAthletic` = 34pt heavy italic default |
| **Recommended** | Remove `displayTitle` or document: `type.hero` = serif large titles (onboarding S-011, screen headers); `type.display` = athletic italic hero card titles (S-033, S-074) |
| **Rationale** | Two 34pt display tokens with different designs; one unused creates maintenance hazard. |
| **Verification checklist** | - [ ] Only one display token per semantic role in API<br>- [ ] S-011 uses `type.hero`; S-033 hero title uses `type.display`<br>- [ ] `displayTitle` removed or aliased |

---

### Finding SA-012

| Field | Value |
|---|---|
| **Smell** | Icon/symbol font sizes conflated with typography ramp |
| **Severity** | **Low** |
| **Location** | `ExerciseDemoPlayerView.swift` (40pt, 44pt play icons); `ForgeHeroCard.swift` L73 (18pt bolt); `ForgeFloatingTabBar` (18pt icon) |
| **Current** | `.font(.system(size: N))` on SF Symbols |
| **Recommended** | Use `Image(systemName:).font(.system(size: ForgeIcon.tab))` via `ForgeIcon` size tokens (foundation §8); do not add to typography ramp |
| **Rationale** | Icon sizing is orthogonal to text type ramp but currently uses `.font()` — separates concerns for lint rules ("no fixed size in feature code" should exclude icon tokens). |
| **Verification checklist** | - [ ] `ForgeIcon` enum with sm/md/lg/xl/tab/play<br>- [ ] Typography lint excludes `ForgeIcon.*` usages |

---

### Finding SA-013

| Field | Value |
|---|---|
| **Smell** | `ForgeTextField` mono input not tied to `type.metric` |
| **Severity** | **Medium** |
| **Location** | `OnboardingViews.swift` `ForgeTextField` (C-025); screens S-017, S-018, S-019, S-052, S-095 |
| **Current** | Input uses `ForgeTypography.monoMetric` (18pt fixed bold mono) for all fields including text names |
| **Recommended** | Numeric fields (weight, height, protein g) → `type.metric`; text fields (limitations, email) → `type.body`; placeholder → `type.body` + `text.secondary` |
| **Rationale** | Monospaced bold on "Shoulder injury" text (S-018) reads as data entry, not prose. Email field (S-095) should not use mono. |
| **Verification checklist** | - [ ] Body stats step (S-017) numeric only mono<br>- [ ] Limitations free-text (S-018) uses body<br>- [ ] Settings auth fields (S-095) use body |

---

### Finding SA-014

| Field | Value |
|---|---|
| **Smell** | Inline components lack extracted typography contract |
| **Severity** | **Low** |
| **Location** | C-027 `CoachMessageBubble` (inline in `CoachView.swift`); C-028 `ProgressStatCard` (inline in `ProgressDashboardView.swift`); C-021 `EmptyStateView` (inline in `TodayView.swift`) |
| **Current** | Bubble: user `body.semibold`, assistant `body`, proposal `.title2`; Progress cards: mix of `caption`/`title`/`monoMetric`; Empty: `heading` + `body` + 28pt icon |
| **Recommended** | Extract specs: Coach user → `type.body` + weight emphasis; assistant → `type.body`; proposal → `type.title`; progress card label → `type.label`, value → `type.metricHero` or `type.title`; empty title → `type.title`, body → `type.body` |
| **Rationale** | Component manifest flags C-027/C-028 for promotion; typography must be specified before extraction to avoid re-drifting. |
| **Verification checklist** | - [ ] Typography table in component spec for C-021, C-027, C-028<br>- [ ] Post-extraction grep shows no inline-only font patterns |

---

## Specs produced (type ramp specs)

### Canonical token implementation target

Replace `ForgeTypography.swift` contents with TextStyle-based semantic API:

| Token | Swift implementation | Weight | Design | Italic | Tracking | Primary roles |
|---|---|---|---|---|---|---|
| `type.hero` | `.largeTitle` | `.black` | `.serif` | — | `eyebrowWide` (2.5) on paired label only | Root screen titles (S-030–S-035, S-061, S-071) |
| `type.display` | `.title` | `.heavy` | `.default` | yes | — | Hero card athletic titles (S-033, S-040, S-074) |
| `type.title` | `.title2` | `.semibold` | `.default` | — | — | Section headings, list row titles, sheet titles |
| `type.body` | `.body` | `.regular` | `.default` | — | — | Body copy, assistant chat, descriptions |
| `type.bodyEmphasis` | `.body` | `.semibold` | `.default` | — | — | User chat bubble, emphasized inline |
| `type.label` | `.caption` | `.medium` | `.default` | — | `eyebrow` (2.0) when uppercase | Eyebrows, metadata, pill text |
| `type.cta` | `.caption` | `.bold` | `.default` | yes | `cta` (1.4) accent / `tight` (1.2) secondary | C-001 all variants |
| `type.metric` | `.title3` | `.bold` | `.monospaced` | — | — | Inline metrics, set counters, meal protein |
| `type.metricHero` | `.largeTitle` | `.bold` | `.monospaced` | — | — | Hero progress numbers (S-033, S-050, C-009) |
| `type.sessionTitle` | `.title2` | `.heavy` | `.default` | yes | — | Active exercise name (S-082, S-083) |
| `type.tabLabel` | `.caption2` | `.medium` / `.semibold` | `.default` | — | — | C-010 tab bar |
| `type.overlayStatus` | `.title3` | `.bold` | `.default` | — | `loading` (3.0) | C-022 regenerating overlay (S-034) |

### Tracking tokens

| Token | Value | Apply to |
|---|---|---|
| `tracking.tight` | 1.2 | Secondary button labels (C-001 `.secondary`, `.primary`, `.inverse`) |
| `tracking.cta` | 1.4 | Accent CTA (C-001 `.accent`) |
| `tracking.eyebrow` | 2.0 | Section eyebrows, hero labels, timeline focus labels |
| `tracking.eyebrowWide` | 2.5 | Root `ForgeScreenHeader` accessory label (C-004 `.root`) |
| `tracking.loading` | 3.0 | Full-screen loading overlay status (C-022) |

### Migration map (current → target)

| Current `ForgeTypography` | Target token | Action |
|---|---|---|
| `largeTitle` | `type.hero` | Reimplement with `.largeTitle` TextStyle |
| `displayTitle` | — | **Remove** (unused) |
| `displayAthletic` | `type.display` | Rename |
| `title` | `type.title` **or** `type.metricHero` | Split: serif 30pt → drop; numeric hero → `metricHero` |
| `heading` | `type.title` | Rename + merge |
| `body` | `type.body` | Reimplement |
| `caption` | `type.label` | Rename |
| `ctaLabel` | `type.cta` | Rename |
| `monoMetric` | `type.metric` | Rename |
| `heroMetric` | `type.metricHero` | Rename |
| *(missing)* | `type.sessionTitle` | **Add** |
| *(missing)* | `type.tabLabel` | **Add** |

### Component typography quick-spec

| ID | Component | Title | Body | Meta | Metric | CTA |
|---|---|---|---|---|---|---|
| C-001 | ForgeButton | — | — | — | — | `type.cta` |
| C-002 | ForgeCard | — | inherited | — | — | — |
| C-003 | ForgeHeroCard | `type.display` / `metricHero` | `type.body` | `type.label` | `type.metric` | via C-001 |
| C-004 | ForgeScreenHeader | `type.hero` / `type.title` | `type.body` | `type.label` | — | — |
| C-005 | ForgeHeaderBackButton | — | — | — | — | — |
| C-006 | ForgeSectionHeader | `type.title` | — | `type.label` | — | — |
| C-007 | ForgePill | — | — | `type.label` | — | — |
| C-008 | ForgeProgressBar | — | — | — | — | — |
| C-009 | MetricCard | — | `type.body` | `type.label` | `type.metricHero` | — |
| C-010 | ForgeFloatingTabBar | — | — | `type.tabLabel` | — | — |
| C-011 | ForgeTabBarMetrics | — | — | — | — | — |
| C-012 | ExerciseThumbnailView | — | — | `type.label` (badge) | — | — |
| C-013 | WorkoutExerciseTimelineRow | `type.title` | — | `type.label` | — | — |
| C-014 | WorkoutSessionHeaderView | `type.sessionTitle` | — | `type.label` | `type.metric` | — |
| C-015 | ExerciseDemoPlayerView | — | `type.label` | `type.label` | — | — |
| C-016 | ExerciseDetailMediaHero | `type.display` | `type.body` | `type.label` | — | — |
| C-017 | SwapExerciseSheet | `type.title` | `type.body` | `type.label` | — | — |
| C-018 | TodayMetricTile | — | — | `type.label` | `type.metric` | — |
| C-019 | TodayDisclosureSection | — | — | `type.label` | — | — |
| C-020 | TodayExerciseStrip | — | — | `type.label` | `type.metric` (sets) | — |
| C-021 | EmptyStateView | `type.title` | `type.body` | — | — | via C-001 |
| C-022 | ForgeHeroRegeneratingOverlay | `type.overlayStatus` | — | — | — | — |
| C-023 | SelectableRow | `type.title` | `type.body` | — | — | — |
| C-024 | SelectableChip | — | `type.body` | — | — | — |
| C-025 | ForgeTextField | — | `type.body` / `type.metric` | `type.label` | input | — |
| C-026 | SettingsSection | `type.body` | `type.body` | `type.label` | `type.metric` | — |
| C-027 | CoachBubble | — | `type.body` / `bodyEmphasis` | — | — | — |
| C-028 | ProgressStatCard | `type.title` | — | `type.label` | `type.metric` | — |

---

## Coverage log

### Screens (54/54)

| ID | Screen | Typography source | Status | Notes |
|---|---|---|---|---|
| S-001 | RootView onboarding route | — | ○ N/A | No text |
| S-002 | RootView main route | — | ○ N/A | Router only |
| S-003 | MainTabView | C-010 | ⚠ | Fixed 10pt tab labels (SA-007) |
| S-010 | Onboarding container | C-001, progress | ✓ | Progress unstyled |
| S-011 | Welcome | `type.hero`, body | ⚠ | Fixed largeTitle (SA-001) |
| S-012 | Goal | C-006, C-023 | ⚠ | Muted captions (SA-009) |
| S-013 | Experience | C-023 | ⚠ | Muted captions |
| S-014 | Location | C-023 | ⚠ | Muted captions |
| S-015 | Equipment | C-023 | ⚠ | Muted captions |
| S-016 | Schedule | C-024, heading | ✓ | Steppers system default |
| S-017 | Body stats | C-025 | ⚠ | Mono on all fields (SA-013) |
| S-018 | Limitations | C-023, C-025 | ⚠ | Mono on text field |
| S-019 | Protein | C-025 | ✓ | Mono appropriate |
| S-020 | Photo | C-023 | ✓ | |
| S-021 | Plan summary | body, C-001 | ✓ | |
| S-030 | Today empty | C-021, C-004 | ⚠ | 28pt icon (SA-010) |
| S-031 | Today loading | ProgressView | ○ N/A | System spinner |
| S-032 | Today rest day | C-003, C-004 | ✓ | |
| S-033 | Today workout ready | C-003, C-018–C-020 | ⚠ | Muted eyebrows |
| S-034 | Today regenerating | C-022 | ⚠ | tracking 3 untokenized |
| S-035 | Today completed | C-003 | ✓ | |
| S-040 | Train with workout | C-003, heading | ⚠ | `title` serif drift |
| S-041 | Train no workout | C-004 | ✓ | |
| S-042 | Train history empty | body, caption | ✓ | |
| S-050 | Protein empty | C-003, heading | ⚠ | Muted meal metadata |
| S-051 | Protein populated | hero metric, rows | ⚠ | Muted captions |
| S-052 | Protein custom sheet | C-025 | ⚠ | Mono input |
| S-053 | Protein save disabled | same | ⚠ | |
| S-055 | Progress loading | ProgressView | ○ N/A | |
| S-056 | Progress loaded | C-028 inline, caption | ⚠ | Serif `title` on metrics |
| S-057 | Progress per-card empty | body, caption | ⚠ | Muted |
| S-058 | Body progress empty | C-004, body | ✓ | |
| S-059 | Body progress photos | heading, caption | ⚠ | Muted dates |
| S-060 | Body comparison | caption, mono | ✓ | |
| S-061 | Coach tab empty | C-004 | ✓ | |
| S-062 | Coach messages | C-027 inline | ⚠ | No extracted spec |
| S-063 | Coach sending | body | ✓ | |
| S-064 | Coach proposal | `.title2` raw | ⚠ | SA-010 |
| S-065 | Coach banner | caption | ✓ | |
| S-066 | Coach push empty | same as S-061 | ✓ | |
| S-067 | Coach push messages | same as S-062 | ⚠ | |
| S-068 | Coach push sending | same | ✓ | |
| S-069 | Coach push proposal | same as S-064 | ⚠ | |
| S-070 | Coach push banner | same as S-065 | ✓ | |
| S-071 | Exercise library | heading, caption | ⚠ | Muted equipment |
| S-072 | Library filter empty | body | ✓ | |
| S-073 | Exercise detail loading | ProgressView | ○ N/A | |
| S-074 | Exercise detail loaded | display, body, label | ✓ | |
| S-075 | Exercise detail no video | C-016 placeholder | ⚠ | Fixed icon fonts |
| S-080 | Workout preview | C-013, caption | ✓ | |
| S-081 | Session loading | ProgressView | ○ N/A | |
| S-082 | Session active | C-014, C-015 | ✗ | Ad-hoc ramp (SA-002) |
| S-083 | Session resting | C-014 + timer | ✗ | Micro-type (SA-008) |
| S-084 | Completion inline | largeTitle, body | ⚠ | Fixed sizes |
| S-085 | Completion sheet | mono, body | ⚠ | |
| S-086 | Completion inline alt | same | ⚠ | |
| S-087 | Swap exercise | C-017 | ✓ | |
| S-088 | Swap empty | body, caption | ✓ | |
| S-090 | Settings default | C-026 | ⚠ | Muted captions |
| S-091 | Settings saving | caption | ✓ | |
| S-092 | Settings save error | caption destructive | ✓ | |
| S-093 | Settings auth error | caption destructive | ✓ | |
| S-094 | Settings signed in | body, caption | ✓ | |
| S-095 | Settings signed out | C-025 | ⚠ | Mono on email |
| S-096 | Settings supabase | body, caption | ✓ | |
| S-097 | Equipment picker | heading, body | ✓ | |
| S-100 | PhotosPicker | — | ○ N/A | System UI |

**Legend:** ✓ compliant enough for MVP · ⚠ drift/warning · ✗ critical gap · ○ no app typography

### Components (28/28)

| ID | Component | Has typography | Status | Finding refs |
|---|---|---|---|---|
| C-001 | ForgeButton | yes | ✓ | SA-006 tracking |
| C-002 | ForgeCard | no | ○ | Inherits children |
| C-003 | ForgeHeroCard | yes | ⚠ | SA-004, SA-009, icon 18pt |
| C-004 | ForgeScreenHeader | yes | ⚠ | SA-005 `.body` bypass |
| C-005 | ForgeHeaderBackButton | no | ○ | Icon only |
| C-006 | ForgeSectionHeader | yes | ✓ | |
| C-007 | ForgePill | yes | ✓ | |
| C-008 | ForgeProgressBar | no | ○ | |
| C-009 | MetricCard | yes | ✓ | |
| C-010 | ForgeFloatingTabBar | yes | ⚠ | SA-007 |
| C-011 | ForgeTabBarMetrics | no | ○ | Layout constant |
| C-012 | ExerciseThumbnailView | yes | ✗ | SA-008 9pt badge |
| C-013 | WorkoutExerciseTimelineRow | yes | ✓ | |
| C-014 | WorkoutSessionHeaderView | yes | ✗ | SA-002, SA-008 |
| C-015 | ExerciseDemoPlayerView | yes | ⚠ | SA-012 icon sizes |
| C-016 | ExerciseDetailMediaHero | yes | ⚠ | SA-012 |
| C-017 | SwapExerciseSheet | yes | ✓ | |
| C-018 | TodayMetricTile | yes | ⚠ | SA-005 caption bypass |
| C-019 | TodayDisclosureSection | yes | ⚠ | SA-005 |
| C-020 | TodayExerciseStrip | yes | ⚠ | SA-008 11pt mono |
| C-021 | EmptyStateView | yes | ⚠ | SA-010, SA-014 |
| C-022 | ForgeHeroRegeneratingOverlay | yes | ⚠ | SA-006 tracking 3 |
| C-023 | SelectableRow | yes | ✓ | |
| C-024 | SelectableChip | yes | ✓ | body token |
| C-025 | ForgeTextField | yes | ⚠ | SA-013 |
| C-026 | SettingsSection | yes | ⚠ | SA-009 muted |
| C-027 | CoachBubble | yes | ⚠ | SA-010, SA-014 |
| C-028 | ProgressStatCard | yes | ⚠ | SA-004, SA-014 |

---

## Open questions for orchestrator

1. **Serif `title` (30pt bold):** Foundation assigns serif only to `type.hero`. Should existing `ForgeTypography.title` serif usages on Progress dashboard (S-056) and Train history (S-040) migrate to `type.title` (semibold sans) or `type.metricHero` (mono)?

2. **`tracking` 1.5 vs 2.0:** Eight call sites use 1.5pt letter-spacing; spec says `eyebrow` = 2.0. Normalize to 2.0 (visual change) or add `tracking.compact` = 1.5 as documented exception?

3. **Session header density:** C-014 stat capsules use 8pt labels to fit three capsules + ring. Should layout reflow (stack vertically on compact width) rather than shrink type below caption2?

4. **Coach proposal banner:** S-064 uses `.title2` — should this be `type.title` or a new `type.banner` token distinct from session exercise title?

5. **Lint enforcement scope:** Should `ForgeIcon.*` be exempt from "no fixed size" rule while all `Text` must use `ForgeTypography.*`?

6. **Migration sequencing:** Refactor `ForgeTypography.swift` first (blocking) or per-screen rollout starting with S-082 session (highest user-visible risk)?

7. **Dark mode caption contrast:** Foundation notes muted fails at 13pt in light mode only — confirm `text.secondary` for dark mode captions too or keep current `muted`?

8. **Monospaced prose:** Confirm rule: mono design applies only to numeric metrics and timers, never to user-entered text fields.
