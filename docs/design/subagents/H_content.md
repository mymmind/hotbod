# Subagent H — Content & Microcopy Auditor

**Audit date:** 2026-07-07  
**Scope:** `HotBod/Features/**`, `HotBod/Core/Components/**`, tab labels in `AppRouter.swift`, sync/status strings in `AppEnvironment.swift`  
**Baseline:** `AGENTS.md` product principles — brutalist UI, no cheesy motivational copy, no medical claims, safety-first tone

---

## Coverage

| Area | Target | Audited | Notes |
|---|---|---|---|
| Feature views | 12 Swift files | 12 | Today, Train, WorkoutSession, Onboarding, Settings, Protein, BodyProgress, Coach, ExerciseLibrary, ExerciseDetail, ProgressDashboard, MainTabView |
| Core components | 8 text-bearing | 8 | ForgeHeroCard, ForgeScreenHeader, SwapExerciseSheet, WorkoutSessionHeaderView, ExerciseDemoPlayerView, WorkoutExerciseTimelineRow, EmptyStateView (in TodayView) |
| `Text("` call sites | 60+ | 60+ | Grep across Features + Components |
| Button / CTA titles | 45+ | 45+ | `ForgeButton`, `Button("…")`, hero `primaryAction` / `secondaryActions` |
| Empty states | 11 | 11 | Workout, history, protein, progress charts, photos, coach, swap sheet |
| Error / status messages | 8 | 8 | Settings auth/save, sync banner, food search, Gemini config |
| Localization | Required for ship | **0** | No `.strings`, no `String(localized:)`, no `LocalizedStringKey` |
| Accessibility labels | 6 | 6 | Back, exit workout, exercise progress, angle |

**Severity summary:** 3 Critical · 5 High · 5 Medium · 3 Low = **16 findings**

**Critical count: 3**

---

## Tools / references used

| Tool / reference | Purpose |
|---|---|
| `rg 'Text\("' HotBod/Features HotBod/Core/Components` | Inline copy inventory |
| `rg 'ForgeButton\(title:|Button\("|primaryAction:|secondaryActions:'` | CTA verb audit |
| `rg '\.navigationTitle\(|EmptyState|authError|localizedDescription'` | Sheets, empty states, errors |
| `glob **/*.strings` | Localization presence check |
| `AGENTS.md` | Voice rules: no cheesy copy, no medical claims, safety-first |

---

## Voice register (target)

| Dimension | Target | Current drift |
|---|---|---|
| Tone | Direct, technical, calm — coach explains, never hypes | Occasional casual slang ("sketchy"), streak language ("keep the streak alive") |
| Person | Second person sparingly; prefer imperative CTAs | Mixed ("Ask your coach" vs "Generate today's…") |
| Case | Sentence case for body; ALL CAPS only for micro-labels (≤3 words) | Inconsistent: `HISTORY`, `WORKOUT COMPLETE`, `RESHUFFLING` alongside Title Case headers |
| Verbs | Consistent action verbs on buttons: Start, Save, Skip, Swap, Done | "Start" vs "Start Workout"; "Apply Workout" vs "Dismiss" |
| Numbers | Units explicit: `g`, `kg`, `min`, `%` | Mostly good; `Cal` abbreviated in session header |
| Safety | Plain language; disclaimers where inference is visual | Onboarding photo disclaimer ✓; comparison metrics need same framing |
| Errors | Human, actionable — never raw API/system strings | `error.localizedDescription` shown in Settings |

---

## Findings

### Finding SH-001

| Field | Value |
|---|---|
| **Smell** | No localization infrastructure |
| **Severity** | **Critical** |
| **Location** | All audited files; zero `*.strings` in repo |
| **Current** | Every user-visible string is hardcoded English literal in Swift (`Text("…")`, `title: "…"`, `Button("…")`) |
| **Recommended** | Introduce `Localizable.xcstrings`; wrap UI strings in `String(localized:)` or `LocalizedStringKey`; extract tab labels, CTAs, empty states, errors into string catalog; add `en` base + export pipeline |
| **Rationale** | Ship blocker for non-English markets; prevents copy iteration without recompile; duplicates will proliferate as features grow |
| **Verification checklist** | - [ ] `*.xcstrings` exists with ≥100 keys<br>- [ ] Tab labels and primary CTAs localized<br>- [ ] Preview builds with pseudolocale (long strings) |

