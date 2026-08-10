# Physique Assessment — Coach Tab Replacement Design

**Date:** 2026-08-10  
**Status:** Approved for planning  
**Related:** Existing Progress photo pipeline (`BodyProgressPhoto`, `VisionBodyPhotoAnalyzer`); Phase 4 chat coach (`CoachView`, `coach` edge function) is superseded as the primary AI surface.

## Goal

Replace the Coach chat tab with a **Physique Focus** surface that:

1. Uses progress photos (front + back required; side optional) to produce a structured physique assessment.
2. Ranks development priorities by visual return for that frame.
3. Explains **why today’s training** reflects those priorities.
4. Soft-biases the existing workout generator via `preferredMuscleGroups` (and related hints later) without a second program engine.

The product loop for v1:

```text
Photos → hybrid assessment → priorities → soft training bias → “why today” UI
```

This is the AI differentiator. Chat-based “AI coach” is not.

## Constraints

- iOS 17+, SwiftUI, local-first MVP patterns (protocols, mock/offline first).
- AGENTS.md: no medical claims; no exact body-fat claims from selfies.
- AI may explain and bias but must not bypass workout validation.
- Somatotype language is descriptive shorthand only — never genetic destiny.
- Distinguish observable vs estimated vs cannot determine; suppress low-confidence guesses.
- No competitor assets; no celebrity likeness claims in v1 (archetypes deferred).
- App must compile after each implementation slice; tests per AGENTS.md hygiene.

## Non-goals (v1)

- Celebrity / athlete archetype matching
- Illustrative “after” physique image generation
- Hard custom split templates (upper/lower program authoring)
- Exact anatomical measurements or body-fat percentage
- Deleting the Supabase `coach` edge function infra (stop calling it from the tab; cleanup optional later)
- Subscription packaging redesign (may reuse an existing premium gate later)

## 1. Product Surface & Flow

### Tab ownership

| Surface | Owns |
|---------|------|
| **Physique tab** (replaces Coach) | Assessment gate, report, active priorities, “why today’s training,” reassess CTA |
| **Progress** | Photo library, pose timeline, before/after compare — not the full assessment report |
| **Today** | One-line focus bias + link back to Physique when an active assessment exists |

Recommend renaming the tab from “Coach” to **Physique** so the IA does not imply chat. Chat, suggestion chips, and “Apply AI workout proposal” leave this tab.

### Happy path

1. Open Physique → empty state if front+back missing.
2. User captures/imports **front + back** (side optional: “Add side for higher confidence”).
3. On-device Vision runs per photo (pose confidence, framing, lighting, shoulder/waist/hip estimates).
4. Quality gates pass → hybrid assessment (cloud when signed in + configured; else on-device).
5. Report: overall build, structural strengths, ranked priorities, confidence notes, why today’s training.
6. Persist assessment; soft-bias next generate/regenerate.
7. Today shows a short focus line when bias is active.

### Partial / blocked states

| Condition | Behavior |
|-----------|----------|
| Missing back | Block full assessment; prompt to add back |
| Side missing | Allow full assessment; lower confidence where side would help |
| Vision quality fail | Angle-specific retake; no cloud call |
| Cloud unavailable / signed out | On-device thin assessment; label `On-device estimate` |
| New photos in Progress, not reassessed | Stale banner: “New photos available — Reassess” |

## 2. Architecture

### Components

| Piece | Role |
|-------|------|
| `VisionBodyPhotoAnalyzer` (existing) | Per-photo metrics + quality gates |
| `PhysiqueAssessmentService` (new protocol) | Orchestrate photos → local metrics → cloud or offline → `PhysiqueAssessment` |
| `RemotePhysiqueAssessmentService` | Supabase edge `physique-assess`; multimodal + structured JSON |
| `OfflinePhysiqueAssessmentService` | Heuristic priorities from ratios/angles; lower confidence |
| Physique assessment repository / store | Persist latest (active) assessment; history optional in v1 |
| `AppEnvironment.makeWorkoutGenerationInput` | Merge `trainingBias.preferredMuscleGroups` into generation input |
| `PhysiqueView` (replaces `CoachView`) | Gate + report UI |

### Data flow

```text
BodyProgressPhoto (front, back, side?)
    → VisionBodyPhotoAnalyzer (per photo)
    → PhysiqueAssessmentService
         ├ RemotePhysiqueAssessmentService (signed in + configured)
         └ OfflinePhysiqueAssessmentService (fallback)
    → persist PhysiqueAssessment (active)
    → makeWorkoutGenerationInput merges trainingBias
    → existing workout generator + validation
```

### Cloud contract

- New edge function: `physique-assess` (not the chat `coach` function).
- Auth: signed-in user JWT required for cloud path.
- Input: angles available, per-photo Vision metrics, optional downscaled images, profile goal / experience / limitations.
- Output: schema-validated JSON matching the client `PhysiqueAssessment` shape (no free-form program JSON in v1).
- Client re-validates: unknown muscle ids dropped; low-confidence claims stripped or demoted.
- Logs: never include photo bytes, message PII, or full response bodies; categorize failures like existing cloud-coach logging.

