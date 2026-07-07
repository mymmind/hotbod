# Subagent F — Information Architecture, Navigation & Pattern Auditor

**Audit date:** 2026-07-07  
**Scope:** `AppRouter.swift`, `HotBodApp.swift` / `RootView`, `screen_manifest.md` (54 screen-states), tab shells, onboarding flow, empty/loading states  
**Baseline:** `AGENTS.md` (local-first MVP, safety-first generation, fast logging), `screen_manifest.md` navigation graph

---

## Coverage

| Area | Target | Audited | Notes |
|---|---|---|---|
| `AppRoute` cases | 7 | 7 | All wired in `RootView`; 3 unreachable via router |
| Tab roots | 5 | 5 | Today, Train, Protein, Progress, Coach |
| Onboarding steps | 11 (0–10) | 11 | `OnboardingContainerView` TabView |
| Manifest screen-states | 54 | 54 | Cross-checked entry points vs code |
| Empty-state patterns | 9 documented | 9 | Implementation consistency varies |
| Overlay vs push vs sheet | 6 flows | 6 | Workout preview/session, settings, coach, exercise detail |

**Severity summary:** 3 Critical · 5 High · 6 Medium · 2 Low = **16 findings**

---

## Tools / references used

| Tool / reference | Purpose |
|---|---|
| `HotBod/App/AppRouter.swift` | Route enum, tab model, stack semantics |
| `HotBod/App/HotBodApp.swift` | Root switcher, bootstrap routing |
| `docs/design/screen_manifest.md` | Canonical screen-state inventory & dead-code notes |
| `HotBod/Features/Today/MainTabView.swift` | Tab shell |
| `HotBod/Features/Onboarding/OnboardingViews.swift` | Onboarding length & validation |
| `rg 'navigate\(to:|\.sheet\(|navigationDestination|EmptyStateView'` | Navigation & empty-state call sites |

---

## Navigation model summary

```
App launch
  └─ RootView (switch router.route)
       ├─ .onboarding → OnboardingContainerView (11 steps)
       └─ .main → MainTabView (5 tabs, ForgeFloatingTabBar)
            ├─ Today (NavigationStack + sheets/push)
            ├─ Train (NavigationStack + library push)
            ├─ Protein (NavigationStack + custom sheet)
            ├─ Progress (NavigationStack + BodyProgress push)
            └─ Coach (NavigationStack when .tab)

Full-screen overlays (replace MainTabView entirely):
  .workoutPreview, .workoutSession  ← actively used
  .exerciseDetail, .settings, .coach ← wired in RootView, never navigated
```

**Active overlay pattern:** `router.navigate(to:)` from tabs pushes workout preview; `router.replace(with:)` transitions preview → session. `dismissRoute()` / `dismissToMain()` pop back to `.main`.

---

## Findings

### Finding SF-001

| Field | Value |
|---|---|
| **Smell** | Returning users flash onboarding on every cold launch |
| **Severity** | **Critical** |
| **Location** | `AppRouter.swift` L15 (`route = .onboarding`); `HotBodApp.swift` L14–17 (`.task` sets route after `bootstrap()`) |
| **Current** | `router.route` initializes to `.onboarding`. `RootView` renders onboarding immediately. After async bootstrap, route switches to `.main` if `hasCompletedOnboarding`. |
| **Recommended** | Initialize route to a neutral `.bootstrapping` splash or block `RootView` behind bootstrap completion before first paint; alternatively persist last route in memory synchronously from a lightweight onboarding flag read. |
| **Rationale** | Violates perceived continuity for the primary user cohort. Manifest S-002 assumes direct main entry post-onboarding; S-001 flash is unintended. |
| **Verification checklist** | - [ ] Cold launch with completed onboarding: zero onboarding frames<br>- [ ] First launch still lands on S-010<br>- [ ] No double animation onboarding → main |

---

### Finding SF-002