---

### Finding SH-002

| Field | Value |
|---|---|
| **Smell** | Developer setup instructions in user Settings |
| **Severity** | **Critical** |
| **Location** | `SettingsView.swift` — Cloud section when Supabase not configured |
| **Current** | `"Copy SupabaseConfig.plist.example to SupabaseConfig.plist and add your project URL + anon key."` |
| **Recommended** | User-facing: `"Cloud sync is not available in this build."` or hide section entirely in production; dev-only copy behind `#if DEBUG` |
| **Rationale** | Breaks premium product illusion; exposes internal file names; confuses non-developer users |
| **Verification checklist** | - [ ] Release build never shows plist instructions<br>- [ ] Cloud section has user-appropriate empty state |

---

### Finding SH-003

| Field | Value |
|---|---|
| **Smell** | Raw system/API errors shown to users |
| **Severity** | **Critical** |
| **Location** | `SettingsView.swift` — `authError = error.localizedDescription`; `saveError = environment.syncMessage ?? "Could not save settings."` |
| **Current** | Supabase/network NSError text surfaced verbatim in red body text |
| **Recommended** | Map known error domains to catalog strings: invalid credentials, network offline, sync conflict; fallback: `"Something went wrong. Try again."` |
| **Rationale** | Unprofessional tone; may leak implementation details; fails accessibility (verbose, technical) |
| **Verification checklist** | - [ ] Wrong password shows friendly message, not HTTP status<br>- [ ] Offline sync shows actionable copy<br>- [ ] No `localizedDescription` in user-visible UI |

---

### Finding SH-004

| Field | Value |
|---|---|
| **Smell** | Empty-state CTA says "Retry" for generation, not failure |
| **Severity** | **High** |
| **Location** | `EmptyStateView` in `TodayView.swift`; used when `todayWorkout == nil` |
| **Current** | Title: `"No workout yet"`; message mentions generate; button: `"Retry"` |
| **Recommended** | Parameterize CTA: `"Generate Workout"` or `"Build Today's Session"`; reserve `"Retry"` for failed network/load |
| **Rationale** | "Retry" implies a prior attempt failed; user has not tried yet — cognitive mismatch |
| **Verification checklist** | - [ ] Empty today workout shows generate-oriented verb<br>- [ ] Failed regenerate overlay uses "Retry" or "Try Again" |

---

### Finding SH-005

| Field | Value |
|---|---|
| **Smell** | Implementation-branded coach status labels |
| **Severity** | **High** |
| **Location** | `CoachView.swift` — `coachConnectionLabel` |
| **Current** | `"CLOUD COACH"`, `"SIGN IN FOR CLOUD COACH"`, `"GEMINI COACH"`, `"OFFLINE COACH"` |
| **Recommended** | User-facing: `"Online"`, `"Sign in to sync coach"`, `"AI Coach"`, `"On-device coach"` — no vendor/model names in UI |
| **Rationale** | Exposes stack (Gemini, Supabase); ALL CAPS eyebrow reads as debug banner, not product chrome |
| **Verification checklist** | - [ ] No third-party model names in production UI<br>- [ ] Eyebrow uses `type.label` sentence case per typography audit |

---

### Finding SH-006

| Field | Value |
|---|---|
| **Smell** | Inconsistent primary workout CTA wording |
| **Severity** | **High** |
| **Location** | `TrainViews.swift` hero `("Start", …)` vs `("Start Workout", …)` in Today/Preview/Onboarding |
| **Current** | Train tab hero primary action is `"Start"`; elsewhere `"Start Workout"` |
| **Recommended** | Standardize on one key: `cta.startWorkout` → `"Start Workout"` everywhere (or `"Start"` only on hero when context is obvious) |
| **Rationale** | Same action, different labels — undermines muscle memory and localization key reuse |
| **Verification checklist** | - [ ] Single string key for start-session CTA<br>- [ ] VoiceOver reads same label on Today and Train |

