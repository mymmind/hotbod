# Physique Split Suggestion Design

**Date:** 2026-08-11  
**Status:** Approved for planning  
**Depends on:** `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`, `docs/superpowers/specs/2026-08-11-physique-stronger-generation-bias-design.md`  
**Supersedes (partially):** stronger-bias non-goal “user-confirm split override / split suggestion dialog” — this slice adds an opt-in, user-confirmed split change from the Physique report only.

## Goal

When an active Physique assessment’s focus muscles are better served by the days/week–suggested split than the user’s current template, offer a one-shot **Apply / Not now** card on the Physique report. Apply updates `preferredSplit`, resets rotation, and regenerates today. Never auto-change the split.

## Constraints

- iOS 17+, SwiftUI, local-first; single generator; existing `TrainingSchedule` day focuses.
- Prefer: “better fit for your current focus,” “why today’s training.”
- Avoid: medical claims, genetic destiny, lookalike claims, “optimal program” guarantees.
- Safety gates (avoided / injury / recovery / validation) unchanged and still win over bias.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- Auto-changing split without confirmation
- Temporary / assessment-scoped split override (Settings remains source of truth after Apply)
- Today banner or Settings “Suggested: …” chrome
- Guaranteed Physique exercise slots
- User-tunable coverage weights
- Cloud sync of dismiss state
- Changing assess pipeline or remote prompts

## Decisions

| Topic | Choice |
|-------|--------|
| Job | Suggest only on mismatch when candidate covers Physique prefs better |
| Candidate source | Existing days/week heuristic (`suggestedSplit`) |
| Filter | Coverage score(candidate) > coverage score(current) |
| Apply | Update split + reset `splitDayIndex` to 0 + regenerate today |
| Dismiss | Silence until a new assessment id |
| UI | Physique report only |
| Persistence | Local dismiss/handled assessment id |

## 1. Product Behavior

### When the card shows

All must hold:

1. Active Physique assessment exists.
2. Suggestion not already dismissed/handled for this `assessment.id`.
3. `candidate = suggestedSplit(for: profile.trainingDaysPerWeek)` ≠ `profile.preferredSplit`.
4. `coverageScore(candidate) > coverageScore(current)` for Physique preferred muscles (minus avoided), order irrelevant for scoring.

If preferred muscles are empty after avoided filtering → no card.

### Coverage score

Pure function over one “week” of `trainingDaysPerWeek` sessions:

1. Let `preferred` = assessment `trainingBias.preferredMuscleGroups` filtered by profile avoided muscles only (same avoid list as generation bias merge). Do not invent a second injury filter here.
2. Build `N = max(1, trainingDaysPerWeek)` session focuses:
   - If `TrainingSchedule.splitSequence(for: split)` is non-empty: `focus_i = sequence[i % sequence.count]` for `i in 0..<N`.
   - If sequence is empty (`.adaptive`): each of the `N` days is treated as able to hit any muscle in the upper∪lower working set (union of `muscles(for: .upper)` and `muscles(for: .lower)`). Equivalently: every preferred muscle in that union scores `+N`; preferred muscles outside it score `0`.
3. For each session focus, take `TrainingSchedule.muscles(for: focus)` (adaptive day → upper∪lower set).
4. Score = sum over `m in preferred` of (number of sessions whose muscle set contains `m`).

Ties (`<=`) → no card. Candidate equal to current → no card (gate 3).

### Card copy

- Title: “Better split for your focus”
- Body: `\(current.displayName) → \(candidate.displayName)` plus a short line naming `highlightMuscles`: for each preferred muscle, `delta = sessionsHit(candidate) - sessionsHit(current)`; take up to two muscles with the highest positive delta (stable tie-break: earlier in preferred order). If no positive deltas (shouldn’t happen when scoreCandidate > scoreCurrent, but if aggregate win is diffuse), fall back to the first two preferred.
- No guarantee / destiny language.
- Actions: **Apply** / **Not now**
- Apply opens `confirmationDialog`: switching split regenerates today’s workout from day one of the new split.

### Apply

1. Confirm via dialog.
2. Persist `profile.preferredSplit = candidate`.
3. Reset `TrainingProgramState.splitDayIndex` to `0`.
4. Regenerate today’s workout (same path as other regenerate entry points).
5. Mark suggestion handled for this assessment id (same store as dismiss) so the card does not return after success.

On profile save or regenerate failure: leave split/rotation unchanged if possible; show existing generation-failure style alert; **do not** mark handled so the user can retry.

### Not now

Persist dismissed assessment id; hide card until a **new** assessment id (reassess).

### Account wipe

Clear dismissed/handled assessment id with other local Physique prefs.

## 2. Architecture

### Domain

New pure module, e.g. `HotBod/Domain/Physique/PhysiqueSplitSuggestion.swift`:

```text
struct PhysiqueSplitSuggestion: Equatable {
  var assessmentId: UUID
  var from: TrainingSplit
  var to: TrainingSplit
  var scoreCurrent: Int
  var scoreCandidate: Int
  var highlightMuscles: [MuscleGroup]  // 1–2 for copy
}

enum PhysiqueSplitSuggestionEvaluator {
  static func suggestedSplit(forDaysPerWeek: Int) -> TrainingSplit
  static func coverageScore(split:daysPerWeek:preferred: ) -> Int
  static func evaluate(...) -> PhysiqueSplitSuggestion?
}
```

Extract days/week heuristic into Domain (same rules as today):

| Days/week | Split |
|-----------|--------|
| …3 | `fullBody` |
| 4 | `upperLower` |
| 5…6 | `pushPullLegs` |
| else | `adaptive` |

`OnboardingProfileEditing.suggestedSplit` becomes a thin wrapper calling the Domain helper so onboarding tests keep passing.

### Persistence

Local only via a tiny UserDefaults-backed preferences type (same style as `ForgeFeedbackPreferences`):

- Key stores dismissed/handled `assessmentId` (`UUID?`)
- Written on Not now and on successful Apply
- Cleared on account wipe

### AppEnvironment

- `physiqueSplitSuggestion(assessment:profile:) -> PhysiqueSplitSuggestion?`
- `dismissPhysiqueSplitSuggestion(assessmentId:)`
- `applyPhysiqueSplitSuggestion(_:) async` → profile + rotation reset + regenerate + mark handled

Wire report UI through these methods; keep evaluator pure for unit tests.

### UI

`PhysiqueAssessmentReportContent` (or small child view): section **below** “Why today’s training” when suggestion non-nil.

Accessibility:

- `physique.splitSuggestion`
- apply / dismiss controls with stable identifiers

No Today / Settings surfaces in this slice.

## 3. Testing

- Unit: coverage — e.g. shoulders/back prefer PPL over UL at 5–6 days when current is UL and candidate is PPL; score math for fullBody vs UL; adaptive empty-sequence rule; tie → nil; dismissed id → nil; candidate == current → nil; empty preferred → nil.
- Unit: Domain `suggestedSplit(forDaysPerWeek:)` matches existing onboarding cases; onboarding wrapper still green.
- Integration: `applyPhysiqueSplitSuggestion` updates split, resets `splitDayIndex`, marks handled; failure path does not mark handled.
- UITest with seeded mismatch fixture under `-UITesting`, **or** explicit exemption comment if fixture cost is disproportionate — prefer UITest when a mock assessment + profile override is already easy in UI testing launch args.

## 4. Out of Scope Follow-ups

- Today “Physique emphasized” / split-suggestion banner
- Settings Split row suggested annotation
- Guaranteed Physique exercise slots
- Tunable coverage weights / alternate candidates beyond days/week heuristic
- Cloud sync of dismiss id