| Field | Value |
|---|---|
| **Smell** | Three dead `AppRoute` overlay cases in production switch |
| **Severity** | **Critical** |
| **Location** | `AppRouter.swift` L8–10; `HotBodApp.swift` L45–59; `screen_manifest.md` Excluded / Dead Code |
| **Current** | `.exerciseDetail`, `.settings`, `.coach` each render dedicated `NavigationStack` branches in `RootView`. Grep shows **zero** `navigate(to: .settings)`, `navigate(to: .coach)`, or `navigate(to: .exerciseDetail)` call sites. Settings uses `.sheet` from Today; Coach uses tab + `navigationDestination`; exercise detail uses `NavigationLink` inside tab stacks. |
| **Recommended** | Remove dead cases from `AppRoute` and `RootView`, or add a single `openCoach()` / unified deep-link API if overlays are intentional. Keep one presentation path per destination. |
| **Rationale** | Dual navigation graphs increase audit surface (manifest already documents the drift). Future contributors may wire the wrong path. `ExerciseDetailView.handleBack()` already branches on `isRouterPresented` for a path that never fires. |
| **Verification checklist** | - [ ] Each screen has exactly one entry mechanism documented in manifest<br>- [ ] `AppRoute` cases ⊆ reachable routes<br>- [ ] No `Presentation.routerOverlay` branches without callers |

---

### Finding SF-003

| Field | Value |
|---|---|
| **Smell** | Onboarding Continue never gated — silent defaults for safety inputs |
| **Severity** | **Critical** |
| **Location** | `OnboardingViews.swift` L35–41 (Continue always enabled); `UserProfile.empty()` defaults in `DomainModels.swift` |
| **Current** | User can tap Continue through all 11 steps without selecting goal, experience, location, equipment, limitations, or protein. `UserProfile.empty()` pre-fills intermediate gym-goer defaults (4 days/week, full equipment, build muscle, etc.). |
| **Recommended** | Per-step validation: disable Continue until required fields set; highlight incomplete steps on progress bar; minimum viable path = goal + experience + equipment + limitations acknowledgment. |
| **Rationale** | Conflicts with AGENTS.md "Safety-first workout generation." Onboarding appears comprehensive but can produce a profile the user never reviewed. |
| **Verification checklist** | - [ ] Cannot finish onboarding with unset goal/equipment<br>- [ ] Limitations step requires explicit "None" or selection<br>- [ ] Saved profile reflects user choices, not only defaults |

---

### Finding SF-004

| Field | Value |
|---|---|
| **Smell** | 11-step onboarding exceeds MVP activation friction |
| **Severity** | **High** |
| **Location** | `OnboardingViews.swift` L15–27; manifest S-010–S-021 |
| **Current** | Steps: Welcome → Goal → Experience → Location → Equipment → Schedule → Body Stats → Limitations → Protein → Photo → Plan. Only photo step offers explicit skip. Estimated 11 Continue taps to first workout. |
| **Recommended** | Collapse to 5–6 steps: (1) Welcome, (2) Goal + Experience, (3) Equipment + Location, (4) Schedule, (5) Limitations + body stats, (6) Plan summary. Defer protein tuning and photo setup to in-app prompts on Protein/Progress tabs. |
| **Rationale** | Fitbod-class apps typically reach first workout faster. Photo and protein are secondary differentiators — better as post-onboarding empty-state CTAs (already built on those tabs). |
| **Verification checklist** | - [ ] Median time-to-main < 90s in usability test<br>- [ ] Step count ≤ 6 without losing required generator inputs<br>- [ ] Post-onboarding regenerate still succeeds |

---

### Finding SF-005

| Field | Value |
|---|---|
| **Smell** | Coach has redundant entry points (tab + Today push + dead overlay) |
| **Severity** | **High** |
| **Location** | `MainTabView.swift` L18–19; `TodayView.swift` L53–55, L452; `CoachView.Presentation`; manifest S-061–S-070 |
| **Current** | Coach is both a **5th tab** and reachable via Today **"Ask Coach"** `navigationDestination` push (`presentation: .navigationPush`). A third `routerOverlay` presentation exists but is unused. Same feature, three navigation metaphors. |
| **Recommended** | Pick one primary: either demote Coach to contextual push-only (remove tab) **or** remove Today "Ask Coach" and deep-link to Coach tab with prefilled suggestion. Remove `routerOverlay` variant. |
| **Rationale** | Five tabs already crowd `ForgeFloatingTabBar`. Duplicate Coach paths split conversation context (tab history vs ephemeral push). |
| **Verification checklist** | - [ ] Single documented Coach entry in manifest<br>- [ ] Tab bar item count matches IA decision<br>- [ ] "Ask Coach" from Today lands in consistent UI state |

---

### Finding SF-006