---

### Finding SH-007

| Field | Value |
|---|---|
| **Smell** | ALL CAPS shout labels mixed with sentence-case UI |
| **Severity** | **High** |
| **Location** | `TrainViews` (`HISTORY`), `WorkoutSessionView` (`SET`, `TARGET`, `ACTUAL`, `WORKOUT COMPLETE`, `REST`), `TodayView` (`RESHUFFLING`), `ExerciseDetailView` (`COMMON MISTAKES`), `WorkoutExerciseTimelineRow` (`FOCUS EXERCISE`) |
| **Current** | 10+ full-word ALL CAPS strings alongside Title Case section headers |
| **Recommended** | Reserve ALL CAPS for ≤3-char column headers or tracking eyebrows; use `"History"`, `"Workout complete"`, `"Common mistakes"` for longer labels |
| **Rationale** | AGENTS brutalist ≠ all-caps body; accessibility suffers (screen readers spell letters); inconsistent with `ForgeSectionHeader` pattern |
| **Verification checklist** | - [ ] No ALL CAPS strings >12 characters in Features<br>- [ ] Column headers use caption + tracking token |

---

### Finding SH-008

| Field | Value |
|---|---|
| **Smell** | Casual / motivational copy drift |
| **Severity** | **Medium** |
| **Location** | `CoachView` suggestion `"My shoulder feels sketchy, adjust this."`; `ProteinTrackerView` `"Goal hit — keep the streak alive."`; `TodayView` `"Good night"` (22:00–05:00) |
| **Current** | Slang and streak gamification in product copy |
| **Recommended** | Coach chip: `"Shoulder discomfort — adjust exercises"`; protein: `"Goal met for today"`; time greeting: `"Good evening"` until sleep hours or omit after 22:00 |
| **Rationale** | AGENTS.md: "No cheesy motivational copy"; coach suggestions should model desired user tone |
| **Verification checklist** | - [ ] Grep for sketchy/streak/crush/kill it — zero in Features<br>- [ ] Coach suggestions read as exemplar queries |

---

### Finding SH-009

| Field | Value |
|---|---|
| **Smell** | Ambiguous duplicate "Skip" actions |
| **Severity** | **Medium** |
| **Location** | `WorkoutSessionView` — rest timer `Button("Skip")` vs exercise `ForgeButton(title: "Skip")` |
| **Current** | Same verb for skip rest vs skip entire exercise |
| **Recommended** | Rest: `"Skip Rest"`; exercise: `"Skip Exercise"` (matches existing `"Swap Exercise"` pattern) |
| **Rationale** | One-handed logging needs unambiguous verbs; destructive-adjacent action (skip exercise) should be explicit |
| **Verification checklist** | - [ ] Rest and exercise skip labels differ<br>- [ ] VoiceOver distinguishes actions |

---

### Finding SH-010

| Field | Value |
|---|---|
| **Smell** | Coach proposal actions lack parallel structure |
| **Severity** | **Medium** |
| **Location** | `CoachView.swift` — `Button("Apply Workout")` / `Button("Dismiss")` |
| **Current** | Noun-heavy apply vs bare dismiss; dismiss is not styled as secondary |
| **Recommended** | `"Apply"` + `"Not now"` or `"Replace workout"` + `"Keep current"`; use `ForgeButton` secondary for cancel path |
| **Rationale** | Paired choices should be symmetric; "Dismiss" is vague (dismiss proposal vs close coach) |
| **Verification checklist** | - [ ] Proposal sheet has clear accept/decline pair<br>- [ ] Decline does not sound like closing the app |

---

### Finding SH-011

