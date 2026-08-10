# Physique Trend Bias Adapt Design

**Date:** 2026-08-10  
**Status:** Approved for planning  
**Depends on:**  
- `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`  
- `docs/superpowers/specs/2026-08-10-physique-assessment-history-diff-design.md`

## Goal

After a reassess with history ≥ 2, **soft-boost** the active assessment’s `trainingBias` when since-last trends support priorities the assessor already named — and show an **Updated because** explanation on the Physique report. Development priorities stay assessor truth; generation continues to read persisted `trainingBias`.

## Constraints

- iOS 17+, SwiftUI, local-first; pure adapter (no new cloud hop).
- Newest assessment remains the active record; avoided/injury still win in `makeWorkoutGenerationInput`.
- Prefer: “emphasized,” “moved up,” “visual trend,” “updated because.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, inventing focus the assessor did not name.
- Soft bias only — do not hard-lock programs or rewrite priority lists.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- Confirm-to-apply / Keep current dialogs
- Today tab chip / focus line changes
- Reassess cadence reminders
- Rewriting past history rows after save
- Direction-only or Vision-narrower rewrites
- After-image generation
- Cloud sync of adaptation metadata

## Decisions

| Topic | Choice |
|-------|--------|
| Job | Soft re-rank (diff-gated boost) |
| Base | Newest `developmentPriorities` → preferred groups |
| Persist | Rewrite `trainingBias` (+ rationale) only; priorities unchanged |
| UI | Physique-only Updated because block |
| Architecture | Adapter after assess, before `saveActive` |

## 1. Product Surface

### Trigger

After successful assess + sanitize, when a previous assessment exists in history:

1. Compute `PhysiqueAssessmentDiff` (current vs previous; front ratios from photos when available).
2. Run `PhysiqueTrendBiasAdapter.adapt`.
3. Persist the (possibly adapted) assessment via existing `saveActive`.

First assessment ever → skip adapter. No user confirmation step.

### What the user sees

| Element | Behavior |
|---------|----------|
| Development Priorities | Unchanged assessor list |
| Since last assessment | Unchanged (existing diff UI) |
| **Updated because** | Shown only when `trendAdaptation != nil`; 1–3 reason bullets; a11y `physique.updatedBecause` |
| Why today’s training | Existing `whyTodaySummary` + bias rationale (rationale may reflect adapt) |
| Today tab | Unchanged this slice |

### Partial / empty

| Case | Behavior |
|------|----------|
| History &lt; 2 | No adapt; hide Updated because |
| No boost signals | `didAdapt = false`; leave bias/rationale as post-sanitize; hide Updated because |
| Vision wider but no shoulder-mapped current priority | Skip Vision boost; other signals may still apply |
| Missing Vision ratios | Skip Vision signal |
| Legacy decode without field | `trendAdaptation = nil` |

## 2. Adapter

### Types

```text
struct PhysiqueTrendAdaptation: Codable, Hashable {
  var previousAssessmentId: UUID
  var reasons: [String]  // 1...3
}

struct PhysiqueTrendAdaptResult {
  var assessment: PhysiqueAssessment
  var didAdapt: Bool
  var reasons: [String]
}

enum PhysiqueTrendBiasAdapter {
  static func adapt(
    current: PhysiqueAssessment,
    previous: PhysiqueAssessment,
    diff: PhysiqueAssessmentDiff
  ) -> PhysiqueTrendAdaptResult
}
```

### Algorithm

1. `baseGroups = PhysiqueTrainingBiasMerger.preferredGroups(from: current.developmentPriorities.map(\.muscle))`.
2. Collect ordered boost `MuscleGroup`s + reasons (cap **3** reasons):

| Signal | Condition | Boost | Reason |
|--------|-----------|-------|--------|
| Appeared | `diff.priorityChanges.added` (current order) | That muscle’s `muscleGroups` | `"{displayName} emphasized — priority appeared since last."` |
| Moved up | Muscle in both lists; current index &lt; previous index | That muscle’s groups | `"{displayName} moved up in focus order."` |
| Vision wider | Any `visionTrends` line contains `"wider"` (case-insensitive) **and** a current priority maps to `.shoulders` | `.shoulders` (once) | `"{displayName} emphasized — visual trend wider."` (first shoulder-mapped priority’s name) |

3. Do **not** boost from removed priorities, Vision narrower/stable, build-only, or direction-only changes.
4. If no boosts → return `current` unchanged (`didAdapt = false`, `reasons = []`, clear any prior `trendAdaptation` on a fresh assess output — fresh assessments start without adaptation).
5. If boosts → reorder `baseGroups` so unique boost groups appear first (stable relative order among boosts, then remaining base groups); set:

```text
trainingBias.preferredMuscleGroups = reordered
trainingBias.rationale = reasons.joined(separator: " ")
trendAdaptation = PhysiqueTrendAdaptation(
  previousAssessmentId: previous.id,
  reasons: reasons
)
```

`developmentPriorities`, `whyTodaySummary`, muscle entries, directions — untouched.

### Wiring

```text
assess → sanitize → (optional) adapt with previous + diff → saveActive
```

Photos for Vision ratios: same lookup as `sinceLastPhysiqueDiff` (`frontPhotoId` → `analysis?.shoulderWaistRatio`). Offline and cloud paths both hit the adapter after sanitize.

## 3. UI

Placement on current Physique report: after **Development Priorities**, before **Why today’s training**.

| Element | Copy |
|---------|------|
| Title | `Updated because` |
| Body | `trendAdaptation.reasons` as bullets |
| a11y | `physique.updatedBecause` |

Past history detail: show Updated because only if that snapshot’s `trendAdaptation != nil` (read-only).

Tone: Forge-aligned, technical. No medical / destiny / lookalike framing.

## 4. Testing

### Unit

- Appeared priority → boost + reason; priorities list identical.
- Moved up → boost; appeared+moved-up cap at 3 reasons.
- Wider + shoulder priority → shoulders boost; wider without shoulder priority → no Vision boost.
- No signals → `didAdapt == false`, `trendAdaptation == nil`.
- Decode assessment missing `trendAdaptation` → `nil`.

### Integration

- Two assesses with an appeared priority → active `trainingBias` reflects boost; priorities unchanged (`testRegression_trendAdaptRewritesBiasNotPriorities`).
- Existing `testRegression_trainingBiasUsesNewestAssessmentOnly` still passes.

### UI

- Seed (or extend `-SeedPhysiqueHistory`) so adapt applies → `physique.updatedBecause` visible.
- No-adapt path → identifier absent.

## 5. Implementation Order

1. `PhysiqueTrendAdaptation` on assessment + decode default  
2. `PhysiqueTrendBiasAdapter` + unit tests  
3. Wire adapt into assess/save (with photo ratios)  
4. Updated because UI + UITest coverage  

## 6. Success Criteria

- Reassess with supporting trends soft-boosts training bias without inventing priorities.
- Users see a clear Updated because story on Physique when a boost applied.
- Avoided/injury still override; soft bias remains soft.
- First assessment and no-signal reassesses behave as today.