| Field | Value |
|---|---|
| **Smell** | Settings split across sheet and dead router overlay |
| **Severity** | **High** |
| **Location** | `TodayView.swift` L52; `SettingsView.swift` L4–9, L51–52, L636–637; `HotBodApp.swift` L50–54 |
| **Current** | Production entry: `SettingsView(presentation: .sheet)` from Today gear. `SettingsView(presentation: .routerOverlay)` supports `ForgeHeaderBackButton` + `router.dismissRoute()` but is only referenced from unreachable `AppRoute.settings`. Reset Onboarding calls `router.showOnboarding()` after sheet dismiss — works, but overlay path is dead. |
| **Recommended** | Delete `routerOverlay` presentation and `AppRoute.settings`. Keep sheet as sole entry; ensure reset/sign-out always dismiss sheet before route change. |
| **Rationale** | Manifest S-090 correctly documents sheet entry; dead overlay duplicates back-stack behavior and confuses settings navigation ownership. |
| **Verification checklist** | - [ ] Settings reachable only from Today sheet<br>- [ ] Reset onboarding returns to S-010 without stale sheet<br>- [ ] No `case .settings` in RootView |

---

### Finding SF-007

| Field | Value |
|---|---|
| **Smell** | Train history is read-only — no navigation to session detail |
| **Severity** | **High** |
| **Location** | `TrainViews.swift` L61–94; manifest S-042 |
| **Current** | Last 5 completed sessions render as static text rows (title + date). No `NavigationLink`, sheet, or tap handler. Completion summary exists (`WorkoutCompletionView` S-085) but only from Today completed state. |
| **Recommended** | Tap row → push or sheet `WorkoutCompletionView` for that session; or navigate to a lightweight `SessionDetailView`. |
| **Rationale** | IA dead end on Train tab undermines "fast workout logging" parity — users cannot review past work from the natural history surface. |
| **Verification checklist** | - [ ] Tap history row opens summary<br>- [ ] Empty history still shows S-042 copy<br>- [ ] Back returns to Train tab root |

---

### Finding SF-008

| Field | Value |
|---|---|
| **Smell** | Onboarding photo step sets flag only — no photo capture |
| **Severity** | **High** |
| **Location** | `OnboardingPhotoView` in `OnboardingViews.swift` L292–306; manifest S-020 |
| **Current** | "Set Up Photo Tracking" sets `photoTrackingEnabled = true`; "Skip For Now" sets false. Neither opens `PhotosPicker` or routes to `BodyProgressView`. User may believe photos are configured. |
| **Recommended** | "Set Up" → present `PhotosPicker` or push `BodyProgressView` after onboarding; or rename to "Enable photo reminders" with honest copy. |
| **Rationale** | False completion undermines trust; Progress tab empty state (S-058) becomes the real first photo moment without onboarding handoff. |
| **Verification checklist** | - [ ] Enable path results in ≥0 photos or explicit deferred state<br>- [ ] Copy does not imply photo already captured<br>- [ ] Progress tab reflects onboarding choice |

---

### Finding SF-009

| Field | Value |
|---|---|
| **Smell** | Empty-state component used only on Today — inconsistent pattern |
| **Severity** | **Medium** |
| **Location** | `TodayView.swift` L117–124, L593–607; `TrainViews.swift` L68–71; `ProteinTrackerView.swift` L86–87; `ProgressDashboardView.swift` (per-card muted text) |
| **Current** | `EmptyStateView` (title, message, optional CTA) exists only for Today "No workout yet." Train, Protein, Coach, library, and progress cards use inline `Text("…").foregroundStyle(ForgeColors.muted)` without shared structure or actions. |
| **Recommended** | Promote `EmptyStateView` to `Core/Components`; adopt on Train (no workout, empty history), Protein (no entries), Coach (pre-messages), library filter-empty, Body Progress timeline. |
| **Rationale** | Fragmented empty UX weakens brutalist consistency and reduces discoverability of recovery actions. |
| **Verification checklist** | - [ ] ≥5 surfaces use shared empty component<br>- [ ] Each empty state has primary CTA where applicable<br>- [ ] Visual weight matches ForgeHeroCard sections |

---

### Finding SF-010