| Field | Value |
|---|---|
| **Smell** | Empty-state copy pattern inconsistency |
| **Severity** | **Medium** |
| **Location** | Multiple features |
| **Current** | `"No entries yet."` / `"No completed workouts yet."` / `"No photos yet. Import your first progress photo."` / `"No strength data yet. Complete some workouts."` — mixed period, second sentence, verb choice (Import vs Add) |
| **Recommended** | Template: `[No {noun} yet.] [Optional: {Imperative CTA sentence}.]` — e.g. `"No photos yet. Add your first progress photo."` |
| **Rationale** | Predictable rhythm helps scanning; "Import" vs "Add Photo" button mismatch on Body Progress |
| **Verification checklist** | - [ ] All empty states follow two-line template<br>- [ ] CTA verb matches nearby button label |

---

### Finding SH-012

| Field | Value |
|---|---|
| **Smell** | Body progress metrics without consistent disclaimer framing |
| **Severity** | **Medium** |
| **Location** | `BodyProgressView.swift` — `"Shoulder-to-waist visual ratio: %.2f"`; `comparisonSummary` |
| **Current** | Numeric visual ratio displayed like a clinical metric; onboarding disclaimer not echoed |
| **Recommended** | Prefix: `"Visual trend (not body fat):"`; ensure `comparisonSummary` never implies medical measurement |
| **Rationale** | AGENTS: "No exact body-fat claims from selfies"; ratio language risks misinterpretation |
| **Verification checklist** | - [ ] Comparison card includes non-medical qualifier<br>- [ ] No `% body fat` phrasing in UI |

---

### Finding SH-013

| Field | Value |
|---|---|
| **Smell** | Sync status messages lack user context |
| **Severity** | **Low** |
| **Location** | `AppEnvironment.swift` — `syncMessage` strings |
| **Current** | `"Signed in. Data synced."`, `"Sync complete."`, `"Sign in to sync."` — period-heavy, terse |
| **Recommended** | `"You're signed in and up to date."`; `"Sign in to back up progress photos."` (specific benefit) |
| **Rationale** | Settings subtitle says "Sign in to sync" but backup value prop is photos — align copy |
| **Verification checklist** | - [ ] Sync toast mentions what synced (profile, photos, workouts)<br>- [ ] Sign-in prompt states benefit |

---

### Finding SH-014

| Field | Value |
|---|---|
| **Smell** | Abbreviated stat labels in session header |
| **Severity** | **Low** |
| **Location** | `WorkoutSessionHeaderView.swift` — `label: "Cal"` |
| **Current** | `"Cal"` abbreviated; `"Sets"`, `"Session"` spelled out |
| **Recommended** | `"Calories"` in accessibility label; visible can stay `"Cal"` if space-constrained — document in register |
| **Rationale** | VoiceOver users hear "Cal" ambiguously (California? calories?) |
| **Verification checklist** | - [ ] `accessibilityLabel` on stat capsules uses full words |

---

### Finding SH-015

| Field | Value |
|---|---|
| **Smell** | Placeholder / default field copy as product strings |
| **Severity** | **Low** |
| **Location** | `ProteinTrackerView` — `customName = "Quick Add"`; `TextField("Ask coach...", text:)` |
| **Current** | Default food name "Quick Add" saved to log; placeholder uses ellipsis inconsistently (`"Ask coach..."` vs `"Search exercises"`) |
| **Recommended** | Empty default name with placeholder `"Food name"`; unify placeholder pattern: no trailing ellipsis or always use em dash |
| **Rationale** | "Quick Add" entries pollute meal history; ellipsis rules should be consistent |
| **Verification checklist** | - [ ] New custom entry requires user-entered name or uses timestamp label<br>- [ ] Placeholder style documented |

---

### Finding SH-016

| Field | Value |
|---|---|
| **Smell** | Regenerate loading copy is jargon |
| **Severity** | **Low** |
| **Location** | `TodayView.swift` — `ForgeHeroRegeneratingOverlay` — `"RESHUFFLING"` |
| **Current** | ALL CAPS "RESHUFFLING" during workout regeneration |
| **Recommended** | `"Building new session…"` — matches generation semantics, sentence case |
| **Rationale** | "Reshuffle" sounds like card game; users expect "generating" or "building" |
| **Verification checklist** | - [ ] Loading state verb matches `Regenerate` CTA terminology |

