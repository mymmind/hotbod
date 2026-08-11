# Physique Front-Only Assessment Design

**Date:** 2026-08-11  
**Status:** Approved for planning  
**Depends on:** `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`  
**Supersedes (partially):** front+back hard gate in that design — back becomes optional like side.

## Goal

Lower the Physique photo gate so **front alone** is enough to run an assessment, while prompting the user that **back and side photos improve results**. Soft upsell in empty/ready and report states; no hard block for missing optional angles.

## Constraints

- iOS 17+, SwiftUI, local-first; extend existing `PhysiquePhotoGate` / hybrid assess pipeline.
- Prefer: “fuller read,” “better results,” “add back and side.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, inventing back metrics when absent.
- Optional angles that fail quality are omitted, not fatal.
- Edge `physique-assess` must accept front-only; if `"back"` is listed in `anglesAvailable`, back metrics remain required.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- Changing illustration (still front-based)
- Auto-reassess when optional angles are added later (stale-photo banner already covers newer photos)
- New Settings toggles
- Requiring side
- Weak synthetic placeholder back photos/metrics

## Decisions

| Topic | Choice |
|-------|--------|
| Required angle | Front only |
| Optional angles | Back + side |
| Upsell placement | Empty/ready helper + report soft CTA when any optional missing |
| Data model | Optional `backPhotoId` / `backMetrics` end-to-end |
| Quality on optional | Fail → drop angle; gate stays ready if front OK |
| Architecture | Optional-back through gate → request → assessment + edge |

## 1. Product Surface

### Gate

| Case | Result |
|------|--------|
| No front | `.missingAngles([.front])` |
| Front quality fail | `.qualityFailed` (front) |
| Front OK, no back/side | `.ready` with `back == nil`, `side == nil` |
| Front OK, back/side present + quality OK | `.ready` including those photos |
| Front OK, optional angle quality fail | `.ready` omitting that angle |

### Copy

- Missing front: “Add a front photo to get a focus plan.”
- Ready / empty helper: “Add back and side photos for a fuller read.”
- Report upsell (active report only, when back and/or side missing):  
  “Add back and side photos for better results.”  
  Accessibility: `physique.anglesUpsell`  
  CTAs only for angles still missing.
- All three present → no upsell.
- Retire hard-gate copy: “Add front and back photos…”, “Add a back photo to unlock a full assessment.”

### Stale

- Newer front than assessment → stale.
- If `backPhotoId != nil` and a newer back photo exists → stale.
- Side never drives stale.

## 2. Data Model & Pipeline

### Types

```text
PhysiquePhotoSelection
  front: BodyProgressPhoto
  back: BodyProgressPhoto?
  side: BodyProgressPhoto?

PhysiqueAssessmentRequest
  backMetrics: BodyPhotoAnalysis?   // was required

PhysiqueAssessment
  backPhotoId: UUID?                // decodeIfPresent → nil when absent
```

### Client services

- `PhysiquePhotoGate.evaluate` / `regate`: front required; optional angles included only when present and quality OK.
- `HybridPhysiqueAssessmentService`: do not throw `missingAngles([.back])` when back absent; analyze optional angles when present.
- Offline assessor: when back missing, lower confidence slightly and note limited angles; never invent back metrics.
- Remote client: send `metrics.back` only when present; `anglesAvailable` lists only included angles (always includes `"front"`).
- Sanitizer: allow nil back photo id; do not over-claim posterior development without back evidence.

### Edge (`physique-assess` / `physiqueSchemas.ts`)

- Require `metrics.front` and `anglesAvailable` containing `"front"`.
- `metrics.back` optional.
- If `anglesAvailable` includes `"back"`, require `metrics.back`.
- Update Deno test that currently expects 400 for missing back → front-only succeeds; add regression that back-in-angles without metrics → 400.

## 3. UI Wiring

- `PhysiqueView` empty/ready: front CTA when missing; Assess when ready; helper + optional Add back / Add side.
- Active report: `physique.anglesUpsell` card when optional angles missing.
- History snapshots: no upsell required (active report only).
- Status messages in `AppEnvironment+Physique` aligned with front-only gate.

## 4. Testing

- Unit: gate front-only ready; front+back ready; front quality fail blocks; back quality fail omits back and stays ready.
- Unit: `PhysiqueAssessment` decode missing `backPhotoId` → nil.
- Integration: `assessPhysique` with front-only succeeds; `backPhotoId == nil`.
- Deno: front-only OK; back listed without metrics → 400.
- UITest: front-only seed/path shows `physique.anglesUpsell`; full angles seed hides it.
- Update fixtures that assumed required back only where multi-angle coverage still needs them.

## 5. Out of Scope Follow-ups

- Completeness meter / confidence badge redesign beyond slight offline confidence nudge
- Prompting from Today tab
- Migrating historical assessments (already have back ids)