| Field | Value |
|---|---|
| **Smell** | Train "no workout" manifest state not implemented |
| **Severity** | **Medium** |
| **Location** | `TrainViews.swift` L108–113; manifest S-041 |
| **Current** | When `todayWorkout == nil`, Train shows header subtitle "Generate today's session from the Today tab." No `EmptyStateView`, no button, no tab switch. Workout card section simply omitted. |
| **Recommended** | Dedicated empty card with CTA: "Go to Today" (`router.selectedTab = .today`) or inline regenerate if generator callable from Train. |
| **Rationale** | Manifest documents S-041 as distinct state; implementation is passive copy only — users on Train tab hit a dead end. |
| **Verification checklist** | - [ ] No-workout Train matches S-041 spec<br>- [ ] CTA switches tab or generates workout<br>- [ ] History/library still visible below empty hero |

---

### Finding SF-011

| Field | Value |
|---|---|
| **Smell** | Exercise library filter-empty state missing |
| **Severity** | **Medium** |
| **Location** | `ExerciseLibraryView.swift` L24–44; manifest S-072 |
| **Current** | `List(filtered)` renders empty list with no placeholder when search/filters yield zero results. No `EmptyStateView` or "Clear filters" action. |
| **Recommended** | When `filtered.isEmpty && !exercises.isEmpty`, show empty message + "Clear filters" button resetting query and menus. |
| **Rationale** | Manifest S-072 audited but unimplemented — users see blank list (ambiguous vs loading). |
| **Verification checklist** | - [ ] Filter to zero shows S-072 copy<br>- [ ] Clear filters restores list<br>- [ ] True empty catalog distinguished from filter-empty |

---

### Finding SF-012

| Field | Value |
|---|---|
| **Smell** | Today workout-empty loading state incomplete |
| **Severity** | **Medium** |
| **Location** | `TodayView.swift` L115–127; manifest S-031 |
| **Current** | Manifest documents Today/Empty **loading** variant during `.task` load. Code shows `EmptyStateView` immediately when `todayWorkout == nil` with "Retry" regenerate — no `ProgressView` for initial bootstrap/regeneration before first result. Regenerating overlay only covers hero when workout exists. |
| **Recommended** | Add `environment.isLoadingTodayWorkout` (or similar) to show loading skeleton/spinner instead of empty+Retry during first generate. |
| **Rationale** | Empty + "Retry" on first launch reads as failure, not loading. |
| **Verification checklist** | - [ ] First post-onboarding load shows loading, not empty<br>- [ ] Failed generate still shows Retry<br>- [ ] S-031 state reachable |

---

### Finding SF-013

| Field | Value |
|---|---|
| **Smell** | Nested `NavigationStack` on Body Progress push |
| **Severity** | **Medium** |
| **Location** | `ProgressDashboardView.swift` L9; `BodyProgressView.swift` L14; manifest S-058–S-060 |
| **Current** | Progress tab root wraps content in `NavigationStack`. `bodyProgressCard` `NavigationLink` pushes `BodyProgressView`, which creates **another** `NavigationStack` with its own `.navigationTitle`. |
| **Recommended** | Remove inner `NavigationStack` from `BodyProgressView` when pushed; use `ForgeScreenHeader` consistent with other feature pushes. |
| **Rationale** | Double stacks can break back gesture, large-title behavior, and `navigationDestination` inheritance. |
| **Verification checklist** | - [ ] Single back affordance from Body Progress<br>- [ ] No duplicate nav bars<br>- [ ] Compare mode (S-060) still works |

---

### Finding SF-014

| Field | Value |
|---|---|
| **Smell** | Workout overlay dismiss loses tab context unpredictably |
| **Severity** | **Medium** |
| **Location** | `AppRouter.swift` L55–84; `WorkoutSessionView.swift` L43, L72 |
| **Current** | `navigate(to:)` from `.main` sets `routeStack = [.main]`. Preview/session use `dismissRoute()` or `dismissToMain()`. `selectedTab` is preserved (good) but overlay always returns to whichever tab was active — no affordance if user started from Today vs Train. Minor: exiting session mid-workout uses `dismissToMain()` without confirm on tab bar reappearance. |
| **Recommended** | Document expected behavior; consider returning to originating tab via metadata on navigate; add exit confirmation before `dismissToMain()` mid-session. |
| **Rationale** | IA clarity for full-screen flows that replace entire tab shell. |
| **Verification checklist** | - [ ] Start from Train → exit → still Train tab<br>- [ ] Mid-session exit confirms data loss<br>- [ ] Complete session lands Today with completed hero |