---

## Content register (starter)

Canonical English strings for localization extraction. Keys are proposed `xcstrings` IDs.

### Navigation — tabs & screens

| Key | English | Context |
|---|---|---|
| `tab.today` | Today | Main tab |
| `tab.train` | Train | Main tab |
| `tab.protein` | Protein | Main tab |
| `tab.progress` | Progress | Main tab |
| `tab.coach` | Coach | Main tab |
| `screen.settings.title` | Settings | Settings header |
| `screen.settings.subtitle` | Profile, account, and preferences. | Settings header |
| `screen.exerciseLibrary.title` | Exercise Library | Library header |
| `screen.exerciseLibrary.subtitle` | Search, filter, and favorite movements. | Library header |
| `screen.bodyProgress.title` | Body Progress | Nav title |
| `screen.customEntry.title` | Custom Entry | Protein sheet |

### Eyebrows & section headers

| Key | English | Context |
|---|---|---|
| `eyebrow.program` | Program | Train tab |
| `eyebrow.nutrition` | Nutrition | Protein tab |
| `eyebrow.analytics` | Analytics | Progress tab |
| `eyebrow.activeSession` | Active Session | Train hero |
| `eyebrow.restDay` | Rest Day | Today rest hero |
| `eyebrow.dailyIntake` | Daily Intake | Protein hero |
| `eyebrow.preview` | Preview | Workout preview |
| `section.fastAdd` | Fast Add | Protein |
| `section.today` | Today | Protein log |
| `section.weekly` | Weekly | Protein chart |
| `section.compliance` | Compliance | Progress |
| `section.compliance.subtitle` | Weekly performance | Progress |
| `section.e1rmTrend` | E1RM Trend | Progress |
| `section.volumeTrend` | Volume Trend | Progress |
| `section.topLifts` | Top Lifts | Progress |
| `section.recovery` | Recovery | Progress |
| `section.insights` | Insights | Progress |
| `section.history` | History | Train card |
| `section.exerciseLibrary` | Exercise Library | Train card |
| `section.readinessCheck` | Readiness Check | Today soreness |
| `section.safetyNotes` | Safety Notes | Today disclosure |
| `section.suggestions` | Suggestions | Today disclosure |
| `section.whyThisWorkout` | Why This Workout? | Today disclosure |
| `section.commonMistakes` | Common mistakes | Exercise detail |

### Primary CTAs

| Key | English | Context |
|---|---|---|
| `cta.startWorkout` | Start Workout | Hero primary |
| `cta.start` | Start | Train hero (resolve vs startWorkout) |
| `cta.completeSet` | Complete Set | Active session |
| `cta.addSet` | Add Set | Active session |
| `cta.skipExercise` | Skip Exercise | Active session |
| `cta.skipRest` | Skip Rest | Rest timer |
| `cta.swapExercise` | Swap Exercise | Session + sheet title |
| `cta.done` | Done | Complete summary, sheets |
| `cta.continue` | Continue | Onboarding |
| `cta.back` | Back | Onboarding |
| `cta.save` | Save | Custom protein entry |
| `cta.cancel` | Cancel | Sheets |
| `cta.retry` | Retry | Failed load only |
| `cta.generateWorkout` | Generate Workout | Today empty state |
| `cta.regenerate` | Regenerate | Today/Train secondary |
| `cta.preview` | Preview | Secondary hero |
| `cta.previewPlan` | Preview Plan | Today completed state |
| `cta.browseExercises` | Browse Exercises | Train |
| `cta.addPhoto` | Add Photo | Body progress |
| `cta.askCoach` | Ask Coach | Today secondary |
| `cta.viewProgress` | View Progress | Today secondary |
| `cta.applyWorkout` | Apply | Coach proposal accept |
| `cta.keepWorkout` | Keep current | Coach proposal decline |
| `cta.signIn` | Sign In | Settings |
| `cta.createAccount` | Create Account | Settings |
| `cta.signOut` | Sign Out | Settings |
| `cta.syncNow` | Sync Now | Settings |

