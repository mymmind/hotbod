# Physique Assessment History & Diff Design

**Date:** 2026-08-10  
**Status:** Approved for planning  
**Depends on:**  
- `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`  
- `docs/superpowers/specs/2026-08-10-physique-archetype-directions-design.md`

## Goal

Turn Physique Focus into a longitudinal loop by **persisting assessment history** (rolling last 12) and showing a **structured + Vision “Since last assessment” diff** on the current report, plus a Physique-owned history list and read-only past snapshots. Progress remains the photo library / before-after tool.

This slice is **history + diff only** — it does not auto-rewrite training priorities from trends.

## Constraints

- iOS 17+, SwiftUI, local-first persistence (extend existing physique assessment repo).
- Active assessment for training bias remains the **newest** history entry.
- Diff is computed locally from stored assessments + linked photo metrics — no new cloud hop required for the diff itself.
- Prefer: “appeared,” “priority shifted,” “visual trend.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims.
- Cap history at 12 assessments; migrate the existing single-active file.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- Auto-updating priorities / training bias from detected trends
- Reassess cadence reminders / scheduling
- Cloud sync of assessment history
- Editing or deleting individual history rows (v1)
- Merging Progress photo UI into Physique
- After-image generation

## 1. Product Surface

### Ownership

| Surface | Owns |
|---------|------|
| Physique report | Current assessment + **Since last assessment** vs previous |
| Physique → History | Up to 12 assessments (newest first); tap → read-only snapshot; optional compare-to-previous |
| Progress | Photo library / pose before-after only (unchanged) |

### Happy path

1. User accumulates ≥2 assessments via Reassess.
2. Current report shows **Since last assessment** (date span, structured change bullets, optional Vision lines).
3. **Assessment history** opens a dated list; current row badged `Current`.
4. Past snapshot reuses report layout read-only (no Reassess on that screen).
5. Stale-photo banner behavior unchanged.

### Partial / empty

| Case | Behavior |
|------|----------|
| Only one assessment | Hide Since last; history may list Current with helper copy to reassess later |
| Diff fields all stable | Show `No meaningful change since last assessment.` |
| Missing Vision metrics on either side | Omit Vision lines; keep structured diff |
| Catalog missing for a direction id | Skip that direction label in diff copy |

## 2. Persistence

### Repository API

```text
PhysiqueAssessmentRepository
  fetchActive() -> PhysiqueAssessment?     // newest
  fetchHistory() -> [PhysiqueAssessment]   // newest-first, includes active, ≤ 12
  saveActive(_ assessment)                 // prepend newest; prune > 12
  fetch(id:) -> PhysiqueAssessment?
  clearActive() / clearAll()               // reset paths / tests
```

### Storage

- History document e.g. `physique_assessments.json`:
  `{ "assessments": [ /* newest first */ ] }`
- Migration: if legacy `physique_assessment.json` exists and history is empty, wrap the single assessment as a one-item history, then stop reading the legacy key (delete or ignore).
- Training bias / `activePhysiqueAssessment` = `assessments.first`.
- On `saveActive`: insert at front; if id already exists, replace in place then move to front; prune to 12.

## 3. Diff Model

Pure local engine:

```text
PhysiqueAssessmentDiff
  previousId, currentId
  previousDate, currentDate
  buildChanges: [(field, from, to)]
  priorityChanges: { added, removed, reordered }  // PhysiqueFocusMuscle
  directionChanges: { added, removed }            // archetypeId
  visionTrends: [String]
  summaryLines: [String]                          // 3–5 bullets for UI
```

### Structured comparison

- **Build:** compare `PhysiqueBuildSummary` string fields; emit only changed fields with human labels (Frame, Shoulder to waist, Muscularity, Leanness, etc.).
- **Priorities:** ordered muscle lists — detect added, removed, and reordered (same set, different order).
- **Directions:** set diff on `physiqueDirections.archetypeId`; display via local catalog `genericLabel`.

### Vision trends

- Load photos by `frontPhotoId` (and optionally `backPhotoId`) from each assessment.
- If both fronts have `shoulderWaistRatio`, produce trend copy consistent with `BodyPhotoVisionMetrics.comparisonSummary` (wider / narrower / stable).
- If either ratio missing → no Vision lines.
- No exact BF% or mass claims.

### When computed

- Current report: `diff(newest, secondNewest)` when history count ≥ 2.
- History detail: optional `diff(selected, nextOlder)` when a neighbor exists.

## 4. UI & Copy

### Since last assessment

| Element | Content |
|---------|---------|
| Title | `Since last assessment` |
| Subtitle | `{previousDate} → {currentDate}` (medium date style) |
| Body | `summaryLines` as bullets |
| Vision | Optional caption `Visual trend` + `visionTrends` |
| Stable case | `No meaningful change since last assessment.` |
| a11y | `physique.sinceLast` |

Placement: on current report after **Build Summary**, before **Development Priorities**.

### History

| Element | Content |
|---------|---------|
| Entry | Secondary control `Assessment history` — `physique.history` |
| List a11y | `physique.history.list`; rows `physique.history.<id>` |
| Row | Date + source (`Online` / `On-device`) + top priority display name |
| Current badge | `Current` |
| Detail | Read-only build / priorities / directions / why today; no Reassess |
| Optional | `Compare to previous` when older neighbor exists |

### Tone

- Direct, technical, Forge-aligned.
- No medical framing, no genetic destiny, no lookalike claims.

## 5. Testing

### Unit

- Save prepends; prune at 12; replace existing id then move to front.
- Migrate legacy single-file → one-item history.
- Diff: build field change; priority add/remove/reorder; direction add/remove; Vision when ratios present / omitted when nil; stable → meaningful-change false / stable summary line.

### Integration

- Two `saveActive` calls → history count 2; active is newest.
- `makeWorkoutGenerationInput` bias uses newest only (`testRegression_trainingBiasUsesNewestAssessmentOnly`).

### UI

- Two seeded assessments → Since last visible.
- History list count / Current badge.
- Past detail has no Reassess CTA.

## 6. Implementation Order

1. History repository + migration + InMemory/test wiring  
2. Diff engine (+ Vision helper using photo ids)  
3. Since-last section on current Physique report  
4. History list + read-only detail (+ optional compare)  

## 7. Success Criteria

- Users with multiple reassesses see a clear since-last story (structured ± Vision).
- Up to 12 assessments remain available in Physique history.
- Newest assessment still exclusively drives soft training bias.
- Legacy single-active files migrate without data loss.
- Progress photo UX remains the photo timeline, not the assessment report.