### Safety rules (encoded)

- No exact body-fat %.
- No “you are genetically an X-morph.”
- Observable / estimated / unknown must be representable on muscle and structure fields.
- Injuries and avoided muscle groups still win over assessment bias.
- Assessment never bypasses workout validation.

## 3. Domain Model

```text
PhysiqueAssessment
  id: UUID
  createdAt: Date
  photoIds: front, back, side?
  photoQuality: angles, lightingQuality, overallConfidence
  physique: overallArchetype (descriptive), frameSize, shoulderToWaist (qualitative),
            waist, torso, muscularity, leanness
  muscleGroups: [{ id, current, priority?, notes, confidence }]
  developmentPriorities: ordered [{ muscleId, reason }]
  trainingBias: { preferredMuscleGroups, rationale }
  limitations: [String]
  confidenceBands: high / medium / low observation lists
  source: cloud | onDevice
```

### Lifecycle

- Exactly one **active** assessment drives training bias.
- Re-run on explicit **Reassess** or when the user completes a new eligible front+back set from the Physique flow.
- v1 may keep only latest + optional previous for “updated from last assessment” copy; full history UI is deferred.

### Generation merge

In `makeWorkoutGenerationInput` (or a focused helper it calls):

1. Load active `PhysiqueAssessment.trainingBias.preferredMuscleGroups` if present.
2. Union with profile `preferredMuscleGroups` (stable order: assessment priorities first, then profile).
3. Remove any groups present in `avoidedMuscleGroups` / blocked by active limitations policy.
4. Pass through existing generator — no new split engine.

## 4. UI States & Copy

### Physique tab states

1. **Empty** — CTA to add front+back (reuse Progress import path).
2. **Needs retake** — Per-angle failure reasons (pose / framing / lighting).
3. **Assessing** — Local then cloud; keep prior report visible when refreshing.
4. **Report (cloud)** — Full structured report; eyebrow e.g. `Online`.
5. **Report (on-device)** — Same layout, thinner content; eyebrow `On-device estimate`.
6. **Stale bias** — Banner when Progress has newer eligible photos.

### “Why today’s training”

- 3–5 lines: top priorities + how they bias the current plan.
- Not a full program card.
- Mirror a one-liner on Today when bias is active.

### Errors

| Failure | User-facing | Behavior |
|---------|-------------|----------|
| Missing back | Add back to unlock full assessment | Block full run |
| Quality gate fail | Angle-specific retake | No cloud call |
| Signed out / no config | Using on-device estimate | Offline path |
| Cloud / decode failure | Cloud unavailable — on-device estimate | Fallback + private log |
| Partial visibility (e.g. rear delts) | `uncertain`; omit or low-rank | Do not invent |
| Priority conflicts with injury/avoid | Shown in report; bias softened/skipped for that group | Safety wins |

### Tone

- Direct, technical, calm — Forge content rules.
- No hype, no genetic destiny, no medical framing.

### Chat removal

- Remove Coach message list, suggestion chips, pending apply-workout card from this tab.
- Stop invoking chat coach from the tab; leave `coach` function dormant unless another caller remains.

## 5. Testing

### Unit

- Photo gate: front+back required; side optional raises confidence.
- Offline heuristic: stable priorities from metric fixtures; never emits exact BF%.
- Cloud JSON mapping: unknown muscle ids dropped; low-confidence demoted.
- Generation merge: bias unions into `preferredMuscleGroups`; avoided/injury still win.
- `testRegression_*` if any Coach-chat entry points remain reachable from the Physique tab.

### Integration (`AppEnvironment`)

- Mock analyzer + mock remote → persists active assessment.
- `makeWorkoutGenerationInput` includes bias after assess.
- Cloud failure → offline assessment persisted with `source: onDevice`.

### UI

- Empty → add photos path.
- Report shows priorities + why today.
- Launch: `-UITesting -ResetState -MockAI` (extend mocks for physique assess).
- Replace `CoachUITests` chat assertions with Physique coverage (`PhysiqueUITests` or renamed file).

### Edge

- Deno tests beside `supabase/functions/physique-assess/`: schema validation, auth required, prompt/contract guards against medical and exact BF claims.

## 6. Implementation Order

1. Domain model + local persistence + generation merge (hooks; minimal UI).
2. Offline assessment + Physique tab shell replacing Coach chat.
3. Cloud edge + hybrid path + Today one-liner.
4. Test migration; remove dead Coach-chat UI entry points from the tab.

## 7. Success Criteria

- User with front+back photos can see a structured assessment and ranked priorities without using chat.
- Regenerating today’s workout reflects soft bias from active priorities when not blocked by recovery/injuries/validation.
- Cloud failure never bricks the tab; on-device estimate still works.
- No exact body-fat percentage or genetic-destiny copy in user-facing strings.
- Coach chat is no longer the primary AI surface.