### Empty & loading states

| Key | English | Context |
|---|---|---|
| `empty.noWorkout.title` | No workout yet | Today |
| `empty.noWorkout.message` | Generate today's %@ session. | Today; `%@` = split name |
| `empty.noWorkouts` | No completed workouts yet. | Train history |
| `empty.noProteinEntries` | No entries yet. | Protein log |
| `empty.noPhotos` | No photos yet. Add your first progress photo. | Body progress |
| `empty.noStrengthData` | No strength data yet. Complete some workouts. | Progress E1RM |
| `empty.noVolumeData` | No volume data yet. Complete some workouts. | Progress volume |
| `empty.noLiftData` | No lift data yet. Start logging workouts. | Progress top lifts |
| `empty.noProgressPhotos` | No progress photos yet. Tap to add your first photo. | Progress card |
| `empty.noSubstitutes` | No substitutes available for your equipment and limitations. | Swap sheet |
| `empty.noEquipment` | No equipment required. | Exercise detail |
| `loading.plan` | Your plan is loading. | Today subtitle |
| `loading.regenerating` | Building new session… | Today overlay |
| `loading.trends` | Loading your trends... | Progress subtitle |
| `loading.recovery` | Recovery data loading... | Progress recovery |

### Workout session labels

| Key | English | Context |
|---|---|---|
| `session.set` | Set | Column header |
| `session.target` | Target | Column header |
| `session.actual` | Actual | Column header |
| `session.rest` | Rest %llds | Rest banner; `%lld` = seconds |
| `session.rest.add30` | +30 | Add rest time |
| `session.complete.title` | Workout complete | Summary |
| `session.exerciseProgress` | Exercise %1$d of %2$d | Header |
| `session.focusExercise` | Focus exercise | Timeline row |
| `session.demoVideo` | Demo video | Demo placeholder |

### Coach

| Key | English | Context |
|---|---|---|
| `coach.title` | Coach | Header |
| `coach.subtitle` | Ask for swaps, adjustments, and training advice. | Header |
| `coach.empty.title` | Ask your coach | Empty chat |
| `coach.input.placeholder` | Ask coach | Text field |
| `coach.proposal` | Coach proposed: %@ | Workout title |
| `coach.banner.updated` | Workout updated | Success banner |
| `coach.status.online` | Online | Eyebrow |
| `coach.status.signIn` | Sign in for full coach | Eyebrow |
| `coach.status.onDevice` | On-device coach | Eyebrow |
| `coach.suggestion.whyWorkout` | Why am I doing this workout today? | Chip |
| `coach.suggestion.shorter` | Make this workout 30 minutes. | Chip |
| `coach.suggestion.shoulder` | Shoulder discomfort — adjust exercises. | Chip |
| `coach.suggestion.proteinRemaining` | How much protein do I still need? | Chip |

### Onboarding

| Key | English | Context |
|---|---|---|
| `onboarding.welcome.title` | Training that adapts. | Welcome |
| `onboarding.welcome.body` | Dynamic strength workouts, protein tracking, visual progress, and an AI coach that explains the plan. | Welcome |
| `onboarding.photo.disclaimer` | Take consistent front, side, and back photos. The app will track visual changes over time. This is not a medical body-fat test. | Photo step |
| `onboarding.photo.setup` | Set Up Photo Tracking | CTA |
| `onboarding.photo.skip` | Skip For Now | Secondary |
| `onboarding.plan.milestone` | First milestone: Complete 4 workouts and hit protein 5 days in a row. | Plan ready |
| `onboarding.cta.startToday` | Start Today's Workout | Final step |

### Status, errors & disclaimers