---

### Finding SF-015

| Field | Value |
|---|---|
| **Smell** | Progress recovery card copy implies loading when empty |
| **Severity** | **Low** |
| **Location** | `ProgressDashboardView.swift` L225–227; manifest S-057 |
| **Current** | When `recoveryByMuscle.isEmpty`, shows "Recovery data loading..." even after `isLoading == false`. |
| **Recommended** | Use honest empty copy: "Complete workouts to see muscle readiness" or tie to HealthKit permission state. |
| **Rationale** | Misleading state label — user waits indefinitely for data that may not arrive. |
| **Verification checklist** | - [ ] Post-load empty shows static message<br>- [ ] Loading spinner only when `isLoading`<br>- [ ] HealthKit denied state handled |

---

### Finding SF-016

| Field | Value |
|---|---|
| **Smell** | Today empty CTA label "Retry" mismatches intent |
| **Severity** | **Low** |
| **Location** | `EmptyStateView` L603; `TodayView.swift` L117–123 |
| **Current** | Message: "Generate today's … session." Button title hardcoded as "Retry" in `EmptyStateView`. |
| **Recommended** | Parameterize button title (`actionTitle: "Generate"`) or default to "Generate" for first-load empty. |
| **Rationale** | "Retry" implies prior failure; first-time empty is not a retry scenario. |
| **Verification checklist** | - [ ] First empty shows "Generate"<br>- [ ] Failed regenerate shows "Retry"<br>- [ ] Button triggers `regenerateTodayWorkout` |

---

## Dead routes & manifest reconciliation

| `AppRoute` | Manifest | Live entry | Status |
|---|---|---|---|
| `.onboarding` | S-010–S-021 | Bootstrap / Settings reset | **Live** |
| `.main` | S-003 + tabs | Post-onboarding | **Live** |
| `.workoutPreview` | S-080 | Today, Train → `navigate` | **Live** |
| `.workoutSession` | S-081–S-084 | Preview/Train/Today `replace` | **Live** |
| `.exerciseDetail` | S-073–S-075 | `NavigationLink` in Train/Preview stacks only | **Overlay dead** |
| `.settings` | S-090–S-097 | Today `.sheet` only | **Overlay dead** |
| `.coach` | S-061–S-070 | Tab + Today push only | **Overlay dead** |

**Manifest accuracy:** Excluded / Dead Code section (lines 167–174) is **correct**. `LegacyProgressDashboardView` no longer exists in codebase — stale manifest row can be removed.

---

## Onboarding length scorecard

| Metric | Value | Assessment |
|---|---|---|
| Step count | 11 | High friction |
| Skippable steps | 1 (photo explicit skip) | Low flexibility |
| Required validation | 0 gates | **Risk** |
| Time to first workout CTA | Step 10 "Start Today's Workout" | Late |
| Generator-critical fields | Goal, experience, equipment, schedule, limitations | Collectable in fewer screens |

---

## Empty-state coverage matrix

| Surface | Manifest ID | Shared component | Actionable CTA |
|---|---|---|---|
| Today no workout | S-030 | `EmptyStateView` | Retry (mislabeled) |
| Today loading | S-031 | — | **Missing** |
| Train no workout | S-041 | — | **Missing** |
| Train history empty | S-042 | Inline text | No |
| Protein meals empty | S-050 | Inline text | Fast-add nearby |
| Coach empty | S-061 | Inline suggestions | Tap suggestion |
| Progress per-card | S-057 | Inline text | No |
| Body photos empty | S-058 | Inline text | Add Photo on detail |
| Library filter empty | S-072 | — | **Missing** |
| Swap substitutes empty | S-088 | (sheet) | — |

---

## Recommended priority order

1. **SF-001** — Eliminate onboarding flash (every returning session).  
2. **SF-002 / SF-006** — Remove dead `AppRoute` cases; unify settings/coach/exercise presentation.  
3. **SF-003 / SF-004** — Shorten onboarding + add validation gates.  
4. **SF-005** — Resolve Coach tab vs push redundancy.  
5. **SF-007 / SF-009–SF-012** — Close empty-state and history navigation gaps.

---

## Critical count

**3 Critical findings:** SF-001, SF-002, SF-003
