# Physique Illustrative Direction Design

**Date:** 2026-08-10  
**Status:** Approved for planning  
**Depends on:**  
- `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`  
- `docs/superpowers/specs/2026-08-10-physique-archetype-directions-design.md`

## Goal

Add an **opt-in illustrative direction** on the Physique report: a server-side subtle image edit of the user’s front photo emphasizing current development priorities (and optional catalog **generic** direction labels). Clearly framed as illustration — not a body forecast, timeline, or lookalike claim.

## Constraints

- iOS 17+, SwiftUI, local-first cache; generation via Supabase edge + OpenAI (no client API keys).
- Prefer: “illustrative direction,” “subtle emphasis,” “not a prediction.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike/celebrity likeness, competitor assets, timeline promises (“in 12 weeks”).
- Subtle edit only — same person, pose, framing; no dramatic bulk or identity swap.
- Never send celebrity `referenceLabel` values into the model prompt — catalog `genericLabel` only.
- Never log photo bytes or full base64 payloads.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- Auto-generate on assess
- Progress tab side-by-side “after” compare
- Illustrations on history detail rows
- Dramatic direction-led stylization
- Cloud sync of generated images
- Client-only overlay mock as the product end state
- Exact body-fat or mass claims from the image

## Decisions

| Topic | Choice |
|-------|--------|
| Job | Motivational illustration |
| Produce | Server image edit from front photo |
| Trigger | Explicit CTA |
| Intensity | Subtle priority emphasis |
| Architecture | Dedicated `physique-illustrate` edge + local cache |

## 1. Product Surface

### Placement

Current Physique report only — section **after Why today’s training** (training-first; illustration is optional).

### States

| State | UI |
|-------|-----|
| Hidden | No active assessment |
| Ready | Assessment + front photo → CTA `Generate illustrative direction` (`physique.illustrate`) + helper `Subtle emphasis of your current focus areas. Not a prediction.` |
| No front photo | CTA disabled + `Add a front photo to generate.` |
| Generating | Loading on CTA/card: `Generating illustration…`; regenerate disabled |
| Result | Image in ForgeCard; title `Illustrative direction`; disclaimer `This is an illustration of possible emphasis — not a forecast of your body, timeline, or genetics.`; Regenerate (`physique.illustrate.regenerate`); container a11y `physique.illustrate.result` |
| Error | Status line only — no fake placeholder body |

### Lifecycle

- Cache keyed by **assessment id**. New assessment → previous illustration not shown; CTA available again.
- Regenerate replaces cache for the current assessment id.
- Account wipe clears illustration files + metadata.

## 2. Edge Function

### `physique-illustrate`

Mirror `physique-assess` auth + `OPENAI_API_KEY` gates.

**Request**
```text
{
  assessmentId: string (UUID),
  imageBase64: string,          // compressed front JPEG
  priorityMuscles: string[],    // PhysiqueFocusMuscle raw ids, max 3
  directionGenericLabels: string[]  // catalog genericLabel only, max 3
}
```

**Response**
```text
{
  imageBase64: string,
  contentType: "image/jpeg"
}
```

v1 returns base64 (avoid new storage bucket). Enforce size budget (~1–1.5MB decoded JPEG). Reject missing/empty image, unknown muscle ids, oversized payloads.

### Prompt rules (server)

- Subtle emphasis of listed muscle areas; keep same person, pose, framing, clothing style.
- Forbid: medical claims, BF%, timelines, “after N weeks,” celebrity likeness, competitor branding, different person / face swap, dramatic bulk.
- Inputs to the model: image + priority muscle display names derived server-side from allowlisted ids + generic direction labels only.

### Deno tests

- 401 without auth; 503 without key.
- Validation: missing image; >3 muscles trimmed/rejected.
- Prompt builder never includes a celebrity `referenceLabel`.

## 3. Client Architecture

```text
PhysiqueIllustrationHints
  priorityMuscles: [PhysiqueFocusMuscle]  // max 3 from assessment
  directionGenericLabels: [String]      // resolved via catalog genericLabel only

PhysiqueIllustrationRecord
  assessmentId: UUID
  sourcePhotoId: UUID
  createdAt: Date
  localImagePath: String

PhysiqueIllustrationService
  generate(hints, imageData) -> Data
LocalPhysiqueIllustrationStore
  fetch(assessmentId) / save / clear(assessmentId) / clearAll
```

**Hint builder:** take top 3 `developmentPriorities`; resolve directions through `PhysiqueDirectionResolve` / catalog — use `genericLabel` only; drop unknown ids.

**Compress:** max edge ~1024px, JPEG quality capped before upload.

**Remote:** invoke `physique-illustrate`; map errors to user-safe status strings.

**Mock:** returns fixture JPEG for UITests (`-MockAI` or dedicated flag if needed).

**AppEnvironment**
```text
physiqueIllustration: PhysiqueIllustrationRecord?
physiqueIllustrationStatus: String?
isGeneratingPhysiqueIllustration: Bool

loadPhysiqueIllustration(for assessmentId)
generatePhysiqueIllustration(assessment, photos)
clearPhysiqueIllustrations()  // account wipe
```

## 4. Testing

### Unit

- Hint builder strips reference labels / caps at 3.
- Compress respects max dimension.
- Store save/load/replace by assessmentId; `clearAll` empties.
- Wipe path clears illustrations.

### Deno

- Auth/key/validation/prompt scrub as above.

### Integration

- Mock generate → record persisted; `physiqueIllustration` set for active assessment.
- New assessment id → load returns nil until generate.

### UI

- Mock generate → result + disclaimer visible.
- Error path does not crash; no fake body image.

## 5. Implementation Order

1. Hints + local store + compress helpers + unit tests  
2. Edge `physique-illustrate` + Deno tests  
3. Remote/Mock service + AppEnvironment wiring (+ wipe)  
4. Physique UI section + UITest  

## 6. Success Criteria

- Users can opt in to a subtle illustrative edit tied to their priorities.
- Copy and prompts never claim prediction, BF%, genetics, or celebrity likeness.
- Assess path stays fast (illustration is a separate hop).
- Offline/unavailable fails clearly; UITests run on mocks without network.