| Key | English | Context |
|---|---|---|
| `error.auth.generic` | Could not sign in. Check your email and password. | Settings |
| `error.saveSettings` | Could not save settings. | Settings |
| `error.foodSearch` | Food search request failed. | Protein search |
| `sync.signedIn` | You're signed in and up to date. | Toast |
| `sync.signedOut` | Signed out. | Toast |
| `sync.signInRequired` | Sign in to sync your data. | Toast |
| `sync.complete` | Sync complete. | Toast |
| `settings.cloud.photosNote` | Photos stay local unless you enable backup while signed in. | Cloud backup |
| `swap.helper` | Swaps stay within the same muscle group and movement pattern. | Swap sheet |
| `swap.group` | Swap Group | Swap sheet section |
| `swap.alternatives` | Alternatives | Swap sheet section |
| `swap.current` | Current | Swap sheet label |
| `body.comparison.hint` | Add a second photo with the same pose for visual trend comparison. | Body progress |
| `body.comparison.unavailable` | Comparison unavailable. | Fallback summary |

### Dynamic copy templates

| Key | English | Context |
|---|---|---|
| `today.greeting.morning` | Good morning | Eyebrow |
| `today.greeting.afternoon` | Good afternoon | Eyebrow |
| `today.greeting.evening` | Good evening | Eyebrow |
| `today.rest.subtitle` | Recovery day — let your muscles rebuild. | Rest day |
| `today.complete.subtitle` | Session complete. Stay on top of protein tonight. | Completed |
| `today.exerciseCount` | %1$d exercises lined up · ~%2$d min | Hero subtitle |
| `protein.remaining` | %1$d g left to hit today's %2$d g goal | Header |
| `protein.goalMet` | Goal met for today. | Header |
| `readiness.question` | How sore are you? | Soreness strip |
| `readiness.sleep` | Sleep last night: %.1f h | Health hint |
| `greeting.timeGreeting` | See `today.greeting.*` | Time-based |

**Register total: 118 proposed strings** (starter set for `en` base localization)

---

## Button verb inventory

| Verb | Count | Locations | Notes |
|---|---|---|---|
| Start / Start Workout | 5 | Today, Train, Preview, Onboarding | Inconsistent — see SH-006 |
| Done | 4 | Session summary, Settings equipment, Today summary | OK |
| Skip | 2 | Rest, exercise | Ambiguous — see SH-009 |
| Save | 1 | Protein custom | OK |
| Cancel | 2 | Protein sheet, Swap sheet | OK |
| Back | 1 | Onboarding | OK |
| Continue | 1 | Onboarding | OK |
| Regenerate | 3 | Today, Train, ForgeHeroCard preview | OK |
| Preview / Preview Plan | 3 | Today, Train | Slight variant |
| Swap / Swap Exercise | 3 | Session, Train preview, sheet | OK |
| Add Set / Complete Set | 2 | Session | OK |
| Browse Exercises | 1 | Train | OK |
| Ask Coach | 1 | Today | OK |
| Apply Workout / Dismiss | 2 | Coach | Asymmetric — see SH-010 |
| Sign In / Out / Create Account | 3 | Settings | OK |
| Sync Now | 1 | Settings | OK |
| Retry | 1 | EmptyStateView | Misused — see SH-004 |
| Add Photo / Compare Latest Two | 2 | Body progress | OK |
| Avoid Exercise / Add Favorite | 2 | Exercise detail menu | OK |
| All | 2 | Library filters | OK |

---

## Recommended next steps

1. **P0 — Critical:** Add `Localizable.xcstrings`; remove dev plist copy from release Settings; map auth/sync errors to catalog strings.
2. **P1 — High:** Unify start-workout CTA; fix empty-state Retry; rename coach status eyebrows; normalize ALL CAPS drift.
3. **P2 — Medium:** Coach suggestion tone pass; skip-label disambiguation; empty-state template; body comparison disclaimer.
4. **P3 — Low:** Sync message benefits; placeholder consistency; regenerating copy; `Cal` accessibility.

---

## Sign-off

| Metric | Value |
|---|---|
| Findings | 16 |
| Critical | **3** |
| High | 5 |
| Medium | 5 |
| Low | 3 |
| Register strings | 118 |
| Localization files | 0 |
